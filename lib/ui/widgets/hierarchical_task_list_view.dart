import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/tasks/domain_task_hierarchy_node.dart';
import 'package:duru_notes/ui/widgets/tasks/domain_task_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Hierarchical task list view with tree structure and progress tracking
/// Pure domain implementation using ITaskRepository
class HierarchicalTaskListView extends ConsumerStatefulWidget {
  const HierarchicalTaskListView({
    super.key,
    required this.showCompleted,
    this.noteId,
  });

  final bool showCompleted;
  final String? noteId; // If provided, show only tasks for this note

  @override
  ConsumerState<HierarchicalTaskListView> createState() =>
      _HierarchicalTaskListViewState();
}

class _HierarchicalTaskListViewState
    extends ConsumerState<HierarchicalTaskListView> {
  AppLogger get _logger => ref.read(loggerProvider);

  @override
  Widget build(BuildContext context) {
    final taskRepository = ref.watch(taskCoreRepositoryProvider);

    if (taskRepository == null) {
      return const Center(child: Text('Task repository not available'));
    }

    final taskController = ref.watch(domainTaskControllerProvider);

    final Stream<List<domain.Task>> taskStream = widget.noteId != null
        ? taskController.watchTasksForNote(
            widget.noteId!,
            includeCompleted: widget.showCompleted,
          )
        : taskController.watchAllTasks(includeCompleted: widget.showCompleted);

    return StreamBuilder<List<domain.Task>>(
      stream: taskStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var tasks = snapshot.data ?? [];

        // Filter completed tasks if needed
        if (!widget.showCompleted) {
          tasks = tasks
              .where((t) => t.status != domain.TaskStatus.completed)
              .toList();
        }

        if (tasks.isEmpty) {
          return EmptyTaskGroup(
            title: 'No tasks found',
            message: widget.showCompleted
                ? 'Create a new task to get started'
                : 'All tasks completed! 🎉\nCreate a new task or show completed tasks.',
            action: ElevatedButton.icon(
              onPressed: () => _showCreateTaskDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            ),
          );
        }

        final rootNodes = _buildTaskHierarchy(tasks);

        return Expanded(
          child: DomainTaskTreeWidget(
            rootNodes: rootNodes,
            showProgress: true,
            maxDepth: 5,
            onTaskChanged: () => setState(() {}),
          ),
        );
      },
    );
  }

  /// Build task hierarchy from domain tasks
  List<DomainTaskHierarchyNode> _buildTaskHierarchy(List<domain.Task> tasks) {
    final nodeMap = <String, DomainTaskHierarchyNode>{};
    final rootNodes = <DomainTaskHierarchyNode>[];

    // First pass: create all nodes
    for (final task in tasks) {
      nodeMap[task.id] = DomainTaskHierarchyNode(task: task, children: []);
    }

    // Second pass: build hierarchy
    for (final task in tasks) {
      final node = nodeMap[task.id]!;

      // Check if task has parent in metadata
      final parentTaskId = task.metadata['parentTaskId'] as String?;
      if (parentTaskId != null && nodeMap.containsKey(parentTaskId)) {
        final parent = nodeMap[parentTaskId]!;
        parent.children.add(node);
        node.parent = parent;
      } else {
        rootNodes.add(node);
      }
    }

    return rootNodes;
  }

  Future<void> _showCreateTaskDialog(BuildContext context) async {
    final taskRepository = ref.read(taskCoreRepositoryProvider);
    if (taskRepository == null) return;

    final taskController = ref.read(domainTaskControllerProvider);

    // Use TextEditingController to capture user input
    final controller = TextEditingController();

    // Show task creation dialog
    final taskContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task description...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    // Clean up controller
    controller.dispose();

    if (taskContent != null && taskContent.isNotEmpty) {
      try {
        final createdTask = await taskController.createTask(
          noteId: widget.noteId,
          title: taskContent,
          priority: domain.TaskPriority.medium,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created successfully')),
          );
        }
        _logger.info(
          'Created hierarchical task',
          data: {
            'noteId': createdTask.noteId,
            'taskId': createdTask.id,
            'isStandalone':
                createdTask.noteId == DomainTaskController.standaloneNoteId,
          },
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to create hierarchical task',
          error: error,
          stackTrace: stackTrace,
          data: {'noteId': widget.noteId},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not create task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_showCreateTaskDialog(context)),
              ),
            ),
          );
        }
      }
    }
  }
}

/// Hierarchical task view mode for enhanced task list screen
class HierarchicalTaskViewMode extends StatelessWidget {
  const HierarchicalTaskViewMode({super.key, required this.showCompleted});

  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    return HierarchicalTaskListView(showCompleted: showCompleted);
  }
}

/// Task hierarchy management panel using ITaskRepository
class TaskHierarchyPanel extends ConsumerWidget {
  const TaskHierarchyPanel({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Task Hierarchy',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) => _handleBulkAction(context, ref, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'expand_all',
                    child: Row(
                      children: [
                        Icon(Icons.unfold_more, size: 16),
                        SizedBox(width: 8),
                        Text('Expand All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'collapse_all',
                    child: Row(
                      children: [
                        Icon(Icons.unfold_less, size: 16),
                        SizedBox(width: 8),
                        Text('Collapse All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'complete_all_root',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 16),
                        SizedBox(width: 8),
                        Text('Complete All Root Tasks'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cleanup_completed',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services, size: 16),
                        SizedBox(width: 8),
                        Text('Archive Completed'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBulkAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'expand_all':
        // This would need to communicate with parent widget
        break;
      case 'collapse_all':
        // This would need to communicate with parent widget
        break;
      case 'complete_all_root':
        _completeAllRootTasks(context, ref);
        break;
      case 'cleanup_completed':
        _cleanupCompletedTasks(context, ref);
        break;
    }
  }

  Future<void> _completeAllRootTasks(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final noteId = this.noteId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete All Root Tasks'),
        content: const Text(
          'This will mark all top-level tasks as completed. '
          'Subtasks will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (ref.read(taskCoreRepositoryProvider) == null) return;

        final controller = ref.read(domainTaskControllerProvider);
        final tasks = await controller.getTasksForNote(noteId);
        final rootTasks = tasks
            .where((t) => t.metadata['parentTaskId'] == null)
            .toList();

        for (final task in rootTasks) {
          await controller.setStatus(task.id, domain.TaskStatus.completed);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Completed ${rootTasks.length} root tasks')),
          );
        }
        ref.read(loggerProvider)
            .info(
              'Completed all root tasks',
              data: {'noteId': noteId, 'count': rootTasks.length},
            );
      } catch (error, stackTrace) {
        ref.read(loggerProvider)
            .error(
              'Failed to complete all root tasks',
              error: error,
              stackTrace: stackTrace,
              data: {'noteId': noteId},
            );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not complete tasks. Please try again.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_completeAllRootTasks(context, ref)),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _cleanupCompletedTasks(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final noteId = this.noteId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Completed Tasks'),
        content: const Text(
          'This will remove all completed tasks from the hierarchy. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (ref.read(taskCoreRepositoryProvider) == null) return;

        final controller = ref.read(domainTaskControllerProvider);
        final tasks = await controller.getTasksForNote(noteId);
        final completedTasks = tasks
            .where((t) => t.status == domain.TaskStatus.completed)
            .toList();

        for (final task in completedTasks) {
          await controller.deleteTask(task.id);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Archived ${completedTasks.length} completed tasks',
              ),
            ),
          );
        }
        ref.read(loggerProvider)
            .info(
              'Archived completed tasks',
              data: {'noteId': noteId, 'count': completedTasks.length},
            );
      } catch (error, stackTrace) {
        ref.read(loggerProvider)
            .error(
              'Failed to archive completed tasks',
              error: error,
              stackTrace: stackTrace,
              data: {'noteId': noteId},
            );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not archive tasks. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () =>
                    unawaited(_cleanupCompletedTasks(context, ref)),
              ),
            ),
          );
        }
      }
    }
  }
}

/// Tree widget replacement is now handled by DomainTaskTreeWidget
