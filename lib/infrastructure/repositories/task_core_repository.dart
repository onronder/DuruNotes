import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Core task repository implementation
class TaskCoreRepository implements ITaskRepository {
  TaskCoreRepository({
    required this.db,
    required this.client,
  })  : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final _uuid = const Uuid();

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    try {
      final localTasks = await db.getTasksForNote(noteId);
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get tasks for note: $noteId', e, stack);
      return [];
    }
  }

  @override
  Future<List<domain.Task>> getAllTasks() async {
    try {
      final localTasks = await db.getAllTasks();
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get all tasks', e, stack);
      return [];
    }
  }

  @override
  Future<List<domain.Task>> getPendingTasks() async {
    try {
      final localTasks = await db.getOpenTasks();
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get pending tasks', e, stack);
      return [];
    }
  }

  @override
  Future<domain.Task?> getTaskById(String id) async {
    try {
      final localTask = await db.getTaskById(id);
      if (localTask == null) return null;

      return TaskMapper.toDomain(localTask);
    } catch (e, stack) {
      _logger.error('Failed to get task by id: $id', e, stack);
      return null;
    }
  }

  @override
  Future<domain.Task> createTask(domain.Task task) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Cannot create task without authenticated user');
      }

      // Create task with new ID if not provided
      final taskToCreate = task.id.isEmpty
          ? task.copyWith(id: _uuid.v4())
          : task;

      // Map to infrastructure model
      final localTask = TaskMapper.toInfrastructure(taskToCreate);

      // Create task companion for insertion
      final taskCompanion = NoteTasksCompanion(
        id: Value(localTask.id),
        noteId: Value(localTask.noteId),
        content: Value(localTask.content),
        status: Value(localTask.status),
        priority: Value(localTask.priority),
        dueDate: Value(localTask.dueDate),
        completedAt: Value(localTask.completedAt),
        completedBy: Value(localTask.completedBy),
        position: Value(localTask.position),
        contentHash: Value(localTask.contentHash),
        reminderId: Value(localTask.reminderId),
        labels: Value(localTask.labels),
        notes: Value(localTask.notes),
        estimatedMinutes: Value(localTask.estimatedMinutes),
        actualMinutes: Value(localTask.actualMinutes),
        parentTaskId: Value(localTask.parentTaskId),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      );

      // Insert into database
      await db.createTask(taskCompanion);

      // Enqueue for sync
      await db.enqueue(taskToCreate.id, 'upsert_task');

      return taskToCreate;
    } catch (e, stack) {
      _logger.error('Failed to create task: ${task.title}', e, stack);
      rethrow;
    }
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    try {
      // Verify task exists
      final existing = await db.getTaskById(task.id);
      if (existing == null) {
        throw Exception('Task not found: ${task.id}');
      }

      // Map to infrastructure model
      final localTask = TaskMapper.toInfrastructure(task);

      // Create update companion
      final updateCompanion = NoteTasksCompanion(
        content: Value(localTask.content),
        status: Value(localTask.status),
        priority: Value(localTask.priority),
        dueDate: Value(localTask.dueDate),
        completedAt: Value(localTask.completedAt),
        completedBy: Value(localTask.completedBy),
        position: Value(localTask.position),
        reminderId: Value(localTask.reminderId),
        labels: Value(localTask.labels),
        notes: Value(localTask.notes),
        estimatedMinutes: Value(localTask.estimatedMinutes),
        actualMinutes: Value(localTask.actualMinutes),
        parentTaskId: Value(localTask.parentTaskId),
        updatedAt: Value(DateTime.now().toUtc()),
      );

      // Update in database
      await db.updateTask(task.id, updateCompanion);

      // Enqueue for sync
      await db.enqueue(task.id, 'upsert_task');

      // Return updated task
      final updatedLocal = await db.getTaskById(task.id);
      return TaskMapper.toDomain(updatedLocal!);
    } catch (e, stack) {
      _logger.error('Failed to update task: ${task.id}', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      // Verify task exists
      final existing = await db.getTaskById(id);
      if (existing == null) {
        _logger.warning('Attempted to delete non-existent task: $id');
        return;
      }

      // Delete from database
      await db.deleteTaskById(id);

      // Enqueue for sync deletion
      await db.enqueue(id, 'delete_task');

      _logger.info('Deleted task: $id');
    } catch (e, stack) {
      _logger.error('Failed to delete task: $id', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> completeTask(String id) async {
    try {
      final userId = client.auth.currentUser?.id;
      await db.completeTask(id, completedBy: userId);

      // Enqueue for sync
      await db.enqueue(id, 'upsert_task');

      _logger.info('Completed task: $id');
    } catch (e, stack) {
      _logger.error('Failed to complete task: $id', e, stack);
      rethrow;
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() {
    try {
      return db.watchOpenTasks().asyncMap((localTasks) async {
        return TaskMapper.toDomainList(localTasks);
      });
    } catch (e, stack) {
      _logger.error('Failed to create task watch stream', e, stack);
      return Stream.error(e, stack);
    }
  }

  /// Watch tasks for a specific note
  Stream<List<domain.Task>> watchTasksForNote(String noteId) {
    try {
      return db.watchTasksForNote(noteId).asyncMap((localTasks) async {
        return TaskMapper.toDomainList(localTasks);
      });
    } catch (e, stack) {
      _logger.error('Failed to create task watch stream for note: $noteId', e, stack);
      return Stream.error(e, stack);
    }
  }

  /// Get completed tasks
  Future<List<domain.Task>> getCompletedTasks({
    DateTime? since,
    int? limit,
  }) async {
    try {
      final localTasks = await db.getCompletedTasks(since: since, limit: limit);
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get completed tasks', e, stack);
      return [];
    }
  }

  /// Get overdue tasks
  Future<List<domain.Task>> getOverdueTasks() async {
    try {
      final localTasks = await db.getOverdueTasks();
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get overdue tasks', e, stack);
      return [];
    }
  }

  /// Get tasks by date range
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    domain.TaskStatus? status,
  }) async {
    try {
      final localTasks = await db.getTasksByDateRange(
        startDate: startDate,
        endDate: endDate,
        status: status != null ? _mapStatusToDb(status) : null,
      );
      return TaskMapper.toDomainList(localTasks);
    } catch (e, stack) {
      _logger.error('Failed to get tasks by date range', e, stack);
      return [];
    }
  }

  /// Toggle task status (open <-> completed)
  Future<void> toggleTaskStatus(String id) async {
    try {
      await db.toggleTaskStatus(id);

      // Enqueue for sync
      await db.enqueue(id, 'upsert_task');

      _logger.info('Toggled task status: $id');
    } catch (e, stack) {
      _logger.error('Failed to toggle task status: $id', e, stack);
      rethrow;
    }
  }

  /// Delete all tasks for a note
  Future<void> deleteTasksForNote(String noteId) async {
    try {
      await db.deleteTasksForNote(noteId);

      // Note: Individual task deletions will be handled by sync mechanism
      _logger.info('Deleted all tasks for note: $noteId');
    } catch (e, stack) {
      _logger.error('Failed to delete tasks for note: $noteId', e, stack);
      rethrow;
    }
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    try {
      final allTasks = await getAllTasks();
      final completedTasks = allTasks.where((t) => t.status == domain.TaskStatus.completed);
      final pendingTasks = allTasks.where((t) => t.status == domain.TaskStatus.pending);
      final inProgressTasks = allTasks.where((t) => t.status == domain.TaskStatus.inProgress);
      final overdueTasks = allTasks.where((t) =>
          t.dueDate != null &&
          t.dueDate!.isBefore(DateTime.now()) &&
          t.status != domain.TaskStatus.completed);

      return {
        'total': allTasks.length,
        'completed': completedTasks.length,
        'pending': pendingTasks.length,
        'in_progress': inProgressTasks.length,
        'overdue': overdueTasks.length,
      };
    } catch (e, stack) {
      _logger.error('Failed to get task statistics', e, stack);
      return {};
    }
  }

  /// Get tasks by priority
  Future<List<domain.Task>> getTasksByPriority(domain.TaskPriority priority) async {
    try {
      final allTasks = await getAllTasks();
      return allTasks.where((task) => task.priority == priority).toList();
    } catch (e, stack) {
      _logger.error('Failed to get tasks by priority: $priority', e, stack);
      return [];
    }
  }

  /// Search tasks by content
  Future<List<domain.Task>> searchTasks(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllTasks();
      }

      final allTasks = await getAllTasks();
      final normalizedQuery = query.toLowerCase();

      return allTasks.where((task) {
        final matchesTitle = task.title.toLowerCase().contains(normalizedQuery);
        final matchesDescription = task.description?.toLowerCase().contains(normalizedQuery) ?? false;
        return matchesTitle || matchesDescription;
      }).toList();
    } catch (e, stack) {
      _logger.error('Failed to search tasks with query: $query', e, stack);
      return [];
    }
  }

  /// Update task priority
  Future<void> updateTaskPriority(String id, domain.TaskPriority priority) async {
    try {
      final task = await getTaskById(id);
      if (task == null) {
        throw Exception('Task not found: $id');
      }

      final updatedTask = task.copyWith(priority: priority);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error('Failed to update task priority: $id', e, stack);
      rethrow;
    }
  }

  /// Update task due date
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    try {
      final task = await getTaskById(id);
      if (task == null) {
        throw Exception('Task not found: $id');
      }

      final updatedTask = task.copyWith(dueDate: dueDate);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error('Failed to update task due date: $id', e, stack);
      rethrow;
    }
  }

  /// Add tag to task
  Future<void> addTagToTask(String taskId, String tag) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) {
        throw Exception('Task not found: $taskId');
      }

      final updatedTags = [...task.tags];
      if (!updatedTags.contains(tag)) {
        updatedTags.add(tag);
        final updatedTask = task.copyWith(tags: updatedTags);
        await updateTask(updatedTask);
      }
    } catch (e, stack) {
      _logger.error('Failed to add tag to task: $taskId', e, stack);
      rethrow;
    }
  }

  /// Remove tag from task
  Future<void> removeTagFromTask(String taskId, String tag) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) {
        throw Exception('Task not found: $taskId');
      }

      final updatedTags = task.tags.where((t) => t != tag).toList();
      final updatedTask = task.copyWith(tags: updatedTags);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error('Failed to remove tag from task: $taskId', e, stack);
      rethrow;
    }
  }

  /// Sync tasks with note content
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) async {
    try {
      await db.syncTasksWithNoteContent(noteId, noteContent);
      _logger.info('Synced tasks with note content: $noteId');
    } catch (e, stack) {
      _logger.error('Failed to sync tasks with note content: $noteId', e, stack);
      rethrow;
    }
  }

  /// Create subtask
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
    domain.TaskPriority priority = domain.TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    try {
      final parentTask = await getTaskById(parentTaskId);
      if (parentTask == null) {
        throw Exception('Parent task not found: $parentTaskId');
      }

      final subtask = domain.Task(
        id: _uuid.v4(),
        noteId: parentTask.noteId,
        title: title,
        description: description,
        status: domain.TaskStatus.pending,
        priority: priority,
        dueDate: dueDate,
        completedAt: null,
        tags: [],
        metadata: {'parentTaskId': parentTaskId},
      );

      return await createTask(subtask);
    } catch (e, stack) {
      _logger.error('Failed to create subtask for: $parentTaskId', e, stack);
      rethrow;
    }
  }

  /// Get subtasks for a parent task
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async {
    try {
      final allTasks = await getAllTasks();
      return allTasks.where((task) =>
          task.metadata['parentTaskId'] == parentTaskId).toList();
    } catch (e, stack) {
      _logger.error('Failed to get subtasks for: $parentTaskId', e, stack);
      return [];
    }
  }

  // Private helper methods

  /// Map domain TaskStatus to database TaskStatus
  TaskStatus _mapStatusToDb(domain.TaskStatus status) {
    switch (status) {
      case domain.TaskStatus.pending:
        return TaskStatus.open;
      case domain.TaskStatus.inProgress:
        return TaskStatus.open; // Map in-progress to open in db
      case domain.TaskStatus.completed:
        return TaskStatus.completed;
      case domain.TaskStatus.cancelled:
        return TaskStatus.cancelled;
    }
  }

  /// Map domain TaskPriority to database TaskPriority
  TaskPriority _mapPriorityToDb(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return TaskPriority.low;
      case domain.TaskPriority.medium:
        return TaskPriority.medium;
      case domain.TaskPriority.high:
        return TaskPriority.high;
      case domain.TaskPriority.urgent:
        return TaskPriority.urgent;
    }
  }

  /// Validate task data
  bool _validateTask(domain.Task task) {
    if (task.title.trim().isEmpty) {
      _logger.warning('Task validation failed: empty title');
      return false;
    }

    if (task.noteId.trim().isEmpty) {
      _logger.warning('Task validation failed: empty noteId');
      return false;
    }

    if (task.dueDate != null && task.completedAt != null &&
        task.dueDate!.isAfter(task.completedAt!)) {
      _logger.warning('Task validation failed: dueDate after completedAt');
      return false;
    }

    return true;
  }
}