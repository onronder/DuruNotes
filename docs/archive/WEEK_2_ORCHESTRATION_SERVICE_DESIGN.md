# GDPRAnonymizationService - Orchestration Service Design

**Date**: November 19, 2025
**Phase**: 1.2 Week 2
**Status**: Design Complete

## Overview

The `GDPRAnonymizationService` orchestrates the complete user anonymization process, coordinating multiple services to ensure all user data is irreversibly anonymized in compliance with GDPR Article 17 (Right to Erasure) and Recital 26 (True Anonymization).

## Architecture

### Service Responsibilities

**GDPRAnonymizationService** is the single entry point for anonymization:
- Coordinates 7-phase destruction process
- Provides transaction-like semantics (all-or-nothing where possible)
- Generates comprehensive audit trail
- Handles rollback for reversible operations
- Implements "Point of No Return" detection

### Dependencies

```dart
class GDPRAnonymizationService {
  final KeyManager _keyManager;
  final AccountKeyService _accountKeyService;
  final EncryptionSyncService _encryptionSyncService;
  final SupabaseClient _client;
  final AppLogger _logger;

  // Services for data anonymization (Phase 2-7)
  final NotesRepository _notesRepository;
  final TasksRepository _tasksRepository;
  final FoldersRepository _foldersRepository;
}
```

## 7-Phase Anonymization Process

### Phase 1: Pre-Anonymization Validation ✅
**Status**: Reversible
**Purpose**: Verify user intent and check current state

**Steps**:
1. Validate user session is active
2. Confirm user has backed up important data (user confirmation required)
3. Check no active sync operations
4. Generate anonymization ID for tracking

**Outputs**:
- Anonymization ID (UUID)
- Pre-validation report
- User data inventory

**Rollback**: No changes made, fully reversible

---

### Phase 2: Account Metadata Anonymization ⚠️
**Status**: Reversible (until Phase 3)
**Purpose**: Anonymize account-level metadata

**Steps**:
1. Replace email with `anonymized_{uuid}@gdpr-deleted.local`
2. Clear display name → `"Anonymized User"`
3. Remove profile photo URL
4. Clear phone number
5. Set `anonymized_at` timestamp
6. Set `gdpr_deletion_reason` field

**Database Tables**:
- `auth.users` (via Supabase Auth Admin API)
- `user_metadata` (custom table if exists)

**Outputs**:
- Original metadata backup (for potential rollback)
- Metadata anonymization report

**Rollback**: Restore from backup (until Phase 3 completes)

---

### Phase 3: Encryption Key Destruction 🔴
**Status**: **POINT OF NO RETURN**
**Purpose**: Destroy all encryption keys, making encrypted data permanently inaccessible

**Steps**:
1. Destroy legacy device key (`KeyManager.securelyDestroyAllKeys`)
2. Destroy Account Master Key (`AccountKeyService.securelyDestroyAccountMasterKey`)
3. Destroy cross-device keys (`EncryptionSyncService.securelyDestroyCrossDeviceKeys`)
4. Record key destruction events in `anonymization_events` table
5. Create immutable proof in `anonymization_proofs` table

**Key Locations Destroyed**:
- `mk:{userId}` - Legacy device key (local)
- `amk:{userId}` - Account Master Key (local)
- `amk_meta:{userId}` - AMK metadata (local)
- `encryption_sync_amk:{userId}` - Cross-device AMK (local)
- `user_keys.wrapped_key` - Remote AMK (database)
- `user_encryption_keys.encrypted_amk` - Remote cross-device key (database)

**Outputs**:
- Combined KeyDestructionReport
- Anonymization event records
- Cryptographic proof of deletion

**Rollback**: ❌ IMPOSSIBLE - Keys are permanently destroyed

---

### Phase 4: Encrypted Content Tombstoning 🔴
**Status**: Irreversible (keys already destroyed)
**Purpose**: Replace encrypted content with tombstone markers

**Steps**:
1. For each note: Replace `encrypted_content` with tombstone
2. For each task: Replace `encrypted_content` with tombstone
3. For each folder: Replace `encrypted_metadata` with tombstone
4. Set `anonymized` flag on all records
5. Preserve structure for foreign key integrity

**Tombstone Format**:
```json
{
  "anonymized": true,
  "reason": "GDPR Article 17 - Right to Erasure",
  "timestamp": "2025-11-19T10:30:00Z",
  "anonymization_id": "uuid",
  "note": "Content permanently inaccessible due to encryption key destruction"
}
```

**Database Tables**:
- `notes.encrypted_content`
- `tasks.encrypted_content`
- `folders.encrypted_metadata`

**Outputs**:
- Tombstone creation report
- Record count per entity type

**Rollback**: ❌ IMPOSSIBLE - Keys destroyed in Phase 3

---

### Phase 5: Unencrypted Metadata Clearing 🔴
**Status**: Irreversible
**Purpose**: Clear any unencrypted metadata that might identify user

**Steps**:
1. Clear note titles (if stored unencrypted)
2. Clear task titles (if stored unencrypted)
3. Clear folder names
4. Clear tag names
5. Clear search indices
6. Anonymize audit logs (replace user ID with anonymization ID)

**Database Tables**:
- `notes` (title, tags)
- `tasks` (title, tags)
- `folders` (name)
- `audit_logs` (user_id → anonymization_id)

**Outputs**:
- Metadata clearing report
- Audit log anonymization count

**Rollback**: ❌ IMPOSSIBLE - Data permanently erased

---

### Phase 6: Cross-Device Sync Invalidation 🔴
**Status**: Irreversible
**Purpose**: Ensure other devices cannot decrypt or restore data

**Steps**:
1. Create key revocation events in `key_revocation_events` table
2. Set revocation reason to "GDPR_ANONYMIZATION"
3. Set revocation timestamp
4. Trigger sync to all active devices (if possible)
5. Wait 30 seconds for sync propagation

**Database Tables**:
- `key_revocation_events`

**Outputs**:
- Revocation event IDs
- Device notification status

**Rollback**: ❌ IMPOSSIBLE - Revocation is permanent

---

### Phase 7: Final Audit Trail & Compliance Proof 🔴
**Status**: Irreversible (compliance requirement)
**Purpose**: Generate immutable proof of GDPR compliance

**Steps**:
1. Aggregate all phase reports
2. Calculate SHA-256 hash of anonymization proof
3. Store in `anonymization_proofs` table (append-only)
4. Record in `anonymization_events` table
5. Generate human-readable compliance certificate
6. Return final anonymization report to user

**Database Tables**:
- `anonymization_proofs` (immutable)
- `anonymization_events` (audit trail)

**Outputs**:
- Anonymization certificate (JSON + human-readable)
- Compliance proof hash
- Complete audit trail

**Rollback**: ❌ N/A - This is the compliance record

---

## API Design

### Primary Method

```dart
/// Anonymize user account in compliance with GDPR Article 17
///
/// ⚠️ **WARNING: THIS IS IRREVERSIBLE AFTER PHASE 3**
///
/// This method orchestrates the complete anonymization process through 7 phases.
/// Phase 3 (Key Destruction) is the Point of No Return - after this phase
/// completes, all encrypted data becomes permanently inaccessible.
///
/// **Process**:
/// 1. Pre-Anonymization Validation (reversible)
/// 2. Account Metadata Anonymization (reversible until Phase 3)
/// 3. **Encryption Key Destruction** (POINT OF NO RETURN)
/// 4. Encrypted Content Tombstoning (irreversible)
/// 5. Unencrypted Metadata Clearing (irreversible)
/// 6. Cross-Device Sync Invalidation (irreversible)
/// 7. Final Audit Trail & Compliance Proof (compliance record)
///
/// **User Confirmations Required**:
/// - Phase 1: Confirm data backup complete
/// - Phase 2: Confirm understanding of irreversibility
/// - Phase 3: Final confirmation before Point of No Return
///
/// **GDPR Compliance**:
/// - Article 17: Right to Erasure
/// - Recital 26: True Anonymization through key destruction
/// - ISO 27001:2022: Secure disposal with audit trail
///
/// **Returns**: [GDPRAnonymizationReport] with:
/// - Anonymization ID (for compliance records)
/// - Completion status for each phase
/// - Cryptographic proof of deletion
/// - Human-readable compliance certificate
///
/// **Throws**:
/// - [SecurityException] if user session is invalid
/// - [SecurityException] if required confirmations not provided
/// - [AnonymizationException] if any phase fails critically
///
Future<GDPRAnonymizationReport> anonymizeUserAccount({
  required String userId,
  required UserConfirmations confirmations,
  void Function(AnonymizationProgress)? onProgress,
}) async {
  // Implementation
}
```

### Supporting Types

```dart
/// User confirmations required before anonymization
class UserConfirmations {
  /// User confirms they have backed up important data
  final bool dataBackupComplete;

  /// User confirms understanding that process is irreversible after Phase 3
  final bool understandsIrreversibility;

  /// Final confirmation token (must match userId)
  final String finalConfirmationToken;

  UserConfirmations({
    required this.dataBackupComplete,
    required this.understandsIrreversibility,
    required this.finalConfirmationToken,
  });
}

/// Progress callback for UI updates
class AnonymizationProgress {
  final int currentPhase;  // 1-7
  final String phaseName;
  final double phaseProgress;  // 0.0 - 1.0
  final String statusMessage;
  final bool pointOfNoReturnReached;  // true after Phase 3

  AnonymizationProgress({
    required this.currentPhase,
    required this.phaseName,
    required this.phaseProgress,
    required this.statusMessage,
    required this.pointOfNoReturnReached,
  });
}

/// Complete anonymization report for GDPR compliance
class GDPRAnonymizationReport {
  /// Unique ID for this anonymization operation
  final String anonymizationId;

  /// Timestamp when anonymization started
  final DateTime startedAt;

  /// Timestamp when anonymization completed
  final DateTime? completedAt;

  /// Overall success status
  final bool success;

  /// Errors encountered during anonymization
  final List<String> errors;

  /// Reports from each phase
  final PhaseReport phase1Validation;
  final PhaseReport phase2Metadata;
  final PhaseReport phase3KeyDestruction;
  final PhaseReport phase4Tombstoning;
  final PhaseReport phase5MetadataClearing;
  final PhaseReport phase6SyncInvalidation;
  final PhaseReport phase7ComplianceProof;

  /// Key destruction details
  final KeyDestructionReport keyDestructionReport;

  /// Cryptographic proof hash (SHA-256)
  final String? proofHash;

  /// Human-readable compliance certificate
  String toComplianceCertificate();

  /// JSON for audit trail
  Map<String, dynamic> toJson();
}

/// Report for individual phase
class PhaseReport {
  final int phaseNumber;
  final String phaseName;
  final bool completed;
  final bool success;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> errors;
  final Map<String, dynamic> details;

  PhaseReport({
    required this.phaseNumber,
    required this.phaseName,
    this.completed = false,
    this.success = false,
    this.startedAt,
    this.completedAt,
    this.errors = const [],
    this.details = const {},
  });
}
```

## Error Handling Strategy

### Phase 1-2 Failures
- **Strategy**: Full rollback
- **Action**: Restore original metadata from backup
- **User Impact**: No data lost, can retry

### Phase 3 Failures
- **Strategy**: Partial success recording
- **Action**: Document which keys were destroyed
- **User Impact**: Some keys destroyed, manual intervention may be needed
- **Recovery**: Retry key destruction with verification

### Phase 4-7 Failures
- **Strategy**: Best-effort continuation
- **Action**: Complete as much as possible, log failures
- **User Impact**: Keys already destroyed (Point of No Return passed)
- **Recovery**: Retry failed phases independently

## Database Schema

### anonymization_events Table
Already created in `migration_45_anonymization_support.dart`

```sql
CREATE TABLE anonymization_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  anonymization_id UUID NOT NULL,
  event_type TEXT NOT NULL,  -- 'STARTED', 'PHASE_COMPLETE', 'COMPLETED', 'FAILED'
  phase_number INTEGER,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### anonymization_proofs Table
Already created in `migration_45_anonymization_support.dart`

```sql
CREATE TABLE anonymization_proofs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  anonymization_id UUID NOT NULL,
  user_id_hash TEXT NOT NULL,  -- SHA-256 of user ID (non-reversible)
  proof_hash TEXT NOT NULL,  -- SHA-256 of complete anonymization report
  proof_data JSONB NOT NULL,  -- Full anonymization report
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Implementation Checklist

- [ ] Create `GDPRAnonymizationService` class
- [ ] Implement Phase 1: Pre-Anonymization Validation
- [ ] Implement Phase 2: Account Metadata Anonymization
- [ ] Implement Phase 3: Encryption Key Destruction (integrate existing services)
- [ ] Implement Phase 4: Encrypted Content Tombstoning
- [ ] Implement Phase 5: Unencrypted Metadata Clearing
- [ ] Implement Phase 6: Cross-Device Sync Invalidation
- [ ] Implement Phase 7: Final Audit Trail & Compliance Proof
- [ ] Create `GDPRAnonymizationReport` class
- [ ] Create `AnonymizationProgress` class
- [ ] Create `UserConfirmations` class
- [ ] Implement progress callbacks
- [ ] Implement error handling and rollback
- [ ] Add comprehensive logging
- [ ] Create unit tests for each phase
- [ ] Create integration tests for full flow
- [ ] Add UI confirmation dialogs
- [ ] Add documentation

## Success Metrics

### Functional Requirements
- ✅ All 7 phases complete successfully
- ✅ Keys destroyed and verified
- ✅ Data tombstoned correctly
- ✅ Audit trail generated
- ✅ Compliance proof created

### Non-Functional Requirements
- ⏱️ Complete anonymization in < 30 seconds
- 📊 Progress updates every 1-2 seconds
- 🛡️ Zero data recovery after Phase 3
- 📝 Complete audit trail for legal compliance
- 🔄 Graceful handling of network failures

---

*Orchestration Service Design*
*Phase 1.2 Week 2 - GDPR Anonymization*
*Production-Grade, Comprehensive, GDPR-Compliant*
