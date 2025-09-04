import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'key_manager.dart';

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

  Future<SecretKey> _deriveKey({
    required String userId,
    required String noteId,
  }) async {
    final master = await _keys.getOrCreateMasterKey(userId);
    final salt = utf8.encode('note:$noteId');
    return _hkdf.deriveKey(secretKey: master, nonce: salt);
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
      print('🔍 SecretBox data structure: ${decoded.runtimeType}');
      
      if (decoded is Map<String, dynamic>) {
        print('📋 Map keys: ${decoded.keys.toList()}');
        // Expected format: {'n': nonce, 'c': ciphertext, 'm': mac}
        if (decoded.containsKey('n') && decoded.containsKey('c') && decoded.containsKey('m')) {
          return SecretBox(
            base64Decode(decoded['c'] as String),
            nonce: base64Decode(decoded['n'] as String),
            mac: Mac(base64Decode(decoded['m'] as String)),
          );
        } else {
          print('❌ Missing required keys. Expected: n, c, m. Found: ${decoded.keys.toList()}');
        }
      }
      
      // Handle the case where Supabase returns the JSON as a List<int>
      if (decoded is List<dynamic>) {
        try {
          // Convert List<int> back to string and parse as JSON
          final bytes = decoded.cast<int>();
          final jsonStr = utf8.decode(bytes);
          final actualData = jsonDecode(jsonStr) as Map<String, dynamic>;
          
          print('🔧 Converted List<int> to Map: ${actualData.keys.toList()}');
          
          if (actualData.containsKey('n') && actualData.containsKey('c') && actualData.containsKey('m')) {
            return SecretBox(
              base64Decode(actualData['c'] as String),
              nonce: base64Decode(actualData['n'] as String),
              mac: Mac(base64Decode(actualData['m'] as String)),
            );
          }
        } catch (e) {
          print('❌ Failed to convert List<int> to JSON: $e');
          
          // Fallback: check if it's a List with a Map as first element
          if (decoded.isNotEmpty && decoded.first is Map) {
            final map = (decoded.first as Map).cast<String, dynamic>();
            print('📋 List[0] keys: ${map.keys.toList()}');
            if (map.containsKey('n') && map.containsKey('c') && map.containsKey('m')) {
              return SecretBox(
                base64Decode(map['c'] as String),
                nonce: base64Decode(map['n'] as String),
                mac: Mac(base64Decode(map['m'] as String)),
              );
            }
          }
        }
      }
      
      print('❌ Invalid SecretBox structure: $decoded');
      throw const FormatException('Invalid SecretBox JSON structure');
    } catch (e) {
      print('❌ SecretBox deserialization error: $e');
      print('📄 Raw data sample: ${data.take(50).toList()}');
      rethrow;
    }
  }
}
