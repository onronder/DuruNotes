-- Enable pg_net extension for HTTP requests from database
CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

-- Grant usage to postgres role for cron jobs
GRANT USAGE ON SCHEMA extensions TO postgres;

-- Fix the push notification cron job to use extensions schema
DO $$
BEGIN
  -- Update existing cron job if it exists
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-push-notifications') THEN
    UPDATE cron.job 
    SET command = '
      SELECT extensions.http_post(
          url := ''https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1'',
          headers := jsonb_build_object(
              ''Content-Type'', ''application/json'',
              ''Authorization'', ''Bearer '' || current_setting(''app.supabase_service_role_key'')
          ),
          body := jsonb_build_object(''batch_size'', 50)
      );'
    WHERE jobname = 'process-push-notifications';
  END IF;
END $$;
