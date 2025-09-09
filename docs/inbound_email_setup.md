# Inbound Email Setup Guide

This guide covers the complete setup and configuration of the inbound email feature, allowing users to send or forward emails to their notes.

## Overview

The inbound email feature enables users to:
- Send or forward emails to a unique email address
- Have email content automatically captured in their notes
- Include attachments that are securely stored
- Access emails through the app's clipper inbox

## Architecture

```
User Email → SendGrid (MX) → Inbound Parse Webhook → Supabase Edge Function → Database + Storage
```

## Prerequisites

1. **Supabase Project**: Active Supabase project with database access
2. **SendGrid Account**: For email parsing (free tier is sufficient)
3. **Custom Domain**: A domain or subdomain for receiving emails
4. **Supabase CLI**: Installed and configured

## Setup Steps

### 1. Database Setup

Run the migration scripts to create necessary tables and functions:

```bash
# Apply database migrations
supabase db push

# Or run migrations individually:
supabase db query -f supabase/migrations/20241231_inbound_email_aliases.sql
supabase db query -f supabase/migrations/20241231_inbound_attachments_storage.sql
```

This creates:
- `inbound_aliases` table for user email mappings
- Storage bucket policies for attachments
- Helper functions for alias generation

### 2. SendGrid Configuration

#### A. Domain Authentication

1. Log into SendGrid Dashboard
2. Navigate to **Settings → Sender Authentication**
3. Click **Authenticate Your Domain**
4. Follow the DNS configuration steps
5. Add the provided DNS records to your domain registrar

#### B. Inbound Parse Setup

1. Go to **Settings → Inbound Parse**
2. Click **Add Host & URL**
3. Configure:
   - **Subdomain**: `notes` (or your chosen subdomain)
   - **Domain**: Select your authenticated domain
   - **Destination URL**: Will be set after deploying the function
4. Leave **Spam Check** and **Raw** options unchecked
5. Save the configuration

#### C. MX Records

Add MX records to your DNS:

```
Type: MX
Host: notes (or your subdomain)
Priority: 10
Value: mx.sendgrid.net
TTL: 3600
```

Verify DNS propagation:
```bash
dig MX notes.yourdomain.com
```

### 3. Deploy Edge Function

#### A. Set Environment Variables

Create `.env.local` in the project root:

```env
# Generate a secure random secret
INBOUND_PARSE_SECRET=your-secure-random-secret-here
INBOUND_EMAIL_DOMAIN=notes.yourdomain.com
```

#### B. Deploy Function

```bash
# Make the deployment script executable
chmod +x supabase/functions/deploy_inbound_email.sh

# Deploy the function
./supabase/functions/deploy_inbound_email.sh
```

The script will:
- Deploy the edge function
- Set the secret in Supabase
- Output the webhook URL

#### C. Update SendGrid Webhook

1. Return to SendGrid Inbound Parse settings
2. Edit your configuration
3. Set **Destination URL** to:
   ```
   https://YOUR_PROJECT_ID.functions.supabase.co/inbound-email?secret=YOUR_SECRET
   ```

### 4. Storage Bucket Setup

Create the storage bucket for attachments:

```sql
-- Run in Supabase SQL Editor
INSERT INTO storage.buckets (id, name, public)
VALUES ('inbound-attachments', 'inbound-attachments', false);
```

Or via Supabase Dashboard:
1. Go to **Storage**
2. Create new bucket named `inbound-attachments`
3. Set as **Private** (uses signed URLs)

### 5. Generate User Aliases

Users need unique email aliases. This can be done:

#### Option A: Automatic on User Creation

Add a database trigger:

```sql
CREATE OR REPLACE FUNCTION public.create_user_alias()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Generate alias for new user
  PERFORM public.generate_user_alias(NEW.id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER create_alias_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_user_alias();
```

#### Option B: On-Demand via App

Use the provided Flutter service:

```dart
final emailService = InboundEmailService(supabase);
final userEmail = await emailService.getUserInboundEmail();
print('Your email address: $userEmail');
```

## Testing

### 1. Local Testing

Run the test script:

```bash
# Make executable
chmod +x supabase/functions/test_inbound_email.sh

# Run tests
./supabase/functions/test_inbound_email.sh
```

### 2. End-to-End Testing

1. **Get a test user's alias**:
   ```sql
   SELECT * FROM inbound_aliases LIMIT 1;
   ```

2. **Send a test email**:
   - To: `test_abc123@notes.yourdomain.com`
   - Subject: "Test Email"
   - Body: "This is a test"
   - Attach a small file

3. **Verify receipt**:
   ```sql
   SELECT * FROM clipper_inbox 
   WHERE source_type = 'email_in' 
   ORDER BY created_at DESC;
   ```

4. **Check logs**:
   ```bash
   supabase functions logs inbound-email --tail
   ```

## Flutter Integration

### Display Inbox

```dart
// In your inbox widget
class EmailInboxWidget extends StatelessWidget {
  final emailService = InboundEmailService(Supabase.instance.client);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InboundEmail>>(
      future: emailService.getInboundEmails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final email = snapshot.data![index];
            return ListTile(
              title: Text(email.subject ?? 'No subject'),
              subtitle: Text(email.from ?? 'Unknown sender'),
              trailing: email.hasAttachments 
                ? Icon(Icons.attach_file)
                : null,
              onTap: () => _convertToNote(email),
            );
          },
        );
      },
    );
  }
  
  void _convertToNote(InboundEmail email) async {
    await emailService.convertEmailToNote(email);
    // Refresh the list
  }
}
```

### Show User's Email Address

```dart
// In settings or profile
class EmailAddressDisplay extends StatelessWidget {
  final emailService = InboundEmailService(Supabase.instance.client);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: emailService.getUserInboundEmail(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('Generating email address...');
        }
        
        return Column(
          children: [
            Text('Forward emails to:'),
            SelectableText(
              snapshot.data!,
              style: TextStyle(fontFamily: 'monospace'),
            ),
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: snapshot.data!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
```

## Monitoring & Maintenance

### Daily Tasks

1. **Check function health**:
   ```bash
   supabase functions logs inbound-email --tail
   ```

2. **Monitor inbox size**:
   ```sql
   SELECT user_id, COUNT(*) as email_count
   FROM clipper_inbox
   WHERE source_type = 'email_in'
   GROUP BY user_id;
   ```

### Automated Cleanup

The `purge_stale_clipper_inbox` function removes emails older than 48 hours. Schedule it:

```sql
-- Using pg_cron (if available)
SELECT cron.schedule(
  'purge-old-emails',
  '0 2 * * *', -- Daily at 2 AM
  'SELECT public.purge_stale_clipper_inbox();'
);
```

### Storage Management

Monitor and clean old attachments:

```sql
-- Find old attachments
SELECT 
  name,
  created_at,
  (metadata->>'size')::int as size_bytes
FROM storage.objects
WHERE bucket_id = 'inbound-attachments'
  AND created_at < NOW() - INTERVAL '30 days';
```

## Security Considerations

1. **Secret Management**:
   - Never expose `INBOUND_PARSE_SECRET` in client code
   - Rotate secrets periodically
   - Use different secrets for dev/staging/production

2. **Email Validation**:
   - The function validates the secret on every request
   - Unknown aliases are ignored (no user data exposed)
   - Message-ID prevents duplicate processing

3. **Attachment Security**:
   - Files stored in private bucket
   - Access requires authentication
   - Signed URLs expire after 1 hour

4. **Rate Limiting**:
   - SendGrid has built-in rate limits
   - Consider adding custom rate limiting if needed
   - Monitor for abuse patterns

## Troubleshooting

### Common Issues

#### Emails Not Arriving

1. **Check MX records**:
   ```bash
   dig MX notes.yourdomain.com
   nslookup -type=mx notes.yourdomain.com
   ```

2. **Verify SendGrid webhook**:
   - Correct URL with secret
   - Function is deployed and running
   - Check SendGrid activity feed

#### Function Errors

1. **Check logs**:
   ```bash
   supabase functions logs inbound-email
   ```

2. **Common errors**:
   - `401 Unauthorized`: Wrong secret
   - `Database error`: Check RLS policies
   - `Storage error`: Verify bucket exists

#### Missing Attachments

1. **Check storage bucket**:
   ```sql
   SELECT * FROM storage.buckets WHERE id = 'inbound-attachments';
   ```

2. **Verify file upload**:
   - Check function logs for upload errors
   - Ensure file size < 50MB limit

### Debug Mode

Enable verbose logging in the function:

```typescript
// In index.ts
const DEBUG = Deno.env.get('DEBUG') === 'true';

if (DEBUG) {
  console.log('Received form data:', Object.fromEntries(formData));
}
```

Deploy with debug:
```bash
supabase secrets set DEBUG=true
supabase functions deploy inbound-email
```

## Performance Optimization

### Database Indexes

Already created:
- `idx_clipper_inbox_user_created` - Fast user queries
- `idx_clipper_inbox_message_id` - Duplicate prevention
- `idx_inbound_aliases_alias` - Fast alias lookup

### Function Optimization

1. **Parallel Processing**:
   - Upload attachments concurrently
   - Use Promise.all() for multiple operations

2. **Caching**:
   - Consider caching user aliases in Redis
   - Cache storage URLs if using frequently

3. **Batch Operations**:
   - Process multiple emails in batch if volume increases
   - Use database transactions for consistency

## Future Enhancements

1. **Email Filtering**:
   - Spam score threshold
   - Sender whitelist/blacklist
   - Subject line filters

2. **Rich Processing**:
   - Extract links from emails
   - Parse structured data (receipts, confirmations)
   - OCR for image attachments

3. **User Features**:
   - Multiple aliases per user
   - Custom alias names
   - Email forwarding rules

4. **Integration**:
   - Webhook notifications
   - Zapier/Make integration
   - Email reply capability

## Support

For issues or questions:
1. Check function logs first
2. Review this documentation
3. Test with the provided scripts
4. Contact support with logs and error messages
