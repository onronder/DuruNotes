-- Complete fix for cross-device sync issues
-- Run these queries in order in Supabase SQL Editor

-- 1. First, let's see the current state
SELECT 
    'Current Notes:' as info;
    
SELECT 
    id,
    user_id,
    created_at,
    updated_at,
    CASE 
        WHEN title_enc IS NOT NULL THEN 'Encrypted'
        ELSE 'Not encrypted'
    END as encryption_status
FROM notes
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
ORDER BY created_at DESC;

-- 2. Check the user_keys status
SELECT 
    'Current User Keys:' as info;
    
SELECT 
    user_id,
    created_at,
    updated_at,
    CASE 
        WHEN wrapped_key::text ~ '^[A-Za-z0-9+/]+=*$' THEN 'Base64 (GOOD)'
        WHEN wrapped_key::text LIKE '\\x%' THEN 'Bytea Hex (BAD - NEEDS FIX)'
        WHEN wrapped_key::text LIKE '\x%' THEN 'Bytea Hex (BAD - NEEDS FIX)'
        ELSE 'Unknown format'
    END as key_format,
    left(wrapped_key::text, 50) as key_preview
FROM user_keys
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- ====================================
-- FIX: Complete Reset (Recommended)
-- ====================================
-- This will clear everything and let you start fresh
-- Uncomment the lines below to run:

/*
-- Step 1: Delete all notes (they're encrypted with incompatible keys)
DELETE FROM notes 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- Step 2: Delete the user's encryption key to force fresh setup
DELETE FROM user_keys 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- Step 3: Verify everything is cleared
SELECT 'Cleanup complete. Notes deleted:' as status, 
       COUNT(*) as count 
FROM notes 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
*/

-- After running this SQL, follow these steps on BOTH devices:
-- 1. Force quit the app completely
-- 2. Open the app
-- 3. Sign out
-- 4. Sign in again - it SHOULD ask for passphrase
-- 5. Enter the SAME passphrase on both devices
-- 6. Create new notes - they will sync properly
