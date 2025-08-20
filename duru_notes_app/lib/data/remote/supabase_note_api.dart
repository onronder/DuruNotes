import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNoteApi {
  SupabaseNoteApi(this._client);
  final SupabaseClient _client;

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

  /// Active (deleted=false) remote IDs for hard-delete reconciliation.
  Future<Set<String>> fetchAllActiveIds() async {
    final dynamic res = await _client
        .from('notes')
        .select('id')
        .eq('user_id', _uid)
        .eq('deleted', false);

    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
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
