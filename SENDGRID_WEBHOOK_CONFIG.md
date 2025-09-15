# SendGrid Webhook Configuration

## ✅ Email Inbox Function - FIXED

The email inbox function has been fixed and renamed to use hyphens for consistency.

## Webhook URL for SendGrid

Use this URL in your SendGrid Inbound Parse settings:

```
https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/email-inbox?secret=04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd
```

## What Was Fixed

1. **Removed complex imports** that were causing boot errors (503)
2. **Renamed from `email_inbox` to `email-inbox`** to match URL conventions (just like we did with `inbound-web`)
3. **Fixed in place** - no more duplicate functions
4. **Deleted the duplicate** `email-inbox-simple` function

## SendGrid Configuration Steps

1. Go to **Settings → Inbound Parse** in SendGrid
2. Click **Add Host & URL**
3. Configure:
   - **Subdomain**: Choose your subdomain (e.g., `inbound`)
   - **Domain**: Select your verified domain
   - **Destination URL**: Paste the webhook URL above
   - **Check**: ✅ POST the raw, full MIME message
   - **Check**: ✅ Check incoming emails for spam

## Testing

Successfully tested with:
```json
{
  "success": true,
  "message": "Email processed successfully",
  "inbox_id": "268a8a12-b7a6-4f4e-ad44-02067081890c",
  "user_id": "49b58975-6446-4482-bed5-5c6b0ec46675",
  "alias": "note_test1234",
  "attachment_count": 0
}
```

## Email Format

Send emails to: `note_test1234@yourdomain.com`

The function will:
1. Extract the alias (`note_test1234`)
2. Find the associated user
3. Store the email in `clipper_inbox` with `source_type: "email_in"`
4. Process attachments if present

## No More Duplicates

- ✅ Using the ORIGINAL `email_inbox` function
- ✅ Deleted `email-inbox-simple` 
- ✅ Fixed the root cause instead of creating workarounds
