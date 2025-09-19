import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/enhanced_task_list_screen.dart';
import 'package:duru_notes/ui/widgets/task_group_header.dart';
import 'package:duru_notes/ui/widgets/task_item_widget.dart';
import 'package:duru_notes/ui/widgets/task_time_tracker_widget.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
          _TaskCalendarView(),
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
        taskContent: '',
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _createStandaloneTask(result);
    }
  }

  Future<void> _createStandaloneTask(TaskMetadata metadata) async {
    try {
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      
      // Create a standalone task (not tied to any note)
      final taskId = await enhancedTaskService.createTask(
        noteId: '', // Empty string for standalone tasks
        content: metadata.taskContent, // Use the task content from metadata
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
        notes: metadata.notes,
        estimatedMinutes: metadata.estimatedMinutes,
        createReminder: metadata.hasReminder && metadata.reminderTime != null,
      );
      
      // Set up custom reminder time if different from due date
      if (metadata.hasReminder && metadata.reminderTime != null && 
          metadata.reminderTime != metadata.dueDate && taskId.isNotEmpty) {
        try {
          // Get the created task to update its reminder
          final db = ref.read(appDbProvider);
          final task = await db.getTaskById(taskId);
          if (task != null) {
            final reminderBridge = ref.read(taskReminderBridgeProvider);
            await reminderBridge.updateTaskReminder(task);
          }
        } catch (e) {
          debugPrint('Failed to update reminder time: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(metadata.hasReminder 
              ? 'Task created with reminder' 
              : 'Task created successfully'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Check if widget is still mounted before calling setState
                if (mounted) {
                  // Refresh the task list
                  setState(() {});
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
      }
    }
  }

  Future<void> _showCreateTaskDialog() async {
    final contentController = TextEditingController();
    DateTime? selectedDate;
    TaskPriority selectedPriority = TaskPriority.medium;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Task description',
                    hintText: 'What needs to be done?',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(
                    selectedDate != null
                        ? DateFormat.yMMMd().format(selectedDate!)
                        : 'No due date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      setState(() {
                        selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 0,
                          time?.minute ?? 0,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            _getPriorityIcon(priority),
                            color: _getPriorityColor(priority),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_getPriorityLabel(priority)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (priority) {
                    if (priority != null) {
                      setState(() => selectedPriority = priority);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.isNotEmpty) {
                  // Create task without note ID (standalone task)
                  final taskService = ref.read(taskServiceProvider);
                  await taskService.createTask(
                    noteId: '', // Empty for standalone tasks
                    content: contentController.text,
                    priority: selectedPriority,
                    dueDate: selectedDate,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.arrow_downward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
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

/// Task list view widget
class _TaskListView extends ConsumerWidget {
  const _TaskListView({
    required this.filter,
    required this.sortBy,
    required this.showCompleted,
  });

  final TaskFilter filter;
  final TaskSortBy sortBy;
  final bool showCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(taskServiceProvider);

    return StreamBuilder<List<NoteTask>>(
      stream: taskService.watchOpenTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var tasks = snapshot.data ?? [];

        // Apply filter
        tasks = _applyFilter(tasks, filter);

        // Apply sort
        tasks = _applySort(tasks, sortBy);

        // Show/hide completed
        if (!showCompleted) {
          tasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
        }

        if (tasks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No tasks found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Create a new task to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _TaskCard(task: task);
          },
        );
      },
    );
  }

  List<NoteTask> _applyFilter(List<NoteTask> tasks, TaskFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.today:
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.year == now.year &&
              t.dueDate!.month == now.month &&
              t.dueDate!.day == now.day;
        }).toList();
      case TaskFilter.week:
        final weekEnd = now.add(const Duration(days: 7));
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.isBefore(weekEnd);
        }).toList();
      case TaskFilter.overdue:
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.isBefore(now) && t.status != TaskStatus.completed;
        }).toList();
      case TaskFilter.highPriority:
        return tasks.where((t) {
          return t.priority == TaskPriority.high ||
              t.priority == TaskPriority.urgent;
        }).toList();
    }
  }

  List<NoteTask> _applySort(List<NoteTask> tasks, TaskSortBy sortBy) {
    final sorted = List<NoteTask>.from(tasks);
    switch (sortBy) {
      case TaskSortBy.dueDate:
        sorted.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case TaskSortBy.priority:
        sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
      case TaskSortBy.created:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortBy.alphabetical:
        sorted.sort((a, b) => a.content.compareTo(b.content));
        break;
    }
    return sorted;
  }
}

/// Task card widget
class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final NoteTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(taskServiceProvider);
    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        task.status != TaskStatus.completed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isOverdue ? Colors.red.shade50 : null,
      child: ListTile(
        leading: Checkbox(
          value: task.status == TaskStatus.completed,
          onChanged: (_) => taskService.toggleTaskStatus(task.id),
        ),
        title: Text(
          task.content,
          style: TextStyle(
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
            color: task.status == TaskStatus.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (task.dueDate != null) ...[
              Icon(
                Icons.schedule,
                size: 16,
                color: isOverdue ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat.MMMd().add_jm().format(task.dueDate!),
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Icon(
              _getPriorityIcon(task.priority),
              size: 16,
              color: _getPriorityColor(task.priority),
            ),
            const SizedBox(width: 4),
            Text(
              _getPriorityLabel(task.priority),
              style: TextStyle(
                color: _getPriorityColor(task.priority),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(leading: Icon(Icons.edit), title: Text('Edit')),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
              ),
            ),
            if (task.noteId.isNotEmpty)
              const PopupMenuItem(
                value: 'open_note',
                child: ListTile(
                  leading: Icon(Icons.note),
                  title: Text('Open Note'),
                ),
              ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditTaskDialog(context, ref, task);
                break;
              case 'delete':
                taskService.deleteTask(task.id);
                break;
              case 'open_note':
                // Navigate to note
                Navigator.pushNamed(context, '/note', arguments: task.noteId);
                break;
            }
          },
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(
    BuildContext context,
    WidgetRef ref,
    NoteTask task,
  ) async {
    final contentController = TextEditingController(text: task.content);
    var selectedDate = task.dueDate;
    var selectedPriority = task.priority;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Task description',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(
                    selectedDate != null
                        ? DateFormat.yMMMd().format(selectedDate!)
                        : 'No due date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      setState(() {
                        selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 0,
                          time?.minute ?? 0,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            _getPriorityIcon(priority),
                            color: _getPriorityColor(priority),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_getPriorityLabel(priority)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (priority) {
                    if (priority != null) {
                      setState(() => selectedPriority = priority);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.isNotEmpty) {
                  final taskService = ref.read(taskServiceProvider);
                  await taskService.updateTask(
                    taskId: task.id,
                    content: contentController.text,
                    priority: selectedPriority,
                    dueDate: selectedDate,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.arrow_downward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
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

/// Tasks grouped by date view
class _TasksByDateView extends ConsumerWidget {
  const _TasksByDateView({required this.showCompleted});

  final bool showCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(taskServiceProvider);

    return FutureBuilder<Map<String, List<NoteTask>>>(
      future: _getTasksGroupedByDate(taskService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final groupedTasks = snapshot.data ?? {};

        if (groupedTasks.isEmpty) {
          return const Center(child: Text('No tasks with due dates'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: groupedTasks.length,
          itemBuilder: (context, index) {
            final dateGroup = groupedTasks.keys.elementAt(index);
            final tasks = groupedTasks[dateGroup]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    dateGroup,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...tasks.map((task) => _TaskCard(task: task)),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, List<NoteTask>>> _getTasksGroupedByDate(
    TaskService taskService,
  ) async {
    final tasks = await taskService.getOpenTasks();
    final grouped = <String, List<NoteTask>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final task in tasks) {
      if (!showCompleted && task.status == TaskStatus.completed) {
        continue;
      }

      String group;
      if (task.dueDate == null) {
        group = 'No Due Date';
      } else {
        final taskDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );

        if (taskDate.isBefore(today)) {
          group = 'Overdue';
        } else if (taskDate == today) {
          group = 'Today';
        } else if (taskDate == tomorrow) {
          group = 'Tomorrow';
        } else if (taskDate.difference(today).inDays < 7) {
          group = 'This Week';
        } else if (taskDate.difference(today).inDays < 30) {
          group = 'This Month';
        } else {
          group = 'Later';
        }
      }

      grouped.putIfAbsent(group, () => []).add(task);
    }

    // Sort groups
    final sortedGroups = <String, List<NoteTask>>{};
    const order = [
      'Overdue',
      'Today',
      'Tomorrow',
      'This Week',
      'This Month',
      'Later',
      'No Due Date',
    ];

    for (final key in order) {
      if (grouped.containsKey(key)) {
        sortedGroups[key] = grouped[key]!;
      }
    }

    return sortedGroups;
  }
}

/// Task calendar view
class _TaskCalendarView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends ConsumerState<_TaskCalendarView> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = ref.watch(taskServiceProvider);
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
          child: FutureBuilder<Map<DateTime, List<NoteTask>>>(
            future: _getTasksForMonth(taskService),
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
                  final isSelected =
                      _selectedDate != null &&
                      date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;
                  final isToday =
                      date.year == DateTime.now().year &&
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
                                      color:
                                          tasks.any(
                                            (t) =>
                                                t.priority ==
                                                    TaskPriority.urgent ||
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

  Future<Map<DateTime, List<NoteTask>>> _getTasksForMonth(
    TaskService taskService,
  ) async {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final endOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    final tasks = await taskService.getTasksByDateRange(
      start: startOfMonth,
      end: endOfMonth,
    );

    final tasksByDate = <DateTime, List<NoteTask>>{};
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
    List<NoteTask> tasks,
  ) {
    showModalBottomSheet(
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
                (task) => ListTile(
                  leading: Checkbox(
                    value: task.status == TaskStatus.completed,
                    onChanged: (_) {
                      ref.read(taskServiceProvider).toggleTaskStatus(task.id);
                      Navigator.pop(context);
                    },
                  ),
                  title: Text(task.content),
                  subtitle: Text(_getPriorityLabel(task.priority)),
                  trailing: Icon(
                    _getPriorityIcon(task.priority),
                    color: _getPriorityColor(task.priority),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.arrow_downward;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.arrow_upward;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
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
