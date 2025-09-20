import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/hierarchical_task_sync_service.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TreeView-like widget for displaying hierarchical tasks
class TaskTreeWidget extends StatefulWidget {
  const TaskTreeWidget({
    super.key,
    required this.rootNodes,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
    this.onTaskMove,
    this.onOpenNote,
    this.showProgress = true,
    this.maxDepth = 5,
  });

  final List<TaskHierarchyNode> rootNodes;
  final Function(NoteTask) onTaskToggle;
  final Function(NoteTask) onTaskEdit;
  final Function(NoteTask) onTaskDelete;
  final Function(NoteTask, String?)? onTaskMove;
  final Function(NoteTask)? onOpenNote;
  final bool showProgress;
  final int maxDepth;

  @override
  State<TaskTreeWidget> createState() => _TaskTreeWidgetState();
}

class _TaskTreeWidgetState extends State<TaskTreeWidget> {
  final Set<String> _expandedNodes = <String>{};
  final HierarchicalTaskSyncService _hierarchyService = HierarchicalTaskSyncService(
    database: AppDb(), // This would need proper injection
    enhancedTaskService: EnhancedTaskService(database: AppDb(), reminderBridge: null as dynamic),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.rootNodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.rootNodes.length,
      itemBuilder: (context, index) {
        return TaskTreeNodeWidget(
          node: widget.rootNodes[index],
          depth: 0,
          maxDepth: widget.maxDepth,
          isExpanded: _expandedNodes.contains(widget.rootNodes[index].task.id),
          onToggleExpanded: () => _toggleExpanded(widget.rootNodes[index].task.id),
          onTaskToggle: widget.onTaskToggle,
          onTaskEdit: widget.onTaskEdit,
          onTaskDelete: widget.onTaskDelete,
          onTaskMove: widget.onTaskMove,
          onOpenNote: widget.onOpenNote,
          showProgress: widget.showProgress,
          hierarchyService: _hierarchyService,
        );
      },
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
}

/// Individual task node widget in the tree
class TaskTreeNodeWidget extends StatelessWidget {
  const TaskTreeNodeWidget({
    super.key,
    required this.node,
    required this.depth,
    required this.maxDepth,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
    required this.hierarchyService,
    this.onTaskMove,
    this.onOpenNote,
    this.showProgress = true,
  });

  final TaskHierarchyNode node;
  final int depth;
  final int maxDepth;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Function(NoteTask) onTaskToggle;
  final Function(NoteTask) onTaskEdit;
  final Function(NoteTask) onTaskDelete;
  final Function(NoteTask, String?)? onTaskMove;
  final Function(NoteTask)? onOpenNote;
  final bool showProgress;
  final HierarchicalTaskSyncService hierarchyService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final task = node.task;
    final isCompleted = task.status == TaskStatus.completed;
    final hasChildren = node.children.isNotEmpty;

    // Calculate progress if this is a parent task
    TaskProgress? progress;
    if (hasChildren && showProgress) {
      progress = hierarchyService.calculateTaskProgress(node);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main task row
        Container(
          margin: EdgeInsets.only(left: depth * 24.0, right: 8, top: 4, bottom: 4),
          child: Material(
            elevation: depth > 0 ? 1 : 2,
            borderRadius: BorderRadius.circular(8),
            color: _getTaskBackgroundColor(colorScheme, depth),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTaskEdit(task),
              onLongPress: () => _showTaskActions(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expand/collapse button for parent tasks
                    if (hasChildren)
                      GestureDetector(
                        onTap: onToggleExpanded,
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          child: Icon(
                            isExpanded 
                              ? Icons.keyboard_arrow_down 
                              : Icons.keyboard_arrow_right,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 28), // Spacing for alignment

                    // Task checkbox
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTaskToggle(task);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCompleted
                                ? _getPriorityColor(task.priority)
                                : colorScheme.outline,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          color: isCompleted
                              ? _getPriorityColor(task.priority)
                              : Colors.transparent,
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Task content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Task title
                          Text(
                            task.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontWeight: hasChildren ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),

                          // Progress bar for parent tasks
                          if (progress != null && hasChildren) ...[
                            const SizedBox(height: 6),
                            TaskProgressBar(
                              progress: progress,
                              compact: true,
                            ),
                          ],

                          // Task indicators
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TaskIndicatorsWidget(
                                  task: task,
                                  compact: true,
                                ),
                              ),
                              
                              // Children count indicator
                              if (hasChildren)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${node.children.length} subtask${node.children.length == 1 ? '' : 's'}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              
                              // Source note indicator
                              if (task.noteId != 'standalone' && onOpenNote != null)
                                GestureDetector(
                                  onTap: () => onOpenNote!(task),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.note,
                                          size: 12,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Note',
                                          style: TextStyle(
                                            color: colorScheme.onSecondaryContainer,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // More actions menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (action) => _handleAction(context, action),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        if (hasChildren) ...[
                          const PopupMenuItem(
                            value: 'complete_all',
                            child: Row(
                              children: [
                                Icon(Icons.done_all, size: 16),
                                SizedBox(width: 8),
                                Text('Complete All'),
                              ],
                            ),
                          ),
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
                        ],
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                        if (hasChildren)
                          const PopupMenuItem(
                            value: 'delete_hierarchy',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete All'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Children (if expanded)
        if (hasChildren && isExpanded && depth < maxDepth)
          ...node.children.map((child) => TaskTreeNodeWidget(
            node: child,
            depth: depth + 1,
            maxDepth: maxDepth,
            isExpanded: _isNodeExpanded(child.task.id),
            onToggleExpanded: () => _toggleNodeExpanded(child.task.id),
            onTaskToggle: onTaskToggle,
            onTaskEdit: onTaskEdit,
            onTaskDelete: onTaskDelete,
            onTaskMove: onTaskMove,
            onOpenNote: onOpenNote,
            showProgress: showProgress,
            hierarchyService: hierarchyService,
          )),
      ],
    );
  }

  void _showTaskActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    // This could show a bottom sheet with more actions
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onTaskEdit(node.task);
        break;
      case 'complete_all':
        _completeAllSubtasks(context);
        break;
      case 'expand_all':
        _expandAllSubtasks();
        break;
      case 'delete':
        _confirmDelete(context);
        break;
      case 'delete_hierarchy':
        _confirmDeleteHierarchy(context);
        break;
    }
  }

  Future<void> _completeAllSubtasks(BuildContext context) async {
    try {
      await hierarchyService.completeAllSubtasks(node.task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All subtasks completed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing subtasks: $e')),
        );
      }
    }
  }

  void _expandAllSubtasks() {
    // This would need access to the parent widget's state
    // For now, just expand this node
    onToggleExpanded();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${node.task.content}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onTaskDelete(node.task);
    }
  }

  Future<void> _confirmDeleteHierarchy(BuildContext context) async {
    final totalTasks = 1 + node.getAllDescendants().length;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Hierarchy'),
        content: Text(
          'Delete "${node.task.content}" and all $totalTasks subtasks?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await hierarchyService.deleteTaskHierarchy(node.task.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted $totalTasks tasks')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting hierarchy: $e')),
          );
        }
      }
    }
  }

  Color _getTaskBackgroundColor(ColorScheme colorScheme, int depth) {
    if (depth == 0) {
      return colorScheme.surface;
    } else {
      final opacity = 0.05 + (depth * 0.02);
      return colorScheme.primaryContainer.withOpacity(opacity.clamp(0.0, 0.2));
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.purple;
    }
  }

  bool _isNodeExpanded(String taskId) {
    // This would need access to parent state
    // Simplified for now
    return false;
  }

  void _toggleNodeExpanded(String taskId) {
    // This would need access to parent state
  }
}

/// Progress bar widget for parent tasks
class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({
    super.key,
    required this.progress,
    this.compact = false,
  });

  final TaskProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final height = compact ? 4.0 : 6.0;
    final progressColor = progress.isFullyCompleted 
        ? Colors.green 
        : colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: colorScheme.surfaceVariant,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.progressPercentage,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: progressColor,
              ),
            ),
          ),
        ),
        
        if (!compact) ...[
          const SizedBox(height: 4),
          // Progress text
          Row(
            children: [
              Text(
                '${progress.completedTasks}/${progress.totalTasks} completed',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress.progressPercentage * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Compact task hierarchy summary widget
class TaskHierarchySummary extends StatelessWidget {
  const TaskHierarchySummary({
    super.key,
    required this.stats,
  });

  final TaskHierarchyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Task Hierarchy',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: Icons.task_alt,
                label: 'Total',
                value: stats.totalTasks.toString(),
                color: colorScheme.primary,
              ),
              _buildStatItem(
                context,
                icon: Icons.check_circle,
                label: 'Done',
                value: stats.completedTasks.toString(),
                color: Colors.green,
              ),
              _buildStatItem(
                context,
                icon: Icons.layers,
                label: 'Levels',
                value: (stats.maxDepth + 1).toString(),
                color: colorScheme.secondary,
              ),
              _buildStatItem(
                context,
                icon: Icons.percent,
                label: 'Progress',
                value: '${(stats.completionPercentage * 100).round()}%',
                color: stats.completionPercentage > 0.8 ? Colors.green : colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Drag handle for reordering tasks in hierarchy
class TaskDragHandle extends StatelessWidget {
  const TaskDragHandle({
    super.key,
    this.isVisible = true,
  });

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 8),
      child: Icon(
        Icons.drag_handle,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}
