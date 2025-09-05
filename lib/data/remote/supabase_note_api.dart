import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// API for Supabase operations with notes, folders, and relationships.
/// 
/// IMPORTANT DATA TYPE HANDLING:
/// - Remote DB (Supabase): Uses UUID type for all IDs
/// - Local DB (Drift): Uses TEXT type for all IDs (stores UUIDs as strings)
/// - Supabase Dart client automatically converts between UUID and String
/// - This API layer works with String IDs for compatibility with local DB
class SupabaseNoteApi {
  SupabaseNoteApi(this._client);
  final SupabaseClient _client;
  
  static const _uuid = Uuid();

  /// Generate a new UUID string for use as an ID.
  /// This ensures compatibility between local TEXT storage and remote UUID storage.
  static String generateId() => _uuid.v4();

  /// Convenience getter for the current authenticated user's id.
  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('Not authenticated');
    }
    return uid;
  }

  /// Upsert encrypted note to the remote 'notes' table.
  /// Soft delete senaryosunda [deleted] alanı true gönderilir.
  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': _uid, // RLS için önemli
      'title_enc': titleEnc,
      'props_enc': propsEnc,
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // onConflict: 'id' çoğu kurulumda opsiyoneldir; tablo PK/UK doğruysa plain upsert yeterli.
    // Ancak bazı sürümlerde parametre ismi farklı olabilir. Sorun yaşarsanız onConflict ekleyin:
    // await _client.from('notes').upsert(row, onConflict: 'id');
    await _client.from('notes').upsert(row);
  }

  /// Pull remote notes, optionally since a given timestamp.
  /// Returns a list of maps with 'title_enc' and 'props_enc' converted to Uint8List.
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async {
    var query = _client
        .from('notes')
        .select(
          'id, user_id, created_at, updated_at, title_enc, props_enc, deleted',
        )
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    final list = _normalizeListOfMaps(res);

    // Normalize bytes to Uint8List for easier downstream use.
    for (final m in list) {
      final t = m['title_enc'];
      final p = m['props_enc'];
      if (t != null) m['title_enc'] = asBytes(t);
      if (p != null) m['props_enc'] = asBytes(p);
    }
    return list;
  }

  /// Active (deleted=false) remote note IDs for hard-delete reconciliation.
  Future<Set<String>> fetchAllActiveIds() async {
    final dynamic res = await _client
        .from('notes')
        .select('id')
        .eq('user_id', _uid)
        .eq('deleted', false);

    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
  }

  // ----------------------
  // Folder Operations
  // ----------------------

  /// Upsert encrypted folder to the remote 'folders' table.
  /// Soft delete scenarios send [deleted] as true.
  /// 
  /// The folder structure uses:
  /// - [id]: UUID string - must be valid UUID format for Supabase UUID field
  /// - [nameEnc]: Encrypted folder name
  /// - [propsEnc]: Encrypted folder properties (parentId, color, icon, description, sortOrder)
  /// 
  /// Note: Supabase will automatically convert the String ID to UUID type.
  /// Use SupabaseNoteApi.generateId() to create new UUIDs.
  Future<void> upsertEncryptedFolder({
    required String id,
    required Uint8List nameEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': _uid, // RLS için önemli
      'name_enc': nameEnc,
      'props_enc': propsEnc,
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('folders').upsert(row);
  }

  /// Pull remote folders, optionally since a given timestamp.
  /// Returns a list of maps with 'name_enc' and 'props_enc' converted to Uint8List.
  Future<List<Map<String, dynamic>>> fetchEncryptedFolders({
    DateTime? since,
  }) async {
    var query = _client
        .from('folders')
        .select(
          'id, user_id, created_at, updated_at, name_enc, props_enc, deleted',
        )
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    final list = _normalizeListOfMaps(res);

    // Normalize bytes to Uint8List for easier downstream use.
    for (final m in list) {
      final n = m['name_enc'];
      final p = m['props_enc'];
      if (n != null) m['name_enc'] = asBytes(n);
      if (p != null) m['props_enc'] = asBytes(p);
    }
    return list;
  }

  /// Active (deleted=false) remote folder IDs for hard-delete reconciliation.
  Future<Set<String>> fetchAllActiveFolderIds() async {
    final dynamic res = await _client
        .from('folders')
        .select('id')
        .eq('user_id', _uid)
        .eq('deleted', false);

    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
  }

  // ----------------------
  // Note-Folder Relationship Operations
  // ----------------------

  /// Upsert note-folder relationship to the remote 'note_folders' table.
  /// This manages which folder a note belongs to.
  /// 
  /// Parameters:
  /// - [noteId]: UUID string of the note (must exist in notes table)
  /// - [folderId]: UUID string of the folder (must exist in folders table)
  /// 
  /// Note: A note can only be in one folder at a time in this implementation.
  /// To move a note to a different folder, upsert with the new folderId.
  /// To remove a note from all folders, use removeNoteFolderRelation().
  Future<void> upsertNoteFolderRelation({
    required String noteId,
    required String folderId,
  }) async {
    final row = <String, dynamic>{
      'note_id': noteId,
      'folder_id': folderId,
      'user_id': _uid, // RLS için önemli
      'added_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('note_folders').upsert(row);
  }

  /// Remove note-folder relationship from the remote 'note_folders' table.
  /// This effectively moves the note to "unfiled" status.
  Future<void> removeNoteFolderRelation({
    required String noteId,
  }) async {
    await _client
        .from('note_folders')
        .delete()
        .eq('user_id', _uid)
        .eq('note_id', noteId);
  }

  /// Fetch note-folder relationships, optionally since a given timestamp.
  /// Returns relationships for all notes and folders owned by the current user.
  /// 
  /// Each relationship contains:
  /// - note_id: The ID of the note
  /// - folder_id: The ID of the folder containing the note
  /// - added_at: When the note was added to the folder
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelations({
    DateTime? since,
  }) async {
    var query = _client
        .from('note_folders')
        .select('note_id, folder_id, user_id, added_at')
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('added_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    return _normalizeListOfMaps(res);
  }

  /// Fetch note-folder relationships for specific notes.
  /// Useful for syncing folder assignments for a batch of notes.
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelationsForNotes(
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return [];

    final dynamic res = await _client
        .from('note_folders')
        .select('note_id, folder_id, user_id, added_at')
        .eq('user_id', _uid)
        .inFilter('note_id', noteIds);

    return _normalizeListOfMaps(res);
  }

  /// Fetch note-folder relationships for a specific folder.
  /// Useful for getting all notes in a folder during sync operations.
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelationsForFolder(
    String folderId,
  ) async {
    final dynamic res = await _client
        .from('note_folders')
        .select('note_id, folder_id, user_id, added_at')
        .eq('user_id', _uid)
        .eq('folder_id', folderId);

    return _normalizeListOfMaps(res);
  }

  /// Supabase PostgREST select may return a List<Map>, Map, or nested List shape.
  static List<Map<String, dynamic>> _normalizeListOfMaps(dynamic res) {
    if (res is List) {
      if (res.isEmpty) return <Map<String, dynamic>>[];
      final first = res.first;
      if (first is Map) {
        return res.cast<Map<String, dynamic>>();
      }
      if (first is List) {
        final nested = first;
        if (nested.isEmpty) return <Map<String, dynamic>>[];
        return nested.cast<Map<String, dynamic>>();
      }
    }
    if (res is Map) {
      return <Map<String, dynamic>>[res.cast<String, dynamic>()];
    }
    throw StateError('Unexpected select result shape: ${res.runtimeType}');
  }

  /// Convert various possible wire formats to Uint8List:
  /// - Uint8List (already bytes)
  /// - List<int> or List<dynamic> (from JSON)
  /// - String: may be Postgres bytea hex (\\xABCD...), base64, or fallback UTF-8
  /// 
  /// This utility is used for both note and folder encrypted data conversion.
  static Uint8List asBytes(dynamic v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());
    if (v is String) {
      // Postgres bytea wire format: \xABCD...
      if (v.startsWith(r'\x')) {
        final hex = v.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }
      // Try base64; if not, treat as UTF-8 (defensive).
      try {
        return base64Decode(v);
      } on FormatException {
        return Uint8List.fromList(utf8.encode(v));
      }
    }
    throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
  }
}
