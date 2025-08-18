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
  Set<GeneratedColumn> get primaryKey => {id};
}

@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  /// 'upsert_note' | 'delete_note'
  TextColumn get kind => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();

  @override
  Set<GeneratedColumn> get primaryKey => {noteId, tag};
}

@DataClassName('NoteLink')
class NoteLinks extends Table {
  /// Linki içeren notun id’si
  TextColumn get sourceId => text()();

  /// Hedef başlık (ör. [[Title]] ya da @Title ile bulunur)
  TextColumn get targetTitle => text()();

  /// Opsiyonel hedef id (ör. [[id:<UUID>]] veya @id:<UUID>)
  TextColumn get targetId => text().nullable()();

  @override
  Set<GeneratedColumn> get primaryKey => {sourceId, targetTitle};
}

/// UI’da kullanmak için küçük bir taşıyıcı sınıf
class BacklinkPair {
  final NoteLink link;
  final LocalNote? source;
  const BacklinkPair({required this.link, this.source});
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
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(noteTags);
            await m.createTable(noteLinks);
          }
        },
      );

  // ----------------------
  // Notes
  // ----------------------

  /// '@' autocomplete için başlığa göre öneri (prefix + kelime başı eşleşmesi).
  Future<List<LocalNote>> suggestNotesByTitlePrefix(
    String query, {
    int limit = 8,
  }) {
    final q = query.trim();

    // Boş sorguda en son güncellenenler
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
                (t.title.like(startsWith) | t.title.like(wordStart)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)])
          ..limit(limit))
        .get();
  }

  Future<List<LocalNote>> allNotes() => (select(localNotes)
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

  Future<void> enqueue(String entityId, String kind, {String? payload}) =>
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

  /// Atomik fetch & clear (sync için)
  Future<List<PendingOp>> dequeueAll() async {
    final ops =
        await (select(pendingOps)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
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
    });
  }

  Future<Set<String>> getLocalActiveNoteIds() async {
    final rows =
        await (select(localNotes)..where((t) => t.deleted.equals(false))).get();
    return rows.map((e) => e.id).toSet();
  }

  // ----------------------
  // Tags index
  // ----------------------

  Future<void> replaceTagsForNote(String noteId, Set<String> tags) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      if (tags.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            noteTags,
            tags.map((t) => NoteTagsCompanion.insert(noteId: noteId, tag: t)),
          );
        });
      }
    });
  }

  Future<Set<String>> tagsOf(String noteId) async {
    final rows =
        await (select(noteTags)..where((t) => t.noteId.equals(noteId))).get();
    return rows.map((e) => e.tag).toSet();
  }

  Future<List<String>> distinctTags() async {
    final q = customSelect(
      'SELECT DISTINCT tag FROM note_tags',
      readsFrom: {noteTags},
    );
    final rows = await q.get();
    final list = <String>[];
    for (final r in rows) {
      final v = r.data['tag'];
      if (v is String && v.isNotEmpty) list.add(v);
    }
    list.sort();
    return list;
  }

  Future<List<String>> noteIdsWithTag(String tag) async {
    final rows =
        await (select(noteTags)..where((t) => t.tag.equals(tag))).get();
    return rows.map((e) => e.noteId).toList();
  }

  Future<List<LocalNote>> notesWithTag(String tag) async {
    final ids = await noteIdsWithTag(tag);
    if (ids.isEmpty) return <LocalNote>[];
    return (select(localNotes)
          ..where((t) => t.deleted.equals(false) & t.id.isIn(ids))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  // ----------------------
  // Links index
  // ----------------------

  /// Parser bazı durumlarda `title` veya `id` üretebilir.
  /// DB’de `targetTitle` NOT NULL olduğu için sanitize ediyoruz.
  Future<void> replaceLinksForNote(
    String noteId,
    List<LinkTarget> links,
  ) async {
    await transaction(() async {
      await (delete(noteLinks)..where((t) => t.sourceId.equals(noteId))).go();

      if (links.isNotEmpty) {
        final rows = <NoteLinksCompanion>[];
        for (final l in links) {
          final safeTitle = ((l.title ?? l.id) ?? '').trim();
          if (safeTitle.isEmpty) continue; // boş başlıkla kaydetme
          rows.add(
            NoteLinksCompanion.insert(
              sourceId: noteId,
              targetTitle: safeTitle,
              targetId: Value(l.id),
            ),
          );
        }
        if (rows.isNotEmpty) {
          await batch((b) => b.insertAll(noteLinks, rows));
        }
      }
    });
  }

  Future<List<NoteLink>> backlinksForTitle(String title) {
    return (select(noteLinks)..where((t) => t.targetTitle.equals(title))).get();
  }

  /// Backlink satırları + opsiyonel kaynak not (başlık gösterebilmek için)
  Future<List<BacklinkPair>> backlinksWithSources(String title) async {
    final rows = await (select(noteLinks).join([
      leftOuterJoin(localNotes, localNotes.id.equalsExp(noteLinks.sourceId)),
    ])..where(noteLinks.targetTitle.equals(title)))
        .get();

    return rows
        .map(
          (r) => BacklinkPair(
            link: r.readTable(noteLinks),
            source: r.readTableOrNull(localNotes),
          ),
        )
        .toList();
  }

  /// Basit lokal arama.
  /// - Genel arama: başlık + gövdede LIKE
  /// - #tag ile başlarsa: tag tablosundan eşleşen notlar
  Future<List<LocalNote>> searchNotes(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return allNotes();

    String likeWrap(String s) {
      final esc = s.replaceAll('%', r'\%').replaceAll('_', r'\_');
      return '%$esc%';
    }

    // Tag araması (#work gibi)
    if (q.startsWith('#')) {
      final needle = q.substring(1).trim();
      if (needle.isEmpty) return allNotes();

      final tagRows =
          await (select(noteTags)..where((t) => t.tag.like(likeWrap(needle))))
              .get();

      final ids = tagRows.map((e) => e.noteId).toSet().toList();
      if (ids.isEmpty) return <LocalNote>[];

      return (select(localNotes)
            ..where((t) => t.deleted.equals(false) & t.id.isIn(ids))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }

    // Genel arama (başlık + gövde)
    final pattern = likeWrap(q);
    return (select(localNotes)
          ..where((t) =>
              t.deleted.equals(false) &
              (t.title.like(pattern) | t.body.like(pattern)))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
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
