# Fix Web Clipper & Edge Function Issues

## Issues Identified

### 1. ❌ Web Clipper 401 Unauthorized Error
The web clipper is failing authentication because:
- The secret in the URL doesn't match `INBOUND_PARSE_SECRET` environment variable
- The secret being sent: `04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd`

### 2. ❌ pg_net Extension Missing
The cron job for push notifications is failing because the `net` schema doesn't exist.

## Fix Instructions

### Fix 1: Update Web Clipper Secret

1. **Check current secret in Supabase Dashboard:**
```bash
# Run this to verify the current secret
supabase secrets list
```

2. **Update the web clipper extension with the correct secret:**
```bash
# In tools/web-clipper-extension/background.js
# Update the secret to match INBOUND_PARSE_SECRET from Supabase
```

3. **OR set the secret in Supabase to match the web clipper:**
```bash
supabase secrets set INBOUND_PARSE_SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd"
```

### Fix 2: Enable pg_net Extension

1. **Create migration to enable pg_net:**
```sql
-- supabase/migrations/20250114_enable_pg_net.sql
-- Enable pg_net extension for HTTP requests from database
CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

-- Grant usage to postgres role for cron jobs
GRANT USAGE ON SCHEMA extensions TO postgres;
```

2. **Update the cron job to use extensions schema:**
```sql
-- Update the push notification cron job
UPDATE cron.job 
SET command = '
    SELECT extensions.http_post(
        url := ''https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1'',
        headers := jsonb_build_object(
            ''Content-Type'', ''application/json''
        ),
        body := jsonb_build_object(''batch_size'', 50)
    );'
WHERE jobname = 'process-push-notifications';
```

## Quick Fix Script

Create and run this script:
```bash
#!/bin/bash
# fix_edge_functions.sh

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
EOF

# 3. Apply migrations
echo "Applying migrations..."
supabase db push

# 4. Deploy functions
echo "Deploying Edge functions..."
supabase functions deploy inbound-web

echo "✅ Done! Test the web clipper now."
```

## Testing

After applying fixes:

1. **Test Web Clipper:**
   - Open a webpage
   - Click the clipper extension
   - It should successfully save to your notes

2. **Verify pg_net:**
```sql
-- Run in Supabase SQL Editor
SELECT extensions.http_get('https://httpbin.org/get');
```

3. **Check cron job:**
```sql
-- Check if cron job runs without errors
SELECT cron.schedule('test-push-notification', '*/1 * * * *', $$
    SELECT extensions.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('batch_size', 1)
    );
$$);

-- Wait 1 minute then check logs
SELECT * FROM cron.job_run_details 
WHERE jobname = 'test-push-notification' 
ORDER BY start_time DESC LIMIT 1;

-- Delete test job
SELECT cron.unschedule('test-push-notification');
```

## Alternative: Update Web Clipper Extension

If you prefer to update the extension instead of changing the secret:

1. Get the current secret from Supabase:
```bash
supabase secrets list | grep INBOUND_PARSE_SECRET
```

2. Update `tools/web-clipper-extension/background.js`:
```javascript
// Replace the hardcoded secret with the one from Supabase
const INBOUND_SECRET = 'YOUR_ACTUAL_SECRET_FROM_SUPABASE';
```

3. Reload the extension in your browser.
