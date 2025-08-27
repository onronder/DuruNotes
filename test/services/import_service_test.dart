import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/services/import_service.dart';
import 'package:duru_notes_app/core/parser/note_block_parser.dart';
import 'package:duru_notes_app/models/note_block.dart';

@GenerateMocks([
  NotesRepository,
  NoteIndexer,
  AppLogger,
  AnalyticsService,
])
void main() {
  group('ImportService', () {
    late ImportService importService;
    late MockNotesRepository mockNotesRepository;
    late MockNoteIndexer mockNoteIndexer;
    late MockAppLogger mockLogger;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockNotesRepository = MockNotesRepository();
      mockNoteIndexer = MockNoteIndexer();
      mockLogger = MockAppLogger();
      mockAnalytics = MockAnalyticsService();

      importService = ImportService(
        notesRepository: mockNotesRepository,
        noteIndexer: mockNoteIndexer,
        logger: mockLogger,
        analytics: mockAnalytics,
      );

      // Setup default mock behaviors
      when(mockNotesRepository.create(
        title: anyNamed('title'),
        blocks: anyNamed('blocks'),
        createdAt: anyNamed('createdAt'),
        updatedAt: anyNamed('updatedAt'),
      )).thenAnswer((_) async => 'test-note-id');

      when(mockNoteIndexer.indexNote(
        id: anyNamed('id'),
        title: anyNamed('title'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async {});
    });

    group('Markdown Import', () {
      testWidgets('imports simple markdown file', (tester) async {
        // Create test file
        final testFile = File('test_markdown.md');
        await testFile.writeAsString('''# Test Note

This is a simple paragraph.

## Subheading

Another paragraph with **bold** text.

- List item 1
- List item 2

> A quote

```dart
print('Hello World');
```
''');

        try {
          final result = await importService.importMarkdown(testFile);

          expect(result.successCount, equals(1));
          expect(result.errorCount, equals(0));
          expect(result.errors, isEmpty);

          verify(mockNotesRepository.create(
            title: 'Test Note',
            blocks: anyNamed('blocks'),
            createdAt: anyNamed('createdAt'),
            updatedAt: anyNamed('updatedAt'),
          )).called(1);

          verify(mockAnalytics.event('import.success', props: anyNamed('props'))).called(1);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('handles file without title', (tester) async {
        final testFile = File('untitled.md');
        await testFile.writeAsString('Just some content without a title.');

        try {
          final result = await importService.importMarkdown(testFile);

          expect(result.successCount, equals(1));
          
          verify(mockNotesRepository.create(
            title: 'Untitled',
            blocks: anyNamed('blocks'),
            createdAt: anyNamed('createdAt'),
            updatedAt: anyNamed('updatedAt'),
          )).called(1);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('handles empty file', (tester) async {
        final testFile = File('empty.md');
        await testFile.writeAsString('');

        try {
          final result = await importService.importMarkdown(testFile);

          expect(result.successCount, equals(0));
          expect(result.errorCount, equals(1));
          expect(result.errors.first, contains('empty'));
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('handles non-existent file', (tester) async {
        final testFile = File('non_existent.md');

        final result = await importService.importMarkdown(testFile);

        expect(result.successCount, equals(0));
        expect(result.errorCount, equals(1));
        expect(result.errors.first, contains('does not exist'));
      });
    });

    group('ENEX Import', () {
      testWidgets('imports simple ENEX file', (tester) async {
        final enexContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export export-date="20231201T120000Z" application="Evernote" version="10.x">
  <note>
    <title>Test Note 1</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
  <div>This is a simple note.</div>
  <div><b>Bold text</b> and <i>italic text</i>.</div>
</en-note>]]></content>
    <created>20231201T100000Z</created>
    <updated>20231201T110000Z</updated>
  </note>
  <note>
    <title>Test Note 2</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
  <div>Another note with content.</div>
</en-note>]]></content>
    <created>20231201T120000Z</created>
    <updated>20231201T130000Z</updated>
  </note>
</en-export>''';

        final testFile = File('test_export.enex');
        await testFile.writeAsString(enexContent);

        try {
          final result = await importService.importEnex(testFile);

          expect(result.successCount, equals(2));
          expect(result.errorCount, equals(0));
          expect(result.errors, isEmpty);

          verify(mockNotesRepository.create(
            title: 'Test Note 1',
            blocks: anyNamed('blocks'),
            createdAt: anyNamed('createdAt'),
            updatedAt: anyNamed('updatedAt'),
          )).called(1);

          verify(mockNotesRepository.create(
            title: 'Test Note 2',
            blocks: anyNamed('blocks'),
            createdAt: anyNamed('createdAt'),
            updatedAt: anyNamed('updatedAt'),
          )).called(1);

          verify(mockAnalytics.event('import.success', props: anyNamed('props'))).called(1);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('handles malformed XML', (tester) async {
        final testFile = File('malformed.enex');
        await testFile.writeAsString('This is not valid XML');

        try {
          final result = await importService.importEnex(testFile);

          expect(result.successCount, equals(0));
          expect(result.errorCount, equals(1));
          expect(result.errors, isNotEmpty);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('handles ENEX with no notes', (tester) async {
        final enexContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export export-date="20231201T120000Z" application="Evernote" version="10.x">
</en-export>''';

        final testFile = File('empty_export.enex');
        await testFile.writeAsString(enexContent);

        try {
          final result = await importService.importEnex(testFile);

          expect(result.successCount, equals(0));
          expect(result.errorCount, equals(1));
          expect(result.errors.first, contains('No notes found'));
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });
    });

    group('Obsidian Import', () {
      testWidgets('imports directory with markdown files', (tester) async {
        // Create test directory structure
        final testDir = Directory('test_vault');
        await testDir.create();

        final file1 = File('${testDir.path}/note1.md');
        await file1.writeAsString('# Note 1\n\nFirst note content.');

        final file2 = File('${testDir.path}/note2.md');
        await file2.writeAsString('# Note 2\n\nSecond note with #tag.');

        final subDir = Directory('${testDir.path}/subfolder');
        await subDir.create();

        final file3 = File('${subDir.path}/note3.md');
        await file3.writeAsString('# Note 3\n\nNested note content.');

        try {
          final result = await importService.importObsidian(testDir);

          expect(result.successCount, equals(3));
          expect(result.errorCount, equals(0));
          expect(result.errors, isEmpty);

          verify(mockNotesRepository.create(
            title: anyNamed('title'),
            blocks: anyNamed('blocks'),
            createdAt: anyNamed('createdAt'),
            updatedAt: anyNamed('updatedAt'),
          )).called(3);

          verify(mockAnalytics.event('import.success', props: anyNamed('props'))).called(1);
        } finally {
          if (await testDir.exists()) {
            await testDir.delete(recursive: true);
          }
        }
      });

      testWidgets('handles directory with no markdown files', (tester) async {
        final testDir = Directory('empty_vault');
        await testDir.create();

        final txtFile = File('${testDir.path}/readme.txt');
        await txtFile.writeAsString('This is not a markdown file.');

        try {
          final result = await importService.importObsidian(testDir);

          expect(result.successCount, equals(0));
          expect(result.errorCount, equals(1));
          expect(result.errors.first, contains('No Markdown files found'));
        } finally {
          if (await testDir.exists()) {
            await testDir.delete(recursive: true);
          }
        }
      });

      testWidgets('handles non-existent directory', (tester) async {
        final testDir = Directory('non_existent_vault');

        final result = await importService.importObsidian(testDir);

        expect(result.successCount, equals(0));
        expect(result.errorCount, equals(1));
        expect(result.errors.first, contains('does not exist'));
      });
    });

    group('Progress Tracking', () {
      testWidgets('reports progress during ENEX import', (tester) async {
        final enexContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export export-date="20231201T120000Z" application="Evernote" version="10.x">
  <note><title>Note 1</title><content><![CDATA[<en-note><div>Content 1</div></en-note>]]></content></note>
  <note><title>Note 2</title><content><![CDATA[<en-note><div>Content 2</div></en-note>]]></content></note>
  <note><title>Note 3</title><content><![CDATA[<en-note><div>Content 3</div></en-note>]]></content></note>
</en-export>''';

        final testFile = File('progress_test.enex');
        await testFile.writeAsString(enexContent);

        final progressUpdates = <String>[];

        try {
          await importService.importEnex(
            testFile,
            onProgress: (current, total, currentFile) {
              progressUpdates.add('$current/$total: $currentFile');
            },
          );

          expect(progressUpdates, isNotEmpty);
          expect(progressUpdates.last, contains('3/3'));
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });
    });

    group('Error Handling', () {
      testWidgets('handles repository errors gracefully', (tester) async {
        when(mockNotesRepository.create(
          title: anyNamed('title'),
          blocks: anyNamed('blocks'),
          createdAt: anyNamed('createdAt'),
          updatedAt: anyNamed('updatedAt'),
        )).thenThrow(Exception('Database error'));

        final testFile = File('error_test.md');
        await testFile.writeAsString('# Test\n\nContent');

        try {
          final result = await importService.importMarkdown(testFile);

          expect(result.successCount, equals(0));
          expect(result.errorCount, equals(1));
          expect(result.errors.first, contains('Database error'));

          verify(mockLogger.error(
            anyNamed('msg'),
            error: anyNamed('error'),
            stackTrace: anyNamed('stackTrace'),
          )).called(1);

          verify(mockAnalytics.event('import.error', props: anyNamed('props'))).called(1);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });
    });

    group('Analytics', () {
      testWidgets('tracks successful imports', (tester) async {
        final testFile = File('analytics_test.md');
        await testFile.writeAsString('# Test\n\nContent');

        try {
          await importService.importMarkdown(testFile);

          verify(mockAnalytics.event('import.success', props: {
            'type': 'markdown',
            'count': 1,
            'duration_ms': anyNamed('duration_ms'),
          })).called(1);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      testWidgets('tracks import errors', (tester) async {
        final testFile = File('non_existent.md');

        await importService.importMarkdown(testFile);

        verify(mockAnalytics.event('import.error', props: {
          'type': 'markdown',
          'error': anyNamed('error'),
        })).called(1);
      });
    });
  });
}
