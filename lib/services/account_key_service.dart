import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/monitoring/app_logger.dart';
import '../data/local/app_db.dart';
import '../repository/notes_repository.dart';

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

  Future<Uint8List?> getLocalAmk({String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) return null;
    final b64 = await _storage.read(key: '$_amkKeyPrefix$uid');
    if (b64 == null) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  Future<void> setLocalAmk(Uint8List amk, {String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
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
  Future<void> provisionAmkForUser({required String passphrase, String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');

    final amk = _randomBytes(32);
    final salt = _randomBytes(16);
    final wrapping = await _deriveWrappingKey(passphrase, salt);
    final wrapped = await _wrapAmk(amk, wrapping);

    try {
      // Store wrapped_key as base64 string to avoid postgres bytea conversion issues
      await _client.from('user_keys').upsert({
        'user_id': uid,
        'wrapped_key': base64Encode(wrapped),
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

    await setLocalAmk(amk, userId: uid);
    await _storage.write(
      key: '$_amkMetaPrefix$uid',
      value: jsonEncode({'salt_b64': base64Encode(salt)}),
    );
    _logger.info('AMK provisioned and stored locally');
  }

  /// Unlock AMK with passphrase - handles both new and existing users
  Future<bool> unlockAmkWithPassphrase(String passphrase) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _logger.warning('Cannot unlock AMK: no authenticated user');
      return false;
    }
    
    // First check if AMK is already present locally
    // This can happen if the unlock screen appears due to timing issues after signup
    final existingAmk = await getLocalAmk(userId: uid);
    if (existingAmk != null) {
      _logger.info('AMK already present locally for user $uid');
      return true;
    }
    
    // Try to fetch from server
    dynamic res;
    try {
      res = await _client
          .from('user_keys')
          .select('wrapped_key, kdf_params')
          .eq('user_id', uid)
          .maybeSingle();
    } catch (e) {
      // Table missing or other schema error => provision new AMK
      if (e.toString().contains("Could not find the table 'public.user_keys'")) {
        _logger.warning('user_keys table not found, provisioning new AMK');
        await provisionAmkForUser(passphrase: passphrase, userId: uid);
        return true;
      }
      _logger.error('Failed to fetch user_keys', data: {'error': e.toString()});
      rethrow;
    }
    
    if (res == null) {
      // No AMK on server yet for this user: create one using provided passphrase
      _logger.info('No AMK found on server for user $uid, provisioning new one');
      await provisionAmkForUser(passphrase: passphrase, userId: uid);
      return true;
    }

    final dynamic wrapped = res['wrapped_key'];
    final dynamic kdfRaw = res['kdf_params'];

    // Debug logging for troubleshooting
    _logger.info('Attempting to unlock AMK for user $uid', data: {
      'wrapped_key_type': wrapped.runtimeType.toString(),
      'kdf_params_type': kdfRaw.runtimeType.toString(),
    });

    // Parse kdf_params regardless of shape (Map or JSON string)
    late final Map<String, dynamic> params;
    if (kdfRaw is Map) {
      params = kdfRaw.cast<String, dynamic>();
    } else if (kdfRaw is String) {
      params = (jsonDecode(kdfRaw) as Map).cast<String, dynamic>();
    } else {
      throw StateError('Unsupported kdf_params type: ${kdfRaw.runtimeType}');
    }

    final saltB64 = params['salt_b64'] as String?;
    if (saltB64 == null || saltB64.isEmpty) {
      throw StateError('Missing salt_b64 in kdf_params');
    }
    final salt = base64Decode(saltB64);
    _logger.info('Deriving wrapping key', data: {
      'passphrase_length': passphrase.length,
      'salt_length': salt.length,
    });
    final wrapping = await _deriveWrappingKey(passphrase, Uint8List.fromList(salt));

    // Convert wrapped_key from base64 string or other formats to bytes
    Uint8List wrappedBytes;
    if (wrapped is String) {
      // First try base64 decode (our new format)
      try {
        wrappedBytes = base64Decode(wrapped);
      } catch (_) {
        // Fallback to legacy format handling
        wrappedBytes = _bytesFromDb(wrapped);
      }
    } else {
      wrappedBytes = _bytesFromDb(wrapped);
    }

    try {
      final amk = await _unwrapAmk(wrappedBytes, wrapping);
      await setLocalAmk(amk, userId: uid);
      _logger.info('AMK successfully unlocked and stored for user $uid');
      return true;
    } catch (e) {
      _logger.error('Failed to unwrap AMK - incorrect passphrase?', data: {'error': e.toString()});
      return false;
    }
  }

  /// Convert various wire formats from PostgREST to bytes
  Uint8List _bytesFromDb(dynamic v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());
    if (v is String) {
      // Postgres bytea hex string: \xABCD...
      if (v.startsWith(r'\x') || v.startsWith(r'\\x')) {
        // Handle possible escape duplication
        final hexPrefixNormalized = v.replaceFirst(r'\\x', r'\x');
        final hex = hexPrefixNormalized.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }
      // Try base64 decode
      try {
        return base64Decode(v);
      } catch (_) {
        // Try JSON array string
        try {
          final arr = (jsonDecode(v) as List).cast<int>();
          return Uint8List.fromList(arr);
        } catch (_) {
          // Fallback to UTF-8
          return Uint8List.fromList(utf8.encode(v));
        }
      }
    }
    throw StateError('Unsupported wrapped_key type: ${v.runtimeType}');
  }

  /// Change passphrase: fetch current wrapped AMK (or local AMK), re-wrap with new passphrase, update remote and local metadata
  Future<void> changePassphrase({required String oldPassphrase, required String newPassphrase, String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');

    // Try to obtain current AMK
    Uint8List? amk = await getLocalAmk();

    // If not present locally, attempt to fetch+unwrap with old passphrase
    if (amk == null) {
      dynamic res = await _client
          .from('user_keys')
          .select('wrapped_key, kdf_params')
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) {
        // No remote; re-provision
        await provisionAmkForUser(passphrase: newPassphrase);
        return;
      }
      final wrapped = res['wrapped_key'] as dynamic;
      final params = (res['kdf_params'] as Map).cast<String, dynamic>();
      final salt = base64Decode(params['salt_b64'] as String);
      final wrappingOld = await _deriveWrappingKey(oldPassphrase, Uint8List.fromList(salt));
      final wrappedBytes = wrapped is Uint8List
          ? wrapped
          : wrapped is List<int>
              ? Uint8List.fromList(wrapped)
              : Uint8List.fromList(wrapped.cast<int>());
      amk = await _unwrapAmk(wrappedBytes, wrappingOld);
    }

    // Derive new wrapping key and wrap
    final newSalt = _randomBytes(16);
    final wrappingNew = await _deriveWrappingKey(newPassphrase, newSalt);
    final newWrapped = await _wrapAmk(amk, wrappingNew);

    try {
      // Store wrapped_key as base64 string to avoid postgres bytea conversion issues
      await _client.from('user_keys').upsert({
        'user_id': uid,
        'wrapped_key': base64Encode(newWrapped),
        'kdf': 'pbkdf2-hmac-sha256',
        'kdf_params': {'iterations': 150000, 'salt_b64': base64Encode(newSalt)},
      });
    } catch (e) {
      _logger.warning('Failed to upsert user_keys during passphrase change', data: {'error': e.toString()});
      // Continue to update local store even if remote fails
    }

    // Update local cache/meta
    await setLocalAmk(amk);
    await _storage.write(
      key: '$_amkMetaPrefix$uid',
      value: jsonEncode({'salt_b64': base64Encode(newSalt)}),
    );
    _logger.info('Passphrase changed and AMK re-wrapped');
  }

  /// Scan local notes/folders encrypted with legacy device key and enqueue rewrap by scheduling upserts
  /// Returns number of entities queued for rewrap
  Future<int> migrateLegacyContentAndEnqueue({required AppDb db, required NotesRepository repo}) async {
    int queued = 0;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;

    // Notes: force a pull using repo logic that detects legacy and enqueues upsert
    await repo.pullSince(null);

    // Additionally, detect any existing local notes that might not have remote changes and enqueue upsert
    final notes = await db.allNotes();
    for (final n in notes) {
      // Enqueue to ensure they get re-encrypted and pushed with AMK-derived keys
      await db.enqueue(n.id, 'upsert_note');
      queued++;
    }

    // Folders
    final folders = await db.allFolders();
    for (final f in folders) {
      await db.enqueue(f.id, 'upsert_folder');
      queued++;
    }

    return queued;
  }
}


