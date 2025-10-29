import 'dart:async';

import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' show TaskPriority, TaskStatus;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/enhanced_task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Using TaskViewMode from enhanced_task_list_screen.dart

/// Task list screen for managing all tasks
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskViewMode _viewMode = TaskViewMode.grouped;
  bool _showCompleted = false;

  DomainTaskController? _controllerOrNull({bool showSnackbar = true}) {
    final logger = ref.read(loggerProvider);
    final repository = ref.read(taskCoreRepositoryProvider);
    if (repository == null) {
      logger.warning(
        'Domain task controller unavailable (unauthenticated user)',
        data: {'screen': 'TaskList'},
      );
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to manage tasks.')),
        );
      }
      return null;
    }

    try {
      return ref.read(domainTaskControllerProvider);
    } on StateError catch (error, stackTrace) {
      logger.error(
        'Failed to obtain domain task controller',
        error: error,
        stackTrace: stackTrace,
        data: {'screen': 'TaskList'},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks temporarily unavailable. Please retry.'),
          ),
        );
      }
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks'),
            Text('Manage your productivity', style: TextStyle(fontSize: 12)),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [DuruColors.primary, DuruColors.accent],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(CupertinoIcons.rectangle_3_offgrid, size: 18),
              text: 'Smart Groups',
            ),
            Tab(
              icon: Icon(CupertinoIcons.calendar, size: 18),
              text: 'Calendar',
            ),
          ],
        ),
        actions: [
          // View mode toggle
          PopupMenuButton<TaskViewMode>(
            icon: const Icon(CupertinoIcons.list_bullet, color: Colors.white),
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: TaskViewMode.grouped,
                child: Row(
                  children: [
                    Icon(CupertinoIcons.rectangle_3_offgrid, size: 18, color: DuruColors.primary),
                    SizedBox(width: 8),
                    Text('Smart Groups'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: TaskViewMode.list,
                child: Row(
                  children: [
                    Icon(CupertinoIcons.list_bullet, size: 18, color: DuruColors.primary),
                    SizedBox(width: 8),
                    Text('Simple List'),
                  ],
                ),
              ),
            ],
          ),
          // Toggle completed
          IconButton(
            icon: Icon(_showCompleted ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
            onPressed: () => setState(() => _showCompleted = !_showCompleted),
            tooltip: _showCompleted ? 'Hide Completed' : 'Show Completed',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          _buildStatsHeader(context),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                EnhancedTaskListView(
                  viewMode: _viewMode,
                  showCompleted: _showCompleted,
                ),
                _TaskCalendarView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'task_list_fab', // PRODUCTION FIX: Unique hero tag
        onPressed: () => _showCreateStandaloneTaskDialog(context),
        backgroundColor: DuruColors.primary,
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.all(DuruSpacing.md),
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DuruColors.primary.withValues(alpha: 0.1),
            DuruColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: StreamBuilder<List<domain.Task>>(
        stream: ref.watch(taskCoreRepositoryProvider)?.watchAllTasks() ?? Stream.value([]),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];
          final pendingTasks = tasks.where((t) => t.status != domain.TaskStatus.completed).length;
          final completedToday = tasks.where((t) {
            if (t.completedAt == null) return false;
            final now = DateTime.now();
            return t.completedAt!.year == now.year &&
                t.completedAt!.month == now.month &&
                t.completedAt!.day == now.day;
          }).length;
          final overdueTasks = tasks.where((t) {
            if (t.dueDate == null) return false;
            return t.dueDate!.isBefore(DateTime.now()) &&
                t.status != domain.TaskStatus.completed;
          }).length;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: CupertinoIcons.list_bullet,
                value: pendingTasks.toString(),
                label: 'Pending',
                color: DuruColors.primary,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.checkmark_circle_fill,
                value: completedToday.toString(),
                label: 'Today',
                color: DuruColors.accent,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.exclamationmark_triangle,
                value: overdueTasks.toString(),
                label: 'Overdue',
                color: overdueTasks > 0 ? DuruColors.error : DuruColors.surfaceVariant,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(DuruSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateStandaloneTaskDialog(BuildContext context) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: '',
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _createStandaloneTask(result);
    }
  }

  Future<void> _createStandaloneTask(TaskMetadata metadata) async {
    final logger = ref.read(loggerProvider);

    try {
      final controller = _controllerOrNull();
      if (controller == null) return;

      await controller.createTask(
        title: metadata.taskContent,
        description: metadata.notes,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        tags: metadata.labels,
        createReminder: metadata.hasReminder,
        reminderTime: metadata.reminderTime,
        estimatedMinutes: metadata.estimatedMinutes,
        metadata: metadata.estimatedMinutes != null
            ? {'estimatedMinutes': metadata.estimatedMinutes}
            : null,
      );

      logger.info(
        'Standalone task created via domain controller',
        data: {
          'hasReminder': metadata.hasReminder,
          'priority': metadata.priority.name,
          'titleLength': metadata.taskContent.length,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              metadata.hasReminder
                  ? 'Task created with reminder'
                  : 'Task created successfully',
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      logger.error(
        'Failed to create standalone task',
        error: error,
        stackTrace: stackTrace,
        data: {
          'hasReminder': metadata.hasReminder,
          'priority': metadata.priority.name,
        },
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create task. Please try again.'),
            backgroundColor: DuruColors.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_createStandaloneTask(metadata)),
            ),
          ),
        );
      }
    }
  }

  // Legacy method _showCreateTaskDialog removed - replaced by _showCreateStandaloneTaskDialog
  // which uses TaskMetadataDialog for enhanced task creation with reminders and metadata

  // Helper methods _getPriorityIcon, _getPriorityColor, _getPriorityLabel removed
  // They were only used by _TaskCard which has been removed
  // _TaskCalendarView has its own copies of these methods
}

// Legacy widget _TaskListView removed - replaced by EnhancedTaskListView from enhanced_task_list_screen.dart
// which provides modern unified task list view with Smart Groups and Simple List modes

// Legacy widget _TaskCard removed - was only used by _TaskListView and _TasksByDateView
// Modern task display is handled by EnhancedTaskListView

// Legacy widget _TasksByDateView removed - unused widget that grouped tasks by date categories
// Replaced by EnhancedTaskListView which provides more flexible Smart Groups functionality

/// Task calendar view
class _TaskCalendarView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends ConsumerState<_TaskCalendarView> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  DomainTaskController? _controllerOrNull({bool showSnackbar = true}) {
    final logger = ref.read(loggerProvider);
    final repository = ref.read(taskCoreRepositoryProvider);
    if (repository == null) {
      logger.warning(
        'Domain task controller unavailable for calendar view',
        data: {'selectedMonth': _selectedMonth.toIso8601String()},
      );
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to manage tasks.')),
        );
      }
      return null;
    }

    try {
      return ref.read(domainTaskControllerProvider);
    } on StateError catch (error, stackTrace) {
      logger.error(
        'Failed to obtain domain task controller in calendar view',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks temporarily unavailable. Please retry.'),
          ),
        );
      }
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                DateFormat.yMMMM().format(_selectedMonth),
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        // Calendar grid
        Expanded(
          child: FutureBuilder<Map<DateTime, List<domain.Task>>>(
            future: _getTasksForMonth(),
            builder: (context, snapshot) {
              final tasksByDate = snapshot.data ?? {};

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: 42, // 6 weeks * 7 days
                itemBuilder: (context, index) {
                  final firstDayOfMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month,
                  );
                  final firstDayWeekday = firstDayOfMonth.weekday;
                  final dayOffset = index - (firstDayWeekday - 1);

                  if (dayOffset < 0 ||
                      dayOffset >=
                          DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                            0,
                          ).day) {
                    return const SizedBox();
                  }

                  final date = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month,
                    dayOffset + 1,
                  );

                  final tasks = tasksByDate[date] ?? [];
                  final isSelected = _selectedDate != null &&
                      date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _showTasksForDate(context, date, tasks);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor.withValues(alpha: 0.2)
                            : isToday
                                ? theme.primaryColor.withValues(alpha: 0.1)
                                : null,
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : null,
                                color: isToday ? theme.primaryColor : null,
                              ),
                            ),
                          ),
                          if (tasks.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: tasks.any(
                                        (t) =>
                                            t.priority == TaskPriority.urgent ||
                                            t.priority == TaskPriority.high,
                                      )
                                          ? Colors.red
                                          : theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  if (tasks.length > 1) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '${tasks.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<DateTime, List<domain.Task>>> _getTasksForMonth() async {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final endOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    // Use repository to get all tasks, then filter by date range
    final taskRepo = ref.read(taskCoreRepositoryProvider);

    // Handle nullable repository
    if (taskRepo == null) {
      return {};
    }

    final allTasks = await taskRepo.getAllTasks();
    final tasks = allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
             task.dueDate!.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();

    final tasksByDate = <DateTime, List<domain.Task>>{};
    for (final task in tasks) {
      if (task.dueDate != null) {
        final date = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        tasksByDate.putIfAbsent(date, () => []).add(task);
      }
    }

    return tasksByDate;
  }

  void _showTasksForDate(
    BuildContext context,
    DateTime date,
    List<domain.Task> tasks,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat.yMMMd().format(date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No tasks for this date')),
              )
            else
              ...tasks.map(
                (task) {
                  // Use task.title directly (already decrypted in domain.Task)
                  final content = task.title;
                  return ListTile(
                    leading: Checkbox(
                      value: task.status == TaskStatus.completed,
                      onChanged: (_) async {
                        final logger = ref.read(loggerProvider);
                        final controller = _controllerOrNull();
                        if (controller == null) return;
                        try {
                          await controller.toggleStatus(task.id);
                          if (mounted) setState(() {});
                          Navigator.pop(context);
                        } catch (error, stackTrace) {
                          logger.error(
                            'Failed to toggle task status from calendar',
                            error: error,
                            stackTrace: stackTrace,
                            data: {'taskId': task.id},
                          );
                          unawaited(
                            Sentry.captureException(
                              error,
                              stackTrace: stackTrace,
                            ),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Could not toggle task. Please try again.',
                                ),
                                backgroundColor: DuruColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    title: Text(content),
                    subtitle: Text(_getPriorityLabel(task.priority)),
                    trailing: Icon(
                      _getPriorityIcon(task.priority),
                      color: _getPriorityColor(task.priority),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
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

/// Task filter options
enum TaskFilter { all, today, week, overdue, highPriority }

/// Task sort options
enum TaskSortBy { dueDate, priority, created, alphabetical }
