import 'package:duru_notes/models/note_block.dart';
import 'package:flutter/material.dart';

class TableBlockWidget extends StatefulWidget {
  const TableBlockWidget({
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    super.key,
  });

  final NoteBlock block;
  final bool isFocused;
  final void Function(NoteBlock) onChanged;
  final void Function(bool) onFocusChanged;

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  late List<List<TextEditingController>> _controllers;
  late List<String> _headers;
  late List<List<String>> _rows;

  @override
  void initState() {
    super.initState();
    _parseTableData();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.block.data != oldWidget.block.data) {
      _disposeControllers();
      _parseTableData();
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _parseTableData() {
    final lines = widget.block.data.split('\n');
    if (lines.isNotEmpty) {
      _headers = lines[0].split('|');
      _rows = lines.skip(1).map((line) => line.split('|')).toList();
    } else {
      _headers = ['Header 1', 'Header 2'];
      _rows = [
        ['Cell 1', 'Cell 2'],
      ];
    }
  }

  void _initializeControllers() {
    _controllers = [];

    // Header controllers
    final headerControllers = _headers
        .map((header) => TextEditingController(text: header))
        .toList();
    _controllers.add(headerControllers);

    // Row controllers
    for (final row in _rows) {
      final rowControllers = row
          .map((cell) => TextEditingController(text: cell))
          .toList();
      _controllers.add(rowControllers);
    }
  }

  void _disposeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }

  void _updateTable() {
    // Update headers
    _headers = _controllers[0].map((c) => c.text).toList();

    // Update rows
    _rows = _controllers
        .skip(1)
        .map((row) => row.map((c) => c.text).toList())
        .toList();

    // Create table data string
    final tableData = [
      _headers.join('|'),
      ..._rows.map((row) => row.join('|')),
    ].join('\n');

    final newBlock = widget.block.copyWith(data: tableData);
    widget.onChanged(newBlock);
  }

  void _addColumn() {
    setState(() {
      _headers.add('New Header');
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].add('New Cell');
      }

      // Add controllers
      _controllers[0].add(TextEditingController(text: 'New Header'));
      for (var i = 1; i < _controllers.length; i++) {
        _controllers[i].add(TextEditingController(text: 'New Cell'));
      }
    });
    _updateTable();
  }

  void _addRow() {
    setState(() {
      final newRow = List.filled(_headers.length, 'New Cell');
      _rows.add(newRow);

      // Add controllers
      final rowControllers = newRow
          .map((cell) => TextEditingController(text: cell))
          .toList();
      _controllers.add(rowControllers);
    });
    _updateTable();
  }

  void _removeColumn(int columnIndex) {
    if (_headers.length > 1) {
      setState(() {
        _headers.removeAt(columnIndex);
        for (var i = 0; i < _rows.length; i++) {
          if (_rows[i].length > columnIndex) {
            _rows[i].removeAt(columnIndex);
          }
        }

        // Remove controllers
        _controllers[0][columnIndex].dispose();
        _controllers[0].removeAt(columnIndex);
        for (var i = 1; i < _controllers.length; i++) {
          if (_controllers[i].length > columnIndex) {
            _controllers[i][columnIndex].dispose();
            _controllers[i].removeAt(columnIndex);
          }
        }
      });
      _updateTable();
    }
  }

  void _removeRow(int rowIndex) {
    if (_rows.length > 1) {
      setState(() {
        _rows.removeAt(rowIndex);

        // Remove controllers (rowIndex + 1 because index 0 is headers)
        final controllersIndex = rowIndex + 1;
        for (final controller in _controllers[controllersIndex]) {
          controller.dispose();
        }
        _controllers.removeAt(controllersIndex);
      });
      _updateTable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Actions
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Text('Table', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: _addColumn,
                  tooltip: 'Add Column',
                ),
                IconButton(
                  icon: const Icon(Icons.add_box, size: 16),
                  onPressed: _addRow,
                  tooltip: 'Add Row',
                ),
              ],
            ),
          ),

          // Table Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: List.generate(_headers.length, (index) {
                return DataColumn(
                  label: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _controllers[0][index],
                          onChanged: (_) => _updateTable(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_headers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close, size: 12),
                          onPressed: () => _removeColumn(index),
                        ),
                    ],
                  ),
                );
              }),
              rows: List.generate(_rows.length, (rowIndex) {
                return DataRow(
                  cells: List.generate(_headers.length, (colIndex) {
                    final controllerIndex = rowIndex + 1;
                    return DataCell(
                      Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller:
                                  _controllers[controllerIndex][colIndex],
                              onChanged: (_) => _updateTable(),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (colIndex == 0 && _rows.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close, size: 12),
                              onPressed: () => _removeRow(rowIndex),
                            ),
                        ],
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
