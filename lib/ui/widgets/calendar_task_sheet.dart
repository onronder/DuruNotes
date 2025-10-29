import 'dart:async';

import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Bottom sheet showing tasks for a selected date
///
/// POST-ENCRYPTION: Now uses domain.Task with decrypted content
class CalendarTaskSheet extends ConsumerWidget {
  const CalendarTaskSheet({
    super.key,
    required this.selectedDate,
    required this.tasks,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
    this.onOpenNote,
  });

  final DateTime selectedDate;
  final List<domain.Task> tasks;
  final void Function(domain.Task) onTaskToggle;
  final void Function(domain.Task) onTaskEdit;
  final void Function(domain.Task) onTaskDelete;
  final void Function(domain.Task)? onOpenNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = _isToday(selectedDate);

    // Separate completed and incomplete tasks
    final incompleteTasks = tasks
        .where((t) => t.status != domain.TaskStatus.completed)
        .toList();
    final completedTasks = tasks
        .where((t) => t.status == domain.TaskStatus.completed)
        .toList();

    // Sort tasks by priority and due time
    incompleteTasks.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }

      // Get createdAt from metadata
      final aCreatedAt = a.metadata['createdAt'] != null
          ? DateTime.parse(a.metadata['createdAt'] as String)
          : DateTime.now();
      final bCreatedAt = b.metadata['createdAt'] != null
          ? DateTime.parse(b.metadata['createdAt'] as String)
          : DateTime.now();

      return aCreatedAt.compareTo(bCreatedAt);
    });

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateHeader(selectedDate),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Text(
                          _getTaskSummary(incompleteTasks, completedTasks),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                // Add task button
                IconButton.filledTonal(
                  onPressed: () => _showAddTaskDialog(context, ref),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add task for this date',
                ),
              ],
            ),
          ),

          // Task list
          Flexible(
            child: tasks.isEmpty
                ? _buildEmptyState(context, isToday)
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Incomplete tasks
                      if (incompleteTasks.isNotEmpty) ...[
                        ...incompleteTasks.map(
                          (task) => CalendarTaskItem(
                            task: task,
                            onToggle: () => onTaskToggle(task),
                            onEdit: () => onTaskEdit(task),
                            onDelete: () => onTaskDelete(task),
                            onOpenNote: onOpenNote != null
                                ? () => onOpenNote!(task)
                                : null,
                          ),
                        ),
                        if (completedTasks.isNotEmpty)
                          const SizedBox(height: 16),
                      ],

                      // Completed tasks (collapsible)
                      if (completedTasks.isNotEmpty)
                        CompletedTasksSection(
                          tasks: completedTasks,
                          onTaskToggle: onTaskToggle,
                          onTaskEdit: onTaskEdit,
                          onTaskDelete: onTaskDelete,
                          onOpenNote: onOpenNote,
                        ),
                    ],
                  ),
          ),

          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isToday) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isToday ? Icons.today : Icons.calendar_today,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isToday ? 'No tasks for today' : 'No tasks for this date',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isToday
                ? 'Enjoy your free time or add a new task!'
                : 'Tap the + button to add a task for this date.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: 'New Task',
        onSave: (metadata) =>
            Navigator.of(context).pop(metadata.copyWith(dueDate: selectedDate)),
      ),
    );

    if (result != null) {
      // Create task with selected date as due date
      await _createTaskForDate(context, ref, result);
    }
  }

  Future<void> _createTaskForDate(
    BuildContext context,
    WidgetRef ref,
    TaskMetadata metadata,
  ) async {
    final logger = ref.read(loggerProvider);
    try {
      final taskRepo = ref.read(taskCoreRepositoryProvider);
      if (taskRepo == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task creation requires authentication'),
            ),
          );
        }
        return;
      }

      final controller = ref.read(domainTaskControllerProvider);
      final taskTitle = metadata.taskContent.trim().isEmpty
          ? 'New Task'
          : metadata.taskContent.trim();

      await controller.createTask(
        title: taskTitle,
        description: metadata.notes,
        priority: metadata.priority,
        dueDate: metadata.dueDate ?? selectedDate,
        tags: metadata.labels,
        estimatedMinutes: metadata.estimatedMinutes,
        createReminder: metadata.hasReminder,
        reminderTime: metadata.reminderTime,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
      }
    } catch (error, stackTrace) {
      logger.error(
        'Failed to create calendar task for date',
        error: error,
        stackTrace: stackTrace,
        data: {'selectedDate': selectedDate.toIso8601String()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to create task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () =>
                  unawaited(_createTaskForDate(context, ref, metadata)),
            ),
          ),
        );
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today, ${DateFormat.MMMd().format(date)}';
    } else if (date.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow, ${DateFormat.MMMd().format(date)}';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday, ${DateFormat.MMMd().format(date)}';
    } else {
      return DateFormat.yMMMEd().format(date);
    }
  }

  String _getTaskSummary(
    List<domain.Task> incomplete,
    List<domain.Task> completed,
  ) {
    final total = incomplete.length + completed.length;
    if (completed.isEmpty) {
      return '$total ${total == 1 ? 'task' : 'tasks'}';
    } else if (incomplete.isEmpty) {
      return 'All $total ${total == 1 ? 'task' : 'tasks'} completed';
    } else {
      return '${completed.length} of $total ${total == 1 ? 'task' : 'tasks'} completed';
    }
  }
}

/// Individual task item in calendar sheet
class CalendarTaskItem extends StatelessWidget {
  const CalendarTaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenNote,
  });

  final domain.Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = task.status == domain.TaskStatus.completed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggle();
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isCompleted
                            ? _getPriorityColor(task.priority)
                            : colorScheme.outline,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: isCompleted
                          ? _getPriorityColor(task.priority)
                          : Colors.transparent,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),

                const SizedBox(width: 12),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task title
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Due time (if set for today)
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Due at ${DateFormat.jm().format(task.dueDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Task indicators
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TaskIndicatorsWidget(
                              task: task,
                              compact: true,
                            ),
                          ),

                          // Source note indicator
                          if (!DomainTaskController.isStandaloneNoteId(
                                task.noteId,
                              ) &&
                              onOpenNote != null)
                            GestureDetector(
                              onTap: onOpenNote,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.note,
                                      size: 12,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Note',
                                      style: TextStyle(
                                        color: colorScheme.onSecondaryContainer,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // More menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) => _handleAction(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    if (onOpenNote != null &&
                        !DomainTaskController.isStandaloneNoteId(task.noteId))
                      PopupMenuItem(
                        value: 'open_note',
                        child: Row(
                          children: [
                            Icon(
                              Icons.note,
                              size: 16,
                              color: colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Open Note'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Delete'),
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

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onEdit();
        break;
      case 'open_note':
        onOpenNote?.call();
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }

  Color _getPriorityColor(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return Colors.green;
      case domain.TaskPriority.medium:
        return Colors.orange;
      case domain.TaskPriority.high:
        return Colors.red;
      case domain.TaskPriority.urgent:
        return Colors.purple;
    }
  }
}

/// Collapsible section for completed tasks
class CompletedTasksSection extends StatefulWidget {
  const CompletedTasksSection({
    super.key,
    required this.tasks,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
    this.onOpenNote,
  });

  final List<domain.Task> tasks;
  final void Function(domain.Task) onTaskToggle;
  final void Function(domain.Task) onTaskEdit;
  final void Function(domain.Task) onTaskDelete;
  final void Function(domain.Task)? onOpenNote;

  @override
  State<CompletedTasksSection> createState() => _CompletedTasksSectionState();
}

class _CompletedTasksSectionState extends State<CompletedTasksSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Completed (${widget.tasks.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expandable task list
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Column(
            children: widget.tasks
                .map(
                  (task) => CalendarTaskItem(
                    task: task,
                    onToggle: () => widget.onTaskToggle(task),
                    onEdit: () => widget.onTaskEdit(task),
                    onDelete: () => widget.onTaskDelete(task),
                    onOpenNote: widget.onOpenNote != null
                        ? () => widget.onOpenNote!(task)
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Extension for TaskMetadata to add copyWith method
extension TaskMetadataCopyWith on TaskMetadata {
  TaskMetadata copyWith({
    String? taskContent,
    DateTime? dueDate,
    domain.TaskPriority? priority,
    bool? hasReminder,
    DateTime? reminderTime,
    int? estimatedMinutes,
    String? notes,
    List<String>? labels,
  }) {
    return TaskMetadata(
      taskContent: taskContent ?? this.taskContent,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      notes: notes ?? this.notes,
      labels: labels ?? this.labels,
    );
  }
}
