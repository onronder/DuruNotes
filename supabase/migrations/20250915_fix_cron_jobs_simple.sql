-- =====================================================
-- FIX CRON JOBS - SIMPLE APPROACH
-- =====================================================
-- The issue: Cron jobs need to authenticate when calling edge functions
-- Solution: Use the service role key in the Authorization header
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Unschedule existing jobs
SELECT cron.unschedule(jobname) 
FROM cron.job 
WHERE jobname IN (
    'process-notification-queue',
    'retry-stuck-notifications',
    'cleanup-old-notifications'
);

-- =====================================================
-- SCHEDULE CRON JOBS WITH PROPER AUTHENTICATION
-- =====================================================

-- 1. Process Notification Queue (Every 2 Minutes)
SELECT cron.schedule(
    'process-notification-queue',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ',
            'x-source', 'pg_cron'
        ),
        body := jsonb_build_object(
            'action', 'process',
            'batch_size', 50
        )
    ) AS request_id;
    $$
);

-- 2. Alternative: Call send-push-notification-v1 directly
SELECT cron.schedule(
    'send-push-notifications',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ'
        ),
        body := jsonb_build_object(
            'batch_size', 50
        )
    ) AS request_id;
    $$
);

-- 3. Retry Stuck Notifications (Every 10 Minutes)
SELECT cron.schedule(
    'retry-stuck-notifications',
    '*/10 * * * *',
    $$
    UPDATE notification_events
    SET status = 'pending',
        processed_at = NULL,
        error_message = 'Reset from stuck processing state',
        retry_count = COALESCE(retry_count, 0) + 1
    WHERE status = 'processing'
      AND processed_at < NOW() - INTERVAL '5 minutes';
    $$
);

-- 4. Cleanup Old Notifications (Daily at 3 AM)
SELECT cron.schedule(
    'cleanup-old-notifications',
    '0 3 * * *',
    $$
    DELETE FROM notification_events
    WHERE created_at < NOW() - INTERVAL '30 days'
      AND status IN ('delivered', 'failed', 'cancelled');
    $$
);

-- =====================================================
-- CREATE TEST FUNCTIONS
-- =====================================================

-- Function to manually test edge function calls
CREATE OR REPLACE FUNCTION public.test_edge_function_call()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ',
            'x-source', 'manual_test'
        ),
        body := jsonb_build_object(
            'action', 'process',
            'batch_size', 1
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.test_edge_function_call TO authenticated;

-- =====================================================
-- VERIFY SETUP
-- =====================================================

DO $$
DECLARE
    v_job_count int;
BEGIN
    SELECT COUNT(*) INTO v_job_count
    FROM cron.job 
    WHERE jobname IN (
        'process-notification-queue',
        'send-push-notifications',
        'retry-stuck-notifications',
        'cleanup-old-notifications'
    )
    AND active = true;
    
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Cron Jobs Fixed!';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Active cron jobs: %', v_job_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Test the edge function call:';
    RAISE NOTICE '  SELECT * FROM public.test_edge_function_call();';
    RAISE NOTICE '';
    RAISE NOTICE 'View active jobs:';
    RAISE NOTICE '  SELECT jobname, schedule, active FROM cron.job WHERE active = true;';
    RAISE NOTICE '====================================';
END $$;
