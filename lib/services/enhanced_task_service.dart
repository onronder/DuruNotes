import 'dart:async';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced task service with integrated reminder management
/// PRODUCTION: Uses TaskCoreRepository for CRUD operations (handles encryption), manages reminders
class EnhancedTaskService {
  EnhancedTaskService({
    required AppDb database,
    required ITaskRepository taskRepository,
    required TaskReminderBridge reminderBridge,
    SupabaseClient? supabaseClient,
  }) : _reminderBridge = reminderBridge,
       _db = database,
       _taskRepository = taskRepository,
       _supabaseClient = supabaseClient ?? _resolveSupabaseClient();

  final TaskReminderBridge _reminderBridge;
  final AppDb _db;
  final ITaskRepository _taskRepository;
  final SupabaseClient? _supabaseClient;

  // Bidirectional sync functionality is coordinated by the domain layer now

  AppDb get database => _db;

  static SupabaseClient? _resolveSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUserId {
    try {
      return _supabaseClient?.auth.currentUser?.id;
    } catch (e) {
      debugPrint('EnhancedTaskService: failed to resolve userId: $e');
      return null;
    }
  }

  String? _requireUserIdFor(String action) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      debugPrint(
        'EnhancedTaskService: cannot perform "$action" without userId',
      );
      return null;
    }
    return userId;
  }

  Future<void> migrateStandaloneNoteId({
    required String fromNoteId,
    required String toNoteId,
  }) async {
    await _db.migrateNoteId(fromNoteId, toNoteId);
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
        'EnhancedTaskService: unable to enqueue note sync, userId unavailable',
      );
      return;
    }
    await _db.enqueue(userId: userId, entityId: toNoteId, kind: 'upsert_note');
  }

  /// Create a new task with optional reminder integration
  /// PRODUCTION: Uses TaskCoreRepository for actual task creation - it handles encryption
  /// This method manages reminder integration and returns the created task ID
  Future<String> createTask({
    required String noteId,
    required String content,
    TaskStatus status = TaskStatus.open,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
    int? position,
    bool createReminder = true,
  }) async {
    // Convert parameters to domain.Task object
    final domainTask = domain.Task(
      id: '', // TaskCoreRepository will generate ID
      noteId: noteId,
      title: content,
      description: notes,
      status: _mapStatusToDomain(status),
      priority: _mapPriorityToDomain(priority),
      dueDate: dueDate,
      completedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: labels != null
          ? (labels['labels'] as List<dynamic>?)?.cast<String>() ?? []
          : [],
      metadata: {
        if (parentTaskId != null) 'parentTaskId': parentTaskId,
        if (position != null) 'position': position,
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      },
    );

    // Create task using TaskCoreRepository (handles encryption)
    final createdTask = await _taskRepository.createTask(domainTask);
    final taskId = createdTask.id;

    // Handle reminder creation if requested
    if (createReminder && dueDate != null) {
      try {
        final userId = _requireUserIdFor('createTask.linkReminder');
        if (userId == null) {
          return taskId;
        }
        final localTask = await _db.getTaskById(taskId, userId: userId);
        if (localTask != null) {
          // Create reminder and get its ID
          final reminderId = await _reminderBridge.createTaskReminder(
            task: localTask,
            beforeDueDate: const Duration(hours: 1), // Default 1 hour before
          );

          // Link reminder to task
          if (reminderId != null) {
            await _db.updateTask(
              taskId,
              userId,
              NoteTasksCompanion(
                reminderId: Value(reminderId),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      } catch (e) {
        // Don't fail task creation if reminder fails
        debugPrint('Failed to create reminder for task $taskId: $e');
      }
    }

    return taskId;
  }

  /// Update an existing task with optional reminder sync
  /// PRODUCTION: Uses TaskCoreRepository for content updates - it handles encryption
  Future<void> updateTask({
    required String taskId,
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
    int? actualMinutes,
    int? reminderId,
    String? parentTaskId,
    bool updateReminder = true,
    bool clearReminderId = false,
  }) async {
    final userId = _requireUserIdFor('updateTask');
    if (userId == null) {
      throw StateError('Task update requires authenticated user');
    }
    // Get old task for comparison and reminder updates
    final oldLocalTask = await _db.getTaskById(taskId, userId: userId);

    // Get current domain task
    final currentTask = await _taskRepository.getTaskById(taskId);
    if (currentTask == null) {
      throw Exception('Task not found: $taskId');
    }

    // Build updated domain task by merging current values with updates
    final updatedTask = domain.Task(
      id: taskId,
      noteId: currentTask.noteId,
      title: content ?? currentTask.title,
      description: notes ?? currentTask.description,
      status: status != null ? _mapStatusToDomain(status) : currentTask.status,
      priority: priority != null
          ? _mapPriorityToDomain(priority)
          : currentTask.priority,
      dueDate: dueDate ?? currentTask.dueDate,
      completedAt: status == TaskStatus.completed
          ? DateTime.now()
          : currentTask.completedAt,
      createdAt: currentTask.createdAt,
      updatedAt: DateTime.now(),
      tags: labels != null
          ? (labels['labels'] as List<dynamic>?)?.cast<String>() ?? []
          : currentTask.tags,
      metadata: {
        ...currentTask.metadata,
        if (parentTaskId != null) 'parentTaskId': parentTaskId,
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
        if (actualMinutes != null) 'actualMinutes': actualMinutes,
        if (reminderId != null) 'reminderId': reminderId,
      },
    );

    // Update task using TaskCoreRepository (handles encryption)
    await _taskRepository.updateTask(updatedTask);

    // Handle reminder ID clearing separately if needed
    if (clearReminderId) {
      await _db.updateTask(
        taskId,
        userId,
        NoteTasksCompanion(
          reminderId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    // Handle reminder updates if enabled
    if (updateReminder && oldLocalTask != null) {
      try {
        final newLocalTask = await _db.getTaskById(taskId, userId: userId);
        if (newLocalTask != null) {
          await _reminderBridge.onTaskUpdated(oldLocalTask, newLocalTask);
        }
      } catch (e) {
        // Don't fail task update if reminder fails
        debugPrint('Failed to update reminder for task $taskId: $e');
      }
    }
  }

  /// Complete a task
  Future<void> completeTask(String taskId, {String? completedBy}) async {
    final userId = _requireUserIdFor('completeTask');
    if (userId == null) {
      return;
    }
    // Get task before completion for reminder cleanup
    final task = await _db.getTaskById(taskId, userId: userId);

    // Complete the task using AppDb directly
    await _db.completeTask(taskId, userId, completedBy: completedBy);

    // Sync handled by domain synchronization flows

    // Cancel reminder if task had one
    if (task != null) {
      try {
        await _reminderBridge.onTaskUpdated(
          task,
          task.copyWith(status: TaskStatus.completed),
        );
      } catch (e) {
        debugPrint('Failed to cancel reminder for completed task $taskId: $e');
      }
    }
  }

  /// Toggle task status between completed and open
  Future<void> toggleTaskStatus(String taskId) async {
    final userId = _requireUserIdFor('toggleTaskStatus');
    if (userId == null) {
      return;
    }
    // Get task before toggle for reminder management
    final oldTask = await _db.getTaskById(taskId, userId: userId);

    // Toggle using AppDb directly
    await _db.toggleTaskStatus(taskId, userId);

    // Sync handled by domain synchronization flows

    // Handle reminder updates
    if (oldTask != null) {
      try {
        final newTask = await _db.getTaskById(taskId, userId: userId);
        if (newTask != null) {
          await _reminderBridge.onTaskUpdated(oldTask, newTask);
        }
      } catch (e) {
        debugPrint('Failed to update reminder for toggled task $taskId: $e');
      }
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    final userId = _requireUserIdFor('deleteTask');
    if (userId == null) {
      return;
    }
    // Get task before deletion for reminder cleanup
    final task = await _db.getTaskById(taskId, userId: userId);

    // Delete the task using AppDb directly
    await _db.deleteTaskById(taskId, userId);

    // Cancel reminder if task had one
    if (task != null) {
      try {
        await _reminderBridge.onTaskDeleted(task);
      } catch (e) {
        debugPrint('Failed to cancel reminder for deleted task $taskId: $e');
      }
    }
  }

  /// Create task with specific reminder time
  Future<String> createTaskWithReminder({
    required String noteId,
    required String content,
    required DateTime dueDate,
    required DateTime reminderTime,
    TaskPriority priority = TaskPriority.medium,
    String? parentTaskId,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
  }) async {
    // Create task without auto-reminder
    final taskId = await createTask(
      noteId: noteId,
      content: content,
      priority: priority,
      dueDate: dueDate,
      parentTaskId: parentTaskId,
      labels: labels,
      notes: notes,
      estimatedMinutes: estimatedMinutes,
      createReminder: false,
    );

    // Create custom reminder
    try {
      final userId = _requireUserIdFor('createTaskWithReminder.loadTask');
      if (userId == null) {
        return taskId;
      }
      final task = await _db.getTaskById(taskId, userId: userId);
      if (task != null) {
        final reminderDuration = reminderTime.difference(dueDate);
        final reminderId = await _reminderBridge.createTaskReminder(
          task: task,
          beforeDueDate: reminderDuration.isNegative
              ? Duration.zero
              : reminderDuration.abs(),
        );

        // Link reminder to task
        if (reminderId != null) {
          await updateTask(taskId: taskId, reminderId: reminderId);
        }
      }
    } catch (e) {
      debugPrint('Failed to create custom reminder for task $taskId: $e');
    }

    return taskId;
  }

  /// Cancel any reminder associated with the task.
  Future<void> clearTaskReminder(String taskId) async {
    final userId = _requireUserIdFor('clearTaskReminder');
    if (userId == null) return;
    final task = await _db.getTaskById(taskId, userId: userId);
    if (task == null) return;

    await _reminderBridge.cancelTaskReminder(task);
  }

  /// Reschedule a task reminder using a custom reminder time.
  Future<void> setCustomTaskReminder({
    required String taskId,
    required DateTime dueDate,
    required DateTime reminderTime,
  }) async {
    final userId = _requireUserIdFor('setCustomTaskReminder');
    if (userId == null) return;
    final task = await _db.getTaskById(taskId, userId: userId);
    if (task == null) return;

    final effectiveTask = task.copyWith(dueDate: Value(dueDate));

    if (effectiveTask.reminderId != null) {
      await _reminderBridge.cancelTaskReminder(effectiveTask);
    }

    final leadTime = dueDate.difference(reminderTime);
    await _reminderBridge.createTaskReminder(
      task: effectiveTask,
      beforeDueDate: leadTime.isNegative ? Duration.zero : leadTime,
    );
  }

  /// Refresh the reminder so it matches the latest due date using default lead time.
  Future<void> refreshDefaultTaskReminder(String taskId) async {
    final userId = _requireUserIdFor('refreshDefaultTaskReminder');
    if (userId == null) return;
    final task = await _db.getTaskById(taskId, userId: userId);
    if (task == null || task.dueDate == null) return;

    await _reminderBridge.updateTaskReminder(task);
  }

  /// Snooze task reminder
  Future<void> snoozeTaskReminder({
    required String taskId,
    required Duration snoozeDuration,
  }) async {
    try {
      final userId = _requireUserIdFor('snoozeTaskReminder');
      if (userId == null) return;
      final task = await _db.getTaskById(taskId, userId: userId);
      if (task != null) {
        await _reminderBridge.snoozeTaskReminder(
          task: task,
          snoozeDuration: snoozeDuration,
        );
      }
    } catch (e) {
      debugPrint('Failed to snooze reminder for task $taskId: $e');
    }
  }

  /// Get tasks with active reminders
  Future<List<NoteTask>> getTasksWithReminders() async {
    return _reminderBridge.getTasksWithReminders();
  }

  /// Bulk update reminders for multiple tasks
  Future<void> bulkUpdateTaskReminders(List<NoteTask> tasks) async {
    await _reminderBridge.bulkUpdateTaskReminders(tasks);
  }

  /// Clean up orphaned task reminders
  Future<void> cleanupOrphanedTaskReminders() async {
    await _reminderBridge.cleanupOrphanedReminders();
  }

  /// Handle task notification actions
  Future<void> handleTaskNotificationAction({
    required String action,
    required String payload,
  }) async {
    await _reminderBridge.handleTaskNotificationAction(
      action: action,
      payload: payload,
    );
  }

  /// Complete all subtasks of a parent task
  Future<void> completeAllSubtasks(String parentTaskId) async {
    try {
      final subtasks = await getSubtasks(parentTaskId);

      for (final subtask in subtasks) {
        await completeTask(subtask.id);

        // Recursively complete children
        await completeAllSubtasks(subtask.id);
      }

      debugPrint('Completed all subtasks for parent: $parentTaskId');
    } catch (e) {
      debugPrint('Error completing all subtasks: $e');
      rethrow;
    }
  }

  /// Delete task hierarchy (parent and all children)
  Future<void> deleteTaskHierarchy(String taskId) async {
    try {
      // Get all children recursively
      final childTasks = await _getAllChildTasks(taskId);

      // Delete children first (to maintain referential integrity)
      for (final child in childTasks.reversed) {
        await deleteTask(child.id);
      }

      // Delete parent task
      await deleteTask(taskId);

      debugPrint(
        'Deleted task hierarchy: $taskId (${childTasks.length + 1} tasks)',
      );
    } catch (e) {
      debugPrint('Error deleting task hierarchy: $e');
      rethrow;
    }
  }

  /// Get subtasks for a parent task
  Future<List<NoteTask>> getSubtasks(String parentTaskId) async {
    final userId = _requireUserIdFor('getSubtasks');
    if (userId == null) return [];
    return _db.getOpenTasks(userId: userId, parentTaskId: parentTaskId);
  }

  /// Get all child tasks recursively
  Future<List<NoteTask>> _getAllChildTasks(String parentTaskId) async {
    final allChildren = <NoteTask>[];
    final directChildren = await getSubtasks(parentTaskId);

    for (final child in directChildren) {
      allChildren.add(child);
      final grandChildren = await _getAllChildTasks(child.id);
      allChildren.addAll(grandChildren);
    }

    return allChildren;
  }

  /// Update task positions for reordering
  Future<void> updateTaskPositions(Map<String, int> taskPositions) async {
    final userId = _requireUserIdFor('updateTaskPositions');
    if (userId == null) return;
    for (final entry in taskPositions.entries) {
      await _db.updateTask(
        entry.key,
        userId,
        NoteTasksCompanion(
          position: Value(entry.value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Move task to different parent (change hierarchy)
  Future<void> moveTaskToParent({
    required String taskId,
    String? newParentId,
    int? newPosition,
  }) async {
    try {
      await updateTask(taskId: taskId, parentTaskId: newParentId);

      if (newPosition != null) {
        await updateTaskPositions({taskId: newPosition});
      }

      debugPrint('Moved task $taskId to parent: $newParentId');
    } catch (e) {
      debugPrint('Error moving task to parent: $e');
      rethrow;
    }
  }

  /// Bulk complete multiple tasks
  Future<void> bulkCompleteTasks(List<String> taskIds) async {
    for (final taskId in taskIds) {
      try {
        await completeTask(taskId);
      } catch (e) {
        debugPrint('Error completing task $taskId: $e');
        // Continue with other tasks
      }
    }
  }

  /// Bulk delete multiple tasks
  Future<void> bulkDeleteTasks(List<String> taskIds) async {
    for (final taskId in taskIds) {
      try {
        await deleteTask(taskId);
      } catch (e) {
        debugPrint('Error deleting task $taskId: $e');
        // Continue with other tasks
      }
    }
  }

  /// Bulk update task priorities
  Future<void> bulkUpdateTaskPriorities(
    Map<String, TaskPriority> taskPriorities,
  ) async {
    for (final entry in taskPriorities.entries) {
      try {
        await updateTask(taskId: entry.key, priority: entry.value);
      } catch (e) {
        debugPrint('Error updating priority for task ${entry.key}: $e');
        // Continue with other tasks
      }
    }
  }

  // ===== Helper Methods =====

  /// Map local TaskStatus to domain TaskStatus
  domain.TaskStatus _mapStatusToDomain(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return domain.TaskStatus.pending;
      case TaskStatus.completed:
        return domain.TaskStatus.completed;
      case TaskStatus.cancelled:
        return domain.TaskStatus.cancelled;
    }
  }

  /// Map local TaskPriority to domain TaskPriority
  domain.TaskPriority _mapPriorityToDomain(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return domain.TaskPriority.urgent;
      case TaskPriority.high:
        return domain.TaskPriority.high;
      case TaskPriority.medium:
        return domain.TaskPriority.medium;
      case TaskPriority.low:
        return domain.TaskPriority.low;
    }
  }
}
