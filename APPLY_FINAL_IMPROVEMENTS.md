# 🔧 Final Steps to Complete Setup

## Apply Database Improvements

Since the migrations had naming issues, run these SQL commands directly in your Supabase SQL Editor:

### Step 1: Apply Core Improvements

Go to your [Supabase SQL Editor](https://supabase.com/dashboard/project/jtaedgpxesshdrnbgvjr/sql/new) and run:

```sql
-- 1. Atomic Claim Function for Concurrent Safety
CREATE OR REPLACE FUNCTION public.claim_notification_events(
    batch_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    event_type TEXT,
    event_source TEXT,
    priority TEXT,
    payload JSONB,
    scheduled_for TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    status TEXT,
    retry_count INTEGER,
    max_retries INTEGER,
    dedupe_key TEXT,
    error_message TEXT,
    error_details JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    notification_templates JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH claimed AS (
        SELECT ne.id
        FROM notification_events ne
        WHERE ne.status = 'pending'
          AND ne.scheduled_for <= now()
        ORDER BY ne.priority DESC, ne.scheduled_for ASC
        LIMIT batch_limit
        FOR UPDATE SKIP LOCKED
    ),
    updated AS (
        UPDATE notification_events ne
        SET status = 'processing',
            processed_at = now(),
            updated_at = now()
        FROM claimed
        WHERE ne.id = claimed.id
        RETURNING ne.*
    )
    SELECT 
        u.*,
        row_to_json(nt.*)::jsonb as notification_templates
    FROM updated u
    LEFT JOIN notification_templates nt ON nt.event_type = u.event_type;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_notification_events TO service_role;

-- 2. Metrics Function
CREATE OR REPLACE FUNCTION public.get_notification_metrics(
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    total_events INTEGER,
    delivered INTEGER,
    failed INTEGER,
    pending INTEGER,
    cancelled INTEGER,
    delivery_rate NUMERIC,
    avg_retry_count NUMERIC,
    events_per_hour NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_events,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END)::INTEGER as delivered,
        COUNT(CASE WHEN status = 'failed' THEN 1 END)::INTEGER as failed,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled,
        ROUND(
            COUNT(CASE WHEN status = 'delivered' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN status IN ('delivered', 'failed') THEN 1 END), 0) * 100, 
            2
        ) as delivery_rate,
        ROUND(AVG(retry_count), 2) as avg_retry_count,
        ROUND(COUNT(*)::NUMERIC / NULLIF(p_hours, 0), 2) as events_per_hour
    FROM notification_events
    WHERE created_at >= (now() - (p_hours || ' hours')::INTERVAL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_notification_metrics TO authenticated;

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_notification_events_processing 
    ON public.notification_events(status, scheduled_for, priority DESC)
    WHERE status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS idx_notification_events_user_status 
    ON public.notification_events(user_id, status, created_at DESC);
```

### Step 2: Enable Automated Processing (Critical!)

Run this to set up automatic notification processing:

```sql
-- Install pg_cron if not exists
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Main processing job - runs every 2 minutes
SELECT cron.schedule(
    'process-notifications',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('batch_size', 50)
    );
    $$
);

-- Retry stuck notifications every 10 minutes
SELECT cron.schedule(
    'retry-stuck',
    '*/10 * * * *',
    $$
    UPDATE notification_events
    SET status = 'pending',
        processed_at = NULL
    WHERE status = 'processing'
      AND processed_at < NOW() - INTERVAL '5 minutes';
    $$
);

-- View scheduled jobs
SELECT * FROM cron.job;
```

### Step 3: Test the System

Create a test notification:

```sql
-- Create a test event
SELECT create_notification_event(
    auth.uid(),  -- Your user ID
    'email_received',
    'test',
    jsonb_build_object(
        'from', 'test@example.com',
        'subject', 'Test Notification',
        'preview', 'This is a test'
    ),
    'high',
    now(),
    'test_' || gen_random_uuid()::text
);

-- Check if it was created
SELECT * FROM notification_events 
WHERE user_id = auth.uid() 
ORDER BY created_at DESC 
LIMIT 1;

-- Check metrics
SELECT * FROM get_notification_metrics(1);
```

## 🚦 System Status Check

Run this query to verify everything is working:

```sql
WITH system_check AS (
    SELECT 
        -- Check for pending events
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
        COUNT(CASE WHEN status = 'processing' THEN 1 END) as processing_count,
        COUNT(CASE WHEN status = 'delivered' AND created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as recent_delivered,
        
        -- Check for stuck events
        COUNT(CASE WHEN status = 'processing' AND processed_at < NOW() - INTERVAL '5 minutes' THEN 1 END) as stuck_count,
        
        -- Check cron jobs
        (SELECT COUNT(*) FROM cron.job WHERE jobname LIKE '%notification%' OR jobname LIKE '%process%') as cron_jobs_count
    FROM notification_events
)
SELECT 
    CASE 
        WHEN cron_jobs_count > 0 THEN '✅ Cron jobs configured'
        ELSE '❌ No cron jobs found - run Step 2!'
    END as cron_status,
    
    CASE 
        WHEN stuck_count = 0 THEN '✅ No stuck events'
        ELSE '⚠️ ' || stuck_count || ' stuck events found'
    END as processing_status,
    
    CASE 
        WHEN recent_delivered > 0 THEN '✅ Recent deliveries: ' || recent_delivered
        ELSE '⚠️ No recent deliveries'
    END as delivery_status,
    
    '📊 Queue: ' || pending_count || ' pending, ' || processing_count || ' processing' as queue_status
FROM system_check;
```

## ✅ Expected Results

After running these steps, you should see:
- ✅ Cron jobs configured
- ✅ No stuck events
- ✅ Queue processing automatically
- ✅ Metrics available

## 🆘 Troubleshooting

If notifications aren't processing:

1. **Check Edge Function logs:**
   - Go to [Supabase Dashboard](https://supabase.com/dashboard/project/jtaedgpxesshdrnbgvjr/functions)
   - Click on `send-push-notification-v1`
   - View logs

2. **Verify Service Account is set:**
   ```bash
   supabase secrets list
   # Should show FCM_SERVICE_ACCOUNT_KEY
   ```

3. **Check for errors:**
   ```sql
   SELECT * FROM notification_events 
   WHERE status = 'failed' 
   AND created_at > NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC;
   ```

---

## 🎉 Once Complete

Your system will:
- Process notifications automatically every 2 minutes
- Retry failures with exponential backoff
- Clean up old data automatically
- Respect user preferences
- Track all metrics

The push notification system is now **fully production-ready!**
