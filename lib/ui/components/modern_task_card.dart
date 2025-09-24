import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Modern task card widget with improved visual design
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenNote,
  });

  final NoteTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        task.status != TaskStatus.completed;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isOverdue
                      ? DuruColors.error.withOpacity(0.05)
                      : task.status == TaskStatus.completed
                          ? DuruColors.accent.withOpacity(0.03)
                          : theme.colorScheme.surface,
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOverdue
                    ? DuruColors.error.withOpacity(0.2)
                    : task.status == TaskStatus.completed
                        ? DuruColors.accent.withOpacity(0.2)
                        : theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.all(DuruSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox with modern styling
                Container(
                  margin: EdgeInsets.only(right: DuruSpacing.md),
                  decoration: BoxDecoration(
                    color: task.status == TaskStatus.completed
                        ? DuruColors.accent.withOpacity(0.1)
                        : DuruColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Checkbox(
                    value: task.status == TaskStatus.completed,
                    onChanged: (_) => onToggle(),
                    activeColor: DuruColors.accent,
                    checkColor: Colors.white,
                  ),
                ),
                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task text
                      Text(
                        task.content,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: task.status == TaskStatus.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.status == TaskStatus.completed
                              ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: DuruSpacing.xs),
                      // Metadata row
                      Wrap(
                        spacing: DuruSpacing.sm,
                        runSpacing: DuruSpacing.xs,
                        children: [
                          // Priority badge
                          _buildPriorityBadge(context),
                          // Due date
                          if (task.dueDate != null)
                            _buildDueDateBadge(context, isOverdue),
                          // Labels
                          if (task.labels != null && task.labels!.isNotEmpty)
                            _buildLabelBadge(context, task.labels!),
                        ],
                      ),
                      // Notes preview
                      if (task.notes != null && task.notes!.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: DuruSpacing.sm),
                          padding: EdgeInsets.all(DuruSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.doc_text,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                              SizedBox(width: DuruSpacing.xs),
                              Expanded(
                                child: Text(
                                  task.notes!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Action menu
                PopupMenuButton<String>(
                  icon: Icon(
                    CupertinoIcons.ellipsis_vertical,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(CupertinoIcons.pencil, color: DuruColors.primary),
                        title: const Text('Edit'),
                      ),
                    ),
                    if (task.noteId.isNotEmpty && onOpenNote != null)
                      PopupMenuItem(
                        value: 'open_note',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(CupertinoIcons.doc_text, color: DuruColors.primary),
                          title: const Text('Open Note'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(CupertinoIcons.trash, color: DuruColors.error),
                        title: Text('Delete', style: TextStyle(color: DuruColors.error)),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'open_note':
                        onOpenNote?.call();
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context) {
    final color = _getPriorityColor(task.priority);
    final icon = _getPriorityIcon(task.priority);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DuruSpacing.sm,
        vertical: DuruSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: DuruSpacing.xs),
          Text(
            _getPriorityLabel(task.priority),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(BuildContext context, bool isOverdue) {
    final theme = Theme.of(context);
    final color = isOverdue ? DuruColors.error : DuruColors.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DuruSpacing.sm,
        vertical: DuruSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 14,
            color: color,
          ),
          SizedBox(width: DuruSpacing.xs),
          Text(
            _formatDueDate(task.dueDate!),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelBadge(BuildContext context, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DuruSpacing.sm,
        vertical: DuruSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DuruColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.tag_fill,
            size: 12,
            color: DuruColors.accent,
          ),
          SizedBox(width: DuruSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: DuruColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today ${DateFormat.jm().format(date)}';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (dateOnly.isBefore(today)) {
      final diff = today.difference(dateOnly).inDays;
      return '$diff days overdue';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return CupertinoIcons.arrow_down_circle;
      case TaskPriority.medium:
        return CupertinoIcons.minus_circle;
      case TaskPriority.high:
        return CupertinoIcons.arrow_up_circle;
      case TaskPriority.urgent:
        return CupertinoIcons.exclamationmark_triangle_fill;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return DuruColors.surfaceVariant;
      case TaskPriority.medium:
        return DuruColors.primary;
      case TaskPriority.high:
        return DuruColors.warning;
      case TaskPriority.urgent:
        return DuruColors.error;
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
}