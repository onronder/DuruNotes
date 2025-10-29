-- Baseline validation script for project mizzxiijxtbwrqgflpnp
-- Run with:
--   supabase db dump --schema public --linked --file tmp_schema.sql (optional)
--   psql "$DB_URL" -f supabase/validation/check_baseline.sql

\echo '🔍 Validating core tables'
WITH expected AS (
  SELECT unnest(ARRAY[
    'notes','note_tasks','note_folders','note_tags','folders','reminders'
  ]) AS table_name
)
SELECT e.table_name,
       CASE WHEN t.table_name IS NOT NULL THEN '✅ present' ELSE '❌ missing' END AS status
FROM expected e
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'public' AND t.table_name = e.table_name
ORDER BY e.table_name;

\echo '🔍 Verifying required columns'
SELECT table_name,
       column_name,
       data_type,
       is_nullable,
       column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (
    ('notes','user_id'),
    ('notes','title_enc'),
    ('notes','props_enc'),
    ('note_tasks','labels'),
    ('note_tasks','metadata'),
    ('note_tasks','user_id'),
    ('note_folders','user_id'),
    ('reminders','metadata'),
    ('reminders','user_id')
  )
ORDER BY table_name, column_name;

\echo '🔍 Checking RLS status'
SELECT tablename,
       CASE WHEN rowsecurity THEN '✅ enabled' ELSE '❌ disabled' END AS rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('notes','note_tasks','note_folders','note_tags','folders','reminders')
ORDER BY tablename;

\echo '🔍 Checking RLS policies'
SELECT tablename,
       COUNT(*) AS policy_count,
       array_agg(policyname ORDER BY policyname) AS policies
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('notes','note_tasks','note_folders','note_tags','folders','reminders')
GROUP BY tablename
ORDER BY tablename;

\echo '🔍 Validating critical indexes'
SELECT tablename,
       indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('notes','note_tasks','note_folders','note_tags','folders','reminders')
  AND indexname IN (
    'notes_user_updated_idx',
    'notes_user_deleted_idx',
    'note_tasks_user_updated_idx',
    'note_tasks_note_idx',
    'note_folders_folder_idx',
    'note_folders_folder_updated',
    'note_tags_tag_idx',
    'note_tags_batch_load_idx',
    'reminders_active_idx',
    'reminders_user_note_idx',
    'folders_user_updated_idx'
  )
ORDER BY tablename, indexname;

\echo '✅ Baseline validation script finished'
