-- ============================================================================
-- Disable automatic updated_at trigger for notes table
-- ============================================================================
--
-- Problem: The trigger updates updated_at when encrypted bytes change, even if
-- the actual content is the same (just re-encrypted with different nonces).
-- This creates a vicious cycle where every sync re-encrypts → trigger updates
-- timestamp → next sync sees conflict → re-encrypts again → repeat forever.
--
-- Solution: Remove the automatic trigger and let the client explicitly control
-- updated_at:
-- - On actual modifications: client passes updated_at = NOW()
-- - On sync of unchanged notes: client doesn't pass updated_at (preserves existing)
-- ============================================================================

-- Drop the automatic timestamp trigger
DROP TRIGGER IF EXISTS trg_notes_updated ON public.notes;

-- Drop the function (no longer needed)
DROP FUNCTION IF EXISTS public.set_notes_updated_at();

-- Add comment for documentation
COMMENT ON TABLE public.notes IS
'Notes table with client-controlled updated_at timestamps. The client is responsible for setting updated_at when content actually changes. During sync operations of unchanged notes, updated_at is preserved by not including it in the upsert payload.';
