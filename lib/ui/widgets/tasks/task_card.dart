import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart';
import 'package:duru_notes/models/note_task.dart';
import 'package:flutter/material.dart';

/// Card-based task widget for grid or board views
/// Now supports both database NoteTask and legacy UiNoteTask models
class TaskCard extends StatelessWidget {
  final NoteTask? dbTask;
  final UiNoteTask? legacyTask; // For backward compatibility
  final UnifiedTaskCallbacks callbacks;
  final bool isSelected;
  final bool showSubtasks;

  const TaskCard({
    super.key,
    this.dbTask,
    this.legacyTask,
    required this.callbacks,
    this.isSelected = false,
    this.showSubtasks = true,
  }) : assert(dbTask != null || legacyTask != null,
            'Either dbTask or legacyTask must be provided');

  @override
  Widget build(BuildContext context) {
    // Use adapter for backward compatibility
    if (dbTask != null) {
      return TaskWidgetAdapter(
        dbTask: dbTask,
        builder: (uiTask) => _buildCard(context, uiTask),
      );
    } else {
      return _buildCard(context, legacyTask!);
    }
  }

  Widget _buildCard(BuildContext context, UiNoteTask task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => callbacks.onEdit(dbTask?.id ?? legacyTask!.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 120,
            maxWidth: 300,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with checkbox and priority
              Row(
                children: [
                  _buildCheckbox(context, task),
                  const Spacer(),
                  if (task.priority != UiTaskPriority.none)
                    _buildPriorityIndicator(context, task),
                  ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            callbacks.onEdit(task.id);
                            break;
                          case 'delete':
                            callbacks.onDeleted(task.id);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Task content
              Expanded(
                child: Text(
                  task.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: task.status == UiTaskStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.status == UiTaskStatus.completed
                        ? colorScheme.onSurface.withOpacity(0.5)
                        : null,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Footer with due date and subtasks
              if (task.dueDate != null || task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (task.dueDate != null)
                      Expanded(child: _buildDueDateChip(context, task)),
                    if (task.subtasks.isNotEmpty) ...[
                      if (task.dueDate != null) const SizedBox(width: 8),
                      _buildSubtaskIndicator(context, task),
                    ],
                  ],
                ),
              ],

              // Tags if present
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: task.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context, UiNoteTask task) {
    final status = task.status;
    return Checkbox(
      value: status == UiTaskStatus.completed,
      onChanged: (value) {
        final newStatus = value! ? TaskStatus.completed : TaskStatus.open;
        callbacks.onStatusChanged(task.id, newStatus);
      },
    );
  }

  Widget _buildPriorityIndicator(BuildContext context, UiNoteTask task) {
    final priority = task.priority;
    Color color;
    IconData icon;

    switch (priority) {
      case UiTaskPriority.urgent:
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case UiTaskPriority.high:
        color = Colors.orange;
        icon = Icons.flag;
        break;
      case UiTaskPriority.medium:
        color = Colors.blue;
        icon = Icons.flag_outlined;
        break;
      case UiTaskPriority.low:
      case UiTaskPriority.none:
        color = Colors.grey;
        icon = Icons.flag_outlined;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildDueDateChip(BuildContext context, UiNoteTask task) {
    final dueDate = task.dueDate;
    if (dueDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now);
    final isDueToday = dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;

    return Chip(
      avatar: Icon(
        Icons.calendar_today,
        size: 14,
        color: isOverdue ? Colors.red : (isDueToday ? Colors.orange : null),
      ),
      label: Text(
        '${dueDate.day}/${dueDate.month}',
        style: TextStyle(
          fontSize: 12,
          color: isOverdue ? Colors.red : (isDueToday ? Colors.orange : null),
        ),
      ),
      backgroundColor: isOverdue
          ? Colors.red.withOpacity(0.1)
          : (isDueToday ? Colors.orange.withOpacity(0.1) : null),
    );
  }

  Widget _buildSubtaskIndicator(BuildContext context, UiNoteTask task) {
    final subtasks = task.subtasks;
    if (subtasks.isEmpty) return const SizedBox.shrink();

    final completedCount =
        subtasks.where((t) => t.status == UiTaskStatus.completed).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            '$completedCount/${subtasks.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
