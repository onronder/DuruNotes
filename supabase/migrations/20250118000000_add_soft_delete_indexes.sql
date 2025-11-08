-- Migration: Add indexes for soft delete queries on folders and tasks
-- Purpose: Optimize queries filtering by deleted flag
-- Date: 2025-01-18
-- Phase: 1.1 - Soft Delete & Trash System

-- =====================================================
-- Add index on folders (user_id, deleted)
-- =====================================================
-- This index optimizes queries like:
-- SELECT * FROM folders WHERE user_id = ? AND deleted = false
CREATE INDEX IF NOT EXISTS folders_user_deleted_idx
  ON public.folders (user_id, deleted);

-- =====================================================
-- Add index on note_tasks (user_id, deleted)
-- =====================================================
-- This index optimizes queries like:
-- SELECT * FROM note_tasks WHERE user_id = ? AND deleted = false
CREATE INDEX IF NOT EXISTS note_tasks_user_deleted_idx
  ON public.note_tasks (user_id, deleted);

-- =====================================================
-- Verify existing indexes are in place
-- =====================================================
-- notes already has: notes_user_deleted_idx (confirmed in baseline schema)
-- This migration completes the index coverage for all soft-deletable tables

COMMENT ON INDEX folders_user_deleted_idx IS
  'Optimizes folder queries filtering by user and deleted status';

COMMENT ON INDEX note_tasks_user_deleted_idx IS
  'Optimizes task queries filtering by user and deleted status';
