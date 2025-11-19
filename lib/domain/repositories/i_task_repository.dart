import '../entities/task.dart';

/// Domain interface for task operations
abstract class ITaskRepository {
  /// Get all tasks for a specific note
  Future<List<Task>> getTasksForNote(String noteId);

  /// Get all tasks
  Future<List<Task>> getAllTasks();

  /// Get pending tasks
  Future<List<Task>> getPendingTasks();

  /// Get task by ID
  Future<Task?> getTaskById(String id);

  /// Create a new task
  Future<Task> createTask(Task task);

  /// Update an existing task
  Future<Task> updateTask(Task task);

  /// Delete a task
  Future<void> deleteTask(String id);

  /// Get all soft-deleted tasks for Trash view (Phase 1.1)
  Future<List<Task>> getDeletedTasks();

  /// Restore a soft-deleted task from trash (Phase 1.1)
  Future<void> restoreTask(String id);

  /// Permanently delete a task (hard delete, cannot be undone)
  /// This removes the task from the database entirely
  Future<void> permanentlyDeleteTask(String id);

  /// Complete a task
  Future<void> completeTask(String id);

  /// Watch tasks stream
  Stream<List<Task>> watchTasks();

  /// Watch all tasks stream
  Stream<List<Task>> watchAllTasks();

  /// Watch tasks for a specific note
  Stream<List<Task>> watchTasksForNote(String noteId);

  /// Search tasks by query
  Future<List<Task>> searchTasks(String query);

  /// Toggle task status between open and completed
  Future<void> toggleTaskStatus(String id);

  /// Update task priority
  Future<void> updateTaskPriority(String id, TaskPriority priority);

  /// Update task due date
  Future<void> updateTaskDueDate(String id, DateTime? dueDate);

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks({int? limit, DateTime? since});

  /// Get overdue tasks
  Future<List<Task>> getOverdueTasks();

  /// Get tasks by date range
  Future<List<Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  });

  /// Delete all tasks for a note
  Future<void> deleteTasksForNote(String noteId);

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics();

  /// Get tasks by priority
  Future<List<Task>> getTasksByPriority(TaskPriority priority);

  /// Add tag to task
  Future<void> addTagToTask(String taskId, String tag);

  /// Remove tag from task
  Future<void> removeTagFromTask(String taskId, String tag);

  /// Update reminder linkage metadata for a task.
  // MIGRATION v41: Changed from int to String (UUID)
  Future<void> updateTaskReminderLink({
    required String taskId,
    required String? reminderId,
  });

  /// Bulk update task positions for manual reordering.
  Future<void> updateTaskPositions(Map<String, int> positions);

  /// Sync tasks with note content
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent);

  /// Create subtask
  Future<Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  });

  /// Get subtasks
  Future<List<Task>> getSubtasks(String parentTaskId);
}
