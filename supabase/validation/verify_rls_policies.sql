-- 🔐 RLS (Row Level Security) Policy Verification
-- Run this script to verify that all RLS policies are correctly configured
-- This ensures users can ONLY access their own data

-- ==================================================
-- TEST 1: Verify RLS is ENABLED on all critical tables
-- ==================================================
SELECT schemaname,
       tablename,
       rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'notes',
    'folders',
    'note_tasks',
    'reminders',
    'user_keys',
    'user_devices',
    'templates',
    'saved_searches'
  )
ORDER BY tablename;

-- Expected: ALL tables should have rls_enabled = true

-- ==================================================
-- TEST 2: List ALL RLS policies
-- ==================================================
SELECT schemaname,
       tablename,
       policyname,
       permissive,
       roles,
       cmd as operation,
       qual as using_expression,
       with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Expected: Multiple policies for each table, including SELECT, INSERT, UPDATE, DELETE

-- ==================================================
-- TEST 3: Verify notes table RLS
-- ==================================================
SELECT policyname,
       cmd as operation,
       qual as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'notes';

-- Expected policies:
-- - notes_select_policy (SELECT): (auth.uid() = user_id)
-- - notes_insert_policy (INSERT): (auth.uid() = user_id)
-- - notes_update_policy (UPDATE): (auth.uid() = user_id)
-- - notes_delete_policy (DELETE): (auth.uid() = user_id)

-- ==================================================
-- TEST 4: Verify user_keys table RLS
-- ==================================================
SELECT policyname,
       cmd as operation,
       qual as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_keys';

-- Expected: STRICT policy - users can ONLY access their own encryption keys

-- ==================================================
-- TEST 5: Verify folders table RLS
-- ==================================================
SELECT policyname,
       cmd as operation,
       qual as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'folders';

-- ==================================================
-- TEST 6: Verify reminders table RLS
-- ==================================================
SELECT policyname,
       cmd as operation,
       qual as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'reminders';

-- ==================================================
-- TEST 7: Test cross-user access (should be BLOCKED)
-- ==================================================
-- This test verifies that User A cannot access User B's data

-- Step 1: Get two different user IDs
WITH test_users AS (
  SELECT id, email,
         ROW_NUMBER() OVER (ORDER BY created_at) as rn
  FROM auth.users
  WHERE email LIKE 'test-%@duru.app'
  LIMIT 2
)
SELECT
  u1.email as user_a_email,
  u1.id as user_a_id,
  u2.email as user_b_email,
  u2.id as user_b_id
FROM test_users u1
CROSS JOIN test_users u2
WHERE u1.rn = 1 AND u2.rn = 2;

-- Step 2: Verify User A cannot query User B's notes
-- (This query should return 0 rows when RLS is working correctly)
SELECT 'SECURITY VIOLATION: Cross-user access detected!' as error_message,
       n.*
FROM notes n
WHERE n.user_id != auth.uid()
LIMIT 1;

-- Expected: 0 rows (RLS blocks cross-user access)
-- If ANY rows returned, RLS is BROKEN!

-- ==================================================
-- TEST 8: Verify user CAN access their own data
-- ==================================================
-- This verifies that RLS doesn't over-restrict

SELECT
  'notes' as table_name,
  COUNT(*) as user_can_see_own_rows
FROM notes
WHERE user_id = auth.uid()
UNION ALL
SELECT
  'folders' as table_name,
  COUNT(*) as user_can_see_own_rows
FROM folders
WHERE user_id = auth.uid()
UNION ALL
SELECT
  'user_keys' as table_name,
  COUNT(*) as user_can_see_own_rows
FROM user_keys
WHERE user_id = auth.uid();

-- Expected: Counts should match actual data for authenticated user

-- ==================================================
-- TEST 9: Verify INSERT protection
-- ==================================================
-- Try to insert a note for a different user (should FAIL)
-- IMPORTANT: This will fail with RLS error if working correctly!

DO $$
DECLARE
  other_user_id uuid;
  current_user_id uuid;
BEGIN
  -- Get current user
  current_user_id := auth.uid();

  -- Get a different user
  SELECT id INTO other_user_id
  FROM auth.users
  WHERE id != current_user_id
  LIMIT 1;

  -- Try to insert note for OTHER user (should fail)
  IF other_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO notes (id, user_id, title_enc, props_enc)
      VALUES (
        gen_random_uuid(),
        other_user_id,  -- Different user!
        'fake'::bytea,
        'fake'::bytea
      );

      -- If we get here, RLS is BROKEN!
      RAISE EXCEPTION 'SECURITY VIOLATION: Inserted note for different user!';
    EXCEPTION
      WHEN insufficient_privilege THEN
        -- This is expected - RLS blocked the insert
        RAISE NOTICE 'PASS: RLS correctly blocked cross-user insert';
    END;
  END IF;
END $$;

-- Expected: "PASS: RLS correctly blocked cross-user insert"
-- If "SECURITY VIOLATION" appears, RLS is BROKEN!

-- ==================================================
-- TEST 10: Verify UPDATE protection
-- ==================================================
DO $$
DECLARE
  other_user_note_id uuid;
  current_user_id uuid;
BEGIN
  current_user_id := auth.uid();

  -- Try to find a note from another user
  SELECT id INTO other_user_note_id
  FROM notes
  WHERE user_id != current_user_id
  LIMIT 1;

  IF other_user_note_id IS NOT NULL THEN
    BEGIN
      -- Try to update another user's note (should fail)
      UPDATE notes
      SET title_enc = 'hacked'::bytea
      WHERE id = other_user_note_id;

      -- Check if any rows were affected
      IF FOUND THEN
        RAISE EXCEPTION 'SECURITY VIOLATION: Updated another user note!';
      ELSE
        RAISE NOTICE 'PASS: RLS blocked cross-user update (no rows affected)';
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: RLS blocked cross-user update';
    END;
  END IF;
END $$;

-- Expected: "PASS: RLS blocked cross-user update"

-- ==================================================
-- TEST 11: Verify DELETE protection
-- ==================================================
DO $$
DECLARE
  other_user_note_id uuid;
  current_user_id uuid;
BEGIN
  current_user_id := auth.uid();

  SELECT id INTO other_user_note_id
  FROM notes
  WHERE user_id != current_user_id
  LIMIT 1;

  IF other_user_note_id IS NOT NULL THEN
    BEGIN
      DELETE FROM notes
      WHERE id = other_user_note_id;

      IF FOUND THEN
        RAISE EXCEPTION 'SECURITY VIOLATION: Deleted another user note!';
      ELSE
        RAISE NOTICE 'PASS: RLS blocked cross-user delete';
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: RLS blocked cross-user delete';
    END;
  END IF;
END $$;

-- ==================================================
-- TEST 12: Verify user_keys encryption key protection
-- ==================================================
-- This is CRITICAL - users must NEVER access other users' encryption keys!

SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'PASS: Cannot see other users AMKs'
    WHEN COUNT(*) > 0 THEN 'CRITICAL SECURITY VIOLATION: Can see other users AMKs!'
  END as test_result,
  COUNT(*) as other_users_keys_visible
FROM user_keys
WHERE user_id != auth.uid();

-- Expected: "PASS: Cannot see other users AMKs", count = 0
-- If count > 0, CRITICAL SECURITY BUG!

-- ==================================================
-- RESULTS SUMMARY
-- ==================================================
SELECT
  'RLS Verification Complete' as status,
  'Review all test results above' as action,
  'All PASS messages indicate correct security' as expected,
  'Any SECURITY VIOLATION indicates CRITICAL BUG' as warning;

-- ==================================================
-- CHECKLIST FOR MANUAL REVIEW
-- ==================================================
-- [ ] All tables have rls_enabled = true
-- [ ] All tables have SELECT/INSERT/UPDATE/DELETE policies
-- [ ] Cross-user access tests return 0 rows
-- [ ] Insert/Update/Delete protection tests show "PASS"
-- [ ] user_keys table protection shows "PASS"
-- [ ] No "SECURITY VIOLATION" messages anywhere
