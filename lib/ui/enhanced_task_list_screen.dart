import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/task_item_widget.dart';
import 'package:duru_notes/ui/widgets/domain_calendar_day_widget.dart';
import 'package:duru_notes/ui/widgets/calendar_task_sheet.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Task view modes
enum TaskViewMode { grouped, list }

/// Enhanced task list screen with smart grouping and advanced features
class EnhancedTaskListScreen extends ConsumerStatefulWidget {
  const EnhancedTaskListScreen({super.key});

  @override
  ConsumerState<EnhancedTaskListScreen> createState() =>
      _EnhancedTaskListScreenState();
}

class _EnhancedTaskListScreenState extends ConsumerState<EnhancedTaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskViewMode _viewMode = TaskViewMode.grouped;
  bool _showCompleted = false;
  bool _isCreatingTask = false; // Prevent duplicate task creation

  AppLogger get _logger => ref.read(loggerProvider);

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

  Widget _buildStatsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final taskRepo = ref.watch(taskCoreRepositoryProvider);

    // Handle nullable repository
    if (taskRepo == null) {
      return Container(
        height: 120,
        margin: EdgeInsets.all(DuruSpacing.md),
        child: Center(
          child: Text(
            'Sign in to view task statistics',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return FutureBuilder<List<domain.Task>>(
      future: taskRepo.getAllTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            margin: EdgeInsets.all(DuruSpacing.md),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final tasks = snapshot.data!;
        final overdueTasks = tasks
            .where(
              (t) =>
                  t.status != domain.TaskStatus.completed &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(DateTime.now()),
            )
            .length;
        final todayTasks = tasks.where((t) {
          if (t.dueDate == null) return false;
          final today = DateTime.now();
          return t.dueDate!.year == today.year &&
              t.dueDate!.month == today.month &&
              t.dueDate!.day == today.day;
        }).length;
        final completedTasks = tasks
            .where((t) => t.status == domain.TaskStatus.completed)
            .length;
        final pendingTasks = tasks
            .where((t) => t.status != domain.TaskStatus.completed)
            .length;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: CupertinoIcons.clock_fill,
                value: pendingTasks.toString(),
                label: 'Pending',
                color: DuruColors.primary,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.calendar_today,
                value: todayTasks.toString(),
                label: 'Today',
                color: DuruColors.accent,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                value: overdueTasks.toString(),
                label: 'Overdue',
                color: overdueTasks > 0
                    ? DuruColors.error
                    : DuruColors.surfaceVariant,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.checkmark_circle_fill,
                value: completedTasks.toString(),
                label: 'Done',
                color: DuruColors.accent,
              ),
            ],
          ),
        );
      },
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
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
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
            Text('Enhanced Tasks'),
            Text(
              'Smart organization & calendar view',
              style: TextStyle(fontSize: 12),
            ),
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
            Tab(text: 'Smart Groups'),
            Tab(text: 'Calendar'),
          ],
        ),
        actions: [
          // View mode toggle
          PopupMenuButton<TaskViewMode>(
            icon: const Icon(
              CupertinoIcons.square_grid_2x2,
              color: Colors.white,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TaskViewMode.grouped,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.square_stack_3d_up,
                      size: 18,
                      color: DuruColors.primary,
                    ),
                    SizedBox(width: DuruSpacing.sm),
                    const Text('Smart Groups'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TaskViewMode.list,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.list_bullet,
                      size: 18,
                      color: DuruColors.primary,
                    ),
                    SizedBox(width: DuruSpacing.sm),
                    const Text('Simple List'),
                  ],
                ),
              ),
            ],
          ),
          // Toggle completed
          IconButton(
            icon: Icon(
              _showCompleted ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
            ),
            tooltip: _showCompleted ? 'Hide Completed' : 'Show Completed',
            onPressed: () => setState(() => _showCompleted = !_showCompleted),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(context),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                EnhancedTaskListView(
                  viewMode: _viewMode,
                  showCompleted: _showCompleted,
                ),
                const _TaskCalendarView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'enhanced_task_list_fab', // PRODUCTION FIX: Unique hero tag
        onPressed: _isCreatingTask
            ? null // Disable while creating to prevent duplicates
            : () => _showCreateStandaloneTaskDialog(context),
        backgroundColor:
            _isCreatingTask ? Colors.grey : DuruColors.primary,
        icon: _isCreatingTask
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(CupertinoIcons.plus_circle_fill, color: Colors.white),
        label: Text(
          _isCreatingTask ? 'Creating...' : 'New Task',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showCreateStandaloneTaskDialog(BuildContext context) async {
    // Prevent opening dialog if already creating
    if (_isCreatingTask) return;

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: '', // Start with empty, not "New Task"
        isNewTask: true, // Flag to show appropriate placeholder
        onSave: (metadata) async {
          Navigator.of(context).pop(metadata);
        },
      ),
    );

    if (result != null && mounted) {
      await _createStandaloneTask(result);
    }
  }

  Future<void> _createStandaloneTask(TaskMetadata metadata) async {
    // Prevent duplicate creation
    if (_isCreatingTask) return;

    // Set loading state
    if (!mounted) return;
    setState(() {
      _isCreatingTask = true;
    });

    try {
      // USE USER'S INPUT instead of hardcoded "New Task"
      final taskContent = metadata.taskContent.trim();

      // Validate content
      if (taskContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task title cannot be empty'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create task using domain controller
      final taskRepo = ref.read(taskCoreRepositoryProvider);
      if (taskRepo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task creation requires authentication'),
            ),
          );
        }
        return;
      }

      final controller = ref.read(domainTaskControllerProvider);
      final createdTask = await controller.createTask(
        noteId: null,
        title: taskContent,
        description: metadata.notes,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        tags: metadata.labels,
        estimatedMinutes: metadata.estimatedMinutes,
        createReminder: metadata.hasReminder,
        reminderTime: metadata.reminderTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created task: $taskContent'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Refresh the task list
                setState(() {});
              },
            ),
          ),
        );
      }
      _logger.info(
        'Created standalone task',
        data: {
          'taskId': createdTask.id,
          'noteId': createdTask.noteId,
          'taskContent': taskContent,
          'hasDueDate': metadata.dueDate != null,
        },
      );
    } on Exception catch (e, stackTrace) {
      _logger.error(
        'Failed to create standalone task',
        error: e,
        stackTrace: stackTrace,
        data: {'taskContent': metadata.taskContent},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_createStandaloneTask(metadata)),
            ),
          ),
        );
      }
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }
}

/// Enhanced task list view with smart grouping
class EnhancedTaskListView extends ConsumerWidget {
  const EnhancedTaskListView({
    super.key,
    required this.viewMode,
    required this.showCompleted,
  });

  final TaskViewMode viewMode;
  final bool showCompleted;

  // Removed _toDomainTask helper - now using domain.Task directly from repository

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: unified task service removed; domain repository powers the stream directly
    final taskRepo = ref.watch(taskCoreRepositoryProvider);

    return StreamBuilder<List<domain.Task>>(
      stream: taskRepo?.watchAllTasks() ?? Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(taskCoreRepositoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var tasks = snapshot.data ?? [];

        // Filter completed tasks if needed
        if (!showCompleted) {
          tasks = tasks
              .where((t) => t.status != domain.TaskStatus.completed)
              .toList();
        }

        if (tasks.isEmpty) {
          return EmptyTaskGroup(
            title: 'No tasks found',
            message: showCompleted
                ? 'All tasks completed! 🎉'
                : 'Create a new task or show completed tasks',
            action: null, // Remove duplicate button, using FAB instead
          );
        }

        return viewMode == TaskViewMode.grouped
            ? _buildGroupedView(context, ref, tasks)
            : _buildListView(context, ref, tasks);
      },
    );
  }

  Widget _buildGroupedView(
    BuildContext context,
    WidgetRef ref,
    List<domain.Task> tasks,
  ) {
    final groupedTasks = _groupTasksByDueDate(tasks);
    final groups = groupedTasks.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    if (groups.isEmpty) {
      return const EmptyTaskGroup(
        title: 'No tasks in selected view',
        message: 'Try changing your filters or create a new task.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final groupTitle = group.key;
        final groupTasks = group.value;

        return ExpandableTaskGroup(
          header: TaskGroupHeader(
            title: groupTitle,
            taskCount: groupTasks.length,
          ),
          children: groupTasks
              .map<Widget>(
                (task) => TaskItemWidget(
                  task: task,
                  showSourceNote: !DomainTaskController.isStandaloneNoteId(
                    task.noteId,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    List<domain.Task> tasks,
  ) {
    // Sort tasks by due date and priority
    final sortedTasks = _sortTasks(tasks);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return TaskItemWidget(
          task: task,
          showSourceNote: !DomainTaskController.isStandaloneNoteId(task.noteId),
        );
      },
    );
  }

  Map<String, List<domain.Task>> _groupTasksByDueDate(List<domain.Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final thisWeek = today.add(const Duration(days: 7));

    final groups = <String, List<domain.Task>>{
      'Overdue': [],
      'Today': [],
      'Tomorrow': [],
      'This Week': [],
      'Later': [],
      'No Due Date': [],
    };

    for (final task in tasks) {
      if (task.dueDate == null) {
        groups['No Due Date']!.add(task);
      } else if (task.dueDate!.isBefore(today)) {
        groups['Overdue']!.add(task);
      } else if (_isSameDay(task.dueDate!, today)) {
        groups['Today']!.add(task);
      } else if (_isSameDay(task.dueDate!, tomorrow)) {
        groups['Tomorrow']!.add(task);
      } else if (task.dueDate!.isBefore(thisWeek)) {
        groups['This Week']!.add(task);
      } else {
        groups['Later']!.add(task);
      }
    }

    // Sort tasks within each group
    for (final group in groups.values) {
      group.sort((a, b) {
        // First by priority (urgent first)
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;

        // Then by due date
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        }

        // Finally by creation date
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    return groups;
  }

  List<domain.Task> _sortTasks(List<domain.Task> tasks) {
    final sortedTasks = List<domain.Task>.from(tasks);
    sortedTasks.sort((a, b) {
      // First by completion status (incomplete first)
      final statusCompare = a.status.index.compareTo(b.status.index);
      if (statusCompare != 0) return statusCompare;

      // Then by due date (overdue and sooner first)
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      }

      // Then by priority (urgent first)
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      // Finally by creation date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return sortedTasks;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Legacy callback methods removed - replaced by:
  // - TaskItemWidget using UnifiedTaskCallbacks directly
  // - _TaskCalendarViewState methods for calendar view callbacks
  // (_toggleTask, _editTask, _updateTask, _deleteTask, _openSourceNote, _snoozeTask, _showCreateTaskDialog)
}

/// Advanced calendar view with task visualization
class _TaskCalendarView extends ConsumerStatefulWidget {
  const _TaskCalendarView();

  @override
  ConsumerState<_TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends ConsumerState<_TaskCalendarView>
    with SingleTickerProviderStateMixin {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  Map<DateTime, List<domain.Task>> _tasksByDate = {};
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _loadTasksForMonth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasksForMonth() async {
    try {
      final taskRepo = ref.read(taskCoreRepositoryProvider);
      if (taskRepo == null) {
        _logger.debug('Task repository not available (user not authenticated)');
        return;
      }

      // Get all tasks from repository (domain entities)
      final allTasks = await taskRepo.getAllTasks();

      // Filter tasks for the current month
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

      final tasksInMonth = allTasks.where((task) {
        if (task.dueDate == null) return false;
        return !task.dueDate!.isBefore(firstDay) &&
            !task.dueDate!.isAfter(lastDay.add(const Duration(days: 1)));
      }).toList();

      // Group tasks by date (using domain.Task)
      final tasksByDate = <DateTime, List<domain.Task>>{};
      for (final task in tasksInMonth) {
        if (task.dueDate != null) {
          final dateKey = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          tasksByDate.putIfAbsent(dateKey, () => []).add(task);
        }
      }

      if (mounted) {
        setState(() {
          _tasksByDate = tasksByDate;
        });
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load tasks for calendar month',
        error: e,
        stackTrace: stackTrace,
        data: {'month': _currentMonth.month, 'year': _currentMonth.year},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  void _navigateMonth(int direction) async {
    // Set up slide animation
    _slideAnimation =
        Tween<Offset>(
          begin: Offset(-direction.toDouble(), 0),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    await _animationController.forward();

    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + direction,
        1,
      );
    });

    _loadTasksForMonth();
    _animationController.reset();
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = today;
    });

    _loadTasksForMonth();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });

    final tasksForDate = _tasksByDate[date] ?? [];
    if (tasksForDate.isNotEmpty || date.isAtSameMomentAs(_selectedDate!)) {
      _showTaskSheet(date, tasksForDate);
    }
  }

  void _showTaskSheet(DateTime date, List<domain.Task> tasks) {
    // Tasks are already domain.Task entities from repository
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CalendarTaskSheet(
          selectedDate: date,
          tasks: tasks,
          onTaskToggle: (task) {
            _toggleTask(task);
          },
          onTaskEdit: (task) {
            _editTask(task);
          },
          onTaskDelete: (task) {
            _deleteTask(task);
          },
          onOpenNote: (task) {
            _openSourceNote(task);
          },
        ),
      ),
    );
  }

  Future<void> _toggleTask(domain.Task task) async {
    try {
      final taskRepo = ref.read(taskCoreRepositoryProvider);
      if (taskRepo == null) {
        _logger.debug('Cannot toggle task; repository unavailable');
        return;
      }

      final controller = ref.read(domainTaskControllerProvider);
      await controller.toggleStatus(task.id);
      await _loadTasksForMonth(); // Refresh calendar
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to toggle task status in calendar',
        error: e,
        stackTrace: stackTrace,
        data: {'taskId': task.id, 'title': task.title},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to toggle task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_toggleTask(task)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editTask(domain.Task task) async {
    // Task is already domain.Task with decrypted content
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: task,
        taskContent: task.title, // Use decrypted title from domain.Task
        onSave: (metadata) async {
          Navigator.of(context).pop(metadata);
        },
      ),
    );

    if (result != null) {
      try {
        final taskRepo = ref.read(taskCoreRepositoryProvider);
        if (taskRepo == null) {
          _logger.debug('Cannot edit task; repository unavailable');
          return;
        }

        final controller = ref.read(domainTaskControllerProvider);
        await controller.updateTask(
          task,
          title: result.taskContent,
          description: result.notes,
          priority: result.priority,
          dueDate: result.dueDate,
          tags: result.labels,
          estimatedMinutes: result.estimatedMinutes,
          hasReminder: result.hasReminder,
          reminderTime: result.reminderTime,
        );
        await _loadTasksForMonth(); // Refresh calendar
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to update task in calendar',
          error: e,
          stackTrace: stackTrace,
          data: {'taskId': task.id, 'title': task.title},
        );
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to update task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_editTask(task)),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTask(domain.Task task) async {
    try {
      final taskRepo = ref.read(taskCoreRepositoryProvider);
      if (taskRepo == null) {
        _logger.debug('Cannot delete task; repository unavailable');
        return;
      }

      final controller = ref.read(domainTaskControllerProvider);
      await controller.deleteTask(task.id);
      await _loadTasksForMonth(); // Refresh calendar
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete task in calendar',
        error: e,
        stackTrace: stackTrace,
        data: {'taskId': task.id, 'title': task.title},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_deleteTask(task)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSourceNote(domain.Task task) async {
    if (DomainTaskController.isStandaloneNoteId(task.noteId)) return;

    try {
      final notesRepo = ref.read(notesCoreRepositoryProvider);
      final note = await notesRepo.getNoteById(task.noteId);

      if (note != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to open source note from calendar',
        error: e,
        stackTrace: stackTrace,
        data: {'taskId': task.id, 'noteId': task.noteId},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to open note. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_openSourceNote(task)),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar header with month navigation
        CalendarHeader(
          currentMonth: _currentMonth,
          onPreviousMonth: () => _navigateMonth(-1),
          onNextMonth: () => _navigateMonth(1),
          onTodayTapped: _goToToday,
        ),

        // Calendar content with animation
        Expanded(
          child: SlideTransition(
            position: _slideAnimation,
            child: DomainCalendarMonthWidget(
              month: _currentMonth,
              tasksByDate: _tasksByDate,
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
            ),
          ),
        ),

        // Quick stats bar
        if (_tasksByDate.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: _buildQuickStats(),
          ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate stats for current month (using domain.Task)
    final List<domain.Task> allTasks = _tasksByDate.values
        .expand((tasks) => tasks)
        .toList();
    final totalTasks = allTasks.length;
    final completedTasks = allTasks
        .where((t) => t.status == domain.TaskStatus.completed)
        .length;
    final overdueTasks = allTasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.isBefore(DateTime.now()) &&
              t.status != domain.TaskStatus.completed,
        )
        .length;
    final highPriorityTasks = allTasks
        .where(
          (t) =>
              t.priority == domain.TaskPriority.high ||
              t.priority == domain.TaskPriority.urgent,
        )
        .length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.task_alt,
          label: 'Total',
          value: totalTasks.toString(),
          color: colorScheme.primary,
        ),
        _buildStatItem(
          icon: Icons.check_circle,
          label: 'Done',
          value: completedTasks.toString(),
          color: Colors.green,
        ),
        if (overdueTasks > 0)
          _buildStatItem(
            icon: Icons.warning,
            label: 'Overdue',
            value: overdueTasks.toString(),
            color: Colors.red,
          ),
        if (highPriorityTasks > 0)
          _buildStatItem(
            icon: Icons.priority_high,
            label: 'High Priority',
            value: highPriorityTasks.toString(),
            color: Colors.orange,
          ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
