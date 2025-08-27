import 'package:flutter/material.dart';

import '../../../models/note_block.dart';

/// Widget for rendering and editing table blocks.
/// 
/// This widget handles:
/// - Dynamic table structure with add/remove rows and columns
/// - Cell editing with text input
/// - Table navigation and layout
/// - Responsive design for different screen sizes
/// - Block deletion functionality
class TableBlockWidget extends StatefulWidget {
  const TableBlockWidget({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onDelete,
  });

  /// The table block being edited
  final NoteBlock block;
  
  /// Callback when the block content changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  late List<List<TextEditingController>> _controllers;
  
  TableBlockData get _tableData => widget.block.data as TableBlockData;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldTable = oldWidget.block.data as TableBlockData;
    if (oldTable.rows.length != _tableData.rows.length ||
        (oldTable.rows.isNotEmpty && 
         oldTable.rows.first.length != _tableData.rows.first.length)) {
      _disposeControllers();
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _controllers = _tableData.rows.map((row) {
      return row.map((cell) => TextEditingController(text: cell)).toList();
    }).toList();
  }

  void _disposeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table header with actions
            _buildTableHeader(context),
            const SizedBox(height: 8),
            
            // Table content
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(context),
            ),
            const SizedBox(height: 8),
            
            // Table actions
            _buildTableActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.table_chart,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Table (${_tableData.rows.length}×${_tableData.rows.isNotEmpty ? _tableData.rows.first.length : 0})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: widget.onDelete,
          tooltip: 'Delete table',
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    if (_tableData.rows.isEmpty) {
      return const Center(
        child: Text('Empty table'),
      );
    }

    return DataTable(
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        width: 1,
      ),
      columnSpacing: 0,
      horizontalMargin: 0,
      headingRowHeight: 48,
      dataRowMinHeight: 48,
      columns: List.generate(
        _tableData.rows.first.length,
        (index) => DataColumn(
          label: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Col ${index + 1}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      rows: List.generate(
        _tableData.rows.length,
        (rowIndex) => DataRow(
          cells: List.generate(
            _tableData.rows[rowIndex].length,
            (colIndex) => DataCell(
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _controllers[rowIndex][colIndex],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) => _updateCell(rowIndex, colIndex, value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Row'),
        ),
        ElevatedButton.icon(
          onPressed: _addColumn,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Column'),
        ),
        if (_tableData.rows.length > 1)
          OutlinedButton.icon(
            onPressed: _removeRow,
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('Remove Row'),
          ),
        if (_tableData.rows.isNotEmpty && _tableData.rows.first.length > 1)
          OutlinedButton.icon(
            onPressed: _removeColumn,
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('Remove Column'),
          ),
      ],
    );
  }

  void _updateCell(int rowIndex, int colIndex, String value) {
    final newRows = List<List<String>>.from(_tableData.rows);
    newRows[rowIndex][colIndex] = value;
    
    final updatedData = _tableData.copyWith(rows: newRows);
    final updatedBlock = widget.block.copyWith(data: updatedData);
    widget.onChanged(updatedBlock);
  }

  void _addRow() {
    final colCount = _tableData.rows.isNotEmpty ? _tableData.rows.first.length : 2;
    final newRow = List<String>.filled(colCount, '');
    final newRows = List<List<String>>.from(_tableData.rows)..add(newRow);
    
    final updatedData = _tableData.copyWith(rows: newRows);
    final updatedBlock = widget.block.copyWith(data: updatedData);
    widget.onChanged(updatedBlock);
  }

  void _addColumn() {
    final newRows = _tableData.rows.map((row) {
      return List<String>.from(row)..add('');
    }).toList();
    
    final updatedData = _tableData.copyWith(rows: newRows);
    final updatedBlock = widget.block.copyWith(data: updatedData);
    widget.onChanged(updatedBlock);
  }

  void _removeRow() {
    if (_tableData.rows.length <= 1) return;
    
    final newRows = List<List<String>>.from(_tableData.rows)..removeLast();
    final updatedData = _tableData.copyWith(rows: newRows);
    final updatedBlock = widget.block.copyWith(data: updatedData);
    widget.onChanged(updatedBlock);
  }

  void _removeColumn() {
    if (_tableData.rows.isEmpty || _tableData.rows.first.length <= 1) return;
    
    final newRows = _tableData.rows.map((row) {
      final newRow = List<String>.from(row);
      if (newRow.isNotEmpty) newRow.removeLast();
      return newRow;
    }).toList();
    
    final updatedData = _tableData.copyWith(rows: newRows);
    final updatedBlock = widget.block.copyWith(data: updatedData);
    widget.onChanged(updatedBlock);
  }
}

/// Widget for displaying table blocks in read-only mode.
class TableBlockPreview extends StatelessWidget {
  const TableBlockPreview({
    super.key,
    required this.tableData,
    this.maxRows,
    this.maxColumns,
  });

  /// The table data to display
  final TableBlockData tableData;
  
  /// Maximum number of rows to show
  final int? maxRows;
  
  /// Maximum number of columns to show
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (tableData.rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Empty table'),
          ),
        ),
      );
    }

    final rows = maxRows != null && tableData.rows.length > maxRows!
        ? tableData.rows.take(maxRows!).toList()
        : tableData.rows;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table info
            Row(
              children: [
                Icon(
                  Icons.table_chart,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Table (${tableData.rows.length}×${tableData.rows.first.length})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Table content
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                border: TableBorder.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
                columns: List.generate(
                  maxColumns != null && tableData.rows.first.length > maxColumns!
                      ? maxColumns!
                      : tableData.rows.first.length,
                  (index) => DataColumn(
                    label: Text('Col ${index + 1}'),
                  ),
                ),
                rows: rows.map((row) {
                  final cells = maxColumns != null && row.length > maxColumns!
                      ? row.take(maxColumns!).toList()
                      : row;
                      
                  return DataRow(
                    cells: cells.map((cell) => DataCell(Text(cell))).toList(),
                  );
                }).toList(),
              ),
            ),
            
            // Truncation indicator
            if ((maxRows != null && tableData.rows.length > maxRows!) ||
                (maxColumns != null && tableData.rows.first.length > maxColumns!))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
