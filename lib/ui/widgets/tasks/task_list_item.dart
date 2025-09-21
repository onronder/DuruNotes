import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart';
import 'package:duru_notes/models/note_task.dart'
    show UiNoteTask, UiTaskStatus, UiTaskPriority;
import 'package:flutter/material.dart';

/// Fully migrated task list item widget
/// Works with both database NoteTask and legacy UiNoteTask models
class TaskListItem extends StatelessWidget {
  final NoteTask? dbTask;
  final UiNoteTask? uiTask;
  final UnifiedTaskCallbacks callbacks;
  final bool isSelected;
  final bool showSubtasks;
  final int indentLevel;

  const TaskListItem({
    super.key,
    this.dbTask,
    this.uiTask,
    required this.callbacks,
    this.isSelected = false,
    this.showSubtasks = true,
    this.indentLevel = 0,
  }) : assert(dbTask != null || uiTask != null,
            'Either dbTask or uiTask must be provided');

  @override
  Widget build(BuildContext context) {
    if (dbTask != null) {
      return TaskWidgetAdapter(
        dbTask: dbTask,
        builder: (uiTask) => _buildListItem(context, uiTask),
      );
    } else {
      return _buildListItem(context, uiTask!);
    }
  }

  Widget _buildListItem(BuildContext context, UiNoteTask task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final taskId = task.id;

    return Container(
      margin: EdgeInsets.only(
        left: indentLevel * 24.0,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => callbacks.onEdit(taskId),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                _buildCheckbox(context, task),
                const SizedBox(width: 12),

                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task content
                      Text(
                        task.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: task.status == UiTaskStatus.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.status == UiTaskStatus.completed
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : null,
                        ),
                      ),

                      // Meta information row
                      if (task.dueDate != null ||
                          task.priority != UiTaskPriority.none ||
                          task.subtasks.isNotEmpty ||
                          task.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (task.priority != UiTaskPriority.none)
                              _buildPriorityChip(context, task),
                            if (task.dueDate != null)
                              _buildDueDateChip(context, task),
                            if (task.subtasks.isNotEmpty)
                              _buildSubtaskIndicator(context, task),
                            ...task.tags.take(3).map(
                                  (tag) => _buildTagChip(context, tag),
                                ),
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
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        callbacks.onEdit(taskId);
                        break;
                      case 'priority':
                        _showPriorityDialog(context, task);
                        break;
                      case 'duedate':
                        _showDueDatePicker(context, task);
                        break;
                      case 'delete':
                        _confirmDelete(context, taskId);
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
                        title:
                            Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _buildCheckbox(BuildContext context, UiNoteTask task) {
    final isCompleted = task.status == UiTaskStatus.completed;
    final colorScheme = Theme.of(context).colorScheme;

    return Checkbox(
      value: isCompleted,
      onChanged: (value) async {
        final newStatus = value! ? TaskStatus.completed : TaskStatus.open;
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

  Widget _buildPriorityChip(BuildContext context, UiNoteTask task) {
    final color = _getPriorityColor(task.priority);
    final icon = _getPriorityIcon(task.priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildDueDateChip(BuildContext context, UiNoteTask task) {
    if (task.dueDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final dueDate = task.dueDate!;
    final isOverdue =
        dueDate.isBefore(now) && task.status != UiTaskStatus.completed;
    final isDueToday = _isSameDay(dueDate, now);

    final color = isOverdue
        ? Colors.red
        : isDueToday
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildSubtaskIndicator(BuildContext context, UiNoteTask task) {
    final completedCount =
        task.subtasks.where((t) => t.status == UiTaskStatus.completed).length;
    final totalCount = task.subtasks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.checklist, size: 14),
          const SizedBox(width: 4),
          Text(
            '$completedCount/$totalCount',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  void _showPriorityDialog(BuildContext context, UiNoteTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskPriority.values.map((priority) {
            return ListTile(
              leading: Icon(
                _getPriorityIcon(
                    TaskModelConverter.dbPriorityToUiPriority(priority)),
                color: _getPriorityColor(
                    TaskModelConverter.dbPriorityToUiPriority(priority)),
              ),
              title: Text(priority.name),
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

  void _showDueDatePicker(BuildContext context, UiNoteTask task) async {
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

  void _confirmDelete(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await callbacks.onDeleted(taskId);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(UiTaskPriority priority) {
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

  IconData _getPriorityIcon(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return Icons.priority_high;
      case UiTaskPriority.high:
        return Icons.flag;
      case UiTaskPriority.medium:
        return Icons.flag_outlined;
      case UiTaskPriority.low:
        return Icons.low_priority;
      case UiTaskPriority.none:
        return Icons.radio_button_unchecked;
    }
  }

  String _getPriorityLabel(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return 'Urgent';
      case UiTaskPriority.high:
        return 'High';
      case UiTaskPriority.medium:
        return 'Medium';
      case UiTaskPriority.low:
        return 'Low';
      case UiTaskPriority.none:
        return '';
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
