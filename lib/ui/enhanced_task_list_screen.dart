import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/task_item_widget.dart';
import 'package:duru_notes/ui/widgets/calendar_day_widget.dart';
import 'package:duru_notes/ui/widgets/calendar_task_sheet.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Task view modes
enum TaskViewMode { grouped, list }

/// Enhanced task list screen with smart grouping and advanced features
class EnhancedTaskListScreen extends ConsumerStatefulWidget {
  const EnhancedTaskListScreen({super.key});

  @override
  ConsumerState<EnhancedTaskListScreen> createState() => _EnhancedTaskListScreenState();
}

class _EnhancedTaskListScreenState extends ConsumerState<EnhancedTaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskViewMode _viewMode = TaskViewMode.grouped;
  bool _showCompleted = false;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
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
            icon: const Icon(Icons.view_list),
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: TaskViewMode.grouped,
                child: Row(
                  children: [
                    Icon(Icons.group_work, size: 18),
                    SizedBox(width: 8),
                    Text('Smart Groups'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: TaskViewMode.list,
                child: Row(
                  children: [
                    Icon(Icons.list, size: 18),
                    SizedBox(width: 8),
                    Text('Simple List'),
                  ],
                ),
              ),
            ],
          ),
          // Toggle completed
          IconButton(
            icon: Icon(
              _showCompleted ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: _showCompleted ? 'Hide Completed' : 'Show Completed',
            onPressed: () => setState(() => _showCompleted = !_showCompleted),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          EnhancedTaskListView(
            viewMode: _viewMode,
            showCompleted: _showCompleted,
          ),
          const _TaskCalendarView(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStandaloneTaskDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  Future<void> _showCreateStandaloneTaskDialog(BuildContext context) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: '', // Start with empty, not "New Task"
        isNewTask: true, // Flag to show appropriate placeholder
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _createStandaloneTask(result);
    }
  }

  Future<void> _createStandaloneTask(TaskMetadata metadata) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      
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
      
      // Create task with user's content
      final taskId = await taskService.createTask(
        noteId: 'standalone', // Special identifier for standalone tasks
        content: taskContent, // USE ACTUAL USER INPUT
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
        notes: metadata.notes,
        estimatedMinutes: metadata.estimatedMinutes,
        createReminder: metadata.hasReminder && metadata.dueDate != null,
      );
      
      // Handle custom reminder time if specified
      if (metadata.hasReminder && 
          metadata.reminderTime != null && 
          metadata.dueDate != null &&
          metadata.reminderTime != metadata.dueDate) {
        final task = await ref.read(appDbProvider).getTaskById(taskId);
        if (task != null) {
          final duration = metadata.dueDate!.difference(metadata.reminderTime!);
          await ref.read(taskReminderBridgeProvider).createTaskReminder(
            task: task,
            beforeDueDate: duration.abs(),
          );
        }
      }

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
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(enhancedTaskServiceProvider);

    return StreamBuilder<List<NoteTask>>(
      stream: taskService.watchOpenTasks(),
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
                  onPressed: () => ref.refresh(taskServiceProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var tasks = snapshot.data ?? [];

        // Filter completed tasks if needed
        if (!showCompleted) {
          tasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
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

  Widget _buildGroupedView(BuildContext context, WidgetRef ref, List<NoteTask> tasks) {
    final groupedTasks = _groupTasksByDueDate(tasks);
    final groups = groupedTasks.entries.where((entry) => entry.value.isNotEmpty).toList();

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
          children: groupTasks.map((task) => 
            TaskItemWidget(
              task: task,
              onToggle: () => _toggleTask(ref, task),
              onEdit: () => _editTask(context, ref, task),
              onDelete: () => _deleteTask(ref, task),
              onOpenNote: task.noteId != 'standalone' 
                ? () => _openSourceNote(context, ref, task)
                : null,
              onSnooze: () => _snoozeTask(context, ref, task),
              showSourceNote: task.noteId != 'standalone',
            ),
          ).toList(),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref, List<NoteTask> tasks) {
    // Sort tasks by due date and priority
    final sortedTasks = _sortTasks(tasks);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return TaskItemWidget(
          task: task,
          onToggle: () => _toggleTask(ref, task),
          onEdit: () => _editTask(context, ref, task),
          onDelete: () => _deleteTask(ref, task),
          onOpenNote: task.noteId != 'standalone' 
            ? () => _openSourceNote(context, ref, task)
            : null,
          onSnooze: () => _snoozeTask(context, ref, task),
          showSourceNote: task.noteId != 'standalone',
        );
      },
    );
  }

  Map<String, List<NoteTask>> _groupTasksByDueDate(List<NoteTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final thisWeek = today.add(const Duration(days: 7));

    final groups = <String, List<NoteTask>>{
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

  List<NoteTask> _sortTasks(List<NoteTask> tasks) {
    final sortedTasks = List<NoteTask>.from(tasks);
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

  Future<void> _toggleTask(WidgetRef ref, NoteTask task) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.toggleTaskStatus(task.id);
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, NoteTask task) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: task,
        taskContent: task.content,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _updateTask(ref, task, result);
    }
  }

  Future<void> _updateTask(WidgetRef ref, NoteTask task, TaskMetadata metadata) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.updateTask(
        taskId: task.id,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
        notes: metadata.notes,
        estimatedMinutes: metadata.estimatedMinutes,
      );
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(WidgetRef ref, NoteTask task) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.deleteTask(task.id);
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _openSourceNote(BuildContext context, WidgetRef ref, NoteTask task) async {
    if (task.noteId == 'standalone') return;
    
    try {
      final notesRepo = ref.read(notesRepositoryProvider);
      final note = await notesRepo.getNote(task.noteId);
      
      if (note != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening source note: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open source note')),
        );
      }
    }
  }

  Future<void> _snoozeTask(BuildContext context, WidgetRef ref, NoteTask task) async {
    final newDueDate = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDueDate != null) {
      final newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          task.dueDate ?? DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      if (newTime != null) {
        final snoozeDateTime = DateTime(
          newDueDate.year,
          newDueDate.month,
          newDueDate.day,
          newTime.hour,
          newTime.minute,
        );

        try {
          final taskService = ref.read(enhancedTaskServiceProvider);
          await taskService.updateTask(
            taskId: task.id,
            dueDate: snoozeDateTime,
          );
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Task snoozed until ${DateFormat.yMd().add_jm().format(snoozeDateTime)}',
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error snoozing task: $e');
        }
      }
    }
  }

  void _showCreateTaskDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        taskContent: 'New Task',
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      try {
        final taskService = ref.read(enhancedTaskServiceProvider);
        await taskService.createTask(
          noteId: 'standalone',
          content: 'New Task',
          priority: result.priority,
          dueDate: result.dueDate,
          labels: result.labels.isNotEmpty ? {'labels': result.labels} : null,
          notes: result.notes,
          estimatedMinutes: result.estimatedMinutes,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating task: $e')),
          );
        }
      }
    }
  }
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
  Map<DateTime, List<NoteTask>> _tasksByDate = {};
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _loadTasksForMonth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasksForMonth() async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      
      // Get all tasks for the current month
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final tasks = await taskService.getTasksByDateRange(
        start: firstDay,
        end: lastDay.add(const Duration(days: 1)),
      );

      // Group tasks by date
      final tasksByDate = <DateTime, List<NoteTask>>{};
      for (final task in tasks) {
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
    } catch (e) {
      debugPrint('Error loading tasks for month: $e');
    }
  }

  void _navigateMonth(int direction) async {
    // Set up slide animation
    _slideAnimation = Tween<Offset>(
      begin: Offset(-direction.toDouble(), 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

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

  void _showTaskSheet(DateTime date, List<NoteTask> tasks) {
    showModalBottomSheet(
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
          onTaskToggle: (task) => _toggleTask(task),
          onTaskEdit: (task) => _editTask(task),
          onTaskDelete: (task) => _deleteTask(task),
          onOpenNote: (task) => _openSourceNote(task),
        ),
      ),
    );
  }

  Future<void> _toggleTask(NoteTask task) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.toggleTaskStatus(task.id);
      await _loadTasksForMonth(); // Refresh calendar
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _editTask(NoteTask task) async {
    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        task: task,
        taskContent: task.content,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      try {
        final taskService = ref.read(enhancedTaskServiceProvider);
        await taskService.updateTask(
          taskId: task.id,
          content: task.content, // Keep existing content
          priority: result.priority,
          dueDate: result.dueDate,
          labels: result.labels.isNotEmpty ? {'labels': result.labels} : null,
          notes: result.notes,
          estimatedMinutes: result.estimatedMinutes,
        );
        await _loadTasksForMonth(); // Refresh calendar
      } catch (e) {
        debugPrint('Error updating task: $e');
      }
    }
  }

  Future<void> _deleteTask(NoteTask task) async {
    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.deleteTask(task.id);
      await _loadTasksForMonth(); // Refresh calendar
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _openSourceNote(NoteTask task) async {
    if (task.noteId == 'standalone') return;
    
    try {
      final notesRepo = ref.read(notesRepositoryProvider);
      final note = await notesRepo.getNote(task.noteId);
      
      if (note != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening source note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open source note')),
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
            child: CalendarMonthWidget(
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
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
    
    // Calculate stats for current month
    final allTasks = _tasksByDate.values.expand((tasks) => tasks).toList();
    final totalTasks = allTasks.length;
    final completedTasks = allTasks.where((t) => t.status == TaskStatus.completed).length;
    final overdueTasks = allTasks.where((t) => 
      t.dueDate != null && 
      t.dueDate!.isBefore(DateTime.now()) && 
      t.status != TaskStatus.completed
    ).length;
    final highPriorityTasks = allTasks.where((t) => 
      t.priority == TaskPriority.high || t.priority == TaskPriority.urgent
    ).length;

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
