import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Events emitted by the inbox realtime service
enum InboxRealtimeEvent {
  itemInserted,
  itemDeleted,
  listChanged,
}

/// Realtime service for inbox updates
/// Provides instant updates for badge counts and list refreshes
class InboxRealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  
  // Event deduplication
  final Set<String> _processedEventIds = {};
  static const int _maxProcessedIds = 100;
  
  // Stream controller for list refresh events
  final _listRefreshController = StreamController<InboxRealtimeEvent>.broadcast();
  Stream<InboxRealtimeEvent> get listRefreshStream => _listRefreshController.stream;
  
  InboxRealtimeService({required SupabaseClient supabase}) : _supabase = supabase;
  
  bool get isSubscribed => _isSubscribed;
  
  /// Start realtime subscription for inbox changes
  Future<void> start() async {
    await stop(); // Clean up any existing subscription
    
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[InboxRealtime] Cannot start: no authenticated user');
      return;
    }
    
    debugPrint('[InboxRealtime] Starting realtime subscription for user: $userId');
    
    try {
      // Create channel for clipper_inbox changes (INSERT and DELETE)
      _channel = _supabase
          .channel('inbox_realtime_$userId')
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
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'clipper_inbox',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleDelete,
          );
      
      // Subscribe to the channel
      _channel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _isSubscribed = true;
          notifyListeners();
          debugPrint('[InboxRealtime] Subscription active');
        } else if (status == RealtimeSubscribeStatus.closed || 
                   status == RealtimeSubscribeStatus.channelError) {
          _isSubscribed = false;
          notifyListeners();
          debugPrint('[InboxRealtime] Subscription lost: $status, error: $error');
          
          // Attempt to reconnect after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isSubscribed && _supabase.auth.currentUser != null) {
              debugPrint('[InboxRealtime] Attempting to reconnect...');
              start();
            }
          });
        }
      });
    } catch (e) {
      debugPrint('[InboxRealtime] Failed to setup subscription: $e');
      _isSubscribed = false;
      notifyListeners();
    }
  }
  
  /// Stop realtime subscription
  Future<void> stop() async {
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
    _isSubscribed = false;
    _processedEventIds.clear();
    notifyListeners();
    debugPrint('[InboxRealtime] Subscription stopped');
  }
  
  /// Handle INSERT events
  void _handleInsert(PostgresChangePayload payload) {
    try {
      final newRow = payload.newRecord;
      final id = newRow['id'] as String?;
      
      if (id == null) {
        debugPrint('[InboxRealtime] INSERT missing ID');
        return;
      }
      
      // Deduplicate events
      if (_processedEventIds.contains(id)) {
        debugPrint('[InboxRealtime] Duplicate INSERT event for ID: $id');
        return;
      }
      
      _processedEventIds.add(id);
      _pruneProcessedIds();
      
      debugPrint('[InboxRealtime] New item inserted: $id');
      
      // Emit events for UI update
      _listRefreshController.add(InboxRealtimeEvent.itemInserted);
      _listRefreshController.add(InboxRealtimeEvent.listChanged);
      
      // Notify listeners (triggers badge update)
      notifyListeners();
    } catch (e) {
      debugPrint('[InboxRealtime] Error handling INSERT: $e');
    }
  }
  
  /// Handle DELETE events
  void _handleDelete(PostgresChangePayload payload) {
    try {
      final oldRow = payload.oldRecord;
      final id = oldRow['id'] as String?;
      
      if (id == null) {
        debugPrint('[InboxRealtime] DELETE missing ID');
        return;
      }
      
      // For deletes, we use a different dedup key
      final deleteKey = 'delete_$id';
      if (_processedEventIds.contains(deleteKey)) {
        debugPrint('[InboxRealtime] Duplicate DELETE event for ID: $id');
        return;
      }
      
      _processedEventIds.add(deleteKey);
      _pruneProcessedIds();
      
      debugPrint('[InboxRealtime] Item deleted: $id');
      
      // Emit events for UI update
      _listRefreshController.add(InboxRealtimeEvent.itemDeleted);
      _listRefreshController.add(InboxRealtimeEvent.listChanged);
      
      // Notify listeners (triggers badge update)
      notifyListeners();
    } catch (e) {
      debugPrint('[InboxRealtime] Error handling DELETE: $e');
    }
  }
  
  /// Prune processed IDs to prevent memory growth
  void _pruneProcessedIds() {
    if (_processedEventIds.length > _maxProcessedIds) {
      // Keep only the most recent IDs
      final toKeep = _processedEventIds.toList()
          .skip(_processedEventIds.length - (_maxProcessedIds ~/ 2))
          .toSet();
      _processedEventIds.clear();
      _processedEventIds.addAll(toKeep);
    }
  }
  
  @override
  void dispose() {
    stop();
    _listRefreshController.close();
    super.dispose();
  }
}
