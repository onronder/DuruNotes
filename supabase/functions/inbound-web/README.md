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
  "alias": "note_abc123",  // User's inbound alias
  "title": "Page Title",   // Title of the web page
  "text": "Selected text", // Clipped text content
  "url": "https://example.com/page", // Source URL
  "html": "<p>HTML content</p>", // Optional: HTML snippet
  "clipped_at": "2025-01-09T10:30:00Z" // Optional: When clipped
}
```

### Alias Normalization

The function automatically normalizes the alias field to handle various formats:

| Input Alias | Normalized Alias |
|-------------|-----------------|
| `note_abc123` | `note_abc123` |
| `note_abc123@in.durunotes.app` | `note_abc123` |
| `Note_ABC123@example.com` | `note_abc123` |
| `NOTE_ABC123 ` | `note_abc123` |

- Strips any domain part (everything after @)
- Converts to lowercase
- Trims whitespace
- This allows the extension to send either format

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

Web clips are stored with `source_type: "web"` in the `clipper_inbox` table. The Flutter app receives instant realtime notifications when new clips arrive, and they appear in the unified Inbox UI for user review. Users can then manually convert clips to encrypted notes or delete them.

## Structured Logging

The function uses structured JSON logging for better observability:

### Log Events

| Event | Description | Fields |
|-------|-------------|--------|
| `auth_success` | Successful authentication | `method` (hmac/query_secret) |
| `auth_failed` | Authentication failed | `reason` |
| `hmac_failed` | HMAC verification failed | `reason` |
| `alias_normalized` | Alias was normalized | `original`, `normalized` |
| `unknown_alias` | Alias not found in database | `alias`, `original_alias`, `title`, `url` |
| `alias_lookup_error` | Database error during alias lookup | `error`, `code` |
| `clip_saved` | Successfully saved web clip | `user_id`, `alias`, `title`, `url` |
| `insert_failed` | Failed to insert into database | `error`, `code`, `user_id`, `title` |
| `missing_alias` | Request missing alias field | `error` |

### Example Log Output

```json
{"event":"alias_normalized","original":"note_abc123@in.durunotes.app","normalized":"note_abc123"}
{"event":"auth_success","method":"hmac"}
{"event":"clip_saved","user_id":"123e4567-e89b-12d3-a456-426614174000","alias":"note_abc123","title":"Test Page","url":"https://example.com"}
```

## Troubleshooting

### Web clips not appearing in inbox

1. **Verify alias exists**: Check that the user has an alias in the `inbound_aliases` table
   ```sql
   SELECT * FROM inbound_aliases WHERE user_id = 'USER_ID';
   ```

2. **Check function logs**: Look for structured log events
   ```bash
   # View logs
   supabase functions logs inbound-web
   
   # Look for specific events
   supabase functions logs inbound-web | grep '"event":"unknown_alias"'
   supabase functions logs inbound-web | grep '"event":"clip_saved"'
   ```

3. **Verify secret configuration**: Ensure `INBOUND_PARSE_SECRET` is set
   ```bash
   supabase secrets list
   ```

4. **Common issues**:
   - **Unknown alias**: Check logs for `{"event":"unknown_alias"}` - user needs to open Email Inbox in app first
   - **Auth failures**: Check logs for `{"event":"auth_failed"}` - verify secret and HMAC signature
   - **Insert failures**: Check logs for `{"event":"insert_failed"}` - may indicate database issues
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