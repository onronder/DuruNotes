import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:duru_notes/ui/widgets/tasks/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Production-ready task management screen
/// Demonstrates the migrated task system using database models
class TaskManagementScreen extends ConsumerStatefulWidget {
  final String noteId;
  
  const TaskManagementScreen({
    super.key,
    required this.noteId,
  });
  
  @override
  ConsumerState<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends ConsumerState<TaskManagementScreen> {
  final _contentController = TextEditingController();
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime? _selectedDueDate;
  bool _showCompleted = true;
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForNoteProvider(widget.noteId));
    final taskService = ref.read(unifiedTaskServiceProvider);
    final theme = Theme.of(context);
    
    // Listen to real-time task updates
    ref.listen<AsyncValue<TaskUpdate>>(
      taskUpdatesProvider,
      (previous, next) {
        next.whenData((update) {
          // Refresh the task list when updates occur
          ref.invalidate(tasksForNoteProvider(widget.noteId));
          
          // Show snackbar for certain events
          if (update.type == TaskUpdateType.deleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task deleted')),
            );
          }
        });
      },
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
            tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
          ),
          // Statistics button
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showStatistics(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Task creation panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Task input field
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: 'Add a new task...',
                    prefixIcon: const Icon(Icons.add_task),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Priority selector
                        PopupMenuButton<TaskPriority>(
                          icon: Icon(
                            Icons.flag,
                            color: _getPriorityColor(_selectedPriority),
                          ),
                          onSelected: (priority) {
                            setState(() {
                              _selectedPriority = priority;
                            });
                          },
                          itemBuilder: (context) => TaskPriority.values.map((priority) {
                            return PopupMenuItem(
                              value: priority,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: _getPriorityColor(priority),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(priority.name),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        // Due date selector
                        IconButton(
                          icon: Icon(
                            Icons.calendar_today,
                            color: _selectedDueDate != null ? theme.colorScheme.primary : null,
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDueDate = date;
                              });
                            }
                          },
                        ),
                        // Add button
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _contentController.text.isNotEmpty
                              ? () => _createTask(taskService)
                              : null,
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _createTask(taskService),
                ),
                if (_selectedDueDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: Text(
                        'Due: ${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedDueDate = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Task list
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                // Filter tasks based on completion status
                final filteredTasks = _showCompleted
                    ? tasks
                    : tasks.where((t) => t.status != TaskStatus.completed).toList();
                
                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showCompleted ? 'No tasks yet' : 'No pending tasks',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Group tasks by status
                final openTasks = filteredTasks.where((t) => t.status == TaskStatus.open).toList();
                final completedTasks = filteredTasks.where((t) => t.status == TaskStatus.completed).toList();
                final cancelledTasks = filteredTasks.where((t) => t.status == TaskStatus.cancelled).toList();
                
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Open tasks
                    if (openTasks.isNotEmpty) ...[
                      _buildSectionHeader('Open Tasks', openTasks.length, Icons.radio_button_unchecked),
                      ...openTasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskCard(
                          dbTask: task,
                          callbacks: taskService,
                        ),
                      )),
                    ],
                    
                    // Completed tasks
                    if (completedTasks.isNotEmpty && _showCompleted) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Completed', completedTasks.length, Icons.check_circle),
                      ...completedTasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Opacity(
                          opacity: 0.7,
                          child: TaskCard(
                            dbTask: task,
                            callbacks: taskService,
                          ),
                        ),
                      )),
                    ],
                    
                    // Cancelled tasks
                    if (cancelledTasks.isNotEmpty && _showCompleted) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Cancelled', cancelledTasks.length, Icons.cancel),
                      ...cancelledTasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Opacity(
                          opacity: 0.5,
                          child: TaskCard(
                            dbTask: task,
                            callbacks: taskService,
                          ),
                        ),
                      )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading tasks: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(tasksForNoteProvider(widget.noteId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating action button for quick add
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddDialog(context, taskService),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.low:
        return Colors.grey;
    }
  }
  
  Future<void> _createTask(UnifiedTaskService service) async {
    if (_contentController.text.trim().isEmpty) return;
    
    try {
      await service.createTask(
        noteId: widget.noteId,
        content: _contentController.text.trim(),
        priority: _selectedPriority,
        dueDate: _selectedDueDate,
      );
      
      // Clear the form
      _contentController.clear();
      setState(() {
        _selectedPriority = TaskPriority.medium;
        _selectedDueDate = null;
      });
      
      // Refresh the task list
      ref.invalidate(tasksForNoteProvider(widget.noteId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    }
  }
  
  void _showQuickAddDialog(BuildContext context, UnifiedTaskService service) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task description...',
            prefixIcon: Icon(Icons.task),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              service.createTask(
                noteId: widget.noteId,
                content: value.trim(),
              );
              ref.invalidate(tasksForNoteProvider(widget.noteId));
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                service.createTask(
                  noteId: widget.noteId,
                  content: controller.text.trim(),
                );
                ref.invalidate(tasksForNoteProvider(widget.noteId));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showStatistics(BuildContext context) {
    final statsAsync = ref.read(taskStatisticsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Statistics'),
        content: statsAsync.when(
          data: (stats) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total Tasks', stats.total.toString()),
              _buildStatRow('Completed', '${stats.completed} (${stats.completionRate.toStringAsFixed(1)}%)'),
              _buildStatRow('Open', stats.open.toString()),
              _buildStatRow('Cancelled', stats.cancelled.toString()),
              _buildStatRow('Overdue', stats.overdue.toString(), 
                color: stats.overdue > 0 ? Colors.red : null),
              const Divider(),
              const Text('By Priority:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...stats.byPriority.entries.map((e) => 
                _buildStatRow(e.key.name, e.value.toString())),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text('Error: $error'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
