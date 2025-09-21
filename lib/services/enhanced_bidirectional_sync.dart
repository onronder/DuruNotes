import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:intl/intl.dart';

/// Enhanced bidirectional sync that preserves task metadata
class EnhancedBidirectionalSync {
  EnhancedBidirectionalSync({
    required AppDb database,
    required TaskService taskService,
  })  : _db = database,
        _taskService = taskService;

  final AppDb _db;
  final TaskService _taskService;
  final AppLogger _logger = LoggerFactory.instance;

  // Track active sync operations to prevent loops
  final Set<String> _activeSyncOperations = {};

  // Cache for task mappings
  final Map<String, List<EnhancedTaskMapping>> _taskMappingCache = {};

  // Cache for embedded IDs
  final Map<String, Map<int, String>> _embeddedIdCache = {};

  /// Initialize sync for a note
  Future<void> initializeSync(String noteId) async {
    try {
      final note = await _db.getNote(noteId);
      if (note != null) {
        // First, embed task IDs if not present
        final updatedContent = await _embedTaskIds(noteId, note.body);

        if (updatedContent != note.body) {
          // Save the updated content with embedded IDs
          await _db.updateNote(
            noteId,
            LocalNotesCompanion(
              id: Value(noteId),
              body: Value(updatedContent),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        // Then sync tasks
        await syncFromNoteToTasks(noteId, updatedContent);

        _logger.info('Initialized enhanced sync for note', data: {
          'noteId': noteId,
          'embeddedIds': _embeddedIdCache[noteId]?.length ?? 0,
        });
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to initialize enhanced sync',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
    }
  }

  /// Embed task IDs in note content for stable tracking
  Future<String> _embedTaskIds(String noteId, String noteContent) async {
    final lines = noteContent.split('\n');
    final result = <String>[];
    final existingTasks = await _db.getTasksForNote(noteId);
    final tasksByContent = <String, NoteTask>{};

    // Build content map for existing tasks
    for (final task in existingTasks) {
      tasksByContent[task.content.toLowerCase().trim()] = task;
    }

    _embeddedIdCache[noteId] = {};

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Check if this is a task line
      final taskInfo = _parseTaskLine(line);
      if (taskInfo != null) {
        // Extract embedded ID if present
        String? embeddedId = _extractEmbeddedId(line);

        if (embeddedId == null) {
          // Try to find existing task by content
          final existingTask =
              tasksByContent[taskInfo.content.toLowerCase().trim()];

          if (existingTask != null) {
            // Use existing task ID
            embeddedId = existingTask.id;
          } else {
            // Generate new stable ID
            embeddedId = _generateStableTaskId(
              noteId: noteId,
              content: taskInfo.content,
              lineNumber: i,
            );
          }

          // Embed the ID in the line
          line = _embedIdInLine(line, embeddedId);
        }

        // Cache the embedded ID
        _embeddedIdCache[noteId]![i] = embeddedId;
      }

      result.add(line);
    }

    return result.join('\n');
  }

  /// Extract embedded task ID from a line
  String? _extractEmbeddedId(String line) {
    final idMatch = RegExp(r'<!-- task-id:([a-f0-9\-]+) -->').firstMatch(line);
    return idMatch?.group(1);
  }

  /// Embed task ID in a line
  String _embedIdInLine(String line, String taskId) {
    // Remove any existing ID first
    line = line.replaceAll(RegExp(r'\s*<!-- task-id:[a-f0-9\-]+ -->'), '');

    // Add the ID at the end of the line
    return '$line <!-- task-id:$taskId -->';
  }

  /// Parse task line and extract metadata
  TaskInfo? _parseTaskLine(String line) {
    // Remove embedded ID from parsing
    final cleanLine =
        line.replaceAll(RegExp(r'\s*<!-- task-id:[a-f0-9\-]+ -->'), '');

    // Match checkbox patterns
    final checkboxRegex = RegExp(r'^(\s*)- \[([ xX])\]\s+(.*)$');
    final match = checkboxRegex.firstMatch(cleanLine);

    if (match == null) return null;

    final indent = match.group(1)!;
    final isCompleted = match.group(2)!.toLowerCase() == 'x';
    var content = match.group(3)!;

    // Extract metadata
    TaskPriority? priority;
    DateTime? dueDate;

    // Extract priority
    final priorityMatch =
        RegExp(r'#(low|medium|high|urgent)').firstMatch(content);
    if (priorityMatch != null) {
      priority = _stringToPriority(priorityMatch.group(1)!);
      content = content.replaceAll(priorityMatch.group(0)!, '').trim();
    }

    // Extract due date
    final dateMatch = RegExp(r'@(\d{4}-\d{2}-\d{2})').firstMatch(content);
    if (dateMatch != null) {
      try {
        dueDate = DateFormat('yyyy-MM-dd').parse(dateMatch.group(1)!);
        content = content.replaceAll(dateMatch.group(0)!, '').trim();
      } catch (e) {
        // Invalid date format
      }
    }

    return TaskInfo(
      content: content,
      isCompleted: isCompleted,
      indentLevel: indent.length ~/ 2,
      priority: priority,
      dueDate: dueDate,
    );
  }

  /// Sync from note to tasks with metadata preservation
  Future<void> syncFromNoteToTasks(String noteId, String noteContent) async {
    final syncKey = 'note_to_task_$noteId';
    if (_activeSyncOperations.contains(syncKey)) return;

    final syncId = TaskSyncMetrics.instance.startSync(
      noteId: noteId,
      syncType: 'enhanced_note_to_tasks',
    );

    _activeSyncOperations.add(syncKey);

    try {
      // Parse tasks with enhanced mapping
      final mappings = _parseTasksWithEnhancedMapping(noteId, noteContent);

      // Get existing tasks
      final existingTasks = await _db.getTasksForNote(noteId);
      final existingMap = <String, NoteTask>{};
      for (final task in existingTasks) {
        existingMap[task.id] = task;
      }

      // Find best matches for each mapping
      for (final mapping in mappings) {
        final matchedTask = _findBestMatchingTask(
          mapping,
          existingMap,
          mappings,
        );

        if (matchedTask != null) {
          // Update existing task, preserving metadata
          await _updateTaskPreservingMetadata(matchedTask, mapping);
          existingMap.remove(matchedTask.id);
        } else {
          // Create new task
          await _createTaskFromMapping(mapping);
        }
      }

      // Delete tasks not in note
      for (final orphanTask in existingMap.values) {
        await _taskService.deleteTask(orphanTask.id);
      }

      // Update cache
      _taskMappingCache[noteId] = mappings;

      TaskSyncMetrics.instance.endSync(
        syncId: syncId,
        success: true,
        taskCount: mappings.length,
      );
    } catch (e, stack) {
      TaskSyncMetrics.instance.endSync(
        syncId: syncId,
        success: false,
        error: e.toString(),
      );

      _logger.error(
        'Enhanced sync failed',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      rethrow;
    } finally {
      _activeSyncOperations.remove(syncKey);
    }
  }

  /// Parse tasks with enhanced mapping
  List<EnhancedTaskMapping> _parseTasksWithEnhancedMapping(
    String noteId,
    String content,
  ) {
    final mappings = <EnhancedTaskMapping>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final taskInfo = _parseTaskLine(line);

      if (taskInfo != null) {
        // Extract embedded ID
        final embeddedId = _extractEmbeddedId(line) ??
            _generateStableTaskId(
              noteId: noteId,
              content: taskInfo.content,
              lineNumber: i,
            );

        mappings.add(EnhancedTaskMapping(
          taskId: embeddedId,
          noteId: noteId,
          lineNumber: i,
          content: taskInfo.content,
          isCompleted: taskInfo.isCompleted,
          priority: taskInfo.priority,
          dueDate: taskInfo.dueDate,
          indentLevel: taskInfo.indentLevel,
          originalLine: line,
        ));
      }
    }

    return mappings;
  }

  /// Find best matching task using multiple strategies
  NoteTask? _findBestMatchingTask(
    EnhancedTaskMapping mapping,
    Map<String, NoteTask> existingTasks,
    List<EnhancedTaskMapping> allMappings,
  ) {
    // 1. Try exact ID match
    if (existingTasks.containsKey(mapping.taskId)) {
      return existingTasks[mapping.taskId];
    }

    // 2. Try position + fuzzy content match
    final candidates = <NoteTask, double>{};

    for (final task in existingTasks.values) {
      // Skip if already matched to another mapping
      if (allMappings.any((m) => m.taskId == task.id && m != mapping)) {
        continue;
      }

      // Calculate similarity score
      double score = 0.0;

      // Position similarity (closer positions = higher score)
      final positionDiff = (task.position - mapping.lineNumber).abs();
      final positionScore = 1.0 / (1.0 + positionDiff);
      score += positionScore * 0.3; // 30% weight

      // Content similarity
      final contentScore = _calculateContentSimilarity(
        task.content,
        mapping.content,
      );
      score += contentScore * 0.7; // 70% weight

      if (score > 0.5) {
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

  /// Calculate content similarity using Levenshtein distance
  double _calculateContentSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Normalize strings
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);

    // Convert to similarity score (0-1)
    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    if (m == 0) return n;
    if (n == 0) return m;

    // Create distance matrix
    final List<List<int>> d = List.generate(
      m + 1,
      (i) => List.filled(n + 1, 0),
    );

    // Initialize first column and row
    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    // Calculate distances
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return d[m][n];
  }

  /// Update task preserving metadata
  Future<void> _updateTaskPreservingMetadata(
    NoteTask existingTask,
    EnhancedTaskMapping mapping,
  ) async {
    // Only update changed fields, preserve metadata
    await _taskService.updateTask(
      taskId: existingTask.id,
      content: mapping.content,
      status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
      priority: mapping.priority ?? existingTask.priority,
      dueDate: mapping.dueDate ?? existingTask.dueDate,
      // Preserve these fields
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
      'preserved': ['labels', 'notes', 'estimatedMinutes', 'reminderId'],
    });
  }

  /// Create new task from mapping
  Future<void> _createTaskFromMapping(EnhancedTaskMapping mapping) async {
    await _taskService.createTask(
      noteId: mapping.noteId,
      content: mapping.content,
      status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
      priority: mapping.priority ?? TaskPriority.medium,
      dueDate: mapping.dueDate,
      position: mapping.lineNumber,
    );
  }

  /// Generate stable task ID
  String _generateStableTaskId({
    required String noteId,
    required String content,
    required int lineNumber,
  }) {
    final input = '$noteId:$content:$lineNumber';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Convert string to priority
  TaskPriority _stringToPriority(String str) {
    switch (str.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }

  /// Clear cache for a note
  void clearCacheForNote(String noteId) {
    _taskMappingCache.remove(noteId);
    _embeddedIdCache.remove(noteId);
  }
}

/// Enhanced task mapping with metadata
class EnhancedTaskMapping {
  final String taskId;
  final String noteId;
  final int lineNumber;
  final String content;
  final bool isCompleted;
  final TaskPriority? priority;
  final DateTime? dueDate;
  final int indentLevel;
  final String originalLine;

  EnhancedTaskMapping({
    required this.taskId,
    required this.noteId,
    required this.lineNumber,
    required this.content,
    required this.isCompleted,
    this.priority,
    this.dueDate,
    required this.indentLevel,
    required this.originalLine,
  });
}

/// Task information parsed from line
class TaskInfo {
  final String content;
  final bool isCompleted;
  final int indentLevel;
  final TaskPriority? priority;
  final DateTime? dueDate;

  TaskInfo({
    required this.content,
    required this.isCompleted,
    required this.indentLevel,
    this.priority,
    this.dueDate,
  });
}
