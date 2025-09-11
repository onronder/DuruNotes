# Inbox V2 Badge Implementation

## Badge Modes

### InboxBadgeMode Enum
```dart
enum InboxBadgeMode { 
  newSinceLastOpen,  // Default - shows new items since last inbox open
  total              // Shows total count of all items in inbox
}
```

## Key Methods

### `markInboxViewed()`
- Called when inbox is opened
- Updates `lastViewedTimestamp` to current time
- Behavior depends on mode:
  - **newSinceLastOpen**: Resets badge to 0 immediately
  - **total**: Maintains current count (no reset)

### `computeBadgeCount()`
- Calculates badge count based on current mode
- **newSinceLastOpen mode**: 
  - Counts items with `created_at > lastViewedTimestamp`
  - Returns 0 if no lastViewedTimestamp (first open)
- **total mode**: 
  - Counts all items in clipper_inbox for user
  - Ignores lastViewedTimestamp

### `setBadgeMode(InboxBadgeMode mode)`
- Changes the badge display mode
- Automatically recomputes count with new mode
- Persists mode preference to SharedPreferences

## Integration Points

### Inbox Widget (`InboundEmailInboxWidget`)
- Calls `markInboxViewed()` on widget initialization
- Resets badge when inbox is opened (in newSinceLastOpen mode)

### Realtime Updates (`ClipperInboxService`)
- Calls `computeBadgeCount()` when new items arrive
- Updates badge immediately via realtime subscription

### Notes List Screen
- Displays badge count on inbox icon
- Refreshes count after returning from inbox

## Data Storage

### SharedPreferences Keys
- `inbox_last_viewed_timestamp`: Last time inbox was opened
- `inbox_unread_count`: Cached badge count
- `inbox_badge_mode`: Current badge mode (index)

## Default Behavior
- Mode: `newSinceLastOpen` (recommended)
- Badge shows count of new items since last inbox open
- Opening inbox resets badge to 0
- Items remain in inbox (no auto-deletion)

## Security
- All queries are user-scoped with `.eq('user_id', userId)`
- Badge count only includes items for authenticated user

## Legacy Support
- `updateUnreadCount()` → forwards to `computeBadgeCount()`
- `markAsViewed()` → forwards to `markInboxViewed()`
- Deprecated methods maintained for backward compatibility
