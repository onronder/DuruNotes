import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/monitoring/app_logger.dart';

/// AccountKeyService manages the Account Master Key (AMK) lifecycle:
/// - generate a random AMK (32 bytes)
/// - derive a wrapping key from passphrase (Argon2id simulated with PBKDF2 here)
/// - wrap/unwrap AMK to/from user_keys table in Supabase
/// - cache AMK in secure storage locally
class AccountKeyService {
  AccountKeyService({
    FlutterSecureStorage? storage,
    AppLogger? logger,
    SupabaseClient? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? LoggerFactory.instance,
        _client = client ?? Supabase.instance.client;

  static const String _amkKeyPrefix = 'amk:';
  static const String _amkMetaPrefix = 'amk_meta:';

  final FlutterSecureStorage _storage;
  final AppLogger _logger;
  final SupabaseClient _client;

  Future<Uint8List?> getLocalAmk() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final b64 = await _storage.read(key: '$_amkKeyPrefix$uid');
    if (b64 == null) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  Future<void> setLocalAmk(Uint8List amk) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _storage.write(key: '$_amkKeyPrefix$uid', value: base64Encode(amk));
  }

  Future<void> clearLocalAmk() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _storage.delete(key: '$_amkKeyPrefix$uid');
    await _storage.delete(key: '$_amkMetaPrefix$uid');
  }

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  /// Derive a wrapping key from passphrase (placeholder PBKDF2-HMAC-SHA256)
  Future<SecretKey> _deriveWrappingKey(String passphrase, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000,
      bits: 256,
    );
    return pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  }

  /// Wrap AMK with passphrase-derived key using XChaCha20-Poly1305
  Future<Uint8List> _wrapAmk(Uint8List amk, SecretKey wrappingKey) async {
    final cipher = Xchacha20.poly1305Aead();
    final nonce = cipher.newNonce();
    final box = await cipher.encrypt(amk, secretKey: wrappingKey, nonce: nonce);
    final payload = <String, String>{
      'n': base64Encode(nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  Future<Uint8List> _unwrapAmk(Uint8List wrapped, SecretKey wrappingKey) async {
    final cipher = Xchacha20.poly1305Aead();
    final map = jsonDecode(utf8.decode(wrapped)) as Map<String, dynamic>;
    final nonce = base64Decode(map['n'] as String);
    final ct = base64Decode(map['c'] as String);
    final mac = base64Decode(map['m'] as String);
    final plain = await cipher.decrypt(
      SecretBox(ct, nonce: nonce, mac: Mac(mac)),
      secretKey: wrappingKey,
    );
    return Uint8List.fromList(plain);
  }

  /// On first signup: generate AMK and upload wrapped to user_keys
  Future<void> provisionAmkForUser({required String passphrase}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');

    final amk = _randomBytes(32);
    final salt = _randomBytes(16);
    final wrapping = await _deriveWrappingKey(passphrase, salt);
    final wrapped = await _wrapAmk(amk, wrapping);

    try {
      await _client.from('user_keys').upsert({
        'user_id': uid,
        'wrapped_key': wrapped,
        'kdf': 'pbkdf2-hmac-sha256',
        'kdf_params': {'iterations': 150000, 'salt_b64': base64Encode(salt)},
      });
    } catch (e) {
      // If user_keys table isn't initialized yet, proceed with local-only AMK
      _logger.warning('Remote user_keys not initialized; using local-only AMK', data: {
        'error': e.toString(),
      });
      // Do not rethrow; app can function locally and sync plaintext-free data won't decrypt cross-device
    }

    await setLocalAmk(amk);
    final uid2 = _client.auth.currentUser?.id;
    await _storage.write(
      key: '$_amkMetaPrefix$uid2',
      value: jsonEncode({'salt_b64': base64Encode(salt)}),
    );
    _logger.info('AMK provisioned and stored locally');
  }

  /// On new device: fetch, derive, unwrap, and cache AMK
  Future<bool> unlockAmkWithPassphrase(String passphrase) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    dynamic res;
    try {
      res = await _client
          .from('user_keys')
          .select('wrapped_key, kdf_params')
          .eq('user_id', uid)
          .maybeSingle();
    } catch (e) {
      // Table missing or other schema error => create a local-only AMK and allow proceeding
      if (e.toString().contains("Could not find the table 'public.user_keys'")) {
        final localAmk = _randomBytes(32);
        await setLocalAmk(localAmk);
        _logger.warning('Proceeding with local-only AMK (user_keys not initialized)');
        return true;
      }
      rethrow;
    }
    if (res == null) return false;

    final wrapped = res['wrapped_key'] as dynamic;
    final params = (res['kdf_params'] as Map).cast<String, dynamic>();
    final salt = base64Decode(params['salt_b64'] as String);
    final wrapping = await _deriveWrappingKey(passphrase, salt);
    final wrappedBytes = wrapped is Uint8List
        ? wrapped
        : wrapped is List<int>
            ? Uint8List.fromList(wrapped)
            : Uint8List.fromList(wrapped.cast<int>());
    final amk = await _unwrapAmk(wrappedBytes, wrapping);
    await setLocalAmk(amk);
    return true;
  }
}


