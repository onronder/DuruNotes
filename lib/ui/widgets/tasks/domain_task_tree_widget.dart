import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:duru_notes/ui/widgets/tasks/domain_task_hierarchy_node.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// TreeView-like widget for displaying hierarchical tasks using domain entities
/// Production-grade replacement for TaskTreeWidget with domain.Task support
class DomainTaskTreeWidget extends ConsumerStatefulWidget {
  const DomainTaskTreeWidget({
    super.key,
    required this.rootNodes,
    this.showProgress = true,
    this.maxDepth = 5,
    this.onTaskChanged,
  });

  final List<DomainTaskHierarchyNode> rootNodes;
  final bool showProgress;
  final int maxDepth;
  final VoidCallback? onTaskChanged;

  @override
  ConsumerState<DomainTaskTreeWidget> createState() =>
      _DomainTaskTreeWidgetState();
}

class _DomainTaskTreeWidgetState extends ConsumerState<DomainTaskTreeWidget> {
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
        return _DomainTaskTreeNodeWidget(
          node: widget.rootNodes[index],
          depth: 0,
          maxDepth: widget.maxDepth,
          isExpanded: _expandedNodes.contains(widget.rootNodes[index].task.id),
          onToggleExpanded: () =>
              _toggleExpanded(widget.rootNodes[index].task.id),
          showProgress: widget.showProgress,
          expandedNodes: _expandedNodes,
          onTaskChanged: widget.onTaskChanged,
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

/// Individual task node widget in the tree using domain entities
class _DomainTaskTreeNodeWidget extends ConsumerStatefulWidget {
  const _DomainTaskTreeNodeWidget({
    required this.node,
    required this.depth,
    required this.maxDepth,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.expandedNodes,
    this.showProgress = true,
    this.onTaskChanged,
  });

  final DomainTaskHierarchyNode node;
  final int depth;
  final int maxDepth;
  final bool isExpanded;
  final void Function() onToggleExpanded;
  final Set<String> expandedNodes;
  final bool showProgress;
  final VoidCallback? onTaskChanged;

  @override
  ConsumerState<_DomainTaskTreeNodeWidget> createState() =>
      _DomainTaskTreeNodeWidgetState();
}

class _DomainTaskTreeNodeWidgetState
    extends ConsumerState<_DomainTaskTreeNodeWidget> {
  late domain.Task _task;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    _task = widget.node.task;
  }

  @override
  void didUpdateWidget(_DomainTaskTreeNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.task != oldWidget.node.task) {
      _task = widget.node.task;
    }
  }

  DomainTaskController? _controllerOrNull({bool showSnackbar = true}) {
    try {
      return ref.read(domainTaskControllerProvider);
    } on StateError catch (error, stackTrace) {
      _logger.error(
        'DomainTaskController unavailable for tree node',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': _task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task actions unavailable. Please retry.'),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _refreshTask() async {
    final controller = _controllerOrNull(showSnackbar: false);
    if (controller == null) return;
    try {
      final latest = await controller.getTaskById(_task.id);
      if (latest != null && mounted) {
        setState(() {
          _task = latest;
        });
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to refresh task after mutation',
        data: {
          'taskId': _task.id,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
  }

  void _notifyTaskChanged() => widget.onTaskChanged?.call();

  bool get _hasChildren => widget.node.children.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = _task.status == domain.TaskStatus.completed;

    int? completedChildren;
    int? totalChildren;
    if (_hasChildren && widget.showProgress) {
      final stats = _calculateProgress(widget.node);
      completedChildren = stats['completed'] as int;
      totalChildren = stats['total'] as int;
    }
    final int totalChildrenValue = totalChildren ?? 0;
    final int completedChildrenValue = completedChildren ?? 0;
    final bool showChildrenProgress =
        _hasChildren && widget.showProgress && totalChildrenValue > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: widget.depth * 24.0,
            right: 8,
            top: 4,
            bottom: 4,
          ),
          child: Material(
            elevation: widget.depth > 0 ? 1 : 2,
            borderRadius: BorderRadius.circular(8),
            color: _getTaskBackgroundColor(colorScheme, widget.depth),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _editTask,
              onLongPress: () => _showTaskActions(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasChildren)
                      GestureDetector(
                        onTap: widget.onToggleExpanded,
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          child: Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 28),
                    GestureDetector(
                      onTap: () => _toggleStatus(context),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCompleted
                                ? _getPriorityColor(_task.priority)
                                : colorScheme.outline,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          color: isCompleted
                              ? _getPriorityColor(_task.priority)
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _task.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontWeight: _hasChildren
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (showChildrenProgress) ...[
                            const SizedBox(height: 6),
                            _buildProgressBar(
                              context,
                              completedChildrenValue,
                              totalChildrenValue,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TaskIndicatorsWidget(
                                  task: _task,
                                  compact: true,
                                ),
                              ),
                              if (_hasChildren)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${widget.node.children.length} subtask${widget.node.children.length == 1 ? '' : 's'}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (!DomainTaskController.isStandaloneNoteId(
                                _task.noteId,
                              ))
                                GestureDetector(
                                  onTap: () => _openSourceNote(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                      ),
                    ),
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
                        if (_hasChildren) ...[
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
                        if (_hasChildren)
                          const PopupMenuItem(
                            value: 'delete_hierarchy',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_sweep,
                                  size: 16,
                                  color: Colors.red,
                                ),
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

        if (_hasChildren && widget.isExpanded && widget.depth < widget.maxDepth)
          ...widget.node.children.map(
            (child) => _DomainTaskTreeNodeWidget(
              node: child,
              depth: widget.depth + 1,
              maxDepth: widget.maxDepth,
              isExpanded: widget.expandedNodes.contains(child.task.id),
              onToggleExpanded: () {}, // Managed by parent
              expandedNodes: widget.expandedNodes,
              showProgress: widget.showProgress,
              onTaskChanged: widget.onTaskChanged,
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, int completed, int total) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = total > 0 ? completed / total : 0.0;
    final progressColor = progress == 1.0 ? Colors.green : colorScheme.primary;

    return Container(
      height: 4.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: progressColor,
          ),
        ),
      ),
    );
  }

  Map<String, int> _calculateProgress(DomainTaskHierarchyNode node) {
    int total = 0;
    int completed = 0;

    void countNode(DomainTaskHierarchyNode n) {
      total++;
      if (n.task.status == domain.TaskStatus.completed) {
        completed++;
      }
      for (final child in n.children) {
        countNode(child);
      }
    }

    // Count children (not including the parent node itself)
    for (final child in node.children) {
      countNode(child);
    }

    return {'total': total, 'completed': completed};
  }

  Future<void> _editTask() async {
    final controller = _controllerOrNull();
    if (controller == null) return;

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: _task,
        taskContent: _task.title,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result == null) return;

    try {
      final updated = await controller.updateTask(
        _task,
        title: result.taskContent,
        description: result.notes,
        priority: result.priority,
        dueDate: result.dueDate,
        tags: result.labels,
        estimatedMinutes: result.estimatedMinutes,
        hasReminder: result.hasReminder,
        reminderTime: result.reminderTime,
      );

      if (mounted) {
        setState(() {
          _task = updated;
        });
      }
      _notifyTaskChanged();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task updated')));
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update task from tree node',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': _task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus(BuildContext context) async {
    HapticFeedback.lightImpact();
    final controller = _controllerOrNull();
    if (controller == null) return;

    try {
      await controller.toggleStatus(_task.id);
      await _refreshTask();
      _notifyTaskChanged();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle task status in tree',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': _task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update task status. Retry?'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _toggleStatus(context),
            ),
          ),
        );
      }
    }
  }

  void _showTaskActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    _editTask();
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        _editTask();
        break;
      case 'complete_all':
        unawaited(_completeAllSubtasks(context));
        break;
      case 'expand_all':
        _expandAllSubtasks();
        break;
      case 'delete':
        unawaited(_confirmDelete(context));
        break;
      case 'delete_hierarchy':
        unawaited(_confirmDeleteHierarchy(context));
        break;
    }
  }

  void _expandAllSubtasks() {
    setState(() {
      void expandNode(DomainTaskHierarchyNode node) {
        widget.expandedNodes.add(node.task.id);
        for (final child in node.children) {
          expandNode(child);
        }
      }

      expandNode(widget.node);
    });
  }

  Future<void> _completeAllSubtasks(BuildContext context) async {
    final controller = _controllerOrNull();
    if (controller == null) return;

    try {
      await controller.completeAllSubtasks(_task.id);
      await _refreshTask();
      _notifyTaskChanged();
      if (mounted) {
        final count = widget.node.getAllDescendants().length;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Completed $count subtasks')));
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to complete subtasks from task tree',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': _task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to complete subtasks. Retry?'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_completeAllSubtasks(context)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final controller = _controllerOrNull();
    if (controller == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${_task.title}"?'),
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
      try {
        await controller.deleteTask(_task.id);
        _notifyTaskChanged();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Task deleted')));
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to delete task',
          error: error,
          stackTrace: stackTrace,
          data: {'taskId': _task.id},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not delete task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteHierarchy(BuildContext context) async {
    final controller = _controllerOrNull();
    if (controller == null) return;

    final totalTasks = 1 + widget.node.getAllDescendants().length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Hierarchy'),
        content: Text(
          'Delete "${_task.title}" and all $totalTasks subtasks?\n\n'
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
        await controller.deleteHierarchy(_task.id);
        _notifyTaskChanged();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted $totalTasks tasks')));
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to delete task hierarchy',
          error: error,
          stackTrace: stackTrace,
          data: {'taskId': _task.id, 'totalTasks': totalTasks},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting hierarchy: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _openSourceNote(BuildContext context) {
    if (DomainTaskController.isStandaloneNoteId(_task.noteId)) return;
    Navigator.of(context).pushNamed('/note', arguments: _task.noteId);
  }

  Color _getTaskBackgroundColor(ColorScheme colorScheme, int depth) {
    if (depth == 0) {
      return colorScheme.surface;
    } else {
      final opacity = 0.05 + (depth * 0.02);
      return colorScheme.primaryContainer.withValues(
        alpha: opacity.clamp(0.0, 0.2),
      );
    }
  }

  Color _getPriorityColor(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return Colors.green;
      case domain.TaskPriority.medium:
        return Colors.orange;
      case domain.TaskPriority.high:
        return Colors.red;
      case domain.TaskPriority.urgent:
        return Colors.purple;
    }
  }
}
