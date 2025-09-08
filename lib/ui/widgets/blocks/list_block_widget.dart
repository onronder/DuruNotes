import 'package:duru_notes/models/note_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ListBlockWidget extends StatefulWidget {
  const ListBlockWidget({
    required this.block, required this.isFocused, required this.onChanged, required this.onFocusChanged, required this.onNewLine, super.key,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final VoidCallback onNewLine;

  @override
  State<ListBlockWidget> createState() => _ListBlockWidgetState();
}

class _ListBlockWidgetState extends State<ListBlockWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.data);
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
  void didUpdateWidget(ListBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.block.data != oldWidget.block.data) {
      _controller.text = widget.block.data;
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

  void _handleTextChanged() {
    final newBlock = widget.block.copyWith(data: _controller.text);
    widget.onChanged(newBlock);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (_controller.selection.baseOffset == _controller.text.length) {
        widget.onNewLine();
      }
    }
  }

  IconData _getListIcon() {
    return widget.block.type == NoteBlockType.bulletList 
        ? Icons.circle 
        : Icons.looks_one;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List Bullet/Number
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: Icon(
              _getListIcon(),
              size: 8,
              color: Theme.of(context).primaryColor,
            ),
          ),
          
          // List Item Text
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
                  hintText: 'List item...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
