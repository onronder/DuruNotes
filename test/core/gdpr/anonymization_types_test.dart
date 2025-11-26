/// Unit tests for GDPR anonymization supporting types
///
/// Tests all types used by GDPRAnonymizationService:
/// - UserConfirmations
/// - AnonymizationProgress
/// - PhaseReport
/// - GDPRAnonymizationReport
///
/// **Test Coverage**:
/// - Validation logic (confirmation tokens, all confirmations)
/// - Progress calculations (per-phase and overall)
/// - Phase state transitions (notStarted -> start -> complete/fail)
/// - Report generation (JSON, compliance certificate)
/// - Edge cases and error conditions
library;

import 'package:duru_notes/core/crypto/key_destruction_report.dart';
import 'package:duru_notes/core/gdpr/anonymization_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserConfirmations', () {
    const testUserId = 'user_123';
    const validToken = 'DELETE MY ACCOUNT';

    test('generateConfirmationToken creates correct format', () {
      final token = UserConfirmations.generateConfirmationToken(testUserId);
      expect(token, equals('DELETE MY ACCOUNT'));
    });

    test('validateToken returns true for correct token', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: validToken,
        acknowledgesRisks: true,
      );

      expect(confirmations.validateToken(testUserId), isTrue);
    });

    test('validateToken returns false for incorrect token', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: 'WRONG_TOKEN',
        acknowledgesRisks: true,
      );

      expect(confirmations.validateToken(testUserId), isFalse);
    });

    test('validateToken is case-insensitive', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: 'delete my account', // lowercase
        acknowledgesRisks: true,
      );

      expect(confirmations.validateToken(testUserId), isTrue);
    });

    test('allConfirmed returns true when all confirmations provided', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: validToken,
        acknowledgesRisks: true,
      );

      expect(confirmations.allConfirmed, isTrue);
    });

    test('allConfirmed returns false when dataBackupComplete is false', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: false,
        understandsIrreversibility: true,
        finalConfirmationToken: validToken,
        acknowledgesRisks: true,
      );

      expect(confirmations.allConfirmed, isFalse);
    });

    test(
      'allConfirmed returns false when understandsIrreversibility is false',
      () {
        final confirmations = UserConfirmations(
          dataBackupComplete: true,
          understandsIrreversibility: false,
          finalConfirmationToken: validToken,
          acknowledgesRisks: true,
        );

        expect(confirmations.allConfirmed, isFalse);
      },
    );

    test('allConfirmed returns false when token is empty', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: '',
        acknowledgesRisks: true,
      );

      expect(confirmations.allConfirmed, isFalse);
    });

    test('toJson includes all confirmation data', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: validToken,
        acknowledgesRisks: true,
      );

      final json = confirmations.toJson();

      expect(json['dataBackupComplete'], isTrue);
      expect(json['understandsIrreversibility'], isTrue);
      expect(json['finalConfirmationTokenProvided'], isTrue);
    });

    test('toJson shows false when token not provided', () {
      final confirmations = UserConfirmations(
        dataBackupComplete: true,
        understandsIrreversibility: true,
        finalConfirmationToken: '',
        acknowledgesRisks: true,
      );

      final json = confirmations.toJson();

      expect(json['finalConfirmationTokenProvided'], isFalse);
    });
  });

  group('AnonymizationProgress', () {
    test('overallProgress calculated correctly for first phase', () {
      final progress = AnonymizationProgress(
        currentPhase: 1,
        phaseName: 'Validation',
        phaseProgress: 0.5,
        statusMessage: 'Validating...',
        pointOfNoReturnReached: false,
      );

      // Phase 1 at 50% = 0/7 + 0.5/7 = 0.0714...
      expect(progress.overallProgress, closeTo(0.0714, 0.001));
    });

    test('overallProgress calculated correctly for middle phase', () {
      final progress = AnonymizationProgress(
        currentPhase: 4,
        phaseName: 'Tombstoning',
        phaseProgress: 0.75,
        statusMessage: 'Creating tombstones...',
        pointOfNoReturnReached: true,
      );

      // Phase 4 at 75% = 3/7 + 0.75/7 = 0.5357...
      expect(progress.overallProgress, closeTo(0.5357, 0.001));
    });

    test('overallProgress calculated correctly for last phase complete', () {
      final progress = AnonymizationProgress(
        currentPhase: 7,
        phaseName: 'Compliance Proof',
        phaseProgress: 1.0,
        statusMessage: 'Complete',
        pointOfNoReturnReached: true,
      );

      // Phase 7 at 100% = 6/7 + 1.0/7 = 1.0
      expect(progress.overallProgress, equals(1.0));
    });

    test('overallProgressPercent rounds correctly', () {
      final progress = AnonymizationProgress(
        currentPhase: 4,
        phaseName: 'Tombstoning',
        phaseProgress: 0.75,
        statusMessage: 'Creating tombstones...',
        pointOfNoReturnReached: true,
      );

      // 0.5357 * 100 = 53.57 -> rounds to 54
      expect(progress.overallProgressPercent, equals(54));
    });

    test('pointOfNoReturnReached reflects current state', () {
      final beforePNR = AnonymizationProgress(
        currentPhase: 2,
        phaseName: 'Metadata',
        phaseProgress: 0.5,
        statusMessage: 'Anonymizing metadata...',
        pointOfNoReturnReached: false,
      );

      expect(beforePNR.pointOfNoReturnReached, isFalse);

      final afterPNR = AnonymizationProgress(
        currentPhase: 4,
        phaseName: 'Tombstoning',
        phaseProgress: 0.5,
        statusMessage: 'Creating tombstones...',
        pointOfNoReturnReached: true,
      );

      expect(afterPNR.pointOfNoReturnReached, isTrue);
    });

    test('toJson includes all progress data', () {
      final progress = AnonymizationProgress(
        currentPhase: 3,
        phaseName: 'Key Destruction',
        phaseProgress: 0.8,
        statusMessage: 'Destroying keys...',
        pointOfNoReturnReached: false,
      );

      final json = progress.toJson();

      expect(json['currentPhase'], equals(3));
      expect(json['phaseName'], equals('Key Destruction'));
      expect(json['phaseProgress'], equals(0.8));
      expect(json['statusMessage'], equals('Destroying keys...'));
      expect(json['pointOfNoReturnReached'], isFalse);
      expect(json['overallProgress'], isA<double>());
      expect(json['overallProgressPercent'], isA<int>());
    });
  });

  group('PhaseReport', () {
    test('notStarted factory creates correct initial state', () {
      final report = PhaseReport.notStarted(1, 'Validation');

      expect(report.phaseNumber, equals(1));
      expect(report.phaseName, equals('Validation'));
      expect(report.completed, isFalse);
      expect(report.success, isFalse);
      expect(report.startedAt, isNull);
      expect(report.completedAt, isNull);
      expect(report.errors, isEmpty);
      expect(report.details, isEmpty);
    });

    test('start() sets startedAt timestamp', () {
      final initial = PhaseReport.notStarted(1, 'Validation');
      final started = initial.start();

      expect(started.startedAt, isNotNull);
      expect(started.completed, isFalse);
      expect(started.success, isFalse);
    });

    test('complete() marks phase as successful', () {
      final initial = PhaseReport.notStarted(1, 'Validation');
      final started = initial.start();
      final completed = started.complete();

      expect(completed.completed, isTrue);
      expect(completed.success, isTrue);
      expect(completed.completedAt, isNotNull);
      expect(completed.errors, isEmpty);
    });

    test('complete() can add additional details', () {
      final initial = PhaseReport.notStarted(3, 'Key Destruction');
      final started = initial.start();
      final completed = started.complete(
        additionalDetails: {'keysDestroyed': 6},
      );

      expect(completed.details['keysDestroyed'], equals(6));
    });

    test('fail() marks phase as failed with error', () {
      final initial = PhaseReport.notStarted(1, 'Validation');
      final started = initial.start();
      final failed = started.fail('Session invalid');

      expect(failed.completed, isTrue);
      expect(failed.success, isFalse);
      expect(failed.completedAt, isNotNull);
      expect(failed.errors, contains('Session invalid'));
    });

    test('fail() can accumulate multiple errors', () {
      final initial = PhaseReport.notStarted(1, 'Validation');
      final started = initial.start();
      final failed1 = started.fail('Error 1');
      final failed2 = failed1.fail('Error 2');

      expect(failed2.errors.length, equals(2));
      expect(failed2.errors, contains('Error 1'));
      expect(failed2.errors, contains('Error 2'));
    });

    test('duration calculated correctly', () {
      final initial = PhaseReport.notStarted(1, 'Validation');

      // Manually set timestamps for predictable duration
      final started = PhaseReport(
        phaseNumber: 1,
        phaseName: 'Validation',
        completed: false,
        success: false,
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
      );

      final completed = PhaseReport(
        phaseNumber: 1,
        phaseName: 'Validation',
        completed: true,
        success: true,
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        completedAt: DateTime(2025, 1, 1, 12, 0, 5),
      );

      expect(completed.duration, equals(const Duration(seconds: 5)));
    });

    test('duration is null when not started', () {
      final report = PhaseReport.notStarted(1, 'Validation');
      expect(report.duration, isNull);
    });

    test('duration is null when started but not completed', () {
      final started = PhaseReport.notStarted(1, 'Validation').start();
      expect(started.duration, isNull);
    });

    test('toJson includes all phase data', () {
      final report = PhaseReport(
        phaseNumber: 3,
        phaseName: 'Key Destruction',
        completed: true,
        success: true,
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        completedAt: DateTime(2025, 1, 1, 12, 0, 5),
        errors: [],
        details: {'keysDestroyed': 6},
      );

      final json = report.toJson();

      expect(json['phaseNumber'], equals(3));
      expect(json['phaseName'], equals('Key Destruction'));
      expect(json['completed'], isTrue);
      expect(json['success'], isTrue);
      expect(json['startedAt'], isNotNull);
      expect(json['completedAt'], isNotNull);
      expect(json['durationMs'], equals(5000));
      expect(json['errors'], isEmpty);
      expect(json['details']['keysDestroyed'], equals(6));
    });
  });

  group('GDPRAnonymizationReport', () {
    late GDPRAnonymizationReport successReport;
    late GDPRAnonymizationReport partialFailureReport;

    setUp(() {
      // Create a successful KeyDestructionReport
      final keyReport = KeyDestructionReport(userId: 'user_456')
        ..memoryKeyDestroyed = true
        ..legacyKeyDestroyed = true
        ..localAmkDestroyed = true
        ..remoteAmkDestroyed = true
        ..localCrossDeviceKeyDestroyed = true
        ..remoteCrossDeviceKeyDestroyed = true;

      // Create a successful report
      successReport = GDPRAnonymizationReport(
        anonymizationId: 'anon_123',
        userId: 'user_456',
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        completedAt: DateTime(2025, 1, 1, 12, 0, 30),
        success: true,
        errors: [],
        phase1Validation: PhaseReport.notStarted(
          1,
          'Pre-Anonymization Validation',
        ).start().complete(),
        phase2Metadata: PhaseReport.notStarted(
          2,
          'Account Metadata Anonymization',
        ).start().complete(),
        phase3KeyDestruction: PhaseReport.notStarted(
          3,
          'Encryption Key Destruction',
        ).start().complete(additionalDetails: {'keysDestroyed': 6}),
        phase4Tombstoning: PhaseReport.notStarted(
          4,
          'Encrypted Content Tombstoning',
        ).start().complete(),
        phase5MetadataClearing: PhaseReport.notStarted(
          5,
          'Unencrypted Metadata Clearing',
        ).start().complete(),
        phase6SyncInvalidation: PhaseReport.notStarted(
          6,
          'Cross-Device Sync Invalidation',
        ).start().complete(),
        phase7ComplianceProof: PhaseReport.notStarted(
          7,
          'Final Audit Trail & Compliance Proof',
        ).start().complete(),
        keyDestructionReport: keyReport,
        proofHash: 'abc123def456',
      );

      // Create a partial failure report
      partialFailureReport = GDPRAnonymizationReport(
        anonymizationId: 'anon_789',
        userId: 'user_012',
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        completedAt: DateTime(2025, 1, 1, 12, 0, 30),
        success: false,
        errors: ['Phase 6 failed: Network error'],
        phase1Validation: PhaseReport.notStarted(
          1,
          'Pre-Anonymization Validation',
        ).start().complete(),
        phase2Metadata: PhaseReport.notStarted(
          2,
          'Account Metadata Anonymization',
        ).start().complete(),
        phase3KeyDestruction: PhaseReport.notStarted(
          3,
          'Encryption Key Destruction',
        ).start().complete(),
        phase4Tombstoning: PhaseReport.notStarted(
          4,
          'Encrypted Content Tombstoning',
        ).start().complete(),
        phase5MetadataClearing: PhaseReport.notStarted(
          5,
          'Unencrypted Metadata Clearing',
        ).start().complete(),
        phase6SyncInvalidation: PhaseReport.notStarted(
          6,
          'Cross-Device Sync Invalidation',
        ).start().fail('Network error'),
        phase7ComplianceProof: PhaseReport.notStarted(
          7,
          'Final Audit Trail & Compliance Proof',
        ).start().complete(),
      );
    });

    test('duration calculated correctly', () {
      expect(successReport.duration, equals(const Duration(seconds: 30)));
    });

    test('pointOfNoReturnReached true when Phase 3 completed', () {
      expect(successReport.pointOfNoReturnReached, isTrue);
    });

    test('pointOfNoReturnReached false when Phase 3 not completed', () {
      final notReachedReport = GDPRAnonymizationReport(
        anonymizationId: 'anon_123',
        userId: 'user_456',
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        success: false,
        phase1Validation: PhaseReport.notStarted(
          1,
          'Pre-Anonymization Validation',
        ).start().complete(),
        phase2Metadata: PhaseReport.notStarted(
          2,
          'Account Metadata Anonymization',
        ).start().fail('Error'),
        phase3KeyDestruction: PhaseReport.notStarted(
          3,
          'Encryption Key Destruction',
        ),
        phase4Tombstoning: PhaseReport.notStarted(
          4,
          'Encrypted Content Tombstoning',
        ),
        phase5MetadataClearing: PhaseReport.notStarted(
          5,
          'Unencrypted Metadata Clearing',
        ),
        phase6SyncInvalidation: PhaseReport.notStarted(
          6,
          'Cross-Device Sync Invalidation',
        ),
        phase7ComplianceProof: PhaseReport.notStarted(
          7,
          'Final Audit Trail & Compliance Proof',
        ),
      );

      expect(notReachedReport.pointOfNoReturnReached, isFalse);
    });

    test('successfulPhasesCount counts all successful phases', () {
      expect(successReport.successfulPhasesCount, equals(7));
    });

    test('successfulPhasesCount excludes failed phases', () {
      expect(partialFailureReport.successfulPhasesCount, equals(6));
    });

    test('toJson includes all report data', () {
      final json = successReport.toJson();

      expect(json['anonymizationId'], equals('anon_123'));
      expect(json['userId'], equals('user_456'));
      expect(json['startedAt'], isNotNull);
      expect(json['completedAt'], isNotNull);
      expect(json['durationSeconds'], equals(30));
      expect(json['success'], isTrue);
      expect(json['errors'], isEmpty);
      expect(json['successfulPhasesCount'], equals(7));
      expect(json['pointOfNoReturnReached'], isTrue);
      expect(json['phases'], isA<Map>());
      expect(json['phases']['phase1'], isA<Map>());
      expect(json['phases']['phase7'], isA<Map>());
      expect(json['keyDestruction'], isA<Map>());
      expect(json['proofHash'], equals('abc123def456'));
    });

    test('toPrettyJson creates formatted JSON string', () {
      final prettyJson = successReport.toPrettyJson();

      expect(prettyJson, contains('"anonymizationId": "anon_123"'));
      expect(prettyJson, contains('"success": true'));
      // Should have indentation (pretty-printed)
      expect(prettyJson, contains('  '));
    });

    test('toString creates compact JSON string', () {
      final compactJson = successReport.toString();

      expect(compactJson, contains('"anonymizationId":"anon_123"'));
      expect(compactJson, contains('"success":true'));
      // Should NOT have extra whitespace (compact)
      expect(compactJson, isNot(contains('  ')));
    });

    test('toComplianceCertificate includes all required sections', () {
      final certificate = successReport.toComplianceCertificate();

      // Header
      expect(certificate, contains('GDPR ARTICLE 17 - RIGHT TO ERASURE'));
      expect(certificate, contains('ANONYMIZATION COMPLIANCE CERTIFICATE'));

      // Basic info
      expect(certificate, contains('Anonymization ID: anon_123'));
      expect(certificate, contains('Duration: 30 seconds'));
      expect(certificate, contains('Status: ✅ SUCCESS'));

      // All phases
      expect(certificate, contains('Phase 1: Pre-Anonymization Validation'));
      expect(certificate, contains('Phase 2: Account Metadata Anonymization'));
      expect(certificate, contains('Phase 3: Encryption Key Destruction'));
      expect(certificate, contains('Phase 4: Encrypted Content Tombstoning'));
      expect(certificate, contains('Phase 5: Unencrypted Metadata Clearing'));
      expect(certificate, contains('Phase 6: Cross-Device Sync Invalidation'));
      expect(
        certificate,
        contains('Phase 7: Final Audit Trail & Compliance Proof'),
      );

      // Key destruction
      expect(certificate, contains('ENCRYPTION KEY DESTRUCTION'));

      // Compliance proof
      expect(certificate, contains('COMPLIANCE PROOF'));
      expect(certificate, contains('Proof Hash (SHA-256): abc123def456'));

      // Footer
      expect(certificate, contains('irreversibly anonymized'));
      expect(certificate, contains('GDPR Article 17'));
    });

    test('toComplianceCertificate shows failure status correctly', () {
      final certificate = partialFailureReport.toComplianceCertificate();

      expect(certificate, contains('Status: ❌ FAILED'));
      expect(certificate, contains('❌ FAILED')); // Phase 6 status
    });

    test('toComplianceCertificate handles missing key destruction report', () {
      final noKeyReport = GDPRAnonymizationReport(
        anonymizationId: 'anon_999',
        userId: 'user_999',
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        success: false,
        phase1Validation: PhaseReport.notStarted(
          1,
          'Pre-Anonymization Validation',
        ).start().fail('Error'),
        phase2Metadata: PhaseReport.notStarted(
          2,
          'Account Metadata Anonymization',
        ),
        phase3KeyDestruction: PhaseReport.notStarted(
          3,
          'Encryption Key Destruction',
        ),
        phase4Tombstoning: PhaseReport.notStarted(
          4,
          'Encrypted Content Tombstoning',
        ),
        phase5MetadataClearing: PhaseReport.notStarted(
          5,
          'Unencrypted Metadata Clearing',
        ),
        phase6SyncInvalidation: PhaseReport.notStarted(
          6,
          'Cross-Device Sync Invalidation',
        ),
        phase7ComplianceProof: PhaseReport.notStarted(
          7,
          'Final Audit Trail & Compliance Proof',
        ),
      );

      final certificate = noKeyReport.toComplianceCertificate();

      expect(certificate, contains('No key destruction performed'));
    });

    test('toComplianceCertificate handles pending proof hash', () {
      final noPendingReport = GDPRAnonymizationReport(
        anonymizationId: 'anon_999',
        userId: 'user_999',
        startedAt: DateTime(2025, 1, 1, 12, 0, 0),
        success: false,
        phase1Validation: PhaseReport.notStarted(
          1,
          'Pre-Anonymization Validation',
        ),
        phase2Metadata: PhaseReport.notStarted(
          2,
          'Account Metadata Anonymization',
        ),
        phase3KeyDestruction: PhaseReport.notStarted(
          3,
          'Encryption Key Destruction',
        ),
        phase4Tombstoning: PhaseReport.notStarted(
          4,
          'Encrypted Content Tombstoning',
        ),
        phase5MetadataClearing: PhaseReport.notStarted(
          5,
          'Unencrypted Metadata Clearing',
        ),
        phase6SyncInvalidation: PhaseReport.notStarted(
          6,
          'Cross-Device Sync Invalidation',
        ),
        phase7ComplianceProof: PhaseReport.notStarted(
          7,
          'Final Audit Trail & Compliance Proof',
        ),
        proofHash: null,
      );

      final certificate = noPendingReport.toComplianceCertificate();

      expect(certificate, contains('Proof Hash (SHA-256): PENDING'));
    });
  });
}
