# Web Clipper Troubleshooting Guide

## Overview

The web clipper feature allows users to save content from web pages directly to their DuruNotes inbox using a Chrome extension. This guide helps diagnose and fix common issues.

## Architecture Overview

1. **Chrome Extension** → sends clip data to →
2. **Supabase Edge Function** (`inbound-web`) → inserts into →
3. **Database** (`clipper_inbox` table) → polled by →
4. **Flutter App** (`ClipperInboxService`) → creates notes

## Common Issues and Solutions

### Issue 1: Web Clips Not Appearing in Inbox

#### Symptom
- Extension shows "Saved successfully" but clips don't appear in the app

#### Diagnosis Steps

1. **Check if the clip reached the database:**
   ```sql
   -- In Supabase SQL Editor
   SELECT * FROM clipper_inbox 
   WHERE source_type = 'web' 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

2. **Check edge function logs:**
   ```bash
   supabase functions logs inbound-web --tail
   ```
   Look for:
   - "Unknown alias" messages (alias doesn't exist)
   - "DB insert failed" (database error)
   - "Authentication failed" (secret mismatch)

#### Common Causes & Fixes

**Cause A: Alias doesn't exist**
- **Solution**: User must open Email Inbox in the app at least once to create their alias
- The alias is created automatically on first inbox access

**Cause B: Wrong alias format in extension**
- **Problem**: User entered `note_abc123@in.durunotes.app` instead of just `note_abc123`
- **Solution**: Update extension settings to use only the alias code
- **Note**: The latest edge function update handles both formats

**Cause C: Secret mismatch**
- **Solution**: Verify `INBOUND_PARSE_SECRET` matches between:
  - Edge function environment: `supabase secrets list`
  - Chrome extension settings

### Issue 2: Clips Appear But Don't Convert to Notes

#### Symptom
- Clips visible in database but not in app inbox UI

#### Diagnosis
```sql
-- Check if clips are being fetched
SELECT id, user_id, source_type, created_at 
FROM clipper_inbox 
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC;
```

#### Solution
- Ensure app is updated to latest version that includes web clip support
- The `ClipperInboxService` should be polling every 30 seconds
- Manual refresh: Open inbox and tap refresh icon

### Issue 3: Authentication Errors (401)

#### Symptom
- Extension shows error notifications
- Function logs show "Authentication failed"

#### Solution
1. Set the secret in Supabase:
   ```bash
   supabase secrets set INBOUND_PARSE_SECRET=your-secret-value
   ```

2. Update extension with same secret value

3. Verify deployment:
   ```bash
   supabase functions deploy inbound-web --no-verify-jwt
   ```

## Complete Setup Checklist

### 1. Server-Side Setup
- [ ] Edge function deployed: `supabase functions deploy inbound-web`
- [ ] Secret configured: `supabase secrets set INBOUND_PARSE_SECRET=...`
- [ ] Database has `clipper_inbox` table (created by migrations)
- [ ] User has entry in `inbound_aliases` table

### 2. Extension Configuration
- [ ] Alias: Just the code (e.g., `note_abc123`)
- [ ] Secret: Matches `INBOUND_PARSE_SECRET`
- [ ] Functions URL: `https://PROJECT-REF.functions.supabase.co` (no trailing slash)

### 3. App Configuration
- [ ] Latest app version with web clip support
- [ ] User has opened Email Inbox at least once
- [ ] Background sync is enabled

## Testing the Flow

### 1. Test Edge Function Directly
```bash
# Get your alias from the app
ALIAS="note_abc123"
SECRET="your-secret-value"
PROJECT_REF="your-project-ref"

# Test with curl
curl -X POST \
  "https://$PROJECT_REF.functions.supabase.co/inbound-web?secret=$SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "'$ALIAS'",
    "title": "Test Clip",
    "text": "This is a test web clip",
    "url": "https://example.com",
    "clipped_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }'
```

Expected response: `{"status":"ok","message":"Clip saved successfully"}`

### 2. Verify Database Insert
```sql
SELECT * FROM clipper_inbox 
WHERE payload_json->>'title' = 'Test Clip'
ORDER BY created_at DESC;
```

### 3. Check App Processing
- Open DuruNotes app
- Go to Email Inbox
- Tap refresh icon
- Test clip should appear

## Debug Information to Collect

When reporting issues, provide:

1. **Extension version**: Check in `chrome://extensions`
2. **Edge function logs**: Last 50 lines
3. **Database query results**: Clips in last 24 hours
4. **App version**: From app settings
5. **User's alias**: From Email Inbox screen (without domain)

## Code Locations

- **Edge Function**: `/supabase/functions/inbound-web/index.ts`
- **Extension**: `/tools/web-clipper-extension/`
- **App Service**: `/lib/services/clipper_inbox_service.dart`
- **Inbox UI**: `/lib/ui/inbound_email_inbox_widget.dart`

## Recent Updates (September 2025)

1. **Edge function**: Now strips domain from alias if included
2. **App services**: Support both `email_in` and `web` source types
3. **UI**: Shows unified inbox with icons distinguishing emails vs web clips
4. **Processing**: Web clips tagged with `#Web` instead of `#Email`

## Contact Support

If issues persist after following this guide:
1. Check function logs for specific error messages
2. Verify all components are on latest versions
3. Test with curl command to isolate the issue
4. Include debug information when requesting help
