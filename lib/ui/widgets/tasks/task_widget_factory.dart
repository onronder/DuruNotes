import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/tasks/task_list_item.dart';
import 'package:duru_notes/ui/widgets/tasks/task_tree_node.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:duru_notes/models/note_task.dart'
    show UiNoteTask, UiTaskStatus, UiTaskPriority;
import 'package:flutter/material.dart';

/// Display modes for task widgets
enum TaskDisplayMode {
  list, // Standard list view
  tree, // Hierarchical tree view
  card, // Card-based view
  compact, // Minimal compact view
}

/// Factory for creating task widgets with unified callbacks
/// Fully migrated to support both database NoteTask and legacy UiNoteTask
class TaskWidgetFactory {
  /// Create a task widget based on display mode
  /// Supports both database NoteTask and legacy UiNoteTask models
  static Widget create({
    required TaskDisplayMode mode,
    NoteTask? dbTask,
    UiNoteTask? uiTask,
    List<NoteTask>? dbSubtasks,
    List<UiNoteTask>? uiSubtasks,
    required UnifiedTaskCallbacks callbacks,
    bool isSelected = false,
    bool showSubtasks = true,
    int indentLevel = 0,
  }) {
    assert(dbTask != null || uiTask != null,
        'Either dbTask or uiTask must be provided');

    switch (mode) {
      case TaskDisplayMode.list:
        return TaskListItem(
          dbTask: dbTask,
          uiTask: uiTask,
          callbacks: callbacks,
          isSelected: isSelected,
          showSubtasks: showSubtasks,
          indentLevel: indentLevel,
        );

      case TaskDisplayMode.tree:
        return TaskTreeNode(
          dbTask: dbTask,
          uiTask: uiTask,
          dbSubtasks: dbSubtasks ?? [],
          uiSubtasks: uiSubtasks ?? [],
          callbacks: callbacks,
          isExpanded: showSubtasks,
          depth: indentLevel,
        );

      case TaskDisplayMode.card:
        // Use TaskListItem for card mode as TaskCard was deleted
        return TaskListItem(
          dbTask: dbTask,
          uiTask: uiTask,
          callbacks: callbacks,
          isSelected: isSelected,
          showSubtasks: showSubtasks,
        );

      case TaskDisplayMode.compact:
        return _CompactTaskWidget(
          dbTask: dbTask,
          uiTask: uiTask,
          callbacks: callbacks,
          isSelected: isSelected,
        );
    }
  }

  /// Create multiple task widgets from a list
  static List<Widget> createList({
    required TaskDisplayMode mode,
    required List<NoteTask> tasks,
    required UnifiedTaskCallbacks callbacks,
    Map<String, List<NoteTask>>? subtasksMap,
    Set<String>? selectedIds,
  }) {
    return tasks
        .map((task) => create(
              mode: mode,
              dbTask: task,
              dbSubtasks: subtasksMap?[task.id],
              callbacks: callbacks,
              isSelected: selectedIds?.contains(task.id) ?? false,
            ))
        .toList();
  }
}

/// Compact task widget for minimal display
class _CompactTaskWidget extends StatelessWidget {
  final NoteTask? dbTask;
  final UiNoteTask? uiTask;
  final UnifiedTaskCallbacks callbacks;
  final bool isSelected;

  const _CompactTaskWidget({
    this.dbTask,
    this.uiTask,
    required this.callbacks,
    this.isSelected = false,
  }) : assert(dbTask != null || uiTask != null);

  @override
  Widget build(BuildContext context) {
    if (dbTask != null) {
      return TaskWidgetAdapter(
        dbTask: dbTask,
        builder: (uiTask) => _buildCompact(context, uiTask),
      );
    } else {
      return _buildCompact(context, uiTask!);
    }
  }

  Widget _buildCompact(BuildContext context, UiNoteTask task) {
    final theme = Theme.of(context);
    final isCompleted = task.status == UiTaskStatus.completed;

    return InkWell(
      onTap: () => callbacks.onEdit(task.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          border: isSelected
              ? Border(
                  left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3,
                ))
              : null,
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isCompleted,
                onChanged: (value) async {
                  final newStatus =
                      value! ? TaskStatus.completed : TaskStatus.open;
                  await callbacks.onStatusChanged(task.id, newStatus);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),

            // Content
            Expanded(
              child: Text(
                task.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Priority indicator
            if (task.priority != UiTaskPriority.none)
              Icon(
                Icons.flag,
                size: 14,
                color: _getPriorityColor(task.priority),
              ),

            // Due date indicator
            if (task.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: task.dueDate!.isBefore(DateTime.now())
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
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
        return Colors.grey.withValues(alpha: 0.5);
      default:
        return Colors.grey;
    }
  }
}
