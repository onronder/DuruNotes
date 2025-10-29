import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade Encryption Service with actual AES-256-GCM encryption
/// This implementation properly encrypts data at rest using industry-standard algorithms
class ProperEncryptionService {
  static final ProperEncryptionService _instance = ProperEncryptionService._internal();
  factory ProperEncryptionService() => _instance;
  ProperEncryptionService._internal();

  // Use AES-256-GCM for authenticated encryption
  final _algorithm = AesGcm.with256bits();

  final AppLogger _logger = LoggerFactory.instance;

  // Secure storage for encryption keys
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Key management
  SecretKey? _masterKey;
  final Map<String, SecretKey> _keyCache = {};
  String? _currentKeyId;
  DateTime? _lastKeyRotation;
  bool _initialized = false;

  void _captureProperEncryptionException({
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
          scope.setTag('service', 'ProperEncryptionService');
          scope.setTag('operation', operation);        },
      ),
    );
  }

  // Configuration
  static const int _keyRotationDays = 90;
  static const String _masterKeyStorageKey = 'master_encryption_key_v2';
  static const String _currentKeyIdStorageKey = 'current_encryption_key_id_v2';
  static const String _keyRotationStorageKey = 'last_key_rotation_v2';

  /// Initialize the encryption service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load or generate master key
      await _loadOrGenerateMasterKey();

      // Load key metadata
      await _loadKeyMetadata();

      // Check if key rotation is needed
      await _checkKeyRotation();

      // Initialize audit trail
      await SecurityAuditTrail().initialize();

      _initialized = true;

      if (kDebugMode) {
        debugPrint('✅ ProperEncryptionService initialized successfully');
      }
    } catch (error, stack) {
      _logger.error(
        'Failed to initialize ProperEncryptionService',
        error: error,
        stackTrace: stack,
      );
      _captureProperEncryptionException(
        operation: 'initialize',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Encrypt data using AES-256-GCM
  Future<EncryptedData> encryptData(
    dynamic data, {
    String? keyId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Serialize data
      final String plaintext = data is String ? data : jsonEncode(data);
      final Uint8List dataBytes = utf8.encode(plaintext);

      // Get or generate encryption key
      final key = await _getOrCreateKey(keyId);

      // Generate random nonce (96 bits for GCM)
      final nonce = _algorithm.newNonce();

      // Encrypt the data
      final secretBox = await _algorithm.encrypt(
        dataBytes,
        secretKey: key,
        nonce: nonce,
      );

      // Create encrypted data object
      final encryptedData = EncryptedData(
        data: base64Encode(secretBox.cipherText),
        nonce: base64Encode(secretBox.nonce),
        mac: base64Encode(secretBox.mac.bytes),
        keyId: keyId ?? _currentKeyId ?? 'default',
        algorithm: 'AES-256-GCM',
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      // Log successful encryption
      await SecurityAuditTrail().logEncryption(
        dataType: data.runtimeType.toString(),
        dataSize: dataBytes.length,
        keyId: encryptedData.keyId,
        success: true,
      );

      return encryptedData;
    } catch (error, stack) {
      // Log encryption failure
      await SecurityAuditTrail().logEncryption(
        dataType: data.runtimeType.toString(),
        dataSize: 0,
        keyId: keyId ?? 'unknown',
        success: false,
        error: error.toString(),
      );
      _logger.error(
        'Proper encryption failed',
        error: error,
        stackTrace: stack,
        data: {'keyId': keyId ?? _currentKeyId, 'dataType': data.runtimeType.toString()},
      );
      _captureProperEncryptionException(
        operation: 'encryptData',
        error: error,
        stackTrace: stack,
        data: {'keyId': keyId ?? _currentKeyId},
      );
      throw EncryptionException('Encryption failed: ${error.toString()}');
    }
  }

  /// Decrypt data using AES-256-GCM
  Future<dynamic> decryptData(EncryptedData encryptedData) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Get encryption key
      final key = await _getKey(encryptedData.keyId);
      if (key == null) {
        throw EncryptionException('Encryption key not found for keyId: ${encryptedData.keyId}');
      }

      // Reconstruct SecretBox
      final secretBox = SecretBox(
        base64Decode(encryptedData.data),
        nonce: base64Decode(encryptedData.nonce),
        mac: Mac(base64Decode(encryptedData.mac)),
      );

      // Decrypt the data
      final decryptedBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );

      // Convert back to string
      final plaintext = utf8.decode(decryptedBytes);

      // Log successful decryption
      await SecurityAuditTrail().logDecryption(
        dataType: 'encrypted_data',
        keyId: encryptedData.keyId,
        success: true,
      );

      // Try to parse as JSON
      try {
        return jsonDecode(plaintext);
      } catch (_) {
        return plaintext;
      }
    } catch (error, stack) {
      // Log decryption failure
      await SecurityAuditTrail().logDecryption(
        dataType: 'encrypted_data',
        keyId: encryptedData.keyId,
        success: false,
        error: error.toString(),
      );

      _logger.error(
        'Proper decryption failed',
        error: error,
        stackTrace: stack,
        data: {'keyId': encryptedData.keyId},
      );
      _captureProperEncryptionException(
        operation: 'decryptData',
        error: error,
        stackTrace: stack,
        data: {'keyId': encryptedData.keyId},
      );

      if (error is EncryptionException) rethrow;
      throw EncryptionException('Decryption failed: ${error.toString()}');
    }
  }

  /// Encrypt sensitive fields in an object
  Future<Map<String, dynamic>> encryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        final encrypted = await encryptData(result[field]);
        result[field] = encrypted.toJson();
      }
    }

    return result;
  }

  /// Decrypt sensitive fields in an object
  Future<Map<String, dynamic>> decryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        if (result[field] is Map<String, dynamic>) {
          final encryptedData = EncryptedData.fromJson(result[field] as Map<String, dynamic>);
          result[field] = await decryptData(encryptedData);
        }
      }
    }

    return result;
  }

  /// Generate encryption key from password using PBKDF2
  Future<SecretKey> deriveKeyFromPassword(
    String password, {
    List<int>? salt,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt ?? List.generate(16, (i) => i),
    );

    return secretKey;
  }

  /// Rotate encryption keys
  Future<void> rotateKeys({bool force = false}) async {
    if (!force && !_shouldRotateKeys()) {
      return;
    }

    try {
      // Generate new key
      final newKey = await _algorithm.newSecretKey();
      final newKeyId = _generateKeyId();

      // Store new key
      await _storeKey(newKeyId, newKey);

      // Update current key
      _currentKeyId = newKeyId;
      _lastKeyRotation = DateTime.now();

      // Store metadata
      await _storeKeyMetadata();

      if (kDebugMode) {
        debugPrint('✅ Key rotation completed successfully');
      }
    } catch (error, stack) {
      _logger.error(
        'Proper encryption key rotation failed',
        error: error,
        stackTrace: stack,
      );
      _captureProperEncryptionException(
        operation: 'rotateKeys',
        error: error,
        stackTrace: stack,
      );
      throw EncryptionException('Key rotation failed: ${error.toString()}');
    }
  }


  // Private helper methods

  Future<void> _loadOrGenerateMasterKey() async {
    // Try to load existing master key
    final storedKeyData = await _secureStorage.read(key: _masterKeyStorageKey);

    if (storedKeyData != null) {
      try {
        final keyBytes = base64Decode(storedKeyData);
        _masterKey = SecretKey(keyBytes);
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to load master key, generating new one');
        }
      }
    }

    // Generate new master key
    _masterKey = await _algorithm.newSecretKey();
    final keyBytes = await _masterKey!.extractBytes();

    // Store the master key securely
    await _secureStorage.write(
      key: _masterKeyStorageKey,
      value: base64Encode(keyBytes),
    );
  }

  Future<void> _loadKeyMetadata() async {
    final prefs = await SharedPreferences.getInstance();

    _currentKeyId = prefs.getString(_currentKeyIdStorageKey);
    final rotationDateStr = prefs.getString(_keyRotationStorageKey);

    if (rotationDateStr != null) {
      _lastKeyRotation = DateTime.tryParse(rotationDateStr);
    }

    // If no current key, generate one
    if (_currentKeyId == null) {
      await rotateKeys(force: true);
    }
  }

  Future<void> _storeKeyMetadata() async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentKeyId != null) {
      await prefs.setString(_currentKeyIdStorageKey, _currentKeyId!);
    }

    if (_lastKeyRotation != null) {
      await prefs.setString(_keyRotationStorageKey, _lastKeyRotation!.toIso8601String());
    }
  }

  Future<SecretKey> _getOrCreateKey(String? keyId) async {
    if (keyId != null) {
      final key = await _getKey(keyId);
      if (key != null) return key;
    }

    // Use current key or master key
    if (_currentKeyId != null) {
      final key = await _getKey(_currentKeyId!);
      if (key != null) return key;
    }

    // Fall back to master key
    return _masterKey!;
  }

  Future<SecretKey?> _getKey(String keyId) async {
    // Check cache
    if (_keyCache.containsKey(keyId)) {
      return _keyCache[keyId];
    }

    // Load from secure storage
    final keyData = await _secureStorage.read(key: 'encryption_key_$keyId');
    if (keyData != null) {
      try {
        final keyBytes = base64Decode(keyData);
        final key = SecretKey(keyBytes);
        _keyCache[keyId] = key;
        return key;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to load key $keyId: $e');
        }
      }
    }

    return null;
  }

  Future<void> _storeKey(String keyId, SecretKey key) async {
    final keyBytes = await key.extractBytes();
    await _secureStorage.write(
      key: 'encryption_key_$keyId',
      value: base64Encode(keyBytes),
    );
    _keyCache[keyId] = key;
  }

  String _generateKeyId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'key_${timestamp}_$random';
  }

  bool _shouldRotateKeys() {
    if (_lastKeyRotation == null) return true;
    final daysSinceRotation = DateTime.now().difference(_lastKeyRotation!).inDays;
    return daysSinceRotation >= _keyRotationDays;
  }

  Future<void> _checkKeyRotation() async {
    if (_shouldRotateKeys()) {
      await rotateKeys();
    }
  }

  /// Check if encryption service is properly initialized
  bool get isInitialized => _initialized;

  /// Clear all cached keys
  void clearCache() {
    _keyCache.clear();
  }

  /// Dispose of service resources
  void dispose() {
    clearCache();
    _initialized = false;
  }

  /// Check if data is properly encrypted
  bool isEncrypted(String data) {
    try {
      // Check if data looks like base64-encoded encrypted data
      if (data.isEmpty || data.length < 100) return false;

      // Try to decode as base64
      final decoded = base64.decode(data);

      // Check if it can be parsed as EncryptedData JSON
      final jsonStr = utf8.decode(decoded);
      final json = jsonDecode(jsonStr);

      // Check for required EncryptedData fields
      return json['data'] != null &&
             json['nonce'] != null &&
             json['mac'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Get encryption status information
  Future<Map<String, dynamic>> getEncryptionStatus() async {
    return {
      'initialized': _initialized,
      'currentKeyId': _currentKeyId,
      'keyCount': _keyCache.length,
      'lastKeyRotation': _lastKeyRotation?.toIso8601String(),
      'shouldRotate': _shouldRotateKeys(),
      'algorithm': 'AES-256-GCM',
    };
  }

  /// Export encryption metadata for backup
  Future<Map<String, dynamic>> exportEncryptionMetadata() async {
    if (!_initialized) {
      throw EncryptionException('Service not initialized');
    }

    return {
      'version': '1.0',
      'currentKeyId': _currentKeyId,
      'keyIds': _keyCache.keys.toList(),
      'lastKeyRotation': _lastKeyRotation?.toIso8601String(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Import encryption metadata from backup
  Future<void> importEncryptionMetadata(Map<String, dynamic> metadata) async {
    if (!_initialized) {
      throw EncryptionException('Service not initialized');
    }

    final version = metadata['version'] as String?;
    if (version != '1.0') {
      throw EncryptionException('Unsupported metadata version: $version');
    }

    // Update metadata
    _currentKeyId = metadata['currentKeyId'] as String?;
    if (metadata['lastKeyRotation'] != null) {
      _lastKeyRotation = DateTime.parse(metadata['lastKeyRotation'] as String);
    }

    // Save to secure storage
    await _saveKeyMetadata();
  }

  /// Generate a secure key for additional encryption needs
  Future<String> generateSecureKey({int length = 32}) async {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Re-encrypt data with a new key
  Future<EncryptedData> reEncryptData(EncryptedData data, String newKeyId) async {
    if (!_initialized) {
      throw EncryptionException('Service not initialized');
    }

    // Decrypt with old key
    final decrypted = await decryptData(data);

    // Re-encrypt with new key
    return await encryptData(
      decrypted,
      keyId: newKeyId,
      metadata: data.metadata,
    );
  }

  /// Securely erase sensitive data from memory
  void secureErase(dynamic data) {
    if (data is String) {
      // For strings, we can't truly erase them in Dart
      // but we can at least clear references
      data = '';
    } else if (data is List<int>) {
      // Clear byte arrays
      for (int i = 0; i < data.length; i++) {
        data[i] = 0;
      }
    }
    // Best effort - Dart doesn't provide true secure memory erasure
  }

  /// Save key metadata to persistent storage
  Future<void> _saveKeyMetadata() async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentKeyId != null) {
      await prefs.setString(_currentKeyIdStorageKey, _currentKeyId!);
    }

    if (_lastKeyRotation != null) {
      await prefs.setString(_keyRotationStorageKey, _lastKeyRotation!.toIso8601String());
    }
  }
}

/// Encrypted data container
class EncryptedData {
  final String data;
  final String nonce;
  final String mac;
  final String keyId;
  final String algorithm;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  EncryptedData({
    required this.data,
    required this.nonce,
    required this.mac,
    required this.keyId,
    required this.algorithm,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'data': data,
    'nonce': nonce,
    'mac': mac,
    'keyId': keyId,
    'algorithm': algorithm,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory EncryptedData.fromJson(Map<String, dynamic> json) => EncryptedData(
    data: json['data'] as String,
    nonce: json['nonce'] as String,
    mac: json['mac'] as String,
    keyId: json['keyId'] as String,
    algorithm: json['algorithm'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

/// Encryption exception
class EncryptionException implements Exception {
  final String message;
  final String? code;

  EncryptionException(this.message, {this.code});

  @override
  String toString() => 'EncryptionException: $message${code != null ? ' (Code: $code)' : ''}';
}
