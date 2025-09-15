# PERMANENT SOLUTION FOR EDGE FUNCTIONS

## The Real Problem

After thorough analysis, here's what's actually happening:

1. **Supabase automatically provides these environment variables to edge functions:**
   - `SUPABASE_URL` - Always available
   - `SUPABASE_ANON_KEY` - Always available  
   - `SUPABASE_SERVICE_ROLE_KEY` - Available when deployed

2. **JWT Verification at Gateway Level:**
   - By default, Supabase requires a valid JWT token (anon or service role) for ALL edge function calls
   - This happens BEFORE your function code runs
   - That's why you get "Missing authorization header" errors

3. **Your Keys:**
   ```
   ANON_KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U
   
   SERVICE_ROLE_KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ
   ```

## The Simple Solution

### 1. Deploy Functions with Correct JWT Settings

Functions are already deployed with the right settings:
- `process-notification-queue` - NO JWT verification (for cron jobs)
- `send-push-notification-v1` - NO JWT verification (for cron jobs)
- `inbound-web` - NO JWT verification (for webhooks)
- `inbound-web-auth` - WITH JWT verification (for Chrome extension)

### 2. How Each Function Should Be Called

#### A. From Cron Jobs (Database)
```sql
-- Cron jobs DON'T need authorization because functions have --no-verify-jwt
SELECT net.http_post(
    url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
        'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('action', 'process', 'batch_size', 50)
);
```

#### B. From Chrome Extension (needs user authentication)
```javascript
// Use the ANON key for user authentication
const response = await fetch('https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web-auth', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${userToken}`, // User's JWT token from Supabase auth
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    alias: 'user@durunotes.app',
    title: 'Clipped content',
    text: 'Content here'
  })
});
```

#### C. From Webhooks (no JWT needed)
```bash
# Using query secret (simple)
curl -X POST "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web?secret=test-secret-123" \
  -H "Content-Type: application/json" \
  -d '{"alias": "test", "title": "Test", "text": "Content"}'

# Or using HMAC (more secure)
SIGNATURE=$(echo -n "$TIMESTAMP\n$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex)
curl -X POST "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web" \
  -H "x-clipper-timestamp: $TIMESTAMP" \
  -H "x-clipper-signature: $SIGNATURE" \
  -H "Content-Type: application/json" \
  -d "$BODY"
```

### 3. Fix the Cron Jobs

Since the functions are deployed with `--no-verify-jwt`, cron jobs don't need Authorization headers:

```sql
-- Simple cron job without authentication
SELECT cron.schedule(
    'process-notifications',
    '*/2 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object('action', 'process', 'batch_size', 50)
    );
    $$
);
```

## What Was Wrong Before

1. **Over-complication**: We were trying to use Vault, complex authentication schemes, when Supabase already handles this
2. **Wrong JWT usage**: `inbound-web-auth` expects USER tokens, not service role keys
3. **Misunderstanding --no-verify-jwt**: When a function is deployed with this flag, it doesn't need ANY authorization header

## Current Status

✅ Functions are deployed correctly:
- `inbound-web` - Works with secret parameter: `?secret=test-secret-123`
- `process-notification-queue` - Can be called without auth (has --no-verify-jwt)
- `send-push-notification-v1` - Can be called without auth (has --no-verify-jwt)
- `inbound-web-auth` - Requires user JWT token

## Action Items

1. **Update cron jobs to remove Authorization headers** (they're not needed)
2. **Set the INBOUND_PARSE_SECRET** to a secure value
3. **Update Chrome extension** to use proper user JWT tokens

## Testing

### Test inbound-web (webhook style)
```bash
curl -X POST "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web?secret=test-secret-123" \
  -H "Content-Type: application/json" \
  -d '{"alias": "test", "title": "Test", "text": "Test content"}'
```

### Test process-notification-queue (cron style)
```bash
curl -X POST "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue" \
  -H "Content-Type: application/json" \
  -d '{"action": "process", "batch_size": 1}'
```

### Test from database
```sql
SELECT net.http_post(
    url := 'https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('action', 'process', 'batch_size', 1)
);
```

## The Bottom Line

**IT'S ACTUALLY SIMPLE:**
1. Functions deployed with `--no-verify-jwt` don't need Authorization headers
2. Functions with JWT verification need valid user tokens (not service role keys)
3. Supabase provides all the environment variables automatically
4. Stop overcomplicating it!
