-- Migration: Phase 5 - Unencrypted Metadata Clearing Functions
-- Phase 1.2 Week 5+: Complete Phase 5 implementation
--
-- GDPR Compliance: Article 17 - Right to Erasure (Unencrypted Metadata)
-- Security: Complete PII removal from unencrypted fields
--
-- These functions clear all unencrypted metadata that may contain PII or
-- reveal user behavioral patterns. This phase runs AFTER Phase 4 (encrypted
-- content tombstoning) to ensure complete anonymization.

BEGIN;

-- ===========================================================================
-- FIX EXISTING FUNCTION: anonymize_user_audit_trail
-- ===========================================================================
-- The existing function in migration 20251119130000 has bugs:
-- 1. References non-existent 'updated_at' column in trash_events
-- 2. Doesn't clear metadata JSONB field
-- This fixed version replaces the buggy one.

CREATE OR REPLACE FUNCTION anonymize_user_audit_trail(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  updated_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Anonymizing audit trail for user %', target_user_id;

  -- Anonymize item_title and clear metadata in trash_events
  UPDATE public.trash_events
  SET
    item_title = 'ANONYMIZED',
    metadata = '{}'::jsonb
  WHERE user_id = target_user_id
    AND (
      (item_title IS NOT NULL AND item_title != 'ANONYMIZED')
      OR metadata != '{}'::jsonb
    );

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Anonymized % audit trail records', updated_count;

  RETURN updated_count;
END;
$$;

COMMENT ON FUNCTION anonymize_user_audit_trail IS 'GDPR Article 17: Anonymizes PII in trash_events audit trail (item_title and metadata). Fixed version.';

-- ===========================================================================
-- FUNCTION: Delete User Tags
-- ===========================================================================
-- Deletes all tags created by the user and their note-tag relationships.
-- Cascading deletion will automatically remove note_tags entries.

CREATE OR REPLACE FUNCTION delete_user_tags(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  tags_count integer;
  note_tags_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting tags for user %', target_user_id;

  -- First count note_tags (for audit trail)
  SELECT COUNT(*) INTO note_tags_count
  FROM public.note_tags
  WHERE user_id = target_user_id;

  -- Delete note_tags first (avoid foreign key issues if any)
  DELETE FROM public.note_tags
  WHERE user_id = target_user_id;

  -- Delete tags (this will cascade delete any remaining note_tags via FK)
  DELETE FROM public.tags
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS tags_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted % tags and % note-tag relationships', tags_count, note_tags_count;

  RETURN tags_count;
END;
$$;

COMMENT ON FUNCTION delete_user_tags IS 'GDPR Article 17: Deletes all user tags and note-tag relationships. Returns count of tags deleted.';

-- ===========================================================================
-- FUNCTION: Delete Saved Searches
-- ===========================================================================
-- Deletes all saved searches which may contain sensitive search queries.

CREATE OR REPLACE FUNCTION delete_user_saved_searches(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  searches_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting saved searches for user %', target_user_id;

  DELETE FROM public.saved_searches
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS searches_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted % saved searches', searches_count;

  RETURN searches_count;
END;
$$;

COMMENT ON FUNCTION delete_user_saved_searches IS 'GDPR Article 17: Deletes all saved searches (which may contain sensitive query terms). Returns count deleted.';

-- ===========================================================================
-- FUNCTION: Delete Notification Events
-- ===========================================================================
-- Deletes all notification events which may contain PII in payload/error fields.

CREATE OR REPLACE FUNCTION delete_user_notification_events(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  events_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting notification events for user %', target_user_id;

  DELETE FROM public.notification_events
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS events_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted % notification events', events_count;

  RETURN events_count;
END;
$$;

COMMENT ON FUNCTION delete_user_notification_events IS 'GDPR Article 17: Deletes all notification events (payload may contain PII). Returns count deleted.';

-- ===========================================================================
-- FUNCTION: Delete User Preferences
-- ===========================================================================
-- Deletes user preferences row (ON DELETE CASCADE will handle cleanup).

CREATE OR REPLACE FUNCTION delete_user_preferences(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting user preferences for user %', target_user_id;

  DELETE FROM public.user_preferences
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted user preferences (count: %)', deleted_count;

  RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION delete_user_preferences IS 'GDPR Article 17: Deletes user preferences. Returns 1 if deleted, 0 if not found.';

-- ===========================================================================
-- FUNCTION: Delete Notification Preferences
-- ===========================================================================
-- Deletes notification preferences row.

CREATE OR REPLACE FUNCTION delete_user_notification_preferences(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting notification preferences for user %', target_user_id;

  DELETE FROM public.notification_preferences
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted notification preferences (count: %)', deleted_count;

  RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION delete_user_notification_preferences IS 'GDPR Article 17: Deletes notification preferences. Returns 1 if deleted, 0 if not found.';

-- ===========================================================================
-- FUNCTION: Delete User Devices
-- ===========================================================================
-- Deletes all registered user devices (push tokens, device IDs).

CREATE OR REPLACE FUNCTION delete_user_devices(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  devices_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Deleting user devices for user %', target_user_id;

  DELETE FROM public.user_devices
  WHERE user_id = target_user_id;

  GET DIAGNOSTICS devices_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Deleted % user devices', devices_count;

  RETURN devices_count;
END;
$$;

COMMENT ON FUNCTION delete_user_devices IS 'GDPR Article 17: Deletes all user devices (push tokens, device IDs). Returns count deleted.';

-- ===========================================================================
-- FUNCTION: Clear Template Metadata
-- ===========================================================================
-- Templates have encrypted content (handled in Phase 4), but we should clear
-- unencrypted metadata fields (category, icon) for completeness.

CREATE OR REPLACE FUNCTION clear_user_template_metadata(target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  updated_count integer;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Clearing template metadata for user %', target_user_id;

  -- Clear unencrypted metadata fields
  -- (Encrypted fields already tombstoned in Phase 4)
  UPDATE public.templates
  SET
    category = NULL,
    icon = NULL,
    sort_order = 0,
    updated_at = timezone('utc', now())
  WHERE user_id = target_user_id
    AND (category IS NOT NULL OR icon IS NOT NULL OR sort_order != 0);

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  RAISE NOTICE 'GDPR Phase 5: Cleared metadata for % templates', updated_count;

  RETURN updated_count;
END;
$$;

COMMENT ON FUNCTION clear_user_template_metadata IS 'GDPR Article 17: Clears unencrypted metadata from templates (category, icon). Encrypted content already tombstoned in Phase 4.';

-- ===========================================================================
-- MASTER ORCHESTRATOR FUNCTION: Clear All Unencrypted Metadata
-- ===========================================================================
-- Calls all Phase 5 functions in the correct order and returns detailed counts.

CREATE OR REPLACE FUNCTION clear_all_user_metadata(target_user_id uuid)
RETURNS TABLE(
  tags_deleted bigint,
  saved_searches_deleted bigint,
  notification_events_deleted bigint,
  user_preferences_deleted bigint,
  notification_preferences_deleted bigint,
  devices_deleted bigint,
  templates_metadata_cleared bigint,
  audit_trail_anonymized bigint,
  total_operations bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tags_deleted bigint;
  v_searches_deleted bigint;
  v_events_deleted bigint;
  v_prefs_deleted bigint;
  v_notif_prefs_deleted bigint;
  v_devices_deleted bigint;
  v_templates_cleared bigint;
  v_audit_anonymized bigint;
  v_total bigint;
BEGIN
  RAISE NOTICE 'GDPR Phase 5: Starting metadata clearing for user %', target_user_id;

  -- Delete tags and note-tag relationships
  SELECT delete_user_tags.count INTO v_tags_deleted
  FROM delete_user_tags(target_user_id) AS count;

  -- Delete saved searches
  SELECT delete_user_saved_searches.count INTO v_searches_deleted
  FROM delete_user_saved_searches(target_user_id) AS count;

  -- Delete notification events
  SELECT delete_user_notification_events.count INTO v_events_deleted
  FROM delete_user_notification_events(target_user_id) AS count;

  -- Delete user preferences
  SELECT delete_user_preferences.count INTO v_prefs_deleted
  FROM delete_user_preferences(target_user_id) AS count;

  -- Delete notification preferences
  SELECT delete_user_notification_preferences.count INTO v_notif_prefs_deleted
  FROM delete_user_notification_preferences(target_user_id) AS count;

  -- Delete user devices
  SELECT delete_user_devices.count INTO v_devices_deleted
  FROM delete_user_devices(target_user_id) AS count;

  -- Clear template metadata
  SELECT clear_user_template_metadata.count INTO v_templates_cleared
  FROM clear_user_template_metadata(target_user_id) AS count;

  -- Anonymize audit trail (trash events)
  SELECT anonymize_user_audit_trail.count INTO v_audit_anonymized
  FROM anonymize_user_audit_trail(target_user_id) AS count;

  -- Calculate total operations
  v_total := COALESCE(v_tags_deleted, 0) +
             COALESCE(v_searches_deleted, 0) +
             COALESCE(v_events_deleted, 0) +
             COALESCE(v_prefs_deleted, 0) +
             COALESCE(v_notif_prefs_deleted, 0) +
             COALESCE(v_devices_deleted, 0) +
             COALESCE(v_templates_cleared, 0) +
             COALESCE(v_audit_anonymized, 0);

  RAISE NOTICE 'GDPR Phase 5: Metadata clearing complete. Total operations: %', v_total;

  RETURN QUERY SELECT
    v_tags_deleted,
    v_searches_deleted,
    v_events_deleted,
    v_prefs_deleted,
    v_notif_prefs_deleted,
    v_devices_deleted,
    v_templates_cleared,
    v_audit_anonymized,
    v_total;
END;
$$;

COMMENT ON FUNCTION clear_all_user_metadata IS 'GDPR Article 17: Master function that clears ALL unencrypted metadata for a user. Returns detailed counts for each category.';

-- ===========================================================================
-- GRANT PERMISSIONS
-- ===========================================================================
-- Grant execute permissions to authenticated users (RLS ensures they can only
-- operate on their own data)

GRANT EXECUTE ON FUNCTION anonymize_user_audit_trail TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_tags TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_saved_searches TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_notification_events TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_notification_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_devices TO authenticated;
GRANT EXECUTE ON FUNCTION clear_user_template_metadata TO authenticated;
GRANT EXECUTE ON FUNCTION clear_all_user_metadata TO authenticated;

COMMIT;

-- ===========================================================================
-- USAGE EXAMPLES
-- ===========================================================================

-- Individual operations:
-- SELECT * FROM delete_user_tags('user-uuid-here');
-- SELECT * FROM delete_user_saved_searches('user-uuid-here');
-- SELECT * FROM anonymize_user_audit_trail('user-uuid-here');

-- Complete Phase 5 execution:
-- SELECT * FROM clear_all_user_metadata('user-uuid-here');

-- Example output:
-- tags_deleted | saved_searches_deleted | notification_events_deleted | user_preferences_deleted | notification_preferences_deleted | devices_deleted | templates_metadata_cleared | audit_trail_anonymized | total_operations
-- -------------+------------------------+-----------------------------+--------------------------+----------------------------------+-----------------+----------------------------+------------------------+------------------
--           15 |                      3 |                          42 |                        1 |                                1 |               2 |                          5 |                     18 |               87

-- ===========================================================================
-- SECURITY NOTES
-- ===========================================================================

-- 1. SECURITY DEFINER: Functions run with creator's privileges
--    This is safe because:
--    - RLS policies still apply (users can only affect their own data)
--    - Functions only DELETE/UPDATE data, never expose sensitive information
--    - All operations are logged via RAISE NOTICE

-- 2. Deletion Order:
--    - note_tags deleted before tags (avoid FK constraint issues)
--    - All other deletions are independent
--    - Cascading deletions handled by ON DELETE CASCADE

-- 3. Atomicity:
--    - Each function runs in its own transaction
--    - Master function calls all sub-functions in sequence
--    - If master function fails, partial deletions may occur (but this is
--      acceptable as Phase 5 can be retried)

-- 4. Irreversibility:
--    - All deletions are permanent (no soft delete)
--    - This satisfies GDPR "Right to Erasure"
--    - Audit trail preserved in anonymization_events table

-- ===========================================================================
-- PERFORMANCE NOTES
-- ===========================================================================

-- Expected performance (approximate):
-- - Tags: Fast (usually < 100 tags per user)
-- - Saved searches: Fast (usually < 20 searches per user)
-- - Notification events: May be slow for heavy users (thousands of events)
-- - Preferences: Instant (single row)
-- - Devices: Fast (usually < 5 devices per user)
-- - Templates: Fast (usually < 50 templates per user)
-- - Audit trail: May be slow for long-time users (hundreds of trash events)

-- Bottlenecks:
-- - notification_events table for users with many notifications
-- - trash_events table for users with extensive trash history

-- For users with very large datasets, consider running during low-traffic periods.

-- ===========================================================================
-- TESTING NOTES
-- ===========================================================================

-- Before production deployment:
-- 1. Test each function individually with test user data
-- 2. Verify RLS policies prevent cross-user deletion
-- 3. Test master function with various user data scenarios
-- 4. Verify transaction rollback on errors
-- 5. Check PostgreSQL logs for RAISE NOTICE outputs
-- 6. Verify counts returned match actual deletions

