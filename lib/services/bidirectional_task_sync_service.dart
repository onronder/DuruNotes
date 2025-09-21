import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:intl/intl.dart';

/// Service that maintains bidirectional sync between notes and tasks
/// Ensures that changes in either direction are properly reflected
class BidirectionalTaskSyncService {
  BidirectionalTaskSyncService({
    required AppDb database,
    required TaskService taskService,
  })  : _db = database,
        _taskService = taskService;

  final AppDb _db;
  final TaskService _taskService;
  final AppLogger _logger = LoggerFactory.instance;

  // Track active sync operations to prevent loops
  final Set<String> _activeSyncOperations = {};

  // Cache for line mappings
  final Map<String, TaskLineMapping> _lineMappingCache = {};

  // Pending changes queue for robust sync
  final Map<String, List<PendingChange>> _pendingChanges = {};
  Timer? _debounceTimer;

  // Debounce delays
  static const _defaultDebounceDelay = Duration(milliseconds: 500);
  static const _criticalDebounceDelay = Duration(milliseconds: 100);

  /// Initialize bidirectional sync for a note
  Future<void> initializeBidirectionalSync(String noteId) async {
    try {
      // Perform initial sync from note to tasks
      final note = await _db.getNote(noteId);
      if (note != null) {
        // This creates any missing tasks with stable IDs based on content hash
        await syncFromNoteToTasks(noteId, note.body);

        // Count tasks for logging
        final taskCount =
            await _db.getTasksForNote(noteId).then((tasks) => tasks.length);

        _logger.info('Initialized bidirectional sync for note', data: {
          'noteId': noteId,
          'taskCount': taskCount,
          'hasCheckboxes':
              note.body.contains('- [ ]') || note.body.contains('- [x]'),
        });
      } else {
        _logger.warning('Note not found for bidirectional sync initialization',
            data: {'noteId': noteId});
      }
    } catch (e, stack) {
      _logger.error('Failed to initialize bidirectional sync',
          error: e, stackTrace: stack, data: {'noteId': noteId});
      // Don't rethrow - allow note to open even if sync fails
    }
  }

  /// Sync changes from note content to task database
  Future<void> syncFromNoteToTasks(String noteId, String noteContent) async {
    // Prevent sync loops
    final syncKey = 'note_to_task_$noteId';
    if (_activeSyncOperations.contains(syncKey)) {
      return;
    }

    // Start metrics tracking
    final syncId = TaskSyncMetrics.instance.startSync(
      noteId: noteId,
      syncType: 'note_to_tasks',
      metadata: {
        'hasCheckboxes':
            noteContent.contains('- [ ]') || noteContent.contains('- [x]'),
      },
    );

    _activeSyncOperations.add(syncKey);
    int taskCount = 0;
    int duplicatesFound = 0;

    try {
      // Parse tasks from note content with line tracking
      final taskMappings = _parseTasksWithLineTracking(noteId, noteContent);
      taskCount = taskMappings.length;

      // Get existing tasks from database
      final existingTasks = await _db.getTasksForNote(noteId);
      final existingMap = {for (var task in existingTasks) task.id: task};

      // Check for potential duplicates
      final contentHashes = <String>{};
      for (final mapping in taskMappings) {
        final hash = _generateStableTaskId(
            noteId, mapping.lineNumber, mapping.taskContent);
        if (contentHashes.contains(hash)) {
          duplicatesFound++;
          TaskSyncMetrics.instance.recordDuplicate(
            noteId: noteId,
            taskId: mapping.taskId,
            duplicateId: hash,
            reason: 'Duplicate content hash in same note',
          );
        }
        contentHashes.add(hash);
      }

      // Update or create tasks
      for (final mapping in taskMappings) {
        await _syncTaskFromMapping(mapping, existingMap);
      }

      // Handle deleted tasks (tasks in DB but not in note)
      final currentTaskIds = taskMappings.map((m) => m.taskId).toSet();
      for (final existingTask in existingTasks) {
        if (!currentTaskIds.contains(existingTask.id)) {
          await _taskService.deleteTask(existingTask.id);
          _logger.debug('Deleted task not found in note', data: {
            'taskId': existingTask.id,
            'noteId': noteId,
          });
        }
      }

      // Update cache
      _updateLineMappingCache(noteId, taskMappings);

      // Record success
      TaskSyncMetrics.instance.endSync(
        syncId: syncId,
        success: true,
        taskCount: taskCount,
        duplicatesFound: duplicatesFound,
      );
    } catch (e, stack) {
      // Record failure
      TaskSyncMetrics.instance.endSync(
        syncId: syncId,
        success: false,
        taskCount: taskCount,
        duplicatesFound: duplicatesFound,
        error: e.toString(),
      );

      _logger.error(
        'Failed to sync from note to tasks',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      rethrow;
    } finally {
      _activeSyncOperations.remove(syncKey);
    }
  }

  /// Sync changes from task to note content
  Future<void> syncFromTaskToNote({
    required String taskId,
    required String noteId,
    String? newContent,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? dueDate,
  }) async {
    // Prevent sync loops
    final syncKey = 'task_to_note_$taskId';
    if (_activeSyncOperations.contains(syncKey)) {
      return;
    }

    _activeSyncOperations.add(syncKey);
    try {
      final note = await _db.getNote(noteId);
      if (note == null) {
        _logger.warning('Note not found for task sync', data: {
          'taskId': taskId,
          'noteId': noteId,
        });
        return;
      }

      // Get the line mapping for this task
      final mapping = await _getTaskLineMapping(taskId, noteId);
      if (mapping == null) {
        _logger.warning('No line mapping found for task', data: {
          'taskId': taskId,
          'noteId': noteId,
        });
        return;
      }

      // Update the note content
      final updatedContent = _updateNoteContentForTask(
        noteContent: note.body,
        mapping: mapping,
        newContent: newContent,
        isCompleted: isCompleted,
        priority: priority,
        dueDate: dueDate,
      );

      if (updatedContent != note.body) {
        // Save the updated note
        await _db.updateNote(
          noteId,
          LocalNotesCompanion(
            id: Value(noteId),
            body: Value(updatedContent),
            updatedAt: Value(DateTime.now()),
          ),
        );

        _logger.debug('Updated note content from task change', data: {
          'taskId': taskId,
          'noteId': noteId,
          'lineNumber': mapping.lineNumber,
        });
      }
    } finally {
      _activeSyncOperations.remove(syncKey);
    }
  }

  /// Parse tasks from note content with precise line tracking
  List<TaskLineMapping> _parseTasksWithLineTracking(
      String noteId, String content) {
    final mappings = <TaskLineMapping>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final taskInfo = _parseTaskLine(line);

      if (taskInfo != null) {
        // Use embedded ID if present, otherwise generate stable ID
        final taskId = taskInfo.embeddedId ??
            _generateStableTaskId(noteId, i, taskInfo.content);

        mappings.add(TaskLineMapping(
          taskId: taskId,
          noteId: noteId,
          lineNumber: i,
          lineContent: line,
          taskContent: taskInfo.content,
          isCompleted: taskInfo.isCompleted,
          indentLevel: taskInfo.indentLevel,
          priority: taskInfo.priority,
          dueDate: taskInfo.dueDate,
          contentHash: _hashContent(line),
        ));
      }
    }

    return mappings;
  }

  /// Parse a single line to extract task information
  TaskInfo? _parseTaskLine(String line) {
    // Match checkbox patterns with optional indentation
    final checkboxRegex = RegExp(r'^(\s*)- \[([ xX])\]\s+(.*)$');
    final match = checkboxRegex.firstMatch(line);

    if (match == null) return null;

    final indent = match.group(1)!;
    final isCompleted = match.group(2)!.toLowerCase() == 'x';
    var content = match.group(3)!;

    // Extract embedded task ID if present
    String? embeddedId;
    final idRegex = RegExp(r'<!-- task-id:([a-f0-9\-]+) -->');
    final idMatch = idRegex.firstMatch(content);
    if (idMatch != null) {
      embeddedId = idMatch.group(1);
      // Remove ID comment from visible content
      content = content.replaceAll(idMatch.group(0)!, '').trim();
    }

    // Extract metadata from content
    final priority = _extractPriority(content);
    final dueDate = _extractDueDate(content);
    final cleanContent = _removeMetadata(content);

    return TaskInfo(
      content: cleanContent,
      isCompleted: isCompleted,
      indentLevel: indent.length ~/ 2, // Assuming 2 spaces per indent
      priority: priority,
      dueDate: dueDate,
      embeddedId: embeddedId,
    );
  }

  /// Update note content with task changes
  String _updateNoteContentForTask({
    required String noteContent,
    required TaskLineMapping mapping,
    String? newContent,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    final lines = noteContent.split('\n');

    // Validate line number
    if (mapping.lineNumber >= lines.length) {
      _logger.warning('Line number out of range', data: {
        'lineNumber': mapping.lineNumber,
        'totalLines': lines.length,
      });
      return noteContent;
    }

    // Get current line
    String currentLine = lines[mapping.lineNumber];

    // Verify this is the correct line (using content hash)
    if (_hashContent(currentLine) != mapping.contentHash) {
      // Line has moved, try to find it
      final newLineNumber = _findTaskLine(lines, mapping);
      if (newLineNumber == -1) {
        _logger.warning('Could not find task line in note', data: {
          'taskId': mapping.taskId,
          'expectedHash': mapping.contentHash,
        });
        return noteContent;
      }
      currentLine = lines[newLineNumber];
      mapping.lineNumber = newLineNumber;
    }

    // Build updated line
    final indent = ' ' * (mapping.indentLevel * 2);
    final checkbox = isCompleted ?? mapping.isCompleted ? '[x]' : '[ ]';
    final content = newContent ?? mapping.taskContent;

    // Add metadata
    String updatedLine = '$indent- $checkbox $content';

    if (priority != null && priority != TaskPriority.medium) {
      updatedLine += ' #${_priorityToString(priority)}';
    }

    if (dueDate != null) {
      updatedLine += ' @${DateFormat('yyyy-MM-dd').format(dueDate)}';
    }

    // Embed task ID to preserve identity across edits
    updatedLine += ' <!-- task-id:${mapping.taskId} -->';

    // Update the line
    lines[mapping.lineNumber] = updatedLine;

    // Update the mapping's content hash for future reference
    mapping.contentHash = _hashContent(updatedLine);

    return lines.join('\n');
  }

  /// Find a task line that may have moved
  int _findTaskLine(List<String> lines, TaskLineMapping mapping) {
    // First, try to find by task content
    for (int i = 0; i < lines.length; i++) {
      final taskInfo = _parseTaskLine(lines[i]);
      if (taskInfo != null && taskInfo.content == mapping.taskContent) {
        return i;
      }
    }

    // If not found, try fuzzy matching
    for (int i = 0; i < lines.length; i++) {
      final taskInfo = _parseTaskLine(lines[i]);
      if (taskInfo != null &&
          _isSimilarContent(taskInfo.content, mapping.taskContent)) {
        return i;
      }
    }

    return -1;
  }

  /// Check if two task contents are similar (for fuzzy matching)
  bool _isSimilarContent(String content1, String content2) {
    // Simple similarity check - can be enhanced
    final words1 = content1.toLowerCase().split(' ');
    final words2 = content2.toLowerCase().split(' ');

    if (words1.isEmpty || words2.isEmpty) return false;

    // Check if at least 70% of words match
    final matchingWords = words1.where((w) => words2.contains(w)).length;
    final similarity = matchingWords / words1.length;

    return similarity >= 0.7;
  }

  /// Sync a single task from mapping with metadata preservation
  Future<void> _syncTaskFromMapping(
    TaskLineMapping mapping,
    Map<String, NoteTask> existingTasks,
  ) async {
    // Try multiple strategies to find the best match
    final matchedTask = _findBestMatchForTask(mapping, existingTasks);

    if (matchedTask != null) {
      // Update existing task if changed, preserving metadata
      if (_hasTaskChanged(matchedTask, mapping)) {
        await _updateTaskPreservingMetadata(matchedTask, mapping);
      }
    } else {
      // Create new task
      await _taskService.createTask(
        noteId: mapping.noteId,
        content: mapping.taskContent,
        status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
        priority: mapping.priority ?? TaskPriority.medium,
        dueDate: mapping.dueDate,
        position: mapping.lineNumber,
      );
    }
  }

  /// Find the best matching task using multiple strategies
  NoteTask? _findBestMatchForTask(
    TaskLineMapping mapping,
    Map<String, NoteTask> existingTasks,
  ) {
    // 1. Try exact ID match
    if (existingTasks.containsKey(mapping.taskId)) {
      return existingTasks[mapping.taskId];
    }

    // 2. Try content + position matching
    final candidates = <NoteTask, double>{};

    for (final task in existingTasks.values) {
      double score = 0.0;

      // Position similarity (30% weight)
      if (task.position == mapping.lineNumber) {
        score += 0.3;
      } else {
        final positionDiff = (task.position - mapping.lineNumber).abs();
        score += (0.3 / (1.0 + positionDiff));
      }

      // Content similarity (70% weight)
      final contentScore = calculateContentSimilarity(
        task.content,
        mapping.taskContent,
      );
      score += contentScore * 0.7;

      if (score > 0.6) {
        // Minimum threshold
        candidates[task] = score;
      }
    }

    if (candidates.isEmpty) return null;

    // Return best match
    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  /// Calculate content similarity between two strings
  double calculateContentSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Normalize strings
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    // Simple word-based similarity
    final words1 = s1.split(RegExp(r'\s+'));
    final words2 = s2.split(RegExp(r'\s+'));

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    // Count matching words
    int matches = 0;
    for (final word in words1) {
      if (words2.contains(word)) matches++;
    }

    // Calculate similarity as ratio of matches
    final similarity = matches / words1.length;
    return similarity;
  }

  /// Update task while preserving metadata
  Future<void> _updateTaskPreservingMetadata(
    NoteTask existingTask,
    TaskLineMapping mapping,
  ) async {
    await _taskService.updateTask(
      taskId: existingTask.id,
      content: mapping.taskContent,
      status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
      priority: mapping.priority ?? existingTask.priority,
      dueDate: mapping.dueDate ?? existingTask.dueDate,
      // Preserve metadata fields
      labels: existingTask.labels != null
          ? {'labels': jsonDecode(existingTask.labels!)}
          : null,
      notes: existingTask.notes,
      estimatedMinutes: existingTask.estimatedMinutes,
      actualMinutes: existingTask.actualMinutes,
      reminderId: existingTask.reminderId,
    );

    _logger.debug('Updated task preserving metadata', data: {
      'taskId': existingTask.id,
      'content': mapping.taskContent,
      'preservedFields': ['labels', 'notes', 'estimatedMinutes', 'reminderId'],
    });
  }

  /// Check if task has changed
  bool _hasTaskChanged(NoteTask existingTask, TaskLineMapping mapping) {
    return existingTask.content != mapping.taskContent ||
        (existingTask.status == TaskStatus.completed) != mapping.isCompleted ||
        existingTask.priority != (mapping.priority ?? TaskPriority.medium) ||
        existingTask.dueDate != mapping.dueDate;
  }

  /// Generate stable task ID
  String _generateStableTaskId(String noteId, int lineNumber, String content) {
    // Use note ID and content hash for stability
    final hash = _hashContent('$noteId:$content');
    return '${noteId}_task_${hash.substring(0, 8)}';
  }

  /// Hash content for comparison
  String _hashContent(String content) {
    final bytes = utf8.encode(content.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Extract priority from task content
  TaskPriority? _extractPriority(String content) {
    final priorityRegex =
        RegExp(r'#(urgent|high|medium|low)\b', caseSensitive: false);
    final match = priorityRegex.firstMatch(content);

    if (match != null) {
      final priorityStr = match.group(1)!.toLowerCase();
      switch (priorityStr) {
        case 'urgent':
          return TaskPriority.urgent;
        case 'high':
          return TaskPriority.high;
        case 'medium':
          return TaskPriority.medium;
        case 'low':
          return TaskPriority.low;
      }
    }

    return null;
  }

  /// Extract due date from task content
  DateTime? _extractDueDate(String content) {
    // Match patterns like @2024-01-15 or @today or @tomorrow
    final dateRegex = RegExp(r'@(\d{4}-\d{2}-\d{2}|\w+)');
    final match = dateRegex.firstMatch(content);

    if (match != null) {
      final dateStr = match.group(1)!;

      // Handle relative dates
      if (dateStr.toLowerCase() == 'today') {
        return DateTime.now();
      } else if (dateStr.toLowerCase() == 'tomorrow') {
        return DateTime.now().add(const Duration(days: 1));
      }

      // Try to parse ISO date
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        // Invalid date format
      }
    }

    return null;
  }

  /// Remove metadata from content
  String _removeMetadata(String content) {
    // Remove priority tags and due dates
    return content
        .replaceAll(
            RegExp(r'#(urgent|high|medium|low)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'@(\d{4}-\d{2}-\d{2}|\w+)'), '')
        .trim();
  }

  /// Convert priority to string
  String _priorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 'urgent';
      case TaskPriority.high:
        return 'high';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.low:
        return 'low';
    }
  }

  /// Update line mapping cache
  void _updateLineMappingCache(String noteId, List<TaskLineMapping> mappings) {
    _lineMappingCache.clear();
    for (final mapping in mappings) {
      _lineMappingCache[mapping.taskId] = mapping;
    }
  }

  /// Get task line mapping
  Future<TaskLineMapping?> _getTaskLineMapping(
      String taskId, String noteId) async {
    // Check cache first
    if (_lineMappingCache.containsKey(taskId)) {
      return _lineMappingCache[taskId];
    }

    // Rebuild cache if needed
    final note = await _db.getNote(noteId);
    if (note != null) {
      final mappings = _parseTasksWithLineTracking(noteId, note.body);
      _updateLineMappingCache(noteId, mappings);
      return _lineMappingCache[taskId];
    }

    return null;
  }

  /// Clear cache for a note
  void clearCacheForNote(String noteId) {
    _lineMappingCache.removeWhere((key, value) => value.noteId == noteId);
  }

  /// Schedule sync with debouncing
  void _scheduleSync(String noteId, {bool isCritical = false}) {
    // Cancel existing timer
    _debounceTimer?.cancel();

    // Use shorter delay for critical changes (like checkbox toggles)
    final delay = isCritical ? _criticalDebounceDelay : _defaultDebounceDelay;

    _debounceTimer = Timer(delay, () async {
      await _processPendingChanges(noteId);
    });
  }

  /// Process all pending changes for a note
  Future<void> _processPendingChanges(String noteId) async {
    final changes = _pendingChanges[noteId];
    if (changes == null || changes.isEmpty) return;

    // Clear pending changes for this note
    _pendingChanges[noteId] = [];

    // If another sync is active, queue these changes
    if (_activeSyncOperations.contains('note_to_task_$noteId')) {
      _pendingChanges[noteId] = changes;
      _scheduleSync(noteId); // Reschedule
      return;
    }

    _activeSyncOperations.add('note_to_task_$noteId');
    try {
      // Get latest note content
      final note = await _db.getNote(noteId);
      if (note != null) {
        // Apply all changes by doing a full sync
        await syncFromNoteToTasks(noteId, note.body);
      }
    } finally {
      _activeSyncOperations.remove('note_to_task_$noteId');

      // Check if more changes accumulated
      if (_pendingChanges[noteId]?.isNotEmpty ?? false) {
        _scheduleSync(noteId);
      }
    }
  }

  /// Handle task toggle specifically for rapid changes
  Future<void> handleTaskToggle({
    required String taskId,
    required String noteId,
    required bool isCompleted,
  }) async {
    // Add to pending changes
    _pendingChanges[noteId] ??= [];
    _pendingChanges[noteId]!.add(
      PendingChange(
        type: ChangeType.toggle,
        taskId: taskId,
        isCompleted: isCompleted,
        timestamp: DateTime.now(),
      ),
    );

    // Schedule with critical priority
    _scheduleSync(noteId, isCritical: true);
  }

  /// Force immediate sync (for note close)
  Future<void> forceSyncForNote(String noteId) async {
    // Cancel any pending debounced syncs
    _debounceTimer?.cancel();

    // Process any pending changes immediately
    if (_pendingChanges[noteId]?.isNotEmpty ?? false) {
      await _processPendingChanges(noteId);
    }

    // Do a final sync to ensure everything is up to date
    final note = await _db.getNote(noteId);
    if (note != null) {
      await syncFromNoteToTasks(noteId, note.body);
    }
  }

  /// Cancel pending sync for a note
  void cancelPendingSync(String noteId) {
    _debounceTimer?.cancel();
    _pendingChanges.remove(noteId);
  }
}

/// Pending change for queue system
class PendingChange {
  final ChangeType type;
  final String taskId;
  final bool? isCompleted;
  final String? content;
  final DateTime timestamp;

  PendingChange({
    required this.type,
    required this.taskId,
    this.isCompleted,
    this.content,
    required this.timestamp,
  });
}

enum ChangeType { toggle, edit, create, delete }

/// Task line mapping for tracking tasks in notes
class TaskLineMapping {
  TaskLineMapping({
    required this.taskId,
    required this.noteId,
    required this.lineNumber,
    required this.lineContent,
    required this.taskContent,
    required this.isCompleted,
    required this.indentLevel,
    required this.contentHash,
    this.priority,
    this.dueDate,
  });

  final String taskId;
  final String noteId;
  int lineNumber; // Can change as note is edited
  final String lineContent;
  final String taskContent;
  final bool isCompleted;
  final int indentLevel;
  String contentHash; // For detecting line changes
  final TaskPriority? priority;
  final DateTime? dueDate;
}

/// Task information extracted from a line
class TaskInfo {
  const TaskInfo({
    required this.content,
    required this.isCompleted,
    required this.indentLevel,
    this.priority,
    this.dueDate,
    this.embeddedId,
  });

  final String content;
  final bool isCompleted;
  final int indentLevel;
  final TaskPriority? priority;
  final DateTime? dueDate;
  final String? embeddedId; // Embedded task ID from note content
}
