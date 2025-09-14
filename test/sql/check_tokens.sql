-- Check if user has registered push tokens
SELECT 
    id,
    user_id,
    platform,
    environment,
    created_at,
    last_used_at,
    SUBSTRING(token, 1, 20) || '...' as token_preview
FROM push_tokens
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 5;
