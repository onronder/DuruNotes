# Email Latency Optimization & Instrumentation

## Overview
Comprehensive guide to achieving <3s email delivery latency from SMTP receipt to app display.

## Architecture
```
Provider SMTP → Webhook → Edge Function → Database → App Realtime
   ~1-2s         ~0.5s       <50ms        ~10ms      ~100ms
```

## 1. Edge Function Optimizations (L-OBS & L-FUNC)

### Latency Instrumentation
The optimized edge function (`index_optimized.ts`) measures each hop:

```json
{
  "event": "email_in_latency",
  "msg_id": "message-id-here",
  "t_provider_to_edge_ms": 1200,    // Provider → Edge latency
  "t_edge_to_insert_ms": 35,        // Edge processing time
  "t_total_edge_ms": 37,            // Total edge time
  "project_ref": "your-project",
  "edge_region": "eu-central-1",
  "alias_norm": "user-alias",
  "source": "email_in"
}
```

### Fast Path Implementation (<50ms processing)
- **HMAC Authentication**: Optional but faster than parsing
- **Minimal Parsing**: Only extract required fields
- **No Attachment Processing**: Marked as `attachments_pending`
- **Single DB Query**: Alias lookup only
- **Duplicate Prevention**: Via unique index on `(user_id, message_id)`

### Security Features
- HMAC signature verification (optional)
- Secret-based auth fallback
- Alias normalization (plus addressing removal)
- No plaintext logging

## 2. Provider Configuration (L-PROV)

### Mailgun Setup (Recommended)

#### A. Create EU Domain (for EU Supabase regions)
```bash
# Use EU region to minimize latency
Domain: mg-eu.yourdomain.com
Region: EU (Europe)
```

#### B. Configure Inbound Route
```python
Priority: 1
Filter: match_recipient(".*@mg-eu.yourdomain.com")
Actions: 
  - forward("https://your-project.supabase.co/functions/v1/email_inbox?secret=YOUR_SECRET")
  - stop()  # Prevent further processing
```

#### C. Webhook Settings
- **Type**: Use "Forward" not "Store" (avoids attachment delays)
- **TLS**: Always use HTTPS
- **Retry**: Enable with exponential backoff

### SendGrid Setup

#### A. Inbound Parse Settings
```
Domain: parse.yourdomain.com
URL: https://your-project.supabase.co/functions/v1/email_inbox?secret=YOUR_SECRET
Send Raw: OFF (lighter payload)
Check Incoming Emails: OFF (faster)
POST the raw, full MIME message: OFF
```

#### B. MX Records
```
Priority: 10
Host: parse.yourdomain.com
Points to: mx.sendgrid.net
```

### DNS Configuration
```
# SPF Record (speeds up delivery)
v=spf1 include:mailgun.org include:sendgrid.net ~all

# DKIM (provider-specific)
# Mailgun: k1._domainkey.yourdomain.com
# SendGrid: m1._domainkey.yourdomain.com

# MX Records
10 mx.sendgrid.net  # or mxa.eu.mailgun.org for EU
```

## 3. Monitoring & Debugging

### View Latency Logs
```bash
# Tail edge function logs
supabase functions logs email_inbox --tail

# Filter for latency events
supabase functions logs email_inbox | grep "email_in_latency"

# Parse JSON logs
supabase functions logs email_inbox | jq 'select(.event=="email_in_latency")'
```

### Key Metrics to Monitor
- **t_provider_to_edge_ms**: Should be 1000-2000ms
  - >3000ms: Check provider region, DNS, routing
  - >5000ms: Provider may be virus scanning attachments
  
- **t_edge_to_insert_ms**: Should be <50ms
  - >100ms: Database query slow
  - >200ms: Check Supabase region match
  
- **Duplicate rate**: Check `duplicate: true` in logs
  - High rate may indicate provider retries

### Troubleshooting High Latency

#### Provider → Edge (>3s)
1. **Region Mismatch**: Use provider region closest to Supabase
   - Mailgun EU → Supabase eu-central-1 ✅
   - Mailgun US → Supabase eu-central-1 ❌
   
2. **Attachment Processing**: Provider scanning large attachments
   - Solution: Use "forward" not "store" mode
   - Or: Limit attachment size at provider level
   
3. **DNS Issues**: Slow DNS resolution
   - Solution: Ensure SPF/DKIM pass
   - Check: No graylisting on your domain

#### Edge Processing (>100ms)
1. **Cold Start**: First request after idle
   - Solution: Keep-alive with health checks
   
2. **Database Distance**: Edge region ≠ Database region
   - Solution: Match regions in Supabase dashboard
   
3. **Payload Size**: Large email bodies
   - Solution: Truncate headers, limit text/html size

## 4. Deployment

### Deploy Optimized Function
```bash
cd supabase/functions/email_inbox
chmod +x deploy_optimized.sh
./deploy_optimized.sh
```

### Set Environment Variables
In Supabase Dashboard → Edge Functions → email_inbox → Settings:

```env
INBOUND_PARSE_SECRET=your-webhook-secret
INBOUND_HMAC_SECRET=optional-hmac-key  # For HMAC auth
SUPABASE_PROJECT_REF=your-project-ref  # For logging
```

### Verify Deployment
```bash
# Test with curl
curl -X POST https://your-project.supabase.co/functions/v1/email_inbox?secret=YOUR_SECRET \
  -F "to=test@yourdomain.com" \
  -F "from=sender@example.com" \
  -F "subject=Test" \
  -F "text=Hello"

# Check logs for latency data
supabase functions logs email_inbox --tail
```

## 5. Performance Targets

### Target Latencies (P50)
- **Provider → Edge**: 1-2s
- **Edge Processing**: <50ms  
- **Database Insert**: <10ms
- **Realtime Broadcast**: <100ms
- **Total End-to-End**: <3s

### Acceptable Latencies (P95)
- **Provider → Edge**: <3s
- **Edge Processing**: <100ms
- **Database Insert**: <20ms
- **Realtime Broadcast**: <200ms
- **Total End-to-End**: <4s

## 6. Production Checklist

- [ ] Edge function deployed with instrumentation
- [ ] Provider webhook configured with HTTPS
- [ ] Provider region matches Supabase region
- [ ] DNS: SPF and DKIM records configured
- [ ] Webhook route priority = 1 with stop()
- [ ] Unique index on (user_id, message_id) exists
- [ ] Monitoring dashboard for latency metrics
- [ ] Alerts for P95 > 4s latency
- [ ] HMAC secret configured (optional but recommended)
- [ ] Attachment handling deferred to app

## Appendix: Provider Headers

### Mailgun Headers
```
X-Mailgun-Timestamp: 1234567890
X-Mailgun-Sid: unique-id
X-Mailgun-Variables: custom-vars
```

### SendGrid Headers  
```
X-Sendgrid-Event-Time: 1234567890
X-Sendgrid-ID: unique-id
```

### Standard Headers
```
Date: Mon, 11 Sep 2025 10:30:00 GMT
Message-ID: <unique@example.com>
Received: from smtp.provider.com...
```
