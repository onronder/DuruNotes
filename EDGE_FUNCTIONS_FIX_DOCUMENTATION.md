# Edge Functions Authentication Fix Documentation

## Overview

This document describes the comprehensive fixes applied to resolve the "Missing Authorization Header" issues with Duru Notes edge functions, based on engineering-level analysis and Supabase best practices.

## Problem Summary

The edge functions were failing with 401 "Missing Authorization Header" errors because:

1. **Gateway-level JWT verification**: Supabase's gateway rejects requests without valid Authorization headers before they reach the function code
2. **Missing `source_type` field**: The `clipper_inbox` table has a NOT NULL constraint on `source_type` that wasn't being satisfied
3. **Insecure secret storage**: Service keys were hardcoded in SQL migrations
4. **Duplicate functions**: Maintaining both `inbound-web` and `inbound-web-auth` led to inconsistencies
5. **Poor error handling**: Generic error messages made debugging difficult

## Applied Solutions

### 1. Fixed Chrome Extension Integration

**File**: `supabase/functions/inbound-web-auth/index.ts`

- Added `source_type: "web"` to all database inserts
- Enhanced error handling with specific database constraint violations
- Improved logging for debugging

### 2. Secure Secret Storage with Vault

**File**: `supabase/migrations/20250915_fix_edge_functions_auth.sql`

- Implemented Supabase Vault for secure secret storage
- Moved all sensitive keys from hardcoded values to encrypted vault
- Created helper functions for secret access

**Vault Secrets Structure**:
```sql
- service_key: Supabase service role key
- anon_key: Supabase anonymous key  
- project_url: Supabase project URL
```

### 3. Updated Cron Jobs with Authorization Headers

**Implementation**: All cron jobs now use `pg_net.http_post` with proper headers:

```sql
SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_key'),
        'x-source', 'pg_cron'
    ),
    body := jsonb_build_object('action', 'process', 'batch_size', 50)
);
```

**Scheduled Jobs**:
- `process-notification-queue`: Every 2 minutes
- `retry-stuck-notifications`: Every 10 minutes
- `cleanup-old-notifications`: Daily at 3 AM
- `notification-health-check`: Every 5 minutes

### 4. Unified Web Clipper Function

**File**: `supabase/functions/inbound-web-unified/index.ts`

Merged `inbound-web` and `inbound-web-auth` into a single function that:

- Supports both JWT authentication (Chrome extension) and HMAC authentication (webhooks)
- Handles user alias creation and management
- Provides detailed error messages for different failure scenarios
- Includes comprehensive logging

**Authentication Flow**:
1. Try JWT authentication first (for Chrome extension)
2. Fall back to HMAC signature verification (for webhooks)
3. Support legacy query string secret (deprecated)

### 5. Enhanced Error Handling

**Files**: 
- `supabase/functions/common/errors.ts`
- `supabase/functions/common/logger.ts`

**Error Types**:
- `ValidationError` (400): Invalid input data
- `AuthenticationError` (401): Missing or invalid credentials
- `AuthorizationError` (403): Insufficient permissions
- `NotFoundError` (404): Resource not found
- `ServerError` (500): Internal server errors
- `ServiceUnavailableError` (503): Temporary unavailability

**Database-specific Error Handling**:
```typescript
if (clipError.code === "23502") { // NOT NULL violation
    throw new ValidationError(`Missing required field: ${clipError.details}`);
} else if (clipError.code === "23503") { // Foreign key violation
    throw new ValidationError("Invalid user reference");
} else if (clipError.code === "23505") { // Unique violation
    throw new ValidationError("Duplicate clip detected");
}
```

## Deployment Instructions

### Prerequisites

1. Ensure you have a `.env` file with:
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_ANON_KEY=your_anon_key
DATABASE_URL=postgresql://...
INBOUND_PARSE_SECRET=your_hmac_secret
```

2. Install Supabase CLI:
```bash
npm install -g supabase
```

### Step 1: Setup Vault Secrets

```bash
./setup_vault_secrets.sh
```

This script:
- Reads your `.env` file
- Creates vault entries for secure secret storage
- Verifies the secrets are properly stored

### Step 2: Deploy All Fixes

```bash
./deploy_edge_function_fixes.sh
```

This script:
- Applies database migrations
- Deploys updated edge functions
- Sets edge function environment variables
- Runs basic connectivity tests

### Step 3: Run Comprehensive Tests

```bash
./test_edge_functions_comprehensive.sh
```

This validates:
- Diagnostic endpoint connectivity
- JWT authentication flow
- HMAC authentication flow
- Notification queue processing
- Error handling
- CORS support

## Testing Individual Components

### Test Diagnostic Endpoint

```bash
curl -X POST "${SUPABASE_URL}/functions/v1/test-diagnostic" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Test Web Clipper with JWT

```javascript
// In Chrome extension
const response = await fetch(`${SUPABASE_URL}/functions/v1/inbound-web-unified`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${userToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    alias: 'user@durunotes.app',
    title: 'Test Clip',
    text: 'Content',
    url: 'https://example.com'
  })
});
```

### Test Web Clipper with HMAC

```bash
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BODY='{"alias":"test@durunotes.app","title":"Test","text":"Content"}'
MESSAGE="${TIMESTAMP}\n${BODY}"
SIGNATURE=$(echo -e "$MESSAGE" | openssl dgst -sha256 -hmac "$INBOUND_PARSE_SECRET" -hex | cut -d' ' -f2)

curl -X POST "${SUPABASE_URL}/functions/v1/inbound-web-unified" \
  -H "Content-Type: application/json" \
  -H "x-clipper-timestamp: ${TIMESTAMP}" \
  -H "x-clipper-signature: ${SIGNATURE}" \
  -d "${BODY}"
```

### Test Database Functions

```sql
-- Test edge function connectivity
SELECT * FROM public.test_edge_function_auth();

-- Manually trigger notification processing
SELECT * FROM public.manual_process_notifications(10);

-- Check vault secrets status
SELECT * FROM public.vault_secrets_status;

-- View active cron jobs
SELECT jobname, schedule, active 
FROM cron.job 
WHERE jobname LIKE '%notification%';
```

## Monitoring and Debugging

### View Edge Function Logs

```bash
# View logs for specific function
supabase functions logs inbound-web-unified --project-ref YOUR_PROJECT_REF

# Follow logs in real-time
supabase functions logs inbound-web-unified --project-ref YOUR_PROJECT_REF --follow
```

### Check Notification Queue Status

```sql
-- Pending notifications
SELECT COUNT(*), MIN(scheduled_for) 
FROM notification_events 
WHERE status = 'pending';

-- Stuck notifications
SELECT * FROM notification_events 
WHERE status = 'processing' 
AND processed_at < NOW() - INTERVAL '5 minutes';

-- Recent failures
SELECT event_type, error_message, COUNT(*) 
FROM notification_events 
WHERE status = 'failed' 
AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY event_type, error_message;
```

### Health Check Query

```sql
SELECT * FROM notification_health_checks 
ORDER BY check_time DESC 
LIMIT 10;
```

## Troubleshooting

### Issue: "Missing Authorization Header" Error

**Cause**: Request doesn't include valid JWT or service role key

**Solution**: 
1. Ensure Authorization header is present: `Bearer <token>`
2. Verify token is not expired
3. For cron jobs, check vault secrets are configured

### Issue: "Missing required field: source_type" Error

**Cause**: Database insert missing required `source_type` field

**Solution**: Ensure all `clipper_inbox` inserts include `source_type: "web"`

### Issue: Cron Jobs Not Running

**Cause**: Missing or invalid Authorization headers in pg_net calls

**Solution**:
1. Check vault secrets: `SELECT * FROM public.vault_secrets_status;`
2. Verify cron jobs are active: `SELECT * FROM cron.job WHERE active = true;`
3. Update secrets if needed: `UPDATE vault.secrets SET secret = 'new_key' WHERE name = 'service_key';`

### Issue: HMAC Signature Verification Fails

**Cause**: Incorrect signature calculation or expired timestamp

**Solution**:
1. Ensure timestamp is within 5 minutes
2. Verify HMAC secret matches between client and server
3. Check signature calculation includes newline between timestamp and body

## Security Best Practices

1. **Never hardcode secrets** - Use Vault or environment variables
2. **Rotate keys regularly** - Update vault secrets periodically
3. **Use appropriate authentication** - JWT for user actions, service keys for system tasks
4. **Validate all inputs** - Check for required fields and data types
5. **Log security events** - Track authentication attempts and failures
6. **Limit token scope** - Use anon key for auth, service key only when needed

## Migration from Old Functions

### For Chrome Extension

Update the endpoint URL:
```javascript
// Old
const url = `${SUPABASE_URL}/functions/v1/inbound-web-auth`;

// New
const url = `${SUPABASE_URL}/functions/v1/inbound-web-unified`;
```

### For Webhooks

No changes needed - HMAC authentication is fully supported in the unified function.

### For Database Queries

Update any direct calls to use the new notification processing:
```sql
-- Old
SELECT send_push_notification_immediate(event_id);

-- New
SELECT public.manual_process_notifications(1);
```

## Performance Considerations

1. **Batch Processing**: Process notifications in batches of 50 for optimal performance
2. **Cleanup Schedule**: Run cleanup during off-peak hours (3 AM)
3. **Retry Logic**: Stuck notifications are retried every 10 minutes
4. **Connection Pooling**: Edge functions use connection pooling automatically
5. **Caching**: Vault secrets are cached for performance

## Future Improvements

1. **Rate Limiting**: Implement per-user rate limits for web clipping
2. **Webhook Retries**: Add exponential backoff for failed webhook deliveries
3. **Metrics Dashboard**: Create Grafana dashboard for monitoring
4. **A/B Testing**: Support for testing different notification strategies
5. **Multi-region**: Deploy edge functions to multiple regions for lower latency

## Support

For issues or questions:
1. Check the logs: `supabase functions logs`
2. Review this documentation
3. Test with the diagnostic endpoint
4. Check database health: `SELECT * FROM notification_health_checks`

## Conclusion

These fixes ensure:
- ✅ Proper authentication for all edge functions
- ✅ Secure secret storage using Vault
- ✅ Reliable cron job execution
- ✅ Comprehensive error handling
- ✅ Unified, maintainable codebase

The system is now production-ready with proper security, monitoring, and error handling in place.
