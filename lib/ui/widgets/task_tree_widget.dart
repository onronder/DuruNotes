import 'dart:async';

import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/helpers/task_decryption_helper.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show unifiedTaskServiceProvider;
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// TreeView-like widget for displaying hierarchical tasks using UnifiedTaskService
/// No VoidCallback usage - all actions go through the unified service
class TaskTreeWidget extends ConsumerStatefulWidget {
  const TaskTreeWidget({
    super.key,
    required this.rootNodes,
    this.showProgress = true,
    this.maxDepth = 5,
  });

  final List<TaskHierarchyNode> rootNodes;
  final bool showProgress;
  final int maxDepth;

  @override
  ConsumerState<TaskTreeWidget> createState() => _TaskTreeWidgetState();
}

class _TaskTreeWidgetState extends ConsumerState<TaskTreeWidget> {
  final Set<String> _expandedNodes = <String>{};

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
          onToggleExpanded: () =>
              _toggleExpanded(widget.rootNodes[index].task.id),
          showProgress: widget.showProgress,
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

/// Individual task node widget in the tree using UnifiedTaskService
class TaskTreeNodeWidget extends ConsumerWidget {
  const TaskTreeNodeWidget({
    super.key,
    required this.node,
    required this.depth,
    required this.maxDepth,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.showProgress = true,
  });

  final TaskHierarchyNode node;
  final int depth;
  final int maxDepth;
  final bool isExpanded;
  final void Function() onToggleExpanded;
  final bool showProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final task = node.task;
    final isCompleted = task.status == TaskStatus.completed;
    final hasChildren = node.children.isNotEmpty;
    final unifiedService = ref.watch(unifiedTaskServiceProvider);
    final logger = ref.read(loggerProvider);

    // Calculate progress if this is a parent task
    TaskProgress? progress;
    if (hasChildren && showProgress) {
      progress = unifiedService.calculateTaskProgress(node);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main task row
        Container(
          margin:
              EdgeInsets.only(left: depth * 24.0, right: 8, top: 4, bottom: 4),
          child: Material(
            elevation: depth > 0 ? 1 : 2,
            borderRadius: BorderRadius.circular(8),
            color: _getTaskBackgroundColor(colorScheme, depth),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => unifiedService.onEdit(task.id),
              onLongPress: () => _showTaskActions(context, ref),
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
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        try {
                          await unifiedService.onStatusChanged(
                            task.id,
                            isCompleted ? TaskStatus.open : TaskStatus.completed,
                          );
                          logger.debug(
                            'Toggled task status in tree',
                            data: {
                              'taskId': task.id,
                              'isCompleted': !isCompleted,
                            },
                          );
                        } catch (error, stackTrace) {
                          logger.error(
                            'Failed to toggle task status in tree',
                            error: error,
                            stackTrace: stackTrace,
                            data: {'taskId': task.id},
                          );
                          unawaited(Sentry.captureException(error, stackTrace: stackTrace));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Could not update task status. Retry?'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                              action: SnackBarAction(
                                label: 'Retry',
                                onPressed: () => unawaited(unifiedService.onStatusChanged(
                                  task.id,
                                  isCompleted ? TaskStatus.open : TaskStatus.completed,
                                )),
                              ),
                            ),
                          );
                        }
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

                    // Task content - decrypt and convert to domain.Task
                    Expanded(
                      child: FutureBuilder<domain.Task>(
                        future: _convertToDomainTask(ref, task),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                          logger.error(
                              'Failed to convert task to domain for tree node',
                              error: snapshot.error,
                              stackTrace: snapshot.stackTrace,
                              data: {'taskId': task.id},
                            );
                            unawaited(Sentry.captureException(
                              snapshot.error ?? 'Task conversion error',
                              stackTrace: snapshot.stackTrace,
                            ));
                          }
                          final content = snapshot.data?.title ?? 'Loading...';
                          final domainTask = snapshot.data;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Task title
                              Text(
                                content,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: isCompleted
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                                  fontWeight: hasChildren
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
                              if (domainTask != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TaskIndicatorsWidget(
                                        task: domainTask,
                                        compact: true,
                                      ),
                                    ),

                                    // Children count indicator
                                    if (hasChildren)
                                      Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.5),
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
                              if (task.noteId != 'standalone')
                                GestureDetector(
                                  onTap: () =>
                                      _openSourceNote(context, ref, task),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.note,
                                          size: 12,
                                          color:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Note',
                                          style: TextStyle(
                                            color: colorScheme
                                                .onSecondaryContainer,
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
                            ],
                          );
                        },
                      ),
                    ),

                    // More actions menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (action) =>
                          _handleAction(context, ref, action),
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
                                Icon(Icons.delete_sweep,
                                    size: 16, color: Colors.red),
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
                isExpanded: false, // Children start collapsed
                onToggleExpanded: () {}, // Will be managed by parent
                showProgress: showProgress,
              )),
      ],
    );
  }

  void _showTaskActions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    // Could show a bottom sheet with more actions
    final unifiedService = ref.read(unifiedTaskServiceProvider);
    unifiedService.onEdit(node.task.id);
  }

  /// Convert NoteTask to domain.Task with decryption
  Future<domain.Task> _convertToDomainTask(WidgetRef ref, NoteTask task) async {
    try {
      final taskRepository = ref.read(taskCoreRepositoryProvider);
      if (taskRepository != null) {
        final domainTask = await taskRepository.getTaskById(task.id);
        if (domainTask != null) {
          return domainTask;
        }
      }

      // Fallback: decrypt manually when repository access is unavailable
      final decryptHelper = TaskDecryptionHelper(ref.read(cryptoBoxProvider));
      final content = await decryptHelper.decryptContent(task, task.noteId);
      final notes = await decryptHelper.decryptNotes(task, task.noteId);
      final labels = await decryptHelper.decryptLabels(task, task.noteId);

      return TaskMapper.toDomain(
        task,
        content: content,
        notes: notes,
        labels: labels,
      );
    } catch (error, stackTrace) {
      final logger = ref.read(loggerProvider);
      logger.error(
        'Failed to convert tree node task to domain',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      rethrow;
    }
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    final unifiedService = ref.read(unifiedTaskServiceProvider);

    switch (action) {
      case 'edit':
        unifiedService.onEdit(node.task.id);
        break;
      case 'complete_all':
        _completeAllSubtasks(context, ref);
        break;
      case 'expand_all':
        _expandAllSubtasks();
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
      case 'delete_hierarchy':
        _confirmDeleteHierarchy(context, ref);
        break;
    }
  }

  Future<void> _completeAllSubtasks(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    try {
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      await unifiedService.completeAllSubtasks(node.task.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All subtasks completed')),
        );
      }
      logger.info(
        'Completed all subtasks from task tree',
        data: {'taskId': node.task.id},
      );
    } catch (error, stackTrace) {
      logger.error(
        'Failed to complete subtasks from task tree',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': node.task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to complete subtasks. Retry?'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_completeAllSubtasks(context, ref)),
            ),
          ),
        );
      }
    }
  }

  void _expandAllSubtasks() {
    // This would need access to the parent widget's state
    // For now, just expand this node
    onToggleExpanded();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final unifiedService = ref.read(unifiedTaskServiceProvider);

    // Decrypt content for dialog
    final decryptHelper = TaskDecryptionHelper(ref.read(cryptoBoxProvider));
    final content = await decryptHelper.decryptContent(node.task, node.task.noteId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "$content"?'),
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
      await unifiedService.onDeleted(node.task.id);
    }
  }

  Future<void> _confirmDeleteHierarchy(
      BuildContext context, WidgetRef ref) async {
    final totalTasks = 1 + node.getAllDescendants().length;

    // Decrypt content for dialog
    final decryptHelper = TaskDecryptionHelper(ref.read(cryptoBoxProvider));
    final content = await decryptHelper.decryptContent(node.task, node.task.noteId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Hierarchy'),
        content: Text(
          'Delete "$content" and all $totalTasks subtasks?\n\n'
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
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.deleteTaskHierarchy(node.task.id);

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

  void _openSourceNote(BuildContext context, WidgetRef ref, NoteTask task) {
    if (task.noteId == 'standalone') return;
    Navigator.of(context).pushNamed('/note', arguments: task.noteId);
  }

  Color _getTaskBackgroundColor(ColorScheme colorScheme, int depth) {
    if (depth == 0) {
      return colorScheme.surface;
    } else {
      final opacity = 0.05 + (depth * 0.02);
      return colorScheme.primaryContainer
          .withValues(alpha: opacity.clamp(0.0, 0.2));
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
    final progressColor =
        progress.isFullyCompleted ? Colors.green : colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: colorScheme.surfaceContainerHighest,
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                color: stats.completionPercentage > 0.8
                    ? Colors.green
                    : colorScheme.tertiary,
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
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.5),
      ),
    );
  }
}
