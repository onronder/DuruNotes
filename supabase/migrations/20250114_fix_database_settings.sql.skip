-- =====================================================
-- Fix Database Settings for Cron Jobs
-- =====================================================
-- This migration sets the required database configuration
-- for cron jobs to authenticate with Edge Functions
-- =====================================================

-- Set the Supabase URL and Service Role Key as database settings
-- These are used by pg_cron jobs to call Edge Functions

DO $$
BEGIN
    -- Set Supabase URL (replace with your actual project URL)
    EXECUTE format('ALTER DATABASE postgres SET app.settings.supabase_url = %L', 
        'https://jtaedgpxesshdrnbgvjr.supabase.co');
    
    -- Set Service Role Key (this is the correct service_role key)
    EXECUTE format('ALTER DATABASE postgres SET app.settings.supabase_service_role_key = %L',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTw');
    
    RAISE NOTICE 'Database settings configured successfully';
END $$;

-- Reload configuration to apply settings immediately
SELECT pg_reload_conf();

-- Verify settings are applied
DO $$
DECLARE
    v_url text;
    v_key text;
BEGIN
    -- Try to get the settings
    BEGIN
        v_url := current_setting('app.settings.supabase_url');
        v_key := current_setting('app.settings.supabase_service_role_key');
        
        RAISE NOTICE 'Settings verified:';
        RAISE NOTICE '  Supabase URL: %', v_url;
        RAISE NOTICE '  Service Role Key: % (first 20 chars)', substring(v_key, 1, 20) || '...';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Settings not immediately available. They will be available after next database connection.';
    END;
END $$;

-- =====================================================
-- Alternative: Update cron jobs to use hardcoded values
-- =====================================================
-- If the above doesn't work, we'll update the cron jobs directly

-- Unschedule existing job
SELECT cron.unschedule('process-notification-queue') 
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'process-notification-queue'
);

-- Reschedule with hardcoded values
SELECT cron.schedule(
    'process-notification-queue',
    '*/2 * * * *', -- Every 2 minutes
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTw',
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'batch_size', 50
        )
    ) AS request_id;
    $$
);

-- Also update the function that sends immediate notifications
CREATE OR REPLACE FUNCTION send_push_notification_immediate(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id bigint;
BEGIN
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTw',
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'event_id', p_event_id::text,
            'batch_size', 1
        )
    ) INTO v_request_id;
    
    -- Log the request
    RAISE NOTICE 'Push notification request sent with ID: %', v_request_id;
END;
$$;

RAISE NOTICE 'Cron jobs updated with hardcoded authentication';
RAISE NOTICE 'Push notification system should now work correctly';
