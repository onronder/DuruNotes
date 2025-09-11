# Inbox V2 Realtime Implementation

## Overview
Instant inbox updates with <1s latency using Supabase Realtime subscriptions.
No polling - everything is event-driven.

## Architecture

### InboxRealtimeService
- **Location**: `lib/services/inbox_realtime_service.dart`
- **Purpose**: Manages realtime subscriptions for inbox changes
- **Events**: INSERT and DELETE on `clipper_inbox` table

### Key Components

#### 1. Realtime Subscription
```dart
// Subscribes to INSERT events
.onPostgresChanges(
  event: PostgresChangeEvent.insert,
  schema: 'public',
  table: 'clipper_inbox',
  filter: PostgresChangeFilter(
    type: PostgresChangeFilterType.eq,
    column: 'user_id',
    value: userId,
  ),
  callback: _handleInsert,
)

// Subscribes to DELETE events  
.onPostgresChanges(
  event: PostgresChangeEvent.delete,
  ...
  callback: _handleDelete,
)
```

#### 2. Event Deduplication
- Maintains `_processedEventIds` set to prevent duplicate processing
- Automatically prunes old IDs to prevent memory growth
- Separate tracking for INSERT and DELETE events

#### 3. Event Stream
- Broadcasts `InboxRealtimeEvent` to listeners
- Events: `itemInserted`, `itemDeleted`, `listChanged`
- UI components can subscribe to refresh instantly

## Integration Points

### Badge Updates (InboxUnreadService)
- Listens to InboxRealtimeService via provider
- Calls `computeBadgeCount()` on any realtime event
- Badge updates within ~1s of database change

### List Updates (InboundEmailInboxWidget)
- Subscribes to `listRefreshStream` 
- Refreshes list on `listChanged` events
- Automatic cleanup on widget disposal

### Providers
- `inboxRealtimeServiceProvider`: Manages service lifecycle
- Auto-starts on authentication
- Auto-stops on logout/disposal

## Performance

### Latency
- **Target**: <1s from database change to UI update
- **Actual**: ~100-500ms typical (depends on network)

### Resource Usage
- Single WebSocket connection per user
- Minimal memory footprint (event dedup limited to 100 IDs)
- No polling timers or background tasks

## Security
- All subscriptions filtered by `user_id`
- Only receives events for authenticated user's items
- Automatic reconnection on connection loss

## Removed Components
- ❌ Polling timers (30s/2min intervals)
- ❌ ClipperInboxService realtime (was notification-only)
- ❌ Manual updateUnreadCount calls

## Event Flow

1. **Web Clip/Email arrives** → Insert into `clipper_inbox`
2. **Realtime event** → InboxRealtimeService receives INSERT
3. **Deduplication** → Check if already processed
4. **Broadcast** → Emit `listChanged` event
5. **Badge update** → InboxUnreadService recomputes count
6. **List refresh** → InboxWidget reloads items
7. **UI update** → User sees new item within ~1s

## No Auto-Processing
- Realtime events ONLY trigger UI updates
- No automatic conversion to notes
- Items remain in inbox until user action

## Error Handling
- Automatic reconnection after 5s on connection loss
- Graceful degradation if realtime unavailable
- Debug logging for troubleshooting
