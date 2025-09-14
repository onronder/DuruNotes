#!/bin/bash

echo "🔧 Fixing Web Clipper and Edge Function Issues..."

# 1. Set the INBOUND_PARSE_SECRET to match web clipper
echo "Setting INBOUND_PARSE_SECRET..."
supabase secrets set INBOUND_PARSE_SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd"

# 2. Create migration for pg_net
echo "Creating pg_net migration..."
cat > supabase/migrations/20250114_enable_pg_net.sql << 'EOF'
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
EOF

# 3. Apply migrations
echo "Applying migrations..."
supabase db push

# 4. Deploy functions
echo "Deploying Edge functions..."
supabase functions deploy inbound-web

echo "✅ Done! The web clipper should now work correctly."
echo ""
echo "📝 Next steps:"
echo "1. Test the web clipper by clipping a webpage"
echo "2. Check if it appears in your notes"
echo "3. If it still doesn't work, check the logs:"
echo "   supabase functions logs inbound-web"
