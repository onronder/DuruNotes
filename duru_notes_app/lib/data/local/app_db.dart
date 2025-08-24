import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duru_notes_app/core/parser/note_indexer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

/// ----------------------
/// Table definitions
/// ----------------------
@DataClassName('LocalNote')
class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get kind => text()(); // 'upsert_note' | 'delete_note'
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {noteId, tag};
}

@DataClassName('NoteLink')
class NoteLinks extends Table {
  TextColumn get sourceId => text()();
  TextColumn get targetTitle => text()();
  TextColumn get targetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId, targetTitle};
}

/// UI’da kullanmak için küçük taşıyıcı
class BacklinkPair {
  const BacklinkPair({required this.link, this.source});
  final NoteLink link;
  final LocalNote? source;
}

/// ----------------------
/// Database
/// ----------------------
@DriftDatabase(tables: [LocalNotes, PendingOps, NoteTags, NoteLinks])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // FTS tablosu
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
          );

          // Tetikleyiciler: local_notes <-> fts_notes senkron
          await _createFtsTriggers();

          // İndeksler
          await _createIndexes();

          // Mevcut veriyi FTS’ye tohumla
          await customStatement(
            'INSERT INTO fts_notes(id, title, body) '
            'SELECT id, title, body FROM local_notes WHERE deleted = 0',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(noteTags);
            await m.createTable(noteLinks);
          }
          // FTS tablosu ve tetikleyiciler/indeksler
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
          );
          if (from < 3) {
            await _createFtsTriggers();
            await _createIndexes();
            await customStatement('DELETE FROM fts_notes');
            await customStatement(
              'INSERT INTO fts_notes(id, title, body) '
              'SELECT id, title, body FROM local_notes WHERE deleted = 0',
            );
          }
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_notes_updated_notdeleted '
      'ON local_notes(updated_at DESC) WHERE deleted = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_links_target_title '
      'ON note_links(target_title)',
    );
  }

  Future<void> _createFtsTriggers() async {
    // INSERT -> fts’ye ekle (silinmiş değilse)
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ai
      AFTER INSERT ON local_notes
      BEGIN
        INSERT INTO fts_notes(id, title, body)
        SELECT NEW.id, NEW.title, NEW.body WHERE NEW.deleted = 0;
      END;
    ''');

    // UPDATE -> fts’yi güncelle / sil
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_au
      AFTER UPDATE ON local_notes
      BEGIN
        DELETE FROM fts_notes WHERE id = NEW.id;
        INSERT INTO fts_notes(id, title, body)
        SELECT NEW.id, NEW.title, NEW.body WHERE NEW.deleted = 0;
      END;
    ''');

    // DELETE -> fts’den sil
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ad
      AFTER DELETE ON local_notes
      BEGIN
        DELETE FROM fts_notes WHERE id = OLD.id;
      END;
    ''');
  }

  // ----------------------
  // Notes
  // ----------------------
  Future<List<LocalNote>> suggestNotesByTitlePrefix(
    String query, {
    int limit = 8,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .get();
    }

    final startsWith = '$q%';
    final wordStart = '% $q%';

    return (select(localNotes)
          ..where((t) =>
              t.deleted.equals(false) &
              (t.title.like(startsWith) | t.title.like(wordStart)))
          ..orderBy([(t) => OrderingTerm.asc(t.title)])
          ..limit(limit))
        .get();
  }

  Future<List<LocalNote>> allNotes() =>
      (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<void> upsertNote(LocalNote n) =>
      into(localNotes).insertOnConflictUpdate(n);

  Future<LocalNote?> findNote(String id) =>
      (select(localNotes)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ----------------------
  // Queue (PendingOps)
  // ----------------------
  Future<int> enqueue(String entityId, String kind, {String? payload}) =>
      into(pendingOps).insert(
        PendingOpsCompanion.insert(
          entityId: entityId,
          kind: kind,
          payload: Value(payload),
        ),
      );

  Future<List<PendingOp>> getPendingOps() =>
      (select(pendingOps)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

  Future<void> deletePendingByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(pendingOps)..where((t) => t.id.isIn(ids.toList()))).go();
  }

  Future<List<PendingOp>> dequeueAll() async {
    final ops = await (select(pendingOps)
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
    await delete(pendingOps).go();
    return ops;
  }

  // ----------------------
  // Maintenance
  // ----------------------
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(pendingOps).go();
      await delete(localNotes).go();
      await delete(noteTags).go();
      await delete(noteLinks).go();
      await customStatement('DELETE FROM fts_notes');
    });
  }

  Future<Set<String>> getLocalActiveNoteIds() async {
    final rows =
        await (select(localNotes)..where((t) => t.deleted.equals(false))).get();
    return rows.map((e) => e.id).toSet();
  }

  // ----------------------
  // Tags & Links index
  // ----------------------
  Future<void> replaceTagsForNote(String noteId, Set<String> tags) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      if (tags.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            noteTags,
            tags.map(
              (t) => NoteTagsCompanion.insert(noteId: noteId, tag: t),
            ),
          );
        });
      }
    });
  }

  Future<void> replaceLinksForNote(String noteId, List<LinkTarget> links) async {
    await transaction(() async {
      await (delete(noteLinks)..where((t) => t.sourceId.equals(noteId))).go();
      if (links.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            noteLinks,
            links.map(
              (l) => NoteLinksCompanion.insert(
                sourceId: noteId,
                targetTitle: l.title ?? '',
                targetId: Value(l.id),
              ),
            ),
          );
        });
      }
    });
  }

  Future<List<String>> distinctTags() async {
    final rows = await customSelect(
      '''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0
      ORDER BY LOWER(t.tag) ASC
      ''',
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
    }

  Future<List<LocalNote>> notesWithTag(String tag) async {
    final list = await customSelect(
      '''
      SELECT n.*
      FROM local_notes n
      JOIN note_tags t ON n.id = t.note_id
      WHERE n.deleted = 0 AND t.tag = ?
      ORDER BY n.updated_at DESC
      ''',
      variables: [Variable(tag)],
      readsFrom: {localNotes, noteTags},
    ).map<LocalNote>((row) => localNotes.map(row.data)).get();

    return list;
  }

  Future<List<BacklinkPair>> backlinksWithSources(String targetTitle) async {
    final links = await (select(noteLinks)
          ..where((l) => l.targetTitle.equals(targetTitle)))
        .get();

    if (links.isEmpty) return const <BacklinkPair>[];

    final sourceIds = links.map((l) => l.sourceId).toSet().toList();
    final sources = await (select(localNotes)
          ..where((n) => n.deleted.equals(false) & n.id.isIn(sourceIds)))
        .get();

    final byId = {for (final n in sources) n.id: n};
    return links
        .map((l) => BacklinkPair(link: l, source: byId[l.sourceId]))
        .toList();
  }

  // ----------------------
  // FTS5 support
  // ----------------------
  // Güvenli MATCH ifadesi oluştur
  String _ftsQuery(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) {
      var s = t.replaceAll('"', '').replaceAll("'", '');
      if (!s.endsWith('*')) s = '$s*';
      return s;
    }).toList();
    if (parts.isEmpty) return '';
    // Tüm kelimeler eşleşsin
    return parts.join(' AND ');
  }

  /// `#tag` => etiket, diğerleri => FTS5 MATCH (LIKE fallback)
  Future<List<LocalNote>> searchNotes(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      return allNotes();
    }

    String likeWrap(String s) {
      final esc = s.replaceAll('%', r'\%').replaceAll('_', r'\_');
      return '%$esc%';
    }

    if (q.startsWith('#')) {
      final needle = q.substring(1).trim();
      if (needle.isEmpty) return allNotes();

      final tagRows = await (select(noteTags)
            ..where((t) => t.tag.like(likeWrap(needle))))
          .get();

      final ids = tagRows.map((e) => e.noteId).toSet().toList();
      if (ids.isEmpty) return const <LocalNote>[];

      return (select(localNotes)
            ..where((t) => t.deleted.equals(false) & t.id.isIn(ids))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }

    final match = _ftsQuery(q);
    if (match.isEmpty) return allNotes();

    try {
      final res = await customSelect(
        '''
        SELECT n.*
        FROM local_notes n
        JOIN fts_notes f ON n.id = f.id
        WHERE n.deleted = 0
          AND f MATCH ?
        ORDER BY n.updated_at DESC
        ''',
        variables: [Variable(match)],
        readsFrom: {localNotes},
      ).map<LocalNote>((row) => localNotes.map(row.data)).get();

      return res;
    } catch (_) {
      // FTS bir nedenden hata verirse LIKE'a dönüş
      final needle = likeWrap(q);
      return (select(localNotes)
            ..where((t) =>
                t.deleted.equals(false) &
                (t.title.like(needle) | t.body.like(needle)))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }
  }
}

/// ----------------------
/// Connection (mobile)
/// ----------------------
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'duru.sqlite'));
    return NativeDatabase(file);
  });
}
