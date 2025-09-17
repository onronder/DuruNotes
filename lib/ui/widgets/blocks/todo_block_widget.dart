import 'package:duru_notes/models/note_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodoBlockWidget extends StatefulWidget {
  const TodoBlockWidget({
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onNewLine,
    super.key,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final VoidCallback onNewLine;

  @override
  State<TodoBlockWidget> createState() => _TodoBlockWidgetState();
}

class _TodoBlockWidgetState extends State<TodoBlockWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _isCompleted;
  late String _text;

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

  void _updateTodo() {
    final todoData = '${_isCompleted ? 'completed' : 'incomplete'}:$_text';
    final newBlock = widget.block.copyWith(data: todoData);
    widget.onChanged(newBlock);
  }

  void _handleTextChanged() {
    _text = _controller.text;
    _updateTodo();
  }

  void _toggleCompleted() {
    setState(() {
      _isCompleted = !_isCompleted;
    });
    _updateTodo();
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: GestureDetector(
              onTap: _toggleCompleted,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isCompleted
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: _isCompleted
                      ? Theme.of(context).primaryColor
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
            child: Focus(
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  decoration: _isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  color: _isCompleted ? Colors.grey.shade500 : null,
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),

          // Priority Selector
          PopupMenuButton<String>(
            icon: Icon(
              Icons.flag_outlined,
              size: 16,
              color: Colors.grey.shade400,
            ),
            onSelected: (priority) {
              // TODO: Implement priority handling
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'high',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('High Priority'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'medium',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('Medium Priority'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'low',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Low Priority'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'none',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Text('No Priority'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
