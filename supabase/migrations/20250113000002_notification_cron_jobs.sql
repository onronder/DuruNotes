-- =====================================================
-- Automated Cron Jobs for Push Notification System
-- =====================================================

-- Ensure pg_cron extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres user
GRANT USAGE ON SCHEMA cron TO postgres;

-- =====================================================
-- 1. Process Notification Queue (Every 2 Minutes)
-- =====================================================

-- Unschedule if exists
SELECT cron.unschedule('process-notification-queue') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'process-notification-queue'
);

-- Schedule notification processing every 2 minutes
SELECT cron.schedule(
    'process-notification-queue',
    '*/2 * * * *', -- Every 2 minutes
    $$
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'batch_size', 50
        )
    ) AS request_id;
    $$
);

-- =====================================================
-- 2. Retry Stuck Notifications (Every 10 Minutes)
-- =====================================================

-- Unschedule if exists
SELECT cron.unschedule('retry-stuck-notifications') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'retry-stuck-notifications'
);

-- Reset stuck notifications every 10 minutes
SELECT cron.schedule(
    'retry-stuck-notifications',
    '*/10 * * * *', -- Every 10 minutes
    $$
    UPDATE notification_events
    SET status = 'pending',
        processed_at = NULL,
        error_message = 'Reset from stuck processing state'
    WHERE status = 'processing'
      AND processed_at < NOW() - INTERVAL '5 minutes';
    $$
);

-- =====================================================
-- 3. Clean Up Old Notifications (Daily at 3 AM)
-- =====================================================

-- Unschedule if exists
SELECT cron.unschedule('cleanup-old-notifications') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-old-notifications'
);

-- Clean up old notifications daily
SELECT cron.schedule(
    'cleanup-old-notifications',
    '0 3 * * *', -- Daily at 3:00 AM
    $$
    DELETE FROM notification_events
    WHERE created_at < NOW() - INTERVAL '30 days'
      AND status IN ('delivered', 'failed', 'cancelled');
    $$
);

-- =====================================================
-- 4. Clean Up Stale Device Tokens (Weekly)
-- =====================================================

-- Unschedule if exists
SELECT cron.unschedule('cleanup-stale-tokens') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-stale-tokens'
);

-- Clean up stale device tokens weekly
SELECT cron.schedule(
    'cleanup-stale-tokens',
    '0 4 * * 0', -- Sunday at 4:00 AM
    $$
    SELECT cleanup_stale_device_tokens(90);
    $$
);

-- =====================================================
-- 5. Generate Daily Analytics (Daily at 1 AM)
-- =====================================================

-- Create analytics table if not exists
CREATE TABLE IF NOT EXISTS public.notification_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL,
    metrics JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(date)
);

-- Unschedule if exists
SELECT cron.unschedule('generate-notification-analytics') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'generate-notification-analytics'
);

-- Generate daily analytics
SELECT cron.schedule(
    'generate-notification-analytics',
    '0 1 * * *', -- Daily at 1:00 AM
    $$
    INSERT INTO notification_analytics (date, metrics)
    SELECT 
        CURRENT_DATE - INTERVAL '1 day',
        jsonb_build_object(
            'total_events', COUNT(*),
            'delivered', COUNT(CASE WHEN status = 'delivered' THEN 1 END),
            'failed', COUNT(CASE WHEN status = 'failed' THEN 1 END),
            'cancelled', COUNT(CASE WHEN status = 'cancelled' THEN 1 END),
            'delivery_rate', ROUND(
                COUNT(CASE WHEN status = 'delivered' THEN 1 END)::NUMERIC / 
                NULLIF(COUNT(CASE WHEN status IN ('delivered', 'failed') THEN 1 END), 0) * 100, 
                2
            ),
            'by_type', jsonb_object_agg(
                event_type,
                jsonb_build_object(
                    'count', type_counts.count,
                    'delivered', type_counts.delivered
                )
            ),
            'by_hour', jsonb_object_agg(
                hour::text,
                hour_counts.count
            )
        )
    FROM notification_events ne
    CROSS JOIN LATERAL (
        SELECT 
            event_type,
            COUNT(*) as count,
            COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered
        FROM notification_events
        WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'
        GROUP BY event_type
    ) type_counts
    CROSS JOIN LATERAL (
        SELECT 
            EXTRACT(HOUR FROM created_at) as hour,
            COUNT(*) as count
        FROM notification_events
        WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'
        GROUP BY EXTRACT(HOUR FROM created_at)
    ) hour_counts
    WHERE DATE(ne.created_at) = CURRENT_DATE - INTERVAL '1 day'
    GROUP BY type_counts.*, hour_counts.*
    ON CONFLICT (date) DO UPDATE
    SET metrics = EXCLUDED.metrics,
        created_at = now();
    $$
);

-- =====================================================
-- 6. Health Check (Every 5 Minutes)
-- =====================================================

-- Create health check table
CREATE TABLE IF NOT EXISTS public.notification_health_checks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    check_time TIMESTAMPTZ DEFAULT now() NOT NULL,
    pending_count INTEGER,
    processing_count INTEGER,
    stuck_count INTEGER,
    oldest_pending TIMESTAMPTZ,
    is_healthy BOOLEAN,
    details JSONB
);

-- Unschedule if exists
SELECT cron.unschedule('notification-health-check') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notification-health-check'
);

-- Health check every 5 minutes
SELECT cron.schedule(
    'notification-health-check',
    '*/5 * * * *', -- Every 5 minutes
    $$
    INSERT INTO notification_health_checks (
        pending_count,
        processing_count,
        stuck_count,
        oldest_pending,
        is_healthy,
        details
    )
    SELECT 
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
        COUNT(CASE WHEN status = 'processing' THEN 1 END) as processing_count,
        COUNT(CASE WHEN status = 'processing' AND processed_at < NOW() - INTERVAL '5 minutes' THEN 1 END) as stuck_count,
        MIN(CASE WHEN status = 'pending' THEN scheduled_for END) as oldest_pending,
        -- Healthy if no stuck events and pending queue is reasonable
        COUNT(CASE WHEN status = 'processing' AND processed_at < NOW() - INTERVAL '5 minutes' THEN 1 END) = 0
        AND COUNT(CASE WHEN status = 'pending' AND scheduled_for < NOW() - INTERVAL '10 minutes' THEN 1 END) < 100,
        jsonb_build_object(
            'queue_depth', COUNT(CASE WHEN status = 'pending' THEN 1 END),
            'overdue_count', COUNT(CASE WHEN status = 'pending' AND scheduled_for < NOW() - INTERVAL '10 minutes' THEN 1 END),
            'avg_retry_count', AVG(retry_count)
        )
    FROM notification_events
    WHERE created_at > NOW() - INTERVAL '24 hours';
    
    -- Clean up old health checks (keep last 7 days)
    DELETE FROM notification_health_checks
    WHERE check_time < NOW() - INTERVAL '7 days';
    $$
);

-- =====================================================
-- 7. View All Scheduled Jobs
-- =====================================================

-- Create view for monitoring cron jobs
CREATE OR REPLACE VIEW public.notification_cron_jobs AS
SELECT 
    jobname,
    schedule,
    command,
    nodename,
    nodeport,
    database,
    username,
    active
FROM cron.job
WHERE jobname LIKE '%notification%' 
   OR jobname LIKE '%cleanup%'
   OR jobname LIKE '%retry%'
ORDER BY jobname;

-- Grant access to view
GRANT SELECT ON public.notification_cron_jobs TO authenticated;
GRANT SELECT ON public.notification_analytics TO authenticated;
GRANT SELECT ON public.notification_health_checks TO authenticated;

-- =====================================================
-- 8. Manual Trigger Functions (for testing)
-- =====================================================

-- Function to manually trigger notification processing
CREATE OR REPLACE FUNCTION public.manual_process_notifications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('batch_size', 10)
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute to authenticated users (for testing)
GRANT EXECUTE ON FUNCTION public.manual_process_notifications TO authenticated;

-- =====================================================
-- 9. Summary Comment
-- =====================================================

-- Note: Schema comment requires ownership, skipping for now
-- COMMENT ON SCHEMA cron IS 'Automated job scheduling for notification system';

-- Log successful setup
DO $$
BEGIN
    RAISE NOTICE 'Notification cron jobs configured successfully:';
    RAISE NOTICE '  - Process queue: Every 2 minutes';
    RAISE NOTICE '  - Retry stuck: Every 10 minutes';
    RAISE NOTICE '  - Cleanup old: Daily at 3 AM';
    RAISE NOTICE '  - Cleanup tokens: Weekly on Sunday';
    RAISE NOTICE '  - Analytics: Daily at 1 AM';
    RAISE NOTICE '  - Health check: Every 5 minutes';
END $$;
