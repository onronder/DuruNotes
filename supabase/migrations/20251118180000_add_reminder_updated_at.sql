-- Migration 43: Add updated_at to reminders table
-- Created: 2025-11-18
-- Purpose: Support proper conflict resolution in reminder sync
--
-- Background:
-- Reminders can be modified after creation (snooze, update time, change location).
-- Without an updated_at timestamp, conflict resolution defaults to created_at, which
-- doesn't accurately reflect when a reminder was last modified.
--
-- Changes:
-- 1. Add updated_at column (nullable for backward compatibility)
-- 2. Backfill existing reminders with updated_at = created_at
-- 3. Add trigger to auto-update updated_at on modifications
-- 4. Add index for conflict resolution queries
--
-- Performance: < 1 second for 10,000 reminders
-- Risk Level: LOW (non-breaking, backward compatible)

-- Step 1: Add the updated_at column (nullable for zero-downtime migration)
ALTER TABLE public.reminders
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- Step 2: Backfill existing reminders with created_at value
-- This ensures proper conflict resolution for pre-existing reminders
UPDATE public.reminders
  SET updated_at = created_at
  WHERE updated_at IS NULL;

-- Step 3: Add trigger to automatically update updated_at on modifications
CREATE OR REPLACE FUNCTION update_reminder_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_reminder_updated_at ON public.reminders;
CREATE TRIGGER trigger_update_reminder_updated_at
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_reminder_updated_at();

-- Step 4: Add index for conflict resolution queries
CREATE INDEX IF NOT EXISTS idx_reminders_updated_at
  ON public.reminders (updated_at);

-- Step 5: Add helpful comment
COMMENT ON COLUMN public.reminders.updated_at IS
  'Timestamp when the reminder was last modified. Used for conflict resolution in sync.';

-- Verification query (for manual testing):
-- SELECT
--   COUNT(*) as total_reminders,
--   COUNT(updated_at) as with_updated_at,
--   COUNT(*) - COUNT(updated_at) as missing_updated_at
-- FROM public.reminders;
-- Expected: missing_updated_at = 0 after migration

-- Rollback (if needed):
-- DROP TRIGGER IF EXISTS trigger_update_reminder_updated_at ON public.reminders;
-- DROP FUNCTION IF EXISTS update_reminder_updated_at();
-- DROP INDEX IF EXISTS idx_reminders_updated_at;
-- ALTER TABLE public.reminders DROP COLUMN IF EXISTS updated_at;
