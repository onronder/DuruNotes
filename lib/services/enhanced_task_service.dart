import 'dart:async';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';
import 'package:duru_notes/services/hierarchical_task_sync_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:flutter/foundation.dart';

/// Enhanced task service with integrated reminder management
class EnhancedTaskService extends TaskService {
  EnhancedTaskService({
    required AppDb database,
    required TaskReminderBridge reminderBridge,
    BidirectionalTaskSyncService? bidirectionalSync,
  }) : _reminderBridge = reminderBridge,
       _db = database,
       _bidirectionalSync = bidirectionalSync,
       super(database: database);

  final TaskReminderBridge _reminderBridge;
  final AppDb _db;
  BidirectionalTaskSyncService? _bidirectionalSync;
  
  /// Set the bidirectional sync service (to avoid circular dependency)
  void setBidirectionalSync(BidirectionalTaskSyncService sync) {
    _bidirectionalSync = sync;
  }

  @override
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
    // Use transaction for atomicity when creating task with reminder
    if (createReminder && dueDate != null) {
      return await _db.transaction(() async {
        // Create the task
        final taskId = await super.createTask(
          noteId: noteId,
          content: content,
          status: status,
          priority: priority,
          dueDate: dueDate,
          parentTaskId: parentTaskId,
          labels: labels,
          notes: notes,
          estimatedMinutes: estimatedMinutes,
          position: position,
        );

        try {
          final task = await _db.getTaskById(taskId);
          if (task != null) {
            // Create reminder and get its ID
            final reminderId = await _reminderBridge.createTaskReminder(
              task: task,
              beforeDueDate: const Duration(hours: 1), // Default 1 hour before
            );
            
            // Link reminder to task within the same transaction
            if (reminderId != null) {
              await super.updateTask(
                taskId: taskId,
                reminderId: reminderId,
              );
            }
          }
        } catch (e) {
          // Log but don't fail the transaction - task is more important than reminder
          debugPrint('Failed to create reminder for task $taskId: $e');
        }

        return taskId;
      });
    } else {
      // No reminder needed, create task normally
      return await super.createTask(
        noteId: noteId,
        content: content,
        status: status,
        priority: priority,
        dueDate: dueDate,
        parentTaskId: parentTaskId,
        labels: labels,
        notes: notes,
        estimatedMinutes: estimatedMinutes,
        position: position,
      );
    }
  }

  @override
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
    // Get old task for comparison
    final oldTask = await _db.getTaskById(taskId);
    
    // Update the task using parent implementation
    await super.updateTask(
      taskId: taskId,
      content: content,
      status: status,
      priority: priority,
      dueDate: dueDate,
      labels: labels,
      notes: notes,
      estimatedMinutes: estimatedMinutes,
      actualMinutes: actualMinutes,
      reminderId: reminderId,
      parentTaskId: parentTaskId,
      clearReminderId: clearReminderId,
    );

    // Sync changes back to note if bidirectional sync is enabled
    if (_bidirectionalSync != null && oldTask != null && oldTask.noteId.isNotEmpty) {
      await _bidirectionalSync!.syncFromTaskToNote(
        taskId: taskId,
        noteId: oldTask.noteId,
        newContent: content,
        isCompleted: status == TaskStatus.completed,
        priority: priority,
        dueDate: dueDate,
      );
    }

    // Handle reminder updates if enabled
    if (updateReminder && oldTask != null) {
      try {
        final newTask = await _db.getTaskById(taskId);
        if (newTask != null) {
          await _reminderBridge.onTaskUpdated(oldTask, newTask);
        }
      } catch (e) {
        // Don't fail task update if reminder fails
        debugPrint('Failed to update reminder for task $taskId: $e');
      }
    }
  }

  @override
  Future<void> completeTask(String taskId, {String? completedBy}) async {
    // Get task before completion for reminder cleanup
    final task = await _db.getTaskById(taskId);
    
    // Complete the task using parent implementation
    await super.completeTask(taskId, completedBy: completedBy);

    // Sync completion back to note
    if (_bidirectionalSync != null && task != null && task.noteId.isNotEmpty) {
      await _bidirectionalSync!.syncFromTaskToNote(
        taskId: taskId,
        noteId: task.noteId,
        isCompleted: true,
      );
    }

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

  @override
  Future<void> toggleTaskStatus(String taskId) async {
    // Get task before toggle for reminder management
    final oldTask = await _db.getTaskById(taskId);
    
    // Toggle using parent implementation
    await super.toggleTaskStatus(taskId);

    // Sync toggle back to note
    if (_bidirectionalSync != null && oldTask != null && oldTask.noteId.isNotEmpty) {
      final newTask = await _db.getTaskById(taskId);
      if (newTask != null) {
        await _bidirectionalSync!.syncFromTaskToNote(
          taskId: taskId,
          noteId: oldTask.noteId,
          isCompleted: newTask.status == TaskStatus.completed,
        );
      }
    }

    // Handle reminder updates
    if (oldTask != null) {
      try {
        final newTask = await _db.getTaskById(taskId);
        if (newTask != null) {
          await _reminderBridge.onTaskUpdated(oldTask, newTask);
        }
      } catch (e) {
        debugPrint('Failed to update reminder for toggled task $taskId: $e');
      }
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    // Get task before deletion for reminder cleanup
    final task = await _db.getTaskById(taskId);
    
    // Delete the task using parent implementation
    await super.deleteTask(taskId);

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
      final task = await _db.getTaskById(taskId);
      if (task != null) {
        final reminderDuration = reminderTime.difference(dueDate);
        final reminderId = await _reminderBridge.createTaskReminder(
          task: task,
          beforeDueDate: reminderDuration.isNegative ? Duration.zero : reminderDuration.abs(),
        );
        
        // Link reminder to task
        if (reminderId != null) {
          await updateTask(
            taskId: taskId,
            reminderId: reminderId,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to create custom reminder for task $taskId: $e');
    }

    return taskId;
  }

  /// Snooze task reminder
  Future<void> snoozeTaskReminder({
    required String taskId,
    required Duration snoozeDuration,
  }) async {
    try {
      final task = await _db.getTaskById(taskId);
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
      
      debugPrint('Deleted task hierarchy: $taskId (${childTasks.length + 1} tasks)');
    } catch (e) {
      debugPrint('Error deleting task hierarchy: $e');
      rethrow;
    }
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

  /// Move task to different parent (change hierarchy)
  Future<void> moveTaskToParent({
    required String taskId,
    String? newParentId,
    int? newPosition,
  }) async {
    try {
      await updateTask(
        taskId: taskId,
        parentTaskId: newParentId,
      );
      
      if (newPosition != null) {
        await updateTaskPositions({taskId: newPosition});
      }
      
      debugPrint('Moved task $taskId to parent: $newParentId');
    } catch (e) {
      debugPrint('Error moving task to parent: $e');
      rethrow;
    }
  }

  /// Get task hierarchy for a note
  Future<List<TaskHierarchyNode>> getTaskHierarchy(String noteId) async {
    try {
      final allTasks = await getTasksForNote(noteId);
      return _buildTaskHierarchy(allTasks);
    } catch (e) {
      debugPrint('Error getting task hierarchy: $e');
      return [];
    }
  }

  /// Build task hierarchy from flat task list
  List<TaskHierarchyNode> _buildTaskHierarchy(List<NoteTask> tasks) {
    final taskMap = <String, NoteTask>{for (var task in tasks) task.id: task};
    final rootTasks = <TaskHierarchyNode>[];
    final nodeMap = <String, TaskHierarchyNode>{};

    // Create nodes for all tasks
    for (final task in tasks) {
      nodeMap[task.id] = TaskHierarchyNode(
        task: task,
        children: [],
        parent: null,
      );
    }

    // Build hierarchy
    for (final task in tasks) {
      final node = nodeMap[task.id]!;
      
      if (task.parentTaskId != null && nodeMap.containsKey(task.parentTaskId!)) {
        // Add as child to parent
        final parentNode = nodeMap[task.parentTaskId!]!;
        parentNode.children.add(node);
        node.parent = parentNode;
      } else {
        // Root task
        rootTasks.add(node);
      }
    }

    // Sort by position
    rootTasks.sort((a, b) => a.task.position.compareTo(b.task.position));
    for (final node in nodeMap.values) {
      node.children.sort((a, b) => a.task.position.compareTo(b.task.position));
    }

    return rootTasks;
  }

  /// Calculate progress for a parent task
  TaskProgress calculateTaskProgress(TaskHierarchyNode parentNode) {
    var totalTasks = 1; // Include the parent task itself
    var completedTasks = parentNode.task.status == TaskStatus.completed ? 1 : 0;
    var totalEstimatedMinutes = parentNode.task.estimatedMinutes ?? 0;
    var totalActualMinutes = parentNode.task.actualMinutes ?? 0;

    void countSubtasks(TaskHierarchyNode node) {
      for (final child in node.children) {
        totalTasks++;
        if (child.task.status == TaskStatus.completed) {
          completedTasks++;
        }
        totalEstimatedMinutes += child.task.estimatedMinutes ?? 0;
        totalActualMinutes += child.task.actualMinutes ?? 0;
        
        // Recursively count children
        countSubtasks(child);
      }
    }

    countSubtasks(parentNode);

    return TaskProgress(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      progressPercentage: totalTasks > 0 ? (completedTasks / totalTasks) : 0.0,
      totalEstimatedMinutes: totalEstimatedMinutes,
      totalActualMinutes: totalActualMinutes,
    );
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
        await updateTask(
          taskId: entry.key,
          priority: entry.value,
        );
      } catch (e) {
        debugPrint('Error updating priority for task ${entry.key}: $e');
        // Continue with other tasks
      }
    }
  }
}
