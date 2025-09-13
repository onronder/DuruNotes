-- =====================================================
-- Production Improvements for Notification System
-- =====================================================

-- 1. Atomic Claim Function with FOR UPDATE SKIP LOCKED
CREATE OR REPLACE FUNCTION public.claim_notification_events(
    batch_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    event_type TEXT,
    event_source TEXT,
    priority TEXT,
    payload JSONB,
    scheduled_for TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    status TEXT,
    retry_count INTEGER,
    max_retries INTEGER,
    dedupe_key TEXT,
    error_message TEXT,
    error_details JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    notification_templates JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Atomically claim and update events to processing status
    -- This prevents concurrent workers from processing the same events
    RETURN QUERY
    WITH claimed AS (
        SELECT ne.id
        FROM notification_events ne
        WHERE ne.status = 'pending'
          AND ne.scheduled_for <= now()
        ORDER BY ne.priority DESC, ne.scheduled_for ASC
        LIMIT batch_limit
        FOR UPDATE SKIP LOCKED
    ),
    updated AS (
        UPDATE notification_events ne
        SET status = 'processing',
            processed_at = now(),
            updated_at = now()
        FROM claimed
        WHERE ne.id = claimed.id
        RETURNING ne.*
    )
    SELECT 
        u.*,
        row_to_json(nt.*)::jsonb as notification_templates
    FROM updated u
    LEFT JOIN notification_templates nt ON nt.event_type = u.event_type;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.claim_notification_events TO service_role;

-- =====================================================
-- 2. Database Triggers for Missing Event Types
-- =====================================================

-- Function to create reminder notification events
CREATE OR REPLACE FUNCTION public.trigger_reminder_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only trigger for reminders that are due in the future
    IF NEW.reminder_time > now() THEN
        -- Create notification event scheduled for reminder time
        PERFORM create_notification_event(
            NEW.user_id,
            'reminder_due',
            'reminder',
            jsonb_build_object(
                'reminder_id', NEW.id,
                'note_id', NEW.note_id,
                'title', COALESCE(NEW.title, 'Reminder'),
                'message', NEW.message,
                'reminder_time', NEW.reminder_time
            ),
            'high',
            NEW.reminder_time,
            'reminder_' || NEW.id::text
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger for reminders (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reminders') THEN
        DROP TRIGGER IF EXISTS reminder_notification_trigger ON public.reminders;
        CREATE TRIGGER reminder_notification_trigger
            AFTER INSERT OR UPDATE OF reminder_time ON public.reminders
            FOR EACH ROW
            WHEN (NEW.status = 'active')
            EXECUTE FUNCTION trigger_reminder_notification();
    END IF;
END $$;

-- Function to create note share notification events
CREATE OR REPLACE FUNCTION public.trigger_share_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sharer_name TEXT;
    v_note_title TEXT;
BEGIN
    -- Get sharer name (if available)
    SELECT email INTO v_sharer_name
    FROM auth.users
    WHERE id = NEW.shared_by
    LIMIT 1;
    
    -- Get note title (if notes table exists and has title)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes') THEN
        EXECUTE format('SELECT title FROM notes WHERE id = $1 LIMIT 1')
        INTO v_note_title
        USING NEW.note_id;
    END IF;
    
    -- Create notification for the recipient
    PERFORM create_notification_event(
        NEW.shared_with,
        'note_shared',
        'share',
        jsonb_build_object(
            'share_id', NEW.id,
            'note_id', NEW.note_id,
            'sharer_id', NEW.shared_by,
            'sharer_name', COALESCE(v_sharer_name, 'Someone'),
            'note_title', COALESCE(v_note_title, 'a note'),
            'permission', NEW.permission
        ),
        'high',
        now(),
        'share_' || NEW.id::text
    );
    
    RETURN NEW;
END;
$$;

-- Create trigger for note shares (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_shares') THEN
        DROP TRIGGER IF EXISTS share_notification_trigger ON public.note_shares;
        CREATE TRIGGER share_notification_trigger
            AFTER INSERT ON public.note_shares
            FOR EACH ROW
            EXECUTE FUNCTION trigger_share_notification();
    END IF;
END $$;

-- Function to create folder share notification events
CREATE OR REPLACE FUNCTION public.trigger_folder_share_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sharer_name TEXT;
    v_folder_name TEXT;
BEGIN
    -- Get sharer name
    SELECT email INTO v_sharer_name
    FROM auth.users
    WHERE id = NEW.shared_by
    LIMIT 1;
    
    -- Get folder name (if folders table exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'folders') THEN
        EXECUTE format('SELECT name FROM folders WHERE id = $1 LIMIT 1')
        INTO v_folder_name
        USING NEW.folder_id;
    END IF;
    
    -- Create notification for the recipient
    PERFORM create_notification_event(
        NEW.shared_with,
        'folder_shared',
        'share',
        jsonb_build_object(
            'share_id', NEW.id,
            'folder_id', NEW.folder_id,
            'sharer_id', NEW.shared_by,
            'sharer_name', COALESCE(v_sharer_name, 'Someone'),
            'folder_name', COALESCE(v_folder_name, 'a folder'),
            'permission', NEW.permission
        ),
        'high',
        now(),
        'folder_share_' || NEW.id::text
    );
    
    RETURN NEW;
END;
$$;

-- Create trigger for folder shares (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'folder_shares') THEN
        DROP TRIGGER IF EXISTS folder_share_notification_trigger ON public.folder_shares;
        CREATE TRIGGER folder_share_notification_trigger
            AFTER INSERT ON public.folder_shares
            FOR EACH ROW
            EXECUTE FUNCTION trigger_folder_share_notification();
    END IF;
END $$;

-- =====================================================
-- 3. Stale Token Cleanup Job
-- =====================================================

-- Drop existing function if it has different signature
DROP FUNCTION IF EXISTS public.cleanup_stale_device_tokens(INTEGER);

-- Enhanced cleanup function with better reporting
CREATE OR REPLACE FUNCTION public.cleanup_stale_device_tokens(
    p_days_old INTEGER DEFAULT 90
)
RETURNS TABLE (
    deleted_count INTEGER,
    oldest_deleted TIMESTAMPTZ,
    users_affected INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted_count INTEGER;
    v_oldest TIMESTAMPTZ;
    v_users INTEGER;
BEGIN
    -- Get stats before deletion
    SELECT MIN(updated_at), COUNT(DISTINCT user_id)
    INTO v_oldest, v_users
    FROM public.user_devices
    WHERE updated_at < (now() - (p_days_old || ' days')::INTERVAL);
    
    -- Delete stale tokens
    DELETE FROM public.user_devices
    WHERE updated_at < (now() - (p_days_old || ' days')::INTERVAL);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN QUERY SELECT v_deleted_count, v_oldest, v_users;
END;
$$;

-- =====================================================
-- 4. Analytics Functions
-- =====================================================

-- Function to get notification metrics
CREATE OR REPLACE FUNCTION public.get_notification_metrics(
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    total_events INTEGER,
    delivered INTEGER,
    failed INTEGER,
    pending INTEGER,
    cancelled INTEGER,
    delivery_rate NUMERIC,
    avg_retry_count NUMERIC,
    events_per_hour NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_events,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END)::INTEGER as delivered,
        COUNT(CASE WHEN status = 'failed' THEN 1 END)::INTEGER as failed,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled,
        ROUND(
            COUNT(CASE WHEN status = 'delivered' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN status IN ('delivered', 'failed') THEN 1 END), 0) * 100, 
            2
        ) as delivery_rate,
        ROUND(AVG(retry_count), 2) as avg_retry_count,
        ROUND(COUNT(*)::NUMERIC / NULLIF(p_hours, 0), 2) as events_per_hour
    FROM notification_events
    WHERE created_at >= (now() - (p_hours || ' hours')::INTERVAL);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.cleanup_stale_device_tokens TO service_role;
GRANT EXECUTE ON FUNCTION public.get_notification_metrics TO authenticated;

-- =====================================================
-- 5. Add Missing Templates
-- =====================================================

-- Insert templates for new event types (if not exists)
INSERT INTO public.notification_templates (event_type, push_template, priority) 
VALUES
    ('reminder_due', '{"title": "Reminder: {{title}}", "body": "{{message}}", "icon": "bell", "sound": "reminder", "badge": 1}', 'critical'),
    ('note_shared', '{"title": "Note Shared", "body": "{{sharer_name}} shared \"{{note_title}}\" with you", "icon": "share", "sound": "default", "badge": 1}', 'high'),
    ('folder_shared', '{"title": "Folder Shared", "body": "{{sharer_name}} shared {{folder_name}} with you", "icon": "folder", "sound": "default", "badge": 1}', 'high'),
    ('sync_conflict', '{"title": "Sync Conflict", "body": "Conflict detected in {{note_title}}", "icon": "warning", "sound": "default"}', 'normal'),
    ('comment_added', '{"title": "New Comment", "body": "{{user_name}} commented on {{note_title}}", "icon": "comment", "sound": "default", "badge": 1}', 'normal'),
    ('note_mentioned', '{"title": "You were mentioned", "body": "{{user_name}} mentioned you in {{note_title}}", "icon": "mention", "sound": "default", "badge": 1}', 'high'),
    ('account_security', '{"title": "Security Alert", "body": "{{message}}", "icon": "security", "sound": "alert"}', 'critical'),
    ('subscription_update', '{"title": "Subscription Update", "body": "{{message}}", "icon": "info", "sound": "default"}', 'normal'),
    ('feature_announcement', '{"title": "New Feature", "body": "{{message}}", "icon": "star", "sound": "default"}', 'low')
ON CONFLICT (event_type) DO UPDATE
SET 
    push_template = EXCLUDED.push_template,
    priority = EXCLUDED.priority,
    updated_at = now();

-- =====================================================
-- 6. Indexes for Performance
-- =====================================================

-- Add index for concurrent processing
CREATE INDEX IF NOT EXISTS idx_notification_events_processing 
    ON public.notification_events(status, scheduled_for, priority DESC)
    WHERE status IN ('pending', 'processing');

-- Add index for user lookups
CREATE INDEX IF NOT EXISTS idx_notification_events_user_status 
    ON public.notification_events(user_id, status, created_at DESC);

-- Add index for analytics
CREATE INDEX IF NOT EXISTS idx_notification_events_created_status 
    ON public.notification_events(created_at, status);

-- =====================================================
-- 7. Comments for Documentation
-- =====================================================

COMMENT ON FUNCTION public.claim_notification_events IS 'Atomically claim notification events for processing with concurrency control';
COMMENT ON FUNCTION public.trigger_reminder_notification IS 'Create notification events for reminders';
COMMENT ON FUNCTION public.trigger_share_notification IS 'Create notification events for note shares';
COMMENT ON FUNCTION public.trigger_folder_share_notification IS 'Create notification events for folder shares';
COMMENT ON FUNCTION public.get_notification_metrics IS 'Get notification delivery metrics for monitoring';
