import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_block.freezed.dart';
part 'note_block.g.dart';

/// Represents a single block within a note with full validation and error handling
@freezed
class NoteBlock with _$NoteBlock {
  const factory NoteBlock({
    required String id,
    required NoteBlockType type,
    required String content,
    @Default({}) Map<String, dynamic> properties,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _NoteBlock;

  const NoteBlock._();

  factory NoteBlock.fromJson(Map<String, Object?> json) => _$NoteBlockFromJson(json);

  /// Create a new paragraph block with validation
  factory NoteBlock.paragraph({
    required String content,
    String? id,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return NoteBlock(
      id: id ?? _generateUniqueId(),
      type: NoteBlockType.paragraph,
      content: content.trim(),
      properties: const {},
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Create a new heading block with level validation
  factory NoteBlock.heading({
    required String content,
    required int level,
    String? id,
    DateTime? createdAt,
  }) {
    if (level < 1 || level > 6) {
      throw ArgumentError('Heading level must be between 1 and 6, got: $level');
    }
    
    final now = DateTime.now();
    return NoteBlock(
      id: id ?? _generateUniqueId(),
      type: NoteBlockType.heading,
      content: content.trim(),
      properties: {'level': level},
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Create a new todo block with checked state
  factory NoteBlock.todo({
    required String content,
    bool checked = false,
    String? id,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return NoteBlock(
      id: id ?? _generateUniqueId(),
      type: NoteBlockType.todo,
      content: content.trim(),
      properties: {'checked': checked},
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Create a new code block with language
  factory NoteBlock.code({
    required String content,
    String language = 'text',
    String? id,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return NoteBlock(
      id: id ?? _generateUniqueId(),
      type: NoteBlockType.code,
      content: content,
      properties: {'language': language.trim().toLowerCase()},
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Validate block content based on type
  bool get isValid {
    try {
      _validateContent();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the heading level (1-6) for heading blocks
  int? get headingLevel {
    if (type != NoteBlockType.heading) return null;
    final level = properties['level'];
    return level is int && level >= 1 && level <= 6 ? level : null;
  }

  /// Get checked state for todo blocks
  bool get isChecked {
    if (type != NoteBlockType.todo) return false;
    return properties['checked'] == true;
  }

  /// Get code language for code blocks
  String get codeLanguage {
    if (type != NoteBlockType.code) return '';
    return properties['language']?.toString() ?? 'text';
  }

  /// Update the block content with validation
  NoteBlock updateContent(String newContent) {
    final trimmedContent = newContent.trim();
    
    // Validate content length
    if (trimmedContent.length > _maxContentLength) {
      throw ArgumentError(
        'Content too long: ${trimmedContent.length} characters. '
        'Maximum allowed: $_maxContentLength characters.',
      );
    }

    return copyWith(
      content: trimmedContent,
      updatedAt: DateTime.now(),
    );
  }

  /// Update todo checked state
  NoteBlock updateTodoState(bool checked) {
    if (type != NoteBlockType.todo) {
      throw StateError('Cannot update todo state on non-todo block');
    }

    return copyWith(
      properties: {...properties, 'checked': checked},
      updatedAt: DateTime.now(),
    );
  }

  /// Update heading level with validation
  NoteBlock updateHeadingLevel(int level) {
    if (type != NoteBlockType.heading) {
      throw StateError('Cannot update heading level on non-heading block');
    }
    
    if (level < 1 || level > 6) {
      throw ArgumentError('Heading level must be between 1 and 6, got: $level');
    }

    return copyWith(
      properties: {...properties, 'level': level},
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to a plain text representation
  String toPlainText() {
    switch (type) {
      case NoteBlockType.heading:
        final level = headingLevel ?? 1;
        return '${'#' * level} $content';
      case NoteBlockType.todo:
        final checkbox = isChecked ? '[x]' : '[ ]';
        return '- $checkbox $content';
      case NoteBlockType.bulletList:
        return '- $content';
      case NoteBlockType.numberedList:
        return '1. $content';
      case NoteBlockType.quote:
        return '> $content';
      case NoteBlockType.code:
        return '```$codeLanguage\n$content\n```';
      case NoteBlockType.table:
      case NoteBlockType.attachment:
      case NoteBlockType.paragraph:
        return content;
    }
  }

  /// Validate content based on block type
  void _validateContent() {
    // Check content length
    if (content.length > _maxContentLength) {
      throw ArgumentError(
        'Content exceeds maximum length of $_maxContentLength characters'
      );
    }

    // Type-specific validation
    switch (type) {
      case NoteBlockType.heading:
        final level = properties['level'];
        if (level is! int || level < 1 || level > 6) {
          throw ArgumentError('Invalid heading level: $level');
        }
        break;
      case NoteBlockType.todo:
        final checked = properties['checked'];
        if (checked is! bool) {
          throw ArgumentError('Todo checked property must be boolean');
        }
        break;
      case NoteBlockType.code:
        final language = properties['language'];
        if (language is! String) {
          throw ArgumentError('Code language must be string');
        }
        break;
      case NoteBlockType.table:
        if (content.isEmpty || !content.contains('|')) {
          throw ArgumentError('Table block must contain pipe-separated content');
        }
        break;
      case NoteBlockType.attachment:
        if (content.isEmpty) {
          throw ArgumentError('Attachment block must have content');
        }
        break;
      case NoteBlockType.paragraph:
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
      case NoteBlockType.quote:
        // No additional validation required
        break;
    }
  }

  static String _generateUniqueId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
  }

  static int _counter = 0;
  static const int _maxContentLength = 100000; // 100KB text limit
}

/// Types of blocks that can be used in a note
enum NoteBlockType {
  @JsonValue('paragraph')
  paragraph,
  
  @JsonValue('heading')
  heading,
  
  @JsonValue('bullet_list')
  bulletList,
  
  @JsonValue('numbered_list')
  numberedList,
  
  @JsonValue('todo')
  todo,
  
  @JsonValue('quote')
  quote,
  
  @JsonValue('code')
  code,
  
  @JsonValue('table')
  table,
  
  @JsonValue('attachment')
  attachment,
}

/// Extension for NoteBlockType utilities
extension NoteBlockTypeExtension on NoteBlockType {
  /// Human-readable name for the block type
  String get displayName {
    switch (this) {
      case NoteBlockType.paragraph:
        return 'Paragraph';
      case NoteBlockType.heading:
        return 'Heading';
      case NoteBlockType.bulletList:
        return 'Bullet List';
      case NoteBlockType.numberedList:
        return 'Numbered List';
      case NoteBlockType.todo:
        return 'Todo';
      case NoteBlockType.quote:
        return 'Quote';
      case NoteBlockType.code:
        return 'Code';
      case NoteBlockType.table:
        return 'Table';
      case NoteBlockType.attachment:
        return 'Attachment';
    }
  }

  /// Whether this block type supports rich text formatting
  bool get supportsRichText {
    switch (this) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading:
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
      case NoteBlockType.todo:
      case NoteBlockType.quote:
        return true;
      case NoteBlockType.code:
      case NoteBlockType.table:
      case NoteBlockType.attachment:
        return false;
    }
  }

  /// Whether this block type is a list type
  bool get isList {
    switch (this) {
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
      case NoteBlockType.todo:
        return true;
      case NoteBlockType.paragraph:
      case NoteBlockType.heading:
      case NoteBlockType.quote:
      case NoteBlockType.code:
      case NoteBlockType.table:
      case NoteBlockType.attachment:
        return false;
    }
  }
}