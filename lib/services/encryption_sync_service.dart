import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:cryptography/cryptography.dart';
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
  })  : _logger = logger ?? LoggerFactory.instance,
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
  static const int _memoryKiB = 131072; // 128 MB (enhanced from 64MB for better resistance)
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
          scope.setTag('operation', operation);        },
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

      _logger.info(
        'Setting up encryption sync',
        data: {'userId': userId},
      );

      // 1. Generate AMK
      final amk = _generateRandomBytes(_amkLength);

      // 2. Derive DEK from password
      final salt = _generateRandomBytes(_saltLength);
      final dek = await _deriveKeyFromPassword(password, salt);

      // 3. Encrypt AMK with DEK
      final encryptedAmk = await _encryptData(amk, dek);

      // 4. Store encrypted AMK on backend
      await supabase.from('user_encryption_keys').insert({
        'user_id': userId,
        'encrypted_amk': base64Encode(encryptedAmk),
        'amk_salt': base64Encode(salt),
        'algorithm': 'Argon2id',
      });

      // 5. Store AMK in Keychain (compatible with AccountKeyService format)
      await secureStorage.write(
        key: '$_amkKeyPrefix$userId',
        value: base64Encode(amk),
      );
      // Also update AccountKeyService so CryptoBox derives keys from the shared AMK
      await _accountKeyService?.setLocalAmk(amk, userId: userId);

      _logger.info(
        'Encryption sync setup complete',
        data: {'userId': userId},
      );
    } on EncryptionException {
      rethrow; // Already user-friendly, pass through
    } on PostgrestException catch (error, stack) {
      // Database error - don't expose internal details
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

      _logger.info(
        'Retrieving encryption sync keys',
        data: {'userId': userId},
      );

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

      _logger.info(
        'Encryption sync keys retrieved',
        data: {'userId': userId},
      );
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

    _logger.info(
      'Rotating encryption keys',
      data: {'userId': userId},
    );

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
      await supabase.from('user_encryption_keys').update({
        'encrypted_amk': base64Encode(newEncryptedAmk),
        'amk_salt': base64Encode(newSalt),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Update local storage (AMK doesn't change, just re-wrapped with new password)
      await secureStorage.write(
        key: '$_amkKeyPrefix$userId',
        value: base64Encode(amk),
      );

      _logger.info(
        'Encryption keys rotated successfully',
        data: {'userId': userId},
      );
    } on PostgrestException catch (error, stack) {
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
      throw Exception('Failed to rotate encryption keys. Please try again.');
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

    _logger.debug(
      'Cleared local encryption keys',
      data: {'userId': userId},
    );
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
      passwordBytes,  // key (password)
      salt,           // salt
      _memoryKiB,     // memory in KiB
      _iterations,    // iterations
      32,             // length (output key size)
      _parallelism,   // parallelism
      2,              // type: 2 = Argon2id (hybrid)
      19,             // version: 19 = v1.3
    );

    final result = await argon2.argon2Async(args);

    return SecretKey(result);
  }

  /// Encrypt data with AES-256-GCM
  Future<Uint8List> _encryptData(Uint8List data, SecretKey key) async {
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: key,
    );

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

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );

    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: key,
    );

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
}
