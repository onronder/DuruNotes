-- Migration: Add timestamp columns for soft delete & trash system
-- Purpose: Track deletion time and scheduled purge date for 30-day retention
-- Date: 2025-03-01
-- Phase: 1.1 - Soft Delete & Trash Enhancement

-- =====================================================
-- Add timestamp columns to notes table
-- =====================================================
-- deleted_at: When the note was soft-deleted
-- scheduled_purge_at: When the note should be permanently deleted (30 days)
ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS scheduled_purge_at timestamptz;

COMMENT ON COLUMN public.notes.deleted_at IS
  'Timestamp when the note was soft-deleted (UTC)';
COMMENT ON COLUMN public.notes.scheduled_purge_at IS
  'Timestamp when the note should be permanently purged (UTC, typically deleted_at + 30 days)';

-- =====================================================
-- Add timestamp columns to folders table
-- =====================================================
ALTER TABLE public.folders
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS scheduled_purge_at timestamptz;

COMMENT ON COLUMN public.folders.deleted_at IS
  'Timestamp when the folder was soft-deleted (UTC)';
COMMENT ON COLUMN public.folders.scheduled_purge_at IS
  'Timestamp when the folder should be permanently purged (UTC, typically deleted_at + 30 days)';

-- =====================================================
-- Add timestamp columns to note_tasks table
-- =====================================================
ALTER TABLE public.note_tasks
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS scheduled_purge_at timestamptz;

COMMENT ON COLUMN public.note_tasks.deleted_at IS
  'Timestamp when the task was soft-deleted (UTC)';
COMMENT ON COLUMN public.note_tasks.scheduled_purge_at IS
  'Timestamp when the task should be permanently purged (UTC, typically deleted_at + 30 days)';

-- =====================================================
-- Create indexes for efficient trash queries
-- =====================================================
-- Index for finding deleted items by user and deletion time
CREATE INDEX IF NOT EXISTS notes_deleted_at_idx
  ON public.notes (user_id, deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS folders_deleted_at_idx
  ON public.folders (user_id, deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS note_tasks_deleted_at_idx
  ON public.note_tasks (user_id, deleted_at)
  WHERE deleted_at IS NOT NULL;

-- Index for finding items ready to be purged (auto-cleanup queries)
CREATE INDEX IF NOT EXISTS notes_purge_schedule_idx
  ON public.notes (scheduled_purge_at)
  WHERE scheduled_purge_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS folders_purge_schedule_idx
  ON public.folders (scheduled_purge_at)
  WHERE scheduled_purge_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS note_tasks_purge_schedule_idx
  ON public.note_tasks (scheduled_purge_at)
  WHERE scheduled_purge_at IS NOT NULL;

COMMENT ON INDEX notes_deleted_at_idx IS
  'Optimizes trash queries for deleted notes by user and deletion time';
COMMENT ON INDEX folders_deleted_at_idx IS
  'Optimizes trash queries for deleted folders by user and deletion time';
COMMENT ON INDEX note_tasks_deleted_at_idx IS
  'Optimizes trash queries for deleted tasks by user and deletion time';
COMMENT ON INDEX notes_purge_schedule_idx IS
  'Optimizes auto-purge queries to find notes ready for permanent deletion';
COMMENT ON INDEX folders_purge_schedule_idx IS
  'Optimizes auto-purge queries to find folders ready for permanent deletion';
COMMENT ON INDEX note_tasks_purge_schedule_idx IS
  'Optimizes auto-purge queries to find tasks ready for permanent deletion';

-- =====================================================
-- Backfill existing soft-deleted items
-- =====================================================
-- For items where deleted = true but no timestamps set:
-- - Set deleted_at = updated_at (best approximation)
-- - Set scheduled_purge_at = updated_at + 30 days
--
-- NOTE: All three tables have updated_at defined as NOT NULL with a default,
-- so updated_at is guaranteed to be non-null. COALESCE is used defensively
-- in case of data corruption, falling back to current time.

-- Backfill notes
UPDATE public.notes
SET
  deleted_at = COALESCE(updated_at, timezone('utc', now())),
  scheduled_purge_at = COALESCE(updated_at, timezone('utc', now())) + interval '30 days'
WHERE
  deleted = true
  AND deleted_at IS NULL;

-- Backfill folders
UPDATE public.folders
SET
  deleted_at = COALESCE(updated_at, timezone('utc', now())),
  scheduled_purge_at = COALESCE(updated_at, timezone('utc', now())) + interval '30 days'
WHERE
  deleted = true
  AND deleted_at IS NULL;

-- Backfill note_tasks
UPDATE public.note_tasks
SET
  deleted_at = COALESCE(updated_at, timezone('utc', now())),
  scheduled_purge_at = COALESCE(updated_at, timezone('utc', now())) + interval '30 days'
WHERE
  deleted = true
  AND deleted_at IS NULL;

-- =====================================================
-- Verification
-- =====================================================
-- Check that backfill completed successfully
DO $$
DECLARE
  notes_count int;
  folders_count int;
  tasks_count int;
  notes_backfilled int;
  folders_backfilled int;
  tasks_backfilled int;
BEGIN
  -- Count any remaining deleted items without timestamps
  SELECT COUNT(*) INTO notes_count
  FROM public.notes
  WHERE deleted = true AND deleted_at IS NULL;

  SELECT COUNT(*) INTO folders_count
  FROM public.folders
  WHERE deleted = true AND deleted_at IS NULL;

  SELECT COUNT(*) INTO tasks_count
  FROM public.note_tasks
  WHERE deleted = true AND deleted_at IS NULL;

  -- Count items that were backfilled
  SELECT COUNT(*) INTO notes_backfilled
  FROM public.notes
  WHERE deleted = true AND deleted_at IS NOT NULL;

  SELECT COUNT(*) INTO folders_backfilled
  FROM public.folders
  WHERE deleted = true AND deleted_at IS NOT NULL;

  SELECT COUNT(*) INTO tasks_backfilled
  FROM public.note_tasks
  WHERE deleted = true AND deleted_at IS NOT NULL;

  IF notes_count > 0 OR folders_count > 0 OR tasks_count > 0 THEN
    RAISE WARNING 'Backfill incomplete - deleted items without timestamps: notes=%, folders=%, tasks=%',
      notes_count, folders_count, tasks_count;
  ELSE
    RAISE NOTICE 'Soft delete timestamps backfill completed successfully: notes=%, folders=%, tasks=%',
      notes_backfilled, folders_backfilled, tasks_backfilled;
  END IF;
END $$;
