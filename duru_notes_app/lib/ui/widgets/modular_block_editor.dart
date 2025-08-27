import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/note_block.dart';
import '../../services/attachment_service.dart';
import 'blocks/attachment_block_widget.dart';
import 'blocks/code_block_widget.dart';
import 'blocks/paragraph_block_widget.dart';
import 'blocks/quote_block_widget.dart';
import 'blocks/table_block_widget.dart';
import 'blocks/todo_block_widget.dart';

/// A modular block-based editor for composing notes.
/// 
/// This refactored editor uses specialized widgets for each block type,
/// providing better maintainability and separation of concerns compared
/// to the monolithic [BlockEditor]. Each block type is handled by its
/// own dedicated widget component.
/// 
/// Features:
/// - Modular architecture with specialized block widgets
/// - Dynamic block insertion and deletion
/// - Drag-and-drop reordering (future enhancement)
/// - Consistent theming and styling across all block types
/// - Optimized performance with focused re-renders
class ModularBlockEditor extends StatefulWidget {
  const ModularBlockEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
    this.readOnly = false,
    this.maxBlocks,
  });

  /// The initial blocks to edit
  final List<NoteBlock> blocks;

  /// Called whenever the list of blocks changes
  final ValueChanged<List<NoteBlock>> onChanged;

  /// Whether the editor is in read-only mode
  final bool readOnly;

  /// Optional maximum number of blocks allowed
  final int? maxBlocks;

  @override
  State<ModularBlockEditor> createState() => _ModularBlockEditorState();
}

class _ModularBlockEditorState extends State<ModularBlockEditor> {
  late List<NoteBlock> _blocks;
  late List<TextEditingController?> _controllers;

  @override
  void initState() {
    super.initState();
    _initializeFromBlocks(widget.blocks);
  }

  @override
  void didUpdateWidget(ModularBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks) {
      _initializeFromBlocks(widget.blocks);
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeFromBlocks(List<NoteBlock> blocks) {
    _blocks = List.from(blocks);
    _disposeControllers();
    _createControllers();
  }

  void _disposeControllers() {
    for (final controller in _controllers) {
      controller?.dispose();
    }
    _controllers.clear();
  }

  void _createControllers() {
    _controllers = _blocks.map<TextEditingController?>((block) {
      return _createControllerForBlock(block);
    }).toList();
  }

  TextEditingController? _createControllerForBlock(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
      case NoteBlockType.quote:
        return TextEditingController(text: block.data as String? ?? '');
        
      case NoteBlockType.code:
        final codeData = block.data as CodeBlockData? ?? const CodeBlockData(code: '');
        return TextEditingController(text: codeData.code);
        
      case NoteBlockType.todo:
        final todoData = block.data as TodoBlockData? ?? const TodoBlockData(text: '', checked: false);
        return TextEditingController(text: todoData.text);
        
      case NoteBlockType.table:
      case NoteBlockType.attachment:
        return null; // These blocks manage their own state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block list
        if (_blocks.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _blocks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildBlockWidget(index),
          ),
        
        // Add block controls
        if (!widget.readOnly) ...[
          const SizedBox(height: 16),
          _buildAddBlockControls(),
        ],
      ],
    );
  }

  Widget _buildBlockWidget(int index) {
    final block = _blocks[index];
    final controller = _controllers[index];

    if (widget.readOnly) {
      return _buildReadOnlyBlock(block);
    }

    switch (block.type) {
      case NoteBlockType.paragraph:
        return ParagraphBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );

      case NoteBlockType.heading1:
        return HeadingBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
          level: 1,
        );

      case NoteBlockType.heading2:
        return HeadingBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
          level: 2,
        );

      case NoteBlockType.heading3:
        return HeadingBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
          level: 3,
        );

      case NoteBlockType.quote:
        return QuoteBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );

      case NoteBlockType.code:
        return CodeBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );

      case NoteBlockType.todo:
        return TodoBlockWidget(
          block: block,
          controller: controller!,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );

      case NoteBlockType.table:
        return TableBlockWidget(
          block: block,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );

      case NoteBlockType.attachment:
        return AttachmentBlockWidget(
          block: block,
          onChanged: (updatedBlock) => _updateBlock(index, updatedBlock),
          onDelete: () => _deleteBlock(index),
        );
    }
  }

  Widget _buildReadOnlyBlock(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            block.data as String? ?? '',
            style: _getTextStyleForBlock(block),
          ),
        );

      case NoteBlockType.quote:
        return QuoteBlockPreview(text: block.data as String? ?? '');

      case NoteBlockType.code:
        final codeData = block.data as CodeBlockData;
        return CodeBlockPreview(codeData: codeData);

      case NoteBlockType.todo:
        return TodoBlockWidget(
          block: block,
          controller: TextEditingController(text: (block.data as TodoBlockData).text),
          onChanged: (_) {}, // Read-only
          onDelete: () {}, // Read-only
        );

      case NoteBlockType.table:
        final tableData = block.data as TableBlockData;
        return TableBlockPreview(tableData: tableData);

      case NoteBlockType.attachment:
        final attachmentData = block.data as AttachmentBlockData;
        return AttachmentBlockPreview(attachmentData: attachmentData);
    }
  }

  TextStyle? _getTextStyleForBlock(NoteBlock block) {
    final theme = Theme.of(context);
    
    switch (block.type) {
      case NoteBlockType.heading1:
        return theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold);
      case NoteBlockType.heading2:
        return theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
      case NoteBlockType.heading3:
        return theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600);
      default:
        return theme.textTheme.bodyLarge;
    }
  }

  Widget _buildAddBlockControls() {
    final canAddMore = widget.maxBlocks == null || _blocks.length < widget.maxBlocks!;
    
    if (!canAddMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Maximum blocks reached (${widget.maxBlocks})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<NoteBlockType>(
        tooltip: 'Add block',
        onSelected: _addBlock,
        itemBuilder: (context) => [
          _buildBlockMenuItem(
            NoteBlockType.paragraph,
            'Paragraph',
            Icons.text_fields,
          ),
          _buildBlockMenuItem(
            NoteBlockType.heading1,
            'Heading 1',
            Icons.title,
          ),
          _buildBlockMenuItem(
            NoteBlockType.heading2,
            'Heading 2',
            Icons.title,
          ),
          _buildBlockMenuItem(
            NoteBlockType.heading3,
            'Heading 3',
            Icons.title,
          ),
          _buildBlockMenuItem(
            NoteBlockType.todo,
            'Todo',
            Icons.check_box_outline_blank,
          ),
          _buildBlockMenuItem(
            NoteBlockType.quote,
            'Quote',
            Icons.format_quote,
          ),
          _buildBlockMenuItem(
            NoteBlockType.code,
            'Code',
            Icons.code,
          ),
          _buildBlockMenuItem(
            NoteBlockType.table,
            'Table',
            Icons.table_chart,
          ),
          _buildBlockMenuItem(
            NoteBlockType.attachment,
            'Attachment',
            Icons.attach_file,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Add block',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<NoteBlockType> _buildBlockMenuItem(
    NoteBlockType type,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _addBlock(NoteBlockType type) {
    if (widget.maxBlocks != null && _blocks.length >= widget.maxBlocks!) {
      return;
    }

    if (type == NoteBlockType.attachment) {
      _createAttachmentBlock();
      return;
    }

    final newBlock = _createBlockOfType(type);
    
    setState(() {
      _blocks.add(newBlock);
      _controllers.add(_createControllerForBlock(newBlock));
    });
    
    _notifyChanged();
  }

  NoteBlock _createBlockOfType(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
      case NoteBlockType.quote:
        return NoteBlock(type: type, data: '');
        
      case NoteBlockType.todo:
        return const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: '', checked: false),
        );
        
      case NoteBlockType.code:
        return const NoteBlock(
          type: NoteBlockType.code,
          data: CodeBlockData(code: ''),
        );
        
      case NoteBlockType.table:
        return const NoteBlock(
          type: NoteBlockType.table,
          data: TableBlockData(rows: [
            ['', ''],
            ['', ''],
          ]),
        );
        
      case NoteBlockType.attachment:
        return const NoteBlock(
          type: NoteBlockType.attachment,
          data: AttachmentBlockData(filename: '', url: ''),
        );
    }
  }

  Future<void> _createAttachmentBlock() async {
    final client = Supabase.instance.client;
    final service = AttachmentService(client);

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final data = await service.pickAndUpload();
      
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        
        if (data != null) {
          final newBlock = NoteBlock(type: NoteBlockType.attachment, data: data);
          setState(() {
            _blocks.add(newBlock);
            _controllers.add(null);
          });
          _notifyChanged();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment upload failed: $e')),
        );
      }
    }
  }

  void _updateBlock(int index, NoteBlock updatedBlock) {
    setState(() {
      _blocks[index] = updatedBlock;
    });
    _notifyChanged();
  }

  void _deleteBlock(int index) {
    setState(() {
      _controllers[index]?.dispose();
      _blocks.removeAt(index);
      _controllers.removeAt(index);
    });
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged(List.from(_blocks));
  }
}
