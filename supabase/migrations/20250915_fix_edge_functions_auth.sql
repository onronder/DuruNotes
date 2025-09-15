-- =====================================================
-- Fix Edge Functions Authentication Issues
-- Date: 2025-09-15
-- =====================================================
-- This migration implements the engineering-level fixes for:
-- 1. Storing secrets securely in Vault
-- 2. Updating cron jobs to include Authorization headers
-- 3. Fixing the notification processing pipeline
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- =====================================================
-- PART 1: Setup Vault for Secure Secret Storage
-- =====================================================

-- Enable vault extension if not already enabled
CREATE EXTENSION IF NOT EXISTS vault;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA vault TO postgres;

-- Store secrets in Vault (replace with your actual values)
DO $$
DECLARE
    v_service_key text;
    v_anon_key text;
    v_project_url text;
BEGIN
    -- Get the actual service role key from environment or use the one from your .env file
    -- IMPORTANT: Replace this with your actual service role key
    v_service_key := 'YOUR_ACTUAL_SERVICE_ROLE_KEY_HERE';
    
    -- Get the anon key
    v_anon_key := 'YOUR_ACTUAL_ANON_KEY_HERE';
    
    -- Get the project URL
    v_project_url := 'https://jtaedgpxesshdrnbgvjr.supabase.co';
    
    -- Delete existing secrets if they exist
    DELETE FROM vault.secrets WHERE name IN ('service_key', 'anon_key', 'project_url');
    
    -- Create new secrets
    INSERT INTO vault.secrets (name, secret)
    VALUES 
        ('service_key', v_service_key),
        ('anon_key', v_anon_key),
        ('project_url', v_project_url);
    
    RAISE NOTICE 'Vault secrets created successfully';
END $$;

-- =====================================================
-- PART 2: Update Cron Jobs with Proper Authentication
-- =====================================================

-- Unschedule all existing notification-related cron jobs
DO $$
DECLARE
    job_record record;
BEGIN
    FOR job_record IN 
        SELECT jobname FROM cron.job 
        WHERE jobname IN (
            'process-notification-queue',
            'retry-stuck-notifications',
            'cleanup-old-notifications',
            'notification-health-check'
        )
    LOOP
        PERFORM cron.unschedule(job_record.jobname);
        RAISE NOTICE 'Unscheduled job: %', job_record.jobname;
    END LOOP;
END $$;

-- 1. Process Notification Queue (Every 2 Minutes) with proper authentication
SELECT cron.schedule(
    'process-notification-queue',
    '*/2 * * * *', -- Every 2 minutes
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_key'),
            'x-source', 'pg_cron'
        ),
        body := jsonb_build_object(
            'action', 'process',
            'batch_size', 50
        )
    ) AS request_id;
    $$
);

-- 2. Retry Stuck Notifications (Every 10 Minutes)
SELECT cron.schedule(
    'retry-stuck-notifications',
    '*/10 * * * *', -- Every 10 minutes
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_key'),
            'x-source', 'pg_cron'
        ),
        body := jsonb_build_object(
            'action', 'retry_stuck',
            'minutes_old', 5
        )
    ) AS request_id;
    $$
);

-- 3. Clean Up Old Notifications (Daily at 3 AM)
SELECT cron.schedule(
    'cleanup-old-notifications',
    '0 3 * * *', -- Daily at 3:00 AM
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_key'),
            'x-source', 'pg_cron'
        ),
        body := jsonb_build_object(
            'action', 'cleanup',
            'days_old', 30
        )
    ) AS request_id;
    $$
);

-- 4. Health Check (Every 5 Minutes)
SELECT cron.schedule(
    'notification-health-check',
    '*/5 * * * *', -- Every 5 minutes
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_key'),
            'x-source', 'pg_cron'
        ),
        body := jsonb_build_object(
            'action', 'analytics',
            'hours', 24
        )
    ) AS request_id;
    $$
);

-- =====================================================
-- PART 3: Create Helper Functions for Manual Testing
-- =====================================================

-- Function to test edge function connectivity
CREATE OR REPLACE FUNCTION public.test_edge_function_auth()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
    v_service_key text;
    v_project_url text;
BEGIN
    -- Get secrets from vault
    SELECT decrypted_secret INTO v_service_key 
    FROM vault.decrypted_secrets WHERE name = 'service_key';
    
    SELECT decrypted_secret INTO v_project_url 
    FROM vault.decrypted_secrets WHERE name = 'project_url';
    
    -- Test the diagnostic endpoint
    SELECT net.http_post(
        url := v_project_url || '/functions/v1/test-diagnostic',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_service_key,
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('test', true)
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function to manually trigger notification processing
CREATE OR REPLACE FUNCTION public.manual_process_notifications(p_batch_size int DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
    v_service_key text;
    v_project_url text;
BEGIN
    -- Get secrets from vault
    SELECT decrypted_secret INTO v_service_key 
    FROM vault.decrypted_secrets WHERE name = 'service_key';
    
    SELECT decrypted_secret INTO v_project_url 
    FROM vault.decrypted_secrets WHERE name = 'project_url';
    
    -- Call the notification processor
    SELECT net.http_post(
        url := v_project_url || '/functions/v1/process-notification-queue',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_service_key,
            'Content-Type', 'application/json',
            'x-source', 'manual'
        ),
        body := jsonb_build_object(
            'action', 'process',
            'batch_size', p_batch_size
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.test_edge_function_auth TO authenticated;
GRANT EXECUTE ON FUNCTION public.manual_process_notifications TO authenticated;

-- =====================================================
-- PART 4: Create Monitoring Views
-- =====================================================

-- View to check vault secrets status
CREATE OR REPLACE VIEW public.vault_secrets_status AS
SELECT 
    name,
    CASE 
        WHEN decrypted_secret IS NOT NULL THEN 'Configured'
        ELSE 'Missing'
    END as status,
    CASE 
        WHEN name = 'service_key' THEN 
            CASE WHEN LENGTH(decrypted_secret) > 100 THEN 'Valid length' ELSE 'Invalid length' END
        WHEN name = 'anon_key' THEN 
            CASE WHEN LENGTH(decrypted_secret) > 100 THEN 'Valid length' ELSE 'Invalid length' END
        WHEN name = 'project_url' THEN 
            CASE WHEN decrypted_secret LIKE 'https://%' THEN 'Valid URL' ELSE 'Invalid URL' END
        ELSE 'Unknown'
    END as validation
FROM vault.decrypted_secrets
WHERE name IN ('service_key', 'anon_key', 'project_url');

-- Grant access to monitoring view
GRANT SELECT ON public.vault_secrets_status TO authenticated;

-- =====================================================
-- PART 5: Verify Setup
-- =====================================================

DO $$
DECLARE
    v_job_count int;
    v_secret_count int;
BEGIN
    -- Count scheduled jobs
    SELECT COUNT(*) INTO v_job_count
    FROM cron.job 
    WHERE jobname IN (
        'process-notification-queue',
        'retry-stuck-notifications',
        'cleanup-old-notifications',
        'notification-health-check'
    );
    
    -- Count configured secrets
    SELECT COUNT(*) INTO v_secret_count
    FROM vault.decrypted_secrets
    WHERE name IN ('service_key', 'anon_key', 'project_url')
    AND decrypted_secret IS NOT NULL;
    
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Edge Functions Auth Fix Applied';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Cron jobs scheduled: %', v_job_count;
    RAISE NOTICE 'Vault secrets configured: %', v_secret_count;
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: Update the vault secrets with your actual keys:';
    RAISE NOTICE '  UPDATE vault.secrets SET secret = ''your_actual_service_key'' WHERE name = ''service_key'';';
    RAISE NOTICE '  UPDATE vault.secrets SET secret = ''your_actual_anon_key'' WHERE name = ''anon_key'';';
    RAISE NOTICE '';
    RAISE NOTICE 'Test the setup:';
    RAISE NOTICE '  SELECT * FROM public.test_edge_function_auth();';
    RAISE NOTICE '  SELECT * FROM public.manual_process_notifications(1);';
    RAISE NOTICE '====================================';
END $$;
