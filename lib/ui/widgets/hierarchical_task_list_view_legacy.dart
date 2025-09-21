import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/hierarchical_task_sync_service.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/task_tree_widget.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hierarchical task list view with tree structure and progress tracking
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
  late HierarchicalTaskSyncService _hierarchyService;
  final Set<String> _expandedNodes = <String>{};

  @override
  void initState() {
    super.initState();
    _hierarchyService = HierarchicalTaskSyncService(
      database: ref.read(appDbProvider),
      enhancedTaskService: ref.read(enhancedTaskServiceProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enhancedTaskService = ref.watch(enhancedTaskServiceProvider);

    return StreamBuilder<List<NoteTask>>(
      stream: widget.noteId != null
          ? enhancedTaskService.watchTasksForNote(widget.noteId!)
          : enhancedTaskService.watchOpenTasks(),
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
                  onPressed: () => ref.refresh(enhancedTaskServiceProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var tasks = snapshot.data ?? [];

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
                    future: _hierarchyService.getHierarchyStats(widget.noteId!),
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
                  child: _buildTaskTree(rootNodes),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<TaskHierarchyNode>> _buildHierarchy(List<NoteTask> tasks) async {
    return _hierarchyService.getTaskHierarchy(widget.noteId ?? 'all');
  }

  Widget _buildTaskTree(List<TaskHierarchyNode> rootNodes) {
    if (rootNodes.isEmpty) {
      return const EmptyTaskGroup(
        title: 'No tasks in hierarchy',
        message: 'Create tasks with indentation to build hierarchies.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rootNodes.length,
      itemBuilder: (context, index) {
        final rootNode = rootNodes[index];
        return _buildTaskNode(rootNode, 0);
      },
    );
  }

  Widget _buildTaskNode(TaskHierarchyNode node, int depth) {
    final isExpanded = _expandedNodes.contains(node.task.id);
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main task
        TaskTreeNodeWidget(
          node: node,
          depth: depth,
          maxDepth: 5,
          isExpanded: isExpanded,
          onToggleExpanded: () => _toggleExpanded(node.task.id),
          onTaskToggle: (task) => _toggleTask(task),
          onTaskEdit: (task) => _editTask(task),
          onTaskDelete: (task) => _deleteTask(task),
          onTaskMove: (task, newParentId) => _moveTask(task, newParentId),
          onOpenNote:
              widget.noteId == null ? (task) => _openSourceNote(task) : null,
          showProgress: true,
          hierarchyService: _hierarchyService,
        ),

        // Children (if expanded)
        if (hasChildren && isExpanded && depth < 4) // Max 4 levels deep
          ...node.children.map((child) => _buildTaskNode(child, depth + 1)),
      ],
    );
  }

  void _toggleExpanded(String taskId) {
    setState(() {
      if (_expandedNodes.contains(taskId)) {
        _expandedNodes.remove(taskId);
      } else {
        _expandedNodes.add(taskId);
      }
    });
  }

  Future<void> _toggleTask(NoteTask task) async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      await enhancedTaskService.toggleTaskStatus(task.id);
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _editTask(NoteTask task) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: task,
        taskContent: task.content,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _updateTask(task, result);
    }
  }

  Future<void> _updateTask(NoteTask task, TaskMetadata metadata) async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      await enhancedTaskService.updateTask(
        taskId: task.id,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
        notes: metadata.notes,
        estimatedMinutes: metadata.estimatedMinutes,
      );
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(NoteTask task) async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      await enhancedTaskService.deleteTask(task.id);
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _moveTask(NoteTask task, String? newParentId) async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      await enhancedTaskService.moveTaskToParent(
        taskId: task.id,
        newParentId: newParentId,
      );
    } catch (e) {
      debugPrint('Error moving task: $e');
    }
  }

  Future<void> _openSourceNote(NoteTask task) async {
    if (task.noteId == 'standalone') return;

    try {
      final notesRepo = ref.read(notesRepositoryProvider);
      final note = await notesRepo.getNote(task.noteId);

      if (note != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening source note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open source note')),
        );
      }
    }
  }

  void _showCreateTaskDialog(BuildContext context) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: 'New Task',
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      try {
        final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
        await enhancedTaskService.createTask(
          noteId: widget.noteId ?? 'standalone',
          content: 'New Task',
          priority: result.priority,
          dueDate: result.dueDate,
          labels: result.labels.isNotEmpty ? {'labels': result.labels} : null,
          notes: result.notes,
          estimatedMinutes: result.estimatedMinutes,
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

/// Task hierarchy management panel
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
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
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
    final hierarchyService = HierarchicalTaskSyncService(
      database: ref.read(appDbProvider),
      enhancedTaskService: ref.read(enhancedTaskServiceProvider),
    );
    return hierarchyService.getHierarchyStats(noteId);
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
        final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
        final tasks = await enhancedTaskService.getTasksForNote(noteId);
        final rootTasks = tasks.where((t) => t.parentTaskId == null).toList();

        await enhancedTaskService.bulkCompleteTasks(
          rootTasks.map((t) => t.id).toList(),
        );

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
        final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
        final tasks = await enhancedTaskService.getTasksForNote(noteId);
        final completedTasks =
            tasks.where((t) => t.status == TaskStatus.completed).toList();

        await enhancedTaskService.bulkDeleteTasks(
          completedTasks.map((t) => t.id).toList(),
        );

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
