import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog for editing task metadata (due date, priority, reminders, etc.)
class TaskMetadataDialog extends ConsumerStatefulWidget {
  const TaskMetadataDialog({
    super.key,
    this.task,
    required this.taskContent,
    required this.onSave,
  });

  final NoteTask? task;
  final String taskContent;
  final Function(TaskMetadata) onSave;

  @override
  ConsumerState<TaskMetadataDialog> createState() => _TaskMetadataDialogState();
}

class _TaskMetadataDialogState extends ConsumerState<TaskMetadataDialog> {
  late String _taskContent;
  late DateTime? _dueDate;
  late TaskPriority _priority;
  late bool _hasReminder;
  late DateTime? _reminderTime;
  late int? _estimatedMinutes;
  late String _notes;
  late List<String> _labels;

  final _taskContentController = TextEditingController();
  final _notesController = TextEditingController();
  final _estimateController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialize from existing task or defaults
    _taskContent = widget.taskContent.isEmpty ? 'New Task' : widget.taskContent;
    _dueDate = widget.task?.dueDate;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _hasReminder = widget.task?.reminderId != null;
    _reminderTime = _dueDate?.subtract(const Duration(hours: 1)); // Default 1 hour before
    _estimatedMinutes = widget.task?.estimatedMinutes;
    _notes = widget.task?.notes ?? '';
    _labels = widget.task?.labels?.split(',').where((l) => l.isNotEmpty).toList() ?? [];

    _taskContentController.text = _taskContent;
    _notesController.text = _notes;
    _estimateController.text = _estimatedMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _taskContentController.dispose();
    _notesController.dispose();
    _estimateController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _selectDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null) {
      if (_dueDate != null) {
        // Preserve time if already set
        final time = TimeOfDay.fromDateTime(_dueDate!);
        _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      } else {
        // Set to end of day by default
        _dueDate = DateTime(date.year, date.month, date.day, 23, 59);
      }
      setState(() {});
    }
  }

  void _selectDueTime() async {
    if (_dueDate == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate!),
    );

    if (time != null) {
      _dueDate = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        time.hour,
        time.minute,
      );
      setState(() {});
    }
  }

  void _selectReminderTime() async {
    if (_dueDate == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderTime ?? _dueDate!.subtract(const Duration(hours: 1))),
    );

    if (time != null) {
      _reminderTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        time.hour,
        time.minute,
      );
      setState(() {});
    }
  }

  void _addLabel() {
    final label = _labelController.text.trim();
    if (label.isNotEmpty && !_labels.contains(label)) {
      setState(() {
        _labels.add(label);
        _labelController.clear();
      });
    }
  }

  void _removeLabel(String label) {
    setState(() {
      _labels.remove(label);
    });
  }

  void _save() {
    // Validate task content
    if (_taskContentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task name')),
      );
      return;
    }

    final metadata = TaskMetadata(
      taskContent: _taskContentController.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      hasReminder: _hasReminder,
      reminderTime: _hasReminder ? _reminderTime : null,
      estimatedMinutes: _estimatedMinutes,
      notes: _notesController.text.trim(),
      labels: _labels,
    );

    widget.onSave(metadata);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.task_alt, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Task Details',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Task content input
            TextField(
              controller: _taskContentController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Task Name',
                hintText: 'Enter task name',
                prefixIcon: const Icon(Icons.task),
                filled: true,
                fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) => _taskContent = value,
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Due Date Section
                    _buildSectionHeader('Due Date', Icons.calendar_today),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDueDate,
                            icon: const Icon(Icons.date_range, size: 18),
                            label: Text(
                              _dueDate != null 
                                ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                : 'Select date',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_dueDate != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectDueTime,
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(
                                '${_dueDate!.hour.toString().padLeft(2, '0')}:${_dueDate!.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (_dueDate != null)
                          IconButton(
                            onPressed: () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Clear due date',
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Priority Section
                    _buildSectionHeader('Priority', Icons.flag),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TaskPriority.values.map((priority) {
                        final isSelected = _priority == priority;
                        return ChoiceChip(
                          label: Text(_getPriorityLabel(priority)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _priority = priority);
                            }
                          },
                          avatar: Icon(
                            Icons.flag,
                            size: 16,
                            color: _getPriorityColor(priority),
                          ),
                          selectedColor: _getPriorityColor(priority).withOpacity(0.2),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Reminder Section
                    if (_dueDate != null) ...[
                      _buildSectionHeader('Reminder', Icons.notifications),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: _hasReminder,
                                onChanged: (value) => setState(() => _hasReminder = value),
                              ),
                              const SizedBox(width: 8),
                              const Text('Set reminder'),
                            ],
                          ),
                          if (_hasReminder) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectReminderTime,
                                    icon: const Icon(Icons.access_time, size: 18),
                                    label: Text(
                                      _reminderTime != null 
                                        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Set time',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Quick reminder options
                                PopupMenuButton<Duration>(
                                  icon: const Icon(Icons.schedule),
                                  tooltip: 'Quick reminder times',
                                  onSelected: (duration) {
                                    setState(() {
                                      _reminderTime = _dueDate!.subtract(duration);
                                    });
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: Duration(minutes: 15),
                                      child: Text('15 minutes before'),
                                    ),
                                    const PopupMenuItem(
                                      value: Duration(hours: 1),
                                      child: Text('1 hour before'),
                                    ),
                                    const PopupMenuItem(
                                      value: Duration(hours: 2),
                                      child: Text('2 hours before'),
                                    ),
                                    const PopupMenuItem(
                                      value: Duration(days: 1),
                                      child: Text('1 day before'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _reminderTime != null
                                ? 'Reminder: ${_formatReminderTime(_reminderTime!)}'
                                : 'Select reminder time',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Time Estimate Section
                    _buildSectionHeader('Time Estimate', Icons.timer),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _estimateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Minutes',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              _estimatedMinutes = int.tryParse(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('minutes'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Labels Section
                    _buildSectionHeader('Labels', Icons.label),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _labelController,
                            decoration: const InputDecoration(
                              hintText: 'Add label',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addLabel(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addLabel,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (_labels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _labels.map((label) {
                          return Chip(
                            label: Text(label),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeLabel(label),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Notes Section
                    _buildSectionHeader('Notes', Icons.note),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Additional notes...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.purple;
    }
  }

  String _formatReminderTime(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);
    
    if (difference.isNegative) {
      return 'Already passed';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) before due date';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) before due date';
    } else {
      return '${difference.inMinutes} minute(s) before due date';
    }
  }
}

/// Data class for task metadata
class TaskMetadata {
  const TaskMetadata({
    required this.taskContent,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.hasReminder = false,
    this.reminderTime,
    this.estimatedMinutes,
    this.notes,
    this.labels = const [],
  });

  final String taskContent;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool hasReminder;
  final DateTime? reminderTime;
  final int? estimatedMinutes;
  final String? notes;
  final List<String> labels;
}
