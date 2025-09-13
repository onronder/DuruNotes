# Production-Grade Push Notification Architecture

## System Overview

This document describes the production-grade push notification system for DuruNotes, designed for reusability, scalability, and maintainability.

## Architecture Components

### 1. Event-Driven Core
```
┌─────────────────────────────────────────────────────────────┐
│                     Event Sources                            │
├──────────────┬──────────────┬──────────────┬───────────────┤
│ Email Inbox  │ Web Clipper  │ Note Events  │ Reminders     │
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬────────┘
       │              │              │              │
       v              v              v              v
┌─────────────────────────────────────────────────────────────┐
│              Notification Events Queue                       │
│         (notification_events table in Supabase)             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────────┐
│           Notification Processor Edge Function               │
│                 (send-push-notification)                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────────┐
│                   Delivery Channels                          │
├──────────────┬──────────────┬──────────────┬───────────────┤
│     FCM      │     APNs     │    Email     │     SMS       │
│   (Android)  │    (iOS)     │   (Future)   │   (Future)    │
└──────────────┴──────────────┴──────────────┴───────────────┘
```

## Database Schema

### notification_events
- Primary event queue for all notifications
- Stores event type, payload, user, status
- Supports retry logic and error tracking

### notification_templates
- Reusable notification templates
- Supports localization
- Dynamic variable substitution

### notification_deliveries
- Tracks actual delivery attempts
- Records success/failure/retry states
- Maintains delivery analytics

### notification_preferences
- User-level notification settings
- Channel preferences (push, email, etc.)
- Quiet hours and DND settings

## Event Types

### Core Events
1. **email_received** - New email in inbox
2. **web_clip_saved** - Web content clipped
3. **note_shared** - Note shared with user
4. **reminder_due** - Scheduled reminder
5. **note_mentioned** - User mentioned in note
6. **folder_shared** - Folder shared with user
7. **comment_added** - Comment on shared note
8. **sync_conflict** - Sync conflict detected

### System Events
1. **account_security** - Security alerts
2. **subscription_expiring** - Billing notifications
3. **feature_announcement** - Product updates
4. **maintenance_scheduled** - System maintenance

## Edge Function Architecture

### send-push-notification
Primary notification delivery function with:
- Automatic retry with exponential backoff
- Multi-channel delivery support
- Template rendering
- User preference checking
- Rate limiting
- Delivery tracking

### process-notification-queue
Background processor for:
- Batch processing queued events
- Scheduled notification delivery
- Failed delivery retries
- Analytics aggregation

## Security & Privacy

### Authentication
- HMAC signature verification for webhooks
- Service role authentication for Edge Functions
- RLS policies for user data access

### Data Protection
- End-to-end encryption for sensitive payloads
- PII redaction in logs
- GDPR-compliant data retention
- User consent tracking

## Scalability Features

### Queue Management
- Event deduplication
- Priority-based processing
- Batch delivery optimization
- Dead letter queue for failures

### Performance Optimization
- Edge region deployment
- Connection pooling
- Caching strategies
- Lazy loading of user preferences

## Monitoring & Observability

### Metrics
- Delivery success rate
- Average delivery latency
- Channel-specific metrics
- User engagement rates

### Logging
- Structured JSON logging
- Correlation IDs for tracing
- Error categorization
- Performance profiling

### Alerting
- Failed delivery thresholds
- Queue depth monitoring
- Latency alerts
- Error rate monitoring

## Error Handling

### Retry Strategy
```
Attempt 1: Immediate
Attempt 2: +30 seconds
Attempt 3: +2 minutes
Attempt 4: +10 minutes
Attempt 5: +1 hour
Failed: Move to dead letter queue
```

### Error Categories
1. **Transient** - Network issues, service temporarily unavailable
2. **Invalid Token** - Expired or invalid device tokens
3. **User Preference** - User has disabled notifications
4. **Rate Limited** - Provider rate limits exceeded
5. **Permanent** - Invalid payload, missing required fields

## Implementation Phases

### Phase 1: Core Infrastructure ✓
- Database schema
- Event queue system
- Basic Edge Function

### Phase 2: Email & Web Triggers
- Email inbox integration
- Web clipper integration
- Template system

### Phase 3: Enhanced Delivery
- Multi-channel support
- User preferences
- Retry logic

### Phase 4: Analytics & Monitoring
- Delivery tracking
- Performance metrics
- User analytics

### Phase 5: Advanced Features
- Rich notifications
- Action buttons
- Deep linking
- Localization

## API Reference

### Trigger Notification
```typescript
interface NotificationEvent {
  user_id: string;
  event_type: string;
  payload: Record<string, any>;
  priority: 'low' | 'normal' | 'high' | 'critical';
  scheduled_for?: string; // ISO timestamp
  dedupe_key?: string;
  channels?: ('push' | 'email' | 'sms')[];
}
```

### Delivery Response
```typescript
interface DeliveryResult {
  event_id: string;
  status: 'delivered' | 'failed' | 'queued' | 'retrying';
  channels: {
    push?: { status: string; token_count: number; };
    email?: { status: string; message_id: string; };
  };
  error?: string;
  retry_at?: string;
}
```

## Testing Strategy

### Unit Tests
- Event creation and validation
- Template rendering
- Preference checking
- Error handling

### Integration Tests
- End-to-end delivery flow
- Multi-channel delivery
- Retry mechanism
- Rate limiting

### Load Tests
- Queue throughput
- Edge Function scalability
- Database performance
- Provider limits

## Maintenance & Operations

### Regular Tasks
- Token cleanup (stale devices)
- Queue maintenance
- Analytics aggregation
- Performance optimization

### Monitoring Dashboard
- Real-time delivery stats
- Error rates by category
- Queue depth visualization
- User engagement metrics

## Future Enhancements

### Planned Features
1. **Rich Media** - Images, videos in notifications
2. **Interactive Actions** - Quick replies, buttons
3. **Smart Delivery** - ML-based optimal timing
4. **Segmentation** - User group targeting
5. **A/B Testing** - Template optimization
6. **In-App Messages** - Fallback to in-app delivery
