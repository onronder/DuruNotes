import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/models/note_block.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show unifiedTaskServiceProvider, taskReminderBridgeProvider;
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Todo block widget using UnifiedTaskService
/// No VoidCallback usage - all actions go through the unified service
/// Phase 11: Re-enabled task matching with decrypted domain.Task from repository
class TodoBlockWidget extends ConsumerStatefulWidget {
  const TodoBlockWidget({
    required this.block,
    required this.noteId,
    required this.position,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onNewLine,
    super.key,
  });

  final NoteBlock block;
  final String? noteId;
  final int position;
  final bool isFocused;
  final void Function(NoteBlock) onChanged;
  final void Function(bool) onFocusChanged;
  final void Function() onNewLine;

  @override
  ConsumerState<TodoBlockWidget> createState() => _TodoBlockWidgetState();
}

class _TodoBlockWidgetState extends ConsumerState<TodoBlockWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _isCompleted;
  late String _text;

  // Phase 11: Re-enabled - now uses decrypted domain.Task from repository
  domain.Task? _task;

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
  void didUpdateWidget(TodoBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.block.data != oldWidget.block.data) {
      _parseTodoData();
      _controller.text = _text;
    }

    if (widget.isFocused && !oldWidget.isFocused) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _parseTodoData() {
    final parts = widget.block.data.split(':');
    if (parts.length >= 2) {
      _isCompleted = parts[0] == 'completed';
      _text = parts.skip(1).join(':');
    } else {
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
        });
      }
    } catch (e) {
      debugPrint('Error loading task data: $e');
    }
  }

  void _updateTodo() {
    final todoData = '${_isCompleted ? 'completed' : 'incomplete'}:$_text';
    final newBlock = widget.block.copyWith(data: todoData);
    widget.onChanged(newBlock);
  }

  void _handleTextChanged() {
    _text = _controller.text;
    _updateTodo();
  }

  void _toggleCompleted() async {
    // Optimistic UI update
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();

    // Phase 11: Re-enabled - update task status if it exists
    if (_task != null && widget.noteId != null) {
      try {
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.toggleTaskStatus(_task!.id);
      } catch (e) {
        debugPrint('Error toggling task status: $e');
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
        // NEW TASK WITH OPTIONAL REMINDER
        if (metadata.hasReminder &&
            metadata.reminderTime != null &&
            metadata.dueDate != null) {
          final createdTask = await unifiedService.createTask(
            noteId: widget.noteId!,
            content: _text,
            dueDate: metadata.dueDate,
            priority: TaskMapper.mapPriorityToDb(metadata.priority),
            labels: metadata.labels,
            notes: metadata.notes,
            estimatedMinutes: metadata.estimatedMinutes,
          );

          final duration = metadata.dueDate!.difference(metadata.reminderTime!);
          await reminderBridge.createTaskReminder(
            task: createdTask,
            beforeDueDate: duration.abs(),
          );
        } else {
          await unifiedService.createTask(
            noteId: widget.noteId!,
            content: _text,
            priority: TaskMapper.mapPriorityToDb(metadata.priority),
            dueDate: metadata.dueDate,
            labels: metadata.labels,
            notes: metadata.notes,
            estimatedMinutes: metadata.estimatedMinutes,
          );
        }

        // Reload task data
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

        // Reload task data
        await _loadTaskData();
      }
    } catch (e) {
      debugPrint('Error saving task metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving task: $e')),
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // Check if cursor is at the end
      if (_controller.selection.baseOffset == _controller.text.length) {
        widget.onNewLine();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox with long-press support
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: GestureDetector(
                  key: ValueKey('todo_checkbox_${widget.position}'),
                  onTap: _toggleCompleted,
                  onLongPress:
                      widget.noteId != null ? _showTaskMetadataDialog : null,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isCompleted
                            ? theme.primaryColor
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: _isCompleted
                          ? theme.primaryColor
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
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),

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

              // More options button
              if (widget.noteId != null)
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: _showTaskMetadataDialog,
                  tooltip: 'Task options',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
