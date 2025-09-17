# Quick Capture Widget Edge Function

Production-grade Edge Function for handling quick note captures from home screen widgets.

## Features

- **Authentication**: Validates user authentication via Supabase Auth
- **Rate Limiting**: 10 requests per minute per user
- **Input Validation**: Comprehensive validation of all inputs
- **Template Support**: Pre-defined templates for meeting notes, todos, and ideas
- **Analytics**: Tracks all events for monitoring and insights
- **Error Handling**: Detailed error responses with codes for client handling
- **Security**: Input sanitization to prevent XSS and injection attacks
- **Performance**: Optimized with proper indexes and monitoring

## API Endpoint

```
POST /quick-capture-widget
```

### Request Headers

```
Authorization: Bearer <user_token>
Content-Type: application/json
```

### Request Body

```json
{
  "text": "Note content (required, max 10000 chars)",
  "platform": "ios|android|web (required)",
  "templateId": "meeting|todo|idea (optional)",
  "attachments": ["attachment_url1", "attachment_url2"] (optional, max 10),
  "metadata": { "custom": "data" } (optional)
}
```

### Response

#### Success (200)
```json
{
  "success": true,
  "noteId": "uuid",
  "message": "Note created successfully"
}
```

#### Error Responses

- **401 Unauthorized**
```json
{
  "success": false,
  "error": "Unauthorized",
  "errorCode": "AUTH_001",
  "message": "Invalid authentication token"
}
```

- **429 Rate Limited**
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "errorCode": "RATE_001",
  "message": "Too many requests. Please wait a moment and try again."
}
```

- **400 Validation Failed**
```json
{
  "success": false,
  "error": "Validation failed",
  "errorCode": "VAL_001",
  "message": "text: Text cannot be empty"
}
```

### Response Headers

```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 9
X-RateLimit-Reset: 2025-01-20T12:00:00Z
X-Processing-Time-Ms: 145
```

## Deployment

### Local Development

```bash
# Start local Supabase
supabase start

# Serve the function locally
supabase functions serve quick-capture-widget --env-file ./supabase/.env.local
```

### Testing

```bash
# Test with curl
curl -X POST \
  http://localhost:54321/functions/v1/quick-capture-widget \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Test note from widget",
    "platform": "ios"
  }'
```

### Production Deployment

```bash
# Deploy to production
supabase functions deploy quick-capture-widget --project-ref YOUR_PROJECT_REF

# Set secrets if needed
supabase secrets set --env-file .env.production
```

## Monitoring

### Key Metrics

- **Request Rate**: Track via `analytics_events` table
- **Error Rate**: Monitor `quick_capture.note_creation_failed` events
- **Rate Limit Hits**: Track `quick_capture.rate_limit_hit` events
- **Processing Time**: Check `X-Processing-Time-Ms` header

### Analytics Events

- `quick_capture.widget_note_created` - Successful note creation
- `quick_capture.validation_failed` - Request validation errors
- `quick_capture.rate_limit_hit` - Rate limit exceeded
- `quick_capture.note_creation_failed` - Database errors
- `quick_capture.auth_failed` - Authentication failures
- `quick_capture.internal_error` - Unexpected errors

## Security

- Input sanitization removes script tags and event handlers
- Rate limiting prevents abuse
- Authentication required for all requests
- CORS headers configured for web widget support
- All errors logged without exposing sensitive data

## Performance

- Optimized database queries with proper indexes
- Efficient rate limit checking with upsert
- Analytics tracked asynchronously
- Response times tracked in headers

## Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| AUTH_001 | Authentication failed | 401 |
| RATE_001 | Rate limit exceeded | 429 |
| VAL_001 | Validation failed | 400 |
| NOTE_001 | Note creation failed | 500 |
| INT_001 | Internal server error | 500 |

## Maintenance

### Database Cleanup

Run periodically to clean up old rate limit entries:

```sql
SELECT public.cleanup_old_rate_limits();
```

### Monitoring Queries

```sql
-- Check recent widget captures
SELECT * FROM analytics_events 
WHERE event_type = 'quick_capture.widget_note_created'
ORDER BY created_at DESC 
LIMIT 100;

-- Check error rate
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as error_count
FROM analytics_events 
WHERE event_type LIKE 'quick_capture.%failed'
GROUP BY hour
ORDER BY hour DESC;

-- Check rate limit usage
SELECT 
  split_part(key, ':', 2) as user_id,
  count,
  window_start
FROM rate_limits
WHERE key LIKE 'widget_capture:%'
ORDER BY updated_at DESC;
```
