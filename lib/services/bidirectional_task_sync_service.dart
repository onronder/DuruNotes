import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:intl/intl.dart';

/// Service that maintains bidirectional sync between notes and tasks
/// Ensures that changes in either direction are properly reflected
class BidirectionalTaskSyncService {
  BidirectionalTaskSyncService({
    required AppDb database,
    required TaskService taskService,
  }) : _db = database,
       _taskService = taskService;

  final AppDb _db;
  final TaskService _taskService;
  final AppLogger _logger = LoggerFactory.instance;
  
  // Track active sync operations to prevent loops
  final Set<String> _activeSyncOperations = {};
  
  // Cache for line mappings
  final Map<String, TaskLineMapping> _lineMappingCache = {};
  
  /// Initialize bidirectional sync for a note
  Future<void> initializeBidirectionalSync(String noteId) async {
    try {
      // Initial sync from note to tasks
      final note = await _db.getNote(noteId);
      if (note != null) {
        await syncFromNoteToTasks(noteId, note.body);
      }
      
      _logger.info('Initialized bidirectional sync for note', data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to initialize bidirectional sync', 
        error: e, 
        stackTrace: stack,
        data: {'noteId': noteId}
      );
    }
  }
  
  /// Sync changes from note content to task database
  Future<void> syncFromNoteToTasks(String noteId, String noteContent) async {
    // Prevent sync loops
    final syncKey = 'note_to_task_$noteId';
    if (_activeSyncOperations.contains(syncKey)) {
      return;
    }
    
    _activeSyncOperations.add(syncKey);
    try {
      // Parse tasks from note content with line tracking
      final taskMappings = _parseTasksWithLineTracking(noteId, noteContent);
      
      // Get existing tasks from database
      final existingTasks = await _db.getTasksForNote(noteId);
      final existingMap = {for (var task in existingTasks) task.id: task};
      
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
  List<TaskLineMapping> _parseTasksWithLineTracking(String noteId, String content) {
    final mappings = <TaskLineMapping>[];
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final taskInfo = _parseTaskLine(line);
      
      if (taskInfo != null) {
        // Generate stable task ID based on note ID and content hash
        final taskId = _generateStableTaskId(noteId, i, taskInfo.content);
        
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
    final content = match.group(3)!;
    
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
      if (taskInfo != null && _isSimilarContent(taskInfo.content, mapping.taskContent)) {
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
  
  /// Sync a single task from mapping
  Future<void> _syncTaskFromMapping(
    TaskLineMapping mapping,
    Map<String, NoteTask> existingTasks,
  ) async {
    final existingTask = existingTasks[mapping.taskId];
    
    if (existingTask != null) {
      // Update existing task if changed
      if (_hasTaskChanged(existingTask, mapping)) {
        await _taskService.updateTask(
          taskId: mapping.taskId,
          content: mapping.taskContent,
          status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
          priority: mapping.priority,
          dueDate: mapping.dueDate,
        );
      }
    } else {
      // Create new task
      await _taskService.createTask(
        noteId: mapping.noteId,
        content: mapping.taskContent,
        priority: mapping.priority ?? TaskPriority.medium,
        dueDate: mapping.dueDate,
      );
    }
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
    final priorityRegex = RegExp(r'#(urgent|high|medium|low)\b', caseSensitive: false);
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
        .replaceAll(RegExp(r'#(urgent|high|medium|low)\b', caseSensitive: false), '')
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
  Future<TaskLineMapping?> _getTaskLineMapping(String taskId, String noteId) async {
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
}

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
  });
  
  final String content;
  final bool isCompleted;
  final int indentLevel;
  final TaskPriority? priority;
  final DateTime? dueDate;
}
