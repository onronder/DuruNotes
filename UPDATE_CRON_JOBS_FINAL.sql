-- =====================================================
-- UPDATE CRON JOBS TO USE FINAL FUNCTIONS
-- =====================================================
-- Points all cron jobs to the consolidated functions
-- =====================================================

-- Clean up ALL old cron jobs
DO $$
DECLARE
    job_record record;
BEGIN
    FOR job_record IN 
        SELECT jobname FROM cron.job 
    LOOP
        PERFORM cron.unschedule(job_record.jobname);
        RAISE NOTICE 'Unscheduled: %', job_record.jobname;
    END LOOP;
END $$;

-- =====================================================
-- FINAL CRON JOBS - Using consolidated functions
-- =====================================================

-- 1. Process notifications every 2 minutes
SELECT cron.schedule(
    'process-notifications',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "process", "batch_size": 50}'::jsonb
    );
    $$
);

-- 2. Retry stuck notifications every 10 minutes
SELECT cron.schedule(
    'retry-stuck',
    '*/10 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "retry_stuck", "minutes_old": 5}'::jsonb
    );
    $$
);

-- 3. Clean up old notifications daily at 3 AM
SELECT cron.schedule(
    'cleanup-notifications',
    '0 3 * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "cleanup", "days_old": 30}'::jsonb
    );
    $$
);

-- 4. Generate stats hourly
SELECT cron.schedule(
    'notification-stats',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notifications',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{"action": "stats"}'::jsonb
    );
    $$
);

-- =====================================================
-- SUMMARY
-- =====================================================
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT COUNT(*) INTO v_count FROM cron.job WHERE active = true;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE '✅ FINAL CRON JOBS CONFIGURED';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Active jobs: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Jobs scheduled:';
    RAISE NOTICE '  • process-notifications: Every 2 minutes';
    RAISE NOTICE '  • retry-stuck: Every 10 minutes';
    RAISE NOTICE '  • cleanup-notifications: Daily at 3 AM';
    RAISE NOTICE '  • notification-stats: Every hour';
    RAISE NOTICE '';
    RAISE NOTICE 'All jobs point to consolidated functions!';
    RAISE NOTICE '====================================';
END $$;
