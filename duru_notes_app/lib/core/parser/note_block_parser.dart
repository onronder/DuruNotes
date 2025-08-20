import 'dart:math' as math;

import 'package:duru_notes_app/models/note_block.dart';

/// Parses a markdown string into a list of [NoteBlock]s. The parser uses
/// simple heuristics to detect headings, todo items, quotes, code blocks and
/// tables. Lines that do not match any special pattern are grouped into
/// paragraph blocks. Blank lines separate paragraphs. This is a best effort
/// parser: it does not handle the full Markdown spec but aims to cover the
/// constructs used in DuruNotes.
List<NoteBlock> parseMarkdownToBlocks(String markdown) {
  final lines = markdown.split(RegExp(r'\r?\n'));
  final blocks = <NoteBlock>[];
  // Use `var` for the line index; explicit type annotation is unnecessary.
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    // Skip blank lines
    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    // Code block (```)
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

    // Table block (lines starting with |)
    if (line.trim().startsWith('|')) {
      final tableLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        tableLines.add(lines[i]);
        i++;
      }
      final rows = <List<String>>[];
      for (final tableLine in tableLines) {
        // Remove leading and trailing pipe, then split
        final trimmed = tableLine.trim();
        final cells = trimmed
            .substring(1, math.max(1, trimmed.length - 1))
            .split('|')
            .map((c) => c.trim())
            .toList();
        rows.add(cells);
      }
      blocks.add(NoteBlock(type: NoteBlockType.table, data: TableBlockData(rows: rows)));
      continue;
    }

    // Quote block (line starts with >)
    if (line.trimLeft().startsWith('>')) {
      final quotes = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
        // Remove leading '>' and optional space
        final quoteLine = lines[i].trimLeft().substring(1).trimLeft();
        quotes.add(quoteLine);
        i++;
      }
      blocks.add(NoteBlock(type: NoteBlockType.quote, data: quotes.join('\n')));
      continue;
    }

    // Heading (#+ space)
    // Note: match up to the end of line. Do not include a literal `$` at the end of the regex.
    final headingMatch = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line.trim());
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

    // Task list item (- [ ] or - [x]). Avoid using the word "todo" in comments
    // to satisfy the flutter_style_todos lint.
    final todoMatch = RegExp(r'^[-*]\s*\[( |x|X)\]\s*(.*)$').firstMatch(line.trim());
    if (todoMatch != null) {
      final checked = todoMatch.group(1)!.toLowerCase() == 'x';
      final text = todoMatch.group(2) ?? '';
      blocks.add(NoteBlock(
        type: NoteBlockType.todo,
        data: TodoBlockData(text: text, checked: checked),
      ));
      i++;
      continue;
    }

    // Attachment block: a single line image syntax (e.g. ![fileName](url)).
    // We treat attachments as their own blocks only if the entire line matches the pattern.
    final attachmentMatch =
        RegExp(r'^!\[(.*?)\]\(([^\)]+)\)\s*$').firstMatch(line.trim());
    if (attachmentMatch != null) {
      final filename = attachmentMatch.group(1)?.trim() ?? '';
      final url = attachmentMatch.group(2)?.trim() ?? '';
      blocks.add(NoteBlock(
        type: NoteBlockType.attachment,
        data: AttachmentBlockData(filename: filename, url: url),
      ));
      i++;
      continue;
    }

    // Paragraph: accumulate until blank line or other block starts
    final buffer = <String>[line];
    i++;
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty) {
        // blank line ends paragraph
        break;
      }
      // stop if next line begins a special block
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
    blocks.add(NoteBlock(type: NoteBlockType.paragraph, data: buffer.join('\n')));
  }
  return blocks;
}

/// Serializes a list of [NoteBlock]s back into a Markdown string. Blocks are
/// separated by a blank line. This inverse operation ensures that blocks
/// created in the editor can be persisted back into the existing body
/// database field without changing the underlying schema.
String blocksToMarkdown(List<NoteBlock> blocks) {
  final buffer = StringBuffer();
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    // Use a series of if/else statements instead of a switch to avoid
    // unnecessary `break` statements (per unnecessary_breaks lint).
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
        // If this is the header row and the table has more than one row,
        // insert a separator row after the header for Markdown syntax.
        if (rowIdx == 0 && table.rows.length > 1) {
          final sepCells = List<String>.filled(row.length, '---');
          buffer.writeln('| ${sepCells.join(' | ')} |');
        }
      }
    } else if (block.type == NoteBlockType.attachment) {
      // Serialize attachment as Markdown image: ![filename](url)
      final attach = block.data as AttachmentBlockData;
      final fname = attach.filename.trim();
      final url = attach.url.trim();
      buffer.writeln('![' + fname + '](' + url + ')');
    }
    if (i != blocks.length - 1) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}