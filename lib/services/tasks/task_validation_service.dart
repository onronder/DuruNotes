import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;

/// Result of task validation
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(List<String> errors) =>
      ValidationResult(isValid: false, errors: errors);
}

/// Service responsible for task validation
class TaskValidationService {
  TaskValidationService({
    required ITaskRepository repository,
    AppLogger? logger,
  }) : _repository = repository,
       _logger = logger ?? LoggerFactory.instance;

  final ITaskRepository _repository;
  final AppLogger _logger;

  /// Helper to get parentTaskId from task metadata
  String? _getParentTaskId(domain.Task task) {
    return task.metadata['parentTaskId'] as String?;
  }

  // Validation constraints
  static const int maxContentLength = 1000;
  static const int maxHierarchyDepth = 10;
  static const int maxChildrenPerTask = 100;

  /// Validate task data before creation or update
  ValidationResult validateTask({
    required String content,
    String? parentTaskId,
    DateTime? dueDate,
    domain.TaskPriority? priority,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate content
    if (content.isEmpty) {
      errors.add('Task content cannot be empty');
    } else if (content.length > maxContentLength) {
      errors.add(
        'Task content exceeds maximum length of $maxContentLength characters',
      );
    }

    // Validate due date
    if (dueDate != null) {
      final now = DateTime.now();
      if (dueDate.isBefore(now.subtract(const Duration(days: 1)))) {
        warnings.add('Due date is in the past');
      }
    }

    // Validate priority
    if (priority != null) {
      // Priority is an enum, so it's always valid
      // But we can add business logic here if needed
    }

    // Log validation result
    if (errors.isNotEmpty) {
      _logger.debug(
        '[TaskValidationService] Validation failed',
        data: {'errors': errors, 'warnings': warnings},
      );
    }

    return errors.isEmpty
        ? ValidationResult(isValid: true, warnings: warnings)
        : ValidationResult(isValid: false, errors: errors, warnings: warnings);
  }

  /// Check if a task can be deleted
  Future<bool> canDelete(String taskId) async {
    try {
      _logger.debug(
        '[TaskValidationService] Checking if task can be deleted',
        data: {'taskId': taskId},
      );

      // Check if task exists
      final task = await _repository.getTaskById(taskId);
      if (task == null) {
        _logger.warning(
          '[TaskValidationService] Task not found',
          data: {'taskId': taskId},
        );
        return false;
      }

      // Check if task has subtasks
      final allTasks = await _repository.getAllTasks();
      final hasSubtasks = allTasks.any((t) => _getParentTaskId(t) == taskId);

      if (hasSubtasks) {
        _logger.info(
          '[TaskValidationService] Cannot delete task with subtasks',
          data: {'taskId': taskId},
        );
        return false;
      }

      return true;
    } catch (e, stack) {
      _logger.error(
        '[TaskValidationService] Failed to check delete permission',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return false;
    }
  }

  /// Check if a task can be moved to a target parent
  Future<bool> canMove(String taskId, String? targetParentId) async {
    try {
      _logger.debug(
        '[TaskValidationService] Checking if task can be moved',
        data: {'taskId': taskId, 'targetParentId': targetParentId},
      );

      // Cannot move to itself
      if (taskId == targetParentId) {
        _logger.warning('[TaskValidationService] Cannot move task to itself');
        return false;
      }

      // Check if task exists
      final task = await _repository.getTaskById(taskId);
      if (task == null) {
        _logger.warning(
          '[TaskValidationService] Task not found',
          data: {'taskId': taskId},
        );
        return false;
      }

      // If no target parent, it's a root task - always allowed
      if (targetParentId == null) {
        return true;
      }

      // Check if target parent exists
      final targetParent = await _repository.getTaskById(targetParentId);
      if (targetParent == null) {
        _logger.warning(
          '[TaskValidationService] Target parent not found',
          data: {'targetParentId': targetParentId},
        );
        return false;
      }

      // Check if tasks are in the same note
      if (task.noteId != targetParent.noteId) {
        _logger.warning(
          '[TaskValidationService] Cannot move task to different note',
          data: {
            'taskId': taskId,
            'taskNote': task.noteId,
            'targetNote': targetParent.noteId,
          },
        );
        return false;
      }

      // Check for circular dependency
      if (await _wouldCreateCycle(taskId, targetParentId)) {
        _logger.warning(
          '[TaskValidationService] Move would create circular dependency',
          data: {'taskId': taskId, 'targetParentId': targetParentId},
        );
        return false;
      }

      // Check hierarchy depth
      final targetDepth = await _getTaskDepth(targetParentId);
      if (targetDepth >= maxHierarchyDepth - 1) {
        _logger.warning(
          '[TaskValidationService] Move would exceed max hierarchy depth',
          data: {'targetDepth': targetDepth, 'maxDepth': maxHierarchyDepth},
        );
        return false;
      }

      // Check number of children for target parent
      final targetChildren = await _getChildCount(targetParentId);
      if (targetChildren >= maxChildrenPerTask) {
        _logger.warning(
          '[TaskValidationService] Target parent has too many children',
          data: {
            'childCount': targetChildren,
            'maxChildren': maxChildrenPerTask,
          },
        );
        return false;
      }

      return true;
    } catch (e, stack) {
      _logger.error(
        '[TaskValidationService] Failed to check move permission',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'targetParentId': targetParentId},
      );
      return false;
    }
  }

  /// Check if moving a task would create a cycle
  Future<bool> _wouldCreateCycle(String taskId, String targetParentId) async {
    final allTasks = await _repository.getAllTasks();
    final taskMap = {for (final task in allTasks) task.id: task};

    // Check if targetParentId is a descendant of taskId
    String? currentId = targetParentId;
    final visited = <String>{};

    while (currentId != null && !visited.contains(currentId)) {
      if (currentId == taskId) {
        return true; // Cycle detected
      }
      visited.add(currentId);
      currentId = taskMap[currentId] != null
          ? _getParentTaskId(taskMap[currentId]!)
          : null;
    }

    return false;
  }

  /// Get the depth of a task in the hierarchy
  Future<int> _getTaskDepth(String taskId) async {
    final allTasks = await _repository.getAllTasks();
    final taskMap = {for (final task in allTasks) task.id: task};

    int depth = 0;
    String? currentId = taskMap[taskId] != null
        ? _getParentTaskId(taskMap[taskId]!)
        : null;

    while (currentId != null && depth < maxHierarchyDepth) {
      depth++;
      currentId = taskMap[currentId] != null
          ? _getParentTaskId(taskMap[currentId]!)
          : null;
    }

    return depth;
  }

  /// Get the number of direct children for a task
  Future<int> _getChildCount(String taskId) async {
    final allTasks = await _repository.getAllTasks();
    return allTasks.where((t) => _getParentTaskId(t) == taskId).length;
  }

  /// Validate bulk task operations
  Future<ValidationResult> validateBulkOperation({
    required List<String> taskIds,
    required String operation,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];

    if (taskIds.isEmpty) {
      errors.add('No tasks selected for $operation');
      return ValidationResult.invalid(errors);
    }

    if (taskIds.length > 100) {
      warnings.add('Large number of tasks selected. Operation may take time.');
    }

    // Check each task
    for (final taskId in taskIds) {
      final task = await _repository.getTaskById(taskId);
      if (task == null) {
        errors.add('Task $taskId not found');
      }
    }

    return errors.isEmpty
        ? ValidationResult(isValid: true, warnings: warnings)
        : ValidationResult(isValid: false, errors: errors, warnings: warnings);
  }
}
