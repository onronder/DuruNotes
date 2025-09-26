-- Migration: Test and Verification Suite
-- Version: Verification of applied migrations
-- Description: Validates indexes, constraints, and policies

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Simple verification output
DO $$
DECLARE
  v_index_count INT;
  v_constraint_count INT;
  v_policy_count INT;
  v_function_count INT;
BEGIN
  -- Count indexes on notes table
  SELECT COUNT(*)
  INTO v_index_count
  FROM pg_indexes
  WHERE tablename = 'notes'
    AND schemaname = current_schema();

  RAISE NOTICE 'Notes table indexes created: %', v_index_count;

  -- Count constraints
  SELECT COUNT(*)
  INTO v_constraint_count
  FROM information_schema.check_constraints
  WHERE constraint_schema = current_schema()
    AND constraint_name LIKE 'chk_%';

  RAISE NOTICE 'Check constraints created: %', v_constraint_count;

  -- Count RLS policies
  SELECT COUNT(*)
  INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = current_schema()
    AND tablename IN ('notes', 'note_tasks', 'folders', 'note_folders');

  RAISE NOTICE 'RLS policies created: %', v_policy_count;

  -- Count validation functions
  SELECT COUNT(*)
  INTO v_function_count
  FROM information_schema.routines
  WHERE routine_schema = current_schema()
    AND routine_name IN ('validate_email', 'validate_url', 'validate_uuid', 'sanitize_text');

  RAISE NOTICE 'Validation functions created: %', v_function_count;

  -- Summary
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MIGRATION VERIFICATION COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total indexes: %', v_index_count;
  RAISE NOTICE 'Total constraints: %', v_constraint_count;
  RAISE NOTICE 'Total RLS policies: %', v_policy_count;
  RAISE NOTICE 'Total functions: %', v_function_count;
  RAISE NOTICE '========================================';
END $$;

-- Test RLS is working
DO $$
BEGIN
  -- Check if RLS is enabled
  IF EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'notes'
      AND rowsecurity = true
  ) THEN
    RAISE NOTICE 'RLS Status: ENABLED on notes table ✓';
  ELSE
    RAISE WARNING 'RLS Status: NOT ENABLED on notes table ✗';
  END IF;
END $$;

-- List all created indexes
SELECT
  indexname,
  tablename,
  indexdef
FROM pg_indexes
WHERE schemaname = current_schema()
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- List all RLS policies
SELECT
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual IS NOT NULL as has_using,
  with_check IS NOT NULL as has_with_check
FROM pg_policies
WHERE schemaname = current_schema()
ORDER BY tablename, policyname;

-- Show validation functions
SELECT
  routine_name as function_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = current_schema()
  AND routine_name IN ('validate_email', 'validate_url', 'validate_uuid', 'sanitize_text', 'update_updated_at_column')
ORDER BY routine_name;