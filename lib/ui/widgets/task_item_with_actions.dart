import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show unifiedTaskServiceProvider, taskReminderBridgeProvider;
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_time_tracker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Enhanced task item widget with actions and time tracking
/// Uses UnifiedTaskService for all operations - no VoidCallback usage
class TaskItemWithActions extends ConsumerStatefulWidget {
  const TaskItemWithActions({
    super.key,
    required this.task,
    required this.content,
    this.notes,
    this.labels,
  });

  final NoteTask task;
  final String content;  // Decrypted content
  final String? notes;   // Decrypted notes
  final String? labels;  // Decrypted labels

  @override
  ConsumerState<TaskItemWithActions> createState() =>
      _TaskItemWithActionsState();
}

class _TaskItemWithActionsState extends ConsumerState<TaskItemWithActions> {
  bool _isExpanded = false;

  AppLogger get _logger => ref.read(loggerProvider);

  Future<void> _toggleTaskStatus() async {
    final unifiedService = ref.read(unifiedTaskServiceProvider);
    final newStatus = widget.task.status == TaskStatus.completed
        ? TaskStatus.open
        : TaskStatus.completed;

    await unifiedService.onStatusChanged(widget.task.id, newStatus);
  }

  Future<void> _editTask() async {
    // Convert NoteTask to domain.Task for the dialog
    final domainTask = TaskMapper.toDomain(
      widget.task,
      content: widget.content,
      notes: widget.notes,
      labels: widget.labels,
    );

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: domainTask,
        taskContent: widget.content,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _applyTaskUpdates(result);
    }
  }

  Future<void> _applyTaskUpdates(TaskMetadata metadata) async {
    try {
      final unifiedService = ref.read(unifiedTaskServiceProvider);

      // Update task priority (convert domain to database priority)
      final dbPriority = TaskMapper.mapPriorityToDb(metadata.priority);
      if (dbPriority != widget.task.priority) {
        await unifiedService.onPriorityChanged(widget.task.id, dbPriority);
      }

      // Update due date
      if (metadata.dueDate != widget.task.dueDate) {
        await unifiedService.onDueDateChanged(widget.task.id, metadata.dueDate);
      }

      // Update other fields through the service
      await unifiedService.updateTask(
        taskId: widget.task.id,
        content: widget.content,
        priority: dbPriority,
        dueDate: metadata.dueDate,
        estimatedMinutes: metadata.estimatedMinutes,
        labels: metadata.labels,
        notes: metadata.notes,
      );

      // Handle reminder changes
      if (metadata.hasReminder &&
          metadata.reminderTime != null &&
          metadata.dueDate != null) {
        final reminderBridge = ref.read(taskReminderBridgeProvider);

        if (widget.task.reminderId == null) {
          // Create new reminder
          final updatedTask = await unifiedService.getTask(widget.task.id);
          if (updatedTask != null) {
            final duration = metadata.dueDate!.difference(metadata.reminderTime!);
            await reminderBridge.createTaskReminder(
              task: updatedTask,
              beforeDueDate: duration.abs(),
            );
          }
        } else {
          // Update existing reminder
          final updatedTask = await unifiedService.getTask(widget.task.id);
          if (updatedTask != null) {
            await reminderBridge.updateTaskReminder(updatedTask);
          }
        }
      } else if (!metadata.hasReminder && widget.task.reminderId != null) {
        // Cancel existing reminder
        final reminderBridge = ref.read(taskReminderBridgeProvider);
        await reminderBridge.cancelTaskReminder(widget.task);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated')),
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update task',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': widget.task.id},
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.onDeleted(widget.task.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted')),
          );
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to delete task',
          error: error,
          stackTrace: stackTrace,
          data: {'taskId': widget.task.id},
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
    final task = widget.task;

    final isCompleted = task.status == TaskStatus.completed;
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !isCompleted;

    Color? priorityColor;
    IconData priorityIcon = Icons.flag_outlined;
    switch (task.priority) {
      case TaskPriority.urgent:
        priorityColor = Colors.red;
        priorityIcon = Icons.flag;
        break;
      case TaskPriority.high:
        priorityColor = Colors.orange;
        priorityIcon = Icons.flag;
        break;
      case TaskPriority.low:
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
              widget.content,
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
                if (widget.notes?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.notes!,
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
                  children: [
                    // Priority indicator
                    if (task.priority != TaskPriority.medium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor?.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              priorityIcon,
                              size: 12,
                              color: priorityColor,
                            ),
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
                            horizontal: 6, vertical: 2),
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
                    if (task.reminderId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
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

                    // Time tracker
                    CompactTimeTracker(task: task),

                    // Labels
                    if (widget.labels?.isNotEmpty == true)
                      ...widget.labels!.split(',').map(
                            (label) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label.trim().toString(),
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
                  icon:
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
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
              child: TaskTimeTrackerWidget(
                task: task,
                onTimeUpdated: () {
                  // Time update is handled through the service
                  setState(() {}); // Just refresh UI
                },
              ),
            ),
        ],
      ),
    );
  }
}
