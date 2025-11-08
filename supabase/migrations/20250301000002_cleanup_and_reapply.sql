-- Cleanup script for trash_events migration
-- Use this if the old version was partially applied
-- Then re-run: 20250301000002_create_trash_events_audit_table.sql

-- Drop any partial state from failed migration
DROP VIEW IF EXISTS public.trash_statistics CASCADE;
DROP FUNCTION IF EXISTS public.get_trash_statistics() CASCADE;
DROP FUNCTION IF EXISTS public.log_trash_event(text, uuid, text, text, timestamptz, jsonb) CASCADE;
DROP TABLE IF EXISTS public.trash_events CASCADE;

-- Now re-run the corrected migration:
-- \i supabase/migrations/20250301000002_create_trash_events_audit_table.sql
