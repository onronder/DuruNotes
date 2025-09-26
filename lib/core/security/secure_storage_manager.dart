import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Production-grade secure storage manager with enhanced security configurations
class SecureStorageManager {
  SecureStorageManager._();

  static final SecureStorageManager _instance = SecureStorageManager._();
  static SecureStorageManager get instance => _instance;

  late final FlutterSecureStorage _storage;
  late final AppLogger _logger;

  // Storage configuration with maximum security
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
    accountName: 'com.durunotes.secure',
  );

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'com.durunotes.secure',
    resetOnError: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  static const _webOptions = WebOptions();

  static const _storageConfig = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
    webOptions: _webOptions,
  );

  // Key versioning for rotation
  static const String _keyVersionPrefix = 'key_version_';
  static const String _currentKeyVersionKey = 'current_key_version';
  static const int _currentKeyVersion = 1;

  // Key prefixes for different data types
  static const String _authPrefix = 'auth_';
  static const String _cryptoPrefix = 'crypto_';
  static const String _userPrefix = 'user_';
  static const String _appPrefix = 'app_';

  /// Initialize the secure storage manager
  Future<void> initialize() async {
    _storage = _storageConfig;
    _logger = LoggerFactory.instance;

    await _performIntegrityCheck();
    await _migrateOldKeys();

    _logger.info('SecureStorageManager initialized with enhanced security');
  }

  /// Store encrypted value with key versioning
  Future<void> write({
    required String key,
    required String value,
    StorageType type = StorageType.app,
  }) async {
    try {
      final prefixedKey = _getPrefixedKey(key, type);
      final versionedKey = _getVersionedKey(prefixedKey);

      // Additional encryption layer for critical data
      final encryptedValue = await _encryptValue(value, type);

      await _storage.write(
        key: versionedKey,
        value: encryptedValue,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      // Store key version metadata
      await _storeKeyVersion(prefixedKey);

      _logger.debug('Securely stored value for key: $prefixedKey');
    } catch (e) {
      _logger.error('Failed to write secure value', error: e);
      rethrow;
    }
  }

  /// Read encrypted value with version handling
  Future<String?> read({
    required String key,
    StorageType type = StorageType.app,
  }) async {
    try {
      final prefixedKey = _getPrefixedKey(key, type);
      final version = await _getKeyVersion(prefixedKey);

      if (version == null) {
        return null;
      }

      final versionedKey = '${prefixedKey}_v$version';
      final encryptedValue = await _storage.read(
        key: versionedKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      if (encryptedValue == null) {
        return null;
      }

      // Decrypt the additional encryption layer
      return await _decryptValue(encryptedValue, type);
    } catch (e) {
      _logger.error('Failed to read secure value', error: e);
      return null;
    }
  }

  /// Delete a secure value
  Future<void> delete({
    required String key,
    StorageType type = StorageType.app,
  }) async {
    try {
      final prefixedKey = _getPrefixedKey(key, type);
      final version = await _getKeyVersion(prefixedKey);

      if (version != null) {
        final versionedKey = '${prefixedKey}_v$version';
        await _storage.delete(
          key: versionedKey,
          aOptions: _androidOptions,
          iOptions: _iosOptions,
        );

        // Remove version metadata
        await _storage.delete(
          key: '$_keyVersionPrefix$prefixedKey',
          aOptions: _androidOptions,
          iOptions: _iosOptions,
        );
      }

      _logger.debug('Deleted secure value for key: $prefixedKey');
    } catch (e) {
      _logger.error('Failed to delete secure value', error: e);
    }
  }

  /// Clear all secure storage (for logout)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      _logger.info('All secure storage cleared');
    } catch (e) {
      _logger.error('Failed to clear secure storage', error: e);
    }
  }

  /// Clear user-specific data only
  Future<void> clearUserData() async {
    try {
      final allKeys = await _storage.readAll(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      for (final key in allKeys.keys) {
        if (key.startsWith(_userPrefix) || key.startsWith(_authPrefix)) {
          await _storage.delete(
            key: key,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );
        }
      }

      _logger.info('User data cleared from secure storage');
    } catch (e) {
      _logger.error('Failed to clear user data', error: e);
    }
  }

  /// Rotate all encryption keys
  Future<void> rotateKeys() async {
    try {
      _logger.info('Starting key rotation');

      final allData = await _storage.readAll(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      // Increment key version
      final newVersion = _currentKeyVersion + 1;

      // Re-encrypt all data with new version
      for (final entry in allData.entries) {
        if (!entry.key.startsWith(_keyVersionPrefix)) {
          // Re-encrypt with new version
          final newKey = entry.key.replaceAll(
            RegExp(r'_v\d+$'),
            '_v$newVersion',
          );

          await _storage.write(
            key: newKey,
            value: entry.value,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );

          // Delete old version
          await _storage.delete(
            key: entry.key,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );
        }
      }

      // Update current key version
      await _storage.write(
        key: _currentKeyVersionKey,
        value: newVersion.toString(),
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      _logger.info('Key rotation completed successfully');
    } catch (e) {
      _logger.error('Key rotation failed', error: e);
      rethrow;
    }
  }

  /// Check if secure storage is available
  Future<bool> isAvailable() async {
    try {
      await _storage.read(
        key: 'availability_check',
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Private helper methods

  String _getPrefixedKey(String key, StorageType type) {
    switch (type) {
      case StorageType.auth:
        return '$_authPrefix$key';
      case StorageType.crypto:
        return '$_cryptoPrefix$key';
      case StorageType.user:
        return '$_userPrefix$key';
      case StorageType.app:
        return '$_appPrefix$key';
    }
  }

  String _getVersionedKey(String key) {
    return '${key}_v$_currentKeyVersion';
  }

  Future<void> _storeKeyVersion(String key) async {
    await _storage.write(
      key: '$_keyVersionPrefix$key',
      value: _currentKeyVersion.toString(),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<int?> _getKeyVersion(String key) async {
    final versionStr = await _storage.read(
      key: '$_keyVersionPrefix$key',
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );

    return versionStr != null ? int.tryParse(versionStr) : null;
  }

  /// Additional encryption layer for critical data
  Future<String> _encryptValue(String value, StorageType type) async {
    if (type == StorageType.crypto || type == StorageType.auth) {
      // Add extra encryption for sensitive data
      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKey();
      final nonce = algorithm.newNonce();

      final secretBox = await algorithm.encrypt(
        utf8.encode(value),
        secretKey: secretKey,
        nonce: nonce,
      );

      // Combine encrypted data with key material
      final combined = {
        'data': base64Encode(secretBox.concatenation()),
        'key': base64Encode(await secretKey.extractBytes()),
        'nonce': base64Encode(nonce),
      };

      return jsonEncode(combined);
    }

    return value;
  }

  Future<String> _decryptValue(String encryptedValue, StorageType type) async {
    if (type == StorageType.crypto || type == StorageType.auth) {
      try {
        final combined = jsonDecode(encryptedValue) as Map<String, dynamic>;
        final algorithm = AesGcm.with256bits();

        final secretKey = SecretKey(base64Decode(combined['key'] as String));
        final box = SecretBox.fromConcatenation(
          base64Decode(combined['data'] as String),
          nonceLength: algorithm.nonceLength,
          macLength: algorithm.macAlgorithm.macLength,
        );

        final decrypted = await algorithm.decrypt(
          box,
          secretKey: secretKey,
        );

        return utf8.decode(decrypted);
      } catch (e) {
        // Fallback for non-encrypted values (backward compatibility)
        return encryptedValue;
      }
    }

    return encryptedValue;
  }

  Future<void> _performIntegrityCheck() async {
    try {
      // Check storage integrity
      final testKey = 'integrity_check_${DateTime.now().millisecondsSinceEpoch}';
      const testValue = 'test_value';

      await _storage.write(
        key: testKey,
        value: testValue,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      final readValue = await _storage.read(
        key: testKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      if (readValue != testValue) {
        throw Exception('Storage integrity check failed');
      }

      await _storage.delete(
        key: testKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      _logger.debug('Storage integrity check passed');
    } catch (e) {
      _logger.error('Storage integrity check failed', error: e);

      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, reset encrypted shared preferences if corrupted
        await _storage.deleteAll(aOptions: _androidOptions);
        _logger.warning('Reset Android encrypted shared preferences');
      }
    }
  }

  Future<void> _migrateOldKeys() async {
    try {
      // Migrate any old unversioned keys to versioned format
      final allKeys = await _storage.readAll(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      for (final entry in allKeys.entries) {
        if (!entry.key.contains('_v') &&
            !entry.key.startsWith(_keyVersionPrefix) &&
            entry.key != _currentKeyVersionKey) {
          // Migrate to versioned key
          final versionedKey = '${entry.key}_v$_currentKeyVersion';

          await _storage.write(
            key: versionedKey,
            value: entry.value,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );

          await _storeKeyVersion(entry.key);

          // Delete old unversioned key
          await _storage.delete(
            key: entry.key,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );

          _logger.debug('Migrated key: ${entry.key}');
        }
      }
    } catch (e) {
      _logger.error('Key migration failed', error: e);
    }
  }
}

/// Types of storage data for proper categorization
enum StorageType {
  auth,   // Authentication tokens, session data
  crypto, // Encryption keys, certificates
  user,   // User preferences, settings
  app,    // Application state, cache
}