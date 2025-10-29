import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'package:duru_notes/core/crypto/key_manager.dart';

/// Result wrapper for decrypt operations that may use a legacy key fallback
/// [value] is the decrypted payload, [usedLegacyKey] indicates a legacy device key was used
class DecryptResult<T> {
  const DecryptResult({required this.value, required this.usedLegacyKey});
  final T value;
  final bool usedLegacyKey;
}

class CryptoBox {
  CryptoBox(this._keys);

  final KeyManager _keys;
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Cipher _cipher = Xchacha20.poly1305Aead();

  Future<Uint8List> encryptJsonForNote({
    required String userId,
    required String noteId,
    required Map<String, dynamic> json,
  }) async {
    final plaintext = utf8.encode(jsonEncode(json));
    final sb = await _encrypt(
      userId: userId,
      noteId: noteId,
      plaintext: plaintext,
    );
    return _serializeSecretBox(sb);
  }

  Future<Map<String, dynamic>> decryptJsonForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final sb = _deserializeSecretBox(data);
    final bytes = await _decrypt(userId: userId, noteId: noteId, box: sb);
    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      // Be tolerant: take first map if present, otherwise wrap as body
      if (decoded.isNotEmpty && decoded.first is Map) {
        return (decoded.first as Map).cast<String, dynamic>();
      }
      return <String, dynamic>{
        'body': decoded.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
        'deleted': false,
      };
    }
    // As a last resort, treat as plain body string.
    return <String, dynamic>{
      'body': decoded.toString(),
      'updatedAt': DateTime.now().toIso8601String(),
      'deleted': false,
    };
  }

  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async {
    final sb = await _encrypt(
      userId: userId,
      noteId: noteId,
      plaintext: utf8.encode(text),
    );
    return _serializeSecretBox(sb);
  }

  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final sb = _deserializeSecretBox(data);
    final bytes = await _decrypt(userId: userId, noteId: noteId, box: sb);
    return utf8.decode(bytes);
  }

  /// Decrypt JSON trying AMK first, then legacy device key as fallback
  Future<DecryptResult<Map<String, dynamic>>> decryptJsonForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final sb = _deserializeSecretBox(data);
    try {
      final bytes = await _decrypt(userId: userId, noteId: noteId, box: sb);
      final decoded = jsonDecode(utf8.decode(bytes));
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'body': decoded.toString()};
      return DecryptResult<Map<String, dynamic>>(
        value: map,
        usedLegacyKey: false,
      );
    } catch (_) {
      // Try legacy key
      final bytes = await _decryptWithLegacy(
        userId: userId,
        noteId: noteId,
        box: sb,
      );
      final decoded = jsonDecode(utf8.decode(bytes));
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'body': decoded.toString()};
      return DecryptResult<Map<String, dynamic>>(
        value: map,
        usedLegacyKey: true,
      );
    }
  }

  /// Decrypt String trying AMK first, then legacy device key as fallback
  Future<DecryptResult<String>> decryptStringForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final sb = _deserializeSecretBox(data);
    try {
      final bytes = await _decrypt(userId: userId, noteId: noteId, box: sb);
      return DecryptResult<String>(
        value: utf8.decode(bytes),
        usedLegacyKey: false,
      );
    } catch (_) {
      final bytes = await _decryptWithLegacy(
        userId: userId,
        noteId: noteId,
        box: sb,
      );
      return DecryptResult<String>(
        value: utf8.decode(bytes),
        usedLegacyKey: true,
      );
    }
  }

  Future<SecretBox> _encrypt({
    required String userId,
    required String noteId,
    required List<int> plaintext,
  }) async {
    final key = await _deriveKey(userId: userId, noteId: noteId);
    final nonce = _cipher.newNonce();
    return _cipher.encrypt(plaintext, secretKey: key, nonce: nonce);
  }

  Future<List<int>> _decrypt({
    required String userId,
    required String noteId,
    required SecretBox box,
  }) async {
    final key = await _deriveKey(userId: userId, noteId: noteId);
    return _cipher.decrypt(box, secretKey: key);
  }

  Future<List<int>> _decryptWithLegacy({
    required String userId,
    required String noteId,
    required SecretBox box,
  }) async {
    final key = await _deriveLegacyKey(userId: userId, noteId: noteId);
    return _cipher.decrypt(box, secretKey: key);
  }

  Future<SecretKey> _deriveKey({
    required String userId,
    required String noteId,
  }) async {
    final master = await _keys.getOrCreateMasterKey(userId);
    final salt = utf8.encode('note:$noteId');
    return _hkdf.deriveKey(secretKey: master, nonce: salt);
  }

  Future<SecretKey> _deriveLegacyKey({
    required String userId,
    required String noteId,
  }) async {
    final legacy = await _keys.getLegacyMasterKey(userId);
    final salt = utf8.encode('note:$noteId');
    return _hkdf.deriveKey(secretKey: legacy, nonce: salt);
  }

  Uint8List _serializeSecretBox(SecretBox sb) {
    final map = <String, String>{
      'n': base64Encode(sb.nonce),
      'c': base64Encode(sb.cipherText),
      'm': base64Encode(sb.mac.bytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  SecretBox _deserializeSecretBox(Uint8List data) {
    try {
      // Handle the case where data is a List<int> representing UTF-8 bytes
      String jsonString;
      if (data.every((byte) => byte >= 0 && byte <= 255)) {
        // Check if data is actually a list of bytes that need to be converted to string
        try {
          jsonString = utf8.decode(data);
        } catch (e) {
          // If UTF-8 decode fails, treat as raw JSON
          jsonString = String.fromCharCodes(data);
        }
      } else {
        jsonString = utf8.decode(data);
      }

      final decoded = jsonDecode(jsonString);
      // Removed excessive debug logging to prevent log spam during sync
      // debugPrint('🔍 SecretBox data structure: ${decoded.runtimeType}');

      if (decoded is Map<String, dynamic>) {
        final resolved = _extractSecretBoxComponents(decoded);
        if (resolved != null) {
          return SecretBox(
            resolved.cipherText,
            nonce: resolved.nonce,
            mac: Mac(resolved.mac),
          );
        }
        // Only log when there's actually an error - missing required keys
        debugPrint(
          '❌ Missing required keys. Expected: n, c, m. Found: ${decoded.keys.toList()}',
        );
      }

      // Handle the case where Supabase returns the JSON as a List<int>
      if (decoded is List<dynamic>) {
        try {
          // Convert List<int> back to string and parse as JSON
          final bytes = decoded.cast<int>();
          final jsonStr = utf8.decode(bytes);
          final actualData = jsonDecode(jsonStr) as Map<String, dynamic>;

          // Removed debug logging to reduce noise
          // debugPrint(
          //   '🔧 Converted List<int> to Map: ${actualData.keys.toList()}',
          // );

          if (actualData.containsKey('n') &&
              actualData.containsKey('c') &&
              actualData.containsKey('m')) {
            return SecretBox(
              base64Decode(actualData['c'] as String),
              nonce: base64Decode(actualData['n'] as String),
              mac: Mac(base64Decode(actualData['m'] as String)),
            );
          }
        } catch (e) {
          debugPrint('❌ Failed to convert List<int> to JSON: $e');

          // Fallback: check if it's a List with a Map as first element
          if (decoded.isNotEmpty && decoded.first is Map) {
            final map = (decoded.first as Map).cast<String, dynamic>();
            // debugPrint('📋 List[0] keys: ${map.keys.toList()}');
            if (map.containsKey('n') &&
                map.containsKey('c') &&
                map.containsKey('m')) {
              return SecretBox(
                base64Decode(map['c'] as String),
                nonce: base64Decode(map['n'] as String),
                mac: Mac(base64Decode(map['m'] as String)),
              );
            }
          }
        }
      }

      debugPrint('❌ Invalid SecretBox structure: $decoded');
      throw const FormatException('Invalid SecretBox JSON structure');
    } catch (e) {
      debugPrint('❌ SecretBox deserialization error: $e');
      debugPrint('📄 Raw data sample: ${data.take(50).toList()}');
      rethrow;
    }
  }

  _SecretBoxComponents? _extractSecretBoxComponents(
    Map<String, dynamic> source,
  ) {
    Map<String, dynamic> working = source;
    final seen = <Map<String, dynamic>>{};

    while (true) {
      if (seen.contains(working)) {
        break; // Prevent infinite recursion on malformed data
      }
      seen.add(working);

      dynamic nonceField = working['n'] ?? working['nonce'];
      dynamic cipherField =
          working['c'] ?? working['cipher'] ?? working['cipherText'];
      dynamic macField = working['m'] ?? working['mac'];

      // Some legacy payloads inadvertently nested a serialized SecretBox inside the fields.
      final nestedMap =
          _tryParseMap(cipherField) ??
          _tryParseMap(nonceField) ??
          _tryParseMap(macField);
      if (nestedMap != null &&
          nestedMap.containsKey('n') &&
          nestedMap.containsKey('c') &&
          nestedMap.containsKey('m')) {
        working = nestedMap;
        continue;
      }

      try {
        final nonceBytes = _decodeSecretBoxField(nonceField);
        final cipherBytes = _decodeSecretBoxField(cipherField);
        final macBytes = _decodeSecretBoxField(macField);
        return _SecretBoxComponents(
          nonce: nonceBytes,
          cipherText: cipherBytes,
          mac: macBytes,
        );
      } on FormatException {
        // Attempt to unwrap once more if the value itself is encoded JSON
        final jsonCandidate = _tryParseMap(cipherField);
        if (jsonCandidate != null &&
            !identical(jsonCandidate, working) &&
            jsonCandidate.containsKey('c')) {
          working = jsonCandidate.cast<String, dynamic>();
          continue;
        }
        rethrow;
      }
    }

    return null;
  }

  Map<String, dynamic>? _tryParseMap(dynamic candidate) {
    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
    if (candidate is String) {
      final trimmed = candidate.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (_) {
          // Ignore parse failures; caller will handle fallback.
        }
      }
    }
    return null;
  }

  Uint8List _decodeSecretBoxField(dynamic value) {
    if (value == null) {
      throw const FormatException('Missing SecretBox component');
    }

    Uint8List? decodeFromMap(Map<String, dynamic> map) {
      final seen = <Map<String, dynamic>>{};
      Map<String, dynamic>? current = map;

      while (current != null) {
        if (seen.contains(current)) {
          break;
        }
        seen.add(current);

        final candidates = [
          current['value'],
          current['data'],
          current['payload'],
          current['cipher'],
          current['cipherText'],
          current['c'],
          current['nonce'],
          current['n'],
          current['mac'],
          current['m'],
        ];

        var advanced = false;

        for (final candidate in candidates) {
          if (candidate == null) {
            continue;
          }
          if (candidate is Map<String, dynamic>) {
            current = candidate;
            advanced = true;
            break;
          }
          if (candidate is List && candidate.isNotEmpty) {
            final first = candidate.first;
            if (first is Map<String, dynamic>) {
              current = first;
              advanced = true;
              break;
            }
          }
          try {
            return _decodeSecretBoxField(candidate);
          } on FormatException {
            // continue trying other candidates
          }
        }

        if (advanced) {
          continue;
        }
        break;
      }

      return null;
    }

    if (value is Uint8List) {
      return value;
    }

    if (value is List<int>) {
      return Uint8List.fromList(value);
    }

    if (value is Map<String, dynamic>) {
      final decoded = decodeFromMap(value);
      if (decoded != null) {
        return decoded;
      }
    }

    if (value is String) {
      final trimmed = value.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        final nested = _tryParseMap(trimmed);
        if (nested != null) {
          final decoded = decodeFromMap(nested);
          if (decoded != null) {
            return decoded;
          }
        }
      }

      try {
        return Uint8List.fromList(base64Decode(trimmed));
      } on FormatException catch (_) {
        final nested = _tryParseMap(trimmed);
        if (nested != null) {
          final decoded = decodeFromMap(nested);
          if (decoded != null) {
            return decoded;
          }
        }
        rethrow;
      }
    }

    throw FormatException(
      'Unsupported SecretBox field type: ${value.runtimeType}',
    );
  }
}

class _SecretBoxComponents {
  _SecretBoxComponents({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}
