import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/hierarchical_task_sync_service.dart';
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:duru_notes/ui/widgets/task_tree_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final void Function() onNewLine;
  final Function(int) onIndentChanged;
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
  NoteTask? _task;
  TaskProgress? _progress;

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
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      final tasks = await unifiedService.getTasksForNote(widget.noteId!);
      final matchingTask = tasks
          .where((task) =>
              task.position == widget.position &&
              task.content.trim() == _text.trim())
          .firstOrNull;

      if (mounted) {
        setState(() {
          _task = matchingTask;
        });

        // Load progress if this is a parent task
        if (_task != null) {
          _loadTaskProgress();
        }
      }
    } catch (e) {
      debugPrint('Error loading task data: $e');
    }
  }

  Future<void> _loadTaskProgress() async {
    if (_task == null) return;

    try {
      final hierarchyService = HierarchicalTaskSyncService(
        database: ref.read(appDbProvider),
        enhancedTaskService: ref.read(enhancedTaskServiceProvider),
      );

      final hasChildren = await hierarchyService.hasSubtasks(_task!.id);
      if (hasChildren) {
        final hierarchy =
            await hierarchyService.getTaskHierarchy(widget.noteId!);
        final node = hierarchy
            .expand((root) => [root, ...root.getAllDescendants()])
            .where((node) => node.task.id == _task!.id)
            .firstOrNull;

        if (node != null && mounted) {
          setState(() {
            _progress = hierarchyService.calculateTaskProgress(node);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading task progress: $e');
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

  Future<void> _toggleCompleted() async {
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();

    // Update task in database if it exists
    if (widget.noteId != null && _task != null) {
      try {
        final unifiedService = ref.read(unifiedTaskServiceProvider);
        await unifiedService.onStatusChanged(
          _task!.id,
          _isCompleted ? TaskStatus.completed : TaskStatus.open,
        );

        // Reload progress after status change
        await _loadTaskProgress();
      } catch (e) {
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
      final unifiedService = ref.read(unifiedTaskServiceProvider);
      final reminderBridge = ref.read(taskReminderBridgeProvider);
      final appDb = ref.read(appDbProvider);

      if (_task == null) {
        // Create new task
        final createdTask = await unifiedService.createTask(
          noteId: widget.noteId!,
          content: _text,
          priority: metadata.priority,
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
        // Update existing task
        final oldTask = _task!;

        await unifiedService.updateTask(
          taskId: oldTask.id,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          labels: metadata.labels,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );

        // Handle reminder changes
        if (metadata.hasReminder &&
            metadata.reminderTime != null &&
            metadata.dueDate != null) {
          if (oldTask.reminderId == null) {
            // Create new reminder with custom time
            final updatedTask = await appDb.getTaskById(oldTask.id);
            if (updatedTask != null) {
              final duration =
                  metadata.dueDate!.difference(metadata.reminderTime!);
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
                            ? _getPriorityColor(
                                _task?.priority ?? TaskPriority.medium)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: _isCompleted
                          ? _getPriorityColor(
                              _task?.priority ?? TaskPriority.medium)
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

                    // Task indicators
                    if (_task != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TaskIndicatorsWidget(
                                task: _task!,
                                compact: true,
                              ),
                            ),

                            // Subtask count indicator
                            if (hasChildren && _progress != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_progress!.totalTasks - 1} subtask${_progress!.totalTasks - 1 == 1 ? '' : 's'}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
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
    if (_task == null) return;

    try {
      final hierarchyService = HierarchicalTaskSyncService(
        database: ref.read(appDbProvider),
        enhancedTaskService: ref.read(enhancedTaskServiceProvider),
      );

      await hierarchyService.completeAllSubtasks(_task!.id);
      await _loadTaskProgress();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All subtasks completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing subtasks: $e')),
        );
      }
    }
  }

  Future<void> _deleteHierarchy() async {
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
        final hierarchyService = HierarchicalTaskSyncService(
          database: ref.read(appDbProvider),
          enhancedTaskService: ref.read(enhancedTaskServiceProvider),
        );

        await hierarchyService.deleteTaskHierarchy(_task!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task hierarchy deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting hierarchy: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTask(UnifiedTaskService unifiedService) async {
    if (_task == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${_task!.content}"?'),
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting task: $e')),
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
