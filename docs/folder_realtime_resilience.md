# Folder Realtime Service Resilience

## Overview
The FolderRealtimeService has been enhanced with resilience features to handle network interruptions, connection errors, and ensure clean lifecycle management.

## Architecture

### Connection States
```dart
enum ConnectionState {
  disconnected,  // Not connected
  connecting,    // Attempting to connect
  connected,     // Successfully connected
  error,         // Connection failed
  offline,       // No network connectivity
}
```

### Key Features

#### 1. Exponential Backoff
- Initial retry: 1 second
- Doubles on each failure: 1s → 2s → 4s → 8s → 16s
- Maximum backoff: 30 seconds
- Maximum attempts: 10
- Resets on successful connection

#### 2. Network Monitoring
- Uses `connectivity_plus` to detect network changes
- Pauses reconnection attempts when offline
- Automatically resumes when network returns
- Prevents unnecessary connection attempts

#### 3. Connection Management
- Single subscription per auth session
- Automatic cleanup on sign-out
- No duplicate subscriptions
- Proper resource disposal

#### 4. Debouncing
- 300ms debounce for folder change events
- Prevents rapid refresh during bulk operations
- Coalesces multiple changes into single update

## Lifecycle Flow

### Startup
1. Check authentication state
2. Set up connectivity monitoring
3. Check network availability
4. Attempt initial connection
5. Monitor for status changes

### Connection Loss
1. Detect disconnection/error
2. Clean up failed subscription
3. Calculate backoff delay
4. Schedule reconnection attempt
5. Retry with exponential backoff

### Network Loss
1. Connectivity monitor detects offline
2. Cancel pending reconnections
3. Set state to offline
4. Wait for network restoration
5. Resume connection when online

### Shutdown
1. Cancel all timers
2. Unsubscribe from channel
3. Clean up connectivity monitoring
4. Mark service as disposed

## Error Handling

### Connection Errors
- Logged with context
- Trigger reconnection with backoff
- Clean up failed resources

### Timeout Handling
- 2-second initial connection timeout
- Triggers reconnection on timeout
- Prevents hanging connections

### Network Errors
- Detected via connectivity monitoring
- Prevents connection attempts when offline
- Automatic recovery when network returns

## Testing Scenarios

### Airplane Mode Test
1. Enable airplane mode
2. Service detects offline state
3. Stops reconnection attempts
4. Disable airplane mode
5. Service automatically reconnects

### Server Restart Test
1. Supabase server restarts
2. Channel disconnects
3. Service detects disconnection
4. Reconnects with backoff
5. Resumes normal operation

### Auth Session Test
1. User signs out
2. Service stops and cleans up
3. User signs in
4. New service instance starts
5. Single subscription active

## Monitoring & Debugging

### Log Messages
- `[FolderRealtime] State change: X → Y` - State transitions
- `[FolderRealtime] Connecting for user X (attempt Y)` - Connection attempts
- `[FolderRealtime] Scheduling reconnect in Xms` - Backoff delays
- `[FolderRealtime] Network lost/restored` - Connectivity changes
- `[FolderRealtime] Folder change detected` - Realtime events

### Health Checks
- Check `state` property for current connection state
- Monitor reconnect attempts counter
- Verify single channel subscription
- Confirm timer cleanup on dispose

## Configuration

### Tunable Parameters
```dart
static const int _initialBackoffMs = 1000;  // Initial retry delay
static const int _maxBackoffMs = 30000;     // Maximum retry delay
static const int _maxReconnectAttempts = 10; // Maximum retries
```

### Debounce Settings
- Folder refresh: 300ms
- Prevents UI thrashing during rapid changes

## Best Practices

1. **Always dispose** - Call dispose() when service is no longer needed
2. **Monitor state** - Check connection state before operations
3. **Handle offline** - Gracefully degrade when offline
4. **Log errors** - All errors are logged for debugging
5. **Test resilience** - Regularly test with network interruptions

## Future Enhancements

1. Add connection quality metrics
2. Implement circuit breaker pattern
3. Add telemetry for monitoring
4. Support custom backoff strategies
5. Add connection pooling for multiple channels
