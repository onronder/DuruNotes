import 'dart:math' as math;

import 'package:duru_notes_app/models/note_block.dart';

/// Parses a markdown string into a list of [NoteBlock]s. The parser uses
/// simple heuristics to detect headings, task items, quotes, code blocks,
/// tables and attachments. Lines that do not match any special pattern
/// are grouped into paragraph blocks. Blank lines separate paragraphs.
List<NoteBlock> parseMarkdownToBlocks(String markdown) {
  final lines = markdown.split(RegExp(r'\r?\n'));
  final blocks = <NoteBlock>[];
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    // Skip blank lines.
    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    // Code block (```).
    if (line.startsWith('```')) {
      final language = line.length > 3 ? line.substring(3).trim() : null;
      final buffer = <String>[];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        buffer.add(lines[i]);
        i++;
      }
      // Skip closing ```
      if (i < lines.length && lines[i].startsWith('```')) {
        i++;
      }
      blocks.add(
        NoteBlock(
          type: NoteBlockType.code,
          data: CodeBlockData(code: buffer.join('\n'), language: language),
        ),
      );
      continue;
    }

    // Table block (lines starting with |).
    if (line.trim().startsWith('|')) {
      final tableLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        tableLines.add(lines[i]);
        i++;
      }
      final rows = <List<String>>[];
      for (final tableLine in tableLines) {
        // Remove leading and trailing pipe, then split.
        final trimmed = tableLine.trim();
        final cells = trimmed
            .substring(1, math.max(1, trimmed.length - 1))
            .split('|')
            .map((c) => c.trim())
            .toList();
        rows.add(cells);
      }
      blocks.add(
        NoteBlock(
          type: NoteBlockType.table,
          data: TableBlockData(rows: rows),
        ),
      );
      continue;
    }

    // Quote block (line starts with >).
    if (line.trimLeft().startsWith('>')) {
      final quotes = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
        // Remove leading '>' and optional space.
        final quoteLine = lines[i].trimLeft().substring(1).trimLeft();
        quotes.add(quoteLine);
        i++;
      }
      blocks.add(
        NoteBlock(type: NoteBlockType.quote, data: quotes.join('\n')),
      );
      continue;
    }

    // Heading (#+ space).
    final headingMatch =
        RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line.trim());
    if (headingMatch != null) {
      final hashes = headingMatch.group(1)!;
      final text = headingMatch.group(2)!.trim();
      final level = hashes.length;
      final type = level == 1
          ? NoteBlockType.heading1
          : level == 2
              ? NoteBlockType.heading2
              : NoteBlockType.heading3;
      blocks.add(NoteBlock(type: type, data: text));
      i++;
      continue;
    }

    // Task list item (- [ ] or - [x]).
    final todoMatch =
        RegExp(r'^[-*]\s*\[( |x|X)\]\s*(.*)$').firstMatch(line.trim());
    if (todoMatch != null) {
      final checked = todoMatch.group(1)!.toLowerCase() == 'x';
      final text = todoMatch.group(2) ?? '';
      blocks.add(
        NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: text, checked: checked),
        ),
      );
      i++;
      continue;
    }

    // Attachment block: a single line in the form ![filename](url).
    final attachmentMatch =
        RegExp(r'^!\[(.*?)\]\(([^)]+)\)\s*$').firstMatch(line.trim());
    if (attachmentMatch != null) {
      final filename = attachmentMatch.group(1)?.trim() ?? '';
      final url = attachmentMatch.group(2)?.trim() ?? '';
      blocks.add(
        NoteBlock(
          type: NoteBlockType.attachment,
          data: AttachmentBlockData(filename: filename, url: url),
        ),
      );
      i++;
      continue;
    }

    // Paragraph: accumulate until blank line or another block begins.
    final buffer = <String>[line];
    i++;
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty) {
        break;
      }
      // Stop if next line begins a special block.
      final trimmed = l.trimLeft();
      if (trimmed.startsWith('```') ||
          trimmed.startsWith('|') ||
          trimmed.startsWith('>') ||
          RegExp(r'^(#{1,3})\s').hasMatch(trimmed) ||
          RegExp(r'^[-*]\s*\[( |x|X)\]').hasMatch(trimmed) ||
          RegExp(r'^!\[').hasMatch(trimmed)) {
        break;
      }
      buffer.add(l);
      i++;
    }
    blocks.add(
      NoteBlock(type: NoteBlockType.paragraph, data: buffer.join('\n')),
    );
  }

  return blocks;
}

/// Serializes a list of [NoteBlock]s back into a Markdown string. Blocks are
/// separated by a blank line.
String blocksToMarkdown(List<NoteBlock> blocks) {
  final buffer = StringBuffer();

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];

    // Use if/else chain (avoids unnecessary_breaks in a switch).
    if (block.type == NoteBlockType.paragraph) {
      buffer.writeln(block.data as String);
    } else if (block.type == NoteBlockType.heading1) {
      buffer.writeln('# ${(block.data as String).trim()}');
    } else if (block.type == NoteBlockType.heading2) {
      buffer.writeln('## ${(block.data as String).trim()}');
    } else if (block.type == NoteBlockType.heading3) {
      buffer.writeln('### ${(block.data as String).trim()}');
    } else if (block.type == NoteBlockType.todo) {
      final todo = block.data as TodoBlockData;
      final box = todo.checked ? '[x]' : '[ ]';
      buffer.writeln('- $box ${todo.text}');
    } else if (block.type == NoteBlockType.quote) {
      final text = block.data as String;
      for (final line in text.split('\n')) {
        buffer.writeln('> $line');
      }
    } else if (block.type == NoteBlockType.code) {
      final data = block.data as CodeBlockData;
      final lang = data.language;
      buffer.writeln('```${lang ?? ''}');
      buffer.writeln(data.code);
      buffer.writeln('```');
    } else if (block.type == NoteBlockType.table) {
      final table = block.data as TableBlockData;
      for (var rowIdx = 0; rowIdx < table.rows.length; rowIdx++) {
        final row = table.rows[rowIdx];
        buffer.writeln('| ${row.join(' | ')} |');
        // Insert a separator row after the header if needed.
        if (rowIdx == 0 && table.rows.length > 1) {
          final sepCells = List<String>.filled(row.length, '---');
          buffer.writeln('| ${sepCells.join(' | ')} |');
        }
      }
    } else if (block.type == NoteBlockType.attachment) {
      final attach = block.data as AttachmentBlockData;
      buffer.writeln('![${attach.filename}](${attach.url})');
    }

    if (i != blocks.length - 1) {
      buffer.writeln();
    }
  }

  return buffer.toString();
}
