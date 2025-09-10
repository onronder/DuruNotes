-- Fix Web Clipper Alias Mapping
-- This script ensures the user's alias is properly mapped in the database

-- First, check if the alias exists
SELECT 
    alias,
    user_id,
    created_at
FROM inbound_aliases 
WHERE alias = 'note_test1234';

-- Insert or update the alias mapping
-- Replace the user_id with your actual user ID if different
INSERT INTO inbound_aliases (alias, user_id, created_at) 
VALUES (
    'note_test1234', 
    '49b58975-6446-4482-bed5-5c6b0ec46675',
    NOW()
)
ON CONFLICT (alias) 
DO UPDATE SET 
    user_id = EXCLUDED.user_id,
    updated_at = NOW();

-- Verify the mapping
SELECT 
    'Alias mapping verified' as status,
    alias,
    user_id
FROM inbound_aliases 
WHERE alias = 'note_test1234';

-- Check recent clipper_inbox entries to see if clips are being saved
SELECT 
    id,
    created_at,
    source_type,
    payload_json->>'title' as title,
    payload_json->>'url' as url
FROM clipper_inbox 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
AND source_type = 'web'
ORDER BY created_at DESC 
LIMIT 5;

-- Check if there are any web clips that might have been saved with wrong user_id
SELECT 
    COUNT(*) as orphaned_clips,
    source_type
FROM clipper_inbox 
WHERE source_type = 'web'
AND user_id != '49b58975-6446-4482-bed5-5c6b0ec46675'
GROUP BY source_type;
