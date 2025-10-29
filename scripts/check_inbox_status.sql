-- Email Inbox Status Check Script
-- Run this to verify the current state of your inbox system
-- Usage: supabase db execute < scripts/check_inbox_status.sql

\echo '================================'
\echo 'EMAIL INBOX SYSTEM STATUS CHECK'
\echo '================================'
\echo ''

-- Check 1: Verify clipper_inbox table exists
\echo '1. Checking if clipper_inbox table exists...'
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'clipper_inbox'
) AS table_exists;

-- Check 2: List all columns in clipper_inbox
\echo ''
\echo '2. Current clipper_inbox schema:'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'clipper_inbox'
ORDER BY ordinal_position;

-- Check 3: Verify critical columns exist
\echo ''
\echo '3. Checking for critical columns:'
SELECT
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'is_processed') AS has_is_processed,
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'converted_to_note_id') AS has_converted_to_note_id,
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'processed_at') AS has_processed_at,
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'updated_at') AS has_updated_at;

-- Check 4: List RLS policies
\echo ''
\echo '4. RLS Policies on clipper_inbox:'
SELECT
    policyname AS policy_name,
    cmd AS operation,
    CASE WHEN qual IS NOT NULL THEN 'USING clause' ELSE 'No USING' END AS has_using,
    CASE WHEN with_check IS NOT NULL THEN 'WITH CHECK clause' ELSE 'No WITH CHECK' END AS has_with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'clipper_inbox'
ORDER BY policyname;

-- Check 5: List indexes
\echo ''
\echo '5. Indexes on clipper_inbox:'
SELECT
    indexname AS index_name,
    indexdef AS definition
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'clipper_inbox'
ORDER BY indexname;

-- Check 6: Count items by status
\echo ''
\echo '6. Item counts:'
SELECT
    COUNT(*) FILTER (WHERE is_processed = false OR is_processed IS NULL) AS unprocessed_count,
    COUNT(*) FILTER (WHERE is_processed = true) AS processed_count,
    COUNT(*) AS total_count
FROM clipper_inbox;

-- Check 7: Recent items
\echo ''
\echo '7. Recent inbox items (last 5):'
SELECT
    id,
    source_type,
    title,
    CASE
        WHEN is_processed IS NULL THEN 'NULL (NEEDS FIX)'
        WHEN is_processed = true THEN 'processed'
        WHEN is_processed = false THEN 'unprocessed'
    END AS status,
    created_at
FROM clipper_inbox
ORDER BY created_at DESC
LIMIT 5;

-- Check 8: Foreign key constraints
\echo ''
\echo '8. Foreign key constraints:'
SELECT
    conname AS constraint_name,
    contype AS constraint_type,
    CASE contype
        WHEN 'f' THEN 'Foreign Key'
        WHEN 'p' THEN 'Primary Key'
        WHEN 'u' THEN 'Unique'
        WHEN 'c' THEN 'Check'
    END AS constraint_description
FROM pg_constraint
WHERE conrelid = 'public.clipper_inbox'::regclass
ORDER BY conname;

-- Check 9: Verify inbox_items view
\echo ''
\echo '9. Checking inbox_items view:'
SELECT EXISTS (
    SELECT 1
    FROM information_schema.views
    WHERE table_schema = 'public'
    AND table_name = 'inbox_items'
) AS view_exists;

-- Check 10: Test query that InboxRepository uses
\echo ''
\echo '10. Testing InboxRepository query pattern:'
\echo 'This query should work without errors:'
DO $$
BEGIN
    -- Try to execute the query that InboxRepository uses
    PERFORM *
    FROM clipper_inbox
    WHERE is_processed = false
    LIMIT 1;

    RAISE NOTICE '✅ InboxRepository query pattern works!';
EXCEPTION
    WHEN undefined_column THEN
        RAISE NOTICE '❌ ERROR: is_processed column does not exist! Migration needed.';
    WHEN OTHERS THEN
        RAISE NOTICE '❌ ERROR: %', SQLERRM;
END $$;

-- Summary
\echo ''
\echo '================================'
\echo 'SUMMARY'
\echo '================================'
\echo ''

DO $$
DECLARE
    has_is_processed boolean;
    has_converted_note_id boolean;
    total_items integer;
    unprocessed_items integer;
BEGIN
    -- Check critical columns
    SELECT
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'is_processed'),
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clipper_inbox' AND column_name = 'converted_to_note_id')
    INTO has_is_processed, has_converted_note_id;

    -- Count items
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE is_processed = false OR is_processed IS NULL)
    INTO total_items, unprocessed_items
    FROM clipper_inbox;

    -- Print summary
    IF has_is_processed AND has_converted_note_id THEN
        RAISE NOTICE '✅ STATUS: Schema is FIXED';
        RAISE NOTICE '   - is_processed column: EXISTS';
        RAISE NOTICE '   - converted_to_note_id column: EXISTS';
        RAISE NOTICE '   - Total items: %', total_items;
        RAISE NOTICE '   - Unprocessed items: %', unprocessed_items;
        RAISE NOTICE '';
        RAISE NOTICE '   Next steps:';
        RAISE NOTICE '   1. Test inbox UI - should show % items', unprocessed_items;
        RAISE NOTICE '   2. Send test email to verify end-to-end flow';
        RAISE NOTICE '   3. Monitor application logs for errors';
    ELSE
        RAISE NOTICE '❌ STATUS: Schema NEEDS FIX';
        IF NOT has_is_processed THEN
            RAISE NOTICE '   - is_processed column: MISSING';
        END IF;
        IF NOT has_converted_note_id THEN
            RAISE NOTICE '   - converted_to_note_id column: MISSING';
        END IF;
        RAISE NOTICE '';
        RAISE NOTICE '   Required action:';
        RAISE NOTICE '   Run migration: supabase db push';
        RAISE NOTICE '   Migration file: supabase/migrations/20251009_fix_clipper_inbox_schema.sql';
    END IF;
END $$;

\echo ''
\echo '================================'
\echo 'For detailed help, see:'
\echo '  EMAIL_INBOX_FIX_GUIDE.md'
\echo '  EMAIL_INBOX_ARCHITECTURE_AUDIT.md'
\echo '================================'
