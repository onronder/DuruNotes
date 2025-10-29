import 'package:flutter/material.dart';

/// Interactive note preview that renders todos as clickable checkboxes
/// Used in preview mode to allow checking off tasks without entering edit mode
class InteractiveNotePreview extends StatefulWidget {
  const InteractiveNotePreview({
    super.key,
    required this.content,
    required this.onContentChanged,
    required this.theme,
    required this.colorScheme,
  });

  final String content;
  final ValueChanged<String> onContentChanged;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  State<InteractiveNotePreview> createState() =>
      _InteractiveNotePreviewState();
}

class _InteractiveNotePreviewState extends State<InteractiveNotePreview> {
  late List<_ContentBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  @override
  void didUpdateWidget(InteractiveNotePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _parseContent();
    }
  }

  void _parseContent() {
    final lines = widget.content.split('\n');
    final blocks = <_ContentBlock>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('- [ ]') || trimmed.startsWith('- [x]')) {
        // Todo item
        final isCompleted = trimmed.startsWith('- [x]');
        final text = trimmed.substring(5).trim();
        final indentLevel = (line.length - trimmed.length) ~/ 2;

        blocks.add(_ContentBlock(
          type: _BlockType.todo,
          content: text,
          lineIndex: i,
          isCompleted: isCompleted,
          indentLevel: indentLevel,
        ));
      } else if (line.trim().isNotEmpty) {
        // Regular text
        blocks.add(_ContentBlock(
          type: _BlockType.text,
          content: line,
          lineIndex: i,
        ));
      } else {
        // Empty line for spacing
        blocks.add(_ContentBlock(
          type: _BlockType.empty,
          content: '',
          lineIndex: i,
        ));
      }
    }

    setState(() {
      _blocks = blocks;
    });
  }

  void _toggleTodo(int lineIndex, bool currentValue) {
    final lines = widget.content.split('\n');

    if (lineIndex >= 0 && lineIndex < lines.length) {
      final line = lines[lineIndex];
      String newLine;

      if (currentValue) {
        // Uncheck: [x] -> [ ]
        newLine = line.replaceFirst('- [x]', '- [ ]');
      } else {
        // Check: [ ] -> [x]
        newLine = line.replaceFirst('- [ ]', '- [x]');
      }

      lines[lineIndex] = newLine;
      widget.onContentChanged(lines.join('\n'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _blocks.map((block) {
          switch (block.type) {
            case _BlockType.todo:
              return Padding(
                padding: EdgeInsets.only(
                  left: block.indentLevel * 24.0,
                  top: 4.0,
                  bottom: 4.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: block.isCompleted,
                          onChanged: (value) {
                            _toggleTodo(block.lineIndex, block.isCompleted);
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          activeColor: widget.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        block.content,
                        style: widget.theme.textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: isDark ? Colors.white : Colors.black87,
                          decoration: block.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor:
                              isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );

            case _BlockType.text:
              // Render markdown-style text
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildMarkdownText(block.content, isDark),
              );

            case _BlockType.empty:
              return const SizedBox(height: 8);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildMarkdownText(String text, bool isDark) {
    // Simple markdown rendering for headings, bold, italic
    TextStyle baseStyle = widget.theme.textTheme.bodyLarge!.copyWith(
      height: 1.7,
      color: isDark ? Colors.white : Colors.black87,
    );

    // Check for headings
    if (text.trimLeft().startsWith('#')) {
      final level = text.trimLeft().indexOf(' ');
      final headingText = text.trimLeft().substring(level + 1);

      return Text(
        headingText,
        style: widget.theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: widget.colorScheme.onSurface,
          fontSize: 24 - (level * 2.0),
        ),
      );
    }

    // Regular text
    return Text(
      text,
      style: baseStyle,
    );
  }
}

enum _BlockType {
  todo,
  text,
  empty,
}

class _ContentBlock {
  final _BlockType type;
  final String content;
  final int lineIndex;
  final bool isCompleted;
  final int indentLevel;

  _ContentBlock({
    required this.type,
    required this.content,
    required this.lineIndex,
    this.isCompleted = false,
    this.indentLevel = 0,
  });
}
