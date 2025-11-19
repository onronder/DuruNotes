import 'package:drift/drift.dart';

/// Migration 45: Add anonymization support tables
///
/// This migration adds the infrastructure for GDPR-compliant user anonymization,
/// including event tracking, proof generation, and key revocation support.
///
/// **GDPR Compliance**:
/// - Article 17 (Right to Erasure): Anonymization as alternative to deletion
/// - Recital 26: True anonymization through irreversible key destruction
/// - ISO 29100:2024: Privacy by design with audit trails
///
/// **Tables Added**:
/// 1. `anonymization_events` - Track anonymization operations (audit trail)
/// 2. `key_revocation_events` - Cross-device key invalidation
/// 3. `anonymization_proofs` - Immutable compliance proofs
///
/// **Design**: See PHASE_1.2_ANONYMIZATION_DESIGN.md for full specification
///
/// **Safety**: All tables are new, no data migration required
Future<void> migration45AnonymizationSupport(Migrator m) async {
  // ========================================================================
  // Table 1: Anonymization Events (Audit Trail)
  // ========================================================================
  //
  // Tracks all anonymization operations for GDPR compliance and debugging.
  // Required for proving compliance with Article 17 (Right to Erasure).
  //
  // **Retention**: Permanent (legal requirement for compliance proof)
  // **PII**: None after anonymization (user_id becomes anonymized account)
  await m.database.customStatement('''
    CREATE TABLE IF NOT EXISTS anonymization_events (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      completed_at INTEGER,
      status TEXT NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'rolled_back')),
      current_phase TEXT CHECK (current_phase IN ('verification', 'backup', 'blob_overwrite', 'key_destruction', 'profile_anonymization', 'audit_anonymization', 'verification_proof')),
      error_message TEXT,
      rollback_reason TEXT,
      confirmation_code TEXT,
      backup_exported INTEGER NOT NULL DEFAULT 0,
      blobs_overwritten INTEGER NOT NULL DEFAULT 0,
      keys_destroyed INTEGER NOT NULL DEFAULT 0,
      profile_anonymized INTEGER NOT NULL DEFAULT 0,
      audit_logs_anonymized INTEGER NOT NULL DEFAULT 0,
      verification_completed INTEGER NOT NULL DEFAULT 0,
      metadata TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  // Index for monitoring and querying
  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_anonymization_events_status
      ON anonymization_events(user_id, status, started_at)
  ''');

  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_anonymization_events_user
      ON anonymization_events(user_id, created_at DESC)
  ''');

  // ========================================================================
  // Table 2: Key Revocation Events (Cross-Device Sync)
  // ========================================================================
  //
  // Tracks encryption key revocation events to ensure keys are invalidated
  // across all user devices. Critical for preventing data recovery after
  // anonymization.
  //
  // **Use Case**: User anonymizes account on Device A, Device B must
  // invalidate cached keys on next sync.
  //
  // **Retention**: 90 days (enough for all devices to sync)
  await m.database.customStatement('''
    CREATE TABLE IF NOT EXISTS key_revocation_events (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      key_type TEXT NOT NULL CHECK (key_type IN ('amk', 'legacy_device_key', 'all')),
      revoked_at INTEGER NOT NULL,
      reason TEXT NOT NULL CHECK (reason IN ('anonymization', 'security_incident', 'key_rotation', 'manual')),
      device_id TEXT,
      synced_at INTEGER,
      acknowledged_at INTEGER,
      metadata TEXT,
      created_at INTEGER NOT NULL
    )
  ''');

  // Index for efficient sync queries
  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_key_revocation_user
      ON key_revocation_events(user_id, revoked_at DESC)
  ''');

  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_key_revocation_sync
      ON key_revocation_events(user_id, synced_at)
      WHERE synced_at IS NULL
  ''');

  // ========================================================================
  // Table 3: Anonymization Proofs (Immutable Compliance Evidence)
  // ========================================================================
  //
  // Generates immutable cryptographic proof that anonymization was
  // successfully completed. Required for GDPR compliance audits.
  //
  // **Proof Components**:
  // - Verification hash (cannot decrypt sample data)
  // - PII scan results (no PII remaining)
  // - Key destruction confirmation
  // - Timestamp and irreversibility attestation
  //
  // **Retention**: Permanent (legal requirement)
  await m.database.customStatement('''
    CREATE TABLE IF NOT EXISTS anonymization_proofs (
      id TEXT PRIMARY KEY NOT NULL,
      anonymization_event_id TEXT NOT NULL,
      user_id_hash TEXT NOT NULL,
      proof_type TEXT NOT NULL CHECK (proof_type IN ('decryption_failure', 'pii_scan', 'key_destruction', 'full_verification')),
      proof_data TEXT NOT NULL,
      verification_hash TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      is_valid INTEGER NOT NULL DEFAULT 1,
      metadata TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (anonymization_event_id) REFERENCES anonymization_events(id) ON DELETE RESTRICT
    )
  ''');

  // Index for proof retrieval and verification
  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_event
      ON anonymization_proofs(anonymization_event_id, proof_type)
  ''');

  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_user
      ON anonymization_proofs(user_id_hash, created_at DESC)
  ''');

  await m.database.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_timestamp
      ON anonymization_proofs(timestamp DESC)
  ''');

  // ========================================================================
  // Verification Queries
  // ========================================================================

  // Verify table creation
  final tables = await m.database.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('anonymization_events', 'key_revocation_events', 'anonymization_proofs')",
  ).get();

  if (tables.length != 3) {
    throw Exception(
      'Migration 45 failed: Expected 3 tables, found ${tables.length}',
    );
  }

  print('✅ Migration 45 complete: Anonymization support tables created');
  print('   - anonymization_events: Audit trail for GDPR compliance');
  print('   - key_revocation_events: Cross-device key invalidation');
  print('   - anonymization_proofs: Immutable compliance evidence');
}

/// Rollback Migration 45
///
/// Drops all anonymization support tables.
/// Safe to rollback: No data dependencies, all tables are new.
Future<void> rollbackMigration45(Migrator m) async {
  await m.database.customStatement('DROP TABLE IF EXISTS anonymization_proofs');
  await m.database.customStatement('DROP TABLE IF EXISTS key_revocation_events');
  await m.database.customStatement('DROP TABLE IF EXISTS anonymization_events');

  print('✅ Migration 45 rolled back: Anonymization tables dropped');
}
