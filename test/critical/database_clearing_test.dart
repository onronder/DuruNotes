import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-database-clearing';
  late AppDb db;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    db = AppDb.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('CRITICAL: Database clearing', () {
    test('clearAll purges every table and FTS index', () async {
      await _seedDatabase(db, userId);

      expect(await db.select(db.localNotes).get(), isNotEmpty);
      expect(await db.select(db.localFolders).get(), isNotEmpty);
      expect(await db.select(db.noteFolders).get(), isNotEmpty);
      expect(await db.select(db.noteTags).get(), isNotEmpty);
      expect(await db.select(db.noteLinks).get(), isNotEmpty);
      expect(await db.select(db.noteReminders).get(), isNotEmpty);
      expect(await db.select(db.noteTasks).get(), isNotEmpty);
      expect(await db.select(db.savedSearches).get(), isNotEmpty);
      expect(await db.select(db.localTemplates).get(), isNotEmpty);
      expect(await db.select(db.attachments).get(), isNotEmpty);
      expect(await db.select(db.inboxItems).get(), isNotEmpty);
      expect(await db.select(db.pendingOps).get(), isNotEmpty);
      expect(await _ftsCount(db), greaterThan(0));

      await db.clearAll();

      expect(await db.select(db.localNotes).get(), isEmpty);
      expect(await db.select(db.localFolders).get(), isEmpty);
      expect(await db.select(db.noteFolders).get(), isEmpty);
      expect(await db.select(db.noteTags).get(), isEmpty);
      expect(await db.select(db.noteLinks).get(), isEmpty);
      expect(await db.select(db.noteReminders).get(), isEmpty);
      expect(await db.select(db.noteTasks).get(), isEmpty);
      expect(await db.select(db.savedSearches).get(), isEmpty);
      expect(await db.select(db.localTemplates).get(), isEmpty);
      expect(await db.select(db.attachments).get(), isEmpty);
      expect(await db.select(db.inboxItems).get(), isEmpty);
      expect(await db.select(db.pendingOps).get(), isEmpty);
      expect(await _ftsCount(db), equals(0));
    });

    test('clearAll is idempotent on an already empty database', () async {
      await db.clearAll(); // Initial run should not throw
      expect(await db.select(db.localNotes).get(), isEmpty);

      await db.clearAll(); // Second run should also succeed
      expect(await db.select(db.localNotes).get(), isEmpty);
      expect(await _ftsCount(db), equals(0));
    });
  });
}

Future<void> _seedDatabase(AppDb db, String userId) async {
  final now = DateTime.utc(2025, 1, 1);

  await db.into(db.localNotes).insert(
        LocalNotesCompanion.insert(
          id: 'note-1',
          titleEncrypted: const Value('enc::title'),
          bodyEncrypted: const Value('enc::body'),
          encryptionVersion: const Value(1),
          createdAt: now,
          updatedAt: now,
          isPinned: const Value(true),
          noteType: Value(NoteKind.note),
          version: const Value(1),
          userId: Value(userId),
        ),
      );

  await db.into(db.localFolders).insert(
        LocalFoldersCompanion.insert(
          id: 'folder-1',
          userId: userId,
          name: 'Projects',
          path: '/Projects',
          createdAt: now,
          updatedAt: now,
        ),
      );

  await db.into(db.noteFolders).insert(
        NoteFoldersCompanion.insert(
          noteId: 'note-1',
          folderId: 'folder-1',
          addedAt: now,
        ),
      );

  await db.into(db.noteTags).insert(
        NoteTagsCompanion.insert(
          noteId: 'note-1',
          tag: 'security',
        ),
      );

  await db.into(db.noteLinks).insert(
        NoteLinksCompanion.insert(
          sourceId: 'note-1',
          targetTitle: 'Other Note',
          targetId: const Value('note-2'),
        ),
      );

  await db.into(db.noteReminders).insert(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: userId,
          type: ReminderType.time,
          title: const Value('Reminder'),
          body: const Value('Follow up soon'),
          createdAt: Value(now),
        ),
      );

  await db.into(db.noteTasks).insert(
        NoteTasksCompanion.insert(
          id: 'task-1',
          noteId: 'note-1',
          userId: userId,
          contentEncrypted: 'enc::task',
          contentHash: 'hash-1',
          status: const Value(TaskStatus.open),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db.into(db.savedSearches).insert(
        SavedSearchesCompanion.insert(
          id: 'search-1',
          name: 'Important',
          query: 'tag:security',
          userId: Value(userId),
          createdAt: now,
        ),
      );

  await db.into(db.localTemplates).insert(
        LocalTemplatesCompanion.insert(
          id: 'template-1',
          userId: Value(userId),
          title: 'Incident Report',
          body: 'Template body',
          category: 'security',
          description: 'Security incident template',
          icon: 'shield',
          createdAt: now,
          updatedAt: now,
        ),
      );

  await db.into(db.attachments).insert(
        AttachmentsCompanion.insert(
          id: 'attachment-1',
          userId: userId,
          noteId: 'note-1',
          filename: 'report.pdf',
          mimeType: 'application/pdf',
          size: 2048,
          createdAt: now,
        ),
      );

  await db.into(db.inboxItems).insert(
        InboxItemsCompanion.insert(
          id: 'inbox-1',
          userId: userId,
          sourceType: 'email_in',
          payload: '{"subject":"Follow up"}',
          createdAt: now,
        ),
      );

  await db.into(db.pendingOps).insert(
        PendingOpsCompanion.insert(
          entityId: 'note-1',
          kind: 'delete_note',
          userId: userId,
          payload: const Value('{"reason":"test"}'),
        ),
      );

  // Verify FTS contains the seeded note
  final ftsCount = await _ftsCount(db);
  if (ftsCount == 0) {
    await db.customStatement(
      '''
      INSERT INTO fts_notes(id, title, body, folder_path)
      VALUES (?, ?, ?, ?)
      ''',
      ['note-1', 'enc::title', 'enc::body', '/Projects'],
    );
  }
}

Future<int> _ftsCount(AppDb db) async {
  final row =
      await db.customSelect('SELECT COUNT(*) AS count FROM fts_notes').getSingle();
  return row.read<int>('count');
}
