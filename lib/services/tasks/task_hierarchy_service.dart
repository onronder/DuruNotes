import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;

/// Represents a task with its hierarchy information
class TaskHierarchyNode {
  const TaskHierarchyNode({
    required this.task,
    required this.children,
    required this.level,
    required this.path,
  });

  final domain.Task task;
  final List<TaskHierarchyNode> children;
  final int level;
  final List<String> path; // IDs from root to this task
}

/// Service responsible for managing task hierarchies and parent-child relationships
class TaskHierarchyService {
  TaskHierarchyService({required ITaskRepository repository, AppLogger? logger})
    : _repository = repository,
      _logger = logger ?? LoggerFactory.instance;

  final ITaskRepository _repository;
  final AppLogger _logger;

  /// Helper to get parentTaskId from task metadata
  String? _getParentTaskId(domain.Task task) {
    return task.metadata['parentTaskId'] as String?;
  }

  /// Helper to get position from task metadata
  int? _getPosition(domain.Task task) {
    return task.metadata['position'] as int?;
  }

  /// Get all subtasks of a parent task
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async {
    try {
      _logger.debug(
        '[TaskHierarchyService] Getting subtasks',
        data: {'parentTaskId': parentTaskId},
      );

      final allTasks = await _repository.getAllTasks();
      final subtasks = allTasks
          .where((task) => _getParentTaskId(task) == parentTaskId)
          .toList();

      // Sort by position
      subtasks.sort(
        (a, b) => (_getPosition(a) ?? 0).compareTo(_getPosition(b) ?? 0),
      );

      _logger.info(
        '[TaskHierarchyService] Found subtasks',
        data: {'parentTaskId': parentTaskId, 'count': subtasks.length},
      );

      return subtasks;
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to get subtasks',
        error: e,
        stackTrace: stack,
        data: {'parentTaskId': parentTaskId},
      );
      return [];
    }
  }

  /// Move a task to a new parent
  Future<bool> moveTask(String taskId, String? newParentId) async {
    try {
      _logger.info(
        '[TaskHierarchyService] Moving task',
        data: {'taskId': taskId, 'newParentId': newParentId},
      );

      // Validate the move (prevent circular dependencies)
      if (newParentId != null && !(await canMove(taskId, newParentId))) {
        _logger.warning(
          '[TaskHierarchyService] Move would create circular dependency',
          data: {'taskId': taskId, 'newParentId': newParentId},
        );
        return false;
      }

      // Get the task
      final task = await _repository.getTaskById(taskId);
      if (task == null) {
        _logger.warning(
          '[TaskHierarchyService] Task not found',
          data: {'taskId': taskId},
        );
        return false;
      }

      // Update parent
      final updatedMetadata = Map<String, dynamic>.from(task.metadata);
      if (newParentId != null) {
        updatedMetadata['parentTaskId'] = newParentId;
      } else {
        updatedMetadata.remove('parentTaskId');
      }
      updatedMetadata['updatedAt'] = DateTime.now().toIso8601String();

      final updated = task.copyWith(metadata: updatedMetadata);

      await _repository.updateTask(updated);

      _logger.info(
        '[TaskHierarchyService] Task moved successfully',
        data: {'taskId': taskId, 'newParentId': newParentId},
      );

      return true;
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to move task',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'newParentId': newParentId},
      );
      return false;
    }
  }

  /// Build complete hierarchy tree for a root task
  Future<TaskHierarchyNode?> buildHierarchy(String rootId) async {
    try {
      _logger.debug(
        '[TaskHierarchyService] Building hierarchy',
        data: {'rootId': rootId},
      );

      final rootTask = await _repository.getTaskById(rootId);
      if (rootTask == null) return null;

      final allTasks = await _repository.getAllTasks();
      final taskMap = {for (final task in allTasks) task.id: task};

      return _buildNodeRecursive(
        task: rootTask,
        taskMap: taskMap,
        level: 0,
        path: [],
      );
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to build hierarchy',
        error: e,
        stackTrace: stack,
        data: {'rootId': rootId},
      );
      return null;
    }
  }

  /// Recursively build hierarchy nodes
  TaskHierarchyNode _buildNodeRecursive({
    required domain.Task task,
    required Map<String, domain.Task> taskMap,
    required int level,
    required List<String> path,
  }) {
    final currentPath = [...path, task.id];

    // Find children
    final children =
        taskMap.values.where((t) => _getParentTaskId(t) == task.id).toList()
          ..sort(
            (a, b) => (_getPosition(a) ?? 0).compareTo(_getPosition(b) ?? 0),
          );

    // Build child nodes recursively
    final childNodes = children
        .map(
          (child) => _buildNodeRecursive(
            task: child,
            taskMap: taskMap,
            level: level + 1,
            path: currentPath,
          ),
        )
        .toList();

    return TaskHierarchyNode(
      task: task,
      children: childNodes,
      level: level,
      path: currentPath,
    );
  }

  /// Get all tasks in a flat list with hierarchy information
  Future<List<TaskHierarchyNode>> getFlatHierarchy(String? noteId) async {
    try {
      final tasks = noteId != null
          ? await _repository.getTasksForNote(noteId)
          : await _repository.getAllTasks();

      // Build hierarchy for root tasks
      final rootTasks = tasks
          .where((t) => _getParentTaskId(t) == null)
          .toList();
      final taskMap = {for (final task in tasks) task.id: task};
      final flatList = <TaskHierarchyNode>[];

      for (final root in rootTasks) {
        _addToFlatList(
          task: root,
          taskMap: taskMap,
          flatList: flatList,
          level: 0,
          path: [],
        );
      }

      return flatList;
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to get flat hierarchy',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      return [];
    }
  }

  /// Add task and its children to flat list
  void _addToFlatList({
    required domain.Task task,
    required Map<String, domain.Task> taskMap,
    required List<TaskHierarchyNode> flatList,
    required int level,
    required List<String> path,
  }) {
    final currentPath = [...path, task.id];

    // Find children
    final children =
        taskMap.values.where((t) => _getParentTaskId(t) == task.id).toList()
          ..sort(
            (a, b) => (_getPosition(a) ?? 0).compareTo(_getPosition(b) ?? 0),
          );

    // Add current node
    flatList.add(
      TaskHierarchyNode(
        task: task,
        children: children
            .map(
              (child) => _buildNodeRecursive(
                task: child,
                taskMap: taskMap,
                level: level + 1,
                path: currentPath,
              ),
            )
            .toList(),
        level: level,
        path: currentPath,
      ),
    );

    // Add children recursively
    for (final child in children) {
      _addToFlatList(
        task: child,
        taskMap: taskMap,
        flatList: flatList,
        level: level + 1,
        path: currentPath,
      );
    }
  }

  /// Check if a task can be moved to a new parent without creating cycles
  Future<bool> canMove(String taskId, String targetParentId) async {
    try {
      if (taskId == targetParentId) return false;

      // Check if targetParent is a descendant of task
      final descendants = await _getAllDescendants(taskId);
      return !descendants.contains(targetParentId);
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to check move validity',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'targetParentId': targetParentId},
      );
      return false;
    }
  }

  /// Get all descendant IDs of a task
  Future<Set<String>> _getAllDescendants(String taskId) async {
    final allTasks = await _repository.getAllTasks();
    final descendants = <String>{};

    void addDescendants(String parentId) {
      for (final task in allTasks) {
        if (_getParentTaskId(task) == parentId &&
            !descendants.contains(task.id)) {
          descendants.add(task.id);
          addDescendants(task.id); // Recursive call
        }
      }
    }

    addDescendants(taskId);
    return descendants;
  }

  /// Get task depth in hierarchy
  Future<int> getTaskDepth(String taskId) async {
    try {
      final task = await _repository.getTaskById(taskId);
      if (task == null) return 0;

      int depth = 0;
      String? currentParentId = _getParentTaskId(task);

      while (currentParentId != null && depth < 10) {
        // Max depth safety
        final parent = await _repository.getTaskById(currentParentId);
        if (parent == null) break;
        depth++;
        currentParentId = _getParentTaskId(parent);
      }

      return depth;
    } catch (e, stack) {
      _logger.error(
        '[TaskHierarchyService] Failed to get task depth',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      return 0;
    }
  }
}
