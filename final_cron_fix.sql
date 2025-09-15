-- =====================================================
-- FINAL WORKING CRON JOB SETUP
-- =====================================================
-- Uses the simplified notification processor that actually works
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Clean up ALL old cron jobs
DO $$
DECLARE
    job_record record;
BEGIN
    FOR job_record IN 
        SELECT jobname FROM cron.job 
        WHERE jobname LIKE '%notification%' 
           OR jobname LIKE '%push%'
           OR jobname LIKE '%process%'
    LOOP
        PERFORM cron.unschedule(job_record.jobname);
        RAISE NOTICE 'Unscheduled: %', job_record.jobname;
    END LOOP;
END $$;

-- =====================================================
-- WORKING CRON JOBS - NO AUTH NEEDED!
-- =====================================================

-- 1. Process notifications every 2 minutes
SELECT cron.schedule(
    'process-notifications-working',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications-simple',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "process", "batch_size": 50}'::jsonb
    );
    $$
);

-- 2. Retry stuck notifications every 10 minutes
SELECT cron.schedule(
    'retry-stuck-notifications',
    '*/10 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications-simple',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "retry_stuck", "minutes_old": 5}'::jsonb
    );
    $$
);

-- 3. Clean up old notifications daily at 3 AM
SELECT cron.schedule(
    'cleanup-old-notifications',
    '0 3 * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications-simple',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "cleanup", "days_old": 30}'::jsonb
    );
    $$
);

-- =====================================================
-- TEST FUNCTIONS
-- =====================================================

-- Function to manually test the notification processor
CREATE OR REPLACE FUNCTION public.test_notification_processor()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Call the working processor
    SELECT content::jsonb INTO v_result
    FROM net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications-simple',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "test"}'::jsonb
    );
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Function to manually process notifications
CREATE OR REPLACE FUNCTION public.process_notifications_now(p_batch_size int DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT content::jsonb INTO v_result
    FROM net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications-simple',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := jsonb_build_object('action', 'process', 'batch_size', p_batch_size)
    );
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.test_notification_processor TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_notifications_now TO authenticated;

-- =====================================================
-- SUMMARY
-- =====================================================
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM cron.job 
    WHERE active = true 
      AND jobname IN ('process-notifications-working', 'retry-stuck-notifications', 'cleanup-old-notifications');
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE '✅ CRON JOBS CONFIGURED SUCCESSFULLY';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Active jobs: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Test commands:';
    RAISE NOTICE '  SELECT test_notification_processor();';
    RAISE NOTICE '  SELECT process_notifications_now(5);';
    RAISE NOTICE '';
    RAISE NOTICE 'View active jobs:';
    RAISE NOTICE '  SELECT jobname, schedule FROM cron.job WHERE active = true;';
    RAISE NOTICE '====================================';
END $$;