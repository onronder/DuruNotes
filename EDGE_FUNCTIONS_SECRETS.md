# Edge Functions Secrets Management

## Overview

This document describes the secrets management strategy for Edge Functions using Supabase Vault and environment variables.

## Required Secrets

### 1. Core Supabase Secrets
- **SUPABASE_URL**: Your Supabase project URL
- **SUPABASE_SERVICE_ROLE_KEY**: Service role key for backend operations
- **SUPABASE_ANON_KEY**: Anonymous key for public operations

### 2. Email Inbox Secrets
- **INBOUND_HMAC_SECRET**: HMAC secret for webhook signature verification
- **INBOUND_ALLOWED_IPS**: Comma-separated list of allowed IP addresses (optional)
- **INBOUND_PARSE_SECRET**: Legacy query string secret (deprecated, for backward compatibility)

### 3. Push Notification Secrets
- **FCM_SERVICE_ACCOUNT_KEY**: Firebase Cloud Messaging service account JSON
- **FCM_PROJECT_ID**: Firebase project ID (extracted from service account)

### 4. Logging Configuration
- **LOG_LEVEL**: Logging level (debug, info, warn, error)

## Setting Secrets

### Using Supabase CLI

```bash
# Set individual secrets
supabase secrets set INBOUND_HMAC_SECRET="your-hmac-secret-here"
supabase secrets set INBOUND_ALLOWED_IPS="192.168.1.1,10.0.0.1"
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'

# Set from .env file
supabase secrets set --env-file .env.production

# List all secrets
supabase secrets list

# Delete a secret
supabase secrets unset SECRET_NAME
```

### Using Supabase Dashboard

1. Navigate to your project in Supabase Dashboard
2. Go to Settings → Edge Functions
3. Click on "Secrets" tab
4. Add or update secrets using the UI

## Secret Rotation Procedures

### 1. HMAC Secret Rotation

```bash
# Step 1: Generate new HMAC secret
NEW_SECRET=$(openssl rand -hex 32)
echo "New HMAC Secret: $NEW_SECRET"

# Step 2: Update Edge Function to accept both old and new secrets temporarily
# (Deploy version that checks both secrets)

# Step 3: Update webhook provider with new secret
# (Configure SendGrid/Mailgun with new HMAC key)

# Step 4: Set new secret in Supabase
supabase secrets set INBOUND_HMAC_SECRET="$NEW_SECRET"

# Step 5: Monitor logs for successful authentications

# Step 6: Remove old secret support after verification
# (Deploy final version that only accepts new secret)
```

### 2. FCM Service Account Rotation

```bash
# Step 1: Create new service account in Firebase Console
# Download the JSON key file

# Step 2: Set new service account in Supabase
supabase secrets set FCM_SERVICE_ACCOUNT_KEY="$(cat new-service-account.json)"

# Step 3: Test push notifications

# Step 4: Delete old service account from Firebase Console
```

### 3. Supabase Service Role Key Rotation

```bash
# Step 1: Generate new service role key in Supabase Dashboard
# Settings → API → Service role key → Regenerate

# Step 2: Update all Edge Functions
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="new-service-role-key"

# Step 3: Update any external services using the key

# Step 4: Monitor for authentication errors
```

## Environment-Specific Configuration

### Development

```env
# .env.local
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your-local-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-local-service-key
INBOUND_HMAC_SECRET=dev-hmac-secret
LOG_LEVEL=debug
```

### Staging

```env
# .env.staging
SUPABASE_URL=https://staging-project.supabase.co
SUPABASE_ANON_KEY=staging-anon-key
SUPABASE_SERVICE_ROLE_KEY=staging-service-key
INBOUND_HMAC_SECRET=staging-hmac-secret
LOG_LEVEL=info
```

### Production

```env
# .env.production
SUPABASE_URL=https://production-project.supabase.co
SUPABASE_ANON_KEY=production-anon-key
SUPABASE_SERVICE_ROLE_KEY=production-service-key
INBOUND_HMAC_SECRET=production-hmac-secret
INBOUND_ALLOWED_IPS=sendgrid-ip-1,sendgrid-ip-2
LOG_LEVEL=warn
```

## Security Best Practices

### 1. Secret Generation

```bash
# Generate strong random secrets
openssl rand -hex 32  # For HMAC secrets
openssl rand -base64 32  # For API keys
uuidgen  # For unique identifiers
```

### 2. Secret Storage

- **Never commit secrets to version control**
- Use `.gitignore` for all `.env` files
- Store production secrets only in Supabase Vault
- Use separate secrets for each environment
- Implement secret expiration policies

### 3. Access Control

- Limit secret access to necessary functions only
- Use service role keys only for backend operations
- Implement IP allowlisting for webhooks
- Monitor secret usage in logs

### 4. Audit and Monitoring

```sql
-- Query to monitor Edge Function invocations
SELECT 
  function_name,
  status,
  COUNT(*) as invocations,
  AVG(execution_time_ms) as avg_time_ms
FROM edge_function_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY function_name, status
ORDER BY invocations DESC;
```

## Migration from Legacy Secrets

### Phase 1: Dual Authentication (Current)
- Functions accept both HMAC and query string secrets
- Log which authentication method is used
- Monitor for clients still using legacy auth

### Phase 2: Deprecation Warning
- Add deprecation headers to responses using legacy auth
- Send notifications to webhook providers
- Set deadline for migration

### Phase 3: HMAC Only
- Remove query string secret support
- Update documentation
- Clean up legacy code

## Troubleshooting

### Common Issues

1. **"Missing Supabase configuration"**
   - Ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set
   - Check secret names for typos

2. **"Invalid HMAC signature"**
   - Verify HMAC secret matches webhook provider
   - Check for trailing whitespace in secret
   - Ensure correct signature header name

3. **"FCM token error"**
   - Validate FCM_SERVICE_ACCOUNT_KEY JSON format
   - Check service account permissions in Firebase

### Debug Commands

```bash
# View Edge Function logs
supabase functions logs email_inbox --tail

# Test Edge Function locally
supabase functions serve email_inbox --env-file .env.local

# Verify secrets are set
supabase secrets list | grep INBOUND

# Test webhook signature
curl -X POST https://your-project.supabase.co/functions/v1/email_inbox \
  -H "x-webhook-signature: $(echo -n 'test-payload' | openssl dgst -sha256 -hmac 'your-secret' -hex)" \
  -d 'test-payload'
```

## Compliance and Security

### Data Protection
- All secrets are encrypted at rest in Supabase Vault
- Secrets are only accessible to Edge Functions runtime
- No secrets are logged or exposed in responses

### Audit Trail
- All secret changes are logged in Supabase audit logs
- Monitor secret access patterns for anomalies
- Regular security reviews of secret usage

### Incident Response
1. Immediately rotate compromised secrets
2. Review access logs for unauthorized usage
3. Update all dependent services
4. Document incident and remediation steps

## References

- [Supabase Edge Functions Secrets](https://supabase.com/docs/guides/functions/secrets)
- [Firebase Cloud Messaging Setup](https://firebase.google.com/docs/cloud-messaging)
- [HMAC Best Practices](https://www.rfc-editor.org/rfc/rfc2104)
