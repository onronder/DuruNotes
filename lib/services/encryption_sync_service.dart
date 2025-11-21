import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:cryptography/cryptography.dart';
import 'package:duru_notes/core/crypto/key_destruction_report.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/account_key_service.dart';

/// Custom exception for encryption-related errors
///
/// SECURITY: Error messages are generic to prevent information disclosure
/// Internal error details are logged but not exposed to users
class EncryptionException implements Exception {
  EncryptionException(this.message, {this.code, this.originalError});

  final String message; // User-facing message (generic)
  final String? code; // Error code for logging/debugging
  final Object? originalError; // Original error for debugging

  @override
  String toString() => 'EncryptionException: $message';
}

/// Service for syncing encryption keys across devices
///
/// Implements Option A from FIX2_ENCRYPTION_DETAILED_ANALYSIS.md:
/// - Generates AMK (Account Master Key) on first device
/// - Derives DEK (Data Encryption Key) from user password using Argon2
/// - Encrypts AMK with DEK and stores on backend
/// - On new device: derives DEK from password, fetches and decrypts AMK
///
/// Security:
/// - Zero-trust: Server never sees plaintext AMK
/// - Password never sent to server
/// - Uses Argon2id (memory-hard, GPU-resistant)
/// - Salt prevents rainbow table attacks
class EncryptionSyncService {
  EncryptionSyncService({
    required this.supabase,
    required this.secureStorage,
    AccountKeyService? accountKeyService,
    AppLogger? logger,
  }) : _logger = logger ?? LoggerFactory.instance,
       _accountKeyService = accountKeyService;

  final SupabaseClient supabase;
  final FlutterSecureStorage secureStorage;
  final AppLogger _logger;
  final AccountKeyService? _accountKeyService;

  // CRITICAL: Different prefix from AccountKeyService to prevent keychain collision
  // AccountKeyService uses 'amk:' - we use 'encryption_sync_amk:' to avoid conflicts
  static const String _amkKeyPrefix = 'encryption_sync_amk:';

  // Argon2 parameters (production-grade security)
  // Based on OWASP recommendations and security audit
  static const int _saltLength = 16; // 128 bits
  static const int _amkLength = 32; // 256 bits
  static const int _iterations = 5; // Argon2id iterations (OWASP minimum)
  static const int _memoryKiB =
      131072; // 128 MB (enhanced from 64MB for better resistance)
  static const int _parallelism = 4; // 4 lanes (optimal for mobile devices)

  // Encryption algorithm for AMK
  final _aesGcm = AesGcm.with256bits();

  void _captureException({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('service', 'EncryptionSyncService');
          scope.setTag('operation', operation);
        },
      ),
    );
  }

  /// Setup encryption on first device (account creation or first setup)
  ///
  /// Process:
  /// 1. Generate random AMK (256-bit)
  /// 2. Derive DEK from password using Argon2
  /// 3. Encrypt AMK with DEK
  /// 4. Store encrypted AMK on backend
  /// 5. Store AMK in device Keychain for fast access
  ///
  /// Throws [EncryptionException] with user-friendly error messages
  Future<void> setupEncryption(String password) async {
    String? userId;
    try {
      // Validation
      if (password.isEmpty) {
        throw EncryptionException(
          'Password is required to set up encryption.',
          code: 'EMPTY_PASSWORD',
        );
      }

      userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw EncryptionException(
          'Please sign in to set up encryption.',
          code: 'NOT_AUTHENTICATED',
        );
      }

      // Check if already setup
      final existing = await _fetchEncryptionKey(userId);
      if (existing != null) {
        throw EncryptionException(
          'Encryption is already set up for your account.',
          code: 'ALREADY_SETUP',
        );
      }

      _logger.info('Setting up encryption sync', data: {'userId': userId});

      // 1. Generate AMK
      final amk = _generateRandomBytes(_amkLength);

      // 2. Derive DEK from password
      final salt = _generateRandomBytes(_saltLength);
      final dek = await _deriveKeyFromPassword(password, salt);

      // 3. Encrypt AMK with DEK
      final encryptedAmk = await _encryptData(amk, dek);

      var remotePersisted = false;
      try {
        // 4. Store encrypted AMK on backend (if table exists)
        await supabase.from('user_encryption_keys').insert({
          'user_id': userId,
          'encrypted_amk': base64Encode(encryptedAmk),
          'amk_salt': base64Encode(salt),
          'algorithm': 'Argon2id',
        });
        remotePersisted = true;
      } on PostgrestException catch (error, stack) {
        if (_isMissingKeyTable(error)) {
          _logger.warning(
            'user_encryption_keys table not available – falling back to local-only encryption setup',
            data: {
              'userId': userId,
              'error': error.message,
              'code': error.code,
            },
          );
          _captureException(
            operation: 'setupEncryption.missingTable',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
            level: SentryLevel.warning,
          );
        } else {
          _logger.error(
            'Failed to persist encryption key material',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
          );
          _captureException(
            operation: 'setupEncryption.persist',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
          );
          throw EncryptionException(
            'Failed to save encryption settings. Please try again.',
            code: 'DATABASE_ERROR',
            originalError: error,
          );
        }
      }

      // 5. Store AMK in Keychain (compatible with AccountKeyService format)
      await secureStorage.write(
        key: '$_amkKeyPrefix$userId',
        value: base64Encode(amk),
      );
      // Also update AccountKeyService so CryptoBox derives keys from the shared AMK
      await _accountKeyService?.setLocalAmk(amk, userId: userId);

      _logger.info(
        'Encryption sync setup complete',
        data: {'userId': userId, 'remotePersisted': remotePersisted},
      );
    } on EncryptionException {
      rethrow; // Already user-friendly, pass through
    } catch (error, stack) {
      // Unexpected error
      _logger.error(
        'Unexpected encryption setup failure',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      _captureException(
        operation: 'setupEncryption.unexpected',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      throw EncryptionException(
        'An unexpected error occurred. Please try again.',
        code: 'UNKNOWN_ERROR',
        originalError: error,
      );
    }
  }

  /// Retrieve encryption keys on new device (sign in)
  ///
  /// Process:
  /// 1. Fetch encrypted AMK from backend
  /// 2. Derive DEK from password (same salt as original)
  /// 3. Decrypt AMK using DEK
  /// 4. Store AMK in device Keychain for fast access
  ///
  /// Throws [EncryptionException] with user-friendly error messages
  Future<void> retrieveEncryption(String password) async {
    String? userId;
    try {
      // Validation
      if (password.isEmpty) {
        throw EncryptionException(
          'Password is required to unlock encryption.',
          code: 'EMPTY_PASSWORD',
        );
      }

      userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw EncryptionException(
          'Please sign in to retrieve your encryption keys.',
          code: 'NOT_AUTHENTICATED',
        );
      }

      _logger.info('Retrieving encryption sync keys', data: {'userId': userId});

      // 1. Fetch encrypted AMK from backend
      final keyData = await _fetchEncryptionKey(userId);
      if (keyData == null) {
        throw EncryptionException(
          'No encryption setup found. Please set up encryption first.',
          code: 'NOT_SETUP',
        );
      }

      // 2. Derive DEK from password
      final salt = base64Decode(keyData['amk_salt'] as String);
      final dek = await _deriveKeyFromPassword(password, salt);

      // 3. Decrypt AMK
      final encryptedAmk = base64Decode(keyData['encrypted_amk'] as String);
      Uint8List amk;
      try {
        amk = await _decryptData(encryptedAmk, dek);
      } on SecretBoxAuthenticationError {
        // Wrong password - decryption failed MAC verification
        throw EncryptionException(
          'Incorrect password. Please try again.',
          code: 'WRONG_PASSWORD',
        );
      }

      // 4. Store AMK in Keychain (compatible with AccountKeyService format)
      await secureStorage.write(
        key: '$_amkKeyPrefix$userId',
        value: base64Encode(amk),
      );
      await _accountKeyService?.setLocalAmk(amk, userId: userId);

      _logger.info('Encryption sync keys retrieved', data: {'userId': userId});
    } on EncryptionException {
      rethrow; // Already user-friendly
    } on PostgrestException catch (error, stack) {
      _logger.error(
        'Failed to retrieve encryption key material',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      _captureException(
        operation: 'retrieveEncryption.persist',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      throw EncryptionException(
        'Failed to retrieve encryption settings. Please try again.',
        code: 'DATABASE_ERROR',
        originalError: error,
      );
    } catch (error, stack) {
      _logger.error(
        'Unexpected encryption retrieval failure',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      _captureException(
        operation: 'retrieveEncryption.unexpected',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      throw EncryptionException(
        'An unexpected error occurred. Please try again.',
        code: 'UNKNOWN_ERROR',
        originalError: error,
      );
    }
  }

  /// Rotate encryption keys (password change)
  ///
  /// Process:
  /// 1. Verify old password by decrypting current AMK
  /// 2. Generate new salt for new password
  /// 3. Derive new DEK from new password
  /// 4. Re-encrypt AMK with new DEK
  /// 5. Update backend with new encrypted AMK and salt
  ///
  /// Note: AMK itself doesn't change - only the password protecting it
  ///
  /// Throws:
  /// - [Exception] if old password is incorrect
  /// - [Exception] if user not authenticated
  Future<void> rotateKeys(String oldPassword, String newPassword) async {
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      throw Exception('Passwords cannot be empty');
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    _logger.info('Rotating encryption keys', data: {'userId': userId});

    try {
      // 1. Fetch and decrypt AMK with old password (verifies old password)
      final keyData = await _fetchEncryptionKey(userId);
      if (keyData == null) {
        throw Exception('No encryption setup found');
      }

      final oldSalt = base64Decode(keyData['amk_salt'] as String);
      final oldDek = await _deriveKeyFromPassword(oldPassword, oldSalt);
      final encryptedAmk = base64Decode(keyData['encrypted_amk'] as String);

      Uint8List amk;
      try {
        amk = await _decryptData(encryptedAmk, oldDek);
      } on SecretBoxAuthenticationError {
        _logger.warning(
          'Invalid old password supplied for key rotation',
          data: {'userId': userId},
        );
        throw Exception('Invalid old password');
      }

      // 2. Generate new salt
      final newSalt = _generateRandomBytes(_saltLength);

      // 3. Derive new DEK
      final newDek = await _deriveKeyFromPassword(newPassword, newSalt);

      // 4. Re-encrypt AMK with new DEK
      final newEncryptedAmk = await _encryptData(amk, newDek);

      // 5. Update backend
      try {
        await supabase
            .from('user_encryption_keys')
            .update({
              'encrypted_amk': base64Encode(newEncryptedAmk),
              'amk_salt': base64Encode(newSalt),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } on PostgrestException catch (error, stack) {
        if (_isMissingKeyTable(error)) {
          _logger.warning(
            'user_encryption_keys table missing during rotateKeys – continuing with local update only',
            data: {'userId': userId, 'code': error.code},
          );
          _captureException(
            operation: 'rotateKeys.missingTable',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
            level: SentryLevel.warning,
          );
        } else {
          _logger.error(
            'Failed to persist rotated encryption keys',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
          );
          _captureException(
            operation: 'rotateKeys.persist',
            error: error,
            stackTrace: stack,
            data: {'userId': userId},
          );
          throw Exception(
            'Failed to rotate encryption keys. Please try again.',
          );
        }
      }

      // Update local storage (AMK doesn't change, just re-wrapped with new password)
      await secureStorage.write(
        key: '$_amkKeyPrefix$userId',
        value: base64Encode(amk),
      );

      _logger.info(
        'Encryption keys rotated successfully',
        data: {'userId': userId},
      );
    } catch (error, stack) {
      _logger.error(
        'Unexpected error rotating encryption keys',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      _captureException(
        operation: 'rotateKeys.unexpected',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
      );
      throw Exception('Failed to rotate encryption keys. Please try again.');
    }
  }

  /// Check if encryption is setup for current user
  Future<bool> isEncryptionSetup() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final keyData = await _fetchEncryptionKey(userId);
    return keyData != null;
  }

  /// Get AMK from local storage (for use in encryption operations)
  ///
  /// Returns null if not found (user needs to setup or retrieve encryption)
  Future<Uint8List?> getLocalAmk() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final amkB64 = await secureStorage.read(key: '$_amkKeyPrefix$userId');
    if (amkB64 == null) return null;

    return base64Decode(amkB64);
  }

  /// Clear local encryption keys (sign out)
  Future<void> clearLocalKeys() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await secureStorage.delete(key: '$_amkKeyPrefix$userId');
    await _accountKeyService?.clearLocalAmk();

    _logger.debug('Cleared local encryption keys', data: {'userId': userId});
  }

  // ========== Private Helper Methods ==========

  /// Fetch encryption key data from backend
  Future<Map<String, dynamic>?> _fetchEncryptionKey(String userId) async {
    try {
      final response = await supabase
          .from('user_encryption_keys')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (error, stack) {
      if (error is PostgrestException && _isMissingKeyTable(error)) {
        _logger.warning(
          'user_encryption_keys table not found when fetching key – treating as not provisioned',
          data: {'userId': userId, 'code': error.code},
        );
        _captureException(
          operation: 'fetchEncryptionKey.missingTable',
          error: error,
          stackTrace: stack,
          data: {'userId': userId},
          level: SentryLevel.warning,
        );
        return null;
      }
      _logger.warning(
        'Failed to fetch encryption key from backend',
        data: {'userId': userId, 'error': error.toString()},
      );
      _captureException(
        operation: 'fetchEncryptionKey',
        error: error,
        stackTrace: stack,
        data: {'userId': userId},
        level: SentryLevel.warning,
      );
      return null;
    }
  }

  /// Derive encryption key from password using Argon2id
  Future<SecretKey> _deriveKeyFromPassword(
    String password,
    Uint8List salt,
  ) async {
    final argon2 = Argon2FfiFlutter();

    final passwordBytes = Uint8List.fromList(utf8.encode(password));

    final args = Argon2Arguments(
      passwordBytes, // key (password)
      salt, // salt
      _memoryKiB, // memory in KiB
      _iterations, // iterations
      32, // length (output key size)
      _parallelism, // parallelism
      2, // type: 2 = Argon2id (hybrid)
      19, // version: 19 = v1.3
    );

    final result = await argon2.argon2Async(args);

    return SecretKey(result);
  }

  /// Encrypt data with AES-256-GCM
  Future<Uint8List> _encryptData(Uint8List data, SecretKey key) async {
    final secretBox = await _aesGcm.encrypt(data, secretKey: key);

    // Combine nonce + ciphertext + mac for storage
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return combined;
  }

  /// Decrypt data with AES-256-GCM
  Future<Uint8List> _decryptData(Uint8List combined, SecretKey key) async {
    // Extract nonce (12 bytes), ciphertext, and mac (16 bytes)
    final nonce = combined.sublist(0, 12);
    final mac = combined.sublist(combined.length - 16);
    final cipherText = combined.sublist(12, combined.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: key);

    return Uint8List.fromList(decrypted);
  }

  /// Generate cryptographically secure random bytes using Random.secure()
  ///
  /// SECURITY: Uses platform's CSPRNG (e.g., /dev/urandom on Linux/iOS, CryptGenRandom on Windows)
  /// This is CRITICAL for encryption key generation - never use predictable sources
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  bool _isMissingKeyTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    return error.code == '42P01' ||
        message.contains('user_encryption_keys') &&
            (message.contains('does not exist') ||
                message.contains('not exist')) ||
        details.contains('user_encryption_keys');
  }

  /// GDPR Anonymization: Securely destroy cross-device encryption keys
  ///
  /// ⚠️ **WARNING: This is IRREVERSIBLE. All cross-device encrypted data becomes permanently inaccessible.**
  ///
  /// This method is **ONLY** for GDPR Article 17 anonymization. For normal sign-out,
  /// use [clearLocalKeys] instead.
  ///
  /// **What this destroys:**
  /// 1. Local cross-device AMK (`encryption_sync_amk:{userId}`) from secure storage
  /// 2. Remote encrypted AMK from `user_encryption_keys` database table
  ///
  /// **What this does NOT destroy:**
  /// - Account Master Key - use [AccountKeyService.securelyDestroyAccountMasterKey]
  /// - Legacy device master key - use [KeyManager.securelyDestroyAllKeys]
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
  /// final token = 'DESTROY_CROSS_DEVICE_KEYS_$userId';
  ///
  /// // Destroy cross-device keys
  /// final report = await encryptionSyncService.securelyDestroyCrossDeviceKeys(
  ///   userId: userId,
  ///   confirmationToken: token,
  ///   verifyBeforeDestroy: true,
  /// );
  ///
  /// // Check result
  /// if (report.localCrossDeviceKeyDestroyed && report.remoteCrossDeviceKeyDestroyed) {
  ///   print('✅ Cross-device keys destroyed');
  /// } else {
  ///   print('❌ Destruction failed: ${report.errors}');
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [userId]: User whose cross-device keys should be destroyed
  /// - [confirmationToken]: Must be exactly `'DESTROY_CROSS_DEVICE_KEYS_$userId'`
  /// - [verifyBeforeDestroy]: If true, checks keys exist before destruction (default: true)
  ///
  /// **Returns:**
  /// [KeyDestructionReport] with:
  /// - Pre-destruction state (which keys existed)
  /// - Destruction results (which keys were destroyed)
  /// - Error list (empty if successful)
  /// - Partial success flag (localCrossDeviceKeyDestroyed && remoteCrossDeviceKeyDestroyed)
  ///
  /// **Throws:**
  /// - [SecurityException] if confirmation token is invalid
  /// - [SecurityException] if keys still exist after deletion attempt
  ///
  /// **Point of No Return:**
  /// After this method completes successfully, cross-device encrypted data is PERMANENTLY
  /// INACCESSIBLE. There is NO way to recover it. Make sure user has confirmed
  /// their intent before calling this method.
  ///
  /// See also:
  /// - [AccountKeyService.securelyDestroyAccountMasterKey] for AMK destruction
  /// - [KeyManager.securelyDestroyAllKeys] for legacy key destruction
  Future<KeyDestructionReport> securelyDestroyCrossDeviceKeys({
    required String userId,
    required String confirmationToken,
    bool verifyBeforeDestroy = true,
  }) async {
    // ========================================================================
    // Step 1: Validate Confirmation Token
    // ========================================================================
    //
    // Prevents accidental invocation. Token must match user ID exactly.
    final expectedToken = 'DESTROY_CROSS_DEVICE_KEYS_$userId';
    if (confirmationToken != expectedToken) {
      _logger.error(
        'Invalid confirmation token for cross-device key destruction',
        data: {
          'userId': userId,
          'expected': expectedToken,
          'received': confirmationToken,
        },
      );
      throw SecurityException(
        'Invalid confirmation token for cross-device key destruction. '
        'Expected: $expectedToken',
      );
    }

    final report = KeyDestructionReport(userId: userId);

    _logger.warning(
      'GDPR Anonymization: Starting cross-device encryption key destruction',
      data: {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'verifyBeforeDestroy': verifyBeforeDestroy,
      },
    );

    try {
      final localCrossDeviceKey = '$_amkKeyPrefix$userId';

      // ======================================================================
      // Step 2: Verify Keys Exist (Optional but Recommended)
      // ======================================================================
      //
      // Checks if keys exist before attempting destruction.
      // Helps detect unexpected state (keys already destroyed, never existed, etc.)
      if (verifyBeforeDestroy) {
        // Check local cross-device AMK
        final localKey = await secureStorage.read(key: localCrossDeviceKey);
        report.crossDeviceAmkExistedBeforeDestruction = (localKey != null);

        // Check remote encrypted AMK
        try {
          final remoteData = await supabase
              .from('user_encryption_keys')
              .select('encrypted_amk')
              .eq('user_id', userId)
              .maybeSingle();
          report.remoteCrossDeviceKeyExistedBeforeDestruction = (remoteData != null);

          _logger.debug(
            'Pre-destruction verification complete',
            data: {
              'userId': userId,
              'localCrossDeviceKeyExists': report.crossDeviceAmkExistedBeforeDestruction,
              'remoteCrossDeviceKeyExists': report.remoteCrossDeviceKeyExistedBeforeDestruction,
            },
          );
        } catch (error, stackTrace) {
          // Remote verification failed - log but continue with local destruction
          final errorMsg = 'Failed to verify remote cross-device key existence: $error';
          report.errors.add(errorMsg);
          _logger.warning(
            errorMsg,
            data: {'userId': userId, 'error': error.toString()},
          );
          _captureException(
            operation: 'securelyDestroyCrossDeviceKeys.verifyRemote',
            error: error,
            stackTrace: stackTrace,
            data: {'userId': userId},
            level: SentryLevel.warning,
          );
        }

        if (!report.crossDeviceAmkExistedBeforeDestruction &&
            !report.remoteCrossDeviceKeyExistedBeforeDestruction) {
          _logger.info(
            'No cross-device keys found (local or remote) before destruction',
            data: {'userId': userId},
          );
        }
      }

      // ======================================================================
      // Step 3: Overwrite Local Cross-Device AMK Memory (Defense in Depth)
      // ======================================================================
      //
      // DoD 5220.22-M inspired: Overwrite before deletion to prevent forensic recovery.
      final existingKey = await secureStorage.read(key: localCrossDeviceKey);
      if (existingKey != null) {
        // Overwrite with zeros (Base64-encoded zeros for 32-byte key)
        await secureStorage.write(
          key: localCrossDeviceKey,
          value: base64Encode(List<int>.filled(_amkLength, 0)),
        );

        _logger.debug(
          'Overwritten local cross-device AMK with zeros',
          data: {'userId': userId},
        );
      }

      // ======================================================================
      // Step 4: Delete Local Cross-Device AMK from Secure Storage
      // ======================================================================
      //
      // Delete from iOS Keychain or Android EncryptedSharedPreferences.
      await secureStorage.delete(key: localCrossDeviceKey);

      _logger.debug(
        'Deleted local cross-device AMK from secure storage',
        data: {'userId': userId, 'localCrossDeviceKey': localCrossDeviceKey},
      );

      // ======================================================================
      // Step 5: Verify Local Deletion Succeeded
      // ======================================================================
      //
      // Confirm key no longer exists in local secure storage.
      final stillExistsLocal = await secureStorage.read(key: localCrossDeviceKey);

      if (stillExistsLocal != null) {
        final error = 'Local cross-device AMK still exists after deletion attempt';
        report.errors.add(error);
        _logger.error(
          error,
          data: {'userId': userId},
        );
        throw SecurityException(error);
      }

      report.localCrossDeviceKeyDestroyed = true;

      _logger.debug(
        'Verified local cross-device AMK deletion',
        data: {'userId': userId},
      );

      // ======================================================================
      // Step 6: Delete Remote Encrypted AMK from Database
      // ======================================================================
      //
      // Delete from user_encryption_keys table in Supabase.
      try {
        await supabase
            .from('user_encryption_keys')
            .delete()
            .eq('user_id', userId);

        _logger.debug(
          'Deleted remote encrypted AMK from user_encryption_keys table',
          data: {'userId': userId},
        );

        // ====================================================================
        // Step 7: Verify Remote Deletion Succeeded
        // ====================================================================
        //
        // Confirm key no longer exists in remote database.
        final stillExistsRemote = await supabase
            .from('user_encryption_keys')
            .select('encrypted_amk')
            .eq('user_id', userId)
            .maybeSingle();

        if (stillExistsRemote != null) {
          final error = 'Remote cross-device key still exists after deletion attempt';
          report.errors.add(error);
          _logger.error(
            error,
            data: {'userId': userId},
          );
          throw SecurityException(error);
        }

        report.remoteCrossDeviceKeyDestroyed = true;

        _logger.debug(
          'Verified remote cross-device key deletion',
          data: {'userId': userId},
        );
      } catch (error, stackTrace) {
        // Remote deletion/verification failed
        final errorMsg = 'Failed to destroy remote cross-device key: $error';
        report.errors.add(errorMsg);

        _logger.error(
          'Remote cross-device key destruction failed',
          error: error,
          stackTrace: stackTrace,
          data: {'userId': userId},
        );

        _captureException(
          operation: 'securelyDestroyCrossDeviceKeys.destroyRemote',
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
        'GDPR Anonymization: Cross-device encryption keys destruction completed',
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
      final errorMessage = 'Failed to destroy cross-device encryption keys: $error';
      if (!report.errors.contains(errorMessage)) {
        report.errors.add(errorMessage);
      }

      _logger.error(
        'Cross-device encryption key destruction failed',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId, 'report': report.toJson()},
      );

      _captureException(
        operation: 'securelyDestroyCrossDeviceKeys',
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
