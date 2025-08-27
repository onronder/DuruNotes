import 'package:flutter/material.dart';

import '../../../models/note_block.dart';

/// Widget for rendering and editing quote blocks.
/// 
/// This widget handles:
/// - Distinctive visual styling with left border and background
/// - Multiline quote text editing
/// - Proper typography for quotations
/// - Block deletion functionality
class QuoteBlockWidget extends StatelessWidget {
  const QuoteBlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
    this.hintText = 'Quote',
  });

  /// The quote block being edited
  final NoteBlock block;
  
  /// Text controller for the quote content
  final TextEditingController controller;
  
  /// Callback when the block content changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;
  
  /// Hint text to display when empty
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote icon
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Icon(
              Icons.format_quote,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          
          // Quote text input
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              onChanged: (value) {
                final updatedBlock = block.copyWith(data: value);
                onChanged(updatedBlock);
              },
            ),
          ),
          
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete quote',
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying quote blocks in read-only mode.
class QuoteBlockPreview extends StatelessWidget {
  const QuoteBlockPreview({
    super.key,
    required this.text,
    this.attribution,
    this.maxLines,
  });

  /// The quote text to display
  final String text;
  
  /// Optional attribution/author of the quote
  final String? attribution;
  
  /// Maximum number of lines to show (for compact previews)
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote,
                size: 20,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                  maxLines: maxLines,
                  overflow: maxLines != null ? TextOverflow.ellipsis : null,
                ),
              ),
            ],
          ),
          
          // Attribution
          if (attribution?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— $attribution',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget for famous quotes or inspirational content.
class InspirationalQuoteWidget extends StatelessWidget {
  const InspirationalQuoteWidget({
    super.key,
    required this.quote,
    required this.author,
    this.onTap,
  });

  /// The inspirational quote text
  final String quote;
  
  /// The author of the quote
  final String author;
  
  /// Optional callback when tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Quote marks
              Icon(
                Icons.format_quote,
                size: 32,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              
              // Quote text
              Text(
                quote,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Author
              Text(
                '— $author',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
