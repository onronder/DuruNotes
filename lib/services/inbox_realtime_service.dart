import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Events emitted by the inbox realtime service
enum InboxRealtimeEvent { itemInserted, itemDeleted, listChanged }

/// Realtime service for inbox updates
/// Provides instant updates for badge counts and list refreshes
class InboxRealtimeService extends ChangeNotifier {
  // Exponential backoff

  InboxRealtimeService({required SupabaseClient supabase})
      : _supabase = supabase;
  final SupabaseClient _supabase;
  final AppLogger _logger = LoggerFactory.instance;
  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  bool _disposed = false;

  // Event deduplication
  final Set<String> _processedEventIds = {};
  static const int _maxProcessedIds = 100;

  // Stream controller for list refresh events
  final _listRefreshController =
      StreamController<InboxRealtimeEvent>.broadcast();
  Stream<InboxRealtimeEvent> get listRefreshStream =>
      _listRefreshController.stream;

  // Exponential backoff for reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 30; // Max 30 seconds
  static const List<int> _backoffDelays = [1, 2, 4, 8, 16, 30];

  bool get isSubscribed => _isSubscribed;

  /// Start realtime subscription for inbox changes
  Future<void> start() async {
    if (_disposed) {
      _logger.debug(' Cannot start: service is disposed');
      return;
    }
    await stop(); // Clean up any existing subscription

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _logger.debug(' Cannot start: no authenticated user');
      return;
    }

    _logger.debug(' Starting realtime subscription for user: $userId');

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
          )
          // Fallback: broadcast channel for environments without DB replication
          .onBroadcast(
            event: 'inbox_changed',
            callback: (payload) {
              try {
                final targetUserId = payload['user_id'] as String?;
                if (targetUserId == userId) {
                  _logger.debug(' Broadcast inbox_changed received');
                  _listRefreshController.add(InboxRealtimeEvent.listChanged);
                  if (!_disposed) notifyListeners();
                }
              } catch (e) {
                _logger.debug(' Broadcast handler error: $e');
              }
            },
          );

      // Subscribe to the channel
      _channel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _isSubscribed = true;
          _reconnectAttempts = 0; // Reset on successful connection
          _cancelReconnectTimer();
          if (!_disposed) {
            notifyListeners();
          }
          _logger.debug(' Subscription active');
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError) {
          _isSubscribed = false;
          if (!_disposed) {
            notifyListeners();
            _logger.debug(' Subscription lost: $status, error: $error');
            // Schedule reconnect with exponential backoff
            _scheduleReconnect();
          }
        }
      });
    } catch (e) {
      _logger.debug(' Failed to setup subscription: $e');
      _isSubscribed = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Stop realtime subscription
  Future<void> stop() async {
    _cancelReconnectTimer();
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
    _isSubscribed = false;
    _processedEventIds.clear();
    _reconnectAttempts = 0;
    if (!_disposed) {
      notifyListeners();
    }
    _logger.debug(' Subscription stopped');
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_disposed || (_reconnectTimer?.isActive ?? false)) {
      return; // Service disposed or already scheduled
    }

    final delayIndex = _reconnectAttempts < _backoffDelays.length
        ? _reconnectAttempts
        : _backoffDelays.length - 1;
    final delaySeconds = _backoffDelays[delayIndex];

    _logger.debug(
      ' Scheduling reconnect in ${delaySeconds}s (attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed && !_isSubscribed && _supabase.auth.currentUser != null) {
        _reconnectAttempts++;
        _logger.debug(' Attempting to reconnect...');
        start();
      }
    });
  }

  /// Cancel any pending reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Handle INSERT events
  void _handleInsert(PostgresChangePayload payload) {
    try {
      final newRow = payload.newRecord;
      final id = newRow['id'] as String?;

      if (id == null) {
        _logger.debug(' INSERT missing ID');
        return;
      }

      // Deduplicate events
      if (_processedEventIds.contains(id)) {
        _logger.debug(' Duplicate INSERT event for ID: $id');
        return;
      }

      _processedEventIds.add(id);
      _pruneProcessedIds();

      _logger.debug(' New item inserted: $id');

      // Emit events for UI update
      _listRefreshController.add(InboxRealtimeEvent.itemInserted);
      _listRefreshController.add(InboxRealtimeEvent.listChanged);

      // Notify listeners (triggers badge update)
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      _logger.debug(' Error handling INSERT: $e');
    }
  }

  /// Handle DELETE events
  void _handleDelete(PostgresChangePayload payload) {
    try {
      final oldRow = payload.oldRecord;
      final id = oldRow['id'] as String?;

      if (id == null) {
        _logger.debug(' DELETE missing ID');
        return;
      }

      // For deletes, we use a different dedup key
      final deleteKey = 'delete_$id';
      if (_processedEventIds.contains(deleteKey)) {
        _logger.debug(' Duplicate DELETE event for ID: $id');
        return;
      }

      _processedEventIds.add(deleteKey);
      _pruneProcessedIds();

      _logger.debug(' Item deleted: $id');

      // Emit events for UI update
      _listRefreshController.add(InboxRealtimeEvent.itemDeleted);
      _listRefreshController.add(InboxRealtimeEvent.listChanged);

      // Notify listeners (triggers badge update)
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      _logger.debug(' Error handling DELETE: $e');
    }
  }

  /// Prune processed IDs to prevent memory growth
  void _pruneProcessedIds() {
    if (_processedEventIds.length > _maxProcessedIds) {
      // Keep only the most recent IDs
      final toKeep = _processedEventIds
          .toList()
          .skip(_processedEventIds.length - (_maxProcessedIds ~/ 2))
          .toSet();
      _processedEventIds.clear();
      _processedEventIds.addAll(toKeep);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnectTimer();
    stop();
    _listRefreshController.close();
    super.dispose();
  }
}
