-- Migration: Create trash_events audit table
-- Purpose: Track all trash operations (soft delete, permanent delete, restore)
-- Date: 2025-03-01
-- Phase: 1.1 - Soft Delete & Trash Enhancement

-- =====================================================
-- Create trash_events audit table
-- =====================================================
-- Tracks all delete/restore operations for compliance and analytics

CREATE TABLE public.trash_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,

  -- What was deleted
  item_type text NOT NULL CHECK (item_type IN ('note', 'folder', 'task')),
  item_id uuid NOT NULL,
  item_title text, -- Stored in plaintext for audit purposes

  -- What action was taken
  action text NOT NULL CHECK (action IN ('soft_delete', 'permanent_delete', 'restore')),

  -- When it happened
  event_timestamp timestamptz NOT NULL DEFAULT timezone('utc', now()),

  -- For soft deletes: when will it be purged
  scheduled_purge_at timestamptz,

  -- For permanent deletes: confirm it's gone
  is_permanent boolean NOT NULL DEFAULT false,

  -- Optional metadata (client version, device info, etc.)
  metadata jsonb,

  -- Standard timestamps
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.trash_events IS
  'Audit log for all trash operations: soft delete, permanent delete, and restore actions';

COMMENT ON COLUMN public.trash_events.item_type IS
  'Type of item: note, folder, or task';
COMMENT ON COLUMN public.trash_events.item_id IS
  'UUID of the deleted item (from notes, folders, or note_tasks table)';
COMMENT ON COLUMN public.trash_events.item_title IS
  'Title of the item at time of deletion (stored in plaintext for audit)';
COMMENT ON COLUMN public.trash_events.action IS
  'Action taken: soft_delete (moved to trash), permanent_delete (purged forever), restore (recovered from trash)';
COMMENT ON COLUMN public.trash_events.event_timestamp IS
  'UTC timestamp when the action occurred';
COMMENT ON COLUMN public.trash_events.scheduled_purge_at IS
  'For soft_delete actions: when the item is scheduled for automatic permanent deletion (typically event_timestamp + 30 days)';
COMMENT ON COLUMN public.trash_events.is_permanent IS
  'True if this is a permanent_delete action, false for soft_delete or restore';
COMMENT ON COLUMN public.trash_events.metadata IS
  'Optional JSON metadata: client version, device info, batch operation ID, etc.';

-- =====================================================
-- Create indexes for efficient queries
-- =====================================================

-- Primary query pattern: get trash events for a user, ordered by time
CREATE INDEX trash_events_user_timestamp_idx
  ON public.trash_events (user_id, event_timestamp DESC);

-- Query pattern: find all events for a specific item
CREATE INDEX trash_events_item_idx
  ON public.trash_events (item_type, item_id, event_timestamp DESC);

-- Query pattern: find items scheduled for purge in a time range
CREATE INDEX trash_events_purge_schedule_idx
  ON public.trash_events (scheduled_purge_at)
  WHERE scheduled_purge_at IS NOT NULL AND action = 'soft_delete';

-- Query pattern: analytics on permanent deletions
CREATE INDEX trash_events_permanent_idx
  ON public.trash_events (user_id, is_permanent, event_timestamp DESC)
  WHERE is_permanent = true;

COMMENT ON INDEX trash_events_user_timestamp_idx IS
  'Optimizes queries for user trash history ordered by time';
COMMENT ON INDEX trash_events_item_idx IS
  'Optimizes queries for tracking a specific item lifecycle (soft delete → restore → permanent delete)';
COMMENT ON INDEX trash_events_purge_schedule_idx IS
  'Optimizes queries for finding items scheduled for auto-purge';
COMMENT ON INDEX trash_events_permanent_idx IS
  'Optimizes analytics queries for permanent deletion events by user';

-- =====================================================
-- Enable Row Level Security (RLS)
-- =====================================================

ALTER TABLE public.trash_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own trash events
CREATE POLICY trash_events_select_own ON public.trash_events
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Users can only insert their own trash events
CREATE POLICY trash_events_insert_own ON public.trash_events
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: No updates allowed (audit log is append-only)
-- (No UPDATE policy = all updates blocked by default with RLS enabled)

-- Policy: No deletes allowed (audit log is permanent)
-- (No DELETE policy = all deletes blocked by default with RLS enabled)

COMMENT ON POLICY trash_events_select_own ON public.trash_events IS
  'Users can only query their own trash events';
COMMENT ON POLICY trash_events_insert_own ON public.trash_events IS
  'Users can only create trash events for items they own';

-- =====================================================
-- Create helper function for logging trash events
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_trash_event(
  p_item_type text,
  p_item_id uuid,
  p_item_title text,
  p_action text,
  p_scheduled_purge_at timestamptz DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id uuid;
  v_is_permanent boolean;
BEGIN
  -- Determine if this is a permanent delete
  v_is_permanent := (p_action = 'permanent_delete');

  -- Insert the audit event
  INSERT INTO public.trash_events (
    user_id,
    item_type,
    item_id,
    item_title,
    action,
    scheduled_purge_at,
    is_permanent,
    metadata
  ) VALUES (
    auth.uid(),
    p_item_type,
    p_item_id,
    p_item_title,
    p_action,
    p_scheduled_purge_at,
    v_is_permanent,
    p_metadata
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

COMMENT ON FUNCTION public.log_trash_event IS
  'Helper function to log a trash event. Called from application code when items are deleted, restored, or permanently purged.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.log_trash_event TO authenticated;

-- =====================================================
-- Create analytics function for trash statistics
-- =====================================================
-- Returns aggregated trash statistics for the current user
-- Uses SECURITY DEFINER to access trash_events with proper RLS

CREATE OR REPLACE FUNCTION public.get_trash_statistics()
RETURNS TABLE (
  user_id uuid,
  total_soft_deletes bigint,
  total_permanent_deletes bigint,
  total_restores bigint,
  notes_deleted bigint,
  folders_deleted bigint,
  tasks_deleted bigint,
  first_delete_at timestamptz,
  last_delete_at timestamptz,
  purge_within_7_days bigint,
  overdue_for_purge bigint
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    auth.uid() AS user_id,
    COUNT(*) FILTER (WHERE action = 'soft_delete') AS total_soft_deletes,
    COUNT(*) FILTER (WHERE action = 'permanent_delete') AS total_permanent_deletes,
    COUNT(*) FILTER (WHERE action = 'restore') AS total_restores,
    COUNT(*) FILTER (WHERE item_type = 'note') AS notes_deleted,
    COUNT(*) FILTER (WHERE item_type = 'folder') AS folders_deleted,
    COUNT(*) FILTER (WHERE item_type = 'task') AS tasks_deleted,
    MIN(event_timestamp) AS first_delete_at,
    MAX(event_timestamp) AS last_delete_at,
    COUNT(*) FILTER (
      WHERE action = 'soft_delete'
        AND scheduled_purge_at IS NOT NULL
        AND scheduled_purge_at <= timezone('utc', now()) + interval '7 days'
        AND scheduled_purge_at > timezone('utc', now())
    ) AS purge_within_7_days,
    COUNT(*) FILTER (
      WHERE action = 'soft_delete'
        AND scheduled_purge_at IS NOT NULL
        AND scheduled_purge_at < timezone('utc', now())
    ) AS overdue_for_purge
  FROM public.trash_events
  WHERE trash_events.user_id = auth.uid();
$$;

COMMENT ON FUNCTION public.get_trash_statistics IS
  'Returns trash statistics for the current authenticated user';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_trash_statistics TO authenticated;

-- =====================================================
-- Verification
-- =====================================================

DO $$
BEGIN
  -- Verify table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'trash_events'
  ) THEN
    RAISE EXCEPTION 'trash_events table was not created';
  END IF;

  -- Verify RLS is enabled
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'trash_events' AND rowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled on trash_events table';
  END IF;

  -- Verify indexes exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'trash_events'
      AND indexname = 'trash_events_user_timestamp_idx'
  ) THEN
    RAISE EXCEPTION 'trash_events_user_timestamp_idx index is missing';
  END IF;

  -- Verify log_trash_event function exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'log_trash_event'
  ) THEN
    RAISE EXCEPTION 'log_trash_event function was not created';
  END IF;

  -- Verify get_trash_statistics function exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'get_trash_statistics'
  ) THEN
    RAISE EXCEPTION 'get_trash_statistics function was not created';
  END IF;

  RAISE NOTICE 'trash_events audit table created successfully with RLS policies and helper functions';
END $$;
