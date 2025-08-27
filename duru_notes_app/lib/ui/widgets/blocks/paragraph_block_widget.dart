import 'package:flutter/material.dart';

import '../../../models/note_block.dart';

/// Widget for rendering and editing paragraph blocks.
/// 
/// This widget handles:
/// - Plain text paragraph editing with multiline support
/// - Responsive text input with auto-growing height
/// - Consistent styling and theming
/// - Block deletion functionality
class ParagraphBlockWidget extends StatelessWidget {
  const ParagraphBlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
    this.hintText = 'Paragraph',
    this.fontSize,
    this.fontWeight,
  });

  /// The paragraph block being edited
  final NoteBlock block;
  
  /// Text controller for the paragraph content
  final TextEditingController controller;
  
  /// Callback when the block content changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;
  
  /// Hint text to display when empty
  final String hintText;
  
  /// Optional custom font size
  final double? fontSize;
  
  /// Optional custom font weight
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 0.0,
              ),
            ),
            onChanged: (value) {
              final updatedBlock = block.copyWith(data: value);
              onChanged(updatedBlock);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          tooltip: 'Delete paragraph',
        ),
      ],
    );
  }
}

/// Widget for rendering heading blocks (H1, H2, H3).
/// 
/// This extends [ParagraphBlockWidget] with heading-specific styling.
class HeadingBlockWidget extends ParagraphBlockWidget {
  const HeadingBlockWidget({
    super.key,
    required super.block,
    required super.controller,
    required super.onChanged,
    required super.onDelete,
    required this.level,
  });

  /// Heading level (1, 2, or 3)
  final int level;

  @override
  double? get fontSize {
    switch (level) {
      case 1:
        return 24.0;
      case 2:
        return 20.0;
      case 3:
        return 18.0;
      default:
        return null;
    }
  }

  @override
  FontWeight? get fontWeight {
    switch (level) {
      case 1:
      case 2:
        return FontWeight.bold;
      case 3:
        return FontWeight.w600;
      default:
        return null;
    }
  }

  @override
  String get hintText {
    switch (level) {
      case 1:
        return 'Heading 1';
      case 2:
        return 'Heading 2';
      case 3:
        return 'Heading 3';
      default:
        return 'Heading';
    }
  }
}
