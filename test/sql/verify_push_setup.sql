-- Verify Push Notification Database Setup
-- Run these queries in your Supabase Dashboard SQL Editor

-- 1. Check if user_devices table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'user_devices'
) as table_exists;

-- 2. Check your registered devices
SELECT 
    device_id,
    platform,
    app_version,
    substring(push_token, 1, 30) || '...' as token_preview,
    created_at,
    updated_at
FROM user_devices 
WHERE user_id = auth.uid();

-- 3. Count total registered devices
SELECT COUNT(*) as total_devices
FROM user_devices
WHERE user_id = auth.uid();

-- 4. Check if the upsert function exists
SELECT EXISTS (
    SELECT FROM pg_proc
    WHERE proname = 'user_devices_upsert'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
) as function_exists;

-- 5. View table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_devices'
ORDER BY ordinal_position;
