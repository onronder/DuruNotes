import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:duru_notes/core/crypto/key_destruction_report.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Legacy type alias for backward compatibility
typedef NotesRepository = NotesCoreRepository;

/// AccountKeyService manages the Account Master Key (AMK) lifecycle:
/// - generate a random AMK (32 bytes)
/// - derive a wrapping key from passphrase (Argon2id simulated with PBKDF2 here)
/// - wrap/unwrap AMK to/from user_keys table in Supabase
/// - cache AMK in secure storage locally
class AccountKeyService {
  AccountKeyService(
    this._ref, {
    FlutterSecureStorage? storage,
    SupabaseClient? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? Supabase.instance.client;

  static const String _amkKeyPrefix = 'amk:';
  static const String _amkMetaPrefix = 'amk_meta:';

  final Ref _ref;
  final FlutterSecureStorage _storage;
  AppLogger get _logger => _ref.read(loggerProvider);
  final SupabaseClient _client;

  void _captureAccountKeyException({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('service', 'AccountKeyService');
          scope.setTag('operation', operation);
        },
      ),
    );
  }

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
  Future<SecretKey> _deriveWrappingKey(
    String passphrase,
    Uint8List salt,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
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
  Future<void> provisionAmkForUser({
    required String passphrase,
    String? userId,
  }) async {
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
    } catch (error, stack) {
      // If user_keys table isn't initialized yet, proceed with local-only AMK
      _logger.warning(
        'Remote user_keys not initialized; using local-only AMK',
        data: {'error': error.toString(), 'userId': uid},
      );
      _captureAccountKeyException(
        operation: 'provisionAmkForUser.remoteUpsert',
        error: error,
        stackTrace: stack,
        data: {'userId': uid},
        level: SentryLevel.warning,
      );
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
    } catch (error, stack) {
      // Table missing or other schema error => provision new AMK
      if (error.toString().contains(
        "Could not find the table 'public.user_keys'",
      )) {
        _logger.warning('user_keys table not found, provisioning new AMK');
        _captureAccountKeyException(
          operation: 'unlockAmk.fetchMissingTable',
          error: error,
          stackTrace: stack,
          data: {'userId': uid},
          level: SentryLevel.warning,
        );
        await provisionAmkForUser(passphrase: passphrase, userId: uid);
        return true;
      }
      _logger.error(
        'Failed to fetch user_keys',
        data: {'error': error.toString(), 'userId': uid},
      );
      _captureAccountKeyException(
        operation: 'unlockAmk.fetch',
        error: error,
        stackTrace: stack,
        data: {'userId': uid},
      );
      rethrow;
    }

    if (res == null) {
      // No AMK on server yet for this user: create one using provided passphrase
      _logger.info(
        'No AMK found on server for user $uid, provisioning new one',
      );
      await provisionAmkForUser(passphrase: passphrase, userId: uid);
      return true;
    }

    final dynamic wrapped = res['wrapped_key'];
    final dynamic kdfRaw = res['kdf_params'];

    // Debug logging for troubleshooting
    _logger.info(
      'Attempting to unlock AMK for user $uid',
      data: {
        'wrapped_key_type': wrapped.runtimeType.toString(),
        'kdf_params_type': kdfRaw.runtimeType.toString(),
      },
    );

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
    _logger.info(
      'Deriving wrapping key',
      data: {
        'passphrase_length': passphrase.length,
        'salt_length': salt.length,
      },
    );
    final wrapping = await _deriveWrappingKey(
      passphrase,
      Uint8List.fromList(salt),
    );

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
    } catch (error) {
      _logger.warning(
        'Failed to unwrap AMK - incorrect passphrase or corrupted data',
        data: {'error': error.toString(), 'userId': uid},
      );
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
  Future<void> changePassphrase({
    required String oldPassphrase,
    required String newPassphrase,
    String? userId,
  }) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');

    // Try to obtain current AMK
    var amk = await getLocalAmk();

    // If not present locally, attempt to fetch+unwrap with old passphrase
    if (amk == null) {
      final dynamic res = await _client
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
      final wrappingOld = await _deriveWrappingKey(
        oldPassphrase,
        Uint8List.fromList(salt),
      );
      final wrappedBytes = wrapped is Uint8List
          ? wrapped
          : wrapped is List<int>
          ? Uint8List.fromList(wrapped)
          : wrapped is List<dynamic>
          ? Uint8List.fromList(wrapped.cast<int>())
          : _bytesFromDb(wrapped);
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
    } catch (error, stack) {
      _logger.warning(
        'Failed to upsert user_keys during passphrase change',
        data: {'error': error.toString(), 'userId': uid},
      );
      _captureAccountKeyException(
        operation: 'changePassphrase.remoteUpsert',
        error: error,
        stackTrace: stack,
        data: {'userId': uid},
        level: SentryLevel.warning,
      );
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
  Future<int> migrateLegacyContentAndEnqueue({
    required AppDb db,
    required NotesRepository repo,
  }) async {
    var queued = 0;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;

    // Notes: force a pull using repo logic that detects legacy and enqueues upsert
    await repo.pullSince(null);

    // Additionally, detect any existing local notes that might not have remote changes and enqueue upsert
    final notes = await db.allNotes();
    for (final n in notes) {
      // Enqueue to ensure they get re-encrypted and pushed with AMK-derived keys
      await db.enqueue(userId: uid, entityId: n.id, kind: 'upsert_note');
      queued++;
    }

    // Folders
    final folders = await db.allFolders();
    for (final f in folders) {
      await db.enqueue(userId: uid, entityId: f.id, kind: 'upsert_folder');
      queued++;
    }

    return queued;
  }

  /// GDPR Anonymization: Securely destroy Account Master Key (AMK)
  ///
  /// ⚠️ **WARNING: This is IRREVERSIBLE. All AMK-encrypted data becomes permanently inaccessible.**
  ///
  /// This method is **ONLY** for GDPR Article 17 anonymization. For normal sign-out,
  /// use [clearLocalAmk] instead.
  ///
  /// **What this destroys:**
  /// 1. Local Account Master Key (`amk:{userId}`) from secure storage
  /// 2. Local AMK metadata/salt (`amk_meta:{userId}`) from secure storage
  /// 3. Remote wrapped AMK from `user_keys` database table
  ///
  /// **What this does NOT destroy:**
  /// - Legacy device master key - use [KeyManager.securelyDestroyAllKeys]
  /// - Cross-device keys - use [EncryptionSyncService.securelyDestroyCrossDeviceKeys]
  ///
  /// **Safety measures:**
  /// - Requires explicit confirmation token (prevents accidental invocation)
  /// - Verifies keys exist before destruction (optional)
  /// - Overwrites memory with zeros before deletion (DoD 5220.22-M inspired)
  /// - Verifies deletion succeeded (local and remote)
  /// - Comprehensive audit logging
  /// - Returns detailed destruction report
  ///
  /// **GDPR Compliance:**
  /// - Article 17 (Right to Erasure): Provides proof of deletion
  /// - Recital 26 (True Anonymization): Ensures irreversibility
  /// - ISO 27001:2022: Secure data disposal with audit trail
  ///
  /// **Usage:**
  /// ```dart
  /// // Generate confirmation token (must match user ID)
  /// final token = 'DESTROY_AMK_$userId';
  ///
  /// // Destroy AMK
  /// final report = await accountKeyService.securelyDestroyAccountMasterKey(
  ///   userId: userId,
  ///   confirmationToken: token,
  ///   verifyBeforeDestroy: true,
  /// );
  ///
  /// // Check result
  /// if (report.localAmkDestroyed && report.remoteAmkDestroyed) {
  ///   print('✅ AMK destroyed');
  /// } else {
  ///   print('❌ Destruction failed: ${report.errors}');
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [userId]: User whose AMK should be destroyed
  /// - [confirmationToken]: Must be exactly `'DESTROY_AMK_$userId'`
  /// - [verifyBeforeDestroy]: If true, checks keys exist before destruction (default: true)
  ///
  /// **Returns:**
  /// [KeyDestructionReport] with:
  /// - Pre-destruction state (which keys existed)
  /// - Destruction results (which keys were destroyed)
  /// - Error list (empty if successful)
  /// - Partial success flag (localAmkDestroyed && remoteAmkDestroyed)
  ///
  /// **Throws:**
  /// - [SecurityException] if confirmation token is invalid
  /// - [SecurityException] if keys still exist after deletion attempt
  ///
  /// **Point of No Return:**
  /// After this method completes successfully, AMK-encrypted data is PERMANENTLY
  /// INACCESSIBLE. There is NO way to recover it. Make sure user has confirmed
  /// their intent before calling this method.
  ///
  /// See also:
  /// - [KeyManager.securelyDestroyAllKeys] for legacy key destruction
  /// - [EncryptionSyncService.securelyDestroyCrossDeviceKeys] for cross-device key destruction
  Future<KeyDestructionReport> securelyDestroyAccountMasterKey({
    required String userId,
    required String confirmationToken,
    bool verifyBeforeDestroy = true,
  }) async {
    // ========================================================================
    // Step 1: Validate Confirmation Token
    // ========================================================================
    //
    // Prevents accidental invocation. Token must match user ID exactly.
    final expectedToken = 'DESTROY_AMK_$userId';
    if (confirmationToken != expectedToken) {
      _logger.error(
        'Invalid confirmation token for AMK destruction',
        data: {
          'userId': userId,
          'expected': expectedToken,
          'received': confirmationToken,
        },
      );
      throw SecurityException(
        'Invalid confirmation token for AMK destruction. '
        'Expected: $expectedToken',
      );
    }

    final report = KeyDestructionReport(userId: userId);

    _logger.warning(
      'GDPR Anonymization: Starting Account Master Key destruction',
      data: {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'verifyBeforeDestroy': verifyBeforeDestroy,
      },
    );

    try {
      final localAmkKey = '$_amkKeyPrefix$userId';
      final localMetaKey = '$_amkMetaPrefix$userId';

      // ======================================================================
      // Step 2: Verify Keys Exist (Optional but Recommended)
      // ======================================================================
      //
      // Checks if keys exist before attempting destruction.
      // Helps detect unexpected state (keys already destroyed, never existed, etc.)
      if (verifyBeforeDestroy) {
        // Check local AMK
        final localAmk = await _storage.read(key: localAmkKey);
        report.amkExistedBeforeDestruction = (localAmk != null);

        // Check remote AMK
        try {
          final remoteData = await _client
              .from('user_keys')
              .select('wrapped_key')
              .eq('user_id', userId)
              .maybeSingle();
          report.remoteAmkExistedBeforeDestruction = (remoteData != null);

          _logger.debug(
            'Pre-destruction verification complete',
            data: {
              'userId': userId,
              'localAmkExists': report.amkExistedBeforeDestruction,
              'remoteAmkExists': report.remoteAmkExistedBeforeDestruction,
            },
          );
        } catch (error, stackTrace) {
          // Remote verification failed - log but continue with local destruction
          final errorMsg = 'Failed to verify remote AMK existence: $error';
          report.errors.add(errorMsg);
          _logger.warning(
            errorMsg,
            data: {'userId': userId, 'error': error.toString()},
          );
          _captureAccountKeyException(
            operation: 'securelyDestroyAmk.verifyRemote',
            error: error,
            stackTrace: stackTrace,
            data: {'userId': userId},
            level: SentryLevel.warning,
          );
        }

        if (!report.amkExistedBeforeDestruction && !report.remoteAmkExistedBeforeDestruction) {
          _logger.info(
            'No AMK found (local or remote) before destruction',
            data: {'userId': userId},
          );
        }
      }

      // ======================================================================
      // Step 3: Overwrite Local AMK Memory (Defense in Depth)
      // ======================================================================
      //
      // DoD 5220.22-M inspired: Overwrite before deletion to prevent forensic recovery.
      final existingAmk = await _storage.read(key: localAmkKey);
      if (existingAmk != null) {
        // Overwrite with zeros (Base64-encoded zeros for 32-byte key)
        await _storage.write(
          key: localAmkKey,
          value: base64Encode(List<int>.filled(32, 0)),
        );

        _logger.debug(
          'Overwritten local AMK with zeros',
          data: {'userId': userId},
        );
      }

      // ======================================================================
      // Step 4: Delete Local AMK from Secure Storage
      // ======================================================================
      //
      // Delete from iOS Keychain or Android EncryptedSharedPreferences.
      await _storage.delete(key: localAmkKey);
      await _storage.delete(key: localMetaKey);

      _logger.debug(
        'Deleted local AMK and metadata from secure storage',
        data: {'userId': userId, 'localAmkKey': localAmkKey, 'localMetaKey': localMetaKey},
      );

      // ======================================================================
      // Step 5: Verify Local Deletion Succeeded
      // ======================================================================
      //
      // Confirm keys no longer exist in local secure storage.
      final stillExistsLocal = await _storage.read(key: localAmkKey);
      final stillExistsMeta = await _storage.read(key: localMetaKey);

      if (stillExistsLocal != null || stillExistsMeta != null) {
        final error = 'Local AMK still exists after deletion attempt';
        report.errors.add(error);
        _logger.error(
          error,
          data: {
            'userId': userId,
            'amkExists': stillExistsLocal != null,
            'metaExists': stillExistsMeta != null,
          },
        );
        throw SecurityException(error);
      }

      report.localAmkDestroyed = true;

      _logger.debug(
        'Verified local AMK deletion',
        data: {'userId': userId},
      );

      // ======================================================================
      // Step 6: Delete Remote Wrapped AMK from Database
      // ======================================================================
      //
      // Delete from user_keys table in Supabase.
      try {
        await _client
            .from('user_keys')
            .delete()
            .eq('user_id', userId);

        _logger.debug(
          'Deleted remote wrapped AMK from user_keys table',
          data: {'userId': userId},
        );

        // ====================================================================
        // Step 7: Verify Remote Deletion Succeeded
        // ====================================================================
        //
        // Confirm key no longer exists in remote database.
        final stillExistsRemote = await _client
            .from('user_keys')
            .select('wrapped_key')
            .eq('user_id', userId)
            .maybeSingle();

        if (stillExistsRemote != null) {
          final error = 'Remote AMK still exists after deletion attempt';
          report.errors.add(error);
          _logger.error(
            error,
            data: {'userId': userId},
          );
          throw SecurityException(error);
        }

        report.remoteAmkDestroyed = true;

        _logger.debug(
          'Verified remote AMK deletion',
          data: {'userId': userId},
        );
      } catch (error, stackTrace) {
        // Remote deletion/verification failed
        final errorMsg = 'Failed to destroy remote AMK: $error';
        report.errors.add(errorMsg);

        _logger.error(
          'Remote AMK destruction failed',
          error: error,
          stackTrace: stackTrace,
          data: {'userId': userId},
        );

        _captureAccountKeyException(
          operation: 'securelyDestroyAmk.destroyRemote',
          error: error,
          stackTrace: stackTrace,
          data: {'userId': userId},
        );

        // Re-throw security exceptions (verification failures)
        if (error is SecurityException) {
          rethrow;
        }

        // For other errors (network, database), continue with partial success
        _logger.warning(
          'Continuing with partial destruction (local succeeded, remote failed)',
          data: {'userId': userId, 'report': report.toJson()},
        );
      }

      // ======================================================================
      // Step 8: Audit Log (CRITICAL for GDPR Compliance)
      // ======================================================================
      //
      // Log destruction event with full details for compliance audit trail.
      _logger.error(
        'GDPR Anonymization: Account Master Key destruction completed',
        data: {
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'report': report.toJson(),
          'summary': report.toSummary(),
          'level': 'CRITICAL',
        },
      );

      return report;
    } catch (error, stackTrace) {
      // ======================================================================
      // Error Handling
      // ======================================================================
      //
      // Log error and add to report, but don't throw unless it's a security exception.
      // This allows destruction to continue even if one location fails.
      final errorMessage = 'Failed to destroy Account Master Key: $error';
      if (!report.errors.contains(errorMessage)) {
        report.errors.add(errorMessage);
      }

      _logger.error(
        'Account Master Key destruction failed',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId, 'report': report.toJson()},
      );

      _captureAccountKeyException(
        operation: 'securelyDestroyAmk',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId, 'report': report.toJson()},
      );

      // Re-throw security exceptions (invalid token, verification failures)
      if (error is SecurityException) {
        rethrow;
      }

      return report;
    }
  }
}
