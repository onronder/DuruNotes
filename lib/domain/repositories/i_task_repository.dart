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
}