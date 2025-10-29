import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/models/note_block.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/widgets/task_indicators_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:duru_notes/services/domain_task_controller.dart';

/// Todo block widget backed by the domain task controller
/// No VoidCallback usage - all actions go through the domain layer
/// Domain migration: matches decrypted domain.Task entities from the repository
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

  AppLogger get _logger => ref.read(loggerProvider);

  DomainTaskController? _maybeController({bool showSnackbar = true}) {
    final repository = ref.read(taskCoreRepositoryProvider);
    if (repository == null) {
      _logger.warning(
        'Task action attempted without authenticated user',
        data: {'noteId': widget.noteId},
      );
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign in to manage tasks.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }

    try {
      return ref.read(domainTaskControllerProvider);
    } on StateError catch (error, stackTrace) {
      _logger.error(
        'DomainTaskController unavailable',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': widget.noteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tasks temporarily unavailable.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }

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
    // Domain migration: load decrypted tasks via controller
    if (widget.noteId == null) return;

    try {
      final controller = _maybeController(showSnackbar: false);
      if (controller == null) return;

      final tasks = await controller.getTasksForNote(widget.noteId!);

      domain.Task? matchedTask;
      for (final task in tasks) {
        if (task.title.trim() == _text.trim()) {
          matchedTask = task;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _task = matchedTask;
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

  void _updateTodo() {
    final todoData = '${_isCompleted ? 'completed' : 'incomplete'}:$_text';
    final newBlock = widget.block.copyWith(data: todoData);
    widget.onChanged(newBlock);
  }

  void _handleTextChanged() {
    _text = _controller.text;
    _updateTodo();
  }

  Future<void> _refreshTask() async {
    if (_task == null) return;
    try {
      final controller = _maybeController(showSnackbar: false);
      if (controller == null) return;

      final updated = await controller.getTaskById(_task!.id);
      if (mounted && updated != null) {
        setState(() {
          _task = updated;
        });
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to refresh task state for todo block',
        data: {
          'taskId': _task?.id,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  void _toggleCompleted() async {
    // Optimistic UI update
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();

    // Domain migration: update task status via controller
    if (_task != null && widget.noteId != null) {
      try {
        final controller = _maybeController();
        if (controller == null) return;

        await controller.toggleStatus(_task!.id);
        await _refreshTask();
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
      final controller = _maybeController();
      if (controller == null) return;

      if (_task == null) {
        final createdTask = await controller.createTask(
          noteId: widget.noteId!,
          title: _text,
          description: metadata.notes,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          tags: metadata.labels,
          createReminder: metadata.hasReminder,
          reminderTime: metadata.reminderTime,
          estimatedMinutes: metadata.estimatedMinutes,
          metadata: metadata.estimatedMinutes != null
              ? {'estimatedMinutes': metadata.estimatedMinutes}
              : null,
        );

        if (mounted) {
          setState(() {
            _task = createdTask;
          });
        }
      } else {
        final updatedTask = await controller.updateTask(
          _task!,
          description: metadata.notes,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          tags: metadata.labels,
          estimatedMinutes: metadata.estimatedMinutes,
          hasReminder: metadata.hasReminder,
          reminderTime: metadata.reminderTime,
        );

        if (mounted) {
          setState(() {
            _task = updatedTask;
          });
        }
      }

      await _refreshTask();
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
