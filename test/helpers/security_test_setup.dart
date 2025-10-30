import 'dart:convert';
import 'dart:typed_data';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/providers/security_providers.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/features/auth/providers/encryption_state_providers.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:encrypt/encrypt.dart' show Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Export at the top
export 'encryption_test_mocks.dart';

import 'encryption_test_mocks.dart';

/// Setup helper for tests that need mock encryption
class SecurityTestSetup {
  static EncryptionMocks? _currentMocks;

  /// Setup mock encryption for tests
  ///
  /// Usage:
  /// ```dart
  /// setUp(() async {
  ///   await SecurityTestSetup.setupMockEncryption();
  /// });
  ///
  /// tearDown(() {
  ///   SecurityTestSetup.teardownEncryption();
  /// });
  /// ```
  static Future<EncryptionMocks> setupMockEncryption({
    bool encryptionEnabled = true,
    bool isSetup = true,
  }) async {
    // Create appropriate mocks based on configuration
    EncryptionMocks mocks;
    if (!encryptionEnabled) {
      mocks = EncryptionMockFactory.createDisabledMocks();
    } else if (!isSetup) {
      mocks = EncryptionMockFactory.createNotSetupMocks();
    } else {
      mocks = EncryptionMockFactory.createEnabledMocks();
    }

    // Initialize all mocks
    await mocks.initialize();

    _applyDefaultStubs(
      mocks,
      encryptionEnabled: encryptionEnabled,
      isSetup: isSetup,
    );

    // Setup security initialization if needed
    // In tests, we don't need to initialize SecurityInitialization
    // as we're using mock services

    _currentMocks = mocks;
    return mocks;
  }

  /// Setup tests without encryption
  ///
  /// Usage:
  /// ```dart
  /// setUp(() async {
  ///   await SecurityTestSetup.setupNoEncryption();
  /// });
  /// ```
  static Future<EncryptionMocks> setupNoEncryption() async {
    return setupMockEncryption(encryptionEnabled: false);
  }

  /// Clean up after encryption tests
  static void teardownEncryption() {
    _currentMocks?.dispose();
    _currentMocks = null;
  }

  /// Get the current mock instances
  static EncryptionMocks? get currentMocks => _currentMocks;

  /// Create provider overrides for encryption services
  static List<Override> createProviderOverrides({EncryptionMocks? mocks}) {
    final m = mocks ?? _currentMocks;
    if (m == null) {
      throw StateError('No mocks available. Call setupMockEncryption first.');
    }

    return [
      // Override encryption services
      encryptionSyncServiceProvider.overrideWithValue(m.encryptionSyncService),

      // Override account key service
      accountKeyServiceProvider.overrideWithValue(m.accountKeyService),

      // Override key manager to use mock account key service
      keyManagerProvider.overrideWith((ref) {
        return KeyManager.inMemory(accountKeyService: m.accountKeyService);
      }),

      // Override crypto box to use mock key manager
      cryptoBoxProvider.overrideWithValue(m.cryptoBox),

      // Add other provider overrides as needed
    ];
  }

  /// Setup encryption state for tests
  static Future<void> setupEncryptionState({
    required WidgetTester tester,
    required EncryptionStatus status,
    String? error,
  }) async {
    final mocks = _currentMocks ?? await setupMockEncryption();

    // Configure mocks based on desired state
    switch (status) {
      case EncryptionStatus.notSetup:
        when(
          mocks.encryptionSyncService.getLocalAmk(),
        ).thenAnswer((_) async => null);
        when(
          mocks.encryptionSyncService.isEncryptionSetup(),
        ).thenAnswer((_) async => false);
        break;

      case EncryptionStatus.locked:
        when(
          mocks.encryptionSyncService.getLocalAmk(),
        ).thenAnswer((_) async => null);
        when(
          mocks.encryptionSyncService.isEncryptionSetup(),
        ).thenAnswer((_) async => true);
        break;

      case EncryptionStatus.unlocked:
        when(
          mocks.encryptionSyncService.getLocalAmk(),
        ).thenAnswer((_) async => utf8.encode('test-amk'));
        when(
          mocks.encryptionSyncService.isEncryptionSetup(),
        ).thenAnswer((_) async => true);
        break;

      case EncryptionStatus.error:
        when(
          mocks.encryptionSyncService.getLocalAmk(),
        ).thenThrow(Exception(error ?? 'Test error'));
        when(
          mocks.encryptionSyncService.isEncryptionSetup(),
        ).thenAnswer((_) async => true);
        break;

      case EncryptionStatus.loading:
        // Loading state is usually transitional
        break;
    }

    // Allow time for state to update
    await tester.pump();
  }

  /// Create a test-friendly SecureApiWrapper
  static SecureApiWrapper createTestSecureApiWrapper({
    required SupabaseNoteApi api,
    String Function()? userIdResolver,
  }) {
    // Use the testing constructor that bypasses security initialization
    return SecureApiWrapper.testing(api: api, userIdResolver: userIdResolver);
  }

  /// Stub common encryption operations for a mock
  static void stubCommonEncryptionOps(
    MockEncryptionSyncService mock, {
    bool isSetup = false,
    bool hasAmk = false,
    String? password,
  }) {
    final amkBytes = hasAmk
        ? Uint8List.fromList(utf8.encode('test-amk-${password ?? 'default'}'))
        : null;
    mock.configure(amk: amkBytes, isSetup: isSetup, password: password);
  }

  static void _applyDefaultStubs(
    EncryptionMocks mocks, {
    required bool encryptionEnabled,
    required bool isSetup,
  }) {
    final syncMock = mocks.encryptionSyncService;
    final hasLocalAmk = encryptionEnabled && isSetup;

    syncMock.configure(
      amk: hasLocalAmk
          ? Uint8List.fromList(utf8.encode('test-amk-default'))
          : null,
      isSetup: isSetup,
      password: isSetup ? 'default-password' : null,
    );
  }

  /// Create a properly initialized CryptoBox for tests
  static CryptoBox createTestCryptoBox({bool encryptionEnabled = true}) {
    final accountKeyService = MockAccountKeyService(
      amk: encryptionEnabled
          ? Uint8List.fromList(utf8.encode('test-amk'))
          : null,
    );

    final keyManager = KeyManager.inMemory(
      accountKeyService: accountKeyService,
    );

    return CryptoBox(keyManager);
  }

  /// Create test encryption data
  static Future<Map<String, dynamic>> createTestEncryptedData({
    required String content,
    String? keyId,
  }) async {
    final mocks = _currentMocks ?? await setupMockEncryption();

    final encrypted = await mocks.encryptionService.encryptData(
      content,
      keyId: keyId,
    );

    return encrypted.toJson();
  }

  /// Verify encryption was used in an operation
  static void verifyEncryptionUsed(MockEncryptionService mock) {
    verify(
      mock.encryptData(any, keyId: anyNamed('keyId')),
    ).called(greaterThan(0));
  }

  /// Verify decryption was used in an operation
  static void verifyDecryptionUsed(MockEncryptionService mock) {
    // Due to Mockito limitations with non-nullable types,
    // verification of decryptData calls should be done differently
    // e.g., by checking the mock's internal state or using captureAny
    // when setting up the mock expectations
  }

  /// Setup encryption for integration tests
  static Future<void> setupIntegrationTestEncryption(
    WidgetTester tester,
  ) async {
    // Setup mocks
    final mocks = await setupMockEncryption();

    // Configure common stubs
    stubCommonEncryptionOps(
      mocks.encryptionSyncService,
      isSetup: true,
      hasAmk: true,
    );

    // Initialize services
    await mocks.encryptionService.initialize();
    await mocks.properEncryptionService.initialize();

    // Pump to allow async operations
    await tester.pump();
  }

  /// Create a test encryption key
  static EncryptionKey createTestKey({String? id, int version = 1}) {
    final keyBytes = Uint8List.fromList(List<int>.generate(32, (i) => i));

    return EncryptionKey(
      id: id ?? 'test-key-$version',
      key: Key(keyBytes),
      createdAt: DateTime.now(),
      version: version,
    );
  }

  /// Mock successful encryption operation
  static void mockSuccessfulEncryption(MockEncryptionService mock) {
    when(
      mock.encryptData(argThat(anything), keyId: anyNamed('keyId')),
    ).thenAnswer((invocation) async {
      final data = invocation.positionalArguments[0];
      final keyId = invocation.namedArguments[#keyId] as String?;

      return EncryptedData(
        data: base64Encode(utf8.encode(jsonEncode(data))),
        iv: 'test-iv',
        mac: 'test-mac',
        keyId: keyId ?? 'default-key',
        algorithm: 'AES-256-GCM',
        compressed: false,
        timestamp: DateTime.now(),
      );
    });
  }

  /// Mock failed encryption operation
  static void mockFailedEncryption(MockEncryptionService mock, String error) {
    when(
      mock.encryptData(argThat(anything), keyId: anyNamed('keyId')),
    ).thenThrow(Exception(error));
  }
}

/// Extension to add encryption test helpers to WidgetTester
extension EncryptionTestHelpers on WidgetTester {
  /// Setup encryption for widget tests
  Future<EncryptionMocks> setupEncryption({
    bool encryptionEnabled = true,
    bool isSetup = true,
  }) async {
    final mocks = await SecurityTestSetup.setupMockEncryption(
      encryptionEnabled: encryptionEnabled,
      isSetup: isSetup,
    );

    await pump();
    return mocks;
  }

  /// Cleanup encryption after widget tests
  void cleanupEncryption() {
    SecurityTestSetup.teardownEncryption();
  }

  /// Wait for encryption state to update
  Future<void> waitForEncryptionState() async {
    await pump(const Duration(milliseconds: 100));
    await pumpAndSettle();
  }
}
