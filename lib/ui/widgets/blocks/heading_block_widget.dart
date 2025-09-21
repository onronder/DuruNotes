import 'package:duru_notes/models/note_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeadingBlockWidget extends StatefulWidget {
  const HeadingBlockWidget({
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
  State<HeadingBlockWidget> createState() => _HeadingBlockWidgetState();
}

class _HeadingBlockWidgetState extends State<HeadingBlockWidget> {
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
  void didUpdateWidget(HeadingBlockWidget oldWidget) {
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

  TextStyle _getHeadingStyle() {
    final theme = Theme.of(context);
    switch (widget.block.type) {
      case NoteBlockType.heading1:
        return theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ) ??
            const TextStyle(fontSize: 32, fontWeight: FontWeight.bold);

      case NoteBlockType.heading2:
        return theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ) ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

      case NoteBlockType.heading3:
        return theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ) ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

      default:
        return theme.textTheme.bodyLarge ?? const TextStyle();
    }
  }

  String _getPlaceholder() {
    switch (widget.block.type) {
      case NoteBlockType.heading1:
        return 'Heading 1';
      case NoteBlockType.heading2:
        return 'Heading 2';
      case NoteBlockType.heading3:
        return 'Heading 3';
      default:
        return 'Heading';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Heading Level Indicator
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                'H${widget.block.type == NoteBlockType.heading1 ? '1' : widget.block.type == NoteBlockType.heading2 ? '2' : '3'}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),

          // Heading Text Field
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
                decoration: InputDecoration(
                  hintText: _getPlaceholder(),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: _getHeadingStyle(),
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),

          // Heading Level Selector
          PopupMenuButton<NoteBlockType>(
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
            onSelected: (newType) {
              final newBlock = widget.block.copyWith(type: newType);
              widget.onChanged(newBlock);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: NoteBlockType.heading1,
                child: Text('Heading 1'),
              ),
              const PopupMenuItem(
                value: NoteBlockType.heading2,
                child: Text('Heading 2'),
              ),
              const PopupMenuItem(
                value: NoteBlockType.heading3,
                child: Text('Heading 3'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
