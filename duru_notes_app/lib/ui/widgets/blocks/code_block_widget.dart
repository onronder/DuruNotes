import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/note_block.dart';

/// Widget for rendering and editing code blocks.
/// 
/// This widget handles:
/// - Syntax highlighting (basic monospace formatting)
/// - Language selection and display
/// - Code formatting and indentation
/// - Copy-to-clipboard functionality
/// - Block deletion functionality
class CodeBlockWidget extends StatelessWidget {
  const CodeBlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
    this.hintText = 'Code',
  });

  /// The code block being edited
  final NoteBlock block;
  
  /// Text controller for the code content
  final TextEditingController controller;
  
  /// Callback when the block content changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;
  
  /// Hint text to display when empty
  final String hintText;

  CodeBlockData get _codeData => block.data as CodeBlockData;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and actions
          _buildCodeHeader(context),
          
          // Code input area
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: controller,
              maxLines: null,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              onChanged: (value) {
                final updatedData = _codeData.copyWith(code: value);
                final updatedBlock = block.copyWith(data: updatedData);
                onChanged(updatedBlock);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.code,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          
          // Language selector
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _codeData.language?.isEmpty == true ? null : _codeData.language,
                hint: Text(
                  'Language',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                isDense: true,
                items: _supportedLanguages.map((lang) {
                  return DropdownMenuItem<String?>(
                    value: lang,
                    child: Text(
                      lang ?? 'Plain text',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }).toList(),
                onChanged: (language) {
                  final updatedData = _codeData.copyWith(language: language);
                  final updatedBlock = block.copyWith(data: updatedData);
                  onChanged(updatedBlock);
                },
              ),
            ),
          ),
          
          // Copy button
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copyToClipboard(context),
              tooltip: 'Copy code',
            ),
          
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: onDelete,
            tooltip: 'Delete code block',
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    if (controller.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: controller.text));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static const List<String?> _supportedLanguages = [
    null, // Plain text
    'dart',
    'javascript',
    'typescript',
    'python',
    'java',
    'kotlin',
    'swift',
    'go',
    'rust',
    'cpp',
    'c',
    'csharp',
    'php',
    'ruby',
    'shell',
    'sql',
    'html',
    'css',
    'json',
    'xml',
    'yaml',
    'markdown',
  ];
}

/// Widget for displaying code block previews in read-only mode.
class CodeBlockPreview extends StatelessWidget {
  const CodeBlockPreview({
    super.key,
    required this.codeData,
    this.maxLines,
  });

  /// The code block data to display
  final CodeBlockData codeData;
  
  /// Maximum number of lines to show (for compact previews)
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (codeData.code.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language label
          if (codeData.language?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.code,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    codeData.language!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // Code content
          Text(
            codeData.code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ],
      ),
    );
  }
}
