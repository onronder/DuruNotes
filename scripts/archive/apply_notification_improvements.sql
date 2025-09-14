-- Apply notification improvements directly
-- This script applies the improvements to the existing notification system

-- 1. Atomic Claim Function
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

GRANT EXECUTE ON FUNCTION public.claim_notification_events TO service_role;

-- 2. Notification Metrics Function
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

GRANT EXECUTE ON FUNCTION public.get_notification_metrics TO authenticated;

-- 3. Add missing notification templates
INSERT INTO public.notification_templates (event_type, push_template, priority) 
VALUES
    ('reminder_due', '{"title": "Reminder: {{title}}", "body": "{{message}}", "icon": "bell", "sound": "reminder", "badge": 1}', 'critical'),
    ('note_shared', '{"title": "Note Shared", "body": "{{sharer_name}} shared \"{{note_title}}\" with you", "icon": "share", "sound": "default", "badge": 1}', 'high'),
    ('folder_shared', '{"title": "Folder Shared", "body": "{{sharer_name}} shared {{folder_name}} with you", "icon": "folder", "sound": "default", "badge": 1}', 'high')
ON CONFLICT (event_type) DO UPDATE
SET 
    push_template = EXCLUDED.push_template,
    priority = EXCLUDED.priority,
    updated_at = now();

-- 4. Add performance indexes
CREATE INDEX IF NOT EXISTS idx_notification_events_processing 
    ON public.notification_events(status, scheduled_for, priority DESC)
    WHERE status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS idx_notification_events_user_status 
    ON public.notification_events(user_id, status, created_at DESC);

-- 5. Manual trigger function for testing
CREATE OR REPLACE FUNCTION public.manual_process_notifications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Note: This is a simplified version for testing
    -- In production, this would call the Edge Function
    result := jsonb_build_object(
        'status', 'queued',
        'message', 'Notification processing triggered manually',
        'timestamp', now()
    );
    
    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manual_process_notifications TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Notification improvements applied successfully!';
END $$;
