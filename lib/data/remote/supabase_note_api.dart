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
  ///
  /// [createdAt] should be provided for new notes to ensure timestamp consistency
  /// across all devices. For existing notes being updated, this can be null.
  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
    DateTime? createdAt,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': _uid, // RLS için önemli
      'title_enc': titleEnc,
      'props_enc': propsEnc,
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Include created_at if provided (for new notes) to ensure exact
    // timestamp consistency across all devices during sync
    if (createdAt != null) {
      row['created_at'] = createdAt.toIso8601String();
    }

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
      if (t != null) m['title_enc'] = _normalizeSecretBoxBytes(t);
      if (p != null) m['props_enc'] = _normalizeSecretBoxBytes(p);
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
      if (n != null) m['name_enc'] = _normalizeSecretBoxBytes(n);
      if (p != null) m['props_enc'] = _normalizeSecretBoxBytes(p);
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
  Future<void> removeNoteFolderRelation({required String noteId}) async {
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

  /// Fetch tags associated with notes for the current user.
  Future<List<Map<String, dynamic>>> fetchNoteTags({DateTime? since}) async {
    var query = _client
        .from('note_tags')
        .select('note_id, tag, user_id, metadata, created_at')
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('created_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
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
  /// - `List<int>` or `List<dynamic>` (from JSON)
  /// - Map (libsodium JSON format): {"n":"nonce", "c":"ciphertext", "m":"mac"}
  /// - String: may be Postgres bytea hex (\\xABCD...), base64, or fallback UTF-8
  ///
  /// This utility is used for both note and folder encrypted data conversion.
  static Uint8List asBytes(dynamic v) {
    // CRITICAL FIX: When Supabase returns bytea as List<int>, it may be the bytes
    // of a base64 string, not the actual encrypted data. We must decode it.
    if (v is Uint8List || v is List<int> || v is List<dynamic>) {
      final bytes = v is Uint8List
          ? v
          : (v is List<int>
                ? Uint8List.fromList(v)
                : Uint8List.fromList((v as List<dynamic>).cast<int>()));

      // Try to decode as UTF-8 string first
      try {
        final str = utf8.decode(bytes);

        // If it's a JSON string (starts with '{'), handle it below
        if (str.startsWith('{') && str.contains('"n"') && str.contains('"c"')) {
          try {
            final jsonMap = jsonDecode(str) as Map<String, dynamic>;
            return asBytes(jsonMap); // Recursively handle the map
          } on FormatException {
            // Not valid JSON, continue
          }
        }

        // If it's a base64 string, decode it
        // Base64 strings only contain [A-Za-z0-9+/=]
        if (_isBase64String(str)) {
          try {
            return base64Decode(str);
          } on FormatException {
            // Not valid base64, return original bytes
            return bytes;
          }
        }

        // Otherwise return original bytes
        return bytes;
      } on FormatException {
        // Not valid UTF-8, return original bytes
        return bytes;
      }
    }

    // PRODUCTION FIX: Handle libsodium JSON format {"n":"...", "c":"...", "m":"..."}
    // This is the format Supabase stores encrypted data in
    if (v is Map<String, dynamic>) {
      final nonce = v['n'] as String?;
      final ciphertext = v['c'] as String?;
      final mac = v['m'] as String?;

      if (nonce != null && ciphertext != null) {
        // Combine into libsodium secretbox format:
        // [nonce (24 bytes)][mac (16 bytes)][ciphertext]
        final nonceBytes = base64Decode(nonce);
        final ciphertextBytes = base64Decode(ciphertext);
        final macBytes = mac != null ? base64Decode(mac) : Uint8List(0);

        // libsodium uses [nonce][mac+ciphertext] format
        final combined = Uint8List(
          nonceBytes.length + macBytes.length + ciphertextBytes.length,
        );
        combined.setRange(0, nonceBytes.length, nonceBytes);
        combined.setRange(
          nonceBytes.length,
          nonceBytes.length + macBytes.length,
          macBytes,
        );
        combined.setRange(
          nonceBytes.length + macBytes.length,
          combined.length,
          ciphertextBytes,
        );

        return combined;
      }
    }

    if (v is String) {
      // PRODUCTION FIX: Try to parse as JSON first (for string-encoded libsodium format)
      if (v.startsWith('{') && v.contains('"n"') && v.contains('"c"')) {
        try {
          final jsonMap = jsonDecode(v) as Map<String, dynamic>;
          return asBytes(jsonMap); // Recursively handle the map
        } on FormatException {
          // Not valid JSON, continue with other string formats
        }
      }

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

  static Uint8List _normalizeSecretBoxBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List<dynamic>) {
      return Uint8List.fromList(value.cast<int>());
    }

    if (value is Map<String, dynamic>) {
      return Uint8List.fromList(utf8.encode(jsonEncode(value)));
    }

    if (value is String) {
      final trimmed = value.trim();

      if (trimmed.startsWith('{') &&
          trimmed.contains('"n"') &&
          trimmed.contains('"c"')) {
        return Uint8List.fromList(utf8.encode(trimmed));
      }

      if (trimmed.startsWith(r'\x')) {
        final hex = trimmed.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final arr = (jsonDecode(trimmed) as List).cast<num>();
          return Uint8List.fromList(arr.map((n) => n.toInt()).toList());
        } catch (_) {
          // Ignore and fall through to other decoders
        }
      }

      if (_isBase64String(trimmed)) {
        try {
          return base64Decode(trimmed);
        } on FormatException {
          // Ignore and fall through to UTF-8 fallback
        }
      }

      return Uint8List.fromList(utf8.encode(trimmed));
    }

    throw UnsupportedError(
      'Unsupported secretbox payload type: ${value.runtimeType}',
    );
  }

  /// Helper to check if a string looks like base64
  /// Base64 only contains: A-Z, a-z, 0-9, +, /, =
  static bool _isBase64String(String str) {
    if (str.isEmpty) return false;
    // Base64 strings should be at least a few characters long
    if (str.length < 4) return false;
    // Check if all characters are valid base64
    return RegExp(r'^[A-Za-z0-9+/]+=*$').hasMatch(str);
  }

  // ----------------------
  // Task Operations
  // ----------------------

  /// Fetch note tasks, optionally since a given timestamp.
  /// Returns tasks for all notes owned by the current user.
  ///
  /// Each task contains:
  /// - id: Task UUID
  /// - note_id: The ID of the parent note
  /// - content: Task description/content
  /// - status: Task status (pending, in_progress, completed, cancelled)
  /// - priority: Task priority (0-5)
  /// - due_date: Optional due date
  /// - completed_at: When task was completed
  /// - parent_id: Parent task ID for hierarchical tasks
  /// - created_at, updated_at: Timestamps
  /// - deleted: Soft deletion flag
  Future<List<Map<String, dynamic>>> fetchNoteTasks({DateTime? since}) async {
    var query = _client
        .from('note_tasks')
        .select('''
          id, note_id, user_id, content, status, priority, position,
          due_date, completed_at, parent_id, labels, metadata,
          created_at, updated_at, deleted
        ''')
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    return _normalizeListOfMaps(res);
  }

  /// Fetch active (non-deleted) task IDs for reconciliation
  Future<Set<String>> fetchAllActiveTaskIds() async {
    final dynamic res = await _client
        .from('note_tasks')
        .select('id')
        .eq('user_id', _uid)
        .eq('deleted', false);

    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
  }

  // ----------------------
  // Attachment Operations
  // ----------------------

  /// Fetch attachments for the current user (excludes soft-deleted records).
  Future<List<Map<String, dynamic>>> fetchAttachments({DateTime? since}) async {
    var query = _client
        .from('attachments')
        .select('''
          id,
          user_id,
          note_id,
          file_name,
          storage_path,
          mime_type,
          size,
          url,
          uploaded_at,
          created_at,
          deleted
        ''')
        .eq('user_id', _uid)
        .eq('deleted', false);

    if (since != null) {
      query = query.gte('created_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    return _normalizeListOfMaps(res);
  }

  /// Fetch active (non-deleted) attachment IDs for reconciliation.
  Future<Set<String>> fetchAllActiveAttachmentIds() async {
    final dynamic res = await _client
        .from('attachments')
        .select('id')
        .eq('user_id', _uid)
        .eq('deleted', false);

    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
  }

  /// Upsert task to the remote 'note_tasks' table
  ///
  /// Parameters:
  /// - [id]: Task UUID
  /// - [noteId]: Parent note UUID
  /// - [content]: Task description
  /// - [status]: Task status (pending, in_progress, completed, cancelled)
  /// - [priority]: Priority level (0-5)
  /// - [dueDate]: Optional due date
  /// - [parentId]: Optional parent task for hierarchy
  /// - [deleted]: Soft deletion flag
  Future<void> upsertNoteTask({
    required String id,
    required String noteId,
    required String content,
    required String status,
    int priority = 0,
    int position = 0,
    DateTime? dueDate,
    DateTime? completedAt,
    String? parentId,
    Map<String, dynamic>? labels,
    Map<String, dynamic>? metadata,
    required bool deleted,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'note_id': noteId,
      'user_id': _uid,
      'content': content,
      'status': status,
      'priority': priority,
      'position': position,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'parent_id': parentId,
      'labels': labels ?? const <String, dynamic>{'labels': <String>[]},
      'metadata': metadata ?? <String, dynamic>{},
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('note_tasks').upsert(row);
  }

  /// Soft delete task by marking it as deleted.
  Future<void> deleteNoteTask({required String id}) async {
    await _client
        .from('note_tasks')
        .update({
          'deleted': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _uid);
  }

  // ----------------------
  // Template Operations
  // ----------------------

  /// Fetch encrypted templates, optionally since a given timestamp.
  Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async {
    var query = _client
        .from('templates')
        .select('''
          id, user_id, title_enc, body_enc, tags_enc, description_enc,
          category, icon, sort_order, props_enc, is_system, deleted,
          created_at, updated_at
          ''')
        .eq('user_id', _uid);

    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    final dynamic res = await query;
    return _normalizeListOfMaps(res);
  }

  /// Upsert template to the remote 'templates' table.
  Future<void> upsertTemplate({
    required String id,
    required String userId,
    required String titleEnc,
    required String bodyEnc,
    String? tagsEnc,
    required bool isSystem,
    required String category,
    String? descriptionEnc,
    String? icon,
    int sortOrder = 0,
    String? propsEnc,
    required bool deleted,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title_enc': titleEnc,
      'body_enc': bodyEnc,
      'tags_enc': tagsEnc,
      'description_enc': descriptionEnc,
      'category': category,
      'icon': icon ?? 'description',
      'sort_order': sortOrder,
      'props_enc': propsEnc,
      'is_system': isSystem,
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('templates').upsert(row);
  }

  /// Soft delete template by marking it as deleted remotely.
  Future<void> deleteTemplate({required String id}) async {
    await _client
        .from('templates')
        .update({
          'deleted': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _uid);
  }

  // ----------------------
  // Reminder Operations
  // ----------------------

  /// PRODUCTION: Get all reminders for the current user
  /// Filters by user_id directly (no need to join with notes)
  Future<List<Map<String, dynamic>>> getReminders() async {
    final dynamic res = await _client
        .from('reminders')
        .select('''
          id,
          note_id,
          user_id,
          title,
          body,
          type,
          remind_at,
          is_active,
          recurrence_pattern,
          recurrence_interval,
          recurrence_end_date,
          latitude,
          longitude,
          radius,
          location_name,
          snoozed_until,
          snooze_count,
          trigger_count,
          last_triggered,
          created_at,
          updated_at
        ''')
        .eq('user_id', _uid);

    return _normalizeListOfMaps(res);
  }

  /// PRODUCTION: Upsert a reminder to Supabase
  /// Creates or updates a reminder in the reminders table
  Future<void> upsertReminder(Map<String, dynamic> reminderData) async {
    // Ensure updated_at is set
    final row = Map<String, dynamic>.from(reminderData);
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await _client.from('reminders').upsert(row);
  }

  /// PRODUCTION: Delete a reminder from Supabase
  /// Hard delete since reminders don't need soft delete
  Future<void> deleteReminder(String reminderId) async {
    await _client.from('reminders').delete().eq('id', reminderId);
  }
}
