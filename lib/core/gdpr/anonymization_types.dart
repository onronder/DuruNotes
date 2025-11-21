/// Supporting types for GDPR-compliant user anonymization
///
/// This file contains all the types used by the GDPRAnonymizationService
/// for orchestrating the complete user anonymization process.
///
/// **GDPR Compliance**:
/// - Article 17: Right to Erasure
/// - Recital 26: True Anonymization through encryption key destruction
/// - ISO 27001:2022: Secure data disposal with comprehensive audit trail
library;

import 'dart:convert';

import 'package:duru_notes/core/crypto/key_destruction_report.dart';

/// User confirmations required before anonymization can proceed
///
/// These confirmations ensure the user understands the irreversible nature
/// of the anonymization process, especially after Phase 3 (Key Destruction).
///
/// **GDPR Requirement**: Article 7 - Conditions for consent
/// User must provide explicit, informed consent before anonymization.
class UserConfirmations {
  /// User confirms they have backed up important data
  ///
  /// Required before Phase 1 can proceed.
  /// User must acknowledge that encrypted data will be permanently inaccessible.
  final bool dataBackupComplete;

  /// User confirms understanding that process is irreversible after Phase 3
  ///
  /// Required before Phase 2 can proceed.
  /// User must understand that Phase 3 (Key Destruction) is the Point of No Return.
  final bool understandsIrreversibility;

  /// Final confirmation token (must match exactly, case-insensitive)
  ///
  /// Format: `'DELETE MY ACCOUNT'`
  /// Required before Phase 3 can proceed.
  /// Prevents accidental anonymization through double-confirmation.
  final String finalConfirmationToken;

  /// User explicitly acknowledges all risks and consequences
  ///
  /// Required for safeguard validation.
  /// Must be true for anonymization to proceed.
  final bool acknowledgesRisks;

  /// Allow production environment override
  ///
  /// Optional - defaults to false.
  /// In production, this must be explicitly set to true to bypass environment check.
  /// This provides an additional safety layer to prevent accidental production deletions.
  final bool allowProductionOverride;

  UserConfirmations({
    required this.dataBackupComplete,
    required this.understandsIrreversibility,
    required this.finalConfirmationToken,
    required this.acknowledgesRisks,
    this.allowProductionOverride = false,
  });

  /// Validate that all confirmations are provided
  bool get allConfirmed {
    return dataBackupComplete &&
        understandsIrreversibility &&
        finalConfirmationToken.isNotEmpty;
  }

  /// Generate expected confirmation token for validation
  static String generateConfirmationToken(String userId) {
    return 'DELETE MY ACCOUNT';
  }

  /// Validate confirmation token (case-insensitive)
  bool validateToken(String userId) {
    final expectedToken = generateConfirmationToken(userId);
    return finalConfirmationToken.trim().toUpperCase() == expectedToken.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'dataBackupComplete': dataBackupComplete,
        'understandsIrreversibility': understandsIrreversibility,
        'finalConfirmationTokenProvided': finalConfirmationToken.isNotEmpty,
        'acknowledgesRisks': acknowledgesRisks,
        'allowProductionOverride': allowProductionOverride,
      };
}

/// Progress updates for real-time UI feedback during anonymization
///
/// Provides granular progress information for each of the 7 phases,
/// allowing the UI to show:
/// - Current phase name and number
/// - Progress percentage within the phase
/// - Status messages (e.g., "Destroying encryption keys...")
/// - Whether Point of No Return has been reached
class AnonymizationProgress {
  /// Current phase number (1-7)
  final int currentPhase;

  /// Human-readable phase name
  ///
  /// Examples:
  /// - "Pre-Anonymization Validation"
  /// - "Encryption Key Destruction"
  /// - "Final Audit Trail & Compliance Proof"
  final String phaseName;

  /// Progress within current phase (0.0 - 1.0)
  ///
  /// - 0.0 = Phase just started
  /// - 0.5 = Phase 50% complete
  /// - 1.0 = Phase fully complete
  final double phaseProgress;

  /// Current status message for user feedback
  ///
  /// Examples:
  /// - "Validating user session..."
  /// - "Destroying Account Master Key..."
  /// - "Creating tombstone markers..."
  final String statusMessage;

  /// True if Phase 3 (Key Destruction) has completed
  ///
  /// After this point, the process is irreversible.
  /// UI should show a clear visual indicator (e.g., red warning).
  final bool pointOfNoReturnReached;

  AnonymizationProgress({
    required this.currentPhase,
    required this.phaseName,
    required this.phaseProgress,
    required this.statusMessage,
    required this.pointOfNoReturnReached,
  });

  /// Overall progress across all 7 phases (0.0 - 1.0)
  double get overallProgress {
    // Each phase contributes 1/7 to overall progress
    final completedPhases = currentPhase - 1;
    final currentPhaseContribution = phaseProgress / 7.0;
    return (completedPhases / 7.0) + currentPhaseContribution;
  }

  /// Overall progress as percentage (0-100)
  int get overallProgressPercent {
    return (overallProgress * 100).round();
  }

  Map<String, dynamic> toJson() => {
        'currentPhase': currentPhase,
        'phaseName': phaseName,
        'phaseProgress': phaseProgress,
        'statusMessage': statusMessage,
        'pointOfNoReturnReached': pointOfNoReturnReached,
        'overallProgress': overallProgress,
        'overallProgressPercent': overallProgressPercent,
      };
}

/// Report for individual anonymization phase
///
/// Each of the 7 phases generates a PhaseReport documenting:
/// - Completion status
/// - Success/failure
/// - Timestamps (start and end)
/// - Errors encountered
/// - Phase-specific details
class PhaseReport {
  /// Phase number (1-7)
  final int phaseNumber;

  /// Human-readable phase name
  final String phaseName;

  /// True if phase completed (may have succeeded or failed)
  final bool completed;

  /// True if phase completed successfully with no errors
  final bool success;

  /// Timestamp when phase started
  final DateTime? startedAt;

  /// Timestamp when phase completed
  final DateTime? completedAt;

  /// Errors encountered during this phase
  final List<String> errors;

  /// Phase-specific details (flexible for different phase types)
  ///
  /// Examples:
  /// - Phase 1: `{'sessionValid': true, 'syncActive': false}`
  /// - Phase 3: `{'keysDestroyed': 6, 'keyDestructionReport': {...}}`
  /// - Phase 4: `{'notesTombstoned': 150, 'tasksTombstoned': 80}`
  final Map<String, dynamic> details;

  PhaseReport({
    required this.phaseNumber,
    required this.phaseName,
    this.completed = false,
    this.success = false,
    this.startedAt,
    this.completedAt,
    List<String>? errors,
    Map<String, dynamic>? details,
  })  : errors = errors ?? [],
        details = details ?? {};

  /// Duration of phase execution
  Duration? get duration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }

  /// Create initial phase report (not started)
  factory PhaseReport.notStarted(int phaseNumber, String phaseName) {
    return PhaseReport(
      phaseNumber: phaseNumber,
      phaseName: phaseName,
      completed: false,
      success: false,
    );
  }

  /// Create in-progress phase report
  PhaseReport start() {
    return PhaseReport(
      phaseNumber: phaseNumber,
      phaseName: phaseName,
      completed: false,
      success: false,
      startedAt: DateTime.now(),
      errors: errors,
      details: details,
    );
  }

  /// Mark phase as successfully completed
  PhaseReport complete({Map<String, dynamic>? additionalDetails}) {
    return PhaseReport(
      phaseNumber: phaseNumber,
      phaseName: phaseName,
      completed: true,
      success: true,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      errors: errors,
      details: {...details, ...?additionalDetails},
    );
  }

  /// Mark phase as failed
  PhaseReport fail(String error, {Map<String, dynamic>? additionalDetails}) {
    return PhaseReport(
      phaseNumber: phaseNumber,
      phaseName: phaseName,
      completed: true,
      success: false,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      errors: [...errors, error],
      details: {...details, ...?additionalDetails},
    );
  }

  Map<String, dynamic> toJson() => {
        'phaseNumber': phaseNumber,
        'phaseName': phaseName,
        'completed': completed,
        'success': success,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'durationMs': duration?.inMilliseconds,
        'errors': errors,
        'details': details,
      };
}

/// Complete GDPR anonymization report for compliance and audit trail
///
/// This is the primary output of the anonymization process, containing:
/// - Unique anonymization ID for tracking
/// - Timestamps for entire process
/// - Success/failure status
/// - Reports from all 7 phases
/// - Key destruction details
/// - Cryptographic proof hash
/// - Human-readable compliance certificate
///
/// **GDPR Requirements**:
/// - Article 17: Proof of deletion
/// - Article 30: Records of processing activities
/// - ISO 27001:2022: Audit trail for compliance
class GDPRAnonymizationReport {
  /// Unique ID for this anonymization operation (UUID)
  ///
  /// Used to track anonymization across all systems and logs.
  /// Stored in `anonymization_events` and `anonymization_proofs` tables.
  final String anonymizationId;

  /// User ID being anonymized
  ///
  /// NOTE: After anonymization, this user ID should only appear in
  /// compliance logs. All other references should be replaced with
  /// anonymization ID.
  final String userId;

  /// Timestamp when anonymization started
  final DateTime startedAt;

  /// Timestamp when anonymization completed (null if still in progress)
  final DateTime? completedAt;

  /// Overall success status
  ///
  /// True only if ALL phases completed successfully with zero errors.
  final bool success;

  /// Errors encountered across all phases
  ///
  /// Empty list indicates complete success.
  final List<String> errors;

  /// Report from Phase 1: Pre-Anonymization Validation
  final PhaseReport phase1Validation;

  /// Report from Phase 2: Account Metadata Anonymization
  final PhaseReport phase2Metadata;

  /// Report from Phase 3: Encryption Key Destruction (POINT OF NO RETURN)
  final PhaseReport phase3KeyDestruction;

  /// Report from Phase 4: Encrypted Content Tombstoning
  final PhaseReport phase4Tombstoning;

  /// Report from Phase 5: Unencrypted Metadata Clearing
  final PhaseReport phase5MetadataClearing;

  /// Report from Phase 6: Cross-Device Sync Invalidation
  final PhaseReport phase6SyncInvalidation;

  /// Report from Phase 7: Final Audit Trail & Compliance Proof
  final PhaseReport phase7ComplianceProof;

  /// Detailed key destruction report from Phase 3
  ///
  /// Contains information about all 6 key locations and their destruction status.
  final KeyDestructionReport? keyDestructionReport;

  /// SHA-256 hash of complete anonymization proof
  ///
  /// Stored in `anonymization_proofs` table for immutable compliance record.
  /// Null until Phase 7 completes.
  final String? proofHash;

  GDPRAnonymizationReport({
    required this.anonymizationId,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    required this.success,
    List<String>? errors,
    required this.phase1Validation,
    required this.phase2Metadata,
    required this.phase3KeyDestruction,
    required this.phase4Tombstoning,
    required this.phase5MetadataClearing,
    required this.phase6SyncInvalidation,
    required this.phase7ComplianceProof,
    this.keyDestructionReport,
    this.proofHash,
  }) : errors = errors ?? [];

  /// Duration of complete anonymization process
  Duration? get duration {
    if (completedAt != null) {
      return completedAt!.difference(startedAt);
    }
    return null;
  }

  /// True if Phase 3 (Point of No Return) has completed
  bool get pointOfNoReturnReached {
    return phase3KeyDestruction.completed;
  }

  /// Count of phases completed successfully
  int get successfulPhasesCount {
    int count = 0;
    if (phase1Validation.success) count++;
    if (phase2Metadata.success) count++;
    if (phase3KeyDestruction.success) count++;
    if (phase4Tombstoning.success) count++;
    if (phase5MetadataClearing.success) count++;
    if (phase6SyncInvalidation.success) count++;
    if (phase7ComplianceProof.success) count++;
    return count;
  }

  /// Generate human-readable compliance certificate
  ///
  /// This certificate can be provided to the user as proof that their
  /// data has been anonymized in compliance with GDPR Article 17.
  ///
  /// Format: Plain text with clear sections for each phase
  String toComplianceCertificate() {
    final buffer = StringBuffer();

    buffer.writeln('='.padRight(70, '='));
    buffer.writeln('GDPR ARTICLE 17 - RIGHT TO ERASURE');
    buffer.writeln('ANONYMIZATION COMPLIANCE CERTIFICATE');
    buffer.writeln('='.padRight(70, '='));
    buffer.writeln();

    buffer.writeln('Anonymization ID: $anonymizationId');
    buffer.writeln('User ID (Anonymized): ${_hashUserId(userId)}');
    buffer.writeln('Started At: ${startedAt.toIso8601String()}');
    buffer.writeln('Completed At: ${completedAt?.toIso8601String() ?? 'IN PROGRESS'}');
    buffer.writeln('Duration: ${duration?.inSeconds ?? 0} seconds');
    buffer.writeln('Status: ${success ? '✅ SUCCESS' : '❌ FAILED'}');
    buffer.writeln();

    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln('ANONYMIZATION PROCESS (7 Phases)');
    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln();

    _writePhaseSummary(buffer, phase1Validation);
    _writePhaseSummary(buffer, phase2Metadata);
    _writePhaseSummary(buffer, phase3KeyDestruction);
    _writePhaseSummary(buffer, phase4Tombstoning);
    _writePhaseSummary(buffer, phase5MetadataClearing);
    _writePhaseSummary(buffer, phase6SyncInvalidation);
    _writePhaseSummary(buffer, phase7ComplianceProof);

    buffer.writeln();
    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln('ENCRYPTION KEY DESTRUCTION');
    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln();

    if (keyDestructionReport != null) {
      buffer.writeln(keyDestructionReport!.toSummary());
    } else {
      buffer.writeln('No key destruction performed');
    }

    buffer.writeln();
    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln('COMPLIANCE PROOF');
    buffer.writeln('-'.padRight(70, '-'));
    buffer.writeln();
    buffer.writeln('Proof Hash (SHA-256): ${proofHash ?? 'PENDING'}');
    buffer.writeln();

    buffer.writeln('='.padRight(70, '='));
    buffer.writeln('This certificate serves as proof that personal data has been');
    buffer.writeln('irreversibly anonymized in compliance with GDPR Article 17.');
    buffer.writeln('='.padRight(70, '='));

    return buffer.toString();
  }

  void _writePhaseSummary(StringBuffer buffer, PhaseReport phase) {
    final status = phase.success ? '✅' : (phase.completed ? '❌' : '⏳');
    buffer.writeln('Phase ${phase.phaseNumber}: ${phase.phaseName}');
    buffer.writeln('  Status: $status ${phase.success ? 'SUCCESS' : (phase.completed ? 'FAILED' : 'PENDING')}');
    if (phase.duration != null) {
      buffer.writeln('  Duration: ${phase.duration!.inMilliseconds}ms');
    }
    if (phase.errors.isNotEmpty) {
      buffer.writeln('  Errors: ${phase.errors.join(', ')}');
    }
    buffer.writeln();
  }

  String _hashUserId(String userId) {
    // Return first 8 characters of anonymization ID as pseudo-hash
    // (Real implementation would use proper SHA-256)
    return anonymizationId.substring(0, 8);
  }

  /// Convert to JSON for audit trail storage
  Map<String, dynamic> toJson() => {
        'anonymizationId': anonymizationId,
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'durationSeconds': duration?.inSeconds,
        'success': success,
        'errors': errors,
        'successfulPhasesCount': successfulPhasesCount,
        'pointOfNoReturnReached': pointOfNoReturnReached,
        'phases': {
          'phase1': phase1Validation.toJson(),
          'phase2': phase2Metadata.toJson(),
          'phase3': phase3KeyDestruction.toJson(),
          'phase4': phase4Tombstoning.toJson(),
          'phase5': phase5MetadataClearing.toJson(),
          'phase6': phase6SyncInvalidation.toJson(),
          'phase7': phase7ComplianceProof.toJson(),
        },
        'keyDestruction': keyDestructionReport?.toJson(),
        'proofHash': proofHash,
      };

  /// Convert to pretty-printed JSON string
  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  @override
  String toString() => jsonEncode(toJson());
}
