-- ============================================================================
-- Check for triggers that auto-update timestamps on notes table
-- ============================================================================

-- Check all triggers on the notes table
SELECT
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'notes'
  AND event_object_schema = 'public';

-- Check if there's a set_updated_at trigger or similar
SELECT
  proname as function_name,
  prosrc as function_body
FROM pg_proc
WHERE proname LIKE '%updated_at%'
   OR proname LIKE '%timestamp%'
   OR proname LIKE '%set_timestamp%';

-- Check the actual table definition for default values
SELECT
  column_name,
  column_default,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notes'
  AND column_name IN ('created_at', 'updated_at');
