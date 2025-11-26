import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Dialog for editing task metadata (due date, priority, reminders, etc.)
class TaskMetadataDialog extends ConsumerStatefulWidget {
  const TaskMetadataDialog({
    super.key,
    this.task,
    required this.taskContent,
    required this.onSave,
    this.isNewTask = false,
  });

  final domain.Task? task;
  final String taskContent;
  final Future<void> Function(TaskMetadata) onSave;
  final bool isNewTask;

  @override
  ConsumerState<TaskMetadataDialog> createState() => _TaskMetadataDialogState();
}

class _TaskMetadataDialogState extends ConsumerState<TaskMetadataDialog> {
  late String _taskContent;
  late DateTime? _dueDate;
  late domain.TaskPriority _priority;
  late bool _hasReminder;
  late DateTime? _reminderTime;
  late int? _estimatedMinutes;
  late String _notes;
  late List<String> _labels;

  final _taskContentController = TextEditingController();
  final _notesController = TextEditingController();
  final _estimateController = TextEditingController();
  final _labelController = TextEditingController();
  final _contentFocusNode = FocusNode();

  String? _contentError;
  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();

    // Initialize from existing task or defaults
    _taskContent = widget.taskContent;
    _dueDate = widget.task?.dueDate;
    _priority = widget.task?.priority ?? domain.TaskPriority.medium;
    // Get reminderId and estimatedMinutes from metadata
    final reminderRaw = widget.task?.metadata['reminderId'];
    _hasReminder = reminderRaw != null;
    _reminderTime = _dueDate?.subtract(
      const Duration(hours: 1),
    ); // Default 1 hour before
    final estimatedRaw = widget.task?.metadata['estimatedMinutes'];
    if (estimatedRaw is int) {
      _estimatedMinutes = estimatedRaw;
    } else if (estimatedRaw is num) {
      _estimatedMinutes = estimatedRaw.toInt();
    } else if (estimatedRaw is String) {
      _estimatedMinutes = int.tryParse(estimatedRaw);
    } else {
      _estimatedMinutes = null;
    }

    // Initialize with empty values - will be loaded asynchronously
    _notes = '';
    _labels = [];

    _taskContentController.text = _taskContent;
    _notesController.text = _notes;
    _estimateController.text = _estimatedMinutes?.toString() ?? '';

    // Load encrypted task metadata asynchronously
    if (widget.task != null) {
      _loadEncryptedTaskMetadata();
    }

    // Auto-focus on content field for new tasks
    if (widget.isNewTask && widget.taskContent.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Safety: Check mounted before accessing context
        // Dialog might be dismissed before this callback executes
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_contentFocusNode);
      });
    }
  }

  /// Load and decrypt task notes and labels
  Future<void> _loadEncryptedTaskMetadata() async {
    if (widget.task == null) return;

    try {
      // Domain tasks store metadata in a Map (already decrypted)
      // Notes and labels are in the metadata map
      final decryptedNotes = widget.task!.metadata['notes']?.toString() ?? '';
      final decryptedLabels = widget.task!.metadata['labels']?.toString() ?? '';

      // Parse labels from comma-separated string
      final labelsList = decryptedLabels.isNotEmpty
          ? decryptedLabels
                .split(',')
                .where((l) => l.trim().isNotEmpty)
                .toList()
          : <String>[];

      if (mounted) {
        setState(() {
          _notes = decryptedNotes;
          _labels = labelsList;
        });

        // Update controller after state is set
        _notesController.text = _notes;
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load decrypted task metadata inside dialog',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': widget.task?.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      // Keep default empty values
    }
  }

  @override
  void dispose() {
    _taskContentController.dispose();
    _notesController.dispose();
    _estimateController.dispose();
    _labelController.dispose();
    _contentFocusNode.dispose();
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
        _dueDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
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
      initialTime: TimeOfDay.fromDateTime(
        _reminderTime ?? _dueDate!.subtract(const Duration(hours: 1)),
      ),
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

  Future<void> _save() async {
    // Validate task content
    final content = _taskContentController.text.trim();

    if (content.isEmpty) {
      if (!mounted) return;
      setState(() {
        _contentError = 'Task title is required';
      });
      // Focus back on the content field
      FocusScope.of(context).requestFocus(_contentFocusNode);
      return;
    }

    // Validate reminder time if reminder is enabled
    if (_hasReminder && _dueDate != null) {
      _reminderTime ??= _dueDate!.subtract(const Duration(hours: 1));

      // Validate reminder is before due date
      if (_reminderTime!.isAfter(_dueDate!)) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 12),
                Text('Invalid Reminder Time'),
              ],
            ),
            content: const Text(
              'Reminder time must be before the due date. Please adjust the reminder time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Warn if reminder is in the past
      if (_reminderTime!.isBefore(DateTime.now())) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 12),
                Text('Reminder in the Past'),
              ],
            ),
            content: const Text(
              'The reminder time has already passed. The task will be created, but no reminder notification will be scheduled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        // Don't return - allow saving with past reminder (it won't be scheduled)
      }
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

    try {
      // Call the onSave callback - the callback will handle navigation
      // by calling Navigator.pop(metadata) from the parent context
      await widget.onSave(metadata);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to save task metadata',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save task: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // NOTE: Navigation is handled by the callback (onSave), not here
    // The callback calls Navigator.of(context).pop(metadata) to return the result
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
                    widget.isNewTask ? 'New Task' : 'Edit Task',
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
              focusNode: _contentFocusNode,
              autofocus: widget.isNewTask,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Task Title*',
                hintText: widget.isNewTask
                    ? 'Enter task description...'
                    : 'Task description',
                errorText: _contentError,
                prefixIcon: const Icon(Icons.task),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
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
              onChanged: (value) {
                _taskContent = value;
                setState(() {
                  _contentError = value.trim().isEmpty
                      ? 'Task title is required'
                      : null;
                });
              },
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
                      children: domain.TaskPriority.values.map((priority) {
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
                          selectedColor: _getPriorityColor(
                            priority,
                          ).withValues(alpha: 0.2),
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
                                onChanged: (value) =>
                                    setState(() => _hasReminder = value),
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
                                    icon: const Icon(
                                      Icons.access_time,
                                      size: 18,
                                    ),
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
                                      _reminderTime = _dueDate!.subtract(
                                        duration,
                                      );
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                            key: const ValueKey('task_estimate_field'),
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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
                  onPressed: _taskContent.trim().isEmpty ? null : _save,
                  child: Text(widget.isNewTask ? 'Create' : 'Save'),
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _getPriorityLabel(domain.TaskPriority priority) {
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

  String _formatReminderTime(DateTime reminderTime) {
    if (_dueDate == null) return '';

    final difference = _dueDate!.difference(reminderTime);

    if (difference.isNegative) {
      return 'Reminder cannot be after due date';
    } else if (reminderTime.isBefore(DateTime.now())) {
      return 'Reminder time has already passed';
    } else if (difference.inDays > 0) {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      if (hours > 0) {
        return '$days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''} before';
      }
      return '$days day${days > 1 ? 's' : ''} before';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      if (minutes > 0) {
        return '$hours hour${hours > 1 ? 's' : ''}, $minutes min before';
      }
      return '$hours hour${hours > 1 ? 's' : ''} before';
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes > 1 ? 's' : ''} before';
    } else {
      return 'At due date time';
    }
  }
}

/// Data class for task metadata
class TaskMetadata {
  const TaskMetadata({
    required this.taskContent,
    this.dueDate,
    this.priority = domain.TaskPriority.medium,
    this.hasReminder = false,
    this.reminderTime,
    this.estimatedMinutes,
    this.notes,
    this.labels = const [],
  });

  final String taskContent;
  final DateTime? dueDate;
  final domain.TaskPriority priority;
  final bool hasReminder;
  final DateTime? reminderTime;
  final int? estimatedMinutes;
  final String? notes;
  final List<String> labels;
}
