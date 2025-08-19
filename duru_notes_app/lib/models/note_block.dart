import 'package:flutter/foundation.dart';

/// Defines the type of a note block. A block represents a single unit of
/// content in the note editor, such as a paragraph, heading, todo item,
/// quote, code block or table. This enum allows the editor to render and
/// serialize blocks appropriately.
enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  todo,
  quote,
  code,
  table,
}

/// Base class for a note block. Each block has a [type] and associated
/// [data]. The data field is typed as `dynamic` so that different block
/// types can store whatever structured data they require. For example,
/// a paragraph or heading stores a simple `String`, whereas a todo block
/// stores a [TodoBlockData] object and a table block stores a
/// [TableBlockData].
@immutable
class NoteBlock {
  const NoteBlock({required this.type, required this.data});

  final NoteBlockType type;
  final dynamic data;

  NoteBlock copyWith({NoteBlockType? type, dynamic data}) {
    return NoteBlock(
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }
}

/// Data model for todo blocks. A todo block consists of a boolean to track
/// whether the item is checked and a string containing the task text.
@immutable
class TodoBlockData {
  const TodoBlockData({required this.text, required this.checked});

  final String text;
  final bool checked;

  TodoBlockData copyWith({String? text, bool? checked}) {
    return TodoBlockData(
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }
}

/// Data model for code blocks. Includes the code text and an optional
/// language identifier. Syntax highlighting can be implemented later based
/// on this language string.
@immutable
class CodeBlockData {
  const CodeBlockData({required this.code, this.language});

  final String code;
  final String? language;

  CodeBlockData copyWith({String? code, String? language}) {
    return CodeBlockData(
      code: code ?? this.code,
      language: language ?? this.language,
    );
  }
}

/// Data model for table blocks. A table is represented as a list of rows,
/// where each row is a list of cell strings. All rows should have the same
/// length. Editing of tables is handled in the UI layer.
@immutable
class TableBlockData {
  const TableBlockData({required this.rows});

  final List<List<String>> rows;

  TableBlockData copyWith({List<List<String>>? rows}) {
    return TableBlockData(rows: rows ?? this.rows);
  }
}
