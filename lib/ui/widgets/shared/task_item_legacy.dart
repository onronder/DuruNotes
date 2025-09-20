import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Shared task item widget with accessibility support
class TaskItem extends StatelessWidget {
  const TaskItem({
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    super.key,
    this.onEdit,
    this.onDelete,
    this.showNoteInfo = false,
  });

  final NoteTask task;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showNoteInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Determine priority color
    final priorityColor = _getPriorityColor(task.priority, colorScheme);

    // Format due date
    String? dueDateText;
    Color? dueDateColor;
    if (task.dueDate != null) {
      final now = DateTime.now();
      final dueDate = task.dueDate!;
      final difference = dueDate.difference(now);

      if (difference.isNegative && task.status != TaskStatus.completed) {
        dueDateText = l10n.overdue;
        dueDateColor = Colors.red;
      } else if (difference.inDays == 0) {
        dueDateText = l10n.today;
        dueDateColor = Colors.orange;
      } else if (difference.inDays == 1) {
        dueDateText = l10n.tomorrow;
        dueDateColor = colorScheme.primary;
      } else {
        final dateFormat = DateFormat.MMMd(l10n.localeName);
        dueDateText = dateFormat.format(task.dueDate!);
        dueDateColor = colorScheme.onSurface.withValues(alpha: 0.6);
      }
    }

    final isCompleted = task.status == TaskStatus.completed;

    return Semantics(
      label:
          '${task.content}. ${task.notes ?? ""}. ${_getPriorityLabel(task.priority, l10n)}. ${dueDateText ?? ""},',
      button: true,
      checked: isCompleted,
      onTapHint: isCompleted ? 'Mark as incomplete' : 'Mark as complete',
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCompleted
                ? colorScheme.outline.withValues(alpha: 0.2)
                : priorityColor.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Semantics(
                  excludeSemantics: true,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      onToggleComplete(value ?? false);
                    },
                    activeColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                    Text(
                      task.content,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : null,
                        ),
                      ),

                      // Description
                      if (task.notes != null &&
                          task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.notes!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Metadata row
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          // Priority badge
                          if (task.priority != TaskPriority.medium)
                            _buildPriorityBadge(
                              context,
                              task.priority,
                              priorityColor,
                              l10n,
                            ),

                          // Due date
                          if (dueDateText != null)
                            _buildDueDateChip(
                              context,
                              dueDateText,
                              dueDateColor!,
                              isCompleted,
                            ),

                          // Note info
                          if (showNoteInfo && task.noteId != null)
                            _buildNoteChip(context, colorScheme),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions menu
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    tooltip: 'More actions',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.edit),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.delete,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
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

  Widget _buildPriorityBadge(
    BuildContext context,
    TaskPriority priority,
    Color color,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    String label;
    IconData icon;

    switch (priority) {
      case TaskPriority.urgent:
        label = l10n.highPriority;
        icon = Icons.priority_high;
        break;
      case TaskPriority.high:
        label = l10n.highPriority;
        icon = Icons.arrow_upward;
        break;
      case TaskPriority.low:
        label = l10n.lowPriority;
        icon = Icons.arrow_downward;
        break;
      default:
        label = l10n.mediumPriority;
        icon = Icons.remove;
    }

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
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(
    BuildContext context,
    String text,
    Color color,
    bool isCompleted,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isCompleted ? Colors.grey : color).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: isCompleted ? Colors.grey : color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCompleted ? Colors.grey : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteChip(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_outlined,
            size: 14,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'From note',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority, ColorScheme colorScheme) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.blue;
      default:
        return colorScheme.primary;
    }
  }

  String _getPriorityLabel(TaskPriority priority, AppLocalizations l10n) {
    switch (priority) {
      case TaskPriority.urgent:
      case TaskPriority.high:
        return l10n.highPriority;
      case TaskPriority.low:
        return l10n.lowPriority;
      default:
        return l10n.mediumPriority;
    }
  }
}
