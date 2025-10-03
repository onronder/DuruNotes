import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/core/converters/task_converter.dart';
import 'package:intl/intl.dart';

/// Task card display styles
enum TaskCardStyle {
  minimal,   // Just checkbox and title
  standard,  // Checkbox, title, and metadata
  detailed,  // Everything including description
}

/// Unified task card component
/// Supports both NoteTask (database) and domain.Task types
class DuruTaskCard extends StatelessWidget {
  final dynamic task; // Can be NoteTask or domain.Task
  final TaskCardStyle style;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onStatusChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;
  final bool showSubtasks;

  const DuruTaskCard({
    super.key,
    required this.task,
    this.style = TaskCardStyle.standard,
    this.onTap,
    this.onStatusChanged,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
    this.showSubtasks = false,
  }) : assert(task is NoteTask || task is domain.Task,
            'Task must be either NoteTask or domain.Task');

  /// Factory constructor to create from database task
  factory DuruTaskCard.fromDb(NoteTask dbTask) {
    final domainTask = TaskConverter.fromLocal(dbTask);
    return DuruTaskCard(task: domainTask);
  }

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      TaskCardStyle.minimal => _buildMinimal(context),
      TaskCardStyle.standard => _buildStandard(context),
      TaskCardStyle.detailed => _buildDetailed(context),
    };
  }

  Widget _buildMinimal(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = _isTaskCompleted();
    final title = _getTaskTitle();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DuruSpacing.sm,
              vertical: DuruSpacing.xs,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isCompleted,
                  onChanged: onStatusChanged,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  activeColor: DuruColors.primary,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted
                          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = _isTaskCompleted();
    final title = _getTaskTitle();
    final priority = _getTaskPriority();
    final dueDate = _getTaskDueDate();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? DuruColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(DuruSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                Checkbox(
                  value: isCompleted,
                  onChanged: onStatusChanged,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  activeColor: DuruColors.primary,
                ),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with priority indicator
                      Row(
                        children: [
                          if (priority == TaskPriority.high) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: DuruSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                CupertinoIcons.exclamationmark,
                                size: 12,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(width: DuruSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Due date if present
                      if (dueDate != null) ...[
                        SizedBox(height: DuruSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.calendar,
                              size: 14,
                              color: _isDueSoon(dueDate)
                                  ? Colors.orange
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            SizedBox(width: DuruSpacing.xs),
                            Text(
                              _formatDueDate(dueDate),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isDueSoon(dueDate)
                                    ? Colors.orange
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions menu
                if (!isSelected)
                  IconButton(
                    onPressed: () => _showTaskMenu(context),
                    icon: Icon(
                      CupertinoIcons.ellipsis_vertical,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailed(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = _isTaskCompleted();
    final title = _getTaskTitle();
    final description = _getTaskDescription();
    final priority = _getTaskPriority();
    final dueDate = _getTaskDueDate();
    final tags = _getTaskTags();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? DuruColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority indicator bar
                if (priority == TaskPriority.high)
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.all(DuruSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox
                          Checkbox(
                            value: isCompleted,
                            onChanged: onStatusChanged,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            activeColor: DuruColors.primary,
                          ),

                          // Title and description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted
                                        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                                        : null,
                                  ),
                                ),
                                if (description != null && description.isNotEmpty) ...[
                                  SizedBox(height: DuruSpacing.sm),
                                  Text(
                                    description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Actions menu
                          if (!isSelected)
                            IconButton(
                              onPressed: () => _showTaskMenu(context),
                              icon: Icon(
                                CupertinoIcons.ellipsis,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),

                      // Tags
                      if (tags.isNotEmpty) ...[
                        SizedBox(height: DuruSpacing.md),
                        Wrap(
                          spacing: DuruSpacing.xs,
                          runSpacing: DuruSpacing.xs,
                          children: tags.map((tag) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: DuruSpacing.sm,
                                vertical: DuruSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Metadata footer
                      SizedBox(height: DuruSpacing.md),
                      Row(
                        children: [
                          // Due date
                          if (dueDate != null) ...[
                            Icon(
                              CupertinoIcons.calendar,
                              size: 16,
                              color: _isDueSoon(dueDate)
                                  ? Colors.orange
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            SizedBox(width: DuruSpacing.xs),
                            Text(
                              _formatDueDate(dueDate),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isDueSoon(dueDate)
                                    ? Colors.orange
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                            SizedBox(width: DuruSpacing.md),
                          ],

                          // Priority badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DuruSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getPriorityLabel(priority),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getPriorityColor(priority),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods to extract task properties
  bool _isTaskCompleted() {
    if (task is NoteTask) {
      return (task as NoteTask).status == TaskStatus.completed;
    } else if (task is domain.Task) {
      return (task as domain.Task).status == domain.TaskStatus.completed;
    }
    return false;
  }

  String _getTaskTitle() {
    if (task is NoteTask) {
      return (task as NoteTask).content;
    } else if (task is domain.Task) {
      return (task as domain.Task).title;
    }
    return '';
  }

  String? _getTaskDescription() {
    if (task is NoteTask) {
      return (task as NoteTask).notes;
    } else if (task is domain.Task) {
      return (task as domain.Task).description;
    }
    return null;
  }

  TaskPriority _getTaskPriority() {
    if (task is NoteTask) {
      return (task as NoteTask).priority;
    } else if (task is domain.Task) {
      return TaskConverter.convertPriorityToLocal((task as domain.Task).priority);
    }
    return TaskPriority.medium;
  }

  DateTime? _getTaskDueDate() {
    if (task is NoteTask) {
      return (task as NoteTask).dueDate;
    } else if (task is domain.Task) {
      return (task as domain.Task).dueDate;
    }
    return null;
  }

  List<String> _getTaskTags() {
    if (task is domain.Task) {
      return (task as domain.Task).tags;
    }
    // NoteTask stores tags in labels JSON field
    if (task is NoteTask) {
      final labels = (task as NoteTask).labels;
      if (labels != null && labels.isNotEmpty) {
        try {
          final decoded = labels.split(',');
          return decoded;
        } catch (_) {}
      }
    }
    return [];
  }

  bool _isDueSoon(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now);
    return diff.inDays <= 1 && !_isTaskCompleted();
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative && !_isTaskCompleted()) {
      return 'Overdue';
    } else if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Tomorrow';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(date);
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => Colors.red.shade900,
      TaskPriority.high => Colors.red,
      TaskPriority.medium => Colors.blue,
      TaskPriority.low => Colors.grey,
    };
  }

  String _getPriorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Normal',
      TaskPriority.low => 'Low',
    };
  }

  void _showTaskMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(DuruSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.pencil),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(
                _isTaskCompleted()
                    ? CupertinoIcons.circle
                    : CupertinoIcons.checkmark_circle,
              ),
              title: Text(_isTaskCompleted() ? 'Mark as incomplete' : 'Mark as complete'),
              onTap: () {
                Navigator.pop(context);
                onStatusChanged?.call(!_isTaskCompleted());
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.calendar),
              title: const Text('Set due date'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.flag),
              title: const Text('Set priority'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                CupertinoIcons.delete,
                color: Colors.red,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}