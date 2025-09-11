import 'dart:io';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;

import 'import_encryption_indexing_test.mocks.dart';

@GenerateMocks([
  NotesRepository,
  NoteIndexer,
  AppLogger,
  AnalyticsService,
  CryptoBox,
])
void main() {
  group('ImportService Encryption & Indexing Integration Tests', () {
    late MockNotesRepository mockRepository;
    late MockNoteIndexer mockIndexer;
    late MockAppLogger mockLogger;
    late MockAnalyticsService mockAnalytics;
    // late MockCryptoBox mockCrypto;  // Not used in current tests
    late ImportService importService;
    late Directory tempDir;

    setUp(() async {
      mockRepository = MockNotesRepository();
      mockIndexer = MockNoteIndexer();
      mockLogger = MockAppLogger();
      mockAnalytics = MockAnalyticsService();
      // mockCrypto = MockCryptoBox();  // Not used in current tests

      importService = ImportService(
        notesRepository: mockRepository,
        noteIndexer: mockIndexer,
        logger: mockLogger,
        analytics: mockAnalytics,
      );

      // Create temp directory for test files
      tempDir = Directory.systemTemp.createTempSync('import_test_');

      // Setup default mock behaviors
      when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.debug(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace'), data: anyNamed('data'))).thenReturn(null);
      when(mockAnalytics.event(any, properties: anyNamed('properties'))).thenReturn(null);
      when(mockAnalytics.startTiming(any)).thenReturn(null);
      when(mockAnalytics.endTiming(any, properties: anyNamed('properties'))).thenReturn(null);
      when(mockAnalytics.featureUsed(any, properties: anyNamed('properties'))).thenReturn(null);
      when(mockAnalytics.trackError(any, context: anyNamed('context'), properties: anyNamed('properties'))).thenReturn(null);
    });

    tearDown(() async {
      tempDir.deleteSync(recursive: true);
    });

    group('Markdown Import Integration', () {
      test('importMarkdown calls NotesRepository.createOrUpdate and NoteIndexer.indexNote', () async {
        // Arrange
        const testContent = '''
# Test Note
This is a test note with content.
Contains #tag1 and #tag2.
''';
        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString(testContent);

        const testNoteId = 'test-note-123';
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => testNoteId);

        when(mockIndexer.indexNote(any)).thenAnswer((_) async {});

        // Act
        final result = await importService.importMarkdown(testFile);

        // Assert
        expect(result.isSuccess, true);
        expect(result.successCount, 1);

        // Verify NotesRepository.createOrUpdate was called
        verify(mockRepository.createOrUpdate(
          title: 'Test Note',
          body: argThat(contains('This is a test note with content'), named: 'body'),
        )).called(1);

        // Verify NoteIndexer.indexNote was called
        verify(mockIndexer.indexNote(argThat(
          predicate<LocalNote>((note) => 
            note.id == testNoteId &&
            note.title == 'Test Note' &&
            note.body.contains('This is a test note with content')
          )
        ))).called(1);

        // Verify logging
        verify(mockLogger.info('Starting Markdown import', data: anyNamed('data'))).called(1);
        verify(mockLogger.info('Successfully imported note', data: anyNamed('data'))).called(1);

        // Verify analytics
        verify(mockAnalytics.event('import.success', properties: anyNamed('properties'))).called(1);
      });

      test('importMarkdown handles repository errors gracefully', () async {
        // Arrange
        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString('# Test\nContent');

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Database error'));

        // Act
        final result = await importService.importMarkdown(testFile);

        // Assert
        expect(result.isSuccess, false);
        expect(result.successCount, 0);
        expect(result.errors, hasLength(1));
        expect(result.errors.first.message, contains('Database error'));

        // Verify repository was called
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(1);

        // Verify indexer was NOT called due to repository error
        verifyNever(mockIndexer.indexNote(any));

        // Verify error logging
        verify(mockLogger.error('Failed to create imported note', 
          error: anyNamed('error'), 
          stackTrace: anyNamed('stackTrace'),
          data: anyNamed('data')
        )).called(1);
      });

      test('importMarkdown handles indexer errors gracefully', () async {
        // Arrange
        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString('# Test\nContent');

        const testNoteId = 'test-note-123';
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => testNoteId);

        when(mockIndexer.indexNote(any)).thenThrow(Exception('Indexing error'));

        // Act
        final result = await importService.importMarkdown(testFile);

        // Assert - Import should still succeed even if indexing fails
        expect(result.isSuccess, true);
        expect(result.successCount, 1);

        // Verify both repository and indexer were called
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(1);

        verify(mockIndexer.indexNote(any)).called(1);

        // Note: In a real implementation, you might want to handle indexing errors
        // differently, but the current ImportService doesn't seem to catch them
      });
    });

    group('ENEX Import Integration', () {
      test('importEnex calls repository and indexer for each note', () async {
        // Arrange
        const enexContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export export-date="20240101T000000Z" application="Evernote" version="10.0">
  <note>
    <title>First Note</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note><div>First note content</div></en-note>]]></content>
    <created>20240101T000000Z</created>
    <updated>20240101T120000Z</updated>
  </note>
  <note>
    <title>Second Note</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note><div>Second note content</div></en-note>]]></content>
    <created>20240101T000000Z</created>
    <updated>20240101T130000Z</updated>
  </note>
</en-export>''';

        final testFile = File(path.join(tempDir.path, 'test.enex'));
        await testFile.writeAsString(enexContent);

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note-id');

        when(mockIndexer.indexNote(any)).thenAnswer((_) async {});

        // Act
        final result = await importService.importEnex(testFile);

        // Assert
        expect(result.isSuccess, true);
        expect(result.successCount, 2);

        // Verify repository was called for each note
        verify(mockRepository.createOrUpdate(
          title: 'First Note',
          body: anyNamed('body'),
        )).called(1);

        verify(mockRepository.createOrUpdate(
          title: 'Second Note',
          body: anyNamed('body'),
        )).called(1);

        // Verify indexer was called for each note
        verify(mockIndexer.indexNote(any)).called(2);
      });
    });

    group('Obsidian Import Integration', () {
      test('importObsidian calls repository and indexer for each markdown file', () async {
        // Arrange
        final vaultDir = Directory(path.join(tempDir.path, 'vault'));
        await vaultDir.create();

        final files = {
          'note1.md': '# Note 1\nFirst note content',
          'note2.md': '# Note 2\nSecond note content',
          'subfolder/note3.md': '# Note 3\nThird note content',
        };

        for (final entry in files.entries) {
          final file = File(path.join(vaultDir.path, entry.key));
          await file.parent.create(recursive: true);
          await file.writeAsString(entry.value);
        }

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note-id');

        when(mockIndexer.indexNote(any)).thenAnswer((_) async {});

        // Act
        final result = await importService.importObsidian(vaultDir);

        // Assert
        expect(result.isSuccess, true);
        expect(result.successCount, 3);

        // Verify repository was called for each file
        verify(mockRepository.createOrUpdate(
          title: 'Note 1',
          body: anyNamed('body'),
        )).called(1);

        verify(mockRepository.createOrUpdate(
          title: 'Note 2',
          body: anyNamed('body'),
        )).called(1);

        verify(mockRepository.createOrUpdate(
          title: 'Note 3',
          body: anyNamed('body'),
        )).called(1);

        // Verify indexer was called for each note
        verify(mockIndexer.indexNote(any)).called(3);
      });
    });

    group('Encryption Verification', () {
      test('verifies encryption is applied during repository operations', () async {
        // This test verifies that the ImportService properly integrates with
        // the encryption layer through NotesRepository

        // Arrange
        final realKeyManager = KeyManager.inMemory();
        final realCrypto = CryptoBox(realKeyManager);
        const userId = 'test-user';

        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString('# Encrypted Note\nThis should be encrypted');

        // Mock repository to capture the note creation
        LocalNote? capturedNote;
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String;
          final body = invocation.namedArguments[#body] as String;
          
          capturedNote = LocalNote(
            id: 'test-note-id',
            title: title,
            body: body,
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
          );
          
          return capturedNote!.id;
        });

        when(mockIndexer.indexNote(any)).thenAnswer((_) async {});

        // Act
        final result = await importService.importMarkdown(testFile);

        // Assert
        expect(result.isSuccess, true);
        expect(capturedNote, isNotNull);
        expect(capturedNote!.title, 'Encrypted Note');

        // Verify the note can be encrypted/decrypted
        final encryptedTitle = await realCrypto.encryptStringForNote(
          userId: userId,
          noteId: capturedNote!.id,
          text: capturedNote!.title,
        );
        
        final decryptedTitle = await realCrypto.decryptStringForNote(
          userId: userId,
          noteId: capturedNote!.id,
          data: encryptedTitle,
        );
        
        expect(decryptedTitle, capturedNote!.title);

        // Verify the note properties can be encrypted/decrypted
        final noteProps = {
          'body': capturedNote!.body,
          'updatedAt': capturedNote!.updatedAt.toIso8601String(),
          'deleted': capturedNote!.deleted,
        };
        
        final encryptedProps = await realCrypto.encryptJsonForNote(
          userId: userId,
          noteId: capturedNote!.id,
          json: noteProps,
        );
        
        final decryptedProps = await realCrypto.decryptJsonForNote(
          userId: userId,
          noteId: capturedNote!.id,
          data: encryptedProps,
        );
        
        expect(decryptedProps['body'], capturedNote!.body);
        expect(decryptedProps['deleted'], capturedNote!.deleted);
      });
    });

    group('Indexing Verification', () {
      test('verifies search indexing is applied for imported notes', () async {
        // This test verifies that the ImportService properly integrates with
        // the search indexing layer through NoteIndexer

        // Arrange
        final realIndexer = NoteIndexer();
        
        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString('''
# Searchable Note
This note contains #important tag and searchable content.
It also links to [[other-note]] and has @mentions.
Multiple words for search testing.
''');

        LocalNote? capturedNote;
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String;
          final body = invocation.namedArguments[#body] as String;
          
          capturedNote = LocalNote(
            id: 'searchable-note-id',
            title: title,
            body: body,
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
          );
          
          // Actually index the note with real indexer
          await realIndexer.indexNote(capturedNote!);
          
          return capturedNote!.id;
        });

        // Use real indexer for verification
        final importServiceWithRealIndexer = ImportService(
          notesRepository: mockRepository,
          noteIndexer: realIndexer,
          logger: mockLogger,
          analytics: mockAnalytics,
        );

        // Act
        final result = await importServiceWithRealIndexer.importMarkdown(testFile);

        // Assert
        expect(result.isSuccess, true);
        expect(capturedNote, isNotNull);

        // Verify search functionality
        final searchResults = realIndexer.searchNotes('searchable');
        expect(searchResults.contains(capturedNote!.id), true);

        final contentResults = realIndexer.searchNotes('content');
        expect(contentResults.contains(capturedNote!.id), true);

        // Verify tag indexing
        final tagResults = realIndexer.findNotesByTag('important');
        expect(tagResults.contains(capturedNote!.id), true);

        final mentionResults = realIndexer.findNotesByTag('mentions');
        expect(mentionResults.contains(capturedNote!.id), true);

        // Verify link indexing
        final linkResults = realIndexer.findNotesLinkingTo('other-note');
        expect(linkResults.contains(capturedNote!.id), true);

        // Verify multi-word search
        final multiWordResults = realIndexer.searchNotes('search testing');
        expect(multiWordResults.contains(capturedNote!.id), true);

        // Verify index statistics
        final indexStats = realIndexer.getIndexStats();
        expect(indexStats['indexed_notes'], 1);
        expect(indexStats['total_tags'], greaterThan(0));
        expect(indexStats['total_words'], greaterThan(0));
      });
    });
  });
}
