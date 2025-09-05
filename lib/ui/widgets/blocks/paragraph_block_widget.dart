import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/note_block.dart';

class ParagraphBlockWidget extends StatefulWidget {
  const ParagraphBlockWidget({
    super.key,
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onNewLine,
    this.isQuote = false,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final VoidCallback onNewLine;
  final bool isQuote;

  @override
  State<ParagraphBlockWidget> createState() => _ParagraphBlockWidgetState();
}

class _ParagraphBlockWidgetState extends State<ParagraphBlockWidget> {
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
  void didUpdateWidget(ParagraphBlockWidget oldWidget) {
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
      // Check if cursor is at the end
      if (_controller.selection.baseOffset == _controller.text.length) {
        widget.onNewLine();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.isQuote
          ? BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 4,
                ),
              ),
            )
          : null,
      padding: widget.isQuote ? const EdgeInsets.only(left: 16) : null,
      child: Focus(
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => _handleTextChanged(),
          decoration: InputDecoration(
            hintText: widget.isQuote 
                ? 'Quote...' 
                : 'Type something...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          style: widget.isQuote
              ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                )
              : Theme.of(context).textTheme.bodyLarge,
          maxLines: null,
          textInputAction: TextInputAction.newline,
        ),
      ),
    );
  }
}