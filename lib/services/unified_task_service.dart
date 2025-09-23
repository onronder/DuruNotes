import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';

/// Production-ready unified task service
/// Handles all task operations with the database NoteTask model
class UnifiedTaskService implements UnifiedTaskCallbacks {
  final AppDb _db;
  final AppLogger _logger;
  final AnalyticsService _analytics;
  final EnhancedTaskService _enhancedService;

  // Stream controllers for real-time updates
  final _taskUpdatesController = StreamController<TaskUpdate>.broadcast();
  Stream<TaskUpdate> get taskUpdates => _taskUpdatesController.stream;

  // ===== Bidirectional Sync Properties =====

  // Track active sync operations to prevent loops
  final Set<String> _activeSyncOperations = {};

  // Cache for line mappings
  final Map<String, TaskLineMapping> _lineMappingCache = {};

  // Pending changes queue for robust sync
  final Map<String, List<PendingChange>> _pendingChanges = {};
  Timer? _debounceTimer;

  // Track active note subscriptions
  final Map<String, StreamSubscription<LocalNote?>> _noteSubscriptions = {};

  // Debounce timers to avoid excessive syncing
  final Map<String, Timer?> _debounceTimers = {};

  // Track if a sync is in progress
  final Set<String> _syncInProgress = {};

  // Debounce delays
  static const _defaultDebounceDelay = Duration(milliseconds: 500);

  UnifiedTaskService({
    required AppDb db,
    required AppLogger logger,
    required AnalyticsService analytics,
    required EnhancedTaskService enhancedTaskService,
  })  : _db = db,
        _logger = logger,
        _analytics = analytics,
        _enhancedService = enhancedTaskService;

  // ===== CRUD Operations =====

  /// Create a new task
  Future<NoteTask> createTask({
    required String noteId,
    required String content,
    TaskStatus status = TaskStatus.open,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    List<String> labels = const [],
    String? notes,
    int? estimatedMinutes,
    bool createReminder = true,
  }) async {
    try {
      _analytics.startTiming('task_create');

      final taskId = await _enhancedService.createTask(
        noteId: noteId,
        content: content,
        status: status,
        priority: priority,
        dueDate: dueDate,
        parentTaskId: parentTaskId,
        labels: labels.isEmpty ? null : {'labels': labels},
        notes: notes,
        estimatedMinutes: estimatedMinutes,
        createReminder: createReminder,
      );

      final task = await _db.getTaskById(taskId);
      if (task == null) {
        throw StateError('Created task $taskId could not be loaded');
      }

      _analytics.endTiming('task_create', properties: {
        'success': true,
        'has_due_date': dueDate != null,
        'has_parent': parentTaskId != null,
        'priority': priority.name,
      });

      _analytics.event('task.created', properties: {
        'task_id': taskId,
        'note_id': noteId,
        'priority': priority.name,
      });

      _logger.info('Task created', data: {
        'task_id': taskId,
        'note_id': noteId,
      });

      // Notify listeners
      _taskUpdatesController.add(TaskUpdate(
        type: TaskUpdateType.created,
        task: task,
      ));

      return task;
    } catch (e, stack) {
      _logger.error('Failed to create task', error: e, stackTrace: stack);
      _analytics.endTiming('task_create', properties: {'success': false});
      rethrow;
    }
  }

  /// Get all tasks for a note
  Future<List<NoteTask>> getTasksForNote(String noteId) async {
    try {
      return await _db.getTasksForNote(noteId);
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks for note',
        error: e,
        stackTrace: stack,
        data: {'note_id': noteId},
      );
      return [];
    }
  }

  /// Get a specific task by ID
  Future<NoteTask?> getTask(String taskId) async {
    try {
      return await _db.getTaskById(taskId);
    } catch (e, stack) {
      _logger.error(
        'Failed to get task',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
      return null;
    }
  }

  /// Get subtasks for a parent task
  Future<List<NoteTask>> getSubtasks(String parentTaskId) async {
    try {
      return await (_db.select(_db.noteTasks)
            ..where((t) => t.parentTaskId.equals(parentTaskId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
    } catch (e, stack) {
      _logger.error(
        'Failed to get subtasks',
        error: e,
        stackTrace: stack,
        data: {'parent_task_id': parentTaskId},
      );
      return [];
    }
  }

  // ===== API Compatibility Methods =====

  /// Watch open tasks stream for UI compatibility
  Stream<List<NoteTask>> watchOpenTasks() {
    return (_db.select(_db.noteTasks)
          ..where((t) => t.status.equals(TaskStatus.open.index)))
        .watch();
  }

  /// Toggle task status for UI compatibility
  Future<void> toggleTaskStatus(String taskId) async {
    try {
      final task = await getTask(taskId);
      if (task != null) {
        final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.open
          : TaskStatus.completed;
        await onStatusChanged(taskId, newStatus);
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to toggle task status',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
      rethrow;
    }
  }

  /// Delete task for UI compatibility
  Future<void> deleteTask(String taskId) async {
    await onDeleted(taskId);
  }

  /// Get tasks by date range for UI compatibility
  Future<List<NoteTask>> getTasksByDateRange(DateTime start, DateTime end) async {
    try {
      return await (_db.select(_db.noteTasks)
            ..where((t) =>
                t.dueDate.isBiggerOrEqualValue(start) &
                t.dueDate.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks by date range',
        error: e,
        stackTrace: stack,
        data: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );
      return [];
    }
  }

  // ===== UnifiedTaskCallbacks Implementation =====

  @override
  Future<void> onStatusChanged(String taskId, TaskStatus newStatus) async {
    try {
      _analytics.startTiming('task_status_change');

      final oldTask = await getTask(taskId);
      if (oldTask == null) {
        _logger.warning('Task not found for status change',
            data: {'task_id': taskId});
        return;
      }

      await _enhancedService.updateTask(
        taskId: taskId,
        status: newStatus,
      );

      // Handle subtasks if completing parent
      if (newStatus == TaskStatus.completed) {
        await _completeSubtasks(taskId);
      }

      _analytics.endTiming('task_status_change', properties: {
        'success': true,
        'old_status': oldTask.status.name,
        'new_status': newStatus.name,
      });

      _analytics.event('task.status_changed', properties: {
        'task_id': taskId,
        'old_status': oldTask.status.name,
        'new_status': newStatus.name,
      });

      _logger.info('Task status changed', data: {
        'task_id': taskId,
        'old_status': oldTask.status.name,
        'new_status': newStatus.name,
      });

      // Notify listeners
      final updatedTask = await getTask(taskId);
      if (updatedTask != null) {
        _taskUpdatesController.add(TaskUpdate(
          type: TaskUpdateType.statusChanged,
          task: updatedTask,
          oldStatus: oldTask.status,
          newStatus: newStatus,
        ));
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to change task status',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId, 'new_status': newStatus.name},
      );
      _analytics
          .endTiming('task_status_change', properties: {'success': false});
    }
  }

  @override
  Future<void> onPriorityChanged(
      String taskId, TaskPriority newPriority) async {
    try {
      await _enhancedService.updateTask(
        taskId: taskId,
        priority: newPriority,
      );

      _analytics.event('task.priority_changed', properties: {
        'task_id': taskId,
        'new_priority': newPriority.name,
      });

      _logger.info('Task priority changed', data: {
        'task_id': taskId,
        'new_priority': newPriority.name,
      });

      // Notify listeners
      final updatedTask = await getTask(taskId);
      if (updatedTask != null) {
        _taskUpdatesController.add(TaskUpdate(
          type: TaskUpdateType.priorityChanged,
          task: updatedTask,
        ));
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to change task priority',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId, 'new_priority': newPriority.name},
      );
    }
  }

  @override
  Future<void> onContentChanged(String taskId, String newContent) async {
    try {
      await _enhancedService.updateTask(
        taskId: taskId,
        content: newContent,
      );

      _analytics.event('task.content_changed', properties: {
        'task_id': taskId,
        'content_length': newContent.length,
      });

      _logger.info('Task content changed', data: {
        'task_id': taskId,
        'content_length': newContent.length,
      });

      // Notify listeners
      final updatedTask = await getTask(taskId);
      if (updatedTask != null) {
        _taskUpdatesController.add(TaskUpdate(
          type: TaskUpdateType.contentChanged,
          task: updatedTask,
        ));
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to change task content',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
    }
  }

  @override
  Future<void> onDeleted(String taskId) async {
    try {
      _analytics.startTiming('task_delete');

      // Delete subtasks first
      await _deleteSubtasks(taskId);

      // Delete the task through the enhanced service to ensure reminders and
      // sync hooks are handled correctly
      await _enhancedService.deleteTask(taskId);

      _analytics.endTiming('task_delete', properties: {'success': true});

      _analytics.event('task.deleted', properties: {
        'task_id': taskId,
      });

      _logger.info('Task deleted', data: {
        'task_id': taskId,
      });

      // Notify listeners
      _taskUpdatesController.add(TaskUpdate(
        type: TaskUpdateType.deleted,
        taskId: taskId,
      ));
    } catch (e, stack) {
      _logger.error(
        'Failed to delete task',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
      _analytics.endTiming('task_delete', properties: {'success': false});
    }
  }

  @override
  void onEdit(String taskId) {
    // This would typically open an edit dialog
    // Implementation depends on UI framework
    _logger.info('Task edit requested', data: {'task_id': taskId});

    _taskUpdatesController.add(TaskUpdate(
      type: TaskUpdateType.editRequested,
      taskId: taskId,
    ));
  }

  @override
  Future<void> onDueDateChanged(String taskId, DateTime? newDate) async {
    try {
      await _enhancedService.updateTask(
        taskId: taskId,
        dueDate: newDate,
      );

      _analytics.event('task.due_date_changed', properties: {
        'task_id': taskId,
        'has_due_date': newDate != null,
      });

      _logger.info('Task due date changed', data: {
        'task_id': taskId,
        'due_date': newDate?.toIso8601String(),
      });

      // Notify listeners
      final updatedTask = await getTask(taskId);
      if (updatedTask != null) {
        _taskUpdatesController.add(TaskUpdate(
          type: TaskUpdateType.dueDateChanged,
          task: updatedTask,
        ));
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to change task due date',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
    }
  }

  /// General task update helper for multi-field updates
  Future<void> updateTask({
    required String taskId,
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    List<String>? labels,
    String? notes,
    int? estimatedMinutes,
    int? actualMinutes,
    int? reminderId,
    String? parentTaskId,
    bool clearReminderId = false,
  }) async {
    try {
      await _enhancedService.updateTask(
        taskId: taskId,
        content: content,
        status: status,
        priority: priority,
        dueDate: dueDate,
        labels: labels != null ? {'labels': labels} : null,
        notes: notes,
        estimatedMinutes: estimatedMinutes,
        actualMinutes: actualMinutes,
        reminderId: reminderId,
        parentTaskId: parentTaskId,
        clearReminderId: clearReminderId,
      );

      final updatedTask = await getTask(taskId);
      if (updatedTask != null) {
        _taskUpdatesController.add(TaskUpdate(
          type: TaskUpdateType.metadataChanged,
          task: updatedTask,
        ));
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to update task',
        error: e,
        stackTrace: stack,
        data: {'task_id': taskId},
      );
      rethrow;
    }
  }

  // ===== Helper Methods =====

  Future<void> _completeSubtasks(String parentTaskId) async {
    final subtasks = await getSubtasks(parentTaskId);
    for (final subtask in subtasks) {
      if (subtask.status != TaskStatus.completed) {
        await onStatusChanged(subtask.id, TaskStatus.completed);
      }
    }
  }

  Future<void> _deleteSubtasks(String parentTaskId) async {
    final subtasks = await getSubtasks(parentTaskId);
    for (final subtask in subtasks) {
      await onDeleted(subtask.id);
    }
  }

  /// Batch update multiple tasks
  Future<void> batchUpdateStatus(
      List<String> taskIds, TaskStatus newStatus) async {
    try {
      _analytics.startTiming('task_batch_update');

      await _db.transaction(() async {
        for (final taskId in taskIds) {
          await onStatusChanged(taskId, newStatus);
        }
      });

      _analytics.endTiming('task_batch_update', properties: {
        'success': true,
        'count': taskIds.length,
        'new_status': newStatus.name,
      });

      _logger.info('Batch task update completed', data: {
        'count': taskIds.length,
        'new_status': newStatus.name,
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to batch update tasks',
        error: e,
        stackTrace: stack,
        data: {'count': taskIds.length},
      );
      _analytics.endTiming('task_batch_update', properties: {'success': false});
      rethrow;
    }
  }

  /// Search tasks by content
  Future<List<NoteTask>> searchTasks(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      return await (_db.select(_db.noteTasks)
            ..where((t) => t.content.lower().contains(lowerQuery)))
          .get();
    } catch (e, stack) {
      _logger.error(
        'Failed to search tasks',
        error: e,
        stackTrace: stack,
        data: {'query': query},
      );
      return [];
    }
  }

  /// Get open (incomplete) tasks
  Future<List<NoteTask>> getOpenTasks({
    DateTime? dueBefore,
    TaskPriority? priority,
    String? parentTaskId,
  }) async {
    try {
      var query = _db.select(_db.noteTasks)
        ..where((t) => t.status.equals(TaskStatus.open.index));

      if (dueBefore != null) {
        query = query..where((t) => t.dueDate.isSmallerThanValue(dueBefore));
      }
      if (priority != null) {
        query = query..where((t) => t.priority.equals(priority.index));
      }
      if (parentTaskId != null) {
        query = query..where((t) => t.parentTaskId.equals(parentTaskId));
      }

      return await query.get();
    } catch (e, stack) {
      _logger.error('Failed to get open tasks', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get overdue tasks
  Future<List<NoteTask>> getOverdueTasks() async {
    try {
      final now = DateTime.now();
      return await (_db.select(_db.noteTasks)
            ..where((t) =>
                t.dueDate.isSmallerThanValue(now) &
                t.status.equals(TaskStatus.open.index)))
          .get();
    } catch (e, stack) {
      _logger.error('Failed to get overdue tasks', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get task statistics
  Future<TaskStatistics> getTaskStatistics() async {
    try {
      final allTasks = await (_db.select(_db.noteTasks)).get();

      final total = allTasks.length;
      final completed =
          allTasks.where((t) => t.status == TaskStatus.completed).length;
      final open = allTasks.where((t) => t.status == TaskStatus.open).length;
      final cancelled =
          allTasks.where((t) => t.status == TaskStatus.cancelled).length;

      final overdue = await getOverdueTasks();

      final byPriority = <TaskPriority, int>{};
      for (final priority in TaskPriority.values) {
        byPriority[priority] =
            allTasks.where((t) => t.priority == priority).length;
      }

      return TaskStatistics(
        total: total,
        completed: completed,
        open: open,
        cancelled: cancelled,
        overdue: overdue.length,
        byPriority: byPriority,
        completionRate: total > 0 ? (completed / total * 100) : 0,
      );
    } catch (e, stack) {
      _logger.error('Failed to get task statistics',
          error: e, stackTrace: stack);
      return TaskStatistics.empty();
    }
  }

  // ===== Bidirectional Sync Methods =====

  /// Initialize bidirectional sync for a note
  Future<void> initializeBidirectionalSync(String noteId) async {
    try {
      // Perform initial sync from note to tasks
      final note = await _db.getNote(noteId);
      if (note != null) {
        // This creates any missing tasks with stable IDs based on content hash
        await syncFromNoteToTasks(noteId, note.body);

        // Count tasks for logging
        final taskCount = await getTasksForNote(noteId).then((tasks) => tasks.length);

        _logger.info('Initialized bidirectional sync for note', data: {
          'noteId': noteId,
          'taskCount': taskCount,
          'hasCheckboxes': note.body.contains('- [ ]') || note.body.contains('- [x]'),
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
        'hasCheckboxes': noteContent.contains('- [ ]') || noteContent.contains('- [x]'),
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
      final existingTasks = await getTasksForNote(noteId);
      final existingMap = {for (var task in existingTasks) task.id: task};

      // Process each parsed task
      for (final mapping in taskMappings) {
        try {
          // Check if task already exists
          final existingTask = existingMap[mapping.taskId];

          if (existingTask != null) {
            // Update existing task if content or status changed
            if (existingTask.content != mapping.content ||
                existingTask.status != (mapping.isCompleted ? TaskStatus.completed : TaskStatus.open)) {
              await updateTask(
                taskId: mapping.taskId,
                content: mapping.content,
                status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
              );
            }
          } else {
            // Create new task with explicit ID for consistency
            final newTask = NoteTask(
              id: mapping.taskId,
              noteId: noteId,
              content: mapping.content,
              contentHash: _generateStableTaskId(noteId, mapping.content, mapping.lineIndex),
              status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
              priority: TaskPriority.medium,
              position: mapping.position,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              dueDate: null,
              completedAt: mapping.isCompleted ? DateTime.now() : null,
              completedBy: null,
              reminderId: null,
              labels: null,
              notes: null,
              estimatedMinutes: null,
              actualMinutes: null,
              parentTaskId: null,
            );

            // Use database directly for sync operations to avoid circular calls
            await _db.createTask(NoteTasksCompanion.insert(
              id: newTask.id,
              noteId: newTask.noteId,
              content: newTask.content,
              contentHash: newTask.contentHash,
              status: Value(newTask.status),
              priority: Value(newTask.priority),
              position: Value(newTask.position),
              createdAt: Value(newTask.createdAt),
              updatedAt: Value(newTask.updatedAt),
              deleted: Value(newTask.deleted),
            ));
          }

          // Cache the line mapping
          _lineMappingCache[mapping.taskId] = mapping;
        } catch (e) {
          _logger.warning('Failed to sync individual task',
              data: {'taskId': mapping.taskId, 'error': e.toString()});
        }
      }

      // Remove tasks that no longer exist in note content
      final currentTaskIds = taskMappings.map((m) => m.taskId).toSet();
      for (final existingTask in existingTasks) {
        if (!currentTaskIds.contains(existingTask.id)) {
          await onDeleted(existingTask.id);
        }
      }

      TaskSyncMetrics.instance.endSync(
        syncId: syncId,
        success: true,
        taskCount: taskCount,
        duplicatesFound: duplicatesFound,
      );

      _logger.debug('Sync from note to tasks completed', data: {
        'noteId': noteId,
        'taskCount': taskCount,
        'duplicatesFound': duplicatesFound,
      });
    } catch (e, stack) {
      TaskSyncMetrics.instance.endSync(syncId: syncId, success: false, error: e.toString());
      _logger.error('Failed to sync from note to tasks',
          error: e, stackTrace: stack, data: {'noteId': noteId});
      rethrow;
    } finally {
      _activeSyncOperations.remove(syncKey);
    }
  }

  /// Parse tasks from note content with line tracking
  List<TaskLineMapping> _parseTasksWithLineTracking(String noteId, String content) {
    final tasks = <TaskLineMapping>[];
    final lines = content.split('\n');
    var position = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('- [ ]') || trimmedLine.startsWith('- [x]')) {
        final isCompleted = trimmedLine.startsWith('- [x]');
        final taskContent = trimmedLine.substring(5).trim();

        if (taskContent.isNotEmpty) {
          // Generate stable task ID based on content hash
          final taskId = _generateStableTaskId(noteId, taskContent, lineIndex);

          tasks.add(TaskLineMapping(
            taskId: taskId,
            noteId: noteId,
            content: taskContent,
            isCompleted: isCompleted,
            lineIndex: lineIndex,
            position: position,
            originalLine: line,
          ));

          position++;
        }
      }
    }

    return tasks;
  }

  /// Generate stable task ID based on content hash
  String _generateStableTaskId(String noteId, String content, int lineIndex) {
    final input = '$noteId:$content:$lineIndex';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return 'task_${digest.toString().substring(0, 16)}';
  }

  /// Start watching a note for changes and sync tasks
  Future<void> startWatchingNote(String noteId) async {
    try {
      // Cancel any existing subscription
      await stopWatchingNote(noteId);

      // Initialize bidirectional sync
      await initializeBidirectionalSync(noteId);

      // Watch for note changes
      _noteSubscriptions[noteId] = _db.watchNote(noteId).listen((note) {
        if (note != null) {
          _handleNoteChange(noteId, note.body);
        }
      });

      _logger.info('Started watching note for task sync', data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to start watching note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Stop watching a note with final sync
  Future<void> stopWatchingNote(String noteId) async {
    try {
      // Force immediate sync of any pending changes
      await _forceSyncPendingChanges(noteId);

      // Cancel subscription
      await _noteSubscriptions[noteId]?.cancel();
      _noteSubscriptions.remove(noteId);

      // Cancel any pending debounce timer
      _debounceTimers[noteId]?.cancel();
      _debounceTimers.remove(noteId);

      // Clear pending changes
      _pendingChanges.remove(noteId);
      _syncInProgress.remove(noteId);

      // Clear cache for this note
      clearCacheForNote(noteId);

      _logger.debug('Stopped watching note', data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to stop watching note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Handle note content changes with debouncing
  void _handleNoteChange(String noteId, String newContent) {
    // Skip if sync is already in progress
    if (_syncInProgress.contains(noteId)) {
      // Add to pending changes even during sync for later processing
      _pendingChanges.putIfAbsent(noteId, () => []).add(
        PendingChange(
          type: ChangeType.content,
          content: newContent,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // Add to pending changes
    _pendingChanges.putIfAbsent(noteId, () => []).add(
      PendingChange(
        type: ChangeType.content,
        content: newContent,
        timestamp: DateTime.now(),
      ),
    );

    // Cancel existing timer
    _debounceTimers[noteId]?.cancel();

    // Start new debounce timer with exponential backoff for frequent changes
    final changeCount = _pendingChanges[noteId]?.length ?? 0;
    final debounceDelay = changeCount > 5
        ? Duration(milliseconds: 1000) // Longer delay for rapid changes
        : _defaultDebounceDelay;

    _debounceTimers[noteId] = Timer(debounceDelay, () {
      _processPendingChanges(noteId);
    });
  }

  /// Process pending changes for a note
  Future<void> _processPendingChanges(String noteId) async {
    final changes = _pendingChanges[noteId];
    if (changes == null || changes.isEmpty) {
      return;
    }

    // Mark sync in progress
    _syncInProgress.add(noteId);

    try {
      // Get the latest content from the most recent change
      final latestChange = changes.last;

      // Sync the latest content
      await syncFromNoteToTasks(noteId, latestChange.content);

      // Clear processed changes
      _pendingChanges[noteId]?.clear();
    } catch (e, stack) {
      _logger.error('Failed to process pending changes',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    } finally {
      _syncInProgress.remove(noteId);

      // Process any additional changes that arrived during sync
      if (_pendingChanges[noteId]?.isNotEmpty == true) {
        // Schedule another processing cycle for remaining changes
        Timer(_defaultDebounceDelay, () {
          _processPendingChanges(noteId);
        });
      }
    }
  }

  /// Force immediate sync of pending changes
  Future<void> _forceSyncPendingChanges(String noteId) async {
    // Cancel any pending timer
    _debounceTimers[noteId]?.cancel();
    _debounceTimers.remove(noteId);

    // Process changes immediately
    await _processPendingChanges(noteId);
  }

  /// Clear cache for a specific note
  void clearCacheForNote(String noteId) {
    _lineMappingCache.removeWhere((key, value) => value.noteId == noteId);
  }

  // ===== Hierarchical Task Methods =====

  /// Sync tasks for note with hierarchical support
  Future<void> syncHierarchicalTasksForNote(String noteId, String noteContent) async {
    try {
      final hierarchicalTasks = extractHierarchicalTasksFromContent(noteContent);
      await _syncHierarchicalTasks(noteId, hierarchicalTasks);
    } catch (e, stack) {
      _logger.error('Error syncing hierarchical tasks for note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Extract hierarchical tasks from markdown content with indentation support
  List<HierarchicalTaskInfo> extractHierarchicalTasksFromContent(String content) {
    final tasks = <HierarchicalTaskInfo>[];
    final lines = content.split('\n');
    final taskStack = <HierarchicalTaskInfo>[]; // Stack to track parent tasks
    var globalPosition = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final indentLevel = _getIndentLevel(line);
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('- [ ]') || trimmedLine.startsWith('- [x]')) {
        final isCompleted = trimmedLine.startsWith('- [x]');
        final taskContent = trimmedLine.substring(5).trim();

        if (taskContent.isNotEmpty) {
          // Parse metadata (due date, priority)
          final parsedTask = _parseTaskMetadata(taskContent);

          // Determine parent task based on indentation
          String? parentTaskId;

          // Pop stack until we find the appropriate parent level
          while (taskStack.isNotEmpty &&
              taskStack.last.indentLevel >= indentLevel) {
            taskStack.removeLast();
          }

          // If there's a task in the stack, it's our parent
          if (taskStack.isNotEmpty) {
            parentTaskId = taskStack.last.id;
          }

          final taskInfo = HierarchicalTaskInfo(
            id: _generateTaskId('temp', globalPosition), // Will be replaced with actual ID
            content: parsedTask.content,
            isCompleted: isCompleted,
            position: globalPosition,
            lineIndex: lineIndex,
            indentLevel: indentLevel,
            parentTaskId: parentTaskId,
            dueDate: parsedTask.dueDate,
            priority: parsedTask.priority,
            children: [],
          );

          // Add to parent's children if applicable
          if (taskStack.isNotEmpty) {
            taskStack.last.children.add(taskInfo);
          }

          // Add to main list
          tasks.add(taskInfo);

          // Push to stack for potential children
          taskStack.add(taskInfo);

          globalPosition++;
        }
      }
    }

    return tasks;
  }

  /// Get indentation level from line (spaces and tabs)
  int _getIndentLevel(String line) {
    var indent = 0;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        indent++;
      } else if (line[i] == '\t') {
        indent += 4; // Tab counts as 4 spaces
      } else {
        break;
      }
    }
    return indent;
  }

  /// Parse task metadata from content (due date, priority, etc.)
  ParsedTaskMetadata _parseTaskMetadata(String content) {
    var cleanContent = content;
    DateTime? dueDate;
    TaskPriority priority = TaskPriority.medium;

    // Parse due date patterns: @due(YYYY-MM-DD) or @YYYY-MM-DD
    final dueDateRegex = RegExp(r'@(?:due\()?(\d{4}-\d{2}-\d{2})\)?');
    final dueDateMatch = dueDateRegex.firstMatch(content);
    if (dueDateMatch != null) {
      try {
        dueDate = DateTime.parse(dueDateMatch.group(1)!);
        cleanContent = cleanContent.replaceAll(dueDateMatch.group(0)!, '').trim();
      } catch (e) {
        _logger.warning('Failed to parse due date', data: {'content': content});
      }
    }

    // Parse priority patterns: !high, !medium, !low, !urgent
    final priorityRegex = RegExp(r'!(high|medium|low|urgent)');
    final priorityMatch = priorityRegex.firstMatch(content);
    if (priorityMatch != null) {
      final priorityStr = priorityMatch.group(1)!.toLowerCase();
      switch (priorityStr) {
        case 'urgent':
          priority = TaskPriority.urgent;
          break;
        case 'high':
          priority = TaskPriority.high;
          break;
        case 'medium':
          priority = TaskPriority.medium;
          break;
        case 'low':
          priority = TaskPriority.low;
          break;
      }
      cleanContent = cleanContent.replaceAll(priorityMatch.group(0)!, '').trim();
    }

    return ParsedTaskMetadata(
      content: cleanContent,
      dueDate: dueDate,
      priority: priority,
    );
  }

  /// Sync hierarchical tasks to database
  Future<void> _syncHierarchicalTasks(String noteId, List<HierarchicalTaskInfo> hierarchicalTasks) async {
    final syncer = HierarchicalTaskSyncer(
      db: _db,
      enhancedTaskService: _enhancedService,
      logger: _logger,
    );

    await syncer.syncTasks(noteId, hierarchicalTasks);
  }

  /// Generate task ID for hierarchical tasks
  String _generateTaskId(String prefix, int position) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${timestamp}_$position';
  }

  void dispose() {
    // Clean up task updates
    _taskUpdatesController.close();

    // Clean up sync resources
    _debounceTimer?.cancel();
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();

    // Cancel all note subscriptions
    for (final subscription in _noteSubscriptions.values) {
      subscription.cancel();
    }
    _noteSubscriptions.clear();

    // Clear sync state
    _activeSyncOperations.clear();
    _lineMappingCache.clear();
    _pendingChanges.clear();
    _syncInProgress.clear();
  }

  // ===== Hierarchical Task Methods for UI Compatibility =====

  /// Get task hierarchy for a note or all notes
  Future<List<TaskHierarchyNode>> getTaskHierarchy(String noteIdOrAll) async {
    try {
      final tasks = noteIdOrAll == 'all'
          ? await _db.getAllTasks()
          : await getTasksForNote(noteIdOrAll);

      // Build hierarchy from flat list
      return _buildTaskHierarchy(tasks);
    } catch (e) {
      _logger.error('[UnifiedTaskService] Failed to get task hierarchy',
          error: e);
      return [];
    }
  }

  /// Build task hierarchy from flat list
  List<TaskHierarchyNode> _buildTaskHierarchy(List<NoteTask> tasks) {
    final nodeMap = <String, TaskHierarchyNode>{};
    final rootNodes = <TaskHierarchyNode>[];

    // First pass: create all nodes
    for (final task in tasks) {
      nodeMap[task.id] = TaskHierarchyNode(
        task: task,
        children: [],
      );
    }

    // Second pass: build hierarchy
    for (final task in tasks) {
      final node = nodeMap[task.id]!;

      if (task.parentTaskId != null && nodeMap.containsKey(task.parentTaskId)) {
        final parent = nodeMap[task.parentTaskId]!;
        parent.children.add(node);
        node.parent = parent;
      } else {
        rootNodes.add(node);
      }
    }

    return rootNodes;
  }

  /// Check if a task has subtasks
  Future<bool> hasSubtasks(String taskId) async {
    try {
      final subtasks = await getSubtasks(taskId);
      return subtasks.isNotEmpty;
    } catch (e) {
      _logger.error('[UnifiedTaskService] Failed to check subtasks', error: e);
      return false;
    }
  }

  /// Calculate task progress for a hierarchy node
  TaskProgress calculateTaskProgress(TaskHierarchyNode node) {
    int totalTasks = 1; // Count self
    int completedTasks = node.task.status == TaskStatus.completed ? 1 : 0;
    int totalEstimated = 0;
    int totalActual = 0;

    // Recursively count children
    void countTasks(TaskHierarchyNode current) {
      for (final child in current.children) {
        totalTasks++;
        if (child.task.status == TaskStatus.completed) {
          completedTasks++;
        }
        countTasks(child);
      }
    }

    countTasks(node);

    final percentage = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;

    return TaskProgress(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      progressPercentage: percentage,
      totalEstimatedMinutes: totalEstimated,
      totalActualMinutes: totalActual,
    );
  }

  /// Get hierarchy statistics for a note
  Future<TaskHierarchyStats> getHierarchyStats(String noteId) async {
    try {
      final hierarchy = await getTaskHierarchy(noteId);

      int totalTasks = 0;
      int rootTasks = hierarchy.length;
      int completedTasks = 0;
      int maxDepth = 0;

      void countStats(TaskHierarchyNode node, int depth) {
        totalTasks++;
        if (node.task.status == TaskStatus.completed) {
          completedTasks++;
        }
        maxDepth = depth > maxDepth ? depth : maxDepth;

        for (final child in node.children) {
          countStats(child, depth + 1);
        }
      }

      for (final root in hierarchy) {
        countStats(root, 0);
      }

      return TaskHierarchyStats(
        totalTasks: totalTasks,
        rootTasks: rootTasks,
        subtasks: totalTasks - rootTasks,
        maxDepth: maxDepth,
        completedTasks: completedTasks,
      );
    } catch (e) {
      _logger.error('[UnifiedTaskService] Failed to get hierarchy stats', error: e);
      return const TaskHierarchyStats(
        totalTasks: 0,
        rootTasks: 0,
        subtasks: 0,
        maxDepth: 0,
        completedTasks: 0,
      );
    }
  }

  /// Complete all subtasks of a parent task
  Future<void> completeAllSubtasks(String parentTaskId) async {
    try {
      final subtasks = await getSubtasks(parentTaskId);

      for (final subtask in subtasks) {
        await onStatusChanged(subtask.id, TaskStatus.completed);
        // Recursively complete children
        await completeAllSubtasks(subtask.id);
      }

      _logger.info('[UnifiedTaskService] Completed all subtasks',
          data: {'parentId': parentTaskId, 'count': subtasks.length});
    } catch (e) {
      _logger.error('[UnifiedTaskService] Failed to complete subtasks', error: e);
      throw e;
    }
  }

  /// Delete task hierarchy (task and all its subtasks)
  Future<void> deleteTaskHierarchy(String taskId) async {
    try {
      // Get all descendants first
      final subtasks = await getSubtasks(taskId);

      // Delete children recursively
      for (final subtask in subtasks) {
        await deleteTaskHierarchy(subtask.id);
      }

      // Finally delete the task itself
      await onDeleted(taskId);

      _logger.info('[UnifiedTaskService] Deleted task hierarchy',
          data: {'taskId': taskId});
    } catch (e) {
      _logger.error('[UnifiedTaskService] Failed to delete hierarchy', error: e);
      throw e;
    }
  }

  /// Watch tasks for a specific note (stream)
  Stream<List<NoteTask>> watchTasksForNote(String noteId) {
    // Use database stream for real-time updates instead of polling
    return _db.watchTasksForNote(noteId);
  }
}

// ===== Supporting Classes =====

/// Type of change being tracked for sync
enum ChangeType { content, toggle, create, delete }

/// Represents a pending change to be synced
class PendingChange {
  final ChangeType type;
  final String content;
  final DateTime timestamp;
  final bool isCritical;
  final String? taskId;
  final bool? isCompleted;

  PendingChange({
    required this.type,
    required this.content,
    required this.timestamp,
    this.isCritical = false,
    this.taskId,
    this.isCompleted,
  });
}

/// Maps task to its line position in note content
class TaskLineMapping {
  final String taskId;
  final String noteId;
  final String content;
  final bool isCompleted;
  final int lineIndex;
  final int position;
  final String originalLine;

  TaskLineMapping({
    required this.taskId,
    required this.noteId,
    required this.content,
    required this.isCompleted,
    required this.lineIndex,
    required this.position,
    required this.originalLine,
  });
}

/// Represents a hierarchical task with parent-child relationships
class HierarchicalTaskInfo {
  final String id;
  final String content;
  final bool isCompleted;
  final int position;
  final int lineIndex;
  final int indentLevel;
  final String? parentTaskId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<HierarchicalTaskInfo> children;

  HierarchicalTaskInfo({
    required this.id,
    required this.content,
    required this.isCompleted,
    required this.position,
    required this.lineIndex,
    required this.indentLevel,
    this.parentTaskId,
    this.dueDate,
    this.priority = TaskPriority.medium,
    required this.children,
  });
}

/// Parsed task metadata
class ParsedTaskMetadata {
  final String content;
  final DateTime? dueDate;
  final TaskPriority priority;

  ParsedTaskMetadata({
    required this.content,
    this.dueDate,
    this.priority = TaskPriority.medium,
  });
}

/// Handles syncing hierarchical tasks to database
class HierarchicalTaskSyncer {
  final AppDb db;
  final EnhancedTaskService enhancedTaskService;
  final AppLogger logger;

  HierarchicalTaskSyncer({
    required this.db,
    required this.enhancedTaskService,
    required this.logger,
  });

  Future<void> syncTasks(String noteId, List<HierarchicalTaskInfo> tasks) async {
    try {
      // Process tasks in order, maintaining parent-child relationships
      final taskIdMap = <String, String>{}; // temp ID -> real ID

      for (final taskInfo in tasks) {
        // Get real parent ID if exists
        String? realParentId;
        if (taskInfo.parentTaskId != null) {
          realParentId = taskIdMap[taskInfo.parentTaskId];
        }

        // Create or update task
        final realTaskId = await enhancedTaskService.createTask(
          noteId: noteId,
          content: taskInfo.content,
          status: taskInfo.isCompleted ? TaskStatus.completed : TaskStatus.open,
          priority: taskInfo.priority,
          dueDate: taskInfo.dueDate,
          parentTaskId: realParentId,
          position: taskInfo.position,
        );

        // Map temp ID to real ID
        taskIdMap[taskInfo.id] = realTaskId;

        logger.debug('Synced hierarchical task', data: {
          'tempId': taskInfo.id,
          'realId': realTaskId,
          'parentId': realParentId,
          'indentLevel': taskInfo.indentLevel,
        });
      }
    } catch (e, stack) {
      logger.error('Failed to sync hierarchical tasks',
          error: e, stackTrace: stack, data: {'noteId': noteId});
      rethrow;
    }
  }
}

/// Task update event for real-time notifications
class TaskUpdate {
  final TaskUpdateType type;
  final NoteTask? task;
  final String? taskId;
  final TaskStatus? oldStatus;
  final TaskStatus? newStatus;

  TaskUpdate({
    required this.type,
    this.task,
    this.taskId,
    this.oldStatus,
    this.newStatus,
  });
}

enum TaskUpdateType {
  created,
  statusChanged,
  priorityChanged,
  contentChanged,
  dueDateChanged,
  metadataChanged,
  deleted,
  editRequested,
}

/// Task statistics
class TaskStatistics {
  final int total;
  final int completed;
  final int open;
  final int cancelled;
  final int overdue;
  final Map<TaskPriority, int> byPriority;
  final double completionRate;

  const TaskStatistics({
    required this.total,
    required this.completed,
    required this.open,
    required this.cancelled,
    required this.overdue,
    required this.byPriority,
    required this.completionRate,
  });

  factory TaskStatistics.empty() => TaskStatistics(
        total: 0,
        completed: 0,
        open: 0,
        cancelled: 0,
        overdue: 0,
        byPriority: {},
        completionRate: 0,
      );
}

// ===== Task Hierarchy Models =====

/// Task hierarchy node for tree operations
class TaskHierarchyNode {
  TaskHierarchyNode({
    required this.task,
    required this.children,
    this.parent,
  });

  final NoteTask task;
  final List<TaskHierarchyNode> children;
  TaskHierarchyNode? parent;

  /// Get all descendants (children, grandchildren, etc.)
  List<TaskHierarchyNode> getAllDescendants() {
    final descendants = <TaskHierarchyNode>[];
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants());
    }
    return descendants;
  }

  /// Check if this node is an ancestor of another node
  bool isAncestorOf(TaskHierarchyNode other) {
    TaskHierarchyNode? current = other.parent;
    while (current != null) {
      if (current.task.id == task.id) return true;
      current = current.parent;
    }
    return false;
  }

  /// Get path from root to this node
  List<TaskHierarchyNode> getPathFromRoot() {
    final path = <TaskHierarchyNode>[];
    TaskHierarchyNode? current = this;

    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }

    return path;
  }
}

/// Task progress information
class TaskProgress {
  const TaskProgress({
    required this.totalTasks,
    required this.completedTasks,
    required this.progressPercentage,
    required this.totalEstimatedMinutes,
    required this.totalActualMinutes,
  });

  final int totalTasks;
  final int completedTasks;
  final double progressPercentage;
  final int totalEstimatedMinutes;
  final int totalActualMinutes;

  /// Check if all tasks are completed
  bool get isFullyCompleted => completedTasks == totalTasks && totalTasks > 0;

  /// Get estimated vs actual time efficiency
  double? get timeEfficiency {
    if (totalEstimatedMinutes > 0 && totalActualMinutes > 0) {
      return totalEstimatedMinutes / totalActualMinutes;
    }
    return null;
  }
}

/// Task hierarchy statistics
class TaskHierarchyStats {
  const TaskHierarchyStats({
    required this.totalTasks,
    required this.rootTasks,
    required this.subtasks,
    required this.maxDepth,
    required this.completedTasks,
  });

  final int totalTasks;
  final int rootTasks;
  final int subtasks;
  final int maxDepth;
  final int completedTasks;

  /// Calculate overall completion percentage
  double get completionPercentage {
    return totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  }

  /// Check if hierarchy has nested structure
  bool get hasNesting => subtasks > 0;
}

