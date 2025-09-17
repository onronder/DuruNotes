import 'package:duru_notes/core/parser/note_block_parser.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/ui/widgets/blocks/code_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/heading_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/list_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/paragraph_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/table_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/todo_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Advanced block-based note editor
class BlockEditor extends ConsumerStatefulWidget {
  const BlockEditor({
    required this.blocks,
    required this.onBlocksChanged,
    super.key,
    this.focusedBlockIndex,
    this.onBlockFocusChanged,
  });

  final List<NoteBlock> blocks;
  final Function(List<NoteBlock>) onBlocksChanged;
  final int? focusedBlockIndex;
  final Function(int?)? onBlockFocusChanged;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  late List<NoteBlock> _blocks;
  int? _focusedBlockIndex;
  bool _showBlockSelector = false;
  int? _blockSelectorIndex;

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.blocks);
    _focusedBlockIndex = widget.focusedBlockIndex;

    // Ensure at least one block exists
    if (_blocks.isEmpty) {
      _blocks.add(createParagraphBlock(''));
    }
  }

  @override
  void didUpdateWidget(BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks != oldWidget.blocks) {
      _blocks = List.from(widget.blocks);
    }
    if (widget.focusedBlockIndex != oldWidget.focusedBlockIndex) {
      _focusedBlockIndex = widget.focusedBlockIndex;
    }
  }

  void _updateBlocks() {
    widget.onBlocksChanged(_blocks);
  }

  void _updateBlock(int index, NoteBlock newBlock) {
    if (index >= 0 && index < _blocks.length) {
      setState(() {
        _blocks[index] = newBlock;
      });
      _updateBlocks();
    }
  }

  void _insertBlock(int index, NoteBlock block) {
    setState(() {
      _blocks.insert(index, block);
    });
    _updateBlocks();
    _focusBlock(index);
  }

  void _deleteBlock(int index) {
    if (_blocks.length > 1 && index >= 0 && index < _blocks.length) {
      setState(() {
        _blocks.removeAt(index);
        if (_focusedBlockIndex != null && _focusedBlockIndex! >= index) {
          _focusedBlockIndex = _focusedBlockIndex! > 0
              ? _focusedBlockIndex! - 1
              : 0;
        }
      });
      _updateBlocks();
    }
  }

  void _moveBlock(int fromIndex, int toIndex) {
    if (fromIndex >= 0 &&
        fromIndex < _blocks.length &&
        toIndex >= 0 &&
        toIndex < _blocks.length) {
      setState(() {
        final block = _blocks.removeAt(fromIndex);
        _blocks.insert(toIndex, block);
      });
      _updateBlocks();
    }
  }

  void _focusBlock(int? index) {
    setState(() {
      _focusedBlockIndex = index;
    });
    widget.onBlockFocusChanged?.call(index);
  }

  void _showBlockSelectorAt(int index) {
    setState(() {
      _blockSelectorIndex = index;
      _showBlockSelector = true;
    });
  }

  void _hideBlockSelector() {
    setState(() {
      _showBlockSelector = false;
      _blockSelectorIndex = null;
    });
  }

  void _addBlockOfType(NoteBlockType type) {
    if (_blockSelectorIndex == null) return;

    final index = _blockSelectorIndex! + 1;
    NoteBlock newBlock;

    switch (type) {
      case NoteBlockType.paragraph:
        newBlock = createParagraphBlock('');
      case NoteBlockType.heading1:
        newBlock = createHeadingBlock(1, '');
      case NoteBlockType.heading2:
        newBlock = createHeadingBlock(2, '');
      case NoteBlockType.heading3:
        newBlock = createHeadingBlock(3, '');
      case NoteBlockType.bulletList:
        newBlock = const NoteBlock(type: NoteBlockType.bulletList, data: '');
      case NoteBlockType.numberedList:
        newBlock = const NoteBlock(type: NoteBlockType.numberedList, data: '');
      case NoteBlockType.todo:
        newBlock = createTodoBlock('');
      case NoteBlockType.code:
        newBlock = createCodeBlock('');
      case NoteBlockType.table:
        newBlock = const NoteBlock(
          type: NoteBlockType.table,
          data: 'Header 1|Header 2\nCell 1|Cell 2',
        );
      case NoteBlockType.quote:
        newBlock = const NoteBlock(type: NoteBlockType.quote, data: '');
      case NoteBlockType.attachment:
        newBlock = const NoteBlock(type: NoteBlockType.attachment, data: '');
    }

    _insertBlock(index, newBlock);
    _hideBlockSelector();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Block Editor Toolbar
            _buildEditorToolbar(),

            // Blocks List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _blocks.length,
                itemBuilder: (context, index) {
                  return _buildBlockWidget(index);
                },
              ),
            ),
          ],
        ),

        // Block Selector Overlay
        if (_showBlockSelector) _buildBlockSelectorOverlay(),
      ],
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 8,
        children: [
          // Add Block Button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showBlockSelectorAt(_blocks.length - 1),
            tooltip: 'Add Block',
          ),

          // Quick Format Buttons
          IconButton(
            icon: const Icon(Icons.title),
            onPressed: () => _addBlockOfType(NoteBlockType.heading1),
            tooltip: 'Add Heading',
          ),

          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => _addBlockOfType(NoteBlockType.bulletList),
            tooltip: 'Add Bullet List',
          ),

          IconButton(
            icon: const Icon(Icons.check_box),
            onPressed: () => _addBlockOfType(NoteBlockType.todo),
            tooltip: 'Add Todo',
          ),

          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _addBlockOfType(NoteBlockType.code),
            tooltip: 'Add Code Block',
          ),

          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => _addBlockOfType(NoteBlockType.table),
            tooltip: 'Add Table',
          ),

          IconButton(
            icon: const Icon(Icons.link),
            onPressed: _showLinkDialog,
            tooltip: 'Add Link',
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(int index) {
    final block = _blocks[index];
    final isFocused = _focusedBlockIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block Handle
          Container(
            width: 40,
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                // Drag Handle
                GestureDetector(
                  onTap: () => _focusBlock(index),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: isFocused
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                ),

                const SizedBox(height: 4),

                // Add Block Button
                GestureDetector(
                  onTap: () => _showBlockSelectorAt(index),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          // Block Content
          Expanded(child: _buildBlockContent(block, index, isFocused)),

          // Block Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade400),
            onSelected: (value) => _handleBlockMenuAction(value, index),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 16),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'move_up',
                enabled: index > 0,
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_arrow_up, size: 16),
                    SizedBox(width: 8),
                    Text('Move Up'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'move_down',
                enabled: index < _blocks.length - 1,
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_arrow_down, size: 16),
                    SizedBox(width: 8),
                    Text('Move Down'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockContent(NoteBlock block, int index, bool isFocused) {
    switch (block.type) {
      case NoteBlockType.paragraph:
        return ParagraphBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );

      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return HeadingBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );

      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
        return ListBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );

      case NoteBlockType.todo:
        return TodoBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createTodoBlock('')),
        );

      case NoteBlockType.code:
        return CodeBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
        );

      case NoteBlockType.table:
        return TableBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
        );

      case NoteBlockType.quote:
        return ParagraphBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
          isQuote: true,
        );

      default:
        return ParagraphBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => focused ? _focusBlock(index) : null,
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );
    }
  }

  void _handleBlockMenuAction(String action, int index) {
    switch (action) {
      case 'duplicate':
        _insertBlock(index + 1, _blocks[index]);
      case 'delete':
        _deleteBlock(index);
      case 'move_up':
        if (index > 0) _moveBlock(index, index - 1);
      case 'move_down':
        if (index < _blocks.length - 1) _moveBlock(index, index + 1);
    }
  }

  Widget _buildBlockSelectorOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideBlockSelector,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
          child: Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Block',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  _buildBlockTypeGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockTypeGrid() {
    final blockTypes = [
      {
        'type': NoteBlockType.paragraph,
        'icon': Icons.subject,
        'label': 'Paragraph',
      },
      {
        'type': NoteBlockType.heading1,
        'icon': Icons.title,
        'label': 'Heading 1',
      },
      {
        'type': NoteBlockType.heading2,
        'icon': Icons.title,
        'label': 'Heading 2',
      },
      {
        'type': NoteBlockType.heading3,
        'icon': Icons.title,
        'label': 'Heading 3',
      },
      {
        'type': NoteBlockType.bulletList,
        'icon': Icons.format_list_bulleted,
        'label': 'Bullet List',
      },
      {
        'type': NoteBlockType.numberedList,
        'icon': Icons.format_list_numbered,
        'label': 'Numbered List',
      },
      {'type': NoteBlockType.todo, 'icon': Icons.check_box, 'label': 'Todo'},
      {'type': NoteBlockType.code, 'icon': Icons.code, 'label': 'Code'},
      {
        'type': NoteBlockType.table,
        'icon': Icons.table_chart,
        'label': 'Table',
      },
      {
        'type': NoteBlockType.quote,
        'icon': Icons.format_quote,
        'label': 'Quote',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: blockTypes.length,
      itemBuilder: (context, index) {
        final blockType = blockTypes[index];
        return InkWell(
          onTap: () => _addBlockOfType(blockType['type']! as NoteBlockType),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(blockType['icon']! as IconData, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    blockType['label']! as String,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLinkDialog() {
    // TODO: Implement link dialog
    // This would show a dialog to add either a web link or note link
  }
}
