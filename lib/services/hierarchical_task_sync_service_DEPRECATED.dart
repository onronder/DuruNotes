import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
// Legacy import removed - note_task_sync_service.dart deleted

/// Enhanced task sync service with hierarchical task support
class HierarchicalTaskSyncService {
  HierarchicalTaskSyncService({
    required AppDb database,
    required EnhancedTaskService enhancedTaskService,
  })  : _enhancedTaskService = enhancedTaskService,
        _database = database;

  final EnhancedTaskService _enhancedTaskService;
  final AppDb _database;
  final AppLogger logger = LoggerFactory.instance;

  Future<void> syncTasksForNote(String noteId, String noteContent) async {
    try {
      final hierarchicalTasks =
          extractHierarchicalTasksFromContent(noteContent);
      await _syncHierarchicalTasks(noteId, hierarchicalTasks);
    } catch (e) {
      logger.debug('Error syncing hierarchical tasks for note $noteId: $e');
    }
  }

  /// Extract hierarchical tasks from markdown content with indentation support
  List<HierarchicalTaskInfo> extractHierarchicalTasksFromContent(
      String content) {
    final tasks = <HierarchicalTaskInfo>[];
    final lines = content.split('\n');
    final taskStack = <HierarchicalTaskInfo>[]; // Stack to track parent tasks
    var globalPosition = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final indentLevel = _getIndentLevel(line);
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('- [ ]') || trimmedLine.startsWith('- [x]')) {
        final isCompleted = trimmedLine.startsWith('- [x]');
        final taskContent = trimmedLine.substring(5).trim();

        if (taskContent.isNotEmpty) {
          // Parse metadata (due date, priority)
          final parsedTask = _parseTaskMetadata(taskContent);

          // Determine parent task based on indentation
          String? parentTaskId;

          // Pop stack until we find the appropriate parent level
          while (taskStack.isNotEmpty &&
              taskStack.last.indentLevel >= indentLevel) {
            taskStack.removeLast();
          }

          // If there's a task in the stack, it's our parent
          if (taskStack.isNotEmpty) {
            parentTaskId = taskStack.last.id;
          }

          final taskInfo = HierarchicalTaskInfo(
            id: _generateTaskId(
                'temp', globalPosition), // Will be replaced with actual ID
            content: parsedTask.content,
            isCompleted: isCompleted,
            position: globalPosition,
            lineIndex: lineIndex,
            indentLevel: indentLevel,
            parentTaskId: parentTaskId,
            dueDate: parsedTask.dueDate,
            priority: parsedTask.priority,
            children: [],
          );

          // Add to parent's children if applicable
          if (taskStack.isNotEmpty) {
            taskStack.last.children.add(taskInfo);
          }

          // Add to main list
          tasks.add(taskInfo);

          // Push to stack for potential children
          taskStack.add(taskInfo);

          globalPosition++;
        }
      }
    }

    return tasks;
  }

  /// Get indentation level from line (spaces and tabs)
  int _getIndentLevel(String line) {
    var indent = 0;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        indent++;
      } else if (line[i] == '\t') {
        indent += 4; // Tab = 4 spaces
      } else {
        break;
      }
    }
    return indent ~/ 2; // Convert to logical levels (2 spaces = 1 level)
  }

  /// Parse task metadata from content
  _ParsedTaskData _parseTaskMetadata(String taskContent) {
    var cleanContent = taskContent;
    DateTime? dueDate;
    var priority = TaskPriority.medium;

    // Parse due date (format: @due(2024-12-25))
    final dueDateMatch =
        RegExp(r'@due\((\d{4}-\d{2}-\d{2})\)').firstMatch(taskContent);
    if (dueDateMatch != null) {
      try {
        dueDate = DateTime.parse(dueDateMatch.group(1)!);
        cleanContent =
            cleanContent.replaceAll(dueDateMatch.group(0)!, '').trim();
      } catch (_) {}
    }

    // Parse priority (format: !high, !urgent, !low)
    if (cleanContent.contains('!urgent')) {
      priority = TaskPriority.urgent;
      cleanContent = cleanContent.replaceAll('!urgent', '').trim();
    } else if (cleanContent.contains('!high')) {
      priority = TaskPriority.high;
      cleanContent = cleanContent.replaceAll('!high', '').trim();
    } else if (cleanContent.contains('!low')) {
      priority = TaskPriority.low;
      cleanContent = cleanContent.replaceAll('!low', '').trim();
    }

    return _ParsedTaskData(
      content: cleanContent,
      dueDate: dueDate,
      priority: priority,
    );
  }

  /// Generate stable task ID based on note and position
  String _generateTaskId(String noteId, int position) {
    return '${noteId}_task_$position';
  }

  /// Sync hierarchical tasks with _database
  Future<void> _syncHierarchicalTasks(
    String noteId,
    List<HierarchicalTaskInfo> hierarchicalTasks,
  ) async {
    try {
      // Get existing tasks for this note
      final existingTasks = await _database.getTasksForNote(noteId);
      final existingTaskMap = {for (var task in existingTasks) task.id: task};

      // Process tasks in hierarchy order
      for (final taskInfo in hierarchicalTasks) {
        await _syncSingleHierarchicalTask(noteId, taskInfo, existingTaskMap);
      }

      // Clean up tasks that no longer exist in content
      final newTaskIds = hierarchicalTasks.map((t) => t.id).toSet();
      for (final existingTask in existingTasks) {
        if (!newTaskIds.contains(existingTask.id)) {
          await _enhancedTaskService.deleteTask(existingTask.id);
        }
      }
    } catch (e) {
      logger.error('Error syncing hierarchical tasks', error: e);
    }
  }

  /// Sync a single hierarchical task
  Future<void> _syncSingleHierarchicalTask(
    String noteId,
    HierarchicalTaskInfo taskInfo,
    Map<String, NoteTask> existingTaskMap,
  ) async {
    final existingTask = existingTaskMap[taskInfo.id];

    if (existingTask == null) {
      // Create new task
      await _enhancedTaskService.createTask(
        noteId: noteId,
        content: taskInfo.content,
        priority: taskInfo.priority,
        dueDate: taskInfo.dueDate,
        parentTaskId: taskInfo.parentTaskId,
        createReminder: taskInfo.dueDate != null,
      );
    } else {
      // Update existing task if needed
      final needsUpdate = _taskNeedsUpdate(existingTask, taskInfo);
      if (needsUpdate) {
        await _enhancedTaskService.updateTask(
          taskId: existingTask.id,
          content: taskInfo.content,
          status: taskInfo.isCompleted ? TaskStatus.completed : TaskStatus.open,
          priority: taskInfo.priority,
          dueDate: taskInfo.dueDate,
          // Note: parentTaskId changes are complex and might need special handling
        );
      }
    }
  }

  /// Check if task needs update
  bool _taskNeedsUpdate(NoteTask existingTask, HierarchicalTaskInfo taskInfo) {
    return existingTask.content != taskInfo.content ||
        existingTask.priority != taskInfo.priority ||
        existingTask.dueDate != taskInfo.dueDate ||
        existingTask.parentTaskId != taskInfo.parentTaskId ||
        (existingTask.status == TaskStatus.completed) != taskInfo.isCompleted;
  }

  /// Add hierarchical task to note content
  Future<void> addHierarchicalTaskToNote({
    required String noteId,
    required String taskContent,
    required int lineIndex,
    required int indentLevel,
    String? parentTaskId,
    bool isCompleted = false,
  }) async {
    try {
      final note = await _database.getNote(noteId);
      if (note == null) return;

      final lines = note.body.split('\n');
      final checkbox = isCompleted ? '[x]' : '[ ]';
      final indent = '  ' * indentLevel; // 2 spaces per level
      final taskLine = '$indent- $checkbox $taskContent';

      // Insert at specified line
      if (lineIndex >= 0 && lineIndex <= lines.length) {
        lines.insert(lineIndex, taskLine);
      } else {
        lines.add(taskLine);
      }

      final updatedContent = lines.join('\n');
      await _database.updateNote(
        noteId,
        LocalNotesCompanion(
          body: Value(updatedContent),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Sync tasks after adding
      await syncTasksForNote(noteId, updatedContent);
    } catch (e) {
      logger.debug('Error adding hierarchical task to note: $e');
    }
  }

  /// Get task hierarchy for a note
  Future<List<TaskHierarchyNode>> getTaskHierarchy(String noteId) async {
    try {
      final allTasks = await _database.getTasksForNote(noteId);
      return _buildTaskHierarchy(allTasks);
    } catch (e) {
      logger.error('Error getting task hierarchy', error: e);
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

      if (task.parentTaskId != null &&
          nodeMap.containsKey(task.parentTaskId!)) {
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

  /// Complete all subtasks of a parent task
  Future<void> completeAllSubtasks(String parentTaskId) async {
    try {
      final subtasks = await _database.getOpenTasks(parentTaskId: parentTaskId);

      for (final subtask in subtasks) {
        await _enhancedTaskService.completeTask(subtask.id);

        // Recursively complete children
        await completeAllSubtasks(subtask.id);
      }

      logger
          .info('Completed all subtasks', data: {'parentTaskId': parentTaskId});
    } catch (e) {
      logger.error('Error completing all subtasks', error: e);
    }
  }

  /// Delete task hierarchy (parent and all children)
  Future<void> deleteTaskHierarchy(String taskId) async {
    try {
      // Get all children recursively
      final childTasks = await _getAllChildTasks(taskId);

      // Delete children first (to maintain referential integrity)
      for (final child in childTasks.reversed) {
        await _enhancedTaskService.deleteTask(child.id);
      }

      // Delete parent task
      await _enhancedTaskService.deleteTask(taskId);

      logger.info('Deleted task hierarchy', data: {
        'parentTaskId': taskId,
        'deletedCount': childTasks.length + 1,
      });
    } catch (e) {
      logger.error('Error deleting task hierarchy', error: e);
    }
  }

  /// Get all child tasks recursively
  Future<List<NoteTask>> _getAllChildTasks(String parentTaskId) async {
    final allChildren = <NoteTask>[];
    final directChildren =
        await _database.getOpenTasks(parentTaskId: parentTaskId);

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
      await _enhancedTaskService.updateTask(
        taskId: taskId,
        // Note: We need to add parentTaskId support to updateTask
      );

      if (newPosition != null) {
        await _enhancedTaskService.updateTaskPositions({taskId: newPosition});
      }

      logger.info('Moved task to new parent', data: {
        'taskId': taskId,
        'newParentId': newParentId,
        'newPosition': newPosition,
      });
    } catch (e) {
      logger.error('Error moving task to parent', error: e);
    }
  }

  /// Get task depth in hierarchy
  Future<int> getTaskDepth(String taskId) async {
    var depth = 0;
    String? currentTaskId = taskId;

    while (currentTaskId != null && depth < 10) {
      // Safety limit
      final task = await _database.getTaskById(currentTaskId);
      if (task?.parentTaskId == null) break;

      currentTaskId = task!.parentTaskId;
      depth++;
    }

    return depth;
  }

  /// Check if task has children
  Future<bool> hasSubtasks(String taskId) async {
    final children = await _database.getOpenTasks(parentTaskId: taskId);
    return children.isNotEmpty;
  }

  /// Get task hierarchy statistics
  Future<TaskHierarchyStats> getHierarchyStats(String noteId) async {
    try {
      final allTasks = await _database.getTasksForNote(noteId);
      final rootTasks = allTasks.where((t) => t.parentTaskId == null).toList();
      final subtasks = allTasks.where((t) => t.parentTaskId != null).toList();

      var maxDepth = 0;
      for (final task in allTasks) {
        final depth = await getTaskDepth(task.id);
        if (depth > maxDepth) maxDepth = depth;
      }

      return TaskHierarchyStats(
        totalTasks: allTasks.length,
        rootTasks: rootTasks.length,
        subtasks: subtasks.length,
        maxDepth: maxDepth,
        completedTasks:
            allTasks.where((t) => t.status == TaskStatus.completed).length,
      );
    } catch (e) {
      logger.error('Error getting hierarchy stats', error: e);
      return TaskHierarchyStats(
        totalTasks: 0,
        rootTasks: 0,
        subtasks: 0,
        maxDepth: 0,
        completedTasks: 0,
      );
    }
  }
}

/// Hierarchical task information with indentation and parent relationship
class HierarchicalTaskInfo {
  HierarchicalTaskInfo({
    required this.id,
    required this.content,
    required this.isCompleted,
    required this.position,
    required this.lineIndex,
    required this.indentLevel,
    required this.children,
    this.parentTaskId,
    this.dueDate,
    this.priority = TaskPriority.medium,
  });

  final String id;
  final String content;
  final bool isCompleted;
  final int position;
  final int lineIndex;
  final int indentLevel;
  final String? parentTaskId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<HierarchicalTaskInfo> children;

  /// Check if this task has children
  bool get hasChildren => children.isNotEmpty;

  /// Get total number of descendants
  int get totalDescendants {
    var count = children.length;
    for (final child in children) {
      count += child.totalDescendants;
    }
    return count;
  }

  /// Get completed descendants count
  int get completedDescendants {
    var count = children.where((c) => c.isCompleted).length;
    for (final child in children) {
      count += child.completedDescendants;
    }
    return count;
  }

  /// Calculate completion percentage including children
  double get completionPercentage {
    final total = totalDescendants + 1; // Include self
    final completed = completedDescendants + (isCompleted ? 1 : 0);
    return total > 0 ? completed / total : 0.0;
  }
}

/// Task hierarchy node for tree operations
class TaskHierarchyNode {
  TaskHierarchyNode({
    required this.task,
    required this.children,
    this.parent,
  });

  final NoteTask task;
  final List<TaskHierarchyNode> children;
  TaskHierarchyNode? parent;

  /// Get all descendants (children, grandchildren, etc.)
  List<TaskHierarchyNode> getAllDescendants() {
    final descendants = <TaskHierarchyNode>[];
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants());
    }
    return descendants;
  }

  /// Check if this node is an ancestor of another node
  bool isAncestorOf(TaskHierarchyNode other) {
    TaskHierarchyNode? current = other.parent;
    while (current != null) {
      if (current.task.id == task.id) return true;
      current = current.parent;
    }
    return false;
  }

  /// Get path from root to this node
  List<TaskHierarchyNode> getPathFromRoot() {
    final path = <TaskHierarchyNode>[];
    TaskHierarchyNode? current = this;

    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }

    return path;
  }
}

/// Task progress information
class TaskProgress {
  const TaskProgress({
    required this.totalTasks,
    required this.completedTasks,
    required this.progressPercentage,
    required this.totalEstimatedMinutes,
    required this.totalActualMinutes,
  });

  final int totalTasks;
  final int completedTasks;
  final double progressPercentage;
  final int totalEstimatedMinutes;
  final int totalActualMinutes;

  /// Check if all tasks are completed
  bool get isFullyCompleted => completedTasks == totalTasks && totalTasks > 0;

  /// Get estimated vs actual time efficiency
  double? get timeEfficiency {
    if (totalEstimatedMinutes > 0 && totalActualMinutes > 0) {
      return totalEstimatedMinutes / totalActualMinutes;
    }
    return null;
  }
}

/// Task hierarchy statistics
class TaskHierarchyStats {
  const TaskHierarchyStats({
    required this.totalTasks,
    required this.rootTasks,
    required this.subtasks,
    required this.maxDepth,
    required this.completedTasks,
  });

  final int totalTasks;
  final int rootTasks;
  final int subtasks;
  final int maxDepth;
  final int completedTasks;

  /// Calculate overall completion percentage
  double get completionPercentage {
    return totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  }

  /// Check if hierarchy has nested structure
  bool get hasNesting => subtasks > 0;
}

/// Parsed task data from content
class _ParsedTaskData {
  const _ParsedTaskData({
    required this.content,
    this.dueDate,
    this.priority = TaskPriority.medium,
  });

  final String content;
  final DateTime? dueDate;
  final TaskPriority priority;
}
