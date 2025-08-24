// lib/repository/notes_repository.dart
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
  })  : api = SupabaseNoteApi(client),
        _indexer = NoteIndexer(db);

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseClient client;
  final String userId;
  final SupabaseNoteApi api;
  final NoteIndexer _indexer;
  final _uuid = const Uuid();

  String _stripBidi(String s) =>
      s.replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '');

  Future<String> createOrUpdate({
    required String title,
    required String body,
    String? id,
  }) async {
    final noteId = id ?? _uuid.v4();
    final now = DateTime.now();

    final n = LocalNote(
      id: noteId,
      title: _stripBidi(title.trim()),
      body: _stripBidi(body),
      updatedAt: now,
      deleted: false,
    );

    await db.upsertNote(n);
    await _indexer.updateIndex(n);
    await db.updateFtsForNote(n);
    await db.enqueue(noteId, 'upsert_note');
    return noteId;
  }

  Future<void> delete(String id) async {
    final n = await (db.select(db.localNotes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (n != null) {
      final deletedNote =
          n.copyWith(deleted: true, updatedAt: DateTime.now());
      await db.upsertNote(deletedNote);
      await _indexer.updateIndex(deletedNote);
      await db.updateFtsForNote(deletedNote);
      await db.enqueue(id, 'upsert_note');
    }
  }

  // ... (pushAllPending, pullSince, fetchRemoteActiveIds, reconcileHardDeletes, list)
}
