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

  /// Migrate tasks from standalone note to parent note (infrastructure operation)
  /// This is a data migration utility, not business logic
  Future<void> migrateStandaloneNoteId({
    required String fromNoteId,
    required String toNoteId,
  }) async {
    // Infrastructure: Data migration operation (not business logic)
    await _db.migrateNoteId(fromNoteId, toNoteId);

    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
        'EnhancedTaskService: unable to enqueue note sync, userId unavailable',
      );
      return;
    }

    // Infrastructure: Sync queue management (not business logic)
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
    // PERFORMANCE INSTRUMENTATION
    final totalStopwatch = Stopwatch()..start();

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
    final repoStopwatch = Stopwatch()..start();
    final createdTask = await _taskRepository.createTask(domainTask);
    debugPrint('[PERF] taskRepository.createTask: ${repoStopwatch.elapsedMilliseconds}ms');

    final taskId = createdTask.id;

    // Handle reminder creation if requested
    // PERFORMANCE FIX: Don't block task creation on reminder scheduling
    if (createReminder && dueDate != null) {
      debugPrint('[PERF] Starting async reminder creation (non-blocking)');
      unawaited(
        Future(() async {
          final reminderStopwatch = Stopwatch()..start();
          try {
            // Infrastructure: Get NoteTask for reminder bridge coordination
            final localTask = await _getTaskForReminder(taskId);
            if (localTask != null) {
              // Create reminder and get its ID
              final reminderId = await _reminderBridge.createTaskReminder(
                task: localTask,
                beforeDueDate: const Duration(hours: 1), // Default 1 hour before
              );

              // Link reminder to task
              if (reminderId != null) {
                await _taskRepository.updateTaskReminderLink(
                  taskId: taskId,
                  reminderId: reminderId,
                );
              }
            }
            debugPrint('[PERF] Async reminder creation completed: ${reminderStopwatch.elapsedMilliseconds}ms');
          } catch (e) {
            // Don't fail task creation if reminder fails
            debugPrint('[PERF] Reminder creation failed after ${reminderStopwatch.elapsedMilliseconds}ms: $e');
          }
        }),
      );
    }

    debugPrint('[PERF] ⏱️ EnhancedTaskService.createTask total: ${totalStopwatch.elapsedMilliseconds}ms');
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
    // MIGRATION v41: Changed from int to String (UUID)
    String? reminderId,
    String? parentTaskId,
    bool updateReminder = true,
    bool clearReminderId = false,
  }) async {
    final userId = _requireUserIdFor('updateTask');
    if (userId == null) {
      throw StateError('Task update requires authenticated user');
    }
    // Infrastructure: Get old task for reminder comparison (platform coordination)
    final oldLocalTask = await _getTaskForReminder(taskId);

    // Business Logic: Get current domain task from repository
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
      await _taskRepository.updateTaskReminderLink(
        taskId: taskId,
        reminderId: null,
      );
    }

    // Handle reminder updates if enabled
    if (updateReminder && oldLocalTask != null) {
      try {
        // Infrastructure: Get updated task for reminder bridge coordination
        final newLocalTask = await _getTaskForReminder(taskId);
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
  /// PRODUCTION: Uses TaskCoreRepository for soft-delete compliance
  Future<void> completeTask(String taskId, {String? completedBy}) async {
    final userId = _requireUserIdFor('completeTask');
    if (userId == null) {
      return;
    }
    // Infrastructure: Get task for reminder cleanup (platform coordination)
    final task = await _getTaskForReminder(taskId);

    // Business Logic: Complete task via repository (handles soft-delete, sync)
    await _taskRepository.completeTask(taskId);

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
  /// PRODUCTION: Uses TaskCoreRepository for soft-delete compliance
  Future<void> toggleTaskStatus(String taskId) async {
    final userId = _requireUserIdFor('toggleTaskStatus');
    if (userId == null) {
      return;
    }
    // Infrastructure: Get task before toggle for reminder management
    final oldTask = await _getTaskForReminder(taskId);

    // Business Logic: Toggle using repository (handles soft-delete, sync)
    await _taskRepository.toggleTaskStatus(taskId);

    // Handle reminder updates
    if (oldTask != null) {
      try {
        // Infrastructure: Get updated task for reminder bridge coordination
        final newTask = await _getTaskForReminder(taskId);
        if (newTask != null) {
          await _reminderBridge.onTaskUpdated(oldTask, newTask);
        }
      } catch (e) {
        debugPrint('Failed to update reminder for toggled task $taskId: $e');
      }
    }
  }

  /// Delete a task
  /// PRODUCTION: Uses TaskCoreRepository for SOFT DELETE (30-day retention)
  /// Task will appear in TrashScreen and can be restored within 30 days
  /// See: DELETION_PATTERNS.md v1.0.0, ARCHITECTURE_VIOLATIONS.md v1.1.0
  Future<void> deleteTask(String taskId) async {
    final userId = _requireUserIdFor('deleteTask');
    if (userId == null) {
      return;
    }
    // Infrastructure: Get task for reminder cleanup (platform coordination)
    final task = await _getTaskForReminder(taskId);

    // Business Logic: Use repository for SOFT DELETE (30-day trash retention)
    await _taskRepository.deleteTask(taskId);

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
      // Infrastructure: Get task for reminder bridge coordination
      final task = await _getTaskForReminder(taskId);
      if (task != null) {
        final reminderDuration = reminderTime.difference(dueDate);
        final reminderId = await _reminderBridge.createTaskReminder(
          task: task,
          beforeDueDate: reminderDuration.isNegative
              ? Duration.zero
              : reminderDuration.abs(),
        );

        // Business Logic: Link reminder to task via repository
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
    // Infrastructure: Get task for reminder bridge coordination
    final task = await _getTaskForReminder(taskId);
    if (task == null) return;

    await _reminderBridge.cancelTaskReminder(task);
  }

  /// Reschedule a task reminder using a custom reminder time.
  Future<void> setCustomTaskReminder({
    required String taskId,
    required DateTime dueDate,
    required DateTime reminderTime,
  }) async {
    // Infrastructure: Get task for reminder bridge coordination
    final task = await _getTaskForReminder(taskId);
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
    // Infrastructure: Get task for reminder bridge coordination
    final task = await _getTaskForReminder(taskId);
    if (task == null || task.dueDate == null) return;

    await _reminderBridge.updateTaskReminder(task);
  }

  /// Snooze task reminder
  Future<void> snoozeTaskReminder({
    required String taskId,
    required Duration snoozeDuration,
  }) async {
    try {
      // Infrastructure: Get task for reminder bridge coordination
      final task = await _getTaskForReminder(taskId);
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
  /// PRODUCTION: Uses TaskCoreRepository for efficient, encrypted queries
  /// Returns domain entities (not database objects) per clean architecture
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async {
    try {
      return await _taskRepository.getSubtasks(parentTaskId);
    } catch (e) {
      debugPrint('Failed to get subtasks for $parentTaskId: $e');
      return [];
    }
  }

  /// Get all child tasks recursively
  /// PRODUCTION: Works with domain entities from repository layer
  Future<List<domain.Task>> _getAllChildTasks(String parentTaskId) async {
    final allChildren = <domain.Task>[];
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
    if (userId == null || taskPositions.isEmpty) return;
    await _taskRepository.updateTaskPositions(taskPositions);
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

  /// Get NoteTask for reminder bridge coordination (infrastructure concern)
  ///
  /// ARCHITECTURAL NOTE: This method exists to bridge the gap between domain layer
  /// and platform-specific reminder APIs. The TaskReminderBridge requires NoteTask
  /// (database layer objects) to interface with platform notification systems.
  ///
  /// For business logic operations, use _taskRepository methods instead.
  /// This is acceptable technical debt documented in ARCHITECTURE_VIOLATIONS.md v1.1.0
  ///
  /// Returns null if user is not authenticated or task not found
  Future<NoteTask?> _getTaskForReminder(String taskId) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
        'EnhancedTaskService: Cannot fetch task for reminder - no userId',
      );
      return null;
    }

    try {
      return await _db.getTaskById(taskId, userId: userId);
    } catch (e) {
      debugPrint('EnhancedTaskService: Failed to fetch task for reminder: $e');
      return null;
    }
  }

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
