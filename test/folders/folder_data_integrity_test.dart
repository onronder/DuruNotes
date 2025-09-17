import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Folder data integrity', () {
    AppDb? db;

    setUp(() {
      db = AppDb();
    });

    tearDown(() async {
      await db?.close();
    });

    test('computes folder note counts from database state', () async {
      final now = DateTime.now();
      final folder = LocalFolder(
        id: 'folder-1',
        name: 'Projects',
        path: '/Projects',
        color: '#FFAA00',
        icon: '📁',
        description: '',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        deleted: false,
      );
      await db!.upsertFolder(folder);

      final note = LocalNote(
        id: 'note-1',
        title: 'Specs',
        body: 'Design doc',
        updatedAt: now,
        deleted: false,
        isPinned: false,
      );
      await db!.upsertNote(note);
      await db!.moveNoteToFolder(note.id, folder.id);

      final counts = await db!.getFolderNoteCounts();

      expect(counts[folder.id], equals(1));
    });

    test('cleans up orphaned note-folder relationships', () async {
      final now = DateTime.now();
      final folder = LocalFolder(
        id: 'folder-2',
        name: 'Archive',
        path: '/Archive',
        color: '#888888',
        icon: '🗂️',
        description: '',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        deleted: false,
      );
      await db!.upsertFolder(folder);

      final note = LocalNote(
        id: 'note-2',
        title: 'Old Note',
        body: 'Legacy content',
        updatedAt: now,
        deleted: false,
        isPinned: false,
      );
      await db!.upsertNote(note);
      await db!.moveNoteToFolder(note.id, folder.id);

      // Remove folder directly to simulate external deletion
      await (db!.delete(
        db!.localFolders,
      )..where((tbl) => tbl.id.equals(folder.id))).go();

      // Relationship should now be orphaned
      var relations = await db!.select(db!.noteFolders).get();
      expect(relations, isNotEmpty);

      await db!.cleanupOrphanedRelationships();

      relations = await db!.select(db!.noteFolders).get();
      expect(relations, isEmpty);
    });
  });
}
