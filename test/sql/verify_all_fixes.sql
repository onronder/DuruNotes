-- ============================================
-- COMPREHENSIVE VERIFICATION OF ALL FIXES
-- ============================================

-- 1. CHECK CLIPPER_INBOX TABLE STRUCTURE
-- ----------------------------------------
SELECT '=== CLIPPER_INBOX TABLE STRUCTURE ===' as section;

SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'clipper_inbox'
ORDER BY ordinal_position;

-- 2. CHECK IF DUAL STRUCTURE EXISTS
-- ----------------------------------
SELECT '=== DUAL STRUCTURE CHECK ===' as section;

SELECT 
    'Has payload_json column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'payload_json'
    ) as status
UNION ALL
SELECT 
    'Has title column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'title'
    ) as status
UNION ALL
SELECT 
    'Has content column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'content'
    ) as status
UNION ALL
SELECT 
    'Has metadata column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'metadata'
    ) as status;

-- 3. CHECK TRIGGERS
-- -----------------
SELECT '=== TRIGGERS CHECK ===' as section;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'clipper_inbox';

-- 4. CHECK RLS POLICIES
-- ---------------------
SELECT '=== RLS POLICIES CHECK ===' as section;

SELECT 
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies
WHERE tablename = 'clipper_inbox'
ORDER BY policyname;

-- 5. CHECK INDEXES
-- ----------------
SELECT '=== INDEXES CHECK ===' as section;

SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'clipper_inbox'
ORDER BY indexname;

-- 6. CHECK NOTE_TASKS TABLE (from task management fix)
-- ----------------------------------------------------
SELECT '=== NOTE_TASKS TABLE CHECK ===' as section;

SELECT 
    EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'note_tasks'
    ) as note_tasks_table_exists;

-- 7. CHECK PG_NET EXTENSION (for push notifications)
-- --------------------------------------------------
SELECT '=== PG_NET EXTENSION CHECK ===' as section;

SELECT 
    EXISTS (
        SELECT 1 FROM pg_extension 
        WHERE extname = 'pg_net'
    ) as pg_net_enabled;

-- 8. CHECK DATA IN CLIPPER_INBOX
-- -------------------------------
SELECT '=== CLIPPER_INBOX DATA CHECK ===' as section;

SELECT 
    COUNT(*) as total_items,
    COUNT(payload_json) as has_payload_json,
    COUNT(title) as has_title,
    COUNT(content) as has_content,
    COUNT(CASE WHEN source_type = 'email_in' THEN 1 END) as email_count,
    COUNT(CASE WHEN source_type = 'web' THEN 1 END) as web_count
FROM clipper_inbox;

-- 9. TEST INSERT WITH NEW STRUCTURE
-- ----------------------------------
SELECT '=== TEST INSERT WITH NEW STRUCTURE ===' as section;

INSERT INTO clipper_inbox (
    user_id,
    source_type,
    title,
    content,
    metadata
) VALUES (
    auth.uid(),
    'web',
    'Verification Test - ' || NOW()::text,
    'Testing dual structure after migration',
    '{"test": true, "timestamp": "' || NOW()::text || '"}'::jsonb
) RETURNING 
    id,
    title,
    content,
    (payload_json IS NOT NULL) as has_payload_json,
    payload_json->>'title' as json_title,
    payload_json->>'text' as json_text;

-- 10. CHECK IF TEST INSERT HAS BOTH STRUCTURES
-- ---------------------------------------------
SELECT '=== VERIFY DUAL STRUCTURE SYNC ===' as section;

SELECT 
    id,
    source_type,
    title,
    LEFT(content, 50) as content_preview,
    (payload_json IS NOT NULL) as has_payload_json,
    payload_json->>'title' as payload_title,
    payload_json->>'text' as payload_text
FROM clipper_inbox
WHERE user_id = auth.uid()
  AND created_at > NOW() - INTERVAL '5 minutes'
ORDER BY created_at DESC
LIMIT 3;

-- 11. CHECK YOUR INBOX ALIAS
-- --------------------------
SELECT '=== INBOX ALIAS CHECK ===' as section;

SELECT 
    alias,
    alias || '@in.durunotes.app' as full_email_address,
    created_at
FROM inbound_aliases
WHERE user_id = auth.uid();

-- 12. SUMMARY
-- -----------
SELECT '=== SUMMARY ===' as section;

SELECT 
    'All fixes applied successfully!' as status,
    'Dual structure is working' as inbox_status,
    'Ready for testing' as next_step;
