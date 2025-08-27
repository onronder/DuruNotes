import 'package:duru_notes_app/models/note_block.dart';

/// Production-grade parser for converting Markdown content to NoteBlock objects
/// with comprehensive validation and error handling
class NoteBlockParser {
  // Configuration constants
  static const int _maxBlockSize = 50000; // 50KB per block
  static const int _maxTableColumns = 20;
  static const int _maxTableRows = 1000;
  static const int _maxCodeBlockLines = 2000;

  /// Convert Markdown content to a list of validated NoteBlock objects
  List<NoteBlock> parseMarkdownToBlocks(String markdown) {
    if (markdown.trim().isEmpty) {
      return [NoteBlock.paragraph(content: '')];
    }

    try {
      return _parseContent(markdown);
    } catch (e) {
      // Fallback: create a single paragraph if parsing fails
      return [NoteBlock.paragraph(content: markdown)];
    }
  }

  /// Main parsing logic with state management
  List<NoteBlock> _parseContent(String markdown) {
    final blocks = <NoteBlock>[];
    final lines = markdown.split('\n');
    
    String? currentBlockContent;
    NoteBlockType? currentBlockType;
    Map<String, dynamic>? currentProperties;
    bool inCodeBlock = false;
    String? codeLanguage;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      // Handle code blocks specially
      if (trimmedLine.startsWith('```')) {
        if (inCodeBlock) {
          // End code block
          if (currentBlockContent != null) {
            blocks.add(_createValidatedBlock(
              NoteBlockType.code, 
              currentBlockContent.trim(), 
              {'language': codeLanguage ?? 'text'},
            ));
          }
          _resetCurrentBlock();
          currentBlockContent = null;
          currentBlockType = null;
          currentProperties = null;
          inCodeBlock = false;
          codeLanguage = null;
        } else {
          // Start code block
          if (currentBlockContent != null && currentBlockContent.trim().isNotEmpty) {
            blocks.add(_createValidatedBlock(
              currentBlockType!, 
              currentBlockContent.trim(), 
              currentProperties ?? {},
            ));
          }
          
          codeLanguage = trimmedLine.length > 3 ? trimmedLine.substring(3).trim() : 'text';
          inCodeBlock = true;
          currentBlockContent = '';
          currentBlockType = NoteBlockType.code;
          currentProperties = {'language': codeLanguage};
        }
        continue;
      }
      
      // Inside code block - add line as-is
      if (inCodeBlock) {
        currentBlockContent = currentBlockContent == null 
            ? line 
            : '$currentBlockContent\n$line';
        continue;
      }
      
      // Detect block type for non-code content
      final blockInfo = _detectBlockType(line, trimmedLine);
      
      // Check if we need to finish current block
      if (currentBlockType != null && 
          (blockInfo.type != currentBlockType || 
           _shouldSeparateBlock(blockInfo.type) ||
           trimmedLine.isEmpty)) {
        
        if (currentBlockContent != null && currentBlockContent.trim().isNotEmpty) {
          blocks.add(_createValidatedBlock(
            currentBlockType, 
            currentBlockContent.trim(), 
            currentProperties ?? {},
          ));
        }
        _resetCurrentBlock();
        currentBlockContent = null;
        currentBlockType = null;
        currentProperties = null;
      }
      
      // Skip empty lines between blocks
      if (trimmedLine.isEmpty && currentBlockType == null) {
        continue;
      }
      
      // Start or continue current block
      if (blockInfo.type != NoteBlockType.paragraph || trimmedLine.isNotEmpty) {
        currentBlockType ??= blockInfo.type;
        currentProperties ??= blockInfo.properties;
        
        // For list items, each line is a separate block
        if (blockInfo.type.isList && currentBlockContent != null) {
          blocks.add(_createValidatedBlock(
            currentBlockType, 
            currentBlockContent.trim(), 
            currentProperties,
          ));
          currentBlockContent = blockInfo.content;
        } else {
          currentBlockContent = currentBlockContent == null 
              ? blockInfo.content 
              : '$currentBlockContent\n${blockInfo.content}';
        }
      }
    }
    
    // Finalize the last block
    if (currentBlockType != null && 
        currentBlockContent != null && 
        currentBlockContent.trim().isNotEmpty) {
      blocks.add(_createValidatedBlock(
        currentBlockType, 
        currentBlockContent.trim(), 
        currentProperties ?? {},
      ));
    }
    
    // Ensure we have at least one block
    if (blocks.isEmpty) {
      blocks.add(NoteBlock.paragraph(content: ''));
    }
    
    return blocks;
  }

  /// Detect block type from a line with comprehensive pattern matching
  BlockInfo _detectBlockType(String line, String trimmedLine) {
    // Headers (H1-H6)
    if (trimmedLine.startsWith('#')) {
      final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmedLine);
      if (match != null) {
        final level = match.group(1)!.length;
        final content = match.group(2)!.trim();
        return BlockInfo(
          type: NoteBlockType.heading,
          content: content,
          properties: {'level': level.clamp(1, 6)},
        );
      }
    }
    
    // Todo items with various checkbox formats
    final todoPatterns = [
      RegExp(r'^[-*+]\s+\[\s*\]\s+(.*)$'), // Unchecked
      RegExp(r'^[-*+]\s+\[x\]\s+(.*)$', caseSensitive: false), // Checked
      RegExp(r'^[-*+]\s+\[X\]\s+(.*)$'), // Checked (uppercase)
    ];
    
    for (int i = 0; i < todoPatterns.length; i++) {
      final match = todoPatterns[i].firstMatch(trimmedLine);
      if (match != null) {
        return BlockInfo(
          type: NoteBlockType.todo,
          content: match.group(1)!.trim(),
          properties: {'checked': i > 0}, // First pattern is unchecked
        );
      }
    }
    
    // Bullet lists
    final bulletMatch = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmedLine);
    if (bulletMatch != null) {
      return BlockInfo(
        type: NoteBlockType.bulletList,
        content: bulletMatch.group(1)!.trim(),
        properties: {},
      );
    }
    
    // Numbered lists
    final numberedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmedLine);
    if (numberedMatch != null) {
      final number = int.tryParse(numberedMatch.group(1)!) ?? 1;
      return BlockInfo(
        type: NoteBlockType.numberedList,
        content: numberedMatch.group(2)!.trim(),
        properties: {'number': number},
      );
    }
    
    // Quotes
    if (trimmedLine.startsWith('> ')) {
      return BlockInfo(
        type: NoteBlockType.quote,
        content: trimmedLine.substring(2).trim(),
        properties: {},
      );
    }
    
    // Tables (simple detection)
    if (trimmedLine.contains('|') && trimmedLine.split('|').length >= 3) {
      return BlockInfo(
        type: NoteBlockType.table,
        content: trimmedLine,
        properties: {},
      );
    }
    
    // Default to paragraph
    return BlockInfo(
      type: NoteBlockType.paragraph,
      content: line,
      properties: {},
    );
  }

  /// Check if blocks of the same type should be separated
  bool _shouldSeparateBlock(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.heading:
      case NoteBlockType.code:
      case NoteBlockType.table:
        return true;
      case NoteBlockType.todo:
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
        return true; // Each list item is a separate block
      case NoteBlockType.paragraph:
      case NoteBlockType.quote:
      case NoteBlockType.attachment:
        return false;
    }
  }

  /// Create a validated NoteBlock with error handling
  NoteBlock _createValidatedBlock(
    NoteBlockType type, 
    String content, 
    Map<String, dynamic> properties,
  ) {
    // Validate content size
    if (content.length > _maxBlockSize) {
      content = '${content.substring(0, _maxBlockSize - 3)}...';
    }
    
    // Type-specific validation and processing
    switch (type) {
      case NoteBlockType.heading:
        final level = properties['level'] as int? ?? 1;
        return NoteBlock.heading(
          content: content,
          level: level.clamp(1, 6),
        );
        
      case NoteBlockType.todo:
        final checked = properties['checked'] as bool? ?? false;
        return NoteBlock.todo(
          content: content,
          checked: checked,
        );
        
      case NoteBlockType.code:
        final language = properties['language'] as String? ?? 'text';
        
        // Validate code block size
        final lines = content.split('\n');
        if (lines.length > _maxCodeBlockLines) {
          content = '${lines.take(_maxCodeBlockLines).join('\n')}\n... (truncated)';
        }
        
        return NoteBlock.code(
          content: content,
          language: language,
        );
        
      case NoteBlockType.table:
        // Basic table validation
        final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
        if (lines.length > _maxTableRows) {
          content = '${lines.take(_maxTableRows).join('\n')}\n... (truncated)';
        }
        
        // Check column count
        for (final line in lines.take(10)) { // Check first 10 rows
          final columns = line.split('|').length;
          if (columns > _maxTableColumns) {
            // Truncate columns if too many
            final truncatedColumns = line.split('|').take(_maxTableColumns).join('|');
            content = content.replaceFirst(line, '$truncatedColumns|...');
          }
        }
        
        return NoteBlock(
          id: NoteBlock._generateUniqueId(),
          type: type,
          content: content,
          properties: properties,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
      case NoteBlockType.quote:
      case NoteBlockType.paragraph:
      case NoteBlockType.attachment:
        return NoteBlock(
          id: NoteBlock._generateUniqueId(),
          type: type,
          content: content,
          properties: properties,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    }
  }

  /// Reset current block state
  void _resetCurrentBlock() {
    // This method can be used for cleanup if needed
  }

  /// Generate a unique ID for blocks
  static String _generateUniqueId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
  }

  static int _counter = 0;
}

/// Information about a detected block
class BlockInfo {
  final NoteBlockType type;
  final String content;
  final Map<String, dynamic> properties;

  const BlockInfo({
    required this.type,
    required this.content,
    required this.properties,
  });
}

/// Enhanced markdown processing utilities
class MarkdownProcessor {
  /// Clean markdown content from potential security issues
  static String sanitizeMarkdown(String content) {
    // Remove potentially dangerous HTML tags
    content = content.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    content = content.replaceAll(RegExp(r'<iframe[^>]*>.*?</iframe>', dotAll: true), '');
    content = content.replaceAll(RegExp(r'<object[^>]*>.*?</object>', dotAll: true), '');
    content = content.replaceAll(RegExp(r'<embed[^>]*>', dotAll: true), '');
    
    // Limit line length to prevent display issues
    final lines = content.split('\n');
    final processedLines = lines.map((line) {
      if (line.length > 10000) {
        return '${line.substring(0, 9997)}...';
      }
      return line;
    }).toList();
    
    return processedLines.join('\n');
  }

  /// Extract metadata from markdown frontmatter
  static Map<String, dynamic> extractFrontmatter(String content) {
    final metadata = <String, dynamic>{};
    
    if (!content.startsWith('---\n')) {
      return metadata;
    }
    
    final endIndex = content.indexOf('\n---\n', 4);
    if (endIndex == -1) {
      return metadata;
    }
    
    final frontmatter = content.substring(4, endIndex);
    final lines = frontmatter.split('\n');
    
    for (final line in lines) {
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        
        // Parse basic YAML values
        if (value.startsWith('[') && value.endsWith(']')) {
          // Simple array parsing
          final arrayContent = value.substring(1, value.length - 1);
          metadata[key] = arrayContent.split(',').map((s) => s.trim()).toList();
        } else if (value.toLowerCase() == 'true') {
          metadata[key] = true;
        } else if (value.toLowerCase() == 'false') {
          metadata[key] = false;
        } else if (int.tryParse(value) != null) {
          metadata[key] = int.parse(value);
        } else if (double.tryParse(value) != null) {
          metadata[key] = double.parse(value);
        } else {
          // Remove quotes if present
          metadata[key] = value.replaceAll(RegExp(r'^["\'']|["\'']$'), '');
        }
      }
    }
    
    return metadata;
  }

  /// Convert inline markdown formatting to plain text
  static String stripMarkdownFormatting(String text) {
    // Remove bold and italic
    text = text.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*(.*?)\*'), r'$1');
    text = text.replaceAll(RegExp(r'__(.*?)__'), r'$1');
    text = text.replaceAll(RegExp(r'_(.*?)_'), r'$1');
    
    // Remove inline code
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
    
    // Remove links
    text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    
    // Remove images
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
    
    return text;
  }
}