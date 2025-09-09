# Email Inbox Testing Guide

## Overview

Your email inbox system is now fully deployed with:
- ✅ Database migration applied (`20250909_in_main_full.sql`)
- ✅ Edge function deployed at `/email_inbox`
- ✅ Flutter app integration via `ClipperInboxService`

## Quick Test

### 1. Update Configuration

Edit `test_email_quick.sh` and set:
```bash
FUNCTION_URL="https://YOUR_PROJECT_REF.functions.supabase.co/email_inbox"
SECRET="YOUR_ACTUAL_SECRET"
ALIAS="note_test1234"  # Or an existing alias from your DB
```

### 2. Run Test
```bash
./test_email_quick.sh
```

This will:
- Send a basic email
- Send an email with attachment
- Test security (wrong secret)
- Show verification queries

## Complete Test Suite

For comprehensive testing, use:
```bash
./test_email_inbox_full.sh
```

This includes:
- ✅ Basic email test
- ✅ Duplicate prevention (same user)
- ✅ Multi-user same Message-ID
- ✅ Attachment handling
- ✅ Security tests
- ✅ Database verification queries

## Expected Behavior

### Edge Function Response
- ✅ `200 OK` - Email accepted (even for duplicates/unknown aliases)
- ✅ `401 Unauthorized` - Wrong secret
- ✅ `405 Method Not Allowed` - GET requests

### Database State

After sending test email:
```sql
-- Check inbox
SELECT * FROM clipper_inbox 
WHERE source_type = 'email_in' 
ORDER BY created_at DESC;

-- Result should show:
-- user_id: (UUID of user owning the alias)
-- source_type: 'email_in'
-- message_id: 'test-123'
-- payload_json: {
--   "to": "note_test1234@in.durunotes.app",
--   "from": "Tester <tester@example.com>",
--   "subject": "Email-In Test",
--   "text": "This is a test email body.",
--   "message_id": "test-123",
--   "attachments": {...} // if any
-- }
```

### App Processing

When `ClipperInboxService` runs (every 30 seconds):

1. **Reads** emails from `clipper_inbox` where `source_type='email_in'`
2. **Creates** encrypted note via `NotesRepository.createOrUpdate()`
3. **Deletes** processed email from inbox

The resulting note will have:
```
Title: Email-In Test
Body: This is a test email body.

---
From: Tester <tester@example.com>
Received: 2025-01-09T10:30:00Z

#Email
```

With metadata:
```json
{
  "source": "email_in",
  "from_email": "Tester <tester@example.com>",
  "received_at": "2025-01-09T10:30:00Z",
  "message_id": "test-123",
  "attachments": {...}
}
```

## Attachment Handling

### Storage Path
Attachments are stored at:
```
inbound-attachments/<user_id>/<timestamp>-<msgid>/filename.ext
```

### Viewing in App
```dart
// Get attachment path from metadata
final path = emailMetadata['attachments']['files'][0]['path'];

// Create signed URL (bucket is private)
final storage = Supabase.instance.client.storage
    .from('inbound-attachments');
final signedUrl = await storage.createSignedUrl(path, 60);

// Display
Image.network(signedUrl);
```

## Security Features

### 1. Secret Token
- Required in query parameter: `?secret=YOUR_SECRET`
- Returns 401 if missing/wrong

### 2. User Isolation
- Unique index on `(user_id, message_id)` prevents cross-user duplicates
- RLS policies ensure users only see their own data
- Storage paths include user_id for isolation

### 3. Unknown Aliases
- Returns 200 but doesn't create inbox entry
- Prevents enumeration attacks

## Troubleshooting

### Email Not Appearing in App

1. **Check inbox table**:
```sql
SELECT COUNT(*) FROM clipper_inbox 
WHERE source_type = 'email_in';
```

2. **Check service is running**:
Look for debug output:
```
clipper inbox processing error: ...
```

3. **Check alias exists**:
```sql
SELECT * FROM inbound_aliases 
WHERE alias = 'note_test1234';
```

### Duplicate Messages

The unique index `idx_clipper_inbox_user_message_id` prevents duplicates per user.
Check logs for: "Duplicate message detected, skipping"

### Attachments Not Uploading

1. **Check bucket exists**:
```sql
SELECT * FROM storage.buckets 
WHERE id = 'inbound-attachments';
```

2. **Check function logs**:
```bash
supabase functions logs email_inbox --tail
```

## Manual Testing via SQL

### Create Test Inbox Entry
```sql
-- Insert test email directly
INSERT INTO clipper_inbox (
  user_id,
  source_type,
  message_id,
  payload_json
) VALUES (
  'YOUR_USER_ID',
  'email_in',
  'manual-test-' || gen_random_uuid(),
  jsonb_build_object(
    'to', 'test@in.durunotes.app',
    'from', 'Manual Test <test@example.com>',
    'subject', 'Manual Test Email',
    'text', 'This is a manually inserted test email.'
  )
);
```

The app should process this within 30 seconds and create a note.

## Performance Monitoring

### Processing Rate
```sql
-- Emails processed per hour
SELECT 
  date_trunc('hour', created_at) as hour,
  COUNT(*) as emails_processed
FROM clipper_inbox 
WHERE source_type = 'email_in'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

### Average Processing Time
Track when emails are created vs deleted to measure processing latency.

## Production Checklist

- [ ] Set production `INBOUND_PARSE_SECRET`
- [ ] Configure SendGrid webhook URL
- [ ] Test with real email to production alias
- [ ] Monitor function logs for first 24 hours
- [ ] Set up alerts for processing failures
- [ ] Document user aliases for support team

## Support Queries

### Get user's email alias
```sql
SELECT alias || '@in.durunotes.app' as email_address
FROM inbound_aliases
WHERE user_id = 'USER_ID';
```

### Check if email was received
```sql
SELECT * FROM clipper_inbox
WHERE payload_json->>'from' LIKE '%user@example.com%'
ORDER BY created_at DESC;
```

### Find failed processing attempts
Check app logs for "clipper item failed" messages with the inbox ID.
