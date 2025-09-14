-- Script to diagnose and fix cross-device sync issues
-- Run this in your Supabase SQL Editor

-- 1. Check the problematic note
SELECT 
    id,
    user_id,
    created_at,
    updated_at,
    CASE 
        WHEN title_enc IS NOT NULL THEN 'Encrypted'
        ELSE 'Not encrypted'
    END as title_status,
    CASE 
        WHEN content_enc IS NOT NULL THEN 'Encrypted'
        ELSE 'Not encrypted'
    END as content_status,
    left(encode(title_enc, 'escape'), 50) as title_preview
FROM notes
WHERE id = 'f9cb5286-28a7-4c8d-8570-78088b420483';

-- 2. Check user_keys for both devices
SELECT 
    user_id,
    created_at,
    updated_at,
    CASE 
        WHEN wrapped_key::text LIKE '\\x%' THEN 'Postgres bytea hex (OLD FORMAT - NEEDS FIX)'
        WHEN wrapped_key::text LIKE '\x%' THEN 'Postgres bytea hex (OLD FORMAT - NEEDS FIX)' 
        WHEN wrapped_key::text LIKE '[%' THEN 'JSON array (OLD FORMAT)'
        WHEN wrapped_key::text LIKE '{%' THEN 'JSON object (OLD FORMAT)'
        WHEN length(wrapped_key::text) > 0 AND wrapped_key::text ~ '^[A-Za-z0-9+/]+=*$' THEN 'Base64 (GOOD)'
        ELSE 'Unknown format'
    END as key_format,
    left(wrapped_key::text, 50) as key_preview
FROM user_keys
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- 3. FIX OPTION 1: Delete the problematic note (easiest)
-- Uncomment to run:
/*
DELETE FROM notes 
WHERE id = 'f9cb5286-28a7-4c8d-8570-78088b420483';
*/

-- 4. FIX OPTION 2: Fix the wrapped_key format if needed
-- Uncomment to run:
/*
UPDATE user_keys
SET wrapped_key = encode(wrapped_key::bytea, 'base64')
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
  AND (wrapped_key::text LIKE '\\x%' OR wrapped_key::text LIKE '\x%');
*/

-- 5. FIX OPTION 3: Reset user's encryption completely (nuclear option)
-- This will require re-entering passphrase on all devices
-- Uncomment to run:
/*
DELETE FROM user_keys WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
DELETE FROM notes WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
*/
