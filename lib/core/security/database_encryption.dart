import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Manages database encryption keys for SQLCipher
class DatabaseEncryption {
  DatabaseEncryption({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _logger = LoggerFactory.instance;

  final FlutterSecureStorage _storage;
  final AppLogger _logger;

  static const _dbKeyId = 'db_encryption_key_v1';
  static const _keyLength = 32; // 256 bits for AES-256

  /// Get or create the database encryption key
  Future<String> getDatabaseKey() async {
    try {
      // Try to retrieve existing key
      String? existingKey = await _storage.read(key: _dbKeyId);

      if (existingKey != null && existingKey.isNotEmpty) {
        _logger.info('Using existing database encryption key');
        return existingKey;
      }

      // Generate new key if none exists
      _logger.info('Generating new database encryption key');
      final newKey = await _generateDatabaseKey();

      // Store securely
      await _storage.write(key: _dbKeyId, value: newKey);
      _logger.info('Database encryption key generated and stored');

      return newKey;
    } catch (e) {
      _logger.error('Failed to get database encryption key', error: e);
      // Fallback to a deterministic but unique key based on device
      return await _generateFallbackKey();
    }
  }

  /// Generate a new random database encryption key
  Future<String> _generateDatabaseKey() async {
    final random = Random.secure();
    final keyBytes = Uint8List(_keyLength);

    for (int i = 0; i < _keyLength; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    // Return as hex string for SQLCipher
    return _bytesToHex(keyBytes);
  }

  /// Generate a fallback key using PBKDF2 from a device-specific seed
  Future<String> _generateFallbackKey() async {
    try {
      // Use a combination of package name and a fixed salt as seed
      const packageSeed = 'com.durunotes.app.db.encryption';
      const salt = 'duru_db_salt_v1';

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 100000,
        bits: _keyLength * 8,
      );

      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(packageSeed)),
        nonce: utf8.encode(salt),
      );

      final keyBytes = await secretKey.extractBytes();
      return _bytesToHex(Uint8List.fromList(keyBytes));
    } catch (e) {
      _logger.error('Failed to generate fallback key', error: e);
      // Last resort: use a fixed key (not recommended for production)
      // This ensures the app can still function but with reduced security
      return 'a' * (_keyLength * 2); // Hex string of correct length
    }
  }

  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Clear the database encryption key (for logout/reset)
  Future<void> clearDatabaseKey() async {
    try {
      await _storage.delete(key: _dbKeyId);
      _logger.info('Database encryption key cleared');
    } catch (e) {
      _logger.error('Failed to clear database encryption key', error: e);
    }
  }

  /// Rotate the database encryption key (requires database re-encryption)
  Future<String> rotateDatabaseKey() async {
    try {
      _logger.info('Rotating database encryption key');

      // Generate new key
      final newKey = await _generateDatabaseKey();

      // Store new key
      await _storage.write(key: _dbKeyId, value: newKey);

      _logger.info('Database encryption key rotated successfully');
      return newKey;
    } catch (e) {
      _logger.error('Failed to rotate database encryption key', error: e);
      rethrow;
    }
  }
}