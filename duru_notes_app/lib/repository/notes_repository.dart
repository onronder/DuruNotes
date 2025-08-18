import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/parser/note_indexer.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/data/remote/supabase_note_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required this.db,
    required this.crypto,
    required this.client,
    required this.userId,
  }) : api = SupabaseNoteApi(client),
       _indexer = NoteIndexer(db);

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseClient client;
  final String userId;
  final SupabaseNoteApi api;
  final NoteIndexer _indexer;

  final _uuid = const Uuid();

  Future<String> createOrUpdate({
    required String title,
    required String body,
    String? id,
  }) async {
    final noteId = id ?? _uuid.v4();
    final now = DateTime.now();
    final n = LocalNote(
      id: noteId,
      title: title,
      body: body,
      updatedAt: now,
      deleted: false,
    );
    await db.upsertNote(n);
    await _indexer.updateIndex(n);
    await db.enqueue(noteId, 'upsert_note');
    return noteId;
  }

  Future<void> delete(String id) async {
    final n = await (db.select(
      db.localNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (n != null) {
      await db.upsertNote(n.copyWith(deleted: true, updatedAt: DateTime.now()));
      await db.enqueue(id, 'upsert_note');
    }
  }

  Future<void> pushAllPending() async {
    final ops = await db.getPendingOps();
    final processedIds = <int>[];

    for (final op in ops) {
      try {
        if (op.kind == 'upsert_note') {
          final n = await (db.select(
            db.localNotes,
          )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();
          if (n == null) {
            processedIds.add(op.id);
            continue;
          }
          final titleEnc = await crypto.encryptStringForNote(
            userId: userId,
            noteId: n.id,
            text: n.title,
          );
          final propsEnc = await crypto.encryptJsonForNote(
            userId: userId,
            noteId: n.id,
            json: {
              'body': n.body,
              'updatedAt': n.updatedAt.toIso8601String(),
              'deleted': n.deleted,
            },
          );
          await api.upsertEncryptedNote(
            id: n.id,
            titleEnc: titleEnc,
            propsEnc: propsEnc,
            deleted: n.deleted,
          );
          processedIds.add(op.id);
        }
      } on Object {
        // keep op for next attempt
      }
    }

    if (processedIds.isNotEmpty) {
      await db.deletePendingByIds(processedIds);
    }
  }

  Future<void> pullSince(DateTime? since) async {
    final rows = await api.fetchEncryptedNotes(since: since);
    for (final r in rows) {
      try {
        final id = r['id'] as String;
        final deleted = (r['deleted'] as bool?) ?? false;

        final titleEnc = SupabaseNoteApi.asBytes(r['title_enc']);
        final propsEnc = SupabaseNoteApi.asBytes(r['props_enc']);

        final title = await crypto.decryptStringForNote(
          userId: userId,
          noteId: id,
          data: titleEnc,
        );
        final props = await crypto.decryptJsonForNote(
          userId: userId,
          noteId: id,
          data: propsEnc,
        );
        final body = (props['body'] as String?) ?? '';
        final updatedAt =
            DateTime.tryParse((props['updatedAt'] as String?) ?? '') ??
            DateTime.now();

        final local = await (db.select(
          db.localNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local == null || local.updatedAt.isBefore(updatedAt)) {
          final n = LocalNote(
            id: id,
            title: title,
            body: body,
            updatedAt: updatedAt,
            deleted: deleted,
          );
          await db.upsertNote(n);
          await _indexer.updateIndex(n);
        }
      } on Object {
        // skip malformed rows
      }
    }
  }

  Future<Set<String>> fetchRemoteActiveIds() => api.fetchAllActiveIds();

  Future<void> reconcileHardDeletes(Set<String> remoteActiveIds) async {
    final localIds = await db.getLocalActiveNoteIds();
    final pending = await db.getPendingOps();
    final pendingIds = pending.map((p) => p.entityId).toSet();

    for (final id in localIds) {
      if (!remoteActiveIds.contains(id) && !pendingIds.contains(id)) {
        final n = await (db.select(
          db.localNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (n != null) {
          await db.upsertNote(
            n.copyWith(deleted: true, updatedAt: DateTime.now()),
          );
        }
      }
    }
  }

  Future<List<LocalNote>> list() => db.allNotes();
}
