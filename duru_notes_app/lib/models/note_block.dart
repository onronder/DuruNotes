/// Types of note blocks supported in the editor
enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  quote,
  code,
  table,
  todo,
  attachment,
}

/// Base class for all note blocks
class NoteBlock {
  const NoteBlock({
    required this.type,
    required this.data,
    this.id,
  });

  final NoteBlockType type;
  final String data; // Simplified to always be String
  final String? id;

  /// Creates a copy of this block with the given fields replaced
  NoteBlock copyWith({
    NoteBlockType? type,
    String? data,
    String? id,
  }) {
    return NoteBlock(
      type: type ?? this.type,
      data: data ?? this.data,
      id: id ?? this.id,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteBlock &&
        other.type == type &&
        other.data == data &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, data, id);
}

/// Data classes for complex block types
class CodeBlockData {
  const CodeBlockData({
    required this.code,
    this.language,
  });

  final String code;
  final String? language;

  CodeBlockData copyWith({
    String? code,
    String? language,
  }) {
    return CodeBlockData(
      code: code ?? this.code,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeBlockData &&
        other.code == code &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(code, language);
}

/// Table block data class
class TableBlockData {
  const TableBlockData({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  TableBlockData copyWith({
    List<String>? headers,
    List<List<String>>? rows,
  }) {
    return TableBlockData(
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TableBlockData &&
        _listEquals(other.headers, headers) &&
        _listOfListsEquals(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(headers, rows);

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _listOfListsEquals(List<List<String>>? a, List<List<String>>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_listEquals(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Todo block data class
class TodoBlockData {
  const TodoBlockData({
    required this.text,
    required this.isCompleted,
  });

  final String text;
  final bool isCompleted;

  TodoBlockData copyWith({
    String? text,
    bool? isCompleted,
  }) {
    return TodoBlockData(
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoBlockData &&
        other.text == text &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(text, isCompleted);
}

/// Attachment block data class
class AttachmentBlockData {
  const AttachmentBlockData({
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.url,
    this.localPath,
    this.thumbnailUrl,
    this.description,
  });

  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? url;
  final String? localPath;
  final String? thumbnailUrl;
  final String? description;

  AttachmentBlockData copyWith({
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? url,
    String? localPath,
    String? thumbnailUrl,
    String? description,
  }) {
    return AttachmentBlockData(
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentBlockData &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.mimeType == mimeType &&
        other.url == url &&
        other.localPath == localPath &&
        other.thumbnailUrl == thumbnailUrl &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(
        fileName,
        fileSize,
        mimeType,
        url,
        localPath,
        thumbnailUrl,
        description,
      );
}