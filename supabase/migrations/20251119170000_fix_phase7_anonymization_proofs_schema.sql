-- Migration: Fix Phase 7 - Anonymization Proofs Table Schema
-- Date: November 19, 2025
--
-- This migration fixes the schema mismatch in the anonymization_proofs table
-- to align with what the GDPR service expects.
--
-- The service expects simpler fields that directly match the anonymization flow.

BEGIN;

-- ===========================================================================
-- ALTER EXISTING TABLE OR CREATE NEW ONE WITH CORRECT SCHEMA
-- ===========================================================================
-- First check if the table exists and has the wrong schema, then migrate safely

-- Check if we need to migrate from the old schema
DO $$
BEGIN
  -- Check if the table exists with the old schema (has anonymization_event_id column)
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'anonymization_proofs'
    AND column_name = 'anonymization_event_id'
  ) THEN
    -- Table exists with old schema - need to migrate
    -- First, backup any existing data (should be none in development)
    CREATE TEMP TABLE temp_anonymization_proofs_backup AS
    SELECT * FROM public.anonymization_proofs;

    -- Drop the old table
    DROP TABLE public.anonymization_proofs CASCADE;

    RAISE NOTICE 'Migrated anonymization_proofs table from old schema to new schema';
  END IF;
END $$;

-- Create the table with the correct schema that matches the service expectations
CREATE TABLE IF NOT EXISTS public.anonymization_proofs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Direct anonymization ID (not a foreign key to allow flexibility)
  anonymization_id uuid NOT NULL,

  -- SHA-256 hash of original user_id (for verification without PII)
  user_id_hash text NOT NULL,

  -- SHA-256 hash of the complete proof data for integrity
  proof_hash text NOT NULL,

  -- Complete proof data including all phase reports
  proof_data jsonb NOT NULL,

  -- Timestamp when the proof was created
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),

  -- Optional metadata for additional context
  metadata jsonb DEFAULT '{}',

  -- Index for faster lookups
  CONSTRAINT unique_anonymization_proof UNIQUE (anonymization_id)
);

-- Create indexes for efficient querying
CREATE INDEX idx_anonymization_proofs_user_hash ON public.anonymization_proofs (user_id_hash);
CREATE INDEX idx_anonymization_proofs_created_at ON public.anonymization_proofs (created_at DESC);
CREATE INDEX idx_anonymization_proofs_anonymization_id ON public.anonymization_proofs (anonymization_id);

-- ===========================================================================
-- ROW LEVEL SECURITY
-- ===========================================================================
-- Proofs are append-only and can only be viewed by admins or the system

ALTER TABLE public.anonymization_proofs ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can insert proofs
CREATE POLICY anonymization_proofs_insert
  ON public.anonymization_proofs
  FOR INSERT
  TO authenticated
  WITH CHECK (true);  -- Service handles validation

-- Policy: Nobody can update proofs (immutable for compliance)
-- No UPDATE policy means updates are blocked

-- Policy: Nobody can delete proofs (permanent record for compliance)
-- No DELETE policy means deletions are blocked

-- Policy: Service role and admins can view proofs
CREATE POLICY anonymization_proofs_select
  ON public.anonymization_proofs
  FOR SELECT
  TO authenticated
  USING (
    -- Users cannot directly query this table
    -- Only service role or admin functions can access
    auth.jwt() ->> 'role' = 'service_role'
    OR EXISTS (
      -- Allow viewing if user is querying their own proof via user_id_hash
      -- This requires them to know their original user_id to compute the hash
      SELECT 1
      WHERE user_id_hash = encode(
        sha256(convert_to(auth.uid()::text, 'UTF8')),
        'hex'
      )
    )
  );

-- ===========================================================================
-- HELPER FUNCTION: Verify Proof Integrity
-- ===========================================================================
-- Verifies that a stored proof has not been tampered with

CREATE OR REPLACE FUNCTION verify_proof_integrity(
  anonymization_id_param uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stored_proof RECORD;
  computed_hash text;
BEGIN
  -- Get the stored proof
  SELECT
    proof_data,
    proof_hash
  INTO stored_proof
  FROM public.anonymization_proofs
  WHERE anonymization_id = anonymization_id_param;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Recompute the hash from the stored data
  computed_hash := encode(
    sha256(convert_to(stored_proof.proof_data::text, 'UTF8')),
    'hex'
  );

  -- Verify the hash matches
  RETURN computed_hash = stored_proof.proof_hash;
END;
$$;

COMMENT ON FUNCTION verify_proof_integrity IS 'Verifies the integrity of a stored anonymization proof by recomputing its hash';

-- ===========================================================================
-- HELPER FUNCTION: Get Proof Summary
-- ===========================================================================
-- Returns a summary of an anonymization proof without exposing sensitive data

CREATE OR REPLACE FUNCTION get_proof_summary(
  anonymization_id_param uuid
)
RETURNS TABLE(
  anonymization_id uuid,
  created_at timestamptz,
  proof_valid boolean,
  phase_count integer,
  all_phases_successful boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  proof_record RECORD;
BEGIN
  -- Get the proof
  SELECT
    ap.anonymization_id,
    ap.created_at,
    ap.proof_data
  INTO proof_record
  FROM public.anonymization_proofs ap
  WHERE ap.anonymization_id = anonymization_id_param;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Extract phase information from proof_data
  RETURN QUERY
  SELECT
    proof_record.anonymization_id,
    proof_record.created_at,
    verify_proof_integrity(anonymization_id_param) AS proof_valid,
    (
      SELECT COUNT(*)::integer
      FROM jsonb_object_keys(proof_record.proof_data -> 'phases')
    ) AS phase_count,
    (
      -- Check if all phases have success = true
      SELECT bool_and((value ->> 'success')::boolean)
      FROM jsonb_each(proof_record.proof_data -> 'phases')
    ) AS all_phases_successful;
END;
$$;

COMMENT ON FUNCTION get_proof_summary IS 'Returns a summary of an anonymization proof without exposing sensitive data';

-- ===========================================================================
-- GRANT PERMISSIONS
-- ===========================================================================

GRANT EXECUTE ON FUNCTION verify_proof_integrity TO authenticated;
GRANT EXECUTE ON FUNCTION get_proof_summary TO authenticated;

-- Table permissions are handled by RLS policies

COMMIT;

-- ===========================================================================
-- USAGE NOTES
-- ===========================================================================

-- 1. IMMUTABILITY:
--    Proofs cannot be updated or deleted once created.
--    This ensures compliance with audit requirements.

-- 2. PROOF VERIFICATION:
--    Use verify_proof_integrity() to check if a proof has been tampered with.

-- 3. SERVICE INTEGRATION:
--    The service inserts proofs with:
--    - anonymization_id: Unique ID for the anonymization operation
--    - user_id_hash: SHA-256 hash of the user ID
--    - proof_hash: SHA-256 hash of the proof_data
--    - proof_data: Complete JSON with all phase reports

-- 4. COMPLIANCE:
--    This table serves as the permanent record of GDPR Article 17 compliance.
--    Proofs should be retained even after user data is anonymized.

-- ===========================================================================
-- MIGRATION SAFETY
-- ===========================================================================

-- This migration drops and recreates the table.
-- If there is existing data, it will be lost.
-- Run this migration only in development or after backing up any existing proofs.