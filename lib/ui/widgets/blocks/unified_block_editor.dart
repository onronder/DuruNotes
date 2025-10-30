import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_block_parser.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/ui/widgets/blocks/block_editor.dart';
import 'package:duru_notes/ui/widgets/blocks/code_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/heading_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/hierarchical_todo_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/list_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/paragraph_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/table_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/todo_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration for the unified block editor
class BlockEditorConfig {
  final bool allowReordering;
  final bool showBlockSelector;
  final bool enableMarkdown;
  final bool enableTaskSync;
  final bool useAdvancedFeatures;
  final BlockTheme? theme;
  final EdgeInsets? padding;
  final double? blockSpacing;

  const BlockEditorConfig({
    this.allowReordering = true,
    this.showBlockSelector = true,
    this.enableMarkdown = true,
    this.enableTaskSync = true,
    this.useAdvancedFeatures = false,
    this.theme,
    this.padding,
    this.blockSpacing,
  });

  /// Legacy configuration for backward compatibility
  factory BlockEditorConfig.legacy() {
    return const BlockEditorConfig(
      allowReordering: true,
      showBlockSelector: true,
      enableMarkdown: false,
      enableTaskSync: false,
      useAdvancedFeatures: false,
    );
  }

  /// Modern configuration with all features enabled
  factory BlockEditorConfig.modern() {
    return const BlockEditorConfig(
      allowReordering: true,
      showBlockSelector: true,
      enableMarkdown: true,
      enableTaskSync: true,
      useAdvancedFeatures: true,
    );
  }
}

/// Theme configuration for blocks
class BlockTheme {
  final TextStyle? paragraphStyle;
  final TextStyle? heading1Style;
  final TextStyle? heading2Style;
  final TextStyle? heading3Style;
  final TextStyle? codeStyle;
  final TextStyle? quoteStyle;
  final Color? todoCheckboxColor;
  final Color? codeBackgroundColor;
  final Color? quoteBackgroundColor;

  const BlockTheme({
    this.paragraphStyle,
    this.heading1Style,
    this.heading2Style,
    this.heading3Style,
    this.codeStyle,
    this.quoteStyle,
    this.todoCheckboxColor,
    this.codeBackgroundColor,
    this.quoteBackgroundColor,
  });
}

/// Unified block editor that consolidates multiple implementations
///
/// This widget merges the best features from both BlockEditor and ModularBlockEditor
/// implementations, providing a single, consistent interface with feature flags
/// for gradual migration.
class UnifiedBlockEditor extends ConsumerStatefulWidget {
  final List<NoteBlock> blocks;
  final void Function(List<NoteBlock>) onBlocksChanged;
  final BlockEditorConfig config;
  final String? noteId;
  final int? focusedBlockIndex;
  final void Function(int?)? onBlockFocusChanged;

  const UnifiedBlockEditor({
    super.key,
    required this.blocks,
    required this.onBlocksChanged,
    this.config = const BlockEditorConfig(),
    this.noteId,
    this.focusedBlockIndex,
    this.onBlockFocusChanged,
  });

  @override
  ConsumerState<UnifiedBlockEditor> createState() => _UnifiedBlockEditorState();
}

class _UnifiedBlockEditorState extends ConsumerState<UnifiedBlockEditor> {
  final AppLogger _logger = LoggerFactory.instance;
  final FeatureFlags _featureFlags = FeatureFlags.instance;

  late List<NoteBlock> _blocks;
  late Map<int, TextEditingController> _controllers;
  late Map<int, FocusNode> _focusNodes;

  int? _focusedBlockIndex;
  bool _showBlockSelector = false;
  int? _blockSelectorIndex;

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.blocks);
    _controllers = {};
    _focusNodes = {};
    _focusedBlockIndex = widget.focusedBlockIndex;
    _initializeControllers();

    _logger.info(
      'UnifiedBlockEditor initialized with ${_blocks.length} blocks',
    );
  }

  @override
  void didUpdateWidget(UnifiedBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks != oldWidget.blocks) {
      _blocks = List.from(widget.blocks);
      _initializeControllers();
    }
    if (widget.focusedBlockIndex != oldWidget.focusedBlockIndex) {
      _focusedBlockIndex = widget.focusedBlockIndex;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    // Dispose old controllers that are no longer needed
    final oldKeys = Set<int>.from(_controllers.keys);
    final newKeys = <int>{};

    for (int i = 0; i < _blocks.length; i++) {
      newKeys.add(i);
      if (!_controllers.containsKey(i)) {
        _controllers[i] = TextEditingController(
          text: _blocks[i].data.toString(),
        );
        _focusNodes[i] = FocusNode();
      } else {
        // Update existing controller if text changed
        final currentText = _blocks[i].data.toString();
        if (_controllers[i]!.text != currentText) {
          _controllers[i]!.text = currentText;
        }
      }
    }

    // Dispose controllers for removed blocks
    for (final key in oldKeys.difference(newKeys)) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check feature flag to determine which implementation to use
    if (_featureFlags.useNewBlockEditor) {
      return _buildUnifiedEditor(context);
    } else {
      // Fall back to legacy implementation
      return _buildLegacyEditor(context);
    }
  }

  Widget _buildUnifiedEditor(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (widget.config.showBlockSelector) _buildToolbar(context),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: widget.config.allowReordering,
                onReorder: widget.config.allowReordering
                    ? _onReorder
                    : (_, _) {},
                padding: widget.config.padding ?? const EdgeInsets.all(16),
                itemCount: _blocks.length,
                itemBuilder: (context, index) {
                  return _buildBlockItem(context, index);
                },
              ),
            ),
          ],
        ),
        if (_showBlockSelector) _buildBlockSelectorOverlay(context),
      ],
    );
  }

  Widget _buildLegacyEditor(BuildContext context) {
    // Use the existing BlockEditor as fallback
    return BlockEditor(
      blocks: widget.blocks,
      onBlocksChanged: widget.onBlocksChanged,
      noteId: widget.noteId,
      focusedBlockIndex: widget.focusedBlockIndex,
      onBlockFocusChanged: widget.onBlockFocusChanged,
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openBlockSelector(0),
            tooltip: 'Add block',
          ),
          if (widget.config.enableMarkdown)
            IconButton(
              icon: const Icon(Icons.code),
              onPressed: _toggleMarkdownMode,
              tooltip: 'Toggle Markdown',
            ),
          if (widget.config.allowReordering)
            IconButton(
              icon: const Icon(Icons.drag_handle),
              onPressed: _toggleReorderMode,
              tooltip: 'Reorder blocks',
            ),
          const Spacer(),
          Text(
            '${_blocks.length} blocks',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildBlockItem(BuildContext context, int index) {
    final block = _blocks[index];
    final isFocused = _focusedBlockIndex == index;

    return Dismissible(
      key: ValueKey('block_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteBlock(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: widget.config.blockSpacing ?? 8),
        decoration: isFocused
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.config.allowReordering)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Theme.of(
                      context,
                    ).iconTheme.color?.withValues(alpha: 0.3),
                  ),
                ),
              ),
            Expanded(child: _buildBlockContent(block, index, isFocused)),
            _buildBlockActions(index),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockContent(NoteBlock block, int index, bool isFocused) {
    // Apply custom theme if provided
    final theme = widget.config.theme;

    switch (block.type) {
      case NoteBlockType.paragraph:
        return ParagraphBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => _handleFocusChange(index, focused),
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );

      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return HeadingBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => _handleFocusChange(index, focused),
          onNewLine: () => _insertBlock(index + 1, createParagraphBlock('')),
        );

      case NoteBlockType.todo:
        // PRODUCTION-GRADE: Extract indent level from block data and route intelligently
        final parts = block.data.split(':');
        final indentLevel = parts.length >= 3
            ? (int.tryParse(parts[1]) ?? 0)
            : 0;

        // Route to hierarchical widget if indented, otherwise flat widget
        // The HierarchicalTodoBlockWidget will handle parent-child relationships
        // by analyzing the task hierarchy in the database
        if (indentLevel > 0) {
          return HierarchicalTodoBlockWidget(
            block: block,
            noteId: widget.noteId,
            position: index,
            indentLevel: indentLevel,
            isFocused: isFocused,
            onChanged: (newBlock) => _updateBlock(index, newBlock),
            onFocusChanged: (focused) => _handleFocusChange(index, focused),
            onNewLine: () => _insertBlock(index + 1, createTodoBlock('')),
            onIndentChanged: (newLevel) => _handleIndentChange(index, newLevel),
            parentTaskId:
                null, // Widget will determine parent from task hierarchy
          );
        } else {
          return TodoBlockWidget(
            block: block,
            noteId: widget.noteId,
            position: index,
            isFocused: isFocused,
            onChanged: (newBlock) => _updateBlock(index, newBlock),
            onFocusChanged: (focused) => _handleFocusChange(index, focused),
            onNewLine: () => _insertBlock(index + 1, createTodoBlock('')),
          );
        }

      case NoteBlockType.code:
        return CodeBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => _handleFocusChange(index, focused),
        );

      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
        return ListBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => _handleFocusChange(index, focused),
          onNewLine: () => _insertBlock(index + 1, block),
        );

      case NoteBlockType.table:
        return TableBlockWidget(
          block: block,
          isFocused: isFocused,
          onChanged: (newBlock) => _updateBlock(index, newBlock),
          onFocusChanged: (focused) => _handleFocusChange(index, focused),
        );

      case NoteBlockType.quote:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                theme?.quoteBackgroundColor ??
                Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
          ),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            style: theme?.quoteStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Quote...',
            ),
            maxLines: null,
            onChanged: (text) => _updateBlock(
              index,
              NoteBlock(type: NoteBlockType.quote, data: text),
            ),
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          child: Text('Unsupported block type: ${block.type}'),
        );
    }
  }

  Widget _buildBlockActions(int index) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
      ),
      onSelected: (value) => _handleBlockAction(index, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add_above',
          child: ListTile(
            leading: Icon(Icons.add_circle_outline),
            title: Text('Add block above'),
          ),
        ),
        const PopupMenuItem(
          value: 'add_below',
          child: ListTile(
            leading: Icon(Icons.add_circle),
            title: Text('Add block below'),
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.content_copy),
            title: Text('Duplicate'),
          ),
        ),
        const PopupMenuItem(
          value: 'convert',
          child: ListTile(
            leading: Icon(Icons.transform),
            title: Text('Convert to...'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockSelectorOverlay(BuildContext context) {
    return GestureDetector(
      onTap: _hideBlockSelector,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Block',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NoteBlockType.values.map((type) {
                          return ActionChip(
                            label: Text(_getBlockTypeName(type)),
                            avatar: Icon(_getBlockTypeIcon(type)),
                            onPressed: () => _addBlock(type),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Action handlers

  void _updateBlock(int index, NoteBlock newBlock) {
    setState(() {
      _blocks[index] = newBlock;
    });
    widget.onBlocksChanged(_blocks);
  }

  void _insertBlock(int index, NoteBlock block) {
    setState(() {
      _blocks.insert(index, block);
      _initializeControllers();
    });
    widget.onBlocksChanged(_blocks);

    // Focus the new block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[index]?.requestFocus();
    });
  }

  void _deleteBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      _initializeControllers();
    });
    widget.onBlocksChanged(_blocks);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final block = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, block);
      _initializeControllers();
    });
    widget.onBlocksChanged(_blocks);
  }

  void _handleFocusChange(int index, bool focused) {
    if (focused) {
      setState(() {
        _focusedBlockIndex = index;
      });
      widget.onBlockFocusChanged?.call(index);
    }
  }

  void _openBlockSelector(int index) {
    setState(() {
      _showBlockSelector = true;
      _blockSelectorIndex = index;
    });
  }

  void _hideBlockSelector() {
    setState(() {
      _showBlockSelector = false;
      _blockSelectorIndex = null;
    });
  }

  void _addBlock(NoteBlockType type) {
    final index = _blockSelectorIndex ?? _blocks.length;
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
      case NoteBlockType.todo:
        newBlock = createTodoBlock('');
      case NoteBlockType.code:
        newBlock = createCodeBlock('');
      case NoteBlockType.bulletList:
        newBlock = const NoteBlock(type: NoteBlockType.bulletList, data: '');
      case NoteBlockType.numberedList:
        newBlock = const NoteBlock(type: NoteBlockType.numberedList, data: '');
      case NoteBlockType.table:
        newBlock = const NoteBlock(
          type: NoteBlockType.table,
          data: 'Header 1|Header 2\nCell 1|Cell 2',
        );
      case NoteBlockType.quote:
        newBlock = const NoteBlock(type: NoteBlockType.quote, data: '');
      default:
        newBlock = const NoteBlock(type: NoteBlockType.paragraph, data: '');
    }

    _insertBlock(index, newBlock);
    _hideBlockSelector();
  }

  void _handleBlockAction(int index, String action) {
    switch (action) {
      case 'add_above':
        _openBlockSelector(index);
      case 'add_below':
        _openBlockSelector(index + 1);
      case 'duplicate':
        _insertBlock(index + 1, _blocks[index]);
      case 'convert':
        // TODO: Show conversion options
        break;
      case 'delete':
        _deleteBlock(index);
    }
  }

  /// PRODUCTION-GRADE: Handle indent level changes for hierarchical todos
  void _handleIndentChange(int index, int newLevel) {
    if (index < 0 || index >= _blocks.length) return;

    final block = _blocks[index];
    if (block.type != NoteBlockType.todo) return;

    // Parse current todo data
    final parts = block.data.split(':');
    if (parts.length < 3) {
      _logger.warning(
        'Invalid todo data format at index $index: ${block.data}',
      );
      return;
    }

    // Reconstruct todo data with new indent level
    final isCompleted = parts[0];
    final text = parts.skip(2).join(':');
    final newTodoData = '$isCompleted:$newLevel:$text';

    // Update block with new indent level
    final newBlock = block.copyWith(data: newTodoData);
    _updateBlock(index, newBlock);

    _logger.info('Updated indent level for block $index to $newLevel');
  }

  void _toggleMarkdownMode() {
    // TODO: Implement markdown mode toggle
    _logger.info('Markdown mode toggle requested');
  }

  void _toggleReorderMode() {
    // TODO: Implement reorder mode toggle
    _logger.info('Reorder mode toggle requested');
  }

  String _getBlockTypeName(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
        return 'Paragraph';
      case NoteBlockType.heading1:
        return 'Heading 1';
      case NoteBlockType.heading2:
        return 'Heading 2';
      case NoteBlockType.heading3:
        return 'Heading 3';
      case NoteBlockType.todo:
        return 'Todo';
      case NoteBlockType.code:
        return 'Code';
      case NoteBlockType.bulletList:
        return 'Bullet List';
      case NoteBlockType.numberedList:
        return 'Numbered List';
      case NoteBlockType.table:
        return 'Table';
      case NoteBlockType.quote:
        return 'Quote';
      default:
        return 'Unknown';
    }
  }

  IconData _getBlockTypeIcon(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
        return Icons.text_fields;
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return Icons.title;
      case NoteBlockType.todo:
        return Icons.check_box;
      case NoteBlockType.code:
        return Icons.code;
      case NoteBlockType.bulletList:
        return Icons.format_list_bulleted;
      case NoteBlockType.numberedList:
        return Icons.format_list_numbered;
      case NoteBlockType.table:
        return Icons.table_chart;
      case NoteBlockType.quote:
        return Icons.format_quote;
      default:
        return Icons.block;
    }
  }
}

/// Temporary wrapper for backward compatibility
@Deprecated('Use UnifiedBlockEditor instead')
class BlockEditorWrapper extends StatelessWidget {
  final List<NoteBlock> blocks;
  final void Function(List<NoteBlock>) onChanged;

  const BlockEditorWrapper({
    super.key,
    required this.blocks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to unified implementation with legacy config
    return UnifiedBlockEditor(
      blocks: blocks,
      onBlocksChanged: onChanged,
      config: BlockEditorConfig.legacy(),
    );
  }
}
