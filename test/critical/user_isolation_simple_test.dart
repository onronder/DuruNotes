/// CRITICAL: User Isolation Test Suite (Simplified)
///
/// Tests to ensure complete data isolation between users
/// Prevents User B from seeing User A's data
///
/// Priority: P0 - CRITICAL
/// These tests MUST pass for production deployment
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';

void main() {
  group('🚨 CRITICAL: User Isolation Tests (Simplified)', () {
    late AppDb database;

    // Test users
    const userA = 'user-a-123';
    const userB = 'user-b-456';

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      // Create in-memory database for testing
      database = AppDb.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      // Ensure complete cleanup
      await database.clearAll();
      await database.close();
    });

    test('User B should NOT see User A notes after database clear', () async {
      // === PHASE 1: Create notes for User A ===

      // Create 5 notes for User A
      for (int i = 0; i < 5; i++) {
        final createdAt = DateTime.now();
        final note = LocalNote(
          id: 'note-a-$i',
          titleEncrypted: 'Encrypted Title A$i',
          bodyEncrypted: 'Encrypted Body A$i',
          createdAt: createdAt,
          updatedAt: createdAt,
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: userA,
          encryptionVersion: 1,
          encryptedMetadata: null,
          metadataEncrypted: null,
          attachmentMeta: null,
          metadata: null,
        );
        await database.into(database.localNotes).insert(note);
      }

      // Verify User A notes are in database
      final userANotes = await database.select(database.localNotes).get();
      expect(
        userANotes.length,
        5,
        reason: 'User A should have 5 notes in database',
      );

      // Verify all notes belong to User A
      for (final note in userANotes) {
        expect(note.userId, userA, reason: 'All notes should belong to User A');
      }

      // === PHASE 2: Clear database (simulating logout) ===

      await database.clearAll();

      // CRITICAL: Verify database is completely empty
      final notesAfterClear = await database.select(database.localNotes).get();
      expect(
        notesAfterClear.length,
        0,
        reason:
            'Database MUST be empty after clearAll() - SECURITY BREACH if not!',
      );

      // === PHASE 3: User B creates notes ===

      // Create 3 notes for User B
      for (int i = 0; i < 3; i++) {
        final createdAt = DateTime.now();
        final note = LocalNote(
          id: 'note-b-$i',
          titleEncrypted: 'Encrypted Title B$i',
          bodyEncrypted: 'Encrypted Body B$i',
          createdAt: createdAt,
          updatedAt: createdAt,
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: userB,
          encryptionVersion: 1,
          encryptedMetadata: null,
          metadataEncrypted: null,
          attachmentMeta: null,
          metadata: null,
        );
        await database.into(database.localNotes).insert(note);
      }

      // Verify User B has only their notes
      final userBNotes = await database.select(database.localNotes).get();
      expect(userBNotes.length, 3, reason: 'User B should have only 3 notes');

      // Verify no User A data exists
      for (final note in userBNotes) {
        expect(note.userId, userB, reason: 'All notes should belong to User B');
        expect(
          note.id,
          isNot(startsWith('note-a')),
          reason: 'No User A notes should exist - DATA LEAK!',
        );
      }
    });

    test('All tables cleared on logout', () async {
      // === PHASE 1: Create comprehensive data for User A ===

      // 1. Notes
      await database.into(database.localNotes).insert(() {
        final createdAt = DateTime.now();
        return LocalNote(
          id: 'note-comprehensive',
          titleEncrypted: 'Note A',
          bodyEncrypted: 'Body A',
          createdAt: createdAt,
          updatedAt: createdAt,
          deleted: false,
          isPinned: true,
          noteType: NoteKind.note,
          version: 1,
          userId: userA,
          encryptionVersion: 1,
          encryptedMetadata: null,
          metadataEncrypted: null,
          attachmentMeta: null,
          metadata: null,
        );
      }());

      // 2. Folders
      await database
          .into(database.localFolders)
          .insert(
            LocalFoldersCompanion.insert(
              id: 'folder-a',
              name: 'Folder A',
              path: '/Folder A',
              userId: userA,
              updatedAt: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );

      // 3. Note-Folder relationships
      await database
          .into(database.noteFolders)
          .insert(
            NoteFoldersCompanion.insert(
              noteId: 'note-comprehensive',
              folderId: 'folder-a',
              addedAt: DateTime.now(),
              userId: userA,
            ),
          );

      // 4. Tags
      await database
          .into(database.noteTags)
          .insert(
            NoteTagsCompanion.insert(
              noteId: 'note-comprehensive',
              tag: 'important',
              userId: userA,
            ),
          );

      // 5. Tasks
      await database
          .into(database.noteTasks)
          .insert(
            NoteTasksCompanion.insert(
              id: 'task-a',
              noteId: 'note-comprehensive',
              userId: userA,
              contentEncrypted: 'Task content',
              contentHash: 'hash123',
            ),
          );

      // 6. Reminders
      await database
          .into(database.noteReminders)
          .insert(
            NoteRemindersCompanion.insert(
              noteId: 'note-comprehensive',
              userId: userA,
              type: ReminderType.time,
            ),
          );

      // 7. Saved Searches
      await database
          .into(database.savedSearches)
          .insert(
            SavedSearchesCompanion.insert(
              id: 'search-a',
              name: 'My Search',
              query: 'test',
              userId: Value(userA),
              createdAt: DateTime.now(),
            ),
          );

      // 8. Pending operations
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              entityId: 'note-comprehensive',
              kind: 'upsert_note',
              userId: userA,
              payload: const Value('{}'),
            ),
          );

      // Verify all data exists
      expect(
        await database.select(database.localNotes).get(),
        isNotEmpty,
        reason: 'Notes should exist before clear',
      );
      expect(
        await database.select(database.localFolders).get(),
        isNotEmpty,
        reason: 'Folders should exist before clear',
      );
      expect(
        await database.select(database.noteFolders).get(),
        isNotEmpty,
        reason: 'Note-folder relationships should exist before clear',
      );
      expect(
        await database.select(database.noteTags).get(),
        isNotEmpty,
        reason: 'Tags should exist before clear',
      );
      expect(
        await database.select(database.noteTasks).get(),
        isNotEmpty,
        reason: 'Tasks should exist before clear',
      );
      expect(
        await database.select(database.noteReminders).get(),
        isNotEmpty,
        reason: 'Reminders should exist before clear',
      );
      expect(
        await database.select(database.savedSearches).get(),
        isNotEmpty,
        reason: 'Saved searches should exist before clear',
      );
      expect(
        await database.select(database.pendingOps).get(),
        isNotEmpty,
        reason: 'Pending ops should exist before clear',
      );

      // === PHASE 2: Clear all data ===

      await database.clearAll();

      // === PHASE 3: Verify EVERY table is empty ===

      expect(
        await database.select(database.localNotes).get(),
        isEmpty,
        reason: 'Notes table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.localFolders).get(),
        isEmpty,
        reason: 'Folders table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.noteFolders).get(),
        isEmpty,
        reason: 'NoteFolders table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.noteTags).get(),
        isEmpty,
        reason: 'Tags table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.noteTasks).get(),
        isEmpty,
        reason: 'NoteTasks table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.noteLinks).get(),
        isEmpty,
        reason: 'Links table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.noteReminders).get(),
        isEmpty,
        reason: 'Reminders table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.savedSearches).get(),
        isEmpty,
        reason: 'SavedSearches table MUST be empty after clearAll()',
      );
      expect(
        await database.select(database.pendingOps).get(),
        isEmpty,
        reason: 'PendingOps table MUST be empty after clearAll()',
      );

      // Also check FTS index is cleared
      final ftsResults = await database
          .customSelect('SELECT * FROM fts_notes')
          .get();
      expect(
        ftsResults,
        isEmpty,
        reason: 'FTS index MUST be empty after clearAll()',
      );
    });

    test('Rapid user switching maintains isolation', () async {
      // Test rapid switching between users
      for (int iteration = 0; iteration < 5; iteration++) {
        // === User A session ===

        // Create a note for User A
        await database.into(database.localNotes).insert(() {
          final createdAt = DateTime.now();
          return LocalNote(
            id: 'rapid-note-a-$iteration',
            titleEncrypted: 'Rapid Note A$iteration',
            bodyEncrypted: 'Body',
            createdAt: createdAt,
            updatedAt: createdAt,
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: userA,
            encryptionVersion: 1,
            encryptedMetadata: null,
            metadataEncrypted: null,
            attachmentMeta: null,
            metadata: null,
          );
        }());

        // Verify note exists
        var notes = await database.select(database.localNotes).get();
        expect(notes.length, 1, reason: 'Should have 1 note after creation');
        expect(
          notes.first.userId,
          userA,
          reason: 'Note should belong to User A',
        );

        // === Simulate logout ===

        await database.clearAll();

        // Verify database is empty
        notes = await database.select(database.localNotes).get();
        expect(
          notes.length,
          0,
          reason: 'Database must be empty after clearAll()',
        );

        // === User B session ===

        // Create a note for User B
        await database.into(database.localNotes).insert(() {
          final createdAt = DateTime.now();
          return LocalNote(
            id: 'rapid-note-b-$iteration',
            titleEncrypted: 'Rapid Note B$iteration',
            bodyEncrypted: 'Body',
            createdAt: createdAt,
            updatedAt: createdAt,
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: userB,
            encryptionVersion: 1,
            encryptedMetadata: null,
            metadataEncrypted: null,
            attachmentMeta: null,
            metadata: null,
          );
        }());

        // Verify User B has only their note
        notes = await database.select(database.localNotes).get();
        expect(notes.length, 1, reason: 'User B should have only 1 note');
        expect(
          notes.first.userId,
          userB,
          reason: 'Note should belong to User B',
        );
        expect(
          notes.first.id,
          startsWith('rapid-note-b'),
          reason: 'Should be User B\'s note',
        );

        // === Clean up for next iteration ===

        await database.clearAll();
      }
    });

    test('Performance: clearAll() with large dataset', () async {
      // Create a large dataset
      final stopwatch = Stopwatch()..start();

      // Create 1000 notes
      for (int i = 0; i < 1000; i++) {
        await database.into(database.localNotes).insert(() {
          final createdAt = DateTime.now();
          return LocalNote(
            id: 'perf-note-$i',
            titleEncrypted: 'Perf Note $i',
            bodyEncrypted: 'Body $i',
            createdAt: createdAt,
            updatedAt: createdAt,
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: userA,
            encryptionVersion: 1,
            encryptedMetadata: null,
            metadataEncrypted: null,
            attachmentMeta: null,
            metadata: null,
          );
        }());
      }

      stopwatch.stop();
      print('Created 1000 notes in ${stopwatch.elapsedMilliseconds}ms');

      // Verify notes exist
      final notes = await database.select(database.localNotes).get();
      expect(notes.length, 1000);

      // Measure clearAll() performance
      stopwatch.reset();
      stopwatch.start();

      await database.clearAll();

      stopwatch.stop();
      print('Cleared 1000 notes in ${stopwatch.elapsedMilliseconds}ms');

      // Assert performance requirement
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason:
            'clearAll() should complete in less than 2 seconds for 1000 notes',
      );

      // Verify complete clearing
      final notesAfterClear = await database.select(database.localNotes).get();
      expect(notesAfterClear, isEmpty, reason: 'All notes must be cleared');
    });

    test('No cross-contamination with mixed userId data', () async {
      // Create mixed data
      final userIds = ['user-1', 'user-2', 'user-3'];

      for (final userId in userIds) {
        for (int i = 0; i < 3; i++) {
          await database.into(database.localNotes).insert(() {
            final createdAt = DateTime.now();
            return LocalNote(
              id: 'note-$userId-$i',
              titleEncrypted: 'Note for $userId #$i',
              bodyEncrypted: 'Content',
              createdAt: createdAt,
              updatedAt: createdAt,
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              version: 1,
              userId: userId,
              encryptionVersion: 1,
              encryptedMetadata: null,
              metadataEncrypted: null,
              attachmentMeta: null,
              metadata: null,
            );
          }());
        }
      }

      // Verify total count
      final allNotes = await database.select(database.localNotes).get();
      expect(
        allNotes.length,
        9,
        reason: 'Should have 9 notes total (3 users × 3 notes)',
      );

      // Simulate query for specific user (would be filtered in repository layer)
      final user1Notes = allNotes.where((n) => n.userId == 'user-1').toList();
      expect(
        user1Notes.length,
        3,
        reason: 'User 1 should have exactly 3 notes',
      );

      // Verify no cross-contamination
      for (final note in user1Notes) {
        expect(
          note.userId,
          'user-1',
          reason: 'All filtered notes should belong to user-1',
        );
        expect(
          note.titleEncrypted,
          contains('user-1'),
          reason: 'Note title should be for user-1',
        );
      }

      // Clear all and verify
      await database.clearAll();

      final notesAfterClear = await database.select(database.localNotes).get();
      expect(
        notesAfterClear,
        isEmpty,
        reason: 'All notes must be cleared regardless of userId',
      );
    });
  });
}
