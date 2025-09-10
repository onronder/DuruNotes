# Inbound Web Edge Function

This Supabase Edge Function handles incoming web clips from the browser extension and stores them in the `clipper_inbox` table.

## Overview

The function accepts HTTP POST requests containing web clip data (title, text, URL) and stores them in the database for later processing by the Flutter app.

## Endpoints

- `POST /functions/v1/inbound-web`

## Authentication Methods

### Method 1: HMAC Signature (Recommended)

Use HMAC-SHA256 signing for enhanced security and replay attack protection.

**Headers:**
- `X-Clipper-Timestamp`: ISO 8601 timestamp (must be within 5 minutes of server time)
- `X-Clipper-Signature`: Hex-encoded HMAC-SHA256 signature

**Signature Computation:**
```
message = timestamp + '\n' + request_body
signature = HMAC-SHA256(secret, message)
```

### Method 2: Query Parameter (Deprecated, for backward compatibility)

- `POST /functions/v1/inbound-web?secret=<SECRET>`

⚠️ **Note:** Query parameter authentication is deprecated and will be removed in a future version. Please migrate to HMAC signing.

## Request Format

```json
{
  "alias": "note_abc123",  // User's inbound alias (without @domain)
  "title": "Page Title",   // Title of the web page
  "text": "Selected text", // Clipped text content
  "url": "https://example.com/page", // Source URL
  "html": "<p>HTML content</p>", // Optional: HTML snippet
  "clipped_at": "2025-01-09T10:30:00Z" // Optional: When clipped
}
```

**Note about alias field:**
- Use only the alias code (e.g., `note_abc123`)
- Do NOT include the domain (e.g., NOT `note_abc123@in.durunotes.app`)
- The function will automatically strip any domain if included

## Security

- Supports HMAC-SHA256 signature verification with timestamp validation (5-minute window)
- Falls back to query parameter secret for backward compatibility
- Maps alias to user via `inbound_aliases` table
- Uses service role to insert data (maintains zero-knowledge principle)
- Returns success even for unknown aliases (prevents alias enumeration)

## Deployment

```bash
# Deploy the function
supabase functions deploy inbound-web

# Set the secret (required for both HMAC and query param auth)
supabase secrets set INBOUND_PARSE_SECRET=<your-secret-value>
```

## Testing

### With HMAC Signature (Recommended)

```bash
# Set variables
SECRET="your-secret-value"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BODY='{
  "alias": "note_abc123",
  "title": "Test Web Clip",
  "text": "This is a test clip",
  "url": "https://example.com"
}'

# Compute signature (requires openssl)
MESSAGE="${TIMESTAMP}
${BODY}"
SIGNATURE=$(echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)

# Send request
curl -X POST \
  "https://<project-id>.supabase.co/functions/v1/inbound-web" \
  -H "Content-Type: application/json" \
  -H "X-Clipper-Timestamp: $TIMESTAMP" \
  -H "X-Clipper-Signature: $SIGNATURE" \
  -d "$BODY"
```

### With Query Parameter (Deprecated)

```bash
# Test with curl
curl -X POST \
  "https://<project-id>.supabase.co/functions/v1/inbound-web?secret=<your-secret>" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "note_abc123",
    "title": "Test Web Clip",
    "text": "This is a test clip",
    "url": "https://example.com"
  }'
```

### Test Invalid Signature (Should return 401)

```bash
curl -X POST \
  "https://<project-id>.supabase.co/functions/v1/inbound-web" \
  -H "Content-Type: application/json" \
  -H "X-Clipper-Timestamp: 2025-01-01T00:00:00Z" \
  -H "X-Clipper-Signature: invalid-signature" \
  -d '{
    "alias": "note_abc123",
    "title": "Test"
  }'
```

### Test Expired Timestamp (Should return 401)

```bash
# Use a timestamp from yesterday
OLD_TIMESTAMP=$(date -u -d "yesterday" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ")
BODY='{"alias": "test", "title": "Test"}'
MESSAGE="${OLD_TIMESTAMP}
${BODY}"
SIGNATURE=$(echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)

curl -X POST \
  "https://<project-id>.supabase.co/functions/v1/inbound-web" \
  -H "Content-Type: application/json" \
  -H "X-Clipper-Timestamp: $OLD_TIMESTAMP" \
  -H "X-Clipper-Signature: $SIGNATURE" \
  -d "$BODY"
```

## Response

Success (200):
```json
{
  "status": "ok",
  "message": "Clip saved successfully"
}
```

Error responses:
- 401: Invalid signature, expired timestamp, or missing secret
- 400: Missing required field (alias) or invalid JSON
- 405: Method not allowed (non-POST)
- 500: Server error

## Processing

Web clips are stored with `source_type: "web"` in the `clipper_inbox` table. The Flutter app's `ClipperInboxService` polls this table every 30 seconds and converts web clips to encrypted notes, similar to how it processes inbound emails.

## Troubleshooting

### Web clips not appearing in inbox

1. **Verify alias exists**: Check that the user has an alias in the `inbound_aliases` table
   ```sql
   SELECT * FROM inbound_aliases WHERE user_id = 'USER_ID';
   ```

2. **Check function logs**: Look for "Unknown alias" messages
   ```bash
   supabase functions logs inbound-web
   ```

3. **Verify secret configuration**: Ensure `INBOUND_PARSE_SECRET` is set
   ```bash
   supabase secrets list
   ```

4. **Common issues**:
   - User entered full email instead of just alias
   - Alias doesn't exist (user needs to open Email Inbox in app first)
   - Secret mismatch between extension and function
   - Function not deployed or not running

## Migration Guide

If you're currently using query parameter authentication, follow these steps to migrate to HMAC signing:

1. Update your Chrome extension to version 0.2.0 or later (includes HMAC support)
2. The extension will automatically use HMAC signing when available
3. The server continues to accept query parameter auth as a fallback
4. Monitor server logs - signed requests log "authenticated via HMAC signature"
5. Once all clients are updated, query parameter auth can be disabled server-side

## Security Considerations

- **Timestamp validation**: Requests with timestamps more than 5 minutes old or in the future are rejected
- **Replay protection**: The timestamp in the signature prevents replay attacks
- **Secret rotation**: To rotate secrets, temporarily accept both old and new secrets during transition
- **No secret logging**: The server never logs the secret or full authentication headers