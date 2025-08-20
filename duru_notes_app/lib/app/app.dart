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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
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
  /// Linki içeren notun id’si
  TextColumn get sourceId => text()();

  /// Hedef başlık (ör. `[[Title]]` ya da `@Title` ile bulunur)
  TextColumn get targetTitle => text()();

  /// Opsiyonel hedef id (ör. `[[id: ]]` veya `@id: `)
  TextColumn get targetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId, targetTitle};
}

/// UI’da kullanmak için küçük bir taşıyıcı sınıf
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
  int get schemaVersion => 2;

  /// Migrations:
  /// v1: LocalNotes + PendingOps
  /// v2: + NoteTags + NoteLinks
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Tüm drift tablolarını oluştur
          await m.createAll();
          // FTS5 sanal tablosu oluştur. NOT: FTS tablosu drift tarafından
          // yönetilmez; customStatement kullanırız.
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(noteTags);
            await m.createTable(noteLinks);
          }
          // FTS tablosu yoksa upgrade sırasında oluştur
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
          );
        },
      );

  // ----------------------
  // Notes
  // ----------------------
  /// '@' önerileri için: başlığa göre not araması (prefix + kelime başı).
  Future<List<LocalNote>> suggestNotesByTitlePrefix(
    String query, {
    int limit = 8,
  }) {
    final q = query.trim();

    // Son güncellenenler en üstte; boş arama kısa liste döndürür.
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
          ..where(
            (t) =>
                t.deleted.equals(false) &
                // Başlangıç veya kelime başı eşleşmesi
                (t.title.like(startsWith) | t.title.like(wordStart)),
          )
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

  /// Tek not (yoksa null)
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

  Future<List<PendingOp>> getPendingOps() => (select(pendingOps)
        ..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

  Future<void> deletePendingByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(pendingOps)..where((t) => t.id.isIn(ids.toList()))).go();
  }

  /// Atomically fetch & clear (used by sync)
  Future<List<PendingOp>> dequeueAll() async {
    final ops = await (select(
      pendingOps,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
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
    final rows = await (select(
      localNotes,
    )..where((t) => t.deleted.equals(false))).get();
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

  // ----------------------
  // FTS5 support
  // ----------------------
  /// Güncel bir notu FTS tablosuna ekler veya günceller. Silinmiş notlarda
  /// başlık ve gövde boş bırakılır ki aramada görünmesin.
  Future<void> updateFtsForNote(LocalNote note) async {
    final titleText = note.deleted ? '' : note.title;
    final bodyText = note.deleted ? '' : note.body;
    await customStatement(
      '''
      INSERT INTO fts_notes(id, title, body)
      VALUES (?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET title = excluded.title, body = excluded.body
      ''',
      [note.id, titleText, bodyText],
    );
  }

  /// Belirli bir notu FTS tablosundan siler.
  Future<void> deleteFromFts(String id) async {
    await customStatement('DELETE FROM fts_notes WHERE id = ?', [id]);
  }

  /// Tüm aktif notları FTS tablosuna yeniden indeksler.
  Future<void> rebuildFtsIndex() async {
    final notes = await (select(localNotes)
          ..where((t) => t.deleted.equals(false)))
        .get();
    for (final n in notes) {
      await updateFtsForNote(n);
    }
  }

  /// Basit lokal arama:
  /// - `#tag` ile başlarsa: etiket tablosunda arama
  /// - değilse: başlık + gövde için FTS5 `MATCH` araması
  Future<List<LocalNote>> searchNotes(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      return allNotes();
    }

    String likeWrap(String s) {
      final esc = s.replaceAll('%', r'\%').replaceAll('_', r'\_');
      return '%$esc%';
    }

    // Tag araması (ör. "#work")
    if (q.startsWith('#')) {
      final needle = q.substring(1).trim();
      if (needle.isEmpty) return allNotes();

      final tagRows = await (select(
        noteTags,
      )..where((t) => t.tag.like(likeWrap(needle)))).get();

      final ids = tagRows.map((e) => e.noteId).toSet().toList();
      if (ids.isEmpty) return [];

      return (select(localNotes)
            ..where((t) => t.deleted.equals(false) & t.id.isIn(ids))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }

    // FTS5 araması: MATCH operatörü büyük/küçük harfe duyarsız ve
    // hızlıdır. '*' ekleyerek prefix aramalar yapılabilir.
    final ftsQuery = q;
    final res = await customSelect(
      '''
      SELECT local_notes.*
      FROM local_notes
      JOIN fts_notes ON local_notes.id = fts_notes.id
      WHERE local_notes.deleted = 0
        AND fts_notes MATCH ?
      ORDER BY local_notes.updated_at DESC
      ''',
      variables: [Variable(ftsQuery)],
      readsFrom: {localNotes},
    ).map(localNotes.map).get();
    return res;
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
