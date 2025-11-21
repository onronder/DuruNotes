-- Migration: Fix Phase 6 - Key Revocation Events Table Schema
-- Date: November 19, 2025
--
-- This migration fixes the schema mismatch in the key_revocation_events table
-- to align with what the GDPR service expects while maintaining backward compatibility.

BEGIN;

-- ===========================================================================
-- ALTER EXISTING TABLE to support GDPR anonymization
-- ===========================================================================

-- Add anonymization_id column if it doesn't exist
ALTER TABLE public.key_revocation_events
  ADD COLUMN IF NOT EXISTS anonymization_id uuid;

-- Create an index on anonymization_id for efficient lookups
CREATE INDEX IF NOT EXISTS idx_key_revocation_anonymization
  ON public.key_revocation_events(anonymization_id)
  WHERE anonymization_id IS NOT NULL;

-- Update the reason CHECK constraint to include 'GDPR_ANONYMIZATION'
ALTER TABLE public.key_revocation_events
  DROP CONSTRAINT IF EXISTS key_revocation_events_reason_check;

ALTER TABLE public.key_revocation_events
  ADD CONSTRAINT key_revocation_events_reason_check
  CHECK (reason IN ('anonymization', 'security_incident', 'key_rotation', 'manual', 'GDPR_ANONYMIZATION'));

-- Make key_type nullable to support GDPR anonymization which revokes all keys
ALTER TABLE public.key_revocation_events
  ALTER COLUMN key_type DROP NOT NULL;

-- Update the key_type CHECK constraint to allow NULL
ALTER TABLE public.key_revocation_events
  DROP CONSTRAINT IF EXISTS key_revocation_events_key_type_check;

ALTER TABLE public.key_revocation_events
  ADD CONSTRAINT key_revocation_events_key_type_check
  CHECK (key_type IS NULL OR key_type IN ('amk', 'legacy_device_key', 'all'));

-- ===========================================================================
-- CREATE WRAPPER FUNCTION for GDPR Service
-- ===========================================================================
-- This function provides the interface that the GDPR service expects
-- while properly populating the required fields in the table

CREATE OR REPLACE FUNCTION create_gdpr_key_revocation_event(
  p_user_id uuid,
  p_revocation_reason text,
  p_anonymization_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  event_id uuid;
BEGIN
  -- Insert the key revocation event with proper field mapping
  INSERT INTO public.key_revocation_events (
    user_id,
    key_type,
    reason,
    anonymization_id,
    metadata
  ) VALUES (
    p_user_id,
    'all',  -- GDPR revokes all keys
    p_revocation_reason,  -- Will be 'GDPR_ANONYMIZATION'
    p_anonymization_id,
    jsonb_build_object(
      'source', 'GDPR_ANONYMIZATION_SERVICE',
      'timestamp', now(),
      'revokes_all_keys', true
    )
  ) RETURNING id INTO event_id;

  RAISE NOTICE 'GDPR Phase 6: Created key revocation event % for user % (anonymization: %)',
    event_id, p_user_id, p_anonymization_id;

  RETURN event_id;
END;
$$;

COMMENT ON FUNCTION create_gdpr_key_revocation_event IS 'Creates a key revocation event for GDPR anonymization process';

-- ===========================================================================
-- UPDATE Phase 6 to use the wrapper function
-- ===========================================================================
-- Instead of direct insert, the service should use RPC to call this function
-- But for backward compatibility, we'll create a trigger that handles direct inserts

CREATE OR REPLACE FUNCTION handle_gdpr_key_revocation_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if this is a GDPR anonymization insert (has anonymization_id but no key_type)
  IF NEW.anonymization_id IS NOT NULL AND NEW.key_type IS NULL THEN
    -- Set default values for GDPR anonymization
    NEW.key_type := 'all';

    -- Ensure reason is properly set
    IF NEW.reason IS NULL OR NEW.reason = '' THEN
      NEW.reason := 'GDPR_ANONYMIZATION';
    END IF;

    -- Add metadata
    NEW.metadata := COALESCE(NEW.metadata, '{}'::jsonb) || jsonb_build_object(
      'source', 'GDPR_ANONYMIZATION_SERVICE',
      'auto_populated', true
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create the trigger
DROP TRIGGER IF EXISTS trg_handle_gdpr_key_revocation ON public.key_revocation_events;

CREATE TRIGGER trg_handle_gdpr_key_revocation
  BEFORE INSERT ON public.key_revocation_events
  FOR EACH ROW
  EXECUTE FUNCTION handle_gdpr_key_revocation_insert();

-- ===========================================================================
-- HELPER FUNCTION: Get Key Revocation Events for User
-- ===========================================================================

CREATE OR REPLACE FUNCTION get_user_key_revocation_events(
  p_user_id uuid,
  p_include_acknowledged boolean DEFAULT false
)
RETURNS TABLE(
  id uuid,
  key_type text,
  reason text,
  revoked_at timestamptz,
  anonymization_id uuid,
  acknowledged boolean,
  metadata jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kre.id,
    kre.key_type,
    kre.reason,
    kre.revoked_at,
    kre.anonymization_id,
    kre.acknowledged_at IS NOT NULL AS acknowledged,
    kre.metadata
  FROM public.key_revocation_events kre
  WHERE kre.user_id = p_user_id
    AND (p_include_acknowledged OR kre.acknowledged_at IS NULL)
  ORDER BY kre.revoked_at DESC;
END;
$$;

COMMENT ON FUNCTION get_user_key_revocation_events IS 'Returns key revocation events for a user, optionally including acknowledged events';

-- ===========================================================================
-- GRANT PERMISSIONS
-- ===========================================================================

GRANT EXECUTE ON FUNCTION create_gdpr_key_revocation_event TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_key_revocation_events TO authenticated;

COMMIT;

-- ===========================================================================
-- MIGRATION NOTES
-- ===========================================================================

-- 1. BACKWARD COMPATIBILITY:
--    This migration maintains backward compatibility with existing code
--    while adding support for GDPR anonymization.

-- 2. TRIGGER HANDLING:
--    The trigger automatically populates required fields when the GDPR
--    service does a direct insert.

-- 3. KEY REVOCATION:
--    GDPR anonymization revokes ALL keys (key_type = 'all')
--    This ensures all devices lose access immediately.

-- 4. SYNC MECHANISM:
--    The synced_at and acknowledged_at fields can be used by clients
--    to track when they've processed the revocation event.

-- ===========================================================================
-- ROLLBACK PLAN
-- ===========================================================================

-- To rollback this migration:
-- 1. Remove the trigger: DROP TRIGGER trg_handle_gdpr_key_revocation ON key_revocation_events;
-- 2. Drop the functions: DROP FUNCTION create_gdpr_key_revocation_event, handle_gdpr_key_revocation_insert, get_user_key_revocation_events;
-- 3. Remove anonymization_id column: ALTER TABLE key_revocation_events DROP COLUMN anonymization_id;
-- 4. Restore original constraints (see original migration file)