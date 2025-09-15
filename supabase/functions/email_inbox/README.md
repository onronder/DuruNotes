# Inbound Email Function

This Supabase Edge Function handles incoming emails from SendGrid's Inbound Parse webhook.

## Quick Start

### 1. Deploy the Function

```bash
# From project root
./supabase/functions/deploy_inbound_email.sh
```

### 2. Configure SendGrid

Set the Inbound Parse webhook URL to:
```
https://YOUR_PROJECT_ID.functions.supabase.co/inbound-email?secret=YOUR_SECRET
```

### 3. Test the Function

```bash
# Run test suite
./supabase/functions/test_inbound_email.sh

# Check logs
supabase functions logs inbound-email --tail
```

## Environment Variables

Required environment variables (set via Supabase secrets):

- `INBOUND_PARSE_SECRET`: Secret token for webhook authentication
- `SUPABASE_URL`: Auto-set by Supabase
- `SUPABASE_SERVICE_ROLE_KEY`: Auto-set by Supabase

## How It Works

1. **Receives Email**: SendGrid POSTs email data to the function
2. **Validates Secret**: Checks the secret query parameter
3. **Parses Recipient**: Extracts the email alias from the recipient address
4. **Looks Up User**: Finds the user ID from the `inbound_aliases` table
5. **Processes Attachments**: Uploads attachments to Supabase Storage
6. **Stores Email**: Inserts email data into `clipper_inbox` table

## Database Tables

### inbound_aliases
- Maps email aliases to user IDs
- One alias per user
- Generated automatically or on-demand

### clipper_inbox
- Stores incoming emails as JSON
- RLS policies allow users to view/delete their own emails
- Includes `message_id` for duplicate prevention

## Storage

Attachments are stored in the `inbound-attachments` bucket:
- Private bucket (requires auth)
- Organized by user ID and timestamp
- 50MB file size limit

## Email Format

Emails are stored with this JSON structure:

```json
{
  "to": "alias@domain.com",
  "from": "sender@example.com",
  "subject": "Email Subject",
  "text": "Plain text body",
  "html": "<p>HTML body</p>",
  "message_id": "unique-message-id",
  "attachments": {
    "count": 1,
    "files": [
      {
        "filename": "document.pdf",
        "type": "application/pdf",
        "size": 1024,
        "url": "https://..."
      }
    ]
  }
}
```

## Security

- Secret token validation on every request
- Service role key for database access
- RLS policies protect user data
- Unknown aliases are silently ignored
- Message-ID prevents duplicate processing

## Monitoring

```bash
# View function logs
supabase functions logs inbound-email

# Check inbox contents
supabase db query "SELECT * FROM clipper_inbox WHERE source_type = 'email_in'"

# Check user aliases
supabase db query "SELECT * FROM inbound_aliases"
```

## Troubleshooting

### Emails Not Arriving
1. Check MX records point to SendGrid
2. Verify webhook URL in SendGrid settings
3. Check function logs for errors

### Authentication Errors
1. Verify INBOUND_PARSE_SECRET matches
2. Check secret is in query parameter
3. Ensure function has service role key

### Storage Errors
1. Verify `inbound-attachments` bucket exists
2. Check file size < 50MB
3. Review storage bucket policies

## Local Development

```bash
# Start local Supabase
supabase start

# Serve function locally
supabase functions serve inbound-email

# Test with local endpoint
curl -X POST http://localhost:54321/functions/v1/inbound-email?secret=test \
  -F "to=test@example.com" \
  -F "from=sender@example.com" \
  -F "subject=Test" \
  -F "text=Body"
```

## Files

- `index.ts`: Main function code
- `../deploy_inbound_email.sh`: Deployment script
- `../test_inbound_email.sh`: Test script
- `.env.example`: Configuration template
