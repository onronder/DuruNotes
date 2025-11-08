-- DATABASE INTEGRITY VERIFICATION QUERIES
-- Run these queries to verify user data isolation is working correctly
-- Execute on device SQLite database after implementing fixes

-- =====================================================================
-- SECTION 1: Check for Missing user_id Columns
-- =====================================================================

-- Check if all tables have user_id column (should return rows for all main tables)
SELECT
  name as table_name,
  sql
FROM sqlite_master
WHERE type = 'table'
  AND name IN (
    'local_notes',
    'local_folders',
    'note_tasks',
    'note_reminders',
    'note_tags',
    'note_links',
    'saved_searches',
    'pending_ops',
    'local_templates',
    'attachments',
    'inbox_items'
  )
ORDER BY name;

-- =====================================================================
-- SECTION 2: Check for NULL or Empty user_id Values
-- =====================================================================

-- Notes with missing user_id (should be 0 after fix)
SELECT COUNT(*) as notes_without_user
FROM local_notes
WHERE user_id IS NULL OR user_id = ''
  AND deleted = 0;

-- Folders with missing user_id (should be 0 after fix)
SELECT COUNT(*) as folders_without_user
FROM local_folders
WHERE user_id IS NULL OR user_id = ''
  AND deleted = 0;

-- Tasks with missing user_id (should be 0 after fix)
SELECT COUNT(*) as tasks_without_user
FROM note_tasks
WHERE user_id IS NULL OR user_id = ''
  AND deleted = 0;

-- Pending operations with missing user_id (should be 0 after fix)
SELECT COUNT(*) as pending_ops_without_user
FROM pending_ops
WHERE user_id IS NULL OR user_id = '';

-- =====================================================================
-- SECTION 3: Check for Multiple Users in Same Database
-- =====================================================================

-- Count distinct users in local_notes (should be 1 after login)
SELECT
  COUNT(DISTINCT user_id) as user_count,
  GROUP_CONCAT(DISTINCT user_id) as user_ids
FROM local_notes
WHERE deleted = 0
  AND user_id IS NOT NULL
  AND user_id != '';

-- Count distinct users across all tables (should all be 1)
SELECT
  'local_notes' as table_name,
  COUNT(DISTINCT user_id) as user_count
FROM local_notes
WHERE deleted = 0 AND user_id IS NOT NULL AND user_id != ''

UNION ALL

SELECT
  'local_folders' as table_name,
  COUNT(DISTINCT user_id) as user_count
FROM local_folders
WHERE deleted = 0 AND user_id IS NOT NULL AND user_id != ''

UNION ALL

SELECT
  'note_tasks' as table_name,
  COUNT(DISTINCT user_id) as user_count
FROM note_tasks
WHERE deleted = 0 AND user_id IS NOT NULL AND user_id != ''

UNION ALL

SELECT
  'saved_searches' as table_name,
  COUNT(DISTINCT user_id) as user_count
FROM saved_searches
WHERE user_id IS NOT NULL AND user_id != ''

UNION ALL

SELECT
  'pending_ops' as table_name,
  COUNT(DISTINCT user_id) as user_count
FROM pending_ops
WHERE user_id IS NOT NULL AND user_id != '';

-- =====================================================================
-- SECTION 4: Detailed Data Leakage Detection
-- =====================================================================

-- This query finds any records that don't belong to the current user
-- Run after User B logs in to check for User A's data
-- Replace '{{CURRENT_USER_ID}}' with actual current user ID

-- Notes from other users
SELECT
  'local_notes' as table_name,
  id,
  user_id,
  updated_at
FROM local_notes
WHERE deleted = 0
  AND user_id != '{{CURRENT_USER_ID}}'
ORDER BY updated_at DESC
LIMIT 10;

-- Folders from other users
SELECT
  'local_folders' as table_name,
  id,
  user_id,
  name,
  updated_at
FROM local_folders
WHERE deleted = 0
  AND user_id != '{{CURRENT_USER_ID}}'
ORDER BY updated_at DESC
LIMIT 10;

-- Tasks from other users
SELECT
  'note_tasks' as table_name,
  id,
  user_id,
  note_id,
  updated_at
FROM note_tasks
WHERE deleted = 0
  AND user_id != '{{CURRENT_USER_ID}}'
ORDER BY updated_at DESC
LIMIT 10;

-- =====================================================================
-- SECTION 5: Verify clearAll() Completeness
-- =====================================================================

-- After logout and clearAll(), all these counts should be 0
SELECT
  (SELECT COUNT(*) FROM local_notes) as local_notes_count,
  (SELECT COUNT(*) FROM local_folders) as local_folders_count,
  (SELECT COUNT(*) FROM note_tasks) as note_tasks_count,
  (SELECT COUNT(*) FROM note_reminders) as note_reminders_count,
  (SELECT COUNT(*) FROM note_tags) as note_tags_count,
  (SELECT COUNT(*) FROM note_links) as note_links_count,
  (SELECT COUNT(*) FROM note_folders) as note_folders_count,
  (SELECT COUNT(*) FROM saved_searches) as saved_searches_count,
  (SELECT COUNT(*) FROM pending_ops) as pending_ops_count,
  (SELECT COUNT(*) FROM local_templates WHERE is_system = 0) as user_templates_count,
  (SELECT COUNT(*) FROM attachments) as attachments_count,
  (SELECT COUNT(*) FROM inbox_items) as inbox_items_count,
  (SELECT COUNT(*) FROM fts_notes) as fts_notes_count;

-- =====================================================================
-- SECTION 6: Orphaned Records Detection
-- =====================================================================

-- Notes without valid user in user table (if you have user cache)
-- Modify if you don't have a local user cache table
SELECT COUNT(*) as orphaned_notes
FROM local_notes
WHERE deleted = 0
  AND user_id NOT IN (
    SELECT DISTINCT user_id FROM local_notes WHERE user_id IS NOT NULL
  );

-- Tasks referencing notes from different users
SELECT
  nt.id as task_id,
  nt.user_id as task_user_id,
  ln.user_id as note_user_id
FROM note_tasks nt
INNER JOIN local_notes ln ON nt.note_id = ln.id
WHERE nt.user_id != ln.user_id
  AND nt.deleted = 0
  AND ln.deleted = 0;

-- Folders referencing notes from different users (via note_folders junction)
SELECT
  nf.note_id,
  ln.user_id as note_user_id,
  lf.user_id as folder_user_id
FROM note_folders nf
INNER JOIN local_notes ln ON nf.note_id = ln.id
INNER JOIN local_folders lf ON nf.folder_id = lf.id
WHERE ln.user_id != lf.user_id;

-- =====================================================================
-- SECTION 7: Data Integrity Checks
-- =====================================================================

-- Check for duplicate notes (same ID, different users - should be impossible)
SELECT
  id,
  COUNT(*) as duplicate_count,
  GROUP_CONCAT(user_id) as user_ids
FROM local_notes
GROUP BY id
HAVING COUNT(*) > 1;

-- Check for folders with same name under same parent for same user
-- (This is OK across different users, but should be unique per user)
SELECT
  user_id,
  name,
  parent_id,
  COUNT(*) as duplicate_count
FROM local_folders
WHERE deleted = 0
GROUP BY user_id, name, parent_id
HAVING COUNT(*) > 1;

-- =====================================================================
-- SECTION 8: Quick Health Check
-- =====================================================================

-- Single query that gives overall database health status
SELECT
  -- Total records
  (SELECT COUNT(*) FROM local_notes WHERE deleted = 0) as total_notes,
  (SELECT COUNT(*) FROM local_folders WHERE deleted = 0) as total_folders,
  (SELECT COUNT(*) FROM note_tasks WHERE deleted = 0) as total_tasks,

  -- Records without user_id
  (SELECT COUNT(*) FROM local_notes WHERE deleted = 0 AND (user_id IS NULL OR user_id = '')) as notes_no_user,
  (SELECT COUNT(*) FROM local_folders WHERE deleted = 0 AND (user_id IS NULL OR user_id = '')) as folders_no_user,
  (SELECT COUNT(*) FROM note_tasks WHERE deleted = 0 AND (user_id IS NULL OR user_id = '')) as tasks_no_user,

  -- Distinct user count (should be 1 when logged in, 0 when logged out)
  (SELECT COUNT(DISTINCT user_id) FROM local_notes WHERE deleted = 0 AND user_id IS NOT NULL AND user_id != '') as distinct_users,

  -- Pending sync operations
  (SELECT COUNT(*) FROM pending_ops) as pending_sync_ops;

-- =====================================================================
-- SECTION 9: Performance Indexes Verification
-- =====================================================================

-- List all indexes on user_id columns (should exist after fix)
SELECT
  name as index_name,
  tbl_name as table_name,
  sql
FROM sqlite_master
WHERE type = 'index'
  AND sql LIKE '%user_id%'
ORDER BY tbl_name, name;

-- =====================================================================
-- SECTION 10: Export Current User State
-- =====================================================================

-- Get summary of current user's data (replace {{CURRENT_USER_ID}})
SELECT
  '{{CURRENT_USER_ID}}' as current_user_id,
  (SELECT COUNT(*) FROM local_notes WHERE user_id = '{{CURRENT_USER_ID}}' AND deleted = 0) as my_notes,
  (SELECT COUNT(*) FROM local_folders WHERE user_id = '{{CURRENT_USER_ID}}' AND deleted = 0) as my_folders,
  (SELECT COUNT(*) FROM note_tasks WHERE user_id = '{{CURRENT_USER_ID}}' AND deleted = 0) as my_tasks,
  (SELECT COUNT(*) FROM saved_searches WHERE user_id = '{{CURRENT_USER_ID}}') as my_searches,
  (SELECT COUNT(*) FROM pending_ops WHERE user_id = '{{CURRENT_USER_ID}}') as my_pending_ops;

-- =====================================================================
-- TROUBLESHOOTING QUERIES
-- =====================================================================

-- If data leakage is detected, use these queries to investigate:

-- 1. Find all records from a specific "wrong" user
-- SELECT * FROM local_notes WHERE user_id = '{{WRONG_USER_ID}}' AND deleted = 0;

-- 2. Find when wrong user's data was created/updated
-- SELECT
--   id,
--   user_id,
--   datetime(updated_at) as updated_at,
--   datetime(created_at) as created_at
-- FROM local_notes
-- WHERE user_id = '{{WRONG_USER_ID}}'
-- ORDER BY updated_at DESC;

-- 3. Check sync queue for mixed users
-- SELECT
--   entity_id,
--   kind,
--   user_id,
--   datetime(created_at) as created_at
-- FROM pending_ops
-- ORDER BY created_at DESC;

-- =====================================================================
-- CLEANUP QUERIES (USE WITH CAUTION)
-- =====================================================================

-- If data leakage is detected and you need to clean up manually:

-- ⚠️ DANGER: These queries will DELETE data. Use only in emergency.
-- ⚠️ Always backup database before running cleanup queries.

-- Delete all notes from wrong user (replace {{CURRENT_USER_ID}})
-- DELETE FROM local_notes WHERE user_id != '{{CURRENT_USER_ID}}';

-- Delete all folders from wrong user
-- DELETE FROM local_folders WHERE user_id != '{{CURRENT_USER_ID}}';

-- Delete all tasks from wrong user
-- DELETE FROM note_tasks WHERE user_id != '{{CURRENT_USER_ID}}';

-- Clear all pending operations (will force full re-sync)
-- DELETE FROM pending_ops;

-- Full database wipe (equivalent to clearAll())
-- DELETE FROM pending_ops;
-- DELETE FROM note_folders;
-- DELETE FROM note_tags;
-- DELETE FROM note_links;
-- DELETE FROM note_reminders;
-- DELETE FROM note_tasks;
-- DELETE FROM local_notes;
-- DELETE FROM local_folders;
-- DELETE FROM saved_searches;
-- DELETE FROM local_templates WHERE is_system = 0;
-- DELETE FROM attachments;
-- DELETE FROM inbox_items;
-- DELETE FROM fts_notes;

-- =====================================================================
-- EXPECTED RESULTS AFTER FIXES
-- =====================================================================

-- ✅ Section 2: All counts should be 0 (no records without user_id)
-- ✅ Section 3: user_count should be 1 when logged in, 0 when logged out
-- ✅ Section 4: Should return 0 rows (no other user's data)
-- ✅ Section 5: After clearAll(), all counts should be 0
-- ✅ Section 6: All orphan queries should return 0 rows
-- ✅ Section 7: Duplicate queries should return 0 rows
-- ✅ Section 8: distinct_users should be 1 (or 0 if logged out)
-- ✅ Section 9: Should show indexes on user_id for all main tables

-- =====================================================================
-- NOTES
-- =====================================================================

-- 1. Replace {{CURRENT_USER_ID}} with actual current user ID before running
-- 2. Run Section 1-8 queries in order to diagnose issues
-- 3. Use Section 10 to verify your own data is correct
-- 4. Only use cleanup queries if absolutely necessary
-- 5. Always backup database before running any DELETE queries

-- To get current user ID in your app, use:
-- final userId = Supabase.instance.client.auth.currentUser?.id;

-- =====================================================================
-- END OF VERIFICATION QUERIES
-- =====================================================================
