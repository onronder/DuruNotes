import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/models/note_block.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show unifiedTaskServiceProvider, taskReminderBridgeProvider;
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:duru_notes/ui/widgets/task_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Enhanced todo block widget with hierarchical task support
/// Uses UnifiedTaskService for all operations - no VoidCallback usage
class HierarchicalTodoBlockWidget extends ConsumerStatefulWidget {
  const HierarchicalTodoBlockWidget({
    required this.block,
    required this.noteId,
    required this.position,
    required this.indentLevel,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onNewLine,
    required this.onIndentChanged,
    super.key,
    this.parentTaskId,
  });

  final NoteBlock block;
  final String? noteId;
  final int position;
  final int indentLevel;
  final bool isFocused;
  final void Function(NoteBlock) onChanged;
  final void Function(bool) onFocusChanged;
  final void Function() onNewLine;
  final void Function(int) onIndentChanged;
  final String? parentTaskId;

  @override
  ConsumerState<HierarchicalTodoBlockWidget> createState() =>
      _HierarchicalTodoBlockWidgetState();
}

class _HierarchicalTodoBlockWidgetState
    extends ConsumerState<HierarchicalTodoBlockWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _isCompleted;
  late String _text;
  // Phase 11: Re-enabled - now uses decrypted domain.Task from repository
  domain.Task? _task;
  TaskProgress? _progress;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    _parseTodoData();
    _controller = TextEditingController(text: _text);
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      widget.onFocusChanged(_focusNode.hasFocus);
    });

    if (widget.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    // Load task data if noteId is available
    if (widget.noteId != null) {
      _loadTaskData();
    }
  }

  @override
  void didUpdateWidget(HierarchicalTodoBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.block.data != oldWidget.block.data) {
      _parseTodoData();
      _controller.text = _text;
    }

    if (widget.isFocused && !oldWidget.isFocused) {
      _focusNode.requestFocus();
    }

    if (widget.indentLevel != oldWidget.indentLevel) {
      _loadTaskData(); // Reload to update parent relationship
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _parseTodoData() {
    // PRODUCTION-GRADE: Parse format "completed:level:text" or "incomplete:level:text"
    final parts = widget.block.data.split(':');
    if (parts.length >= 3) {
      // New format with indent level
      _isCompleted = parts[0] == 'completed';
      // Indent level is at parts[1], but we use widget.indentLevel instead
      _text = parts.skip(2).join(':');
    } else if (parts.length >= 2) {
      // Legacy format "completed:text" or "incomplete:text"
      _isCompleted = parts[0] == 'completed';
      _text = parts.skip(1).join(':');
    } else {
      // Fallback for malformed data
      _isCompleted = false;
      _text = widget.block.data;
    }
  }

  Future<void> _loadTaskData() async {
    // Phase 11: Re-enabled - now uses decrypted domain.Task from repository
    if (widget.noteId == null) return;

    try {
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      final tasks = await unifiedService.getTasksForNote(widget.noteId!);

      // Match task by title (now works because title is decrypted)
      final matchedTask = tasks.cast<domain.Task?>().firstWhere(
        (task) => task?.title.trim() == _text.trim(),
        orElse: () => null,
      );

      if (mounted) {
        setState(() {
          _task = matchedTask;
          // TODO: Load progress for hierarchical tasks
          // This would require calculating subtask completion
        });
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to load task data for todo block',
        data: {
          'noteId': widget.noteId,
          'text': _text.length > 50 ? '${_text.substring(0, 50)}…' : _text,
          'error': e.toString(),
        },
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  // Method _loadTaskProgress removed - unused and disabled due to encryption migration
  // Will be re-implemented once UnifiedTaskService returns decrypted domain.Task

  void _updateTodo() {
    // PRODUCTION-GRADE: Save in format "completed:level:text" with indent level
    final todoData = '${_isCompleted ? 'completed' : 'incomplete'}:${widget.indentLevel}:$_text';
    final newBlock = widget.block.copyWith(data: todoData);
    widget.onChanged(newBlock);
  }

  void _handleTextChanged() {
    _text = _controller.text;
    _updateTodo();
  }

  Future<void> _toggleCompleted() async {
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();

    // Phase 11: Re-enabled - update task status if it exists
    if (_task != null && widget.noteId != null) {
      try {
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.toggleTaskStatus(_task!.id);
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to toggle task status in todo block',
          error: e,
          stackTrace: stackTrace,
          data: {'taskId': _task!.id, 'noteId': widget.noteId},
        );
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to toggle task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _toggleCompleted,
              ),
            ),
          );
        }
      }
    }
  }

  void _showTaskMetadataDialog() async {
    if (widget.noteId == null) return;

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
        // Phase 11: Re-enabled - now passes decrypted domain.Task
        task: _task,
        taskContent: _text,
        onSave: (metadata) => Navigator.of(context).pop(metadata),
      ),
    );

    if (result != null) {
      await _saveTaskMetadata(result);
    }
  }

  Future<void> _saveTaskMetadata(TaskMetadata metadata) async {
    if (widget.noteId == null) return;

    try {
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      final reminderBridge = ref.read(taskReminderBridgeProvider);

      // Phase 11: Re-enabled task create/update logic
      if (_task == null) {
        // Create new task
        final createdTask = await unifiedService.createTask(
          noteId: widget.noteId!,
          content: _text,
          priority: TaskMapper.mapPriorityToDb(metadata.priority),
          dueDate: metadata.dueDate,
          parentTaskId: widget.parentTaskId,
          labels: metadata.labels,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );

        // Add reminder if needed
        if (metadata.hasReminder &&
            metadata.reminderTime != null &&
            metadata.dueDate != null) {
          final duration = metadata.dueDate!.difference(metadata.reminderTime!);
          await reminderBridge.createTaskReminder(
            task: createdTask,
            beforeDueDate: duration.abs(),
          );
        }

        await _loadTaskData();
      } else {
        // UPDATE EXISTING TASK - Phase 11: Re-enabled
        final oldTask = _task!;

        await unifiedService.updateTask(
          taskId: oldTask.id,
          priority: TaskMapper.mapPriorityToDb(metadata.priority),
          dueDate: metadata.dueDate,
          labels: metadata.labels,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );

        // Handle reminder changes - Note: TaskReminderBridge needs NoteTask
        // Get the updated NoteTask from database for reminder operations
        final updatedNoteTask = await unifiedService.getTask(oldTask.id);
        if (updatedNoteTask != null) {
          if (metadata.hasReminder &&
              metadata.reminderTime != null &&
              metadata.dueDate != null) {
            if (updatedNoteTask.reminderId == null) {
              // Create new reminder
              final duration =
                  metadata.dueDate!.difference(metadata.reminderTime!);
              await reminderBridge.createTaskReminder(
                task: updatedNoteTask,
                beforeDueDate: duration.abs(),
              );
            } else {
              // Update existing reminder
              await reminderBridge.updateTaskReminder(updatedNoteTask);
            }
          } else if (!metadata.hasReminder && updatedNoteTask.reminderId != null) {
            // Cancel existing reminder
            await reminderBridge.cancelTaskReminder(updatedNoteTask);
          }
        }

        await _loadTaskData();
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save task metadata in todo block',
        error: e,
        stackTrace: stackTrace,
        data: {
          'noteId': widget.noteId,
          'hasTask': _task != null,
          'priority': metadata.priority.toString(),
        },
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save task. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_saveTaskMetadata(metadata)),
            ),
          ),
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Check if cursor is at the end
        if (_controller.selection.baseOffset == _controller.text.length) {
          widget.onNewLine();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        // Increase indent level
        widget.onIndentChanged(widget.indentLevel + 1);
      } else if (event.logicalKey == LogicalKeyboardKey.tab &&
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.shift)) {
        // Decrease indent level
        if (widget.indentLevel > 0) {
          widget.onIndentChanged(widget.indentLevel - 1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasChildren = _progress != null;
    final unifiedService = ref.watch(unifiedTaskServiceProvider);

    return Container(
      margin: EdgeInsets.only(left: widget.indentLevel * 16.0),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hierarchy connector lines
              if (widget.indentLevel > 0) ...[
                Container(
                  width: 16,
                  height: 24,
                  margin: const EdgeInsets.only(right: 4, top: 12),
                  child: CustomPaint(
                    painter: HierarchyLinePainter(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      isLast: false, // This would need to be calculated
                    ),
                  ),
                ),
              ],

              // Checkbox with long-press support
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: GestureDetector(
                  key: ValueKey(
                    'hierarchical_todo_checkbox_${widget.position}_${widget.indentLevel}',
                  ),
                  onTap: _toggleCompleted,
                  onLongPress:
                      widget.noteId != null ? _showTaskMetadataDialog : null,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isCompleted
                            // Phase 11: Re-enabled - uses actual task priority
                            ? _getPriorityColor(
                                (_task?.priority ?? TaskPriority.medium) as TaskPriority,
                              )
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: _isCompleted
                          // Phase 11: Re-enabled - uses actual task priority
                          ? _getPriorityColor(
                              (_task?.priority ?? TaskPriority.medium) as TaskPriority,
                            )
                          : Colors.transparent,
                    ),
                    child: _isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),

              // Todo Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Focus(
                      onKeyEvent: (node, event) {
                        _handleKeyEvent(event);
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (_) => _handleTextChanged(),
                        decoration: const InputDecoration(
                          hintText: 'Todo item...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: _isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: _isCompleted ? Colors.grey.shade500 : null,
                          fontWeight:
                              hasChildren ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),

                    // Progress bar for parent tasks
                    if (_progress != null && hasChildren) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12),
                        child: TaskProgressBar(
                          progress: _progress!,
                          compact: true,
                        ),
                      ),
                    ],

                    // Phase 11: Re-enabled task indicators
                    if (_task != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: TaskIndicatorsWidget(
                          task: _task!,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Indent controls and more options
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indent controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrease indent
                      if (widget.indentLevel > 0)
                        IconButton(
                          icon: Icon(
                            Icons.format_indent_decrease,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () =>
                              widget.onIndentChanged(widget.indentLevel - 1),
                          tooltip: 'Decrease indent (Shift+Tab)',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),

                      // Increase indent
                      if (widget.indentLevel < 4) // Max 4 levels
                        IconButton(
                          icon: Icon(
                            Icons.format_indent_increase,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () =>
                              widget.onIndentChanged(widget.indentLevel + 1),
                          tooltip: 'Increase indent (Tab)',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                    ],
                  ),

                  // More options button
                  if (widget.noteId != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      onSelected: (action) =>
                          _handleAction(action, unifiedService),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit Task'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_subtask',
                          child: Row(
                            children: [
                              Icon(Icons.subdirectory_arrow_right, size: 16),
                              SizedBox(width: 8),
                              Text('Add Subtask'),
                            ],
                          ),
                        ),
                        if (hasChildren) ...[
                          const PopupMenuItem(
                            value: 'complete_all',
                            child: Row(
                              children: [
                                Icon(Icons.done_all, size: 16),
                                SizedBox(width: 8),
                                Text('Complete All'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete All'),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      padding: const EdgeInsets.all(4),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, UnifiedTaskService unifiedService) {
    switch (action) {
      case 'edit':
        _showTaskMetadataDialog();
        break;
      case 'add_subtask':
        _addSubtask();
        break;
      case 'complete_all':
        _completeAllSubtasks();
        break;
      case 'delete_all':
        _deleteHierarchy();
        break;
      case 'delete':
        _deleteTask(unifiedService);
        break;
    }
  }

  void _addSubtask() {
    // This would trigger adding a new todo block with increased indent
    // Implementation depends on the parent editor structure
    widget.onNewLine();
    widget.onIndentChanged(widget.indentLevel + 1);
  }

  Future<void> _completeAllSubtasks() async {
    // Phase 11: Re-enabled - now works with domain.Task
    if (_task == null) return;

    try {
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      await unifiedService.completeAllSubtasks(_task!.id);
      await _loadTaskData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All subtasks completed')),
        );
      }
      _logger.info(
        'Completed all subtasks for todo block',
        data: {'taskId': _task!.id},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to complete all subtasks in todo block',
        error: e,
        stackTrace: stackTrace,
        data: {'taskId': _task?.id},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to complete subtasks. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _completeAllSubtasks,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteHierarchy() async {
    // Phase 11: Re-enabled - now works with domain.Task
    if (_task == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Hierarchy'),
        content: const Text(
          'This will delete this task and all its subtasks. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.deleteTaskHierarchy(_task!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task hierarchy deleted')),
          );
        }
        _logger.info(
          'Deleted task hierarchy from todo block',
          data: {'taskId': _task!.id},
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to delete task hierarchy in todo block',
          error: e,
          stackTrace: stackTrace,
          data: {'taskId': _task?.id},
        );
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete hierarchy. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _deleteHierarchy,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTask(UnifiedTaskService unifiedService) async {
    // Phase 11: Re-enabled - now works with domain.Task
    if (_task == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${_task!.title}"?'),
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
      try {
        await unifiedService.onDeleted(_task!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted')),
          );
        }
        _logger.info(
          'Deleted task from todo block',
          data: {'taskId': _task!.id, 'title': _task!.title},
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to delete task in todo block',
          error: e,
          stackTrace: stackTrace,
          data: {'taskId': _task?.id},
        );
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete task. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_deleteTask(unifiedService)),
              ),
            ),
          );
        }
      }
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
}

/// Custom painter for hierarchy connector lines
class HierarchyLinePainter extends CustomPainter {
  HierarchyLinePainter({
    required this.color,
    required this.isLast,
  });

  final Color color;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Vertical line from top
    if (!isLast) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width / 2, size.height);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width / 2, size.height / 2);
    }

    // Horizontal line to task
    path.moveTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HierarchyLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLast != isLast;
  }
}

/// Compact progress indicator for tasks
class TaskProgressIndicator extends StatelessWidget {
  const TaskProgressIndicator({
    super.key,
    required this.progress,
    this.size = 16.0,
  });

  final TaskProgress progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor =
        progress.isFullyCompleted ? Colors.green : theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: progress.progressPercentage,
        strokeWidth: 2.0,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
      ),
    );
  }
}
