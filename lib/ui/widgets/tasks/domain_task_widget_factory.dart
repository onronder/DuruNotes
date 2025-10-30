import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/ui/widgets/tasks/domain_task_callbacks.dart';
import 'package:duru_notes/ui/widgets/tasks/domain_task_list_item.dart';
import 'package:flutter/material.dart';

/// Display modes for task widgets
enum DomainTaskDisplayMode {
  list, // Standard list view
  tree, // Hierarchical tree view
  card, // Card-based view
  compact, // Minimal compact view
}

/// Factory for creating task widgets using domain entities
/// Production-grade replacement for TaskWidgetFactory with domain.Task support
class DomainTaskWidgetFactory {
  /// Create a task widget based on display mode
  static Widget create({
    required DomainTaskDisplayMode mode,
    required domain.Task task,
    required DomainTaskCallbacks callbacks,
    List<domain.Task>? subtasks,
    bool isSelected = false,
    bool showSubtasks = true,
    int indentLevel = 0,
  }) {
    switch (mode) {
      case DomainTaskDisplayMode.list:
        return DomainTaskListItem(
          task: task,
          callbacks: callbacks,
          isSelected: isSelected,
          showSubtasks: showSubtasks,
          indentLevel: indentLevel,
        );

      case DomainTaskDisplayMode.tree:
        // TODO: Create DomainTaskTreeNode widget (Batch 2)
        // For now, use list item with indentation
        return DomainTaskListItem(
          task: task,
          callbacks: callbacks,
          isSelected: isSelected,
          showSubtasks: showSubtasks,
          indentLevel: indentLevel,
        );

      case DomainTaskDisplayMode.card:
        // Use list item for card mode (consistent with old implementation)
        return DomainTaskListItem(
          task: task,
          callbacks: callbacks,
          isSelected: isSelected,
          showSubtasks: showSubtasks,
          indentLevel: 0,
        );

      case DomainTaskDisplayMode.compact:
        return _DomainCompactTaskWidget(
          task: task,
          callbacks: callbacks,
          isSelected: isSelected,
        );
    }
  }

  /// Create multiple task widgets from a list
  static List<Widget> createList({
    required DomainTaskDisplayMode mode,
    required List<domain.Task> tasks,
    required DomainTaskCallbacks callbacks,
    Map<String, List<domain.Task>>? subtasksMap,
    Set<String>? selectedIds,
  }) {
    return tasks
        .map(
          (task) => create(
            mode: mode,
            task: task,
            subtasks: subtasksMap?[task.id],
            callbacks: callbacks,
            isSelected: selectedIds?.contains(task.id) ?? false,
          ),
        )
        .toList();
  }

  /// Create a separator widget for grouping tasks
  static Widget createSeparator({required String label, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(label, style: style),
    );
  }

  /// Create an empty state widget
  static Widget createEmptyState({
    required String message,
    IconData icon = Icons.inbox_outlined,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact task widget for minimal display using domain entities
class _DomainCompactTaskWidget extends StatelessWidget {
  final domain.Task task;
  final DomainTaskCallbacks callbacks;
  final bool isSelected;

  const _DomainCompactTaskWidget({
    required this.task,
    required this.callbacks,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == domain.TaskStatus.completed;

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
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                )
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
                  final newStatus = value!
                      ? domain.TaskStatus.completed
                      : domain.TaskStatus.pending;
                  await callbacks.onStatusChanged(task.id, newStatus);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),

            // Content
            Expanded(
              child: Text(
                task.title,
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
            if (task.priority != domain.TaskPriority.low)
              Icon(
                _getPriorityIcon(task.priority),
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
                  color: task.dueDate!.isBefore(DateTime.now()) && !isCompleted
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
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
}
