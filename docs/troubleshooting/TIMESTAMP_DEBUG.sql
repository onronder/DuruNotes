-- Diagnostic query to check note timestamps in Supabase
-- Run this in Supabase Dashboard → SQL Editor

-- Check your actual notes in the database
SELECT
  id,
  created_at,
  updated_at,
  -- Show if created_at and updated_at are the same
  CASE
    WHEN created_at = updated_at THEN 'NEVER_EDITED'
    ELSE 'WAS_EDITED'
  END as edit_status,
  -- Show age of note
  EXTRACT(EPOCH FROM (NOW() - created_at))/3600 as hours_old,
  -- Show actual timestamps in readable format
  created_at AT TIME ZONE 'UTC' as created_utc,
  updated_at AT TIME ZONE 'UTC' as updated_utc
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
ORDER BY created_at DESC
LIMIT 20;

-- Check if all notes have the same timestamp (THIS IS THE BUG)
SELECT
  created_at,
  updated_at,
  COUNT(*) as note_count
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
GROUP BY created_at, updated_at
ORDER BY note_count DESC;
