// ignore_for_file: deprecated_member_use
import 'package:duru_notes/models/note_task.dart';
import 'package:flutter/material.dart';

/// Task display modes for different contexts
@Deprecated('Use TaskDisplayMode from task_widget_factory.dart instead')
enum TaskDisplayMode {
  list, // Standard list view
  tree, // Hierarchical tree view
  card, // Card-based view
  compact, // Minimal compact view
}

/// Callbacks for task interactions
@Deprecated('Use UnifiedTaskCallbacks from task_widget_adapter.dart instead. '
    'This class does not support proper task IDs and will be removed.')
class TaskCallbacks {
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final Function(UiTaskPriority)? onPriorityChanged;
  final Function(DateTime)? onDueDateChanged;

  const TaskCallbacks({
    this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onPriorityChanged,
    this.onDueDateChanged,
  });
}

/// Base widget for all task display components
///
/// @Deprecated Use the new task widgets with UnifiedTaskCallbacks instead:
/// - TaskListItem for list views
/// - TaskTreeNode for hierarchical views
/// - TaskCard for card views
/// - TaskWidgetFactory to create any type
///
/// This class uses the legacy TaskCallbacks which don't support proper task IDs.
@Deprecated(
    'Use TaskListItem, TaskTreeNode, or TaskCard with UnifiedTaskCallbacks instead. '
    'This base class will be removed in the next major version.')
abstract class BaseTaskWidget extends StatelessWidget {
  final UiNoteTask task;
  final TaskCallbacks callbacks;
  final bool isSelected;
  final bool showSubtasks;
  final int indentLevel;

  const BaseTaskWidget({
    super.key,
    required this.task,
    required this.callbacks,
    this.isSelected = false,
    this.showSubtasks = true,
    this.indentLevel = 0,
  });

  // Shared UI components

  /// Build the checkbox for task completion
  Widget buildCheckbox(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = task.status == UiTaskStatus.completed;
    final checkboxColor =
        isCompleted ? getPriorityColor(task.priority) : colorScheme.outline;

    return GestureDetector(
      onTap: callbacks.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(
            color: checkboxColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
          color:
              isCompleted ? checkboxColor.withOpacity(0.1) : Colors.transparent,
        ),
        child: isCompleted
            ? Icon(
                Icons.check,
                size: 16,
                color: checkboxColor,
              )
            : null,
      ),
    );
  }

  /// Build priority indicator
  Widget buildPriorityIndicator(BuildContext context) {
    if (task.priority == UiTaskPriority.none) {
      return const SizedBox.shrink();
    }

    final color = getPriorityColor(task.priority);
    final icon = getPriorityIcon(task.priority);

    return Tooltip(
      message: getPriorityLabel(task.priority),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }

  /// Build due date chip
  Widget buildDueDateChip(BuildContext context) {
    if (task.dueDate == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final now = DateTime.now();
    final dueDate = task.dueDate!;
    final isOverdue =
        dueDate.isBefore(now) && task.status != UiTaskStatus.completed;
    final isDueToday = _isSameDay(dueDate, now);
    final isDueTomorrow = _isSameDay(
      dueDate,
      now.add(const Duration(days: 1)),
    );

    String label;
    if (isDueToday) {
      label = 'Today';
    } else if (isDueTomorrow) {
      label = 'Tomorrow';
    } else if (isOverdue) {
      final daysOverdue = now.difference(dueDate).inDays;
      label = '$daysOverdue days overdue';
    } else {
      label = _formatDate(dueDate);
    }

    final chipColor = isOverdue
        ? theme.colorScheme.error
        : isDueToday
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceVariant;

    final textColor = isOverdue || isDueToday
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => callbacks.onDueDateChanged?.call(dueDate),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(isOverdue ? 1.0 : 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 12,
              color: isOverdue || isDueToday ? textColor : chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOverdue || isDueToday
                    ? textColor
                    : chipColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build task content with strikethrough if completed
  Widget buildTaskContent(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == UiTaskStatus.completed;

    return Text(
      task.content,
      style: theme.textTheme.bodyLarge?.copyWith(
        decoration: isCompleted ? TextDecoration.lineThrough : null,
        color:
            isCompleted ? theme.colorScheme.onSurface.withOpacity(0.5) : null,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build subtask indicator
  Widget buildSubtaskIndicator(BuildContext context) {
    if (task.subtasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount =
        task.subtasks.where((t) => t.status == UiTaskStatus.completed).length;
    final totalCount = task.subtasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              backgroundColor: Colors.grey.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$completedCount/$totalCount',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // Helper methods

  /// Get color for priority level
  Color getPriorityColor(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return Colors.red;
      case UiTaskPriority.high:
        return Colors.orange;
      case UiTaskPriority.medium:
        return Colors.blue;
      case UiTaskPriority.low:
        return Colors.grey;
      case UiTaskPriority.none:
        return Colors.grey.withOpacity(0.5);
    }
  }

  /// Get icon for priority level
  IconData getPriorityIcon(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return Icons.priority_high;
      case UiTaskPriority.high:
        return Icons.arrow_upward;
      case UiTaskPriority.medium:
        return Icons.remove;
      case UiTaskPriority.low:
        return Icons.arrow_downward;
      case UiTaskPriority.none:
        return Icons.radio_button_unchecked;
    }
  }

  /// Get label for priority level
  String getPriorityLabel(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return 'Urgent';
      case UiTaskPriority.high:
        return 'High Priority';
      case UiTaskPriority.medium:
        return 'Medium Priority';
      case UiTaskPriority.low:
        return 'Low Priority';
      case UiTaskPriority.none:
        return 'No Priority';
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < 7) {
      // Within a week, show day name
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return dayNames[date.weekday - 1];
    } else if (date.year == now.year) {
      // Same year, show month and day
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${monthNames[date.month - 1]} ${date.day}';
    } else {
      // Different year, show full date
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
