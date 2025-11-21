-- ============================================================================
-- Fix notes updated_at trigger to only update when content actually changes
-- ============================================================================
--
-- Problem: The current trigger updates updated_at on EVERY UPDATE, even when
-- the content hasn't changed. This causes all notes to have the same timestamp
-- after sync operations.
--
-- Solution: Make the trigger smarter - only update updated_at when the actual
-- content (title_enc, props_enc, etc.) has changed.
-- ============================================================================

-- Drop the old trigger
DROP TRIGGER IF EXISTS trg_notes_updated ON public.notes;

-- Create new smart trigger function for notes
CREATE OR REPLACE FUNCTION public.set_notes_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only update updated_at if the actual content has changed
  -- Compare title_enc, props_enc, deleted, and note_type
  -- Do NOT update timestamp if only metadata or updated_at itself changed
  IF (
    NEW.title_enc IS DISTINCT FROM OLD.title_enc OR
    NEW.props_enc IS DISTINCT FROM OLD.props_enc OR
    NEW.deleted IS DISTINCT FROM OLD.deleted OR
    NEW.note_type IS DISTINCT FROM OLD.note_type OR
    NEW.encrypted_metadata IS DISTINCT FROM OLD.encrypted_metadata
  ) THEN
    NEW.updated_at := timezone('utc', now());
  ELSE
    -- Preserve the old updated_at if content hasn't changed
    NEW.updated_at := OLD.updated_at;
  END IF;

  RETURN NEW;
END;
$$;

-- Create new trigger using the smart function
CREATE TRIGGER trg_notes_updated
BEFORE UPDATE ON public.notes
FOR EACH ROW EXECUTE FUNCTION public.set_notes_updated_at();

-- Add comment for documentation
COMMENT ON FUNCTION public.set_notes_updated_at() IS
'Smart trigger that only updates updated_at when note content actually changes. Prevents timestamp corruption during sync operations.';
