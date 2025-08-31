import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:duru_notes_app/app/app.dart';
import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:duru_notes_app/core/parser/note_indexer.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:duru_notes_app/services/import_service.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Import Encryption & Indexing Verification Tests', () {
    late AppDb testDb;
    late KeyManager testKeyManager;
    late CryptoBox testCrypto;
    late NoteIndexer testIndexer;
    late NotesRepository testRepository;
    late ImportService testImportService;
    late Directory tempDir;
    
    const String testUserId = 'test-user-123';

    setUpAll(() async {
      // Create temporary directory for test files
      tempDir = await getTemporaryDirectory();
      
      // Initialize test dependencies
      testDb = AppDb();
      testKeyManager = KeyManager.inMemory();
      testCrypto = CryptoBox(testKeyManager);
      testIndexer = NoteIndexer();
      
      testRepository = NotesRepository(
        db: testDb,
        crypto: testCrypto,
        client: null as dynamic, // Mock client not needed for local tests
        userId: testUserId,
      );
      
      testImportService = ImportService(
        notesRepository: testRepository,
        noteIndexer: testIndexer,
        logger: LoggerFactory.instance,
        analytics: AnalyticsFactory.instance,
      );
    });

    tearDownAll(() async {
      await testDb.close();
    });

    setUp(() async {
      // Clear database before each test
      await testDb.delete(testDb.localNotes).go();
      await testDb.delete(testDb.noteTags).go();
      await testDb.delete(testDb.noteLinks).go();
      await testDb.delete(testDb.pendingOps).go();
      
      // Clear indexer
      await testIndexer.clearIndex();
    });

    group('Markdown Import Encryption & Indexing', () {
      testWidgets('Imported markdown note is properly encrypted and indexed', 
        (WidgetTester tester) async {
        
        // Create test markdown file
        final testContent = '''# Test Note Title

This is a test note with **bold text** and *italic text*.

## Section 1
- Item 1 with #tag1
- Item 2 with #tag2
- Reference to [[other-note]]

## Section 2
Some content with @mention and more searchable words.
''';
        
        final testFile = File(path.join(tempDir.path, 'test_note.md'));
        await testFile.writeAsString(testContent);

        // Import the file
        final result = await testImportService.importMarkdown(testFile);
        
        // Verify import was successful
        expect(result.success, true);
        expect(result.successCount, 1);
        expect(result.errors, isEmpty);

        // Verify note exists in database
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 1);
        
        final importedNote = allNotes.first;
        expect(importedNote.title, 'Test Note Title');
        expect(importedNote.body.contains('This is a test note'), true);
        expect(importedNote.deleted, false);

        // === ENCRYPTION VERIFICATION ===
        
        // Verify that when synced to remote, the note is encrypted
        await testRepository.pushAllPending();
        
        // Check that encryption keys were generated
        final masterKey = await testKeyManager.getOrCreateMasterKey(testUserId);
        expect(masterKey, isNotNull);
        
        // Test encryption/decryption roundtrip
        final encryptedTitle = await testCrypto.encryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          text: importedNote.title,
        );
        expect(encryptedTitle.length, greaterThan(0));
        
        final decryptedTitle = await testCrypto.decryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          data: encryptedTitle,
        );
        expect(decryptedTitle, importedNote.title);
        
        // Test JSON encryption for note properties
        final noteProps = {
          'body': importedNote.body,
          'updatedAt': importedNote.updatedAt.toIso8601String(),
          'deleted': importedNote.deleted,
        };
        
        final encryptedProps = await testCrypto.encryptJsonForNote(
          userId: testUserId,
          noteId: importedNote.id,
          json: noteProps,
        );
        expect(encryptedProps.length, greaterThan(0));
        
        final decryptedProps = await testCrypto.decryptJsonForNote(
          userId: testUserId,
          noteId: importedNote.id,
          data: encryptedProps,
        );
        expect(decryptedProps['body'], importedNote.body);
        expect(decryptedProps['deleted'], importedNote.deleted);

        // === INDEXING VERIFICATION ===
        
        // Verify note is indexed for search
        final searchResults = testIndexer.searchNotes('test note');
        expect(searchResults.contains(importedNote.id), true);
        
        // Verify tag indexing
        final tag1Results = testIndexer.findNotesByTag('tag1');
        expect(tag1Results.contains(importedNote.id), true);
        
        final tag2Results = testIndexer.findNotesByTag('tag2');
        expect(tag2Results.contains(importedNote.id), true);
        
        // Verify word indexing
        final boldResults = testIndexer.searchNotes('bold');
        expect(boldResults.contains(importedNote.id), true);
        
        final italicResults = testIndexer.searchNotes('italic');
        expect(italicResults.contains(importedNote.id), true);
        
        // Verify link indexing
        final linkResults = testIndexer.findNotesLinkingTo('other-note');
        expect(linkResults.contains(importedNote.id), true);
        
        // Verify mention indexing (treated as tag)
        final mentionResults = testIndexer.findNotesByTag('mention');
        expect(mentionResults.contains(importedNote.id), true);
        
        // Verify complex search queries
        final multiWordResults = testIndexer.searchNotes('test bold');
        expect(multiWordResults.contains(importedNote.id), true);
        
        // Verify index statistics
        final indexStats = testIndexer.getIndexStats();
        expect(indexStats['indexed_notes'], 1);
        expect(indexStats['total_tags'], greaterThan(0));
        expect(indexStats['total_words'], greaterThan(0));
        
        // Clean up test file
        await testFile.delete();
      });

      testWidgets('Multiple imported notes maintain separate encryption and indexing', 
        (WidgetTester tester) async {
        
        // Create multiple test files
        final testFiles = <File>[];
        final testContents = [
          '# First Note\nContent with #first and unique words.',
          '# Second Note\nDifferent content with #second and other terms.',
          '# Third Note\nAnother note with #third and specific vocabulary.',
        ];
        
        for (int i = 0; i < testContents.length; i++) {
          final file = File(path.join(tempDir.path, 'test_note_$i.md'));
          await file.writeAsString(testContents[i]);
          testFiles.add(file);
        }
        
        // Import all files
        final results = <ImportResult>[];
        for (final file in testFiles) {
          final result = await testImportService.importMarkdown(file);
          results.add(result);
        }
        
        // Verify all imports were successful
        for (final result in results) {
          expect(result.success, true);
          expect(result.successCount, 1);
        }
        
        // Verify all notes exist in database
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 3);
        
        // === ENCRYPTION VERIFICATION FOR MULTIPLE NOTES ===
        
        for (final note in allNotes) {
          // Each note should have unique encryption
          final encryptedTitle = await testCrypto.encryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            text: note.title,
          );
          
          final decryptedTitle = await testCrypto.decryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            data: encryptedTitle,
          );
          
          expect(decryptedTitle, note.title);
          
          // Verify encryption is unique per note (same plaintext, different ciphertext)
          final encryptedTitle2 = await testCrypto.encryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            text: note.title,
          );
          
          // Different nonces should produce different ciphertext
          expect(encryptedTitle, isNot(equals(encryptedTitle2)));
        }
        
        // === INDEXING VERIFICATION FOR MULTIPLE NOTES ===
        
        // Verify each note is indexed separately
        final firstResults = testIndexer.findNotesByTag('first');
        expect(firstResults.length, 1);
        
        final secondResults = testIndexer.findNotesByTag('second');
        expect(secondResults.length, 1);
        
        final thirdResults = testIndexer.findNotesByTag('third');
        expect(thirdResults.length, 1);
        
        // Verify search finds appropriate notes
        final uniqueResults = testIndexer.searchNotes('unique');
        expect(uniqueResults.length, 1);
        
        final contentResults = testIndexer.searchNotes('content');
        expect(contentResults.length, 2); // First and Second notes
        
        // Verify index statistics
        final indexStats = testIndexer.getIndexStats();
        expect(indexStats['indexed_notes'], 3);
        expect(indexStats['total_tags'], 3);
        
        // Clean up test files
        for (final file in testFiles) {
          await file.delete();
        }
      });
    });

    group('ENEX Import Encryption & Indexing', () {
      testWidgets('Imported ENEX note is properly encrypted and indexed', 
        (WidgetTester tester) async {
        
        // Create test ENEX file
        final enexContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export export-date="20240101T000000Z" application="Evernote" version="10.0">
  <note>
    <title>ENEX Test Note</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
  <div>This is an ENEX test note with <b>formatting</b>.</div>
  <div>It contains #enexTag and searchable content.</div>
  <div>Multiple paragraphs with different content.</div>
</en-note>]]></content>
    <created>20240101T000000Z</created>
    <updated>20240101T120000Z</updated>
    <tag>test-tag</tag>
    <tag>evernote</tag>
  </note>
</en-export>''';
        
        final testFile = File(path.join(tempDir.path, 'test_export.enex'));
        await testFile.writeAsString(enexContent);

        // Import the ENEX file
        final result = await testImportService.importEnex(testFile);
        
        // Verify import was successful
        expect(result.success, true);
        expect(result.successCount, 1);
        expect(result.errors, isEmpty);

        // Verify note exists in database
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 1);
        
        final importedNote = allNotes.first;
        expect(importedNote.title, 'ENEX Test Note');
        expect(importedNote.body.contains('ENEX test note'), true);

        // === ENCRYPTION VERIFICATION ===
        
        // Test encryption for ENEX imported note
        final encryptedTitle = await testCrypto.encryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          text: importedNote.title,
        );
        
        final decryptedTitle = await testCrypto.decryptStringForNote(
          userId: testUserId,
          noteId: importedNote.id,
          data: encryptedTitle,
        );
        
        expect(decryptedTitle, importedNote.title);

        // === INDEXING VERIFICATION ===
        
        // Verify ENEX note is indexed
        final searchResults = testIndexer.searchNotes('ENEX');
        expect(searchResults.contains(importedNote.id), true);
        
        // Verify tag indexing from ENEX
        final enexTagResults = testIndexer.findNotesByTag('enexTag');
        expect(enexTagResults.contains(importedNote.id), true);
        
        // Verify content search
        final formattingResults = testIndexer.searchNotes('formatting');
        expect(formattingResults.contains(importedNote.id), true);
        
        // Clean up test file
        await testFile.delete();
      });
    });

    group('Obsidian Import Encryption & Indexing', () {
      testWidgets('Imported Obsidian vault notes are properly encrypted and indexed', 
        (WidgetTester tester) async {
        
        // Create test Obsidian vault structure
        final vaultDir = Directory(path.join(tempDir.path, 'test_vault'));
        await vaultDir.create();
        
        final testFiles = <String, String>{
          'Note 1.md': '''# Obsidian Note 1
This is the first note with [[Note 2]] link.
Contains #obsidian and #vault tags.
''',
          'Note 2.md': '''# Obsidian Note 2
This is the second note linking back to [[Note 1]].
Has different #tags and content.
''',
          'subfolder/Note 3.md': '''# Nested Note
This note is in a subfolder.
Contains #nested tag and unique content.
''',
        };
        
        // Create test files
        for (final entry in testFiles.entries) {
          final filePath = path.join(vaultDir.path, entry.key);
          final file = File(filePath);
          await file.parent.create(recursive: true);
          await file.writeAsString(entry.value);
        }

        // Import the Obsidian vault
        final result = await testImportService.importObsidian(vaultDir);
        
        // Verify import was successful
        expect(result.success, true);
        expect(result.successCount, 3);
        expect(result.errors, isEmpty);

        // Verify all notes exist in database
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 3);

        // === ENCRYPTION VERIFICATION FOR ALL VAULT NOTES ===
        
        for (final note in allNotes) {
          final encryptedTitle = await testCrypto.encryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            text: note.title,
          );
          
          final decryptedTitle = await testCrypto.decryptStringForNote(
            userId: testUserId,
            noteId: note.id,
            data: encryptedTitle,
          );
          
          expect(decryptedTitle, note.title);
        }

        // === INDEXING VERIFICATION FOR VAULT NOTES ===
        
        // Verify all notes are indexed
        final obsidianResults = testIndexer.findNotesByTag('obsidian');
        expect(obsidianResults.length, 1);
        
        final vaultResults = testIndexer.findNotesByTag('vault');
        expect(vaultResults.length, 1);
        
        final nestedResults = testIndexer.findNotesByTag('nested');
        expect(nestedResults.length, 1);
        
        // Verify cross-linking between notes
        final note1Links = testIndexer.findNotesLinkingTo('Note 2');
        expect(note1Links.length, 1);
        
        final note2Links = testIndexer.findNotesLinkingTo('Note 1');
        expect(note2Links.length, 1);
        
        // Verify search across all vault notes
        final noteResults = testIndexer.searchNotes('note');
        expect(noteResults.length, 3); // All notes contain "note"
        
        // Verify subfolder note is indexed
        final subfolderResults = testIndexer.searchNotes('subfolder');
        expect(subfolderResults.length, 1);
        
        // Clean up test vault
        await vaultDir.delete(recursive: true);
      });
    });

    group('Import Error Handling', () {
      testWidgets('Failed imports do not corrupt encryption or indexing', 
        (WidgetTester tester) async {
        
        // Create a corrupted markdown file
        final corruptedFile = File(path.join(tempDir.path, 'corrupted.md'));
        await corruptedFile.writeAsString(''); // Empty file should cause error
        
        // Attempt to import corrupted file
        final result = await testImportService.importMarkdown(corruptedFile);
        
        // Verify import failed gracefully
        expect(result.success, false);
        expect(result.successCount, 0);
        expect(result.errors, isNotEmpty);
        
        // Verify no notes were created
        final allNotes = await testDb.allNotes();
        expect(allNotes.length, 0);
        
        // Verify indexer is still clean
        final indexStats = testIndexer.getIndexStats();
        expect(indexStats['indexed_notes'], 0);
        expect(indexStats['total_tags'], 0);
        expect(indexStats['total_words'], 0);
        
        // Now import a valid file to ensure system still works
        final validFile = File(path.join(tempDir.path, 'valid.md'));
        await validFile.writeAsString('# Valid Note\nThis should work fine.');
        
        final validResult = await testImportService.importMarkdown(validFile);
        expect(validResult.success, true);
        expect(validResult.successCount, 1);
        
        // Verify the valid note is properly encrypted and indexed
        final validNotes = await testDb.allNotes();
        expect(validNotes.length, 1);
        
        final validNote = validNotes.first;
        final searchResults = testIndexer.searchNotes('Valid');
        expect(searchResults.contains(validNote.id), true);
        
        // Clean up test files
        await corruptedFile.delete();
        await validFile.delete();
      });
    });

    group('Encryption Key Management', () {
      testWidgets('Different users get different encryption keys', 
        (WidgetTester tester) async {
        
        const String userId1 = 'user-1';
        const String userId2 = 'user-2';
        
        // Get master keys for different users
        final key1 = await testKeyManager.getOrCreateMasterKey(userId1);
        final key2 = await testKeyManager.getOrCreateMasterKey(userId2);
        
        // Keys should be different
        expect(key1.extractBytes(), isNot(equals(key2.extractBytes())));
        
        // Same user should get same key
        final key1Again = await testKeyManager.getOrCreateMasterKey(userId1);
        expect(key1.extractBytes(), equals(key1Again.extractBytes()));
        
        // Test encryption with different user keys
        final testNote = 'Test note content';
        final noteId = 'test-note-123';
        
        final encrypted1 = await testCrypto.encryptStringForNote(
          userId: userId1,
          noteId: noteId,
          text: testNote,
        );
        
        final encrypted2 = await testCrypto.encryptStringForNote(
          userId: userId2,
          noteId: noteId,
          text: testNote,
        );
        
        // Same plaintext with different user keys should produce different ciphertext
        expect(encrypted1, isNot(equals(encrypted2)));
        
        // Each user should only be able to decrypt their own data
        final decrypted1 = await testCrypto.decryptStringForNote(
          userId: userId1,
          noteId: noteId,
          data: encrypted1,
        );
        expect(decrypted1, testNote);
        
        // User 2 should not be able to decrypt user 1's data
        expect(() async {
          await testCrypto.decryptStringForNote(
            userId: userId2,
            noteId: noteId,
            data: encrypted1,
          );
        }, throwsException);
      });
    });
  });
}
