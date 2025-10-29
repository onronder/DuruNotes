-- =====================================================
-- Find Actual Function Signatures
-- =====================================================
-- This query will show all functions that need search_path fixed
-- with their ACTUAL signatures from your database
-- =====================================================

SELECT
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as actual_signature,
    n.nspname as schema,
    CASE
        WHEN p.proconfig IS NULL THEN '⚠️  Needs fixing'
        WHEN 'search_path' = ANY(
            SELECT split_part(unnest(p.proconfig), '=', 1)
        ) THEN '✅ Already fixed'
        ELSE '⚠️  Needs fixing'
    END as status,
    -- Generate the correct ALTER FUNCTION statement
    format(
        'ALTER FUNCTION %I.%I(%s) SET search_path = '''';',
        n.nspname,
        p.proname,
        pg_get_function_identity_arguments(p.oid)
    ) as fix_statement
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    '_policy_exists',
    'verify_jwt_claims',
    'validate_email',
    'validate_url',
    'validate_uuid',
    'sanitize_text',
    'get_unread_inbox_count',
    'mark_inbox_item_read',
    'log_encryption_key_operation',
    'update_user_encryption_keys_updated_at',
    'cleanup_old_login_attempts',
    'touch_user_keys_updated_at',
    'purge_stale_clipper_inbox',
    'extract_message_id',
    'get_template_stats',
    'test_notification_processor',
    'process_notifications_now',
    'update_updated_at_column',
    'copy_template',
    'update_template_updated_at',
    'update_notification_updated_at',
    'manual_process_notifications',
    'update_clipper_inbox_updated_at',
    'get_template_count',
    'get_user_templates',
    'merge_duplicate_folders',
    'sync_notes_encryption',
    'test_edge_function_call',
    'search_clipper_inbox_metadata',
    'get_inbox_with_attachments',
    'send_push_notification_immediate',
    'sync_tasks_encryption',
    'validate_schema_compatibility',
    'rollback_schema_compatibility',
    'process_notification_queue_internal',
    'cleanup_old_rate_limits',
    'convert_email_to_note',
    'cleanup_old_inbox_items',
    'jsonb_set_attachments',
    'enforce_user_id',
    'touch_updated_at',
    'set_auth_user_id',
    'check_clipper_inbox_health',
    'update_inbox_attachments',
    'test_fcm_notification_v2'
  )
ORDER BY function_name;

-- =====================================================
-- Count Summary
-- =====================================================

SELECT
    COUNT(*) as total_functions_found,
    COUNT(*) FILTER (WHERE status = '⚠️  Needs fixing') as needs_fixing,
    COUNT(*) FILTER (WHERE status = '✅ Already fixed') as already_fixed
FROM (
    SELECT
        p.proname,
        CASE
            WHEN p.proconfig IS NULL THEN '⚠️  Needs fixing'
            WHEN 'search_path' = ANY(
                SELECT split_part(unnest(p.proconfig), '=', 1)
            ) THEN '✅ Already fixed'
            ELSE '⚠️  Needs fixing'
        END as status
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        '_policy_exists',
        'verify_jwt_claims',
        'validate_email',
        'validate_url',
        'validate_uuid',
        'sanitize_text',
        'get_unread_inbox_count',
        'mark_inbox_item_read',
        'log_encryption_key_operation',
        'update_user_encryption_keys_updated_at',
        'cleanup_old_login_attempts',
        'touch_user_keys_updated_at',
        'purge_stale_clipper_inbox',
        'extract_message_id',
        'get_template_stats',
        'test_notification_processor',
        'process_notifications_now',
        'update_updated_at_column',
        'copy_template',
        'update_template_updated_at',
        'update_notification_updated_at',
        'manual_process_notifications',
        'update_clipper_inbox_updated_at',
        'get_template_count',
        'get_user_templates',
        'merge_duplicate_folders',
        'sync_notes_encryption',
        'test_edge_function_call',
        'search_clipper_inbox_metadata',
        'get_inbox_with_attachments',
        'send_push_notification_immediate',
        'sync_tasks_encryption',
        'validate_schema_compatibility',
        'rollback_schema_compatibility',
        'process_notification_queue_internal',
        'cleanup_old_rate_limits',
        'convert_email_to_note',
        'cleanup_old_inbox_items',
        'jsonb_set_attachments',
        'enforce_user_id',
        'touch_updated_at',
        'set_auth_user_id',
        'check_clipper_inbox_health',
        'update_inbox_attachments',
        'test_fcm_notification_v2'
      )
) subquery;
