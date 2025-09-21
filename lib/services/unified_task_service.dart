import 'dart:async';

import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void dispose() {
    _taskUpdatesController.close();
  }
}

// ===== Supporting Classes =====

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

// ===== Providers =====

/// Provider for the unified task service
final unifiedTaskServiceProvider = Provider<UnifiedTaskService>((ref) {
  final db = ref.watch(appDbProvider);
  final enhancedService = ref.watch(enhancedTaskServiceProvider);
  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  final service = UnifiedTaskService(
    db: db,
    logger: logger,
    analytics: analytics,
    enhancedTaskService: enhancedService,
  );

  // CRITICAL: Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for task updates stream
final taskUpdatesProvider = StreamProvider<TaskUpdate>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.taskUpdates;
});

/// Provider for tasks by note
final tasksForNoteProvider =
    FutureProvider.family<List<NoteTask>, String>((ref, noteId) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.getTasksForNote(noteId);
});

/// Provider for task statistics
final taskStatisticsProvider = FutureProvider<TaskStatistics>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);

  // Refresh when task updates occur
  ref.watch(taskUpdatesProvider);

  return service.getTaskStatistics();
});
