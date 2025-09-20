import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_time_tracker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Enhanced task item widget with actions and time tracking
class TaskItemWithActions extends ConsumerStatefulWidget {
  const TaskItemWithActions({
    super.key,
    required this.task,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final NoteTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  ConsumerState<TaskItemWithActions> createState() => _TaskItemWithActionsState();
}

class _TaskItemWithActionsState extends ConsumerState<TaskItemWithActions> {
  bool _isExpanded = false;

  Future<void> _toggleTaskStatus() async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      await enhancedTaskService.toggleTaskStatus(widget.task.id);
      widget.onToggle?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e')),
        );
      }
    }
  }

  Future<void> _editTask() async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: widget.task,
        taskContent: widget.task.content,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      try {
        final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
        await enhancedTaskService.updateTask(
          taskId: widget.task.id,
          content: widget.task.content, // Keep existing content
          priority: result.priority,
          dueDate: result.dueDate,
          estimatedMinutes: result.estimatedMinutes,
          notes: result.notes,
          labels: result.labels.isNotEmpty ? {'labels': result.labels} : null,
        );
        
        // Update reminder if changed
        if (result.hasReminder && result.reminderTime != null) {
          // Get the updated task to refresh reminder
          final db = ref.read(appDbProvider);
          final updatedTask = await db.getTaskById(widget.task.id);
          if (updatedTask != null) {
            final reminderBridge = ref.read(taskReminderBridgeProvider);
            await reminderBridge.updateTaskReminder(updatedTask);
          }
        } else if (!result.hasReminder && widget.task.reminderId != null) {
          final reminderBridge = ref.read(taskReminderBridgeProvider);
          await reminderBridge.cancelTaskReminder(widget.task.id);
        }
        
        widget.onEdit?.call();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating task: $e')),
          );
        }
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
        final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
        await enhancedTaskService.deleteTask(widget.task.id);
        widget.onDelete?.call();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting task: $e')),
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
              task.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted 
                  ? colorScheme.onSurface.withOpacity(0.5)
                  : colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.notes?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      task.notes!,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor?.withOpacity(0.1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOverdue 
                            ? Colors.red.withOpacity(0.1)
                            : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: isOverdue ? Colors.red : colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.MMMd().format(task.dueDate!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isOverdue ? Colors.red : colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Reminder indicator
                    if (task.reminderId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
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
                    if (task.labels?.isNotEmpty == true)
                      ...task.labels!.split(',').map((label) => 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label.trim(),
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
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
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
                onTimeUpdated: widget.onEdit,
              ),
            ),
        ],
      ),
    );
  }
}
