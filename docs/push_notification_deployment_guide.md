# Push Notification System - Deployment & Operations Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Deployment Steps](#deployment-steps)
3. [Configuration](#configuration)
4. [Testing](#testing)
5. [Monitoring](#monitoring)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance](#maintenance)

## Prerequisites

### Required Services
- ✅ Firebase Project with FCM enabled
- ✅ Supabase Project with Edge Functions enabled
- ✅ Apple Developer Account (for iOS)
- ✅ Google Play Console Account (for Android)

### Required Files
- ✅ `google-services.json` (Android)
- ✅ `GoogleService-Info.plist` (iOS)
- ✅ FCM Server Key
- ✅ APNs Authentication Key (.p8 file)

### Environment Variables
```bash
# Supabase Edge Functions
FCM_SERVER_KEY=your_fcm_server_key
FCM_SERVICE_ACCOUNT_KEY=your_service_account_json
INBOUND_PARSE_SECRET=your_webhook_secret
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## Deployment Steps

### 1. Database Migration

Run the notification system migration:

```bash
# Apply the migration
supabase db push

# Or run directly
psql $DATABASE_URL < supabase/migrations/20250113_notification_system.sql
```

Verify tables created:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
  'notification_events',
  'notification_templates', 
  'notification_deliveries',
  'notification_preferences'
);
```

### 2. Deploy Edge Functions

```bash
# Navigate to functions directory
cd supabase/functions

# Deploy send-push-notification function
supabase functions deploy send-push-notification \
  --no-verify-jwt

# Deploy process-notification-queue function
supabase functions deploy process-notification-queue \
  --no-verify-jwt

# Or use the deployment script
./deploy_notification_functions.sh
```

### 3. Set Edge Function Secrets

```bash
# Set FCM credentials
supabase secrets set FCM_SERVER_KEY="your_fcm_server_key"
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'

# Set webhook secret
supabase secrets set INBOUND_PARSE_SECRET="your_secret"
```

### 4. Configure Cron Jobs

Set up periodic processing of the notification queue:

```sql
-- Install pg_cron extension if not already installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule queue processing every 5 minutes
SELECT cron.schedule(
  'process-notification-queue',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('action', 'process', 'batch_size', 50)
  );
  $$
);

-- Schedule cleanup daily at 2 AM
SELECT cron.schedule(
  'cleanup-notifications',
  '0 2 * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('action', 'cleanup', 'cleanup_days', 30)
  );
  $$
);

-- Schedule analytics collection hourly
SELECT cron.schedule(
  'collect-notification-analytics',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('action', 'analytics')
  );
  $$
);
```

### 5. Update Client Application

#### Initialize Notification Handler in main.dart

```dart
// In main.dart
import 'package:duru_notes/services/notification_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notification handler
  final notificationHandler = NotificationHandlerService();
  await notificationHandler.initialize();
  
  // Handle notification taps
  notificationHandler.onNotificationTap.listen((payload) {
    // Navigate based on payload
    _handleNotificationNavigation(payload);
  });
  
  runApp(MyApp());
}
```

#### Register Push Token on Login

```dart
// In auth_screen.dart or after successful login
final pushService = ref.read(pushNotificationServiceProvider);
final result = await pushService.registerWithBackend();

if (result.success) {
  print('Push notifications registered successfully');
} else {
  print('Failed to register push notifications: ${result.error}');
}
```

### 6. Configure Firebase Console

1. **Android Configuration**
   - Add SHA-1 fingerprint in Firebase Console
   - Enable Cloud Messaging API
   - Download latest `google-services.json`

2. **iOS Configuration**
   - Upload APNs Authentication Key
   - Enter Key ID and Team ID
   - Enable push notifications in Xcode capabilities

## Configuration

### Notification Templates

Customize notification templates in the database:

```sql
-- Update email notification template
UPDATE notification_templates 
SET push_template = jsonb_build_object(
  'title', 'New Email from {{from}}',
  'body', '{{subject}}',
  'icon', 'email',
  'sound', 'email_sound',
  'badge', 1,
  'color', '#4CAF50'
)
WHERE event_type = 'email_received';

-- Add custom template
INSERT INTO notification_templates (event_type, push_template, priority)
VALUES (
  'custom_event',
  '{"title": "Custom Notification", "body": "{{message}}"}',
  'normal'
);
```

### User Preferences

Set default preferences for new users:

```sql
-- Create trigger for default preferences
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (
    user_id,
    enabled,
    push_enabled,
    email_enabled,
    event_preferences
  ) VALUES (
    NEW.id,
    true,
    true,
    false,
    '{}'::jsonb
  ) ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_user_notification_preferences
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_notification_preferences();
```

## Testing

### 1. Test Push Token Registration

```bash
# Check if tokens are being stored
psql $DATABASE_URL -c "
  SELECT device_id, platform, updated_at 
  FROM user_devices 
  WHERE user_id = 'YOUR_USER_ID'
  ORDER BY updated_at DESC;
"
```

### 2. Test Notification Creation

```bash
# Create a test notification event
curl -X POST https://YOUR_PROJECT.supabase.co/rest/v1/rpc/create_notification_event \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": "YOUR_USER_ID",
    "p_event_type": "email_received",
    "p_event_source": "test",
    "p_payload": {
      "from": "test@example.com",
      "subject": "Test Email"
    }
  }'
```

### 3. Test Edge Function

```bash
# Process notifications manually
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"batch_size": 10}'
```

### 4. Test End-to-End Flow

```bash
# Send test email to trigger notification
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/email_inbox?secret=YOUR_SECRET \
  -F "from=sender@example.com" \
  -F "to=YOUR_ALIAS@in.durunotes.app" \
  -F "subject=Test Email" \
  -F "text=This is a test email"
```

## Monitoring

### Key Metrics to Track

1. **Delivery Rate**
```sql
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total_events,
  COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
  ROUND(
    COUNT(CASE WHEN status = 'delivered' THEN 1 END)::numeric / 
    COUNT(*)::numeric * 100, 2
  ) as delivery_rate
FROM notification_events
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

2. **Average Delivery Time**
```sql
SELECT 
  event_type,
  AVG(EXTRACT(EPOCH FROM (delivered_at - sent_at))) as avg_seconds,
  MIN(EXTRACT(EPOCH FROM (delivered_at - sent_at))) as min_seconds,
  MAX(EXTRACT(EPOCH FROM (delivered_at - sent_at))) as max_seconds
FROM notification_deliveries
WHERE delivered_at IS NOT NULL
  AND sent_at IS NOT NULL
  AND created_at >= NOW() - INTERVAL '24 hours'
GROUP BY event_type;
```

3. **Failed Notifications**
```sql
SELECT 
  ne.event_type,
  ne.error_message,
  COUNT(*) as count
FROM notification_events ne
WHERE ne.status = 'failed'
  AND ne.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY ne.event_type, ne.error_message
ORDER BY count DESC;
```

4. **User Engagement**
```sql
SELECT 
  DATE(created_at) as date,
  COUNT(DISTINCT event_id) as notifications_sent,
  COUNT(DISTINCT CASE WHEN status = 'opened' THEN event_id END) as opened,
  COUNT(DISTINCT CASE WHEN status = 'clicked' THEN event_id END) as clicked
FROM notification_deliveries
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Set Up Alerts

```sql
-- Alert for high failure rate
CREATE OR REPLACE FUNCTION check_notification_failure_rate()
RETURNS void AS $$
DECLARE
  failure_rate numeric;
BEGIN
  SELECT 
    COUNT(CASE WHEN status = 'failed' THEN 1 END)::numeric / 
    COUNT(*)::numeric * 100
  INTO failure_rate
  FROM notification_events
  WHERE created_at >= NOW() - INTERVAL '1 hour';
  
  IF failure_rate > 10 THEN
    -- Send alert (integrate with your alerting system)
    RAISE WARNING 'High notification failure rate: %', failure_rate;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Schedule alert check every 10 minutes
SELECT cron.schedule(
  'check-notification-failures',
  '*/10 * * * *',
  'SELECT check_notification_failure_rate();'
);
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Notifications Not Received

**Check Token Registration:**
```sql
-- Verify token exists and is recent
SELECT * FROM user_devices 
WHERE user_id = 'USER_ID'
ORDER BY updated_at DESC;
```

**Check Event Creation:**
```sql
-- Verify events are being created
SELECT * FROM notification_events
WHERE user_id = 'USER_ID'
ORDER BY created_at DESC
LIMIT 10;
```

**Check Delivery Status:**
```sql
-- Check delivery attempts
SELECT * FROM notification_deliveries
WHERE user_id = 'USER_ID'
ORDER BY created_at DESC
LIMIT 10;
```

#### 2. High Failure Rate

**Identify Failed Tokens:**
```sql
-- Find devices with consistent failures
SELECT 
  ud.device_id,
  ud.platform,
  COUNT(nd.id) as failure_count
FROM user_devices ud
JOIN notification_deliveries nd ON ud.device_id = nd.device_id
WHERE nd.status = 'failed'
  AND nd.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY ud.device_id, ud.platform
HAVING COUNT(nd.id) > 5
ORDER BY failure_count DESC;
```

**Clean Invalid Tokens:**
```sql
-- Remove tokens that consistently fail
DELETE FROM user_devices
WHERE id IN (
  SELECT ud.id
  FROM user_devices ud
  JOIN notification_deliveries nd ON ud.device_id = nd.device_id
  WHERE nd.status = 'failed'
    AND nd.error_code IN ('InvalidRegistration', 'NotRegistered')
  GROUP BY ud.id
  HAVING COUNT(nd.id) > 3
);
```

#### 3. Queue Processing Issues

**Check Queue Depth:**
```sql
-- Check pending notifications
SELECT 
  status,
  COUNT(*) as count,
  MIN(scheduled_for) as oldest,
  MAX(scheduled_for) as newest
FROM notification_events
WHERE status IN ('pending', 'processing')
GROUP BY status;
```

**Reset Stuck Events:**
```sql
-- Reset events stuck in processing
UPDATE notification_events
SET status = 'pending',
    processed_at = NULL,
    retry_count = retry_count + 1
WHERE status = 'processing'
  AND processed_at < NOW() - INTERVAL '10 minutes';
```

#### 4. Performance Issues

**Optimize Indexes:**
```sql
-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename IN ('notification_events', 'notification_deliveries')
ORDER BY idx_scan DESC;
```

**Analyze Query Performance:**
```sql
EXPLAIN ANALYZE
SELECT * FROM notification_events
WHERE status = 'pending'
  AND scheduled_for <= NOW()
ORDER BY priority DESC, scheduled_for ASC
LIMIT 50;
```

## Maintenance

### Daily Tasks

1. **Monitor Delivery Metrics**
   - Check delivery rate
   - Review failed notifications
   - Monitor queue depth

2. **Clean Up Old Data**
   ```sql
   -- Run cleanup function
   SELECT cleanup_old_notifications(30);
   ```

### Weekly Tasks

1. **Review Analytics**
   - User engagement rates
   - Popular notification types
   - Peak usage times

2. **Update Invalid Tokens**
   ```sql
   -- Remove stale tokens
   SELECT cleanup_stale_device_tokens(90);
   ```

### Monthly Tasks

1. **Performance Review**
   - Analyze slow queries
   - Optimize database indexes
   - Review Edge Function logs

2. **Security Audit**
   - Rotate API keys
   - Review access logs
   - Update dependencies

### Backup Strategy

```bash
# Backup notification data
pg_dump $DATABASE_URL \
  --table=notification_events \
  --table=notification_templates \
  --table=notification_deliveries \
  --table=notification_preferences \
  > notifications_backup_$(date +%Y%m%d).sql
```

## Security Considerations

### API Security

1. **Validate Webhooks**
   - Always verify HMAC signatures
   - Check timestamp freshness
   - Validate source IPs

2. **Rate Limiting**
   ```sql
   -- Implement rate limiting
   CREATE TABLE notification_rate_limits (
     user_id UUID REFERENCES auth.users(id),
     window_start TIMESTAMPTZ,
     count INTEGER DEFAULT 0,
     PRIMARY KEY (user_id, window_start)
   );
   ```

3. **Encrypt Sensitive Data**
   - Store tokens encrypted at rest
   - Use secure connections (HTTPS/TLS)
   - Redact PII in logs

### Compliance

1. **GDPR Compliance**
   - Allow users to opt-out
   - Provide data export
   - Implement data deletion

2. **Privacy Policy**
   - Document data collection
   - Explain notification usage
   - Provide contact information

## Performance Optimization

### Database Optimization

```sql
-- Partition large tables
CREATE TABLE notification_events_2024_01 
PARTITION OF notification_events
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Create materialized view for analytics
CREATE MATERIALIZED VIEW notification_daily_stats AS
SELECT 
  DATE(created_at) as date,
  event_type,
  COUNT(*) as count,
  COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered
FROM notification_events
GROUP BY DATE(created_at), event_type;

-- Refresh daily
CREATE OR REPLACE FUNCTION refresh_notification_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY notification_daily_stats;
END;
$$ LANGUAGE plpgsql;
```

### Edge Function Optimization

1. **Connection Pooling**
   - Reuse database connections
   - Implement connection limits
   - Use prepared statements

2. **Batch Processing**
   - Process notifications in batches
   - Implement parallel processing
   - Use async/await properly

3. **Caching**
   - Cache user preferences
   - Cache templates
   - Use CDN for static assets

## Conclusion

This production-grade push notification system provides:

✅ **Scalable Architecture** - Event-driven design with queue processing
✅ **Reliability** - Retry logic, error handling, and monitoring
✅ **Flexibility** - Multi-channel support and template system
✅ **Security** - Authentication, encryption, and rate limiting
✅ **Observability** - Comprehensive logging and analytics
✅ **Maintainability** - Clear documentation and automated maintenance

Follow this guide for successful deployment and operation of the notification system in production.
