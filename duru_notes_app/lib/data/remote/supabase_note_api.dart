import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNoteApi {
  SupabaseNoteApi(this._client);
  final SupabaseClient _client;

  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {
    await _client.from('notes').upsert({
      'id': id,
      'title_enc': titleEnc,
      'props_enc': propsEnc,
      'deleted': deleted,
    });
  }

  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async {
    var query = _client
        .from('notes')
        .select('id, updated_at, title_enc, props_enc, deleted');
    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }
    final dynamic res = await query;
    return _normalizeListOfMaps(res);
  }

  // Active (deleted=false) remote IDs for hard-delete reconciliation
  Future<Set<String>> fetchAllActiveIds() async {
    final dynamic res = await _client
        .from('notes')
        .select('id')
        .eq('deleted', false);
    final list = _normalizeListOfMaps(res);
    return list.map((m) => m['id'] as String).toSet();
  }

  static List<Map<String, dynamic>> _normalizeListOfMaps(dynamic res) {
    if (res is List) {
      if (res.isEmpty) return <Map<String, dynamic>>[];
      final first = res.first;
      if (first is Map) {
        return res.cast<Map<String, dynamic>>();
      }
      if (first is List) {
        final nested = first; // no unnecessary cast
        if (nested.isEmpty) return <Map<String, dynamic>>[];
        return nested.cast<Map<String, dynamic>>();
      }
    }
    if (res is Map) {
      return <Map<String, dynamic>>[res.cast<String, dynamic>()];
    }
    throw StateError('Unexpected select result shape: ${res.runtimeType}');
  }

  static Uint8List asBytes(dynamic v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());
    if (v is String) {
      if (v.startsWith(r'\x')) {
        final hex = v.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }
      try {
        return base64Decode(v);
      } on FormatException {
        return Uint8List.fromList(utf8.encode(v));
      }
    }
    throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
  }
}
