# Edge Function Hardening Summary

## Overview
The `inbound-web` Edge Function has been hardened with alias normalization and improved server-side guardrails.

## Key Improvements

### 1. Alias Normalization
- **Function**: `normalizeAlias(alias: string)`
- **Behavior**:
  - Strips domain part (everything after @)
  - Converts to lowercase
  - Trims whitespace
- **Examples**:
  - `note_abc123@in.durunotes.app` → `note_abc123`
  - `NOTE_ABC123@example.com` → `note_abc123`
  - `Note_ABC123 ` → `note_abc123`

### 2. Structured Logging
All log outputs now use structured JSON format for better observability:

```json
{"event":"alias_normalized","original":"note_abc123@in.durunotes.app","normalized":"note_abc123"}
{"event":"auth_success","method":"hmac"}
{"event":"unknown_alias","alias":"xyz789","original_alias":"xyz789@domain.com","title":"Test","url":"https://example.com"}
{"event":"clip_saved","user_id":"123e4567","alias":"note_abc123","title":"Page Title","url":"https://example.com"}
```

### 3. Security Enhancements
- **HMAC remains primary**: Query secret only as fallback
- **No alias enumeration**: Unknown aliases return 200 with generic response
- **Consistent CORS headers**: All response paths include CORS headers

## Log Event Types

| Event | When | Key Fields |
|-------|------|------------|
| `auth_success` | Successful authentication | `method` (hmac/query_secret) |
| `auth_failed` | Authentication failed | `reason` |
| `hmac_failed` | HMAC verification failed | `reason` |
| `alias_normalized` | Alias was normalized | `original`, `normalized` |
| `unknown_alias` | Alias not found | `alias`, `original_alias`, `title`, `url` |
| `alias_lookup_error` | Database error | `error`, `code` |
| `clip_saved` | Success | `user_id`, `alias`, `title`, `url` |
| `insert_failed` | Insert error | `error`, `code`, `user_id` |
| `missing_alias` | No alias in request | `error` |

## Monitoring Unknown Aliases

To identify potential issues with unknown aliases:

```bash
# View all unknown alias attempts
supabase functions logs inbound-web | grep '"event":"unknown_alias"'

# Extract just the aliases
supabase functions logs inbound-web | grep '"event":"unknown_alias"' | jq -r '.alias'

# Count by alias
supabase functions logs inbound-web | grep '"event":"unknown_alias"' | jq -r '.alias' | sort | uniq -c
```

## Backward Compatibility
- Accepts both `alias` and `alias@domain` formats
- Query secret authentication still works (logs warning)
- Existing Chrome extensions continue to work without changes

## Deployment
```bash
# Deploy the updated function
./supabase/functions/deploy_inbound_web.sh

# Verify deployment
supabase functions list

# Monitor logs
supabase functions logs inbound-web --tail
```

## Testing Examples

### Test with normalized alias
```bash
curl -X POST \
  "https://PROJECT.supabase.co/functions/v1/inbound-web?secret=SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "note_abc123@in.durunotes.app",
    "title": "Test with domain",
    "text": "Should normalize to note_abc123"
  }'
```

### Test unknown alias (returns 200)
```bash
curl -X POST \
  "https://PROJECT.supabase.co/functions/v1/inbound-web?secret=SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "nonexistent_alias",
    "title": "Test unknown",
    "text": "Should return 200 but log unknown_alias"
  }'
```

## Security Notes
- Never logs secrets or authentication headers
- Unknown aliases return success to prevent enumeration
- All database operations use service role (maintains zero-knowledge)
- Timestamp validation prevents replay attacks (5-minute window)
