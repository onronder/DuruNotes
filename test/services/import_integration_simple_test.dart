import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseNoteApi extends Mock implements SupabaseNoteApi {}

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  group('ImportService Integration - Encryption & Indexing Verification', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('import_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'ImportService integration calls verify encryption and indexing flow',
      () async {
        // This test verifies the integration points without running the full import
        // It focuses on verifying that the ImportService has the right structure
        // to call NotesRepository.createOrUpdate and NoteIndexer.indexNote

        // Create test components
        final testDb = AppDb();
        final testKeyManager = KeyManager.inMemory();
        final testCrypto = CryptoBox(testKeyManager);
        final testIndexer = NoteIndexer();

        const testUserId = 'test-user-123';
        final testRepository = NotesRepository(
          db: testDb,
          crypto: testCrypto,
          client: MockSupabaseClient(),
          api: MockSupabaseNoteApi(),
        );

        final testImportService = ImportService(
          notesRepository: testRepository,
          noteIndexer: testIndexer,
          logger: LoggerFactory.instance,
          analytics: AnalyticsFactory.instance,
        );

        // Verify ImportService has correct dependencies
        expect(testImportService, isNotNull);

        // Create a simple test file
        final testFile = File(path.join(tempDir.path, 'test.md'));
        await testFile.writeAsString('''
# Integration Test Note
This note tests the integration between ImportService, NotesRepository, and NoteIndexer.
It contains #integration and #test tags for verification.
''');

        // === VERIFY IMPORT CALLS REPOSITORY AND INDEXER ===

        // Import the file - this should call both repository and indexer
        final result = await testImportService.importMarkdown(testFile);

        // Verify import was successful
        expect(result.isSuccess, true, reason: 'Import should succeed');
        expect(result.successCount, 1, reason: 'Should import one note');
        expect(result.errors, isEmpty, reason: 'Should have no errors');

        // === VERIFY REPOSITORY INTEGRATION (ENCRYPTION) ===

        // Check that note was stored in repository
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 1, reason: 'Should have one note in database');

        final importedNote = allNotes.first;
        expect(importedNote.title, 'Integration Test Note');
        expect(
          importedNote.body.contains('integration between ImportService'),
          true,
        );

        // Verify encryption capability exists
        final masterKey = await testKeyManager.getOrCreateMasterKey(testUserId);
        expect(masterKey, isNotNull, reason: 'Master key should be generated');

        // Test that the note can be encrypted/decrypted
        final encryptedTitle = await testCrypto.encryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          text: importedNote.title,
        );
        expect(
          encryptedTitle.length,
          greaterThan(0),
          reason: 'Encrypted title should not be empty',
        );

        final decryptedTitle = await testCrypto.decryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          data: encryptedTitle,
        );
        expect(
          decryptedTitle,
          importedNote.title,
          reason: 'Decryption should restore original title',
        );

        // === VERIFY INDEXER INTEGRATION (SEARCH) ===

        // Verify note is searchable
        final searchResults = testIndexer.searchNotes('integration');
        expect(
          searchResults.contains(importedNote.id),
          true,
          reason: 'Note should be searchable by content',
        );

        // Verify tag indexing
        final integrationTagResults = testIndexer.findNotesByTag('integration');
        expect(
          integrationTagResults.contains(importedNote.id),
          true,
          reason: 'Note should be findable by #integration tag',
        );

        final testTagResults = testIndexer.findNotesByTag('test');
        expect(
          testTagResults.contains(importedNote.id),
          true,
          reason: 'Note should be findable by #test tag',
        );

        // Verify word indexing
        final importServiceResults = testIndexer.searchNotes('ImportService');
        expect(
          importServiceResults.contains(importedNote.id),
          true,
          reason: 'Note should be searchable by ImportService word',
        );

        // Verify index statistics show the note is indexed
        final indexStats = testIndexer.getIndexStats();
        expect(
          indexStats['indexed_notes'],
          1,
          reason: 'Should have 1 indexed note',
        );
        expect(
          indexStats['total_tags'],
          greaterThanOrEqualTo(2),
          reason: 'Should have at least 2 tags',
        );
        expect(
          indexStats['total_words'],
          greaterThan(0),
          reason: 'Should have indexed words',
        );

        // === VERIFY ERROR HANDLING ===

        // Test that invalid files don't corrupt the system
        final invalidFile = File(path.join(tempDir.path, 'invalid.md'));
        await invalidFile.writeAsString(''); // Empty file

        final invalidResult = await testImportService.importMarkdown(
          invalidFile,
        );
        expect(
          invalidResult.isSuccess,
          false,
          reason: 'Empty file import should fail',
        );

        // Verify system is still functional after error
        final postErrorNotes = await testDb.allNotes();
        expect(
          postErrorNotes.length,
          1,
          reason: 'Should still have original note after error',
        );

        final postErrorStats = testIndexer.getIndexStats();
        expect(
          postErrorStats['indexed_notes'],
          1,
          reason: 'Index should be unchanged after error',
        );

        // Clean up
        await testDb.close();
      },
    );

    test(
      'Multiple file import maintains encryption and indexing integrity',
      () async {
        // Test that importing multiple files maintains separate encryption and indexing

        final testDb = AppDb();
        final testKeyManager = KeyManager.inMemory();
        final testCrypto = CryptoBox(testKeyManager);
        final testIndexer = NoteIndexer();

        const testUserId = 'multi-user-456';
        final testRepository = NotesRepository(
          db: testDb,
          crypto: testCrypto,
          client: MockSupabaseClient(),
          api: MockSupabaseNoteApi(),
        );

        final testImportService = ImportService(
          notesRepository: testRepository,
          noteIndexer: testIndexer,
          logger: LoggerFactory.instance,
          analytics: AnalyticsFactory.instance,
        );

        // Create multiple test files
        final testFiles = <String, String>{
          'note1.md': '# First Note\nContent with #first tag and unique words.',
          'note2.md': '# Second Note\nDifferent content with #second tag.',
          'note3.md':
              '# Third Note\nAnother note with #third tag and specific terms.',
        };

        final files = <File>[];
        for (final entry in testFiles.entries) {
          final file = File(path.join(tempDir.path, entry.key));
          await file.writeAsString(entry.value);
          files.add(file);
        }

        // Import all files
        final results = <ImportResult>[];
        for (final file in files) {
          final result = await testImportService.importMarkdown(file);
          results.add(result);
        }

        // Verify all imports succeeded
        for (final result in results) {
          expect(result.isSuccess, true);
          expect(result.successCount, 1);
        }

        // Verify all notes are in database
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 3, reason: 'Should have 3 notes in database');

        // === VERIFY SEPARATE ENCRYPTION ===

        for (final note in allNotes) {
          // Each note should be encryptable with unique results
          final encrypted1 = await testCrypto.encryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            text: note.title,
          );

          final encrypted2 = await testCrypto.encryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            text: note.title,
          );

          // Same content should produce different ciphertext (due to random nonces)
          expect(
            encrypted1,
            isNot(equals(encrypted2)),
            reason:
                'Same content should encrypt differently due to random nonces',
          );

          // Both should decrypt to the same plaintext
          final decrypted1 = await testCrypto.decryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            data: encrypted1,
          );

          final decrypted2 = await testCrypto.decryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            data: encrypted2,
          );

          expect(decrypted1, note.title);
          expect(decrypted2, note.title);
        }

        // === VERIFY SEPARATE INDEXING ===

        // Each note should be indexed separately
        final firstResults = testIndexer.findNotesByTag('first');
        expect(
          firstResults.length,
          1,
          reason: 'Should find exactly one note with #first tag',
        );

        final secondResults = testIndexer.findNotesByTag('second');
        expect(
          secondResults.length,
          1,
          reason: 'Should find exactly one note with #second tag',
        );

        final thirdResults = testIndexer.findNotesByTag('third');
        expect(
          thirdResults.length,
          1,
          reason: 'Should find exactly one note with #third tag',
        );

        // Verify content-based search
        final uniqueResults = testIndexer.searchNotes('unique');
        expect(
          uniqueResults.length,
          1,
          reason: 'Only first note contains "unique"',
        );

        final contentResults = testIndexer.searchNotes('content');
        expect(
          contentResults.length,
          2,
          reason: 'First and second notes contain "content"',
        );

        // Verify index statistics
        final indexStats = testIndexer.getIndexStats();
        expect(
          indexStats['indexed_notes'],
          3,
          reason: 'Should have 3 indexed notes',
        );
        expect(
          indexStats['total_tags'],
          3,
          reason: 'Should have 3 unique tags',
        );

        // Clean up
        await testDb.close();

        // Clean up test files
        for (final file in files) {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      },
    );

    test(
      'Verify ImportService._createNoteWithValidation calls repository and indexer',
      () async {
        // This test specifically verifies that the _createNoteWithValidation method
        // in ImportService calls both NotesRepository.createOrUpdate and NoteIndexer.indexNote

        // Note: This test verifies the integration by checking the end result,
        // since _createNoteWithValidation is a private method

        final testDb = AppDb();
        final testKeyManager = KeyManager.inMemory();
        final testCrypto = CryptoBox(testKeyManager);
        final testIndexer = NoteIndexer();

        const testUserId = 'validation-user-789';
        final testRepository = NotesRepository(
          db: testDb,
          crypto: testCrypto,
          client: MockSupabaseClient(),
          api: MockSupabaseNoteApi(),
        );

        final testImportService = ImportService(
          notesRepository: testRepository,
          noteIndexer: testIndexer,
          logger: LoggerFactory.instance,
          analytics: AnalyticsFactory.instance,
        );

        // Create test file that will trigger _createNoteWithValidation
        final testFile = File(path.join(tempDir.path, 'validation_test.md'));
        await testFile.writeAsString('''
# Validation Test
This note tests that _createNoteWithValidation properly calls:
1. NotesRepository.createOrUpdate (for encryption and storage)
2. NoteIndexer.indexNote (for search indexing)

Tags: #validation #repository #indexer
Links: [[related-note]]
''');

        // Clear any existing state
        await testDb.delete(testDb.localNotes).go();
        await testIndexer.clearIndex();

        // Import the file - this will call _createNoteWithValidation internally
        final result = await testImportService.importMarkdown(testFile);

        expect(result.isSuccess, true);
        expect(result.successCount, 1);

        // === VERIFY REPOSITORY WAS CALLED ===

        // Check that NotesRepository.createOrUpdate was called by verifying note exists
        final repositoryNotes = await testRepository.list();
        expect(
          repositoryNotes.length,
          1,
          reason:
              'NotesRepository.createOrUpdate should have been called to store the note',
        );

        final storedNote = repositoryNotes.first;
        expect(storedNote.title, 'Validation Test');
        expect(storedNote.body.contains('_createNoteWithValidation'), true);

        // === VERIFY INDEXER WAS CALLED ===

        // Check that NoteIndexer.indexNote was called by verifying search works
        final searchResults = testIndexer.searchNotes('validation');
        expect(
          searchResults.contains(storedNote.id),
          true,
          reason:
              'NoteIndexer.indexNote should have been called to index the note',
        );

        // Verify tag indexing (tags are indexed by NoteIndexer.indexNote)
        final validationTagResults = testIndexer.findNotesByTag('validation');
        expect(
          validationTagResults.contains(storedNote.id),
          true,
          reason: 'Tags should be indexed by NoteIndexer.indexNote',
        );

        final repositoryTagResults = testIndexer.findNotesByTag('repository');
        expect(repositoryTagResults.contains(storedNote.id), true);

        final indexerTagResults = testIndexer.findNotesByTag('indexer');
        expect(indexerTagResults.contains(storedNote.id), true);

        // Verify link indexing (links are indexed by NoteIndexer.indexNote)
        final linkResults = testIndexer.findNotesLinkingTo('related-note');
        expect(
          linkResults.contains(storedNote.id),
          true,
          reason: 'Links should be indexed by NoteIndexer.indexNote',
        );

        // === VERIFY BOTH SYSTEMS WORK TOGETHER ===

        // Test that encryption and indexing work together
        final encryptedNote = await testCrypto.encryptStringForNote(
          userId: testUserId,
          noteId: storedNote.id,
          text: storedNote.body,
        );

        final decryptedNote = await testCrypto.decryptStringForNote(
          userId: testUserId,
          noteId: storedNote.id,
          data: encryptedNote,
        );

        expect(
          decryptedNote,
          storedNote.body,
          reason: 'Encryption should work for notes stored via repository',
        );

        // The decrypted content should still be searchable via the indexer
        expect(decryptedNote.contains('_createNoteWithValidation'), true);
        expect(
          testIndexer
              .searchNotes('createNoteWithValidation')
              .contains(storedNote.id),
          true,
          reason: 'Indexed content should match encrypted content',
        );

        // Clean up
        await testDb.close();
      },
    );
  });
}
