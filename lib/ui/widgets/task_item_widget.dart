import 'dart:async';

import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/utils/accessibility_helper.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Enhanced task item widget using the domain task controller
/// No VoidCallback usage - all actions go through the domain layer
///
/// POST-ENCRYPTION: Now uses domain.Task with decrypted content
class TaskItemWidget extends ConsumerWidget {
  const TaskItemWidget({
    super.key,
    required this.task,
    this.showSourceNote = true,
  });

  final domain.Task task;
  final bool showSourceNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = task.status == domain.TaskStatus.completed;
    final taskRepository = ref.watch(taskCoreRepositoryProvider);
    if (taskRepository == null) {
      return const SizedBox.shrink();
    }
    final taskController = ref.watch(domainTaskControllerProvider);

    return Dismissible(
      key: Key('task_${task.id}'),
      background: _buildSwipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: Colors.green,
        icon: Icons.check,
        label: 'Complete',
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Complete action
          HapticFeedback.mediumImpact();
          await taskController.toggleStatus(task.id);
          A11yHelper.announce(
            context,
            isCompleted ? 'Task reopened' : 'Task completed',
          );
          return false; // Don't dismiss, just toggle
        } else if (direction == DismissDirection.endToStart) {
          // Delete action
          return await _showDeleteConfirmation(context, ref);
        }
        return false;
      },
      child: A11yHelper.taskCard(
        title: task.title,
        description: task.description,
        isCompleted: isCompleted,
        dueDate: task.dueDate != null
            ? _getRelativeTime(task.dueDate!, DateTime.now())
            : null,
        priority: task.priority.toString().split('.').last,
        tags: task.tags,
        onTap: () => _editTask(context, ref),
        onToggle: (value) async {
          if (value == null) return;
          await taskController.setStatus(
            task.id,
            value ? domain.TaskStatus.completed : domain.TaskStatus.pending,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _editTask(context, ref),
              onLongPress: () => _showQuickActions(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main task row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox
                        A11yHelper.checkbox(
                          label: task.title,
                          value: isCompleted,
                          hint: isCompleted
                              ? 'Swipe right to reopen task'
                              : 'Swipe right to complete task',
                          onTap: () async {
                            await taskController.setStatus(
                              task.id,
                              isCompleted
                                  ? domain.TaskStatus.pending
                                  : domain.TaskStatus.completed,
                            );
                          },
                          child: GestureDetector(
                            onTap: () async {
                              await taskController.setStatus(
                                task.id,
                                isCompleted
                                    ? domain.TaskStatus.pending
                                    : domain.TaskStatus.completed,
                              );
                            },
                            child: Container(
                              width: 24,
                              height: 24,
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
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Task content
                        Expanded(
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Task title
                                Text(
                                  task.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    color: isCompleted
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                // Task description/notes (domain.Task has description field)
                                if (task.description?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],

                                // Due date with relative time
                                if (task.dueDate != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDueDateChip(context, task.dueDate!),
                                ],

                                // Task indicators
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TaskIndicatorsWidget(
                                        task: task,
                                        compact: true,
                                      ),
                                    ),

                                    // Source note indicator
                                    if (showSourceNote &&
                                        !DomainTaskController.isStandaloneNoteId(
                                          task.noteId,
                                        ))
                                      _buildSourceNoteChip(context, ref),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick actions menu
                        A11yHelper.iconButton(
                          label: 'More options for task: ${task.title}',
                          hint:
                              'Open menu with edit, complete, snooze, and delete actions',
                          enabled: true,
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (action) =>
                                _handleQuickAction(context, ref, action),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Semantics(
                                  label: 'Edit task',
                                  hint: 'Edit this task',
                                  button: true,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Edit'),
                                    ],
                                  ),
                                ),
                              ),
                              if (!DomainTaskController.isStandaloneNoteId(
                                task.noteId,
                              ))
                                PopupMenuItem(
                                  value: 'open_note',
                                  child: Semantics(
                                    label: 'Open note',
                                    hint: 'Open the note containing this task',
                                    button: true,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.note,
                                          size: 18,
                                          color: colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Open Note'),
                                      ],
                                    ),
                                  ),
                                ),
                              if (task.dueDate != null && !isCompleted)
                                PopupMenuItem(
                                  value: 'snooze',
                                  child: Semantics(
                                    label: 'Snooze task',
                                    hint: 'Postpone task due date',
                                    button: true,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.snooze,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Snooze'),
                                      ],
                                    ),
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Semantics(
                                  label: 'Delete task',
                                  hint: 'Delete this task permanently',
                                  button: true,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Delete'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Time tracking (if available) - access from metadata
                    if ((task.metadata['estimatedMinutes'] as int?) != null ||
                        (task.metadata['actualMinutes'] as int?) != null) ...[
                      const SizedBox(height: 8),
                      _buildTimeTracking(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return A11yHelper.decorative(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateChip(BuildContext context, DateTime dueDate) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOverdue =
        dueDate.isBefore(now) && task.status != domain.TaskStatus.completed;
    final isToday = _isSameDay(dueDate, now);
    final isTomorrow = _isSameDay(dueDate, now.add(const Duration(days: 1)));

    Color chipColor;
    String relativeText;
    IconData icon;

    if (isOverdue) {
      chipColor = Colors.red;
      relativeText = 'Overdue ${_getRelativeTime(dueDate, now)}';
      icon = Icons.warning;
    } else if (isToday) {
      chipColor = Colors.orange;
      relativeText = 'Due today at ${DateFormat.Hm().format(dueDate)}';
      icon = Icons.today;
    } else if (isTomorrow) {
      chipColor = Colors.blue;
      relativeText = 'Due tomorrow at ${DateFormat.Hm().format(dueDate)}';
      icon = Icons.schedule;
    } else {
      chipColor = theme.colorScheme.primary;
      relativeText = 'Due ${_getRelativeTime(dueDate, now)}';
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            relativeText,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceNoteChip(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _openSourceNote(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note, size: 12, color: colorScheme.onSecondaryContainer),
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
    );
  }

  Widget _buildTimeTracking(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Access time tracking from metadata
    final estimated = task.metadata['estimatedMinutes'] as int?;
    final actual = task.metadata['actualMinutes'] as int?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          if (estimated != null && actual != null)
            Text(
              '${_formatDuration(actual)} / ${_formatDuration(estimated)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            )
          else if (estimated != null)
            Text(
              'Est: ${_formatDuration(estimated)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            )
          else if (actual != null)
            Text(
              'Spent: ${_formatDuration(actual)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    if (ref.read(taskCoreRepositoryProvider) == null) return;
    final controller = ref.read(domainTaskControllerProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _TaskQuickActionsSheet(
        task: task,
        onToggleStatus: () => controller.toggleStatus(task.id),
        onEdit: () => _editTask(context, ref),
        onOpenNote: () => _openSourceNote(context, ref),
        onSnooze: () => _snoozeTask(context, ref),
        onDelete: () async {
          _confirmDelete(context, ref);
        },
      ),
    );
  }

  void _handleQuickAction(BuildContext context, WidgetRef ref, String action) {
    if (ref.read(taskCoreRepositoryProvider) == null) return;

    switch (action) {
      case 'edit':
        _editTask(context, ref);
        break;
      case 'open_note':
        _openSourceNote(context, ref);
        break;
      case 'snooze':
        _snoozeTask(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  Future<void> _openSourceNote(BuildContext context, WidgetRef ref) async {
    if (DomainTaskController.isStandaloneNoteId(task.noteId)) return;

    try {
      // Navigate to note - implementation depends on your navigation setup
      Navigator.of(context).pushNamed('/note', arguments: task.noteId);
      ref
          .read(loggerProvider)
          .info(
            'Navigating to task source note',
            data: {'taskId': task.id, 'noteId': task.noteId},
          );
    } catch (error, stackTrace) {
      final logger = ref.read(loggerProvider);
      logger.error(
        'Failed to open source note from task item',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': task.id, 'noteId': task.noteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not open source note. Please try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref) async {
    if (ref.read(taskCoreRepositoryProvider) == null) return;
    final controller = ref.read(domainTaskControllerProvider);

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: task,
        taskContent: task.title,
        onSave: (metadata) async {
          Navigator.of(context).pop(metadata);
        },
      ),
    );

    if (result != null) {
      try {
        await controller.updateTask(
          task,
          title: result.taskContent,
          description: result.notes,
          priority: result.priority,
          dueDate: result.dueDate,
          tags: result.labels,
          estimatedMinutes: result.estimatedMinutes,
          hasReminder: result.hasReminder,
          reminderTime: result.reminderTime,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Task updated')));
        }
      } catch (error, stackTrace) {
        ref
            .read(loggerProvider)
            .error(
              'Failed to update task from widget',
              error: error,
              stackTrace: stackTrace,
              data: {'taskId': task.id},
            );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not update task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _snoozeTask(BuildContext context, WidgetRef ref) async {
    if (ref.read(taskCoreRepositoryProvider) == null) return;
    final controller = ref.read(domainTaskControllerProvider);

    // Show snooze duration picker
    final duration = await showDialog<Duration>(
      context: context,
      builder: (context) => _SnoozeDurationDialog(),
    );

    if (duration != null && task.dueDate != null) {
      final newDueDate = task.dueDate!.add(duration);
      await controller.setDueDate(task.id, newDueDate);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task snoozed until ${DateFormat.MMMd().add_Hm().format(newDueDate)}',
            ),
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (ref.read(taskCoreRepositoryProvider) == null) return false;
    final controller = ref.read(domainTaskControllerProvider);

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text('Are you sure you want to delete this task?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await controller.deleteTask(task.id);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    _showDeleteConfirmation(context, ref).then((deleted) {
      if (deleted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task deleted')));
      }
    });
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getRelativeTime(DateTime date, DateTime now) {
    final difference = date.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inDays > 0) {
        return '${absDiff.inDays} days ago';
      } else if (absDiff.inHours > 0) {
        return '${absDiff.inHours} hours ago';
      } else {
        return '${absDiff.inMinutes} minutes ago';
      }
    } else {
      if (difference.inDays > 0) {
        return 'in ${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return 'in ${difference.inHours} hours';
      } else {
        return 'in ${difference.inMinutes} minutes';
      }
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }
}

/// Quick actions bottom sheet for tasks
class _TaskQuickActionsSheet extends StatelessWidget {
  const _TaskQuickActionsSheet({
    required this.task,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onOpenNote,
    required this.onSnooze,
    required this.onDelete,
  });

  final domain.Task task;
  final Future<void> Function() onToggleStatus;
  final Future<void> Function() onEdit;
  final Future<void> Function()? onOpenNote;
  final Future<void> Function()? onSnooze;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == domain.TaskStatus.completed;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Task title
          Text(
            task.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 24),

          // Actions
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ActionChip(
                icon: isCompleted ? Icons.undo : Icons.check,
                label: isCompleted ? 'Reopen' : 'Complete',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(onToggleStatus());
                },
              ),
              _ActionChip(
                icon: Icons.edit,
                label: 'Edit',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(onEdit());
                },
              ),
              if (!DomainTaskController.isStandaloneNoteId(task.noteId))
                _ActionChip(
                  icon: Icons.note,
                  label: 'Open Note',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenNote?.call();
                  },
                ),
              if (task.dueDate != null && !isCompleted)
                _ActionChip(
                  icon: Icons.snooze,
                  label: 'Snooze',
                  onTap: () {
                    Navigator.of(context).pop();
                    onSnooze?.call();
                  },
                ),
              _ActionChip(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(onDelete());
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final void Function() onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Material(
      color: effectiveColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Snooze duration dialog
class _SnoozeDurationDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Snooze Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('1 hour'),
            onTap: () => Navigator.of(context).pop(const Duration(hours: 1)),
          ),
          ListTile(
            title: const Text('3 hours'),
            onTap: () => Navigator.of(context).pop(const Duration(hours: 3)),
          ),
          ListTile(
            title: const Text('Tomorrow'),
            onTap: () => Navigator.of(context).pop(const Duration(days: 1)),
          ),
          ListTile(
            title: const Text('Next week'),
            onTap: () => Navigator.of(context).pop(const Duration(days: 7)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
