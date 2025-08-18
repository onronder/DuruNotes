import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  KeyManager({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  KeyManager.inMemory() : _storage = null;

  final FlutterSecureStorage? _storage;
  final Map<String, String> _mem = {};

  static const _prefix = 'mk:'; // master key prefix

  Future<SecretKey> getOrCreateMasterKey(String userId) async {
    final keyName = '$_prefix$userId';
    String? b64;
    if (_storage == null) {
      b64 = _mem[keyName];
    } else {
      b64 = await _storage.read(
        key: keyName,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );
    }
    if (b64 == null) {
      final bytes = _randomBytes(32);
      b64 = base64Encode(bytes);
      if (_storage == null) {
        _mem[keyName] = b64;
      } else {
        await _storage.write(
          key: keyName,
          value: b64,
          aOptions: _aOptions,
          iOptions: _iOptions,
        );
      }
    }
    return SecretKey(base64Decode(b64));
  }

  Future<void> deleteMasterKey(String userId) async {
    final keyName = '$_prefix$userId';
    if (_storage == null) {
      _mem.remove(keyName);
    } else {
      await _storage.delete(
        key: keyName,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );
    }
  }

  static const AndroidOptions _aOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const IOSOptions _iOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }
}
