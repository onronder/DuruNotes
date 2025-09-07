-- Script to fix wrapped_key format issues for existing users
-- Run this in Supabase SQL Editor

-- Step 1: Check current state of user_keys
SELECT 
    user_id,
    created_at,
    CASE 
        WHEN wrapped_key::text LIKE '\\x%' THEN 'Postgres bytea hex (NEEDS FIX)'
        WHEN wrapped_key::text LIKE '\x%' THEN 'Postgres bytea hex (NEEDS FIX)'
        WHEN wrapped_key::text LIKE '[%' THEN 'JSON array (NEEDS FIX)'
        WHEN wrapped_key::text LIKE '{%' THEN 'JSON object (NEEDS FIX)'
        WHEN length(wrapped_key::text) > 0 AND wrapped_key::text ~ '^[A-Za-z0-9+/]+=*$' THEN 'Base64 (GOOD)'
        ELSE 'Unknown format'
    END as format_status,
    length(wrapped_key::text) as key_length,
    left(wrapped_key::text, 30) || '...' as key_preview
FROM user_keys
ORDER BY created_at DESC;

-- Step 2: Fix for specific user (replace USER_ID_HERE with actual user ID)
-- Uncomment and run if you need to reset a specific user:
/*
DELETE FROM user_keys 
WHERE user_id = 'USER_ID_HERE';
-- After running this, the user will need to enter their passphrase again on next login
*/

-- Step 3: Attempt automatic fix for all users with bytea format
-- Only run this if you see "NEEDS FIX" in the format_status above
/*
UPDATE user_keys
SET wrapped_key = encode(wrapped_key::bytea, 'base64')
WHERE wrapped_key::text LIKE '\\x%' 
   OR wrapped_key::text LIKE '\x%';
*/

-- Step 4: Verify the fix worked
-- Run Step 1 query again to check all keys show "Base64 (GOOD)"
