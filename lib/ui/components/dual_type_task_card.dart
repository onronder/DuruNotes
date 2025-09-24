import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/core/migration/ui_migration_utility.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Dual-type task card that supports both NoteTask and domain.Task
class DualTypeTaskCard extends StatelessWidget {
  const DualTypeTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenNote,
  }) : assert(task is NoteTask || task is domain.Task,
            'Task must be either NoteTask or domain.Task');

  final dynamic task; // Can be NoteTask or domain.Task
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extract common properties using utility
    final taskId = UiMigrationUtility.getTaskId(task);
    final taskTitle = UiMigrationUtility.getTaskTitle(task);
    final isCompleted = UiMigrationUtility.getTaskIsCompleted(task);

    // Get task-specific properties
    final dueDate = _getDueDate();
    final priority = _getPriority();
    final notes = _getNotes();
    final labels = _getLabels();
    final noteId = _getNoteId();

    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        !isCompleted;

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
                      : isCompleted
                          ? DuruColors.accent.withOpacity(0.03)
                          : theme.colorScheme.surface,
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOverdue
                    ? DuruColors.error.withOpacity(0.2)
                    : isCompleted
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
                    color: isCompleted
                        ? DuruColors.accent.withOpacity(0.1)
                        : DuruColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Checkbox(
                    value: isCompleted,
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
                        taskTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
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
                          _buildPriorityBadge(context, priority),
                          // Due date
                          if (dueDate != null)
                            _buildDueDateBadge(context, dueDate, isOverdue),
                          // Labels
                          if (labels.isNotEmpty)
                            for (final label in labels)
                              _buildLabelBadge(context, label),
                        ],
                      ),
                      // Notes preview
                      if (notes.isNotEmpty)
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
                                  notes,
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
                    if (noteId.isNotEmpty && onOpenNote != null)
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

  DateTime? _getDueDate() {
    if (task is domain.Task) {
      return (task as domain.Task).dueDate;
    } else if (task is NoteTask) {
      return (task as NoteTask).dueDate;
    }
    return null;
  }

  dynamic _getPriority() {
    if (task is domain.Task) {
      return (task as domain.Task).priority;
    } else if (task is NoteTask) {
      return (task as NoteTask).priority;
    }
    return null;
  }

  String _getNotes() {
    if (task is domain.Task) {
      return (task as domain.Task).description ?? '';
    } else if (task is NoteTask) {
      return (task as NoteTask).notes ?? '';
    }
    return '';
  }

  List<String> _getLabels() {
    if (task is domain.Task) {
      return (task as domain.Task).tags;
    } else if (task is NoteTask) {
      final labels = (task as NoteTask).labels;
      if (labels != null && labels.isNotEmpty) {
        return [labels];
      }
    }
    return [];
  }

  String _getNoteId() {
    if (task is domain.Task) {
      return (task as domain.Task).noteId;
    } else if (task is NoteTask) {
      return (task as NoteTask).noteId;
    }
    return '';
  }

  Widget _buildPriorityBadge(BuildContext context, dynamic priority) {
    if (priority == null) return const SizedBox.shrink();

    final color = _getPriorityColor(priority);
    final icon = _getPriorityIcon(priority);
    final label = _getPriorityLabel(priority);

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
            label,
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

  Widget _buildDueDateBadge(BuildContext context, DateTime date, bool isOverdue) {
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
            _formatDueDate(date),
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

  IconData _getPriorityIcon(dynamic priority) {
    if (priority is TaskPriority) {
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
    } else if (priority is domain.TaskPriority) {
      switch (priority) {
        case domain.TaskPriority.low:
          return CupertinoIcons.arrow_down_circle;
        case domain.TaskPriority.medium:
          return CupertinoIcons.minus_circle;
        case domain.TaskPriority.high:
          return CupertinoIcons.arrow_up_circle;
        case domain.TaskPriority.urgent:
          return CupertinoIcons.exclamationmark_triangle_fill;
      }
    }
    return CupertinoIcons.minus_circle;
  }

  Color _getPriorityColor(dynamic priority) {
    if (priority is TaskPriority) {
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
    } else if (priority is domain.TaskPriority) {
      switch (priority) {
        case domain.TaskPriority.low:
          return DuruColors.surfaceVariant;
        case domain.TaskPriority.medium:
          return DuruColors.primary;
        case domain.TaskPriority.high:
          return DuruColors.warning;
        case domain.TaskPriority.urgent:
          return DuruColors.error;
      }
    }
    return DuruColors.primary;
  }

  String _getPriorityLabel(dynamic priority) {
    if (priority is TaskPriority) {
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
    } else if (priority is domain.TaskPriority) {
      switch (priority) {
        case domain.TaskPriority.low:
          return 'Low';
        case domain.TaskPriority.medium:
          return 'Medium';
        case domain.TaskPriority.high:
          return 'High';
        case domain.TaskPriority.urgent:
          return 'Urgent';
      }
    }
    return 'Medium';
  }
}