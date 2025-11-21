-- ============================================================================
-- GDPR & Soft Delete Verification Queries
-- ============================================================================
-- These queries help verify that GDPR and soft-delete features are working
-- correctly in your production database.
--
-- Run these in Supabase Dashboard → SQL Editor
-- ============================================================================

-- ============================================================================
-- SECTION 1: VERIFY GDPR FUNCTIONS EXIST
-- ============================================================================

-- List all GDPR-related functions
SELECT
  proname as function_name,
  pronargs as arg_count,
  pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname LIKE '%anonymize%'
   OR proname LIKE '%gdpr%'
   OR proname LIKE '%profile_anonymization%'
   OR proname LIKE '%proof%'
ORDER BY proname;

-- Expected results:
-- - anonymize_all_user_content
-- - anonymize_user_audit_trail
-- - anonymize_user_folders
-- - anonymize_user_notes
-- - anonymize_user_profile
-- - anonymize_user_reminders
-- - anonymize_user_tasks
-- - clear_all_user_metadata
-- - create_gdpr_key_revocation_event
-- - delete_user_devices
-- - delete_user_notification_events
-- - delete_user_preferences
-- - delete_user_saved_searches
-- - delete_user_tags
-- - get_profile_anonymization_status
-- - get_proof_summary
-- - get_user_key_revocation_events
-- - is_profile_anonymized
-- - verify_proof_integrity

-- ============================================================================
-- SECTION 2: VERIFY GDPR TABLES EXIST
-- ============================================================================

-- List all GDPR-related tables
SELECT
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name IN (
    'anonymization_events',
    'anonymization_proofs',
    'key_revocation_events'
  )
ORDER BY table_name;

-- Expected results:
-- - anonymization_events (should have ~10 columns)
-- - anonymization_proofs (should have ~7 columns)
-- - key_revocation_events (should have ~10 columns)

-- ============================================================================
-- SECTION 3: VERIFY RLS POLICIES
-- ============================================================================

-- Check RLS is enabled on GDPR tables
SELECT
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'anonymization_events',
    'anonymization_proofs',
    'key_revocation_events'
  );

-- All should show rls_enabled = true

-- List all policies on GDPR tables
SELECT
  schemaname,
  tablename,
  policyname,
  cmd as policy_command
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'anonymization_events',
    'anonymization_proofs',
    'key_revocation_events'
  )
ORDER BY tablename, policyname;

-- ============================================================================
-- SECTION 4: TEST GDPR FUNCTIONS (SAFE - READ ONLY)
-- ============================================================================

-- Test 1: Check if a user is anonymized (safe, does not modify data)
-- Replace with your test user ID
SELECT * FROM get_profile_anonymization_status('05a1e86f-5d86-4462-bcaf-a5a3f1be73d0');

-- Expected result if NOT anonymized:
-- fully_anonymized = false
-- current_email = actual email
-- expected_anonymous_email = anon_xxxxxxxx@anonymized.local

-- Test 2: Check if profile is anonymized (safe, does not modify data)
SELECT is_profile_anonymized('05a1e86f-5d86-4462-bcaf-a5a3f1be73d0');

-- Expected result: false (if not anonymized yet)

-- ============================================================================
-- SECTION 5: SOFT DELETE VERIFICATION
-- ============================================================================

-- Check if soft-delete columns exist on all tables
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('notes', 'tasks', 'folders', 'reminders')
  AND column_name IN ('deleted_at', 'is_deleted')
ORDER BY table_name, column_name;

-- Expected: Each table should have both deleted_at and is_deleted columns

-- Count soft-deleted items for your user
-- Replace user ID with your test user ID
SELECT
  'notes' as item_type,
  COUNT(*) as deleted_count
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'tasks' as item_type,
  COUNT(*) as deleted_count
FROM tasks
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'folders' as item_type,
  COUNT(*) as deleted_count
FROM folders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'reminders' as item_type,
  COUNT(*) as deleted_count
FROM reminders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL;

-- ============================================================================
-- SECTION 6: VIEW SAMPLE SOFT-DELETED ITEMS
-- ============================================================================

-- View soft-deleted notes (if any)
SELECT
  id,
  deleted_at,
  is_deleted,
  created_at,
  updated_at
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL
ORDER BY deleted_at DESC
LIMIT 10;

-- ============================================================================
-- SECTION 7: ANONYMIZATION AUDIT TRAIL (for users who have been anonymized)
-- ============================================================================

-- Check if any anonymizations have occurred
SELECT
  user_id,
  anonymization_id,
  event_type,
  phase_number,
  created_at
FROM anonymization_events
ORDER BY created_at DESC
LIMIT 10;

-- If no results, no anonymizations have occurred yet (expected for new deployment)

-- ============================================================================
-- SECTION 8: COMPLIANCE PROOFS (for users who have been anonymized)
-- ============================================================================

-- Check if any compliance proofs exist
SELECT
  id,
  anonymization_id,
  user_id_hash,
  created_at
FROM anonymization_proofs
ORDER BY created_at DESC
LIMIT 10;

-- If no results, no anonymizations have occurred yet (expected for new deployment)

-- ============================================================================
-- SECTION 9: DATABASE HEALTH CHECK
-- ============================================================================

-- Count total users
SELECT COUNT(DISTINCT id) as total_users FROM auth.users;

-- Count total items per user (for your test user)
SELECT
  'notes' as type,
  COUNT(*) as total_count,
  COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted_count,
  COUNT(CASE WHEN deleted_at IS NULL THEN 1 END) as active_count
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'

UNION ALL

SELECT
  'tasks' as type,
  COUNT(*) as total_count,
  COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted_count,
  COUNT(CASE WHEN deleted_at IS NULL THEN 1 END) as active_count
FROM tasks
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'

UNION ALL

SELECT
  'folders' as type,
  COUNT(*) as total_count,
  COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted_count,
  COUNT(CASE WHEN deleted_at IS NULL THEN 1 END) as active_count
FROM folders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'

UNION ALL

SELECT
  'reminders' as type,
  COUNT(*) as total_count,
  COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted_count,
  COUNT(CASE WHEN deleted_at IS NULL THEN 1 END) as active_count
FROM reminders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0';

-- ============================================================================
-- SECTION 10: PROOF INTEGRITY TEST (only if proofs exist)
-- ============================================================================

-- Get all anonymization IDs
SELECT anonymization_id FROM anonymization_proofs;

-- Then test proof integrity for each ID (replace with actual ID)
-- SELECT verify_proof_integrity('anonymization-id-here');

-- Expected result: true (proof is valid and not tampered with)

-- ============================================================================
-- END OF VERIFICATION QUERIES
-- ============================================================================
--
-- SUMMARY:
-- 1. Run Section 1-3 to verify GDPR infrastructure is deployed
-- 2. Run Section 4 to test GDPR functions (safe, read-only)
-- 3. Run Section 5-6 to verify soft-delete functionality
-- 4. Run Section 7-8 after performing test anonymization
-- 5. Run Section 9 for overall database health
--
-- All queries are safe to run and will not modify any data
-- (except when explicitly noted)
-- ============================================================================
