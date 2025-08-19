import 'package:duru_notes_app/models/note_block.dart';
import 'package:flutter/material.dart';

/// A block-based editor for composing notes. This widget renders a list of
/// [NoteBlock]s and allows the user to edit each block independently. It
/// exposes the updated list of blocks via the [onChanged] callback whenever
/// the user edits or reorders blocks. Use this editor in place of a single
/// large `TextField` to support rich content such as headings, todos, quotes,
/// code blocks and tables.
class BlockEditor extends StatefulWidget {
  const BlockEditor({
    required this.blocks,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  /// The initial blocks to edit. The list is copied internally; mutations
  /// inside the editor will not modify the provided list directly.
  final List<NoteBlock> blocks;

  /// Called whenever the list of blocks changes. This includes text edits,
  /// adding/removing blocks, toggling checkboxes and reordering.
  final ValueChanged<List<NoteBlock>> onChanged;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  late List<NoteBlock> _blocks;
  late List<TextEditingController?> _controllers;

  @override
  void initState() {
    super.initState();
    _initFromBlocks(widget.blocks);
  }

  @override
  void didUpdateWidget(BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks) {
      _initFromBlocks(widget.blocks);
    }
  }

  void _initFromBlocks(List<NoteBlock> blocks) {
    _blocks = List<NoteBlock>.from(blocks);
    _controllers = _blocks.map<TextEditingController?>((block) {
      switch (block.type) {
        case NoteBlockType.paragraph:
        case NoteBlockType.heading1:
        case NoteBlockType.heading2:
        case NoteBlockType.heading3:
        case NoteBlockType.quote:
          return TextEditingController(text: block.data as String);
        case NoteBlockType.code:
          final code = (block.data as CodeBlockData).code;
          return TextEditingController(text: code);
        case NoteBlockType.todo:
        case NoteBlockType.table:
          return null;
      }
    }).toList();
  }

  void _notifyChange() {
    widget.onChanged(List<NoteBlock>.from(_blocks));
  }

  void _insertBlock(NoteBlockType type, [int? index]) {
    final insertIndex = index ?? _blocks.length;

    // Construct a new block instance based on the selected type. Use
    // const constructors where possible and avoid redundant parameters.
    late final NoteBlock newBlock;
    if (type == NoteBlockType.paragraph) {
      newBlock = const NoteBlock(type: NoteBlockType.paragraph, data: '');
    } else if (type == NoteBlockType.heading1) {
      newBlock = const NoteBlock(type: NoteBlockType.heading1, data: '');
    } else if (type == NoteBlockType.heading2) {
      newBlock = const NoteBlock(type: NoteBlockType.heading2, data: '');
    } else if (type == NoteBlockType.heading3) {
      newBlock = const NoteBlock(type: NoteBlockType.heading3, data: '');
    } else if (type == NoteBlockType.todo) {
      newBlock = NoteBlock(
        type: NoteBlockType.todo,
        data: const TodoBlockData(text: '', checked: false),
      );
    } else if (type == NoteBlockType.quote) {
      newBlock = const NoteBlock(type: NoteBlockType.quote, data: '');
    } else if (type == NoteBlockType.code) {
      newBlock = const NoteBlock(
        type: NoteBlockType.code,
        data: CodeBlockData(code: ''),
      );
    } else {
      newBlock = const NoteBlock(
        type: NoteBlockType.table,
        data: TableBlockData(
          rows: <List<String>>[
            <String>['', ''],
            <String>['', ''],
          ],
        ),
      );
    }

    setState(() {
      _blocks.insert(insertIndex, newBlock);
      _controllers.insert(
        insertIndex,
        _needsController(newBlock) ? TextEditingController(text: '') : null,
      );
    });
    _notifyChange();
  }

  bool _needsController(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
      case NoteBlockType.quote:
      case NoteBlockType.code:
        return true;
      case NoteBlockType.todo:
      case NoteBlockType.table:
        return false;
    }
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      _controllers.removeAt(index);
    });
    _notifyChange();
  }

  Widget _buildBlock(int index) {
    final block = _blocks[index];
    final controller = _controllers[index];
    switch (block.type) {
      case NoteBlockType.paragraph:
        return _buildTextBlock(index, block, controller!, isParagraph: true);
      case NoteBlockType.heading1:
        return _buildTextBlock(
          index,
          block,
          controller!,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );
      case NoteBlockType.heading2:
        return _buildTextBlock(
          index,
          block,
          controller!,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
      case NoteBlockType.heading3:
        return _buildTextBlock(
          index,
          block,
          controller!,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        );
      case NoteBlockType.quote:
        return _buildQuoteBlock(index, block, controller!);
      case NoteBlockType.code:
        return _buildCodeBlock(index, block, controller!);
      case NoteBlockType.todo:
        return _buildTodoBlock(index, block);
      case NoteBlockType.table:
        return _buildTableBlock(index, block);
    }
  }

  Widget _buildTextBlock(
    int index,
    NoteBlock block,
    TextEditingController controller, {
    double? fontSize,
    FontWeight? fontWeight,
    bool isParagraph = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
            decoration: InputDecoration(
              hintText: isParagraph ? 'Paragraph' : null,
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _blocks[index] = _blocks[index].copyWith(data: value);
              });
              _notifyChange();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _removeBlock(index),
        ),
      ],
    );
  }

  Widget _buildQuoteBlock(
    int index,
    NoteBlock block,
    TextEditingController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 4,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Quote',
              ),
              onChanged: (value) {
                setState(() {
                  _blocks[index] = _blocks[index].copyWith(data: value);
                });
                _notifyChange();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _removeBlock(index),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(
    int index,
    NoteBlock block,
    TextEditingController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.code, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Code',
                  ),
                  onChanged: (value) {
                    final data = block.data as CodeBlockData;
                    setState(() {
                      _blocks[index] = _blocks[index].copyWith(
                        data: data.copyWith(code: value),
                      );
                    });
                    _notifyChange();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _removeBlock(index),
              ),
            ],
          ),
          // Optional: a language picker could be added here.
        ],
      ),
    );
  }

  Widget _buildTodoBlock(int index, NoteBlock block) {
    final todo = block.data as TodoBlockData;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: todo.checked,
          onChanged: (checked) {
            setState(() {
              _blocks[index] = _blocks[index].copyWith(
                data: todo.copyWith(checked: checked ?? false),
              );
            });
            _notifyChange();
          },
        ),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: todo.text),
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Todo',
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _blocks[index] = _blocks[index].copyWith(
                  data: todo.copyWith(text: value),
                );
              });
              _notifyChange();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _removeBlock(index),
        ),
      ],
    );
  }

  Widget _buildTableBlock(int index, NoteBlock block) {
    final table = block.data as TableBlockData;
    // Render a simple read-only preview of the table. Editing support could
    // be added in the future.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (var i = 0; i < table.rows.first.length; i++)
                DataColumn(label: Text('Col ${i + 1}')),
            ],
            rows: [
              for (final row in table.rows)
                DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
            ],
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                // Add a new row of empty cells.
                setState(() {
                  final cols = table.rows.first.length;
                  final newRows = List<List<String>>.from(table.rows)
                    ..add(List<String>.filled(cols, ''));
                  _blocks[index] = _blocks[index].copyWith(
                    data: table.copyWith(rows: newRows),
                  );
                });
                _notifyChange();
              },
              child: const Text('+ Row'),
            ),
            TextButton(
              onPressed: () {
                // Add a new column to each row.
                setState(() {
                  final newRows = table.rows
                      .map((r) => List<String>.from(r)..add(''))
                      .toList();
                  _blocks[index] = _blocks[index].copyWith(
                    data: table.copyWith(rows: newRows),
                  );
                });
                _notifyChange();
              },
              child: const Text('+ Col'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeBlock(index),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _blocks.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildBlock(index),
            );
          },
        ),
        // Add block button at the bottom.
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<NoteBlockType>(
            tooltip: 'Add block',
            // Use a tear-off to satisfy unnecessary_lambdas lint.
            onSelected: _insertBlock,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: NoteBlockType.paragraph,
                child: Text('Paragraph'),
              ),
              PopupMenuItem(
                value: NoteBlockType.heading1,
                child: Text('Heading 1'),
              ),
              PopupMenuItem(
                value: NoteBlockType.heading2,
                child: Text('Heading 2'),
              ),
              PopupMenuItem(
                value: NoteBlockType.heading3,
                child: Text('Heading 3'),
              ),
              PopupMenuItem(
                value: NoteBlockType.todo,
                child: Text('Todo'),
              ),
              PopupMenuItem(
                value: NoteBlockType.quote,
                child: Text('Quote'),
              ),
              PopupMenuItem(
                value: NoteBlockType.code,
                child: Text('Code'),
              ),
              PopupMenuItem(
                value: NoteBlockType.table,
                child: Text('Table'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_circle_outline, size: 20),
                  SizedBox(width: 4),
                  Text('Add block'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
