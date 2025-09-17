import 'package:duru_notes/models/note_block.dart';

/// Parses markdown text into a list of note blocks
List<NoteBlock> parseMarkdownToBlocks(String markdown) {
  if (markdown.trim().isEmpty) {
    return [const NoteBlock(type: NoteBlockType.paragraph, data: '')];
  }

  final lines = markdown.split('\n');
  final blocks = <NoteBlock>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Skip empty lines
    if (line.trim().isEmpty) {
      continue;
    }

    // Parse headings
    if (line.startsWith('#')) {
      final level = line.indexOf(' ');
      if (level > 0 && level <= 3) {
        final text = line.substring(level + 1).trim();
        final type = level == 1
            ? NoteBlockType.heading1
            : level == 2
            ? NoteBlockType.heading2
            : NoteBlockType.heading3;
        blocks.add(NoteBlock(type: type, data: text));
        continue;
      }
    }

    // Parse quotes
    if (line.startsWith('> ')) {
      final text = line.substring(2).trim();
      blocks.add(NoteBlock(type: NoteBlockType.quote, data: text));
      continue;
    }

    // Parse code blocks
    if (line.startsWith('```')) {
      final language = line.substring(3).trim();
      final codeLines = <String>[];
      i++; // Move to next line

      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }

      final code = codeLines.join('\n');
      // For simplicity, store code as text with language prefix
      final codeData = language.isEmpty ? code : '$language\n$code';
      blocks.add(NoteBlock(type: NoteBlockType.code, data: codeData));
      continue;
    }

    // Parse todo items
    if (line.trim().startsWith('- [ ]') || line.trim().startsWith('- [x]')) {
      final isCompleted = line.trim().startsWith('- [x]');
      final text = line.trim().substring(5).trim();
      // Store todo as "completed:text" or "incomplete:text"
      final todoData = '${isCompleted ? 'completed' : 'incomplete'}:$text';
      blocks.add(NoteBlock(type: NoteBlockType.todo, data: todoData));
      continue;
    }

    // Parse bullet lists
    if (line.trim().startsWith('- ')) {
      final text = line.trim().substring(2).trim();
      blocks.add(NoteBlock(type: NoteBlockType.bulletList, data: text));
      continue;
    }

    // Parse numbered lists
    final numberedMatch = RegExp(r'^\s*\d+\.\s+(.*)').firstMatch(line.trim());
    if (numberedMatch != null) {
      final text = numberedMatch.group(1)!;
      blocks.add(NoteBlock(type: NoteBlockType.numberedList, data: text));
      continue;
    }

    // Default to paragraph
    blocks.add(NoteBlock(type: NoteBlockType.paragraph, data: line.trim()));
  }

  return blocks.isEmpty
      ? [const NoteBlock(type: NoteBlockType.paragraph, data: '')]
      : blocks;
}

/// Converts a list of note blocks back to markdown
String blocksToMarkdown(List<NoteBlock> blocks) {
  final buffer = StringBuffer();

  for (final block in blocks) {
    switch (block.type) {
      case NoteBlockType.paragraph:
        buffer.writeln(block.data);

      case NoteBlockType.heading1:
        buffer.writeln('# ${block.data}');

      case NoteBlockType.heading2:
        buffer.writeln('## ${block.data}');

      case NoteBlockType.heading3:
        buffer.writeln('### ${block.data}');

      case NoteBlockType.quote:
        buffer.writeln('> ${block.data}');

      case NoteBlockType.code:
        // Parse language from data if it exists
        final parts = block.data.split('\n');
        if (parts.length > 1 && !parts[0].contains(' ')) {
          // First line is likely the language
          final language = parts[0];
          final code = parts.skip(1).join('\n');
          buffer.writeln('```$language');
          buffer.writeln(code);
        } else {
          buffer.writeln('```');
          buffer.writeln(block.data);
        }
        buffer.writeln('```');

      case NoteBlockType.todo:
        // Parse todo from "completed:text" or "incomplete:text" format
        final parts = block.data.split(':');
        if (parts.length >= 2) {
          final isCompleted = parts[0] == 'completed';
          final text = parts.skip(1).join(':');
          final checkbox = isCompleted ? '[x]' : '[ ]';
          buffer.writeln('- $checkbox $text');
        } else {
          buffer.writeln('- [ ] ${block.data}');
        }

      case NoteBlockType.bulletList:
        buffer.writeln('- ${block.data}');

      case NoteBlockType.numberedList:
        buffer.writeln('1. ${block.data}');

      case NoteBlockType.table:
        // For simplified table, just output the data as is
        buffer.writeln(block.data);

      case NoteBlockType.attachment:
        // For simplified attachment, just output the data as is
        buffer.writeln('[Attachment: ${block.data}]');
    }

    // Add spacing between blocks
    if (block != blocks.last) {
      buffer.writeln();
    }
  }

  return buffer.toString().trim();
}

/// Helper function to create a paragraph block
NoteBlock createParagraphBlock(String text) {
  return NoteBlock(type: NoteBlockType.paragraph, data: text);
}

/// Helper function to create a heading block
NoteBlock createHeadingBlock(int level, String text) {
  final type = level == 1
      ? NoteBlockType.heading1
      : level == 2
      ? NoteBlockType.heading2
      : NoteBlockType.heading3;
  return NoteBlock(type: type, data: text);
}

/// Helper function to create a todo block
NoteBlock createTodoBlock(String text, {bool isCompleted = false}) {
  final todoData = '${isCompleted ? 'completed' : 'incomplete'}:$text';
  return NoteBlock(type: NoteBlockType.todo, data: todoData);
}

/// Helper function to create a code block
NoteBlock createCodeBlock(String code, {String? language}) {
  final codeData = language != null ? '$language\n$code' : code;
  return NoteBlock(type: NoteBlockType.code, data: codeData);
}
