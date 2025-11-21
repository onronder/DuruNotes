-- ============================================================================
-- Timestamp Fix Verification Query
-- Run this in Supabase Dashboard → SQL Editor after sync completes
-- ============================================================================

-- Query 1: Check timestamp distribution
-- This should show notes with DIFFERENT timestamps if the fix worked
SELECT
  id,
  created_at AT TIME ZONE 'UTC' as created_utc,
  updated_at AT TIME ZONE 'UTC' as updated_utc,
  CASE
    WHEN ABS(EXTRACT(EPOCH FROM (created_at - updated_at))) < 2 THEN 'NEVER_EDITED'
    ELSE 'WAS_EDITED'
  END as edit_status,
  ROUND(EXTRACT(EPOCH FROM (NOW() - created_at))/86400, 1) as days_old
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
ORDER BY created_at DESC
LIMIT 20;

-- Expected: Different timestamps, not all the same!

-- Query 2: Count unique timestamps
-- If fix worked, should have multiple unique timestamp combinations
SELECT
  COUNT(*) as total_notes,
  COUNT(DISTINCT created_at) as unique_created_timestamps,
  COUNT(DISTINCT updated_at) as unique_updated_timestamps,
  CASE
    WHEN COUNT(DISTINCT created_at) > 1 THEN '✅ FIXED - Multiple creation times'
    ELSE '❌ STILL BROKEN - All same creation time'
  END as created_status,
  CASE
    WHEN COUNT(DISTINCT updated_at) > 1 THEN '✅ VARIED - Multiple update times'
    WHEN COUNT(DISTINCT updated_at) = COUNT(*) THEN '⚠️ WARNING - All different (unexpected)'
    ELSE '❌ STILL BROKEN - All same update time'
  END as updated_status
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false;

-- Query 3: Show oldest and newest notes
-- Verify timestamps span across the actual creation range
SELECT
  'OLDEST NOTE' as note_type,
  id,
  created_at,
  updated_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/86400 as days_old
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
ORDER BY created_at ASC
LIMIT 1

UNION ALL

SELECT
  'NEWEST NOTE' as note_type,
  id,
  created_at,
  updated_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/86400 as days_old
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
ORDER BY created_at DESC
LIMIT 1;

-- Expected: Oldest note should be weeks/months old, newest should be recent

-- Query 4: Verify trigger is working
-- Show notes where content changed (updated_at > created_at)
-- vs notes never edited (updated_at = created_at)
SELECT
  CASE
    WHEN ABS(EXTRACT(EPOCH FROM (created_at - updated_at))) < 2 THEN 'Never Edited'
    ELSE 'Was Edited'
  END as status,
  COUNT(*) as count
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted = false
GROUP BY status;

-- Expected: Mix of both "Never Edited" and "Was Edited" notes

-- ============================================================================
-- SUCCESS INDICATORS:
-- ============================================================================
-- ✅ Query 1: Shows notes with DIFFERENT created_at and updated_at timestamps
-- ✅ Query 2: Shows "FIXED" status for both created and updated
-- ✅ Query 3: Shows oldest note is weeks/months old, not hours old
-- ✅ Query 4: Shows mix of edited and never-edited notes
--
-- If all above pass, the timestamp bug is FIXED! 🎉
-- ============================================================================
