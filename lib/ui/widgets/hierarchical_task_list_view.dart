import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/task_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hierarchical task list view with tree structure and progress tracking
/// Uses UnifiedTaskService for all task operations - no VoidCallback usage
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
  final Set<String> _expandedNodes = <String>{};

  @override
  Widget build(BuildContext context) {
    final enhancedTaskService = ref.watch(unifiedTaskServiceProvider);

    return StreamBuilder<List<NoteTask>>(
      stream: enhancedTaskService.watchOpenTasks(),
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
                  onPressed: () => ref.refresh(unifiedTaskServiceProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var tasks = snapshot.data ?? [];

        // Filter by noteId if specified
        if (widget.noteId != null) {
          tasks = tasks.where((t) => t.noteId == widget.noteId).toList();
        }

        // Filter completed tasks if needed
        if (!widget.showCompleted) {
          tasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
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

        return FutureBuilder<List<TaskHierarchyNode>>(
          future: _buildHierarchy(tasks),
          builder: (context, hierarchySnapshot) {
            if (hierarchySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rootNodes = hierarchySnapshot.data ?? [];

            return Column(
              children: [
                // Hierarchy statistics
                if (widget.noteId != null)
                  FutureBuilder<TaskHierarchyStats>(
                    future: ref.read(unifiedTaskServiceProvider).getHierarchyStats(widget.noteId!),
                    builder: (context, statsSnapshot) {
                      if (statsSnapshot.hasData &&
                          statsSnapshot.data!.hasNesting) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              TaskHierarchySummary(stats: statsSnapshot.data!),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                // Hierarchical task tree
                Expanded(
                  child: TaskTreeWidget(
                    rootNodes: rootNodes,
                    showProgress: true,
                    maxDepth: 5,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<TaskHierarchyNode>> _buildHierarchy(List<NoteTask> tasks) async {
    return ref.read(unifiedTaskServiceProvider).getTaskHierarchy(widget.noteId ?? 'all');
  }

  void _showCreateTaskDialog(BuildContext context) async {
    final unifiedService = ref.read(unifiedTaskServiceProvider);

    // Show task creation dialog
    final taskContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Task'),
        content: TextField(
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
              // Get text from controller would be better
              Navigator.of(context).pop('New Task');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (taskContent != null && taskContent.isNotEmpty) {
      try {
        await unifiedService.createTask(
          noteId: widget.noteId ?? 'standalone',
          content: taskContent,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating task: $e')),
          );
        }
      }
    }
  }
}

/// Hierarchical task view mode for enhanced task list screen
class HierarchicalTaskViewMode extends StatelessWidget {
  const HierarchicalTaskViewMode({
    super.key,
    required this.showCompleted,
  });

  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    return HierarchicalTaskListView(
      showCompleted: showCompleted,
    );
  }
}

/// Task hierarchy management panel using UnifiedTaskService
class TaskHierarchyPanel extends ConsumerWidget {
  const TaskHierarchyPanel({
    super.key,
    required this.noteId,
  });

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
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree,
                color: colorScheme.primary,
                size: 20,
              ),
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

          const SizedBox(height: 12),

          // Quick stats
          FutureBuilder<TaskHierarchyStats>(
            future: _getHierarchyStats(ref),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return TaskHierarchySummary(stats: snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<TaskHierarchyStats> _getHierarchyStats(WidgetRef ref) async {
    return ref.read(unifiedTaskServiceProvider).getHierarchyStats(noteId);
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
      BuildContext context, WidgetRef ref) async {
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
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        final tasks = await unifiedService.getTasksForNote(noteId);
        final rootTasks = tasks.where((t) => t.parentTaskId == null).toList();

        for (final task in rootTasks) {
          await unifiedService.onStatusChanged(task.id, TaskStatus.completed);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Completed ${rootTasks.length} root tasks')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing tasks: $e')),
          );
        }
      }
    }
  }

  Future<void> _cleanupCompletedTasks(
      BuildContext context, WidgetRef ref) async {
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
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        final tasks = await unifiedService.getTasksForNote(noteId);
        final completedTasks =
            tasks.where((t) => t.status == TaskStatus.completed).toList();

        for (final task in completedTasks) {
          await unifiedService.onDeleted(task.id);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Archived ${completedTasks.length} completed tasks')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error archiving tasks: $e')),
          );
        }
      }
    }
  }
}
