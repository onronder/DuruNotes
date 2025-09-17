# Duru Notes Performance Optimization Plan

## Executive Summary
The primary performance bottleneck is **Realtime subscriptions** consuming 97% of database query time with 1.17 million calls. Additionally, there are issues with timezone lookups, excessive HTTP requests, and memory leaks from unmanaged subscriptions.

## Critical Issues Identified

### 1. **Realtime Subscription Overload**
- **5 concurrent Realtime services** running simultaneously:
  - `NotesRealtimeService`
  - `InboxRealtimeService` 
  - `FolderRealtimeService`
  - `ClipperInboxService` (with its own realtime)
  - `SyncService` (with duplicate realtime channels)
- Each service creates separate channels, multiplying database load
- Services are initialized on app start and never properly disposed
- Exponential backoff reconnection creates subscription storms

### 2. **Timezone Query Spam**
- `pg_timezone_names` queried 134 times (76ms each)
- Used by `ReminderService` but never cached
- Re-fetched on every reminder operation

### 3. **Memory Leaks**
- Providers don't properly dispose of Realtime channels
- Multiple subscriptions to the same data (notes, folders)
- Event deduplication sets grow unbounded

## Phase 1: Immediate Fixes (1-2 days)

### A. Consolidate Realtime Services
**File: `lib/services/unified_realtime_service.dart`** (NEW)
```dart
// Create a single unified Realtime service that manages all subscriptions
class UnifiedRealtimeService extends ChangeNotifier {
  // Single channel for all table changes
  RealtimeChannel? _channel;
  
  // Consolidated event streams
  final _notesStream = StreamController<DatabaseChangeEvent>.broadcast();
  final _foldersStream = StreamController<DatabaseChangeEvent>.broadcast();
  final _inboxStream = StreamController<DatabaseChangeEvent>.broadcast();
  
  void start() {
    // Create ONE channel with multiple table listeners
    _channel = supabase
      .channel('unified_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) => _notesStream.add(DatabaseChangeEvent.from(payload)),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'folders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) => _foldersStream.add(DatabaseChangeEvent.from(payload)),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'clipper_inbox',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) => _inboxStream.add(DatabaseChangeEvent.from(payload)),
      );
      
    _channel!.subscribe();
  }
}
```

### B. Fix Provider Lifecycle
**File: `lib/providers.dart`** (MODIFY)
```dart
// Replace multiple realtime providers with single unified provider
final unifiedRealtimeProvider = ChangeNotifierProvider<UnifiedRealtimeService?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  
  return authState.when(
    data: (state) {
      if (state.session == null) return null;
      
      final service = UnifiedRealtimeService(
        supabase: Supabase.instance.client,
        userId: state.session!.user.id,
      );
      
      service.start();
      
      // CRITICAL: Proper disposal
      ref.onDispose(() {
        service.dispose();
      });
      
      return service;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Deprecate individual realtime providers
@Deprecated('Use unifiedRealtimeProvider')
final notesRealtimeServiceProvider = Provider<NotesRealtimeService?>((ref) {
  // Return null - migration period
  return null;
});
```

### C. Cache Timezone Data
**File: `lib/services/reminder_service.dart`** (MODIFY)
```dart
class ReminderService {
  // Cache timezone for entire app session
  static String? _cachedTimezone;
  static final _timezoneCompleter = Completer<String>();
  
  Future<String> _getTimezone() async {
    if (_cachedTimezone != null) return _cachedTimezone!;
    
    if (!_timezoneCompleter.isCompleted) {
      try {
        tzdata.initializeTimeZones();
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
        _cachedTimezone = name;
        _timezoneCompleter.complete(name);
      } catch (e) {
        _cachedTimezone = 'UTC';
        _timezoneCompleter.complete('UTC');
      }
    }
    
    return _timezoneCompleter.future;
  }
}
```

## Phase 2: Architecture Improvements (3-5 days)

### A. Implement Debounced Updates
**File: `lib/services/debounced_update_service.dart`** (NEW)
```dart
class DebouncedUpdateService {
  final _updateQueue = <String, Timer>{};
  final Duration debounceDelay;
  
  void scheduleUpdate(String key, VoidCallback update) {
    _updateQueue[key]?.cancel();
    _updateQueue[key] = Timer(debounceDelay, () {
      update();
      _updateQueue.remove(key);
    });
  }
}
```

### B. Replace SyncService Realtime
**File: `lib/repository/sync_service.dart`** (MODIFY)
```dart
class SyncService {
  // Remove duplicate realtime implementation
  // Use unified realtime service instead
  
  void startRealtime() {
    // Listen to unified service events
    _unifiedRealtimeService.notesStream.listen((event) {
      _debouncer.scheduleUpdate('sync', () => syncNow());
    });
  }
}
```

### C. Implement Connection Pooling
**File: `lib/services/connection_manager.dart`** (NEW)
```dart
class ConnectionManager {
  static const maxRealtimeChannels = 1; // Force single channel
  static const maxHttpConnections = 5;
  
  // Queue HTTP requests when limit reached
  final _httpQueue = Queue<HttpRequest>();
  
  // Singleton pattern to ensure single instance
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();
}
```

## Phase 3: Database Optimizations (1 week)

### A. Migrate System Tables to Private Schema
```sql
-- Create private schema for system tables
CREATE SCHEMA IF NOT EXISTS private;

-- Move notification tables
ALTER TABLE public.notification_analytics 
  SET SCHEMA private;
  
ALTER TABLE public.notification_health_checks 
  SET SCHEMA private;

-- Create API functions for necessary access
CREATE OR REPLACE FUNCTION public.get_notification_stats()
RETURNS TABLE(...) 
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM private.notification_analytics
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql;
```

### B. Optimize Realtime Triggers
```sql
-- Add rate limiting to realtime triggers
CREATE OR REPLACE FUNCTION realtime.throttle_changes()
RETURNS trigger AS $$
DECLARE
  last_update timestamp;
BEGIN
  -- Check last update time
  SELECT last_notified INTO last_update
  FROM realtime.rate_limits
  WHERE user_id = NEW.user_id;
  
  -- Skip if updated within 100ms
  IF last_update > NOW() - INTERVAL '100 milliseconds' THEN
    RETURN NULL;
  END IF;
  
  -- Update rate limit
  INSERT INTO realtime.rate_limits (user_id, last_notified)
  VALUES (NEW.user_id, NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET last_notified = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### C. Implement Cursor Pagination
**File: `lib/features/notes/pagination_notifier.dart`** (MODIFY)
```dart
class NotesPaginationNotifier extends StateNotifier<AsyncValue<NotesPage>> {
  // Replace OFFSET with cursor-based pagination
  Future<NotesPage> _fetchPage({String? cursor}) async {
    final query = _db.select(_db.localNotes)
      ..where((t) => t.deleted.equals(false));
      
    if (cursor != null) {
      query.where((t) => t.updatedAt.isSmallerThan(DateTime.parse(cursor)));
    }
    
    query
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(_pageSize + 1); // Fetch one extra to check hasMore
      
    final notes = await query.get();
    final hasMore = notes.length > _pageSize;
    
    if (hasMore) notes.removeLast();
    
    return NotesPage(
      notes: notes,
      hasMore: hasMore,
      cursor: notes.isNotEmpty ? notes.last.updatedAt.toIso8601String() : null,
    );
  }
}
```

## Phase 4: Monitoring & Prevention (Ongoing)

### A. Add Performance Monitoring
```dart
class PerformanceMonitor {
  static void trackRealtimeSubscriptions() {
    Timer.periodic(Duration(minutes: 5), (_) {
      final activeChannels = Supabase.instance.client.getChannels().length;
      
      if (activeChannels > 1) {
        LoggerFactory.instance.warning(
          'Multiple Realtime channels detected',
          data: {'count': activeChannels},
        );
      }
    });
  }
}
```

### B. Implement Circuit Breaker
```dart
class CircuitBreaker {
  int _failureCount = 0;
  static const maxFailures = 5;
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_failureCount >= maxFailures) {
      throw Exception('Circuit breaker open - too many failures');
    }
    
    try {
      final result = await operation();
      _failureCount = 0; // Reset on success
      return result;
    } catch (e) {
      _failureCount++;
      rethrow;
    }
  }
}
```

## Implementation Timeline

### Week 1
- Day 1-2: Implement unified Realtime service
- Day 3: Fix provider lifecycle management
- Day 4: Cache timezone data
- Day 5: Testing and bug fixes

### Week 2
- Day 1-2: Implement debounced updates
- Day 3: Replace SyncService realtime
- Day 4: Add connection pooling
- Day 5: Testing and monitoring

### Week 3
- Day 1-2: Migrate system tables
- Day 3: Optimize realtime triggers
- Day 4: Implement cursor pagination
- Day 5: Performance testing

## Success Metrics

### Target Improvements
- **Realtime query time**: Reduce from 97% to <20% of total
- **Active channels**: Reduce from 5+ to 1
- **Timezone queries**: Reduce from 134 to 1 per session
- **Memory usage**: 30% reduction
- **App startup time**: 40% faster

### Monitoring Dashboard
```sql
-- Create monitoring view
CREATE VIEW performance_metrics AS
SELECT 
  COUNT(DISTINCT subscription_id) as active_subscriptions,
  COUNT(*) as total_changes,
  AVG(execution_time) as avg_query_time,
  MAX(execution_time) as max_query_time
FROM realtime.messages
WHERE created_at > NOW() - INTERVAL '5 minutes';
```

## Rollback Plan

If issues arise:
1. Feature flag to disable unified Realtime
2. Revert to individual services temporarily
3. Gradual migration path for users

## Code Review Checklist

- [ ] All Realtime channels properly disposed
- [ ] No duplicate subscriptions
- [ ] Timezone cached on first access
- [ ] Debouncing implemented for all updates
- [ ] Connection limits enforced
- [ ] Performance metrics logged
- [ ] Circuit breakers in place
- [ ] Memory leaks fixed

## Testing Requirements

1. **Load Testing**: Simulate 100+ concurrent users
2. **Memory Testing**: Monitor for leaks over 24 hours
3. **Network Testing**: Test with poor connectivity
4. **Subscription Testing**: Verify proper cleanup

## Notes

- The unified Realtime service is the most critical fix
- Provider lifecycle management prevents memory leaks
- Caching eliminates unnecessary database queries
- Monitoring prevents regression

This plan addresses the root causes while maintaining app functionality.
