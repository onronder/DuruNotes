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