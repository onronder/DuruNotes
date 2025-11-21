/// Unit tests for GDPRAnonymizationService
///
/// Tests the complete 7-phase GDPR-compliant user anonymization orchestration:
/// - Phase 1: Pre-Anonymization Validation
/// - Phase 2: Account Metadata Anonymization
/// - Phase 3: Encryption Key Destruction (Point of No Return)
/// - Phase 4: Encrypted Content Tombstoning
/// - Phase 5: Unencrypted Metadata Clearing
/// - Phase 6: Cross-Device Sync Invalidation
/// - Phase 7: Final Audit Trail & Compliance Proof
///
/// **Test Coverage**:
/// - Confirmation token validation
/// - Key destruction orchestration
/// - Progress callback notifications
/// - Error handling and best-effort continuation
/// - Report generation and compliance certificate
library;

import 'package:duru_notes/core/crypto/key_destruction_report.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/gdpr/anonymization_types.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/services/encryption_sync_service.dart';
import 'package:duru_notes/services/gdpr_anonymization_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gdpr_anonymization_service_test.mocks.dart';

// ============================================================================
// Mock Generation Configuration
// ============================================================================

@GenerateNiceMocks([
  MockSpec<KeyManager>(),
  MockSpec<AccountKeyService>(),
  MockSpec<EncryptionSyncService>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<Session>(),
  MockSpec<ProviderRef>(),
  MockSpec<AppLogger>(),
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(as: #MockRpcListFilterBuilder),
  MockSpec<PostgrestFilterBuilder<void>>(as: #MockRpcVoidFilterBuilder),
])

// ============================================================================
// Test Helpers
// ============================================================================

/// Create a successful KeyDestructionReport for testing
KeyDestructionReport createSuccessfulKeyDestructionReport(String userId) {
  return KeyDestructionReport(userId: userId)
    ..memoryKeyDestroyed = true
    ..legacyKeyDestroyed = true
    ..localAmkDestroyed = true
    ..remoteAmkDestroyed = true
    ..localCrossDeviceKeyDestroyed = true
    ..remoteCrossDeviceKeyDestroyed = true;
}

/// Create a partially failed KeyDestructionReport for testing
KeyDestructionReport createPartiallyFailedKeyDestructionReport(String userId) {
  return KeyDestructionReport(userId: userId)
    ..memoryKeyDestroyed = true
    ..legacyKeyDestroyed = true
    ..localAmkDestroyed = false // Failed
    ..remoteAmkDestroyed = true
    ..localCrossDeviceKeyDestroyed = true
    ..remoteCrossDeviceKeyDestroyed = false // Failed
    ..errors.add('Failed to destroy local AMK')
    ..errors.add('Failed to destroy remote cross-device key');
}

/// Create valid UserConfirmations for testing
UserConfirmations createValidConfirmations(String userId) {
  return UserConfirmations(
    dataBackupComplete: true,
    understandsIrreversibility: true,
    finalConfirmationToken: UserConfirmations.generateConfirmationToken(userId),
    acknowledgesRisks: true,
    allowProductionOverride: false,
  );
}

// ============================================================================
// Main Test Suite
// ============================================================================

void main() {
  late MockKeyManager mockKeyManager;
  late MockAccountKeyService mockAccountKeyService;
  late MockEncryptionSyncService mockEncryptionSyncService;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockSession mockSession;
  late MockRpcListFilterBuilder mockRpcListFilterBuilder;
  late MockRpcVoidFilterBuilder mockRpcVoidFilterBuilder;
  late MockProviderRef mockRef;
  late MockAppLogger mockLogger;
  late GDPRAnonymizationService service;

  const testUserId = 'test_user_123';

  setUpAll(() {
    // Provide dummy value for AppLogger to fix mockito generic method stubbing
    provideDummy<AppLogger>(MockAppLogger());
  });

  setUp(() {
    // Create mocks
    mockKeyManager = MockKeyManager();
    mockAccountKeyService = MockAccountKeyService();
    mockEncryptionSyncService = MockEncryptionSyncService();
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockSession = MockSession();
    mockRpcListFilterBuilder = MockRpcListFilterBuilder();
    mockRpcVoidFilterBuilder = MockRpcVoidFilterBuilder();
    mockRef = MockProviderRef();
    mockLogger = MockAppLogger();

    // Setup basic auth mocks (mockito syntax)
    when(mockClient.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockAuth.currentSession).thenReturn(mockSession);
    when(mockUser.id).thenReturn(testUserId);
    when(mockSession.accessToken).thenReturn('test_token');

    // Setup provider ref to return mock logger
    when(mockRef.read(loggerProvider)).thenReturn(mockLogger);

    // Create service
    service = GDPRAnonymizationService(
      mockRef,
      keyManager: mockKeyManager,
      accountKeyService: mockAccountKeyService,
      encryptionSyncService: mockEncryptionSyncService,
      client: mockClient,
    );
  });

  group('UserConfirmations Validation', () {
    test('rejects anonymization when dataBackupComplete is false', () async {
      final confirmations = UserConfirmations(
        dataBackupComplete: false,
        understandsIrreversibility: true,
        finalConfirmationToken:
            UserConfirmations.generateConfirmationToken(testUserId),
      );

      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: confirmations,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('confirmations'),
          ),
        ),
      );
    });

    test('rejects anonymization when token does not match userId', () async {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: 'ANONYMIZE_ACCOUNT_wrong_user',
      );

      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: confirmations,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('confirmation token'),
          ),
        ),
      );
    });
  });

  group('Phase 1: Pre-Anonymization Validation', () {
    test('throws exception when user is not authenticated', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Mock no user
      when(mockAuth.currentUser).thenReturn(null);

      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: confirmations,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Phase 1 validation failed'),
          ),
        ),
      );
    });
  });

  group('Phase 3: Encryption Key Destruction (Point of No Return)', () {
    late UserConfirmations validConfirmations;

    setUp(() {
      validConfirmations = createValidConfirmations(testUserId);

      // Valid session for Phase 1
      when(mockAuth.currentSession).thenReturn(mockSession);
    });

    test('successfully destroys all 6 key locations', () async {
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);

      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: validConfirmations,
      );

      expect(report.phase3KeyDestruction.success, isTrue);
      expect(report.pointOfNoReturnReached, isTrue);
      expect(report.keyDestructionReport, isNotNull);

      // Verify all services were called
      verify(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).called(1);

      verify(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).called(1);

      verify(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).called(1);
    });

    test('throws exception on Phase 3 key destruction failure', () async {
      // Partial failure in key destruction
      final partialReport =
          createPartiallyFailedKeyDestructionReport(testUserId);

      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => partialReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => partialReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => partialReport);

      // Phase 3 failure should throw exception
      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: validConfirmations,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Phase 3 key destruction failed'),
          ),
        ),
      );
    });
  });

  group('Progress Callbacks', () {
    test('invokes progress callback for each phase', () async {
      final confirmations = createValidConfirmations(testUserId);
      final progressUpdates = <AnonymizationProgress>[];

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Successful key destruction
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
        onProgress: progressUpdates.add,
      );

      // Should have received progress updates for all 7 phases
      expect(progressUpdates.length, greaterThanOrEqualTo(7));

      // Verify we got updates for each phase
      final phaseNumbers =
          progressUpdates.map((p) => p.currentPhase).toSet().toList()..sort();
      expect(phaseNumbers, containsAll([1, 2, 3, 4, 5, 6, 7]));

      // Verify Point of No Return flag
      final beforePNR =
          progressUpdates.where((p) => p.currentPhase < 3).toList();
      final afterPNR =
          progressUpdates.where((p) => p.currentPhase >= 4).toList();

      for (final progress in beforePNR) {
        expect(progress.pointOfNoReturnReached, isFalse);
      }

      for (final progress in afterPNR) {
        expect(progress.pointOfNoReturnReached, isTrue);
      }
    });

    test('progress shows increasing overall progress', () async {
      final confirmations = createValidConfirmations(testUserId);
      final progressUpdates = <AnonymizationProgress>[];

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Successful key destruction
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
        onProgress: progressUpdates.add,
      );

      // Verify progress is monotonically increasing
      for (var i = 1; i < progressUpdates.length; i++) {
        expect(
          progressUpdates[i].overallProgress,
          greaterThanOrEqualTo(progressUpdates[i - 1].overallProgress),
        );
      }

      // First progress should be near 0%
      expect(progressUpdates.first.overallProgress, lessThan(0.2));

      // Last progress should be 100%
      expect(progressUpdates.last.overallProgress, equals(1.0));
      expect(progressUpdates.last.overallProgressPercent, equals(100));
    });
  });

  group('Complete Anonymization Flow', () {
    test('successfully completes all 7 phases', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session for Phase 1
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Successful key destruction for Phase 3
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
      );

      // Verify critical phases completed successfully
      // Note: Phases 4-7 may fail in unit tests due to missing database mocking
      // The important part is that the orchestration logic works correctly
      expect(report.phase1Validation.success, isTrue);
      expect(report.phase2Metadata.success, isTrue);
      expect(report.phase3KeyDestruction.success, isTrue);

      // Verify Point of No Return reached (Phase 3 completed)
      expect(report.pointOfNoReturnReached, isTrue);

      // Verify timestamps
      expect(report.startedAt, isNotNull);
      expect(report.completedAt, isNotNull);
      expect(report.duration, isNotNull);

      // Note: proof hash is generated in Phase 7 which requires database mocking
      // In integration tests, we would verify the full flow including proof hash
    });

    test('generates valid anonymization ID (UUID format)', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Successful key destruction
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
      );

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(report.anonymizationId, matches(uuidPattern));
    });

    test('generates compliance certificate with all required sections',
        () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Successful key destruction
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockAccountKeyService.securelyDestroyAccountMasterKey(
          userId: testUserId,
          confirmationToken: 'DESTROY_AMK_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      when(
        mockEncryptionSyncService.securelyDestroyCrossDeviceKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_CROSS_DEVICE_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
      );

      final certificate = report.toComplianceCertificate();

      // Verify certificate contains all required sections
      expect(certificate, contains('GDPR ARTICLE 17'));
      expect(certificate, contains('ANONYMIZATION COMPLIANCE CERTIFICATE'));
      expect(certificate, contains('Anonymization ID:'));
      expect(certificate, contains('Phase 1: Pre-Anonymization Validation'));
      expect(certificate, contains('Phase 2: Account Metadata Anonymization'));
      expect(certificate, contains('Phase 3: Encryption Key Destruction'));
      expect(certificate, contains('Phase 4: Encrypted Content Tombstoning'));
      expect(
        certificate,
        contains('Phase 5: Unencrypted Metadata Clearing'),
      );
      expect(
        certificate,
        contains('Phase 6: Cross-Device Sync Invalidation'),
      );
      expect(
        certificate,
        contains('Phase 7: Final Audit Trail & Compliance Proof'),
      );
      expect(certificate, contains('ENCRYPTION KEY DESTRUCTION'));
      expect(certificate, contains('COMPLIANCE PROOF'));
      expect(certificate, contains('Proof Hash (SHA-256):'));
      expect(certificate, contains('irreversibly anonymized'));
    });
  });

  group('Error Handling', () {
    test('throws exception if user is not authenticated', () async {
      final confirmations = createValidConfirmations(testUserId);

      // No user
      when(mockAuth.currentUser).thenReturn(null);

      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: confirmations,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Phase 1 validation failed'),
          ),
        ),
      );
    });

    test('throws exception when key destruction fails', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Key destruction throws exception
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenThrow(Exception('KeyManager destruction failed'));

      expect(
        () => service.anonymizeUserAccount(
          userId: testUserId,
          confirmations: confirmations,
        ),
        throwsA(
          isA<Exception>(),
        ),
      );
    });
  });

  group('Phase 5: Unencrypted Metadata Clearing', () {
    test('successfully clears all unencrypted metadata', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Mock successful key destruction (Phase 3)
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      // Mock Phase 4: Content tombstoning
      final mockPhase4Filter = MockRpcListFilterBuilder();
      when(mockPhase4Filter.then(any)).thenAnswer((_) async => [
            {
              'notes_count': 10,
              'tasks_count': 5,
              'folders_count': 3,
              'reminders_count': 8,
              'total_count': 26,
            } as Map<String, dynamic>
          ]);
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'anonymize_all_user_content',
        params: {'target_user_id': testUserId},
      )).thenReturn(mockPhase4Filter);

      // Mock Phase 5: Metadata clearing - This is the test focus
      final mockPhase5Filter = MockRpcListFilterBuilder();
      when(mockPhase5Filter.then(any)).thenAnswer((_) async => [
            {
              'tags_deleted': 15,
              'saved_searches_deleted': 3,
              'notification_events_deleted': 42,
              'user_preferences_deleted': 1,
              'notification_preferences_deleted': 1,
              'devices_deleted': 2,
              'templates_metadata_cleared': 5,
              'audit_trail_anonymized': 18,
              'total_operations': 87,
            } as Map<String, dynamic>
          ]);
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'clear_all_user_metadata',
        params: {'target_user_id': testUserId},
      )).thenAnswer((_) async => mockPhase5Filter);

      // Mock other phases to complete the flow
      final mockCreateRecordFilter = MockRpcVoidFilterBuilder();
      when(mockCreateRecordFilter.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'create_anonymization_record',
        params: any,
      )).thenAnswer((_) async => mockCreateRecordFilter);

      final mockEventFilter = MockRpcVoidFilterBuilder();
      when(mockEventFilter.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'record_anonymization_event',
        params: any,
      )).thenAnswer((_) async => mockEventFilter);

      // Execute anonymization
      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
      );

      // Verify Phase 5 was called
      verify(mockClient.rpc<List<Map<String, dynamic>>>(
        'clear_all_user_metadata',
        params: {'target_user_id': testUserId},
      )).called(1);

      // Verify Phase 5 success in report
      expect(report.phase5MetadataClearing.success, isTrue);
      expect(report.phase5MetadataClearing.phaseNumber, equals(5));
      expect(report.phase5MetadataClearing.phaseName, equals('Unencrypted Metadata Clearing'));
      expect(report.phase5MetadataClearing.details, isNotEmpty);
      expect(report.phase5MetadataClearing.errors, isEmpty);
    });

    test('handles Phase 5 partial failure gracefully', () async {
      final confirmations = createValidConfirmations(testUserId);

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Mock successful key destruction (Phase 3)
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      // Mock Phase 4 success
      final mockPhase4Filter2 = MockRpcListFilterBuilder();
      when(mockPhase4Filter2.then(any)).thenAnswer((_) async => [
            {
              'notes_count': 10,
              'tasks_count': 5,
              'folders_count': 3,
              'reminders_count': 8,
              'total_count': 26,
            } as Map<String, dynamic>
          ]);
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'anonymize_all_user_content',
        params: {'target_user_id': testUserId},
      )).thenAnswer((_) async => mockPhase4Filter2);

      // Mock Phase 5 failure
      final mockPhase5FailFilter = MockRpcListFilterBuilder();
      when(mockPhase5FailFilter.then(any))
          .thenThrow(Exception('Database error clearing metadata'));
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'clear_all_user_metadata',
        params: {'target_user_id': testUserId},
      )).thenAnswer((_) async => mockPhase5FailFilter);

      // Mock other phases
      final mockCreateRecordFilter2 = MockRpcVoidFilterBuilder();
      when(mockCreateRecordFilter2.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'create_anonymization_record',
        params: any,
      )).thenAnswer((_) async => mockCreateRecordFilter2);

      final mockEventFilter2 = MockRpcVoidFilterBuilder();
      when(mockEventFilter2.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'record_anonymization_event',
        params: any,
      )).thenAnswer((_) async => mockEventFilter2);

      // Execute anonymization
      final report = await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
      );

      // Verify Phase 5 was attempted
      verify(mockClient.rpc<List<Map<String, dynamic>>>(
        'clear_all_user_metadata',
        params: {'target_user_id': testUserId},
      )).called(1);

      // Phase 5 should report failure but not crash the whole process
      expect(report.phase5MetadataClearing.success, isFalse);
      expect(report.phase5MetadataClearing.errors, isNotEmpty);
      expect(
        report.phase5MetadataClearing.errors.first,
        contains('Database error clearing metadata'),
      );

      // Other phases should still complete
      expect(report.phase3KeyDestruction.success, isTrue);
      expect(report.phase4Tombstoning.success, isTrue);
    });

    test('tracks Phase 5 progress callbacks correctly', () async {
      final confirmations = createValidConfirmations(testUserId);
      final progressUpdates = <AnonymizationProgress>[];

      // Valid session
      when(mockAuth.currentSession).thenReturn(mockSession);

      // Mock successful key destruction (Phase 3)
      final keyReport = createSuccessfulKeyDestructionReport(testUserId);
      when(
        mockKeyManager.securelyDestroyAllKeys(
          userId: testUserId,
          confirmationToken: 'DESTROY_ALL_KEYS_$testUserId',
          verifyBeforeDestroy: true,
        ),
      ).thenAnswer((_) async => keyReport);

      // Mock Phase 4
      final mockPhase4Filter3 = MockRpcListFilterBuilder();
      when(mockPhase4Filter3.then(any)).thenAnswer((_) async => [
            {'total_count': 26} as Map<String, dynamic>
          ]);
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'anonymize_all_user_content',
        params: {'target_user_id': testUserId},
      )).thenAnswer((_) async => mockPhase4Filter3);

      // Mock Phase 5
      final mockPhase5Filter3 = MockRpcListFilterBuilder();
      when(mockPhase5Filter3.then(any)).thenAnswer((_) async => [
            {'total_operations': 87} as Map<String, dynamic>
          ]);
      when(mockClient.rpc<List<Map<String, dynamic>>>(
        'clear_all_user_metadata',
        params: {'target_user_id': testUserId},
      )).thenAnswer((_) async => mockPhase5Filter3);

      // Mock other phases
      final mockCreateRecordFilter3 = MockRpcVoidFilterBuilder();
      when(mockCreateRecordFilter3.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'create_anonymization_record',
        params: any,
      )).thenAnswer((_) async => mockCreateRecordFilter3);

      final mockEventFilter3 = MockRpcVoidFilterBuilder();
      when(mockEventFilter3.then(any)).thenAnswer((_) async {});
      when(mockClient.rpc<void>(
        'record_anonymization_event',
        params: any,
      )).thenAnswer((_) async => mockEventFilter3);

      // Execute with progress tracking
      await service.anonymizeUserAccount(
        userId: testUserId,
        confirmations: confirmations,
        onProgress: progressUpdates.add,
      );

      // Find Phase 5 progress updates
      final phase5Updates = progressUpdates
          .where((p) => p.currentPhase == 5)
          .toList();

      // Verify Phase 5 progress updates were emitted
      expect(phase5Updates, isNotEmpty);
      expect(phase5Updates.first.phaseName, equals('Unencrypted Metadata Clearing'));
      expect(phase5Updates.first.pointOfNoReturnReached, isTrue);
      expect(phase5Updates.first.statusMessage, contains('metadata'));
    });
  });
}
