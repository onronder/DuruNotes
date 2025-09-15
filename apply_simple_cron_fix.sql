-- =====================================================
-- SIMPLE CRON FIX - NO AUTHENTICATION NEEDED
-- =====================================================
-- Since functions are deployed with --no-verify-jwt,
-- we don't need Authorization headers at all!
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Unschedule ALL existing notification jobs
DO $$
DECLARE
    job_record record;
BEGIN
    FOR job_record IN 
        SELECT jobname FROM cron.job 
        WHERE jobname LIKE '%notification%' 
           OR jobname LIKE '%push%'
    LOOP
        PERFORM cron.unschedule(job_record.jobname);
        RAISE NOTICE 'Unscheduled: %', job_record.jobname;
    END LOOP;
END $$;

-- Schedule new job WITHOUT authentication (because function has --no-verify-jwt)
SELECT cron.schedule(
    'process-notifications-simple',
    '*/2 * * * *',  -- Every 2 minutes
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "process", "batch_size": 50}'::jsonb
    );
    $$
);

-- Alternative: Direct database operations (no edge function needed)
SELECT cron.schedule(
    'retry-stuck-direct',
    '*/10 * * * *',  -- Every 10 minutes
    $$
    UPDATE notification_events
    SET status = 'pending',
        processed_at = NULL,
        retry_count = COALESCE(retry_count, 0) + 1
    WHERE status = 'processing'
      AND processed_at < NOW() - INTERVAL '5 minutes';
    $$
);

-- Test function
CREATE OR REPLACE FUNCTION public.test_notification_edge_function()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Call without authentication (function has --no-verify-jwt)
    SELECT content::jsonb INTO v_result
    FROM net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "process", "batch_size": 1}'::jsonb
    );
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.test_notification_edge_function TO authenticated;

-- Show results
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT COUNT(*) INTO v_count FROM cron.job WHERE active = true;
    RAISE NOTICE '====================================';
    RAISE NOTICE 'SIMPLE CRON FIX APPLIED';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Active cron jobs: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Test with: SELECT test_notification_edge_function();';
    RAISE NOTICE '====================================';
END $$;
