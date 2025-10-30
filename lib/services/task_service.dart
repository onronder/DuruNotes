import 'dart:async';

import 'package:duru_notes/data/local/app_db.dart';

/// DEPRECATED: This legacy service bypasses encryption and cannot work with encrypted fields.
///
/// Use TaskCoreRepository instead, which handles encryption/decryption automatically:
/// - infrastructure/repositories/task_core_repository.dart
///
/// TaskCoreRepository provides the same functionality but works with domain.Task entities
/// (already decrypted) instead of raw database models.
///
/// Migration guide:
/// - createTask() → taskRepository.createTask()
/// - updateTask() → taskRepository.updateTask()
/// - All fields are automatically encrypted/decrypted by the repository
@Deprecated(
  'Use TaskCoreRepository instead - this service cannot handle encryption',
)
class TaskService {
  TaskService({required AppDb database}) : _db = database;

  final AppDb _db;

  UnsupportedError _deprecatedError(String method) => UnsupportedError(
    'TaskService.$method is deprecated. Use TaskCoreRepository/EnhancedTaskService instead. '
    '(database=${_db.runtimeType})',
  );

  /// Create a new task
  @Deprecated('Use TaskCoreRepository.createTask() instead')
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
  }) async {
    throw UnsupportedError(
      'TaskService is deprecated. Use TaskCoreRepository instead - it handles encryption automatically.',
    );
  }

  /// Update an existing task
  @Deprecated('Use TaskCoreRepository.updateTask() instead')
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
    bool clearReminderId = false,
  }) async {
    throw UnsupportedError(
      'TaskService is deprecated. Use TaskCoreRepository instead - it handles encryption automatically.',
    );
  }

  /// Mark a task as completed
  Future<void> completeTask(String taskId, {String? completedBy}) =>
      throw _deprecatedError('completeTask');

  /// Toggle task completion status
  Future<void> toggleTaskStatus(String taskId) =>
      throw _deprecatedError('toggleTaskStatus');

  /// Delete a task
  Future<void> deleteTask(String taskId) =>
      throw _deprecatedError('deleteTask');

  /// Get all tasks for a note
  Future<List<NoteTask>> getTasksForNote(String noteId) =>
      throw _deprecatedError('getTasksForNote');

  /// Get all open tasks
  Future<List<NoteTask>> getOpenTasks({
    DateTime? dueBefore,
    TaskPriority? priority,
    String? parentTaskId,
  }) => throw _deprecatedError('getOpenTasks');

  /// Get tasks for a specific date range
  Future<List<NoteTask>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) => throw _deprecatedError('getTasksByDateRange');

  /// Get overdue tasks
  Future<List<NoteTask>> getOverdueTasks() =>
      throw _deprecatedError('getOverdueTasks');

  /// Get completed tasks
  Future<List<NoteTask>> getCompletedTasks({DateTime? since, int? limit}) =>
      throw _deprecatedError('getCompletedTasks');

  /// Get tasks for today
  Future<List<NoteTask>> getTodaysTasks() =>
      throw _deprecatedError('getTodaysTasks');

  /// Get tasks for this week
  Future<List<NoteTask>> getThisWeeksTasks() =>
      throw _deprecatedError('getThisWeeksTasks');

  /// Watch all open tasks
  Stream<List<NoteTask>> watchOpenTasks() =>
      throw _deprecatedError('watchOpenTasks');

  /// Watch tasks for a specific note
  Stream<List<NoteTask>> watchTasksForNote(String noteId) =>
      throw _deprecatedError('watchTasksForNote');

  /// Sync tasks with note content
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) =>
      throw _deprecatedError('syncTasksWithNoteContent');

  /// Get task statistics
  Future<TaskStatistics> getTaskStatistics() =>
      throw _deprecatedError('getTaskStatistics');

  /// Batch update task positions (for reordering)
  Future<void> updateTaskPositions(Map<String, int> taskPositions) =>
      throw _deprecatedError('updateTaskPositions');

  /// Get subtasks for a parent task
  Future<List<NoteTask>> getSubtasks(String parentTaskId) =>
      throw _deprecatedError('getSubtasks');

  /// Convert task priority to display string
  String priorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  /// Convert task status to display string
  String statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Task statistics model
class TaskStatistics {
  const TaskStatistics({
    required this.totalOpen,
    required this.totalOverdue,
    required this.dueToday,
    required this.completedToday,
  });

  final int totalOpen;
  final int totalOverdue;
  final int dueToday;
  final int completedToday;
}
