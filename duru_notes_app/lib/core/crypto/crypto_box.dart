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
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is Map<String, dynamic>) {
      return SecretBox(
        base64Decode(decoded['c'] as String),
        nonce: base64Decode(decoded['n'] as String),
        mac: Mac(base64Decode(decoded['m'] as String)),
      );
    }
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final map = (decoded.first as Map).cast<String, dynamic>();
      return SecretBox(
        base64Decode(map['c'] as String),
        nonce: base64Decode(map['n'] as String),
        mac: Mac(base64Decode(map['m'] as String)),
      );
    }
    throw const FormatException('Invalid SecretBox JSON structure');
  }
}
