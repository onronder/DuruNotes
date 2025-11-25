import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/services/encryption_sync_service.dart'
    hide EncryptionException;
import 'package:duru_notes/services/security/encryption_service.dart'
    as encryption_service;
import 'package:duru_notes/services/security/proper_encryption_service.dart'
    as proper;
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:encrypt/encrypt.dart' show Key;
import 'package:mockito/mockito.dart';

/// Mock implementation of EncryptionService for testing
class MockEncryptionService extends Mock
    implements encryption_service.EncryptionService {
  bool _initialized = false;
  bool _encryptionEnabled = true;
  final Map<String, dynamic> _storage = {};

  MockEncryptionService({bool encryptionEnabled = true}) {
    _encryptionEnabled = encryptionEnabled;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<encryption_service.EncryptedData> encryptData(
    dynamic data, {
    String? keyId,
    Map<String, dynamic>? metadata,
    bool compressBeforeEncrypt = true,
  }) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    // Return deterministic encrypted data for testing
    final String plaintext = data is String ? data : jsonEncode(data);
    final encrypted = base64Encode(utf8.encode(plaintext));

    return encryption_service.EncryptedData(
      data: encrypted,
      iv: 'test-iv-${DateTime.now().millisecondsSinceEpoch}',
      mac: 'test-mac',
      keyId: keyId ?? 'test-key-id',
      algorithm: 'AES-256-GCM',
      compressed: compressBeforeEncrypt,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  @override
  Future<dynamic> decryptData(
    encryption_service.EncryptedData encryptedData,
  ) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    // Decrypt deterministic data for testing
    final decrypted = utf8.decode(base64Decode(encryptedData.data));

    try {
      return jsonDecode(decrypted);
    } catch (_) {
      return decrypted;
    }
  }

  @override
  Future<Key> deriveKeyFromPassword(
    String password, {
    String? salt,
    int iterations = 100000,
  }) async {
    // Return deterministic key for testing
    final bytes = utf8.encode(password);
    final paddedBytes = Uint8List(32);
    for (int i = 0; i < bytes.length && i < 32; i++) {
      paddedBytes[i] = bytes[i];
    }
    return Key(paddedBytes);
  }

  @override
  Future<void> rotateKeys({bool force = false}) async {
    // No-op for testing
  }

  @override
  Future<Map<String, dynamic>> encryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        if (_encryptionEnabled) {
          final encrypted = await encryptData(result[field]);
          result[field] = encrypted.toJson();
        }
      }
    }

    return result;
  }

  @override
  Future<Map<String, dynamic>> decryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        if (result[field] is Map<String, dynamic>) {
          final encryptedData = encryption_service.EncryptedData.fromJson(
            result[field] as Map<String, dynamic>,
          );
          result[field] = await decryptData(encryptedData);
        }
      }
    }

    return result;
  }

  @override
  void secureErase(dynamic data) {
    // No-op for testing
  }

  @override
  void clearCache() {
    _storage.clear();
  }

  @override
  void dispose() {
    _initialized = false;
    clearCache();
  }
}

/// Mock implementation of CryptoBox for testing
class MockCryptoBox extends Mock implements CryptoBox {
  bool _encryptionEnabled = true;

  MockCryptoBox({bool encryptionEnabled = true}) {
    _encryptionEnabled = encryptionEnabled;
  }

  @override
  Future<Uint8List> encryptJsonForNote({
    required String userId,
    required String noteId,
    required Map<String, dynamic> json,
  }) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    // Return deterministic encrypted data for testing
    final plaintext = jsonEncode(json);
    return Uint8List.fromList(utf8.encode('encrypted:$plaintext'));
  }

  @override
  Future<Map<String, dynamic>> decryptJsonForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    // Decrypt deterministic data for testing
    final encrypted = utf8.decode(data);
    if (encrypted.startsWith('encrypted:')) {
      final plaintext = encrypted.substring('encrypted:'.length);
      return jsonDecode(plaintext) as Map<String, dynamic>;
    }
    throw Exception('Invalid encrypted data');
  }

  @override
  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    return Uint8List.fromList(utf8.encode('encrypted:$text'));
  }

  @override
  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    final encrypted = utf8.decode(data);
    if (encrypted.startsWith('encrypted:')) {
      return encrypted.substring('encrypted:'.length);
    }
    throw Exception('Invalid encrypted data');
  }

  @override
  Future<DecryptResult<Map<String, dynamic>>> decryptJsonForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final result = await decryptJsonForNote(
      userId: userId,
      noteId: noteId,
      data: data,
    );
    return DecryptResult(value: result, usedLegacyKey: false);
  }

  @override
  Future<DecryptResult<String>> decryptStringForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    final result = await decryptStringForNote(
      userId: userId,
      noteId: noteId,
      data: data,
    );
    return DecryptResult(value: result, usedLegacyKey: false);
  }
}

/// Mock implementation of KeyManager for testing
class MockKeyManager extends Mock implements KeyManager {
  final Map<String, SecretKey> _keys = {};
  bool _encryptionEnabled = true;

  MockKeyManager({bool encryptionEnabled = true}) {
    _encryptionEnabled = encryptionEnabled;
  }

  @override
  Future<SecretKey> getOrCreateMasterKey(String userId) async {
    if (!_encryptionEnabled) {
      throw Exception('Encryption not enabled');
    }

    if (!_keys.containsKey(userId)) {
      // Create deterministic key for testing
      final bytes = utf8.encode('test-key-$userId');
      final paddedBytes = Uint8List(32);
      for (int i = 0; i < bytes.length && i < 32; i++) {
        paddedBytes[i] = bytes[i];
      }
      _keys[userId] = SecretKey(paddedBytes);
    }

    return _keys[userId]!;
  }

  @override
  Future<SecretKey> getLegacyMasterKey(String userId) async {
    return getOrCreateMasterKey('legacy-$userId');
  }

  @override
  Future<void> deleteMasterKey(String userId) async {
    _keys.remove(userId);
  }
}

/// Mock implementation of SecureApiWrapper for testing
class MockSecureApiWrapper extends Mock implements SecureApiWrapper {
  final Map<String, dynamic> _storage = {};
  bool _encryptionEnabled = true;

  MockSecureApiWrapper({bool encryptionEnabled = true}) {
    _encryptionEnabled = encryptionEnabled;
  }

  @override
  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    if (!_encryptionEnabled) {
      // Fallback to unencrypted storage in tests
      _storage[id] = {
        'id': id,
        'titleEnc': titleEnc,
        'propsEnc': propsEnc,
        'deleted': deleted,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
      return;
    }

    _storage[id] = {
      'id': id,
      'titleEnc': titleEnc,
      'propsEnc': propsEnc,
      'deleted': deleted,
      'encrypted': true,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async {
    return _storage.values
        .where((note) => !(note['deleted'] as bool? ?? false))
        .toList()
        .cast<Map<String, dynamic>>();
  }

  @override
  Future<Set<String>> fetchAllActiveIds() async {
    return _storage.keys
        .where((id) => !(_storage[id]?['deleted'] as bool? ?? false))
        .toSet();
  }
}

/// Mock implementation of EncryptionSyncService for testing
class MockEncryptionSyncService extends Mock implements EncryptionSyncService {
  Uint8List? _amk;
  bool _isSetup = false;
  String? _password;

  MockEncryptionSyncService({bool isSetup = false}) {
    _isSetup = isSetup;
  }

  void configure({Uint8List? amk, bool? isSetup, String? password}) {
    _amk = amk;
    if (isSetup != null) {
      _isSetup = isSetup;
    }
    _password = password;
    if (_password != null && _amk == null) {
      _amk = Uint8List.fromList(utf8.encode('mock-amk-${_password!}'));
    }
  }

  @override
  Future<Uint8List?> getLocalAmk() async {
    return _amk;
  }

  @override
  Future<bool> isEncryptionSetup() async {
    return _isSetup;
  }

  @override
  Future<void> setupEncryption(String password) async {
    if (_isSetup) {
      throw Exception('Encryption already setup for this user');
    }
    _password = password;
    _amk = Uint8List.fromList(utf8.encode('mock-amk-$password'));
    _isSetup = true;
  }

  @override
  Future<void> retrieveEncryption(String password) async {
    if (!_isSetup) {
      throw Exception('Encryption not set up');
    }
    if (_password != password) {
      throw Exception('Invalid password - decryption failed');
    }
    _amk = Uint8List.fromList(utf8.encode('mock-amk-$password'));
  }

  @override
  Future<void> clearLocalKeys() async {
    _amk = null;
  }
}

/// Lightweight fake of ProperEncryptionService for tests.
class MockProperEncryptionService implements proper.ProperEncryptionService {
  bool _initialized = false;
  String? _currentKeyId;
  DateTime? _lastRotation;
  final Random _random = Random(42);

  int _nonceCounter = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
    _currentKeyId ??= 'mock-key';
    _lastRotation ??= DateTime.now();
  }

  @override
  void clearCache() {
    // Nothing to cache in the fake implementation.
  }

  @override
  void dispose() {
    clearCache();
    _initialized = false;
  }

  @override
  bool isEncrypted(String data) => data.startsWith('mock:');

  @override
  Future<proper.EncryptedData> encryptData(
    dynamic data, {
    String? keyId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      throw proper.EncryptionException('Service not initialized');
    }

    final String plaintext = data is String ? data : jsonEncode(data);
    final encoded = base64Encode(utf8.encode(plaintext));
    final timestamp = DateTime.now();
    final id = keyId ?? _currentKeyId ?? 'mock-key';
    final salt = _nonceCounter++;

    return proper.EncryptedData(
      data: 'mock:$encoded',
      nonce: base64Encode(utf8.encode('nonce-$salt')),
      mac: base64Encode(utf8.encode('mac-$salt')),
      keyId: id,
      algorithm: 'mock-aes',
      timestamp: timestamp,
      metadata: metadata,
    );
  }

  @override
  Future<dynamic> decryptData(proper.EncryptedData encryptedData) async {
    if (!encryptedData.data.startsWith('mock:')) {
      throw proper.EncryptionException('Unsupported payload');
    }
    final payload = encryptedData.data.substring(5);
    final decoded = utf8.decode(base64Decode(payload));
    try {
      return jsonDecode(decoded);
    } catch (_) {
      return decoded;
    }
  }

  @override
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

  @override
  Future<Map<String, dynamic>> decryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final result = Map<String, dynamic>.from(data);
    for (final field in sensitiveFields) {
      final value = result[field];
      if (value is Map<String, dynamic>) {
        final encrypted = proper.EncryptedData.fromJson(value);
        result[field] = await decryptData(encrypted);
      }
    }
    return result;
  }

  @override
  Future<SecretKey> deriveKeyFromPassword(
    String password, {
    List<int>? salt,
  }) async {
    final seed = utf8.encode(password);
    final combined = <int>[...seed, ...?salt];
    final bytes = Uint8List(32);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = i < combined.length ? combined[i] & 0xFF : i;
    }
    return SecretKey(bytes);
  }

  @override
  Future<void> rotateKeys({bool force = false}) async {
    if (!_initialized) {
      throw proper.EncryptionException('Service not initialized');
    }
    if (!force && _lastRotation != null) {
      final delta = DateTime.now().difference(_lastRotation!);
      if (delta.inDays < 1) {
        return;
      }
    }
    _currentKeyId = 'mock-key-${DateTime.now().millisecondsSinceEpoch}';
    _lastRotation = DateTime.now();
  }

  @override
  Future<Map<String, dynamic>> getEncryptionStatus() async {
    return {
      'initialized': _initialized,
      'currentKeyId': _currentKeyId,
      'lastKeyRotation': _lastRotation?.toIso8601String(),
      'shouldRotate': true,
      'algorithm': 'mock-aes',
    };
  }

  @override
  Future<Map<String, dynamic>> exportEncryptionMetadata() async {
    if (!_initialized) {
      throw proper.EncryptionException('Service not initialized');
    }
    return {
      'version': 'mock-1.0',
      'currentKeyId': _currentKeyId,
      'lastKeyRotation': _lastRotation?.toIso8601String(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importEncryptionMetadata(Map<String, dynamic> metadata) async {
    if (!_initialized) {
      throw proper.EncryptionException('Service not initialized');
    }
    _currentKeyId = metadata['currentKeyId'] as String?;
    final rotation = metadata['lastKeyRotation'] as String?;
    _lastRotation = rotation != null ? DateTime.tryParse(rotation) : null;
  }

  @override
  Future<String> generateSecureKey({int length = 32}) async {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  @override
  Future<proper.EncryptedData> reEncryptData(
    proper.EncryptedData data,
    String newKeyId,
  ) async {
    final decrypted = await decryptData(data);
    return encryptData(decrypted, keyId: newKeyId, metadata: data.metadata);
  }

  @override
  void secureErase(dynamic data) {
    if (data is List<int>) {
      for (var i = 0; i < data.length; i++) {
        data[i] = 0;
      }
    }
  }
}

/// Mock implementation of AccountKeyService for testing
class MockAccountKeyService extends Mock implements AccountKeyService {
  Uint8List? _amk;

  MockAccountKeyService({Uint8List? amk}) {
    _amk = amk;
  }

  @override
  Future<Uint8List?> getLocalAmk({String? userId}) async {
    return _amk;
  }

  void setAmk(Uint8List? amk) {
    _amk = amk;
  }
}

/// Mock implementation of SecurityAuditTrail for testing
class MockSecurityAuditTrail extends Mock implements SecurityAuditTrail {
  @override
  Future<void> initialize() async {
    // No-op for testing
  }

  @override
  Future<void> logEncryption({
    required String dataType,
    required int dataSize,
    required String keyId,
    bool success = true,
    String? error,
  }) async {
    // No-op for testing
  }

  @override
  Future<void> logDecryption({
    required String dataType,
    required String keyId,
    bool success = true,
    String? error,
  }) async {
    // No-op for testing
  }
}

/// Factory for creating mock encryption services with different configurations
class EncryptionMockFactory {
  /// Create mocks for encryption-enabled tests
  static EncryptionMocks createEnabledMocks() {
    return EncryptionMocks(
      encryptionService: MockEncryptionService(encryptionEnabled: true),
      cryptoBox: MockCryptoBox(encryptionEnabled: true),
      keyManager: MockKeyManager(encryptionEnabled: true),
      secureApiWrapper: MockSecureApiWrapper(encryptionEnabled: true),
      encryptionSyncService: MockEncryptionSyncService(isSetup: true),
      properEncryptionService: MockProperEncryptionService(),
      accountKeyService: MockAccountKeyService(
        amk: Uint8List.fromList(utf8.encode('test-amk')),
      ),
      securityAuditTrail: MockSecurityAuditTrail(),
    );
  }

  /// Create mocks for encryption-disabled tests
  static EncryptionMocks createDisabledMocks() {
    return EncryptionMocks(
      encryptionService: MockEncryptionService(encryptionEnabled: false),
      cryptoBox: MockCryptoBox(encryptionEnabled: false),
      keyManager: MockKeyManager(encryptionEnabled: false),
      secureApiWrapper: MockSecureApiWrapper(encryptionEnabled: false),
      encryptionSyncService: MockEncryptionSyncService(isSetup: false),
      properEncryptionService: MockProperEncryptionService(),
      accountKeyService: MockAccountKeyService(amk: null),
      securityAuditTrail: MockSecurityAuditTrail(),
    );
  }

  /// Create mocks for not-setup encryption tests
  static EncryptionMocks createNotSetupMocks() {
    return EncryptionMocks(
      encryptionService: MockEncryptionService(encryptionEnabled: true),
      cryptoBox: MockCryptoBox(encryptionEnabled: true),
      keyManager: MockKeyManager(encryptionEnabled: true),
      secureApiWrapper: MockSecureApiWrapper(encryptionEnabled: true),
      encryptionSyncService: MockEncryptionSyncService(isSetup: false),
      properEncryptionService: MockProperEncryptionService(),
      accountKeyService: MockAccountKeyService(amk: null),
      securityAuditTrail: MockSecurityAuditTrail(),
    );
  }
}

/// Container for all encryption-related mocks
class EncryptionMocks {
  final MockEncryptionService encryptionService;
  final MockCryptoBox cryptoBox;
  final MockKeyManager keyManager;
  final MockSecureApiWrapper secureApiWrapper;
  final MockEncryptionSyncService encryptionSyncService;
  final MockProperEncryptionService properEncryptionService;
  final MockAccountKeyService accountKeyService;
  final MockSecurityAuditTrail securityAuditTrail;

  EncryptionMocks({
    required this.encryptionService,
    required this.cryptoBox,
    required this.keyManager,
    required this.secureApiWrapper,
    required this.encryptionSyncService,
    required this.properEncryptionService,
    required this.accountKeyService,
    required this.securityAuditTrail,
  });

  /// Initialize all mock services
  Future<void> initialize() async {
    await encryptionService.initialize();
    await properEncryptionService.initialize();
    await securityAuditTrail.initialize();
  }

  /// Dispose all mock services
  void dispose() {
    encryptionService.dispose();
    properEncryptionService.dispose();
  }
}
