import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/ui/widgets/tasks/domain_task_callbacks.dart';
import 'package:flutter/material.dart';

/// Task list item widget using domain entities
/// Production-grade replacement for TaskListItem with domain.Task
class DomainTaskListItem extends StatelessWidget {
  final domain.Task task;
  final DomainTaskCallbacks callbacks;
  final bool isSelected;
  final bool showSubtasks;
  final int indentLevel;

  const DomainTaskListItem({
    super.key,
    required this.task,
    required this.callbacks,
    this.isSelected = false,
    this.showSubtasks = true,
    this.indentLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.only(left: indentLevel * 24.0, bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => callbacks.onEdit(task.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                _buildCheckbox(context),
                const SizedBox(width: 12),

                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task title
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: task.status == domain.TaskStatus.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.status == domain.TaskStatus.completed
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : null,
                        ),
                      ),

                      // Task description (if present)
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Meta information row
                      if (task.dueDate != null ||
                          task.priority != domain.TaskPriority.low ||
                          task.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (task.priority != domain.TaskPriority.low)
                              _buildPriorityChip(context),
                            if (task.dueDate != null)
                              _buildDueDateChip(context),
                            ...task.tags
                                .take(3)
                                .map((tag) => _buildTagChip(context, tag)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        callbacks.onEdit(task.id);
                        break;
                      case 'priority':
                        _showPriorityDialog(context);
                        break;
                      case 'duedate':
                        _showDueDatePicker(context);
                        break;
                      case 'delete':
                        _confirmDelete(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'priority',
                      child: ListTile(
                        leading: Icon(Icons.flag),
                        title: Text('Set Priority'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duedate',
                      child: ListTile(
                        leading: Icon(Icons.calendar_today),
                        title: Text('Set Due Date'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final isCompleted = task.status == domain.TaskStatus.completed;
    final colorScheme = Theme.of(context).colorScheme;

    return Checkbox(
      value: isCompleted,
      onChanged: (value) async {
        final newStatus = value!
            ? domain.TaskStatus.completed
            : domain.TaskStatus.pending;
        await callbacks.onStatusChanged(task.id, newStatus);
      },
      activeColor: _getPriorityColor(task.priority),
      side: BorderSide(
        color: isCompleted
            ? _getPriorityColor(task.priority)
            : colorScheme.outline,
        width: 2,
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context) {
    final color = _getPriorityColor(task.priority);
    final icon = _getPriorityIcon(task.priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _getPriorityLabel(task.priority),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(BuildContext context) {
    if (task.dueDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final dueDate = task.dueDate!;
    final isOverdue =
        dueDate.isBefore(now) && task.status != domain.TaskStatus.completed;
    final isDueToday = _isSameDay(dueDate, now);

    final color = isOverdue
        ? Colors.red
        : isDueToday
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _formatDate(dueDate, isOverdue, isDueToday),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('#$tag', style: Theme.of(context).textTheme.bodySmall),
    );
  }

  void _showPriorityDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: domain.TaskPriority.values.map((priority) {
            return ListTile(
              leading: Icon(
                _getPriorityIcon(priority),
                color: _getPriorityColor(priority),
              ),
              title: Text(_getPriorityLabel(priority)),
              onTap: () async {
                await callbacks.onPriorityChanged(task.id, priority);
                if (context.mounted) Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDueDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      await callbacks.onDueDateChanged(task.id, date);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await callbacks.onDeleted(task.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.urgent:
        return Colors.red;
      case domain.TaskPriority.high:
        return Colors.orange;
      case domain.TaskPriority.medium:
        return Colors.blue;
      case domain.TaskPriority.low:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.urgent:
        return Icons.priority_high;
      case domain.TaskPriority.high:
        return Icons.flag;
      case domain.TaskPriority.medium:
        return Icons.flag_outlined;
      case domain.TaskPriority.low:
        return Icons.low_priority;
    }
  }

  String _getPriorityLabel(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.urgent:
        return 'Urgent';
      case domain.TaskPriority.high:
        return 'High';
      case domain.TaskPriority.medium:
        return 'Medium';
      case domain.TaskPriority.low:
        return 'Low';
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date, bool isOverdue, bool isDueToday) {
    if (isOverdue) {
      final days = DateTime.now().difference(date).inDays;
      return '$days days overdue';
    } else if (isDueToday) {
      return 'Today';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
