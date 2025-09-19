import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Enhanced task item widget with rich metadata display and swipe actions
class TaskItemWidget extends StatelessWidget {
  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenNote,
    this.onSnooze,
    this.showSourceNote = true,
  });

  final NoteTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;
  final VoidCallback? onSnooze;
  final bool showSourceNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = task.status == TaskStatus.completed;

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
          onToggle();
          return false; // Don't dismiss, just toggle
        } else if (direction == DismissDirection.endToStart) {
          // Delete action
          return await _showDeleteConfirmation(context);
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onEdit,
            onLongPress: () => _showQuickActions(context),
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
                      GestureDetector(
                        onTap: onToggle,
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

                      const SizedBox(width: 12),

                      // Task content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task title
                            Text(
                              task.content,
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

                            // Task description/notes
                            if (task.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.notes!,
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
                                if (showSourceNote && onOpenNote != null)
                                  _buildSourceNoteChip(context),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Quick actions menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onSelected: (action) => _handleQuickAction(context, action),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('Edit'),
                              ],
                            ),
                          ),
                          if (onOpenNote != null)
                            PopupMenuItem(
                              value: 'open_note',
                              child: Row(
                                children: [
                                  Icon(Icons.note, size: 18, color: colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  const Text('Open Note'),
                                ],
                              ),
                            ),
                          if (onSnooze != null && !isCompleted)
                            PopupMenuItem(
                              value: 'snooze',
                              child: Row(
                                children: [
                                  Icon(Icons.snooze, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  const Text('Snooze'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Time tracking (if available)
                  if (task.estimatedMinutes != null || task.actualMinutes != null) ...[
                    const SizedBox(height: 8),
                    _buildTimeTracking(context),
                  ],
                ],
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
    return Container(
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
    );
  }

  Widget _buildDueDateChip(BuildContext context, DateTime dueDate) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && task.status != TaskStatus.completed;
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
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
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

  Widget _buildSourceNoteChip(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onOpenNote,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _buildTimeTracking(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final estimated = task.estimatedMinutes;
    final actual = task.actualMinutes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
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

  void _showQuickActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => _TaskQuickActionsSheet(
        task: task,
        onEdit: onEdit,
        onToggle: onToggle,
        onDelete: onDelete,
        onOpenNote: onOpenNote,
        onSnooze: onSnooze,
      ),
    );
  }

  void _handleQuickAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onEdit();
        break;
      case 'open_note':
        onOpenNote?.call();
        break;
      case 'snooze':
        onSnooze?.call();
        break;
      case 'delete':
        _confirmDelete(context);
        break;
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
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
            onPressed: () {
              Navigator.of(context).pop(true);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _confirmDelete(BuildContext context) {
    _showDeleteConfirmation(context);
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
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.onOpenNote,
    this.onSnooze,
  });

  final NoteTask task;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;

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
            task.content,
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
                  onToggle();
                },
              ),
              
              _ActionChip(
                icon: Icons.edit,
                label: 'Edit',
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              
              if (onOpenNote != null)
                _ActionChip(
                  icon: Icons.note,
                  label: 'Open Note',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenNote!();
                  },
                ),
              
              if (onSnooze != null && !isCompleted)
                _ActionChip(
                  icon: Icons.snooze,
                  label: 'Snooze',
                  onTap: () {
                    Navigator.of(context).pop();
                    onSnooze!();
                  },
                ),
              
              _ActionChip(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
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
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Material(
      color: effectiveColor.withOpacity(0.1),
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
