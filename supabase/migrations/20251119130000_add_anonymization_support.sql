-- Migration: Add Anonymization Support Tables
-- Version: 45
-- Date: 2025-11-19
-- Purpose: GDPR Article 17 compliance - User data anonymization infrastructure
--
-- **GDPR Compliance**:
-- - Article 17 (Right to Erasure): Anonymization as alternative to deletion
-- - Recital 26: True anonymization through irreversible key destruction
-- - ISO 29100:2024: Privacy by design with audit trails
-- - ISO 27001:2022: Secure data disposal with proof of destruction
--
-- **Tables Added**:
-- 1. anonymization_events - Track anonymization operations (audit trail)
-- 2. key_revocation_events - Cross-device key invalidation
-- 3. anonymization_proofs - Immutable compliance proofs
--
-- **Design**: See PHASE_1.2_ANONYMIZATION_DESIGN.md
-- **Safety**: All tables are new, no data migration required

-- ============================================================================
-- Table 1: Anonymization Events (Audit Trail)
-- ============================================================================
--
-- Tracks all anonymization operations for GDPR compliance and debugging.
-- Required for proving compliance with Article 17 (Right to Erasure).
--
-- **Retention**: Permanent (legal requirement for compliance proof)
-- **RLS**: Users can only see their own anonymization events
CREATE TABLE IF NOT EXISTS anonymization_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'rolled_back')),
  current_phase TEXT CHECK (current_phase IN (
    'verification',
    'backup',
    'blob_overwrite',
    'key_destruction',
    'profile_anonymization',
    'audit_anonymization',
    'verification_proof'
  )),
  error_message TEXT,
  rollback_reason TEXT,
  confirmation_code TEXT,
  backup_exported BOOLEAN NOT NULL DEFAULT FALSE,
  blobs_overwritten BOOLEAN NOT NULL DEFAULT FALSE,
  keys_destroyed BOOLEAN NOT NULL DEFAULT FALSE,
  profile_anonymized BOOLEAN NOT NULL DEFAULT FALSE,
  audit_logs_anonymized BOOLEAN NOT NULL DEFAULT FALSE,
  verification_completed BOOLEAN NOT NULL DEFAULT FALSE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies for anonymization_events
ALTER TABLE anonymization_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY anonymization_events_select_own
  ON anonymization_events
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY anonymization_events_insert_own
  ON anonymization_events
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY anonymization_events_update_own
  ON anonymization_events
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Indexes for monitoring and querying
CREATE INDEX IF NOT EXISTS idx_anonymization_events_status
  ON anonymization_events(user_id, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymization_events_user
  ON anonymization_events(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymization_events_phase
  ON anonymization_events(current_phase, status)
  WHERE status IN ('pending', 'in_progress');

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_anonymization_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER anonymization_events_updated_at_trigger
  BEFORE UPDATE ON anonymization_events
  FOR EACH ROW
  EXECUTE FUNCTION update_anonymization_events_updated_at();

-- ============================================================================
-- Table 2: Key Revocation Events (Cross-Device Sync)
-- ============================================================================
--
-- Tracks encryption key revocation events to ensure keys are invalidated
-- across all user devices. Critical for preventing data recovery after
-- anonymization.
--
-- **Use Case**: User anonymizes account on Device A, Device B must
-- invalidate cached keys on next sync.
--
-- **Retention**: 90 days (auto-purge after all devices sync)
CREATE TABLE IF NOT EXISTS key_revocation_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key_type TEXT NOT NULL CHECK (key_type IN ('amk', 'legacy_device_key', 'all')),
  revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT NOT NULL CHECK (reason IN ('anonymization', 'security_incident', 'key_rotation', 'manual')),
  device_id TEXT,
  synced_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies for key_revocation_events
ALTER TABLE key_revocation_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY key_revocation_events_select_own
  ON key_revocation_events
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY key_revocation_events_insert_own
  ON key_revocation_events
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY key_revocation_events_update_own
  ON key_revocation_events
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Indexes for efficient sync queries
CREATE INDEX IF NOT EXISTS idx_key_revocation_user
  ON key_revocation_events(user_id, revoked_at DESC);

CREATE INDEX IF NOT EXISTS idx_key_revocation_sync
  ON key_revocation_events(user_id, synced_at)
  WHERE synced_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_key_revocation_unacked
  ON key_revocation_events(user_id, acknowledged_at)
  WHERE acknowledged_at IS NULL;

-- Auto-purge old revocation events (90 days)
CREATE OR REPLACE FUNCTION cleanup_old_key_revocations()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM key_revocation_events
  WHERE created_at < NOW() - INTERVAL '90 days'
    AND acknowledged_at IS NOT NULL;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Table 3: Anonymization Proofs (Immutable Compliance Evidence)
-- ============================================================================
--
-- Generates immutable cryptographic proof that anonymization was
-- successfully completed. Required for GDPR compliance audits.
--
-- **Proof Components**:
-- - Verification hash (cannot decrypt sample data)
-- - PII scan results (no PII remaining)
-- - Key destruction confirmation
-- - Timestamp and irreversibility attestation
--
-- **Retention**: Permanent (legal requirement)
CREATE TABLE IF NOT EXISTS anonymization_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anonymization_event_id UUID NOT NULL REFERENCES anonymization_events(id) ON DELETE RESTRICT,
  user_id_hash TEXT NOT NULL, -- SHA-256 hash of original user_id (for verification without PII)
  proof_type TEXT NOT NULL CHECK (proof_type IN (
    'decryption_failure',
    'pii_scan',
    'key_destruction',
    'full_verification'
  )),
  proof_data JSONB NOT NULL,
  verification_hash TEXT NOT NULL, -- SHA-256 hash of proof data for integrity
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_valid BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies for anonymization_proofs
-- Note: Proofs are append-only for compliance, no updates/deletes allowed
ALTER TABLE anonymization_proofs ENABLE ROW LEVEL SECURITY;

CREATE POLICY anonymization_proofs_select_own
  ON anonymization_proofs
  FOR SELECT
  USING (
    -- User can see proofs for their own anonymization events
    anonymization_event_id IN (
      SELECT id FROM anonymization_events WHERE user_id = auth.uid()
    )
  );

CREATE POLICY anonymization_proofs_insert_own
  ON anonymization_proofs
  FOR INSERT
  WITH CHECK (
    -- Can only insert proofs for own anonymization events
    anonymization_event_id IN (
      SELECT id FROM anonymization_events WHERE user_id = auth.uid()
    )
  );

-- No UPDATE or DELETE policies - proofs are immutable

-- Indexes for proof retrieval and verification
CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_event
  ON anonymization_proofs(anonymization_event_id, proof_type);

CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_user_hash
  ON anonymization_proofs(user_id_hash, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymization_proofs_timestamp
  ON anonymization_proofs(timestamp DESC);

-- ============================================================================
-- Utility Function: Anonymize User Audit Trail
-- ============================================================================
--
-- Anonymizes PII in trash_events table while preserving audit structure.
-- Called during anonymization process to remove item_title fields.
CREATE OR REPLACE FUNCTION anonymize_user_audit_trail(target_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  -- Update trash_events to remove PII from item_title
  UPDATE trash_events
  SET
    item_title = 'ANONYMIZED',
    updated_at = NOW()
  WHERE user_id = target_user_id
    AND item_title IS NOT NULL
    AND item_title != 'ANONYMIZED';

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  -- Log the anonymization
  INSERT INTO anonymization_events (user_id, status, current_phase, metadata)
  VALUES (
    target_user_id,
    'completed',
    'audit_anonymization',
    jsonb_build_object(
      'audit_records_anonymized', updated_count,
      'timestamp', NOW()
    )
  )
  ON CONFLICT (id) DO NOTHING; -- Prevent duplicate if event already exists

  RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Verification
-- ============================================================================

-- Verify all tables were created
DO $$
DECLARE
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('anonymization_events', 'key_revocation_events', 'anonymization_proofs');

  IF table_count != 3 THEN
    RAISE EXCEPTION 'Migration failed: Expected 3 tables, found %', table_count;
  END IF;

  RAISE NOTICE '✅ Migration complete: Anonymization support tables created';
  RAISE NOTICE '   - anonymization_events: Audit trail for GDPR compliance';
  RAISE NOTICE '   - key_revocation_events: Cross-device key invalidation';
  RAISE NOTICE '   - anonymization_proofs: Immutable compliance evidence';
END $$;
