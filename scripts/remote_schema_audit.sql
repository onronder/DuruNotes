-- ============================================================================
-- REMOTE SCHEMA AUDIT - Run each section in Supabase SQL Editor
-- Copy ALL outputs and paste back to me
-- ============================================================================

-- SECTION 1: Which tables exist?
-- ============================================================================
SELECT
  tablename,
  CASE WHEN rowsecurity THEN 'RLS enabled' ELSE 'RLS DISABLED' END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('notes', 'note_tasks', 'folders', 'saved_searches', 'note_tags', 'note_folders', 'note_reminders')
ORDER BY tablename;


-- SECTION 2: user_id columns check
-- ============================================================================
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name = 'user_id'
  AND table_name IN ('notes', 'note_tasks', 'folders', 'saved_searches')
ORDER BY table_name;


-- SECTION 3: notes table structure
-- ============================================================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notes'
ORDER BY ordinal_position;


-- SECTION 4: note_tasks table structure
-- ============================================================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'note_tasks'
ORDER BY ordinal_position;


-- SECTION 5: folders table structure
-- ============================================================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'folders'
ORDER BY ordinal_position;


-- SECTION 6: RLS Policies
-- ============================================================================
SELECT
  tablename,
  policyname,
  cmd as operation,
  LEFT(qual::text, 100) as policy_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('notes', 'note_tasks', 'folders', 'saved_searches', 'note_tags', 'note_folders')
ORDER BY tablename, cmd;


-- SECTION 7: Data counts
-- ============================================================================
SELECT
  'notes' as table_name,
  COUNT(*) as row_count,
  COUNT(DISTINCT user_id) as unique_users
FROM notes
UNION ALL
SELECT
  'note_tasks',
  COUNT(*),
  COUNT(DISTINCT user_id)
FROM note_tasks
UNION ALL
SELECT
  'folders',
  COUNT(*),
  COUNT(DISTINCT user_id)
FROM folders;


-- SECTION 8: Recent migrations
-- ============================================================================
SELECT
  version,
  inserted_at
FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 10;


-- SECTION 9: Check for encryption columns in notes
-- ============================================================================
SELECT
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notes'
  AND column_name LIKE '%encrypted%'
    OR column_name IN ('title', 'body');


-- SECTION 10: Sample note (if any exist)
-- ============================================================================
-- Only run if you have data and want to verify encryption
SELECT
  id,
  user_id,
  LEFT(COALESCE(title_encrypted, title, ''), 50) as title_sample,
  deleted,
  created_at
FROM notes
LIMIT 1;
