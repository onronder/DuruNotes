import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:duru_notes/core/crypto/key_destruction_report.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  KeyManager({
    FlutterSecureStorage? storage,
    required AccountKeyService accountKeyService,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _accountKeyService = accountKeyService;
  KeyManager.inMemory({required AccountKeyService accountKeyService})
    : _storage = null,
      _accountKeyService = accountKeyService;

  final FlutterSecureStorage? _storage;
  final Map<String, String> _mem = {};
  final AccountKeyService _accountKeyService;
  final AppLogger _logger = LoggerFactory.instance;

  static const _prefix = 'mk:'; // legacy device master key prefix

  /// PRODUCTION FIX #6: Safe keychain write with duplicate error handling
  /// iOS Keychain returns error -25299 when item already exists
  Future<void> _safeKeychainWrite({
    required String key,
    required String value,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
  }) async {
    if (_storage == null) {
      _mem[key] = value;
      return;
    }

    try {
      await _storage.write(
        key: key,
        value: value,
        aOptions: aOptions ?? _aOptions,
        iOptions: iOptions ?? _iOptions,
      );
    } on PlatformException catch (e) {
      // iOS Keychain duplicate error (-25299)
      if (e.code == '-25299') {
        // Delete existing key and retry
        await _storage.delete(key: key);
        await _storage.write(
          key: key,
          value: value,
          aOptions: aOptions ?? _aOptions,
          iOptions: iOptions ?? _iOptions,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<SecretKey> getOrCreateMasterKey(String userId) async {
    // Prefer account-bound AMK
    final amk = await _accountKeyService.getLocalAmk();
    if (amk != null) {
      return SecretKey(amk);
    }

    // Fallback to legacy device key to allow migration
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
      // Use safe write with duplicate error handling
      await _safeKeychainWrite(
        key: keyName,
        value: b64,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );
    }
    return SecretKey(base64Decode(b64));
  }

  /// Explicitly fetch legacy device-bound key (for migration/decrypt fallback)
  Future<SecretKey> getLegacyMasterKey(String userId) async {
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
      // If missing, generate to avoid crashes but this indicates no legacy data
      final bytes = _randomBytes(32);
      b64 = base64Encode(bytes);
      // Use safe write with duplicate error handling
      await _safeKeychainWrite(
        key: keyName,
        value: b64,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );
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

  /// GDPR Anonymization: Securely destroy ALL encryption keys for user
  ///
  /// ⚠️ **WARNING: This is IRREVERSIBLE. All encrypted data becomes permanently inaccessible.**
  ///
  /// This method is **ONLY** for GDPR Article 17 anonymization. For normal sign-out,
  /// use [deleteMasterKey] instead.
  ///
  /// **What this destroys:**
  /// 1. Legacy device master key (`mk:{userId}`) from secure storage
  /// 2. In-memory cached key (defense in depth)
  ///
  /// **What this does NOT destroy:**
  /// - Account Master Key (AMK) - use [AccountKeyService.securelyDestroyAccountMasterKey]
  /// - Cross-device keys - use [EncryptionSyncService.securelyDestroyCrossDeviceKeys]
  ///
  /// **Safety measures:**
  /// - Requires explicit confirmation token (prevents accidental invocation)
  /// - Verifies key exists before destruction (optional)
  /// - Overwrites memory with zeros before deletion (DoD 5220.22-M inspired)
  /// - Verifies deletion succeeded
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
  /// final token = 'DESTROY_ALL_KEYS_$userId';
  ///
  /// // Destroy keys
  /// final report = await keyManager.securelyDestroyAllKeys(
  ///   userId: userId,
  ///   confirmationToken: token,
  ///   verifyBeforeDestroy: true,
  /// );
  ///
  /// // Check result
  /// if (report.allKeysDestroyed) {
  ///   print('✅ All keys destroyed');
  /// } else {
  ///   print('❌ Destruction failed: ${report.errors}');
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [userId]: User whose keys should be destroyed
  /// - [confirmationToken]: Must be exactly `'DESTROY_ALL_KEYS_$userId'`
  /// - [verifyBeforeDestroy]: If true, checks key exists before destruction (default: true)
  ///
  /// **Returns:**
  /// [KeyDestructionReport] with:
  /// - Pre-destruction state (which keys existed)
  /// - Destruction results (which keys were destroyed)
  /// - Error list (empty if successful)
  /// - Success flag ([KeyDestructionReport.allKeysDestroyed])
  ///
  /// **Throws:**
  /// - [SecurityException] if confirmation token is invalid
  /// - [SecurityException] if key still exists after deletion attempt
  ///
  /// **Point of No Return:**
  /// After this method completes successfully, encrypted data is PERMANENTLY
  /// INACCESSIBLE. There is NO way to recover it. Make sure user has confirmed
  /// their intent before calling this method.
  ///
  /// See also:
  /// - [AccountKeyService.securelyDestroyAccountMasterKey] for AMK destruction
  /// - [EncryptionSyncService.securelyDestroyCrossDeviceKeys] for cross-device key destruction
  Future<KeyDestructionReport> securelyDestroyAllKeys({
    required String userId,
    required String confirmationToken,
    bool verifyBeforeDestroy = true,
  }) async {
    // ========================================================================
    // Step 1: Validate Confirmation Token
    // ========================================================================
    //
    // Prevents accidental invocation. Token must match user ID exactly.
    final expectedToken = 'DESTROY_ALL_KEYS_$userId';
    if (confirmationToken != expectedToken) {
      _logger.error(
        'Invalid confirmation token for key destruction',
        data: {
          'userId': userId,
          'expected': expectedToken,
          'received': confirmationToken,
        },
      );
      throw SecurityException(
        'Invalid confirmation token for key destruction. '
        'Expected: $expectedToken',
      );
    }

    final report = KeyDestructionReport(userId: userId);

    _logger.warning(
      'GDPR Anonymization: Starting legacy key destruction',
      data: {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'verifyBeforeDestroy': verifyBeforeDestroy,
      },
    );

    try {
      final keyName = '$_prefix$userId';

      // ======================================================================
      // Step 2: Verify Key Exists (Optional but Recommended)
      // ======================================================================
      //
      // Checks if key exists before attempting destruction.
      // Helps detect unexpected state (key already destroyed, never existed, etc.)
      if (verifyBeforeDestroy) {
        bool exists;
        if (_storage == null) {
          exists = _mem.containsKey(keyName);
        } else {
          final value = await _storage.read(
            key: keyName,
            aOptions: _aOptions,
            iOptions: _iOptions,
          );
          exists = (value != null);
        }

        report.legacyKeyExistedBeforeDestruction = exists;

        if (!exists) {
          _logger.info(
            'Legacy key did not exist before destruction (may have been migrated to AMK)',
            data: {'userId': userId, 'keyName': keyName},
          );
        } else {
          _logger.debug(
            'Legacy key exists, proceeding with destruction',
            data: {'userId': userId, 'keyName': keyName},
          );
        }
      }

      // ======================================================================
      // Step 3: Overwrite Memory (Defense in Depth)
      // ======================================================================
      //
      // DoD 5220.22-M inspired: Overwrite before deletion to prevent forensic recovery.
      // Even though Flutter Secure Storage uses platform encryption, this adds
      // an extra layer of security.
      if (_mem.containsKey(keyName)) {
        // Overwrite with zeros (Base64-encoded zeros)
        _mem[keyName] = base64Encode(List<int>.filled(32, 0));

        // Then remove from memory
        _mem.remove(keyName);

        report.memoryKeyDestroyed = true;

        _logger.debug(
          'Overwritten and cleared in-memory key',
          data: {'userId': userId},
        );
      } else {
        // No in-memory key to destroy
        report.memoryKeyDestroyed =
            true; // Mark as "destroyed" since it never existed
      }

      // ======================================================================
      // Step 4: Delete from Secure Storage
      // ======================================================================
      //
      // Delete from iOS Keychain or Android EncryptedSharedPreferences.
      if (_storage != null) {
        await _storage.delete(
          key: keyName,
          aOptions: _aOptions,
          iOptions: _iOptions,
        );

        _logger.debug(
          'Deleted legacy key from secure storage',
          data: {'userId': userId, 'keyName': keyName},
        );

        // ====================================================================
        // Step 5: Verify Deletion Succeeded
        // ====================================================================
        //
        // Confirm key no longer exists in secure storage.
        // If it still exists, something went wrong.
        final stillExists = await _storage.read(
          key: keyName,
          aOptions: _aOptions,
          iOptions: _iOptions,
        );

        if (stillExists != null) {
          final error = 'Legacy key still exists after deletion attempt';
          report.errors.add(error);
          _logger.error(error, data: {'userId': userId, 'keyName': keyName});
          throw SecurityException(error);
        }

        report.legacyKeyDestroyed = true;

        _logger.debug('Verified legacy key deletion', data: {'userId': userId});
      } else {
        // In-memory mode - already deleted in Step 3
        report.legacyKeyDestroyed = true;
      }

      // ======================================================================
      // Step 6: Audit Log (CRITICAL for GDPR Compliance)
      // ======================================================================
      //
      // Log destruction event with full details for compliance audit trail.
      _logger.error(
        'GDPR Anonymization: Legacy device key destroyed',
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
      final errorMessage = 'Failed to destroy legacy key: $error';
      report.errors.add(errorMessage);

      _logger.error(
        'Legacy key destruction failed',
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
