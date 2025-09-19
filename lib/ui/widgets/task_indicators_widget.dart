import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';

/// Widget for displaying visual indicators for task metadata (due date, priority, etc.)
class TaskIndicatorsWidget extends StatelessWidget {
  const TaskIndicatorsWidget({
    super.key,
    required this.task,
    this.compact = false,
  });

  final NoteTask task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    final indicators = <Widget>[];

    // Priority indicator
    if (task.priority != TaskPriority.medium) {
      indicators.add(
        _buildPriorityIndicator(task.priority, colorScheme, compact),
      );
    }

    // Due date indicator
    if (task.dueDate != null) {
      indicators.add(
        _buildDueDateIndicator(task.dueDate!, now, colorScheme, compact),
      );
    }

    // Reminder indicator
    if (task.reminderId != null) {
      indicators.add(
        _buildReminderIndicator(colorScheme, compact),
      );
    }

    // Labels indicator
    if (task.labels?.isNotEmpty == true) {
      final labels = task.labels!.split(',').where((l) => l.isNotEmpty).toList();
      if (labels.isNotEmpty) {
        indicators.add(
          _buildLabelsIndicator(labels, colorScheme, compact),
        );
      }
    }

    // Time estimate indicator
    if (task.estimatedMinutes != null) {
      indicators.add(
        _buildTimeEstimateIndicator(task.estimatedMinutes!, colorScheme, compact),
      );
    }

    if (indicators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: 2,
      children: indicators,
    );
  }

  Widget _buildPriorityIndicator(TaskPriority priority, ColorScheme colorScheme, bool compact) {
    final color = _getPriorityColor(priority);
    final size = compact ? 14.0 : 16.0;

    return Tooltip(
      message: '${_getPriorityLabel(priority)} Priority',
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          Icons.flag,
          size: size,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDueDateIndicator(DateTime dueDate, DateTime now, ColorScheme colorScheme, bool compact) {
    final isOverdue = dueDate.isBefore(now);
    final isToday = dueDate.day == now.day && 
                   dueDate.month == now.month && 
                   dueDate.year == now.year;
    final isTomorrow = dueDate.difference(now).inDays == 0 && dueDate.day == now.day + 1;

    Color color;
    String tooltip;
    IconData icon = Icons.calendar_today;

    if (isOverdue) {
      color = Colors.red;
      tooltip = 'Overdue: ${_formatDate(dueDate)}';
      icon = Icons.warning;
    } else if (isToday) {
      color = Colors.orange;
      tooltip = 'Due today at ${_formatTime(dueDate)}';
      icon = Icons.today;
    } else if (isTomorrow) {
      color = Colors.blue;
      tooltip = 'Due tomorrow at ${_formatTime(dueDate)}';
    } else {
      color = colorScheme.primary;
      tooltip = 'Due: ${_formatDate(dueDate)} at ${_formatTime(dueDate)}';
    }

    final size = compact ? 14.0 : 16.0;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }

  Widget _buildReminderIndicator(ColorScheme colorScheme, bool compact) {
    final size = compact ? 14.0 : 16.0;

    return Tooltip(
      message: 'Reminder set',
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 3),
        decoration: BoxDecoration(
          color: colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.secondary.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          Icons.notifications,
          size: size,
          color: colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildLabelsIndicator(List<String> labels, ColorScheme colorScheme, bool compact) {
    final size = compact ? 14.0 : 16.0;
    final tooltip = 'Labels: ${labels.join(', ')}';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 3),
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.tertiary.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label,
              size: size,
              color: colorScheme.tertiary,
            ),
            if (!compact && labels.length == 1) ...[
              const SizedBox(width: 2),
              Text(
                labels.first,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else if (!compact && labels.length > 1) ...[
              const SizedBox(width: 2),
              Text(
                '${labels.length}',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEstimateIndicator(int minutes, ColorScheme colorScheme, bool compact) {
    final size = compact ? 14.0 : 16.0;
    final tooltip = 'Estimated time: ${_formatDuration(minutes)}';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 3),
        decoration: BoxDecoration(
          color: colorScheme.outline.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: size,
              color: colorScheme.outline,
            ),
            if (!compact) ...[
              const SizedBox(width: 2),
              Text(
                _formatDurationShort(minutes),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  String _formatDurationShort(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      return '${hours}h';
    }
  }
}
