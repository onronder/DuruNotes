-- Check migration history
SELECT version, name, executed_at 
FROM supabase_migrations.schema_migrations 
ORDER BY version DESC;

-- Check if our tables exist
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('notes', 'folders', 'note_folders', 'clipper_inbox', 'inbound_aliases', 'user_devices', 'note_tasks')
ORDER BY table_name;

-- Check existing indexes on notes table
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename = 'notes'
ORDER BY indexname;

-- Check existing policies
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check if metadata columns are JSONB
SELECT 
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
AND column_name LIKE '%metadata%'
ORDER BY table_name, column_name;

-- Check for our quick capture function
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'rpc_get_quick_capture_summaries';
