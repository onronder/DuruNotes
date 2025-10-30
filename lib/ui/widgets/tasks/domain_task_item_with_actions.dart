import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/tasks/domain_task_time_tracker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Enhanced task item widget with actions and time tracking using domain entities
/// Production-grade replacement for TaskItemWithActions with domain.Task support
class DomainTaskItemWithActions extends ConsumerStatefulWidget {
  const DomainTaskItemWithActions({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  final domain.Task task;
  final VoidCallback? onTaskUpdated;

  @override
  ConsumerState<DomainTaskItemWithActions> createState() =>
      _DomainTaskItemWithActionsState();
}

class _DomainTaskItemWithActionsState
    extends ConsumerState<DomainTaskItemWithActions> {
  bool _isExpanded = false;
  late domain.Task _task;

  AppLogger get _logger => ref.read(loggerProvider);

  DomainTaskController? _controllerOrNull({bool showSnackbar = true}) {
    try {
      final controller = ref.read(domainTaskControllerProvider);
      return controller;
    } on StateError catch (error, stackTrace) {
      _logger.error(
        'DomainTaskController unavailable for task actions',
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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  void didUpdateWidget(DomainTaskItemWithActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task != oldWidget.task) {
      _task = widget.task;
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

  Future<void> _toggleTaskStatus() async {
    try {
      final controller = _controllerOrNull();
      if (controller == null) return;

      await controller.toggleStatus(_task.id);
      await _refreshTask();
      widget.onTaskUpdated?.call();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle task status',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': _task.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not update task status. Please try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editTask() async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: _task,
        taskContent: _task.title,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _applyTaskUpdates(result);
    }
  }

  Future<void> _applyTaskUpdates(TaskMetadata metadata) async {
    try {
      final controller = _controllerOrNull();
      if (controller == null) return;

      final updatedTask = await controller.updateTask(
        _task,
        title: metadata.taskContent,
        description: metadata.notes,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        tags: metadata.labels,
        estimatedMinutes: metadata.estimatedMinutes,
        hasReminder: metadata.hasReminder,
        reminderTime: metadata.reminderTime,
      );

      if (mounted) {
        setState(() {
          _task = updatedTask;
        });
      }
      widget.onTaskUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task updated')));
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update task',
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
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_applyTaskUpdates(metadata)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final controller = _controllerOrNull();
        if (controller == null) return;

        await controller.deleteTask(_task.id);
        widget.onTaskUpdated?.call();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final task = _task;

    final isCompleted = task.status == domain.TaskStatus.completed;
    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !isCompleted;

    Color? priorityColor;
    IconData priorityIcon = Icons.flag_outlined;
    switch (task.priority) {
      case domain.TaskPriority.urgent:
        priorityColor = Colors.red;
        priorityIcon = Icons.flag;
        break;
      case domain.TaskPriority.high:
        priorityColor = Colors.orange;
        priorityIcon = Icons.flag;
        break;
      case domain.TaskPriority.low:
        priorityColor = Colors.blue;
        break;
      default:
        break;
    }

    return Card(
      elevation: _isExpanded ? 2 : 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: isCompleted,
              onChanged: (_) => _toggleTaskStatus(),
              activeColor: colorScheme.primary,
            ),
            title: Text(
              task.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? colorScheme.onSurface.withValues(alpha: 0.5)
                    : colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      task.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Priority indicator
                    if (task.priority != domain.TaskPriority.medium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor?.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(priorityIcon, size: 12, color: priorityColor),
                            const SizedBox(width: 4),
                            Text(
                              task.priority.name.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: priorityColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Due date
                    if (task.dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withValues(alpha: 0.1)
                              : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: isOverdue
                                  ? Colors.red
                                  : colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.MMMd().format(task.dueDate!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isOverdue
                                    ? Colors.red
                                    : colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Reminder indicator
                    if (task.metadata['reminderId'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              size: 12,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reminder',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Time tracking (need drift task for widget - will address in Batch 3)
                    // TODO: Create domain version of CompactTimeTracker

                    // Tags
                    ...task.tags.map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  tooltip: _isExpanded ? 'Collapse' : 'Expand',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editTask();
                        break;
                      case 'delete':
                        _deleteTask();
                        break;
                    }
                  },
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
                  ],
                ),
              ],
            ),
          ),

          // Expanded content with time tracker
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DomainTaskTimeTrackerWidget(
                task: task,
                onTimeUpdated: () {
                  widget.onTaskUpdated?.call();
                  _refreshTask();
                },
              ),
            ),
        ],
      ),
    );
  }
}
