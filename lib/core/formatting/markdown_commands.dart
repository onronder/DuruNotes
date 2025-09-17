import 'package:flutter/material.dart';

/// Base class for all Markdown formatting commands
abstract class MarkdownCommand {
  /// Execute the command on the given text controller
  void execute(TextEditingController controller);

  /// Undo the command (if supported)
  void undo(TextEditingController controller) {}

  /// Get the command name for analytics
  String get analyticsName;
}

/// Command execution result
class CommandResult {
  const CommandResult({
    required this.text,
    required this.selection,
    this.success = true,
    this.error,
  });
  final String text;
  final TextSelection selection;
  final bool success;
  final String? error;
}

/// Utilities for Markdown formatting
class MarkdownUtils {
  /// Check if text has a markdown wrapper
  static bool hasWrapper(
    String text,
    String startWrapper, [
    String? endWrapper,
  ]) {
    endWrapper ??= startWrapper;
    return text.startsWith(startWrapper) && text.endsWith(endWrapper);
  }

  /// Toggle markdown wrapper around text
  static String toggleWrapper(
    String text,
    String startWrapper, [
    String? endWrapper,
  ]) {
    endWrapper ??= startWrapper;

    if (hasWrapper(text, startWrapper, endWrapper)) {
      // Remove wrapper
      return text.substring(
        startWrapper.length,
        text.length - endWrapper.length,
      );
    } else {
      // Add wrapper
      return '$startWrapper$text$endWrapper';
    }
  }

  /// Get lines from selection
  static List<String> getLinesFromSelection(
    String text,
    TextSelection selection,
  ) {
    final beforeSelection = text.substring(0, selection.start);
    final inSelection = text.substring(selection.start, selection.end);
    final afterSelection = text.substring(selection.end);

    // Find line boundaries
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    var lineEnd = selection.end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final fullLines = text.substring(lineStart, lineEnd);
    return fullLines.split('\n');
  }

  /// Apply prefix to lines
  static String applyPrefixToLines(
    List<String> lines,
    String prefix, {
    bool toggle = false,
  }) {
    return lines
        .map((line) {
          if (toggle && line.startsWith(prefix)) {
            // Remove prefix
            return line.substring(prefix.length);
          } else if (!line.startsWith(prefix)) {
            // Add prefix
            return '$prefix$line';
          }
          return line;
        })
        .join('\n');
  }
}

/// Bold command implementation
class BoldCommand extends MarkdownCommand {
  @override
  String get analyticsName => 'bold';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Insert bold markers at cursor
      final newText =
          '${text.substring(0, selection.start)}****${text.substring(selection.end)}';
      final newPosition = selection.start + 2;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPosition),
      );
    } else {
      // Toggle bold on selection
      final selectedText = text.substring(selection.start, selection.end);
      final isMultiline = selectedText.contains('\n');

      if (isMultiline) {
        // For multiline, apply to each line
        final lines = selectedText.split('\n');
        final formattedLines = lines
            .map((line) {
              if (line.trim().isEmpty) return line;
              return MarkdownUtils.toggleWrapper(line, '**');
            })
            .join('\n');

        final newText = text.replaceRange(
          selection.start,
          selection.end,
          formattedLines,
        );
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + formattedLines.length,
          ),
        );
      } else {
        // Single line selection
        final toggled = MarkdownUtils.toggleWrapper(selectedText, '**');
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          toggled,
        );

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + toggled.length,
          ),
        );
      }
    }
  }
}

/// Italic command implementation
class ItalicCommand extends MarkdownCommand {
  @override
  String get analyticsName => 'italic';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Insert italic markers at cursor
      final newText =
          '${text.substring(0, selection.start)}__${text.substring(selection.end)}';
      final newPosition = selection.start + 1;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPosition),
      );
    } else {
      // Toggle italic on selection
      final selectedText = text.substring(selection.start, selection.end);
      final toggled = MarkdownUtils.toggleWrapper(selectedText, '_');
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        toggled,
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.start + toggled.length,
        ),
      );
    }
  }
}

/// Heading command with level cycling
class HeadingCommand extends MarkdownCommand {
  HeadingCommand({this.level = 2});
  final int level; // Default to H2

  @override
  String get analyticsName => 'heading_$level';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    // Get the current line
    final lines = MarkdownUtils.getLinesFromSelection(text, selection);
    if (lines.isEmpty) return;

    // Process each line
    final processedLines = lines.map((line) {
      // Remove existing heading markers
      final cleanLine = line.replaceFirst(RegExp(r'^#{1,6}\s*'), '');

      // Check if we should cycle or apply
      if (line.startsWith('#' * level + ' ')) {
        // Same level, cycle to next or remove
        if (level < 6) {
          return '${'#' * (level + 1)} $cleanLine';
        } else {
          return cleanLine; // Remove heading
        }
      } else {
        // Apply heading level
        return '${'#' * level} $cleanLine';
      }
    }).toList();

    // Find line boundaries
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    var lineEnd = selection.end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final newLines = processedLines.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newLines);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + newLines.length,
      ),
    );
  }
}

/// List command (bullet and numbered)
class ListCommand extends MarkdownCommand {
  ListCommand({required this.type});
  final ListType type;

  @override
  String get analyticsName =>
      type == ListType.bullet ? 'bullet_list' : 'numbered_list';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    final lines = MarkdownUtils.getLinesFromSelection(text, selection);
    if (lines.isEmpty) return;

    // Process each line
    final processedLines = <String>[];
    var number = 1;

    for (final line in lines) {
      if (line.trim().isEmpty) {
        processedLines.add(line);
        continue;
      }

      // Remove existing list markers
      final cleanLine = line
          .replaceFirst(RegExp(r'^[-*•]\s+'), '')
          .replaceFirst(RegExp(r'^\d+\.\s+'), '');

      String prefix;
      switch (type) {
        case ListType.bullet:
          prefix = '- ';
          break;
        case ListType.numbered:
          prefix = '${number++}. ';
          break;
        case ListType.checkbox:
          prefix = '- [ ] ';
          break;
      }

      // Check if we should toggle off
      final shouldRemove =
          (type == ListType.bullet && line.startsWith('- ')) ||
          (type == ListType.numbered && RegExp(r'^\d+\.\s').hasMatch(line)) ||
          (type == ListType.checkbox && line.startsWith('- [ ]'));

      if (shouldRemove) {
        processedLines.add(cleanLine);
      } else {
        processedLines.add('$prefix$cleanLine');
      }
    }

    // Replace in text
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    var lineEnd = selection.end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final newLines = processedLines.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newLines);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + newLines.length,
      ),
    );
  }
}

/// List types
enum ListType { bullet, numbered, checkbox }

/// Code command (inline and block)
class CodeCommand extends MarkdownCommand {
  CodeCommand({this.isBlock = false});
  final bool isBlock;

  @override
  String get analyticsName => isBlock ? 'code_block' : 'code_inline';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Insert code markers at cursor
      if (isBlock) {
        final newText =
            '${text.substring(0, selection.start)}\n```\n\n```\n${text.substring(selection.end)}';
        final newPosition = selection.start + 5; // Position after ```\n

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newPosition),
        );
      } else {
        final newText =
            '${text.substring(0, selection.start)}``${text.substring(selection.end)}';
        final newPosition = selection.start + 1;

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newPosition),
        );
      }
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final isMultiline = selectedText.contains('\n');

      if (isBlock || isMultiline) {
        // Use code block
        final hasBlock =
            selectedText.startsWith('```') && selectedText.endsWith('```');
        final formatted = hasBlock
            ? selectedText.substring(3, selectedText.length - 3).trim()
            : '```\n$selectedText\n```';

        final newText = text.replaceRange(
          selection.start,
          selection.end,
          formatted,
        );
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + formatted.length,
          ),
        );
      } else {
        // Inline code
        final toggled = MarkdownUtils.toggleWrapper(selectedText, '`');
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          toggled,
        );

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + toggled.length,
          ),
        );
      }
    }
  }
}

/// Quote command
class QuoteCommand extends MarkdownCommand {
  @override
  String get analyticsName => 'quote';

  @override
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    final lines = MarkdownUtils.getLinesFromSelection(text, selection);
    if (lines.isEmpty) return;

    // Toggle quote prefix
    final allQuoted = lines.every(
      (line) => line.startsWith('> ') || line.trim().isEmpty,
    );

    final processedLines = lines.map((line) {
      if (line.trim().isEmpty) return line;

      if (allQuoted) {
        // Remove quote
        return line.startsWith('> ') ? line.substring(2) : line;
      } else {
        // Add quote
        return line.startsWith('> ') ? line : '> $line';
      }
    }).toList();

    // Replace in text
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    var lineEnd = selection.end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final newLines = processedLines.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newLines);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + newLines.length,
      ),
    );
  }
}

/// Link command with dialog
class LinkCommand extends MarkdownCommand {
  LinkCommand({this.url, this.text});
  final String? url;
  final String? text;

  @override
  String get analyticsName => 'link';

  @override
  void execute(TextEditingController controller) {
    final textValue = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Insert link template at cursor
      final linkText = text ?? 'link text';
      final linkUrl = url ?? 'https://';
      final markdown = '[$linkText]($linkUrl)';

      final newText =
          '${textValue.substring(0, selection.start)}$markdown${textValue.substring(selection.end)}';

      // Position cursor to select the link text for easy editing
      final textStart = selection.start + 1;
      final textEnd = textStart + linkText.length;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: textStart, extentOffset: textEnd),
      );
    } else {
      // Wrap selection as link text
      final selectedText = textValue.substring(selection.start, selection.end);
      final linkUrl = url ?? 'https://';
      final markdown = '[$selectedText]($linkUrl)';

      final newText = textValue.replaceRange(
        selection.start,
        selection.end,
        markdown,
      );

      // Position cursor in URL for editing
      final urlStart = selection.start + selectedText.length + 3;
      final urlEnd = urlStart + linkUrl.length;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: urlStart, extentOffset: urlEnd),
      );
    }
  }
}
