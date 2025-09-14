# Edge Functions Secrets Setup Guide

## Current Secrets in Your Supabase Vault

You already have these secrets set up:
1. ✅ `SUPABASE_URL` 
2. ✅ `SUPABASE_ANON_KEY`
3. ✅ `SUPABASE_SERVICE_ROLE_KEY`
4. ✅ `SUPABASE_DB_URL`
5. ✅ `INBOUND_PARSE_SECRET`
6. ✅ `FCM_SERVICE_ACCOUNT_KEY`

## Missing Secrets That Need to Be Added

Based on the Edge Functions code, you need to add:
1. ❌ `INBOUND_HMAC_SECRET` - For secure webhook verification
2. ❌ `INBOUND_ALLOWED_IPS` - Optional IP allowlist
3. ❌ `SUPABASE_PROJECT_REF` - Your project reference
4. ❌ `LOG_LEVEL` - Logging configuration

## Detailed Secret Explanations

### 1. SUPABASE_URL ✅ (Already Set)
**What it is:** Your Supabase project URL  
**Current value:** `https://jtaedgpxesshdrnbgvjr.supabase.co`  
**Where to find it:** Supabase Dashboard → Settings → API → Project URL  
**Used by:** All Edge Functions for database access

### 2. SUPABASE_ANON_KEY ✅ (Already Set)
**What it is:** Public anonymous key for Supabase  
**Current value:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`  
**Where to find it:** Supabase Dashboard → Settings → API → anon/public key  
**Used by:** Client-side operations (not really needed in Edge Functions)

### 3. SUPABASE_SERVICE_ROLE_KEY ✅ (Already Set)
**What it is:** Secret key for server-side operations (bypasses RLS)  
**Where to find it:** Supabase Dashboard → Settings → API → service_role key  
**Used by:** All Edge Functions for admin operations  
**⚠️ SECURITY:** Never expose this publicly!

### 4. SUPABASE_DB_URL ✅ (Already Set)
**What it is:** Direct PostgreSQL connection string  
**Current value:** Should be `postgresql://postgres:[password]@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres`  
**Where to find it:** Supabase Dashboard → Settings → Database → Connection string  
**Used by:** Not directly by Edge Functions, but useful for migrations

### 5. INBOUND_PARSE_SECRET ✅ (Already Set)
**What it is:** Legacy query string secret for webhook authentication  
**Current value:** You have this set  
**How to generate:** `openssl rand -hex 32`  
**Used by:** Email inbox function (backward compatibility)  
**Note:** This is deprecated in favor of HMAC

### 6. FCM_SERVICE_ACCOUNT_KEY ✅ (Already Set)
**What it is:** Firebase Cloud Messaging service account JSON  
**Where to find it:** 
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings → Service Accounts
4. Click "Generate new private key"
5. Download the JSON file
**Used by:** Push notification functions  
**Format:** Full JSON object as a string

### 7. INBOUND_HMAC_SECRET ❌ (NEEDS TO BE ADDED)
**What it is:** Secret key for HMAC-SHA256 webhook signature verification  
**How to generate:** 
```bash
openssl rand -hex 32
```
**Example value:** `a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890`  
**Used by:** Email inbox function for secure webhook verification  
**Where to configure:** Also needs to be set in SendGrid/Mailgun webhook settings

### 8. INBOUND_ALLOWED_IPS ❌ (OPTIONAL - NEEDS TO BE ADDED)
**What it is:** Comma-separated list of allowed IP addresses for webhooks  
**Example value:** `168.245.22.118,168.245.22.119,168.245.22.120` (SendGrid IPs)  
**Used by:** Email inbox function for IP-based security  
**Note:** Optional but recommended for production

### 9. SUPABASE_PROJECT_REF ❌ (NEEDS TO BE ADDED)
**What it is:** Your Supabase project reference ID  
**Your value:** `jtaedgpxesshdrnbgvjr`  
**Where to find it:** It's in your SUPABASE_URL between `https://` and `.supabase.co`  
**Used by:** Logging and monitoring

### 10. LOG_LEVEL ❌ (OPTIONAL - NEEDS TO BE ADDED)
**What it is:** Controls logging verbosity  
**Recommended value:** `info` for production, `debug` for development  
**Options:** `debug`, `info`, `warn`, `error`  
**Used by:** Common logger module

## Commands to Set Missing Secrets

Run these commands to add the missing secrets:

```bash
# 1. Generate and set HMAC secret
HMAC_SECRET=$(openssl rand -hex 32)
echo "Generated HMAC Secret: $HMAC_SECRET"
supabase secrets set INBOUND_HMAC_SECRET="$HMAC_SECRET"

# 2. Set project reference
supabase secrets set SUPABASE_PROJECT_REF="jtaedgpxesshdrnbgvjr"

# 3. Set log level for production
supabase secrets set LOG_LEVEL="info"

# 4. Optional: Set allowed IPs (example for SendGrid)
# Get current SendGrid IPs from: https://docs.sendgrid.com/for-developers/parsing-email/setting-up-the-inbound-parse-webhook#security-considerations
supabase secrets set INBOUND_ALLOWED_IPS="168.245.22.118,168.245.22.119,168.245.22.120"
```

## Webhook Provider Configuration

### SendGrid Setup
1. Go to Settings → Inbound Parse → Add Host & URL
2. Set URL: `https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/email_inbox`
3. Enable "Post the raw, full MIME message"
4. Add webhook signature:
   - Go to Mail Settings → Event Webhook
   - Enable "Signed Event Webhook Requests"
   - Set Verification Key to your `INBOUND_HMAC_SECRET` value

### Mailgun Setup
1. Go to Receiving → Routes
2. Create new route
3. Expression: `match_recipient(".*@in.durunotes.app")`
4. Action: `forward("https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/email_inbox")`
5. Add webhook signature in webhook settings using your `INBOUND_HMAC_SECRET`

## Verification Steps

After setting the secrets, verify they're working:

```bash
# 1. List all secrets to confirm they're set
supabase secrets list

# 2. Test email webhook with HMAC
curl -X POST https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/email_inbox \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "x-webhook-signature: $(echo -n 'test=data' | openssl dgst -sha256 -hmac 'YOUR_HMAC_SECRET' -hex | cut -d' ' -f2)" \
  -d 'test=data'

# 3. Check Edge Function logs
supabase functions logs email_inbox --tail
supabase functions logs send-push-notification-v1 --tail
```

## Environment File Updates

Update your `/Users/onronder/duru-notes/assets/env/prod.env` to include:

```env
# Add these lines to your prod.env
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
INBOUND_HMAC_SECRET=your-generated-hmac-secret
SUPABASE_PROJECT_REF=jtaedgpxesshdrnbgvjr
FCM_SERVICE_ACCOUNT_KEY=your-fcm-json-here
LOG_LEVEL=info
```

## Security Notes

1. **Never commit secrets to git** - Use `.gitignore` for all `.env` files
2. **Rotate secrets regularly** - Especially after any potential exposure
3. **Use HMAC over query strings** - Query string secrets are visible in logs
4. **Monitor failed authentications** - Check logs for unauthorized access attempts
5. **Keep service role key secret** - It bypasses all RLS policies

## Next Steps

1. Generate and set the HMAC secret
2. Configure your webhook provider (SendGrid/Mailgun) with the HMAC secret
3. Test the webhook endpoint
4. Monitor logs to ensure everything works
5. Plan to deprecate `INBOUND_PARSE_SECRET` once HMAC is working
