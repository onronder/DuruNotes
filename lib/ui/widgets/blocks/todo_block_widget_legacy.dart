import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final VoidCallback onNewLine;

  @override
  ConsumerState<TodoBlockWidget> createState() => _TodoBlockWidgetState();
}

class _TodoBlockWidgetState extends ConsumerState<TodoBlockWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _isCompleted;
  late String _text;
  NoteTask? _task;

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
    if (widget.noteId == null) return;
    
    try {
      // Check if widget is still mounted before using ref
      if (!mounted) return;
      
      final tasks = await ref.read(appDbProvider).getTasksForNote(widget.noteId!);
      final matchingTask = tasks.where((task) => 
        task.position == widget.position && 
        task.content.trim() == _text.trim()
      ).firstOrNull;
      
      if (mounted) {
        setState(() {
          _task = matchingTask;
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
    final previousState = _isCompleted;
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();
    
    // Track the optimistic state
    final optimisticState = _isCompleted;

    // Update task in database if it exists
    if (widget.noteId != null && _task != null) {
      try {
        // Use the coordinator for critical sync
        final coordinator = ref.read(noteTaskCoordinatorProvider);
        
        // Get the updated note content
        final noteContent = widget.controller.text;
        
        // Handle task toggle with critical priority
        await coordinator.handleTaskToggle(
          noteId: widget.noteId!,
          taskId: _task!.id,
          isCompleted: _isCompleted,
          updatedContent: noteContent,
        );
        
        // Update is handled by the note content update above
        // The bidirectional sync service will handle task updates
      } catch (e) {
        // Revert on error
        if (mounted && _isCompleted == optimisticState) {
          setState(() {
            _isCompleted = previousState;
          });
          _updateTodo();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update task: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('Error updating task completion: $e');
      }
    }
  }

  void _showTaskMetadataDialog() async {
    if (widget.noteId == null) return;

    final result = await showDialog<TaskMetadata>(
      context: context,
      builder: (context) => TaskMetadataDialog(
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
      final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
      final reminderBridge = ref.read(taskReminderBridgeProvider);
      final appDb = ref.read(appDbProvider);

      if (_task == null) {
        // NEW TASK WITH CUSTOM REMINDER
        String taskId;
        
        if (metadata.hasReminder && 
            metadata.reminderTime != null && 
            metadata.dueDate != null) {
          // Use createTaskWithReminder for custom reminder times
          taskId = await enhancedTaskService.createTaskWithReminder(
            noteId: widget.noteId!,
            content: _text,
            dueDate: metadata.dueDate,
            reminderTime: metadata.reminderTime,
            priority: metadata.priority,
            labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
            notes: metadata.notes,
            estimatedMinutes: metadata.estimatedMinutes,
          );
        } else {
          // Create task without reminder or with default reminder
          taskId = await enhancedTaskService.createTask(
            noteId: widget.noteId!,
            content: _text,
            priority: metadata.priority,
            dueDate: metadata.dueDate,
            labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
            notes: metadata.notes,
            estimatedMinutes: metadata.estimatedMinutes,
            createReminder: metadata.hasReminder && metadata.dueDate != null,
          );
        }

        // Reload task data
        await _loadTaskData();
      } else {
        // UPDATE EXISTING TASK
        final oldTask = _task!;
        
        await enhancedTaskService.updateTask(
          taskId: oldTask.id,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );
        
        // Handle reminder changes
        if (metadata.hasReminder && metadata.reminderTime != null && metadata.dueDate != null) {
          if (oldTask.reminderId == null) {
            // Create new reminder
            final updatedTask = await appDb.getTaskById(oldTask.id);
            if (updatedTask != null) {
              final duration = metadata.dueDate!.difference(metadata.reminderTime!);
              await reminderBridge.createTaskReminder(
                task: updatedTask,
                beforeDueDate: duration.abs(),
              );
            }
          } else {
            // Update existing reminder
            final updatedTask = await appDb.getTaskById(oldTask.id);
            if (updatedTask != null) {
              await reminderBridge.updateTaskReminder(updatedTask);
            }
          }
        } else if (!metadata.hasReminder && oldTask.reminderId != null) {
          // Cancel existing reminder
          await reminderBridge.cancelTaskReminder(oldTask);
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
    final colorScheme = theme.colorScheme;

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
                  onTap: _toggleCompleted,
                  onLongPress: widget.noteId != null ? _showTaskMetadataDialog : null,
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
                    
                    // Task indicators
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
