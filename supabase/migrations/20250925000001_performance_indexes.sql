-- Migration: Add Performance Indexes for Production-Grade Optimization
-- Version: Sync with local DB v18
-- Description: Critical performance indexes for billion-scale operations

-- ============================================================================
-- NOTES TABLE INDEXES
-- ============================================================================

-- Primary query patterns
CREATE INDEX IF NOT EXISTS idx_notes_updated_at
  ON notes(updated_at DESC)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_notes_user_id
  ON notes(user_id, updated_at DESC)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_notes_deleted
  ON notes(deleted, updated_at DESC);

-- Composite indexes for common filters
CREATE INDEX IF NOT EXISTS idx_notes_user_deleted_updated
  ON notes(user_id, deleted, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_notes_user_active
  ON notes(user_id, updated_at DESC)
  WHERE deleted = false;

-- Encryption and sync optimization
CREATE INDEX IF NOT EXISTS idx_notes_sync_status
  ON notes(user_id, updated_at)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_notes_version
  ON notes(version, updated_at DESC)
  WHERE deleted = false;

-- Full-text search optimization (on encrypted title)
CREATE INDEX IF NOT EXISTS idx_notes_title_enc_hash
  ON notes(user_id, md5(title_enc::text))
  WHERE deleted = false;

-- ============================================================================
-- NOTE_TASKS TABLE INDEXES
-- ============================================================================

-- Task query optimization for note_tasks table
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status
  ON note_tasks(user_id, status, due_date);

CREATE INDEX IF NOT EXISTS idx_note_tasks_note_id
  ON note_tasks(note_id, status);

CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date
  ON note_tasks(due_date, status)
  WHERE deleted = false;

-- Task overdue and priority indexes
CREATE INDEX IF NOT EXISTS idx_note_tasks_overdue
  ON note_tasks(user_id, due_date)
  WHERE deleted = false AND due_date < CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_note_tasks_priority
  ON note_tasks(user_id, priority DESC, due_date)
  WHERE deleted = false;

-- ============================================================================
-- FOLDERS TABLE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_folders_user_id
  ON folders(user_id, name_enc)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_folders_parent
  ON folders(parent_id, user_id)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_folders_updated
  ON folders(updated_at DESC)
  WHERE deleted = false;

-- Hierarchical query optimization
CREATE INDEX IF NOT EXISTS idx_folders_hierarchy
  ON folders(user_id, parent_id, name_enc)
  WHERE deleted = false;

-- ============================================================================
-- NOTE_FOLDERS RELATIONSHIP INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_note_folders_note
  ON note_folders(note_id, folder_id);

CREATE INDEX IF NOT EXISTS idx_note_folders_folder
  ON note_folders(folder_id, note_id);

CREATE INDEX IF NOT EXISTS idx_note_folders_user
  ON note_folders(user_id, folder_id, note_id);

-- ============================================================================
-- TAGS TABLE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_tags_user_name
  ON tags(user_id, name)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_tags_popularity
  ON tags(user_id, use_count DESC)
  WHERE deleted = false;

-- ============================================================================
-- NOTE_TAGS RELATIONSHIP INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_note_tags_note
  ON note_tags(note_id, tag_id);

CREATE INDEX IF NOT EXISTS idx_note_tags_tag
  ON note_tags(tag_id, note_id);

-- ============================================================================
-- ATTACHMENTS TABLE INDEXES
-- ============================================================================

-- CREATE INDEX IF NOT EXISTS idx_attachments_note
--   ON attachments(note_id, created_at DESC)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_attachments_user
--   ON attachments(user_id, created_at DESC)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_attachments_type
--   ON attachments(user_id, file_type, created_at DESC)
--   WHERE deleted = false;

-- ============================================================================
-- REMINDERS TABLE INDEXES
-- ============================================================================

-- CREATE INDEX IF NOT EXISTS idx_reminders_scheduled
--   ON reminders(scheduled_time, fired)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_reminders_user_pending
--   ON reminders(user_id, scheduled_time)
--   WHERE fired = false AND deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_reminders_task
--   ON reminders(task_id, scheduled_time)
--   WHERE deleted = false;

-- ============================================================================
-- TEMPLATES TABLE INDEXES
-- ============================================================================

-- CREATE INDEX IF NOT EXISTS idx_templates_user
--   ON templates(user_id, name)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_templates_category
--   ON templates(category, user_id)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_templates_shared
--   ON templates(is_shared, category)
--   WHERE deleted = false;

-- ============================================================================
-- SAVED_SEARCHES TABLE INDEXES
-- ============================================================================

-- CREATE INDEX IF NOT EXISTS idx_saved_searches_user
--   ON saved_searches(user_id, name)
--   WHERE deleted = false;

-- CREATE INDEX IF NOT EXISTS idx_saved_searches_used
--   ON saved_searches(user_id, last_used DESC)
--   WHERE deleted = false;

-- ============================================================================
-- PARTIAL INDEXES FOR SPECIAL QUERIES
-- ============================================================================

-- Pinned notes optimization
CREATE INDEX IF NOT EXISTS idx_notes_pinned
  ON notes(user_id, updated_at DESC)
  WHERE is_pinned = true AND deleted = false;

-- Archived notes optimization
-- CREATE INDEX IF NOT EXISTS idx_notes_archived
--   ON notes(user_id, archived_at DESC)
--   WHERE archived = true AND deleted = false;

-- Shared notes optimization
-- CREATE INDEX IF NOT EXISTS idx_notes_shared
--   ON notes(user_id, updated_at DESC)
--   WHERE is_shared = true AND deleted = false;

-- ============================================================================
-- PERFORMANCE STATISTICS
-- ============================================================================

-- Create index statistics table for monitoring
CREATE TABLE IF NOT EXISTS index_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  index_name TEXT NOT NULL,
  table_name TEXT NOT NULL,
  index_size BIGINT,
  number_of_scans BIGINT DEFAULT 0,
  rows_read BIGINT DEFAULT 0,
  rows_fetched BIGINT DEFAULT 0,
  last_used TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index to track index usage
CREATE INDEX IF NOT EXISTS idx_index_statistics_usage
  ON index_statistics(last_used DESC, number_of_scans DESC);

-- ============================================================================
-- ANALYZE TABLES FOR QUERY PLANNER
-- ============================================================================

-- Update statistics for query planner optimization
ANALYZE notes;
ANALYZE note_tasks;
ANALYZE folders;
ANALYZE note_folders;
-- ANALYZE tags;
-- ANALYZE note_tags;
-- ANALYZE attachments;
-- ANALYZE reminders;
-- ANALYZE templates;
-- ANALYZE saved_searches;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON INDEX idx_notes_updated_at IS 'Primary index for recent notes queries';
COMMENT ON INDEX idx_notes_user_id IS 'User isolation and multi-tenancy';
COMMENT ON INDEX idx_note_tasks_user_status IS 'Task query optimization';
COMMENT ON INDEX idx_note_tasks_due_date IS 'Task scheduling and due date queries';
COMMENT ON INDEX idx_folders_user_id IS 'Folder user isolation';
COMMENT ON INDEX idx_notes_title_enc_hash IS 'Encrypted title search optimization';