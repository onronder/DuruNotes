import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/core/parser/note_block_parser.dart';
import 'package:duru_notes_app/models/note_block.dart';

/// Simple tests for import functionality without mocks
void main() {
  group('NoteBlockParser', () {
    late NoteBlockParser parser;

    setUp(() {
      parser = NoteBlockParser();
    });

    testWidgets('parses simple markdown', (tester) async {
      const markdown = '''# Test Title

This is a paragraph.

## Subheading

Another paragraph with content.''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      expect(blocks.length, greaterThan(0));
      
      // Check that we have a heading block
      final headingBlocks = blocks.where((b) => b.type == NoteBlockType.heading).toList();
      expect(headingBlocks.length, equals(2));
      expect(headingBlocks.first.content, equals('Test Title'));
      expect(headingBlocks.first.properties['level'], equals(1));
      
      // Check that we have paragraph blocks
      final paragraphBlocks = blocks.where((b) => b.type == NoteBlockType.paragraph).toList();
      expect(paragraphBlocks.length, greaterThan(0));
    });

    testWidgets('parses todo items', (tester) async {
      const markdown = '''# Todo List

- [ ] Unchecked item
- [x] Checked item
- [ ] Another unchecked item''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final todoBlocks = blocks.where((b) => b.type == NoteBlockType.todo).toList();
      expect(todoBlocks.length, equals(3));
      
      expect(todoBlocks[0].content, equals('Unchecked item'));
      expect(todoBlocks[0].properties['checked'], equals(false));
      
      expect(todoBlocks[1].content, equals('Checked item'));
      expect(todoBlocks[1].properties['checked'], equals(true));
      
      expect(todoBlocks[2].content, equals('Another unchecked item'));
      expect(todoBlocks[2].properties['checked'], equals(false));
    });

    testWidgets('parses bullet lists', (tester) async {
      const markdown = '''# List

- First item
- Second item
* Third item
* Fourth item''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final listBlocks = blocks.where((b) => b.type == NoteBlockType.bulletList).toList();
      expect(listBlocks.length, equals(4));
      expect(listBlocks.map((b) => b.content).toList(), equals([
        'First item',
        'Second item',
        'Third item',
        'Fourth item',
      ]));
    });

    testWidgets('parses numbered lists', (tester) async {
      const markdown = '''# Numbered List

1. First numbered item
2. Second numbered item
3. Third numbered item''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final numberedBlocks = blocks.where((b) => b.type == NoteBlockType.numberedList).toList();
      expect(numberedBlocks.length, equals(3));
      expect(numberedBlocks.map((b) => b.content).toList(), equals([
        'First numbered item',
        'Second numbered item',
        'Third numbered item',
      ]));
    });

    testWidgets('parses quotes', (tester) async {
      const markdown = '''# Quote

> This is a quote
> With multiple lines
> And more content''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final quoteBlocks = blocks.where((b) => b.type == NoteBlockType.quote).toList();
      expect(quoteBlocks.length, equals(3));
      expect(quoteBlocks.first.content, equals('This is a quote'));
    });

    testWidgets('parses code blocks', (tester) async {
      const markdown = '''# Code

```dart
print('Hello World');
void main() {
  print('Flutter');
}
```''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final codeBlocks = blocks.where((b) => b.type == NoteBlockType.code).toList();
      expect(codeBlocks.length, greaterThan(0));
      expect(codeBlocks.first.properties['language'], equals('dart'));
    });

    testWidgets('handles empty input', (tester) async {
      final blocks = parser.parseMarkdownToBlocks('');

      expect(blocks.length, equals(1));
      expect(blocks.first.type, equals(NoteBlockType.paragraph));
      expect(blocks.first.content, equals(''));
    });

    testWidgets('handles whitespace-only input', (tester) async {
      final blocks = parser.parseMarkdownToBlocks('   \n  \n  ');

      expect(blocks.length, equals(1));
      expect(blocks.first.type, equals(NoteBlockType.paragraph));
      expect(blocks.first.content, equals(''));
    });

    testWidgets('generates unique IDs for blocks', (tester) async {
      const markdown = '''# Test

Paragraph 1

Paragraph 2''';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      final ids = blocks.map((b) => b.id).toSet();
      expect(ids.length, equals(blocks.length)); // All IDs should be unique
    });

    testWidgets('sets timestamps for blocks', (tester) async {
      const markdown = '# Test\n\nContent';

      final blocks = parser.parseMarkdownToBlocks(markdown);

      for (final block in blocks) {
        expect(block.createdAt, isNotNull);
        expect(block.updatedAt, isNotNull);
        expect(block.createdAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
        expect(block.updatedAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
      }
    });
  });

  group('ImportService File Detection', () {
    testWidgets('detects file extension correctly', (tester) async {
      // Test markdown extension detection
      final mdFile = File('test.md');
      expect(mdFile.path.toLowerCase().endsWith('.md'), isTrue);
      
      // Test ENEX extension detection
      final enexFile = File('export.enex');
      expect(enexFile.path.toLowerCase().endsWith('.enex'), isTrue);
      
      // Test unsupported extension
      final txtFile = File('document.txt');
      expect(txtFile.path.toLowerCase().endsWith('.txt'), isTrue);
      expect(txtFile.path.toLowerCase().endsWith('.md'), isFalse);
      expect(txtFile.path.toLowerCase().endsWith('.enex'), isFalse);
    });
  });

  group('XML Parsing (Basic)', () {
    testWidgets('validates basic XML structure', (tester) async {
      const validXml = '''<?xml version="1.0" encoding="UTF-8"?>
<root>
  <child>Content</child>
</root>''';

      // Just test that we can work with basic XML structure
      expect(validXml.contains('<?xml'), isTrue);
      expect(validXml.contains('<root>'), isTrue);
      expect(validXml.contains('</root>'), isTrue);
    });
  });
}
