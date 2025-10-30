import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:uuid/uuid.dart';

/// Service responsible for task CRUD operations
class TaskCrudService {
  TaskCrudService({
    required ITaskRepository repository,
    required AppDb db, // Kept for backward compatibility
    AppLogger? logger,
  }) : _repository = repository,
       _logger = logger ?? LoggerFactory.instance,
       _uuid = const Uuid();

  final ITaskRepository _repository;
  final AppLogger _logger;
  final Uuid _uuid;

  /// Create a new task
  Future<domain.Task?> createTask({
    required String noteId,
    required String content,
    bool isCompleted = false,
    int? blockLineNumber,
    DateTime? dueDate,
    domain.TaskPriority? priority,
    String? parentTaskId,
    int? reminderId,
  }) async {
    try {
      _logger.info(
        '[TaskCrudService] Creating task',
        data: {
          'noteId': noteId,
          'content': content,
          'isCompleted': isCompleted,
          'parentTaskId': parentTaskId,
        },
      );

      final taskId = _uuid.v4();
      final now = DateTime.now();

      // Create the task entity
      final task = domain.Task(
        id: taskId,
        noteId: noteId,
        title: content,
        description: null,
        status: isCompleted
            ? domain.TaskStatus.completed
            : domain.TaskStatus.pending,
        priority: priority ?? domain.TaskPriority.medium,
        dueDate: dueDate,
        completedAt: isCompleted ? now : null,
        createdAt: now, // Required domain parameter
        updatedAt: now, // Required domain parameter
        tags: [],
        metadata: {
          'blockLineNumber': blockLineNumber,
          'parentTaskId': parentTaskId,
          'position': 0,
          'reminderId': reminderId,
        },
      );

      // Save via repository
      final created = await _repository.createTask(task);

      _logger.info(
        '[TaskCrudService] Task created successfully',
        data: {'taskId': created.id},
      );

      return created;
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to create task',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Update an existing task
  Future<domain.Task?> updateTask({
    required String taskId,
    String? content,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? dueDate,
    domain.TaskPriority? priority,
    String? parentTaskId,
    int? reminderId,
    bool clearReminderId = false,
  }) async {
    try {
      _logger.debug(
        '[TaskCrudService] Updating task',
        data: {
          'taskId': taskId,
          'updates': {
            if (content != null) 'content': content,
            if (isCompleted != null) 'isCompleted': isCompleted,
            if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
            if (priority != null) 'priority': priority.toString(),
          },
        },
      );

      // Get existing task
      final existing = await _repository.getTaskById(taskId);
      if (existing == null) {
        _logger.warning(
          '[TaskCrudService] Task not found',
          data: {'taskId': taskId},
        );
        return null;
      }

      // Update the task
      final updatedMetadata = Map<String, dynamic>.from(existing.metadata);
      if (parentTaskId != null) {
        updatedMetadata['parentTaskId'] = parentTaskId;
      }
      if (clearReminderId) {
        updatedMetadata.remove('reminderId');
      } else if (reminderId != null) {
        updatedMetadata['reminderId'] = reminderId;
      }
      updatedMetadata['updatedAt'] = DateTime.now().toIso8601String();

      final updated = existing.copyWith(
        title: content ?? existing.title,
        status: isCompleted == true
            ? domain.TaskStatus.completed
            : isCompleted == false
            ? domain.TaskStatus.pending
            : existing.status,
        completedAt: completedAt ?? existing.completedAt,
        dueDate: dueDate ?? existing.dueDate,
        priority: priority ?? existing.priority,
        metadata: updatedMetadata,
      );

      // Save via repository
      final saved = await _repository.updateTask(updated);

      _logger.info(
        '[TaskCrudService] Task updated successfully',
        data: {'taskId': saved.id},
      );

      return saved;
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to update task',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return null;
    }
  }

  /// Delete a task
  Future<bool> deleteTask(String taskId) async {
    try {
      _logger.info('[TaskCrudService] Deleting task', data: {'taskId': taskId});

      await _repository.deleteTask(taskId);

      _logger.info(
        '[TaskCrudService] Task deleted successfully',
        data: {'taskId': taskId},
      );

      return true;
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to delete task',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return false;
    }
  }

  /// Get a task by ID
  Future<domain.Task?> getTask(String taskId) async {
    try {
      return await _repository.getTaskById(taskId);
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to get task',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return null;
    }
  }

  /// Get all tasks for a note
  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    try {
      return await _repository.getTasksForNote(noteId);
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to get tasks for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      return [];
    }
  }

  /// Get all tasks
  Future<List<domain.Task>> getAllTasks() async {
    try {
      return await _repository.getAllTasks();
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to get all tasks',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Toggle task completion status
  Future<domain.Task?> toggleTaskCompletion(String taskId) async {
    try {
      final task = await getTask(taskId);
      if (task == null) return null;

      return await updateTask(
        taskId: taskId,
        isCompleted: !(task.status == domain.TaskStatus.completed),
        completedAt: task.status == domain.TaskStatus.completed
            ? null
            : DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error(
        '[TaskCrudService] Failed to toggle task completion',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return null;
    }
  }
}
