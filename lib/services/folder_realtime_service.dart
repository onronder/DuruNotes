import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection states for the realtime service
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  offline,
}

/// Service to handle realtime updates for folders with resilience
class FolderRealtimeService {
  FolderRealtimeService({
    required this.supabase,
    required this.ref,
  });

  final SupabaseClient supabase;
  final Ref ref;

  // Subscription management
  RealtimeChannel? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Timers
  Timer? _debounceTimer;
  Timer? _reconnectTimer;

  // State tracking
  ConnectionState _state = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  String? _currentUserId;

  // Backoff configuration
  static const int _initialBackoffMs = 1000; // 1 second
  static const int _maxBackoffMs = 30000; // 30 seconds
  static const int _maxReconnectAttempts = 10;

  /// Current connection state
  ConnectionState get state => _state;

  /// Start listening for folder changes
  Future<void> start() async {
    if (_isDisposed) {
      debugPrint('[FolderRealtime] Service is disposed, cannot start');
      return;
    }

    // Clean up any existing subscription
    await _cleanup();

    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[FolderRealtime] No authenticated user, skipping start');
      _setState(ConnectionState.disconnected);
      return;
    }

    _currentUserId = user.id;

    // Set up connectivity monitoring
    _setupConnectivityMonitoring();

    // Check initial connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      debugPrint('[FolderRealtime] No network connectivity, waiting...');
      _setState(ConnectionState.offline);
      return;
    }

    // Attempt to connect
    await _connect();
  }

  /// Set up network connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = !results.contains(ConnectivityResult.none);

        if (hasConnection && _state == ConnectionState.offline) {
          debugPrint(
              '[FolderRealtime] Network restored, attempting reconnection');
          _setState(ConnectionState.disconnected);
          _scheduleReconnect(immediate: true);
        } else if (!hasConnection && _state != ConnectionState.offline) {
          debugPrint('[FolderRealtime] Network lost, pausing service');
          _setState(ConnectionState.offline);
          _cancelReconnect();
        }
      },
    );
  }

  /// Connect to realtime channel
  Future<void> _connect() async {
    if (_isDisposed || _currentUserId == null) return;

    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      debugPrint('[FolderRealtime] Already ${_state.name}, skipping connect');
      return;
    }

    _setState(ConnectionState.connecting);

    try {
      debugPrint(
          '[FolderRealtime] Connecting for user $_currentUserId (attempt ${_reconnectAttempts + 1})');

      // Create new channel
      _subscription = supabase
          .channel('realtime:folders:$_currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all, // INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'folders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUserId!,
            ),
            callback: (payload) => _onFolderChanged(payload),
          )
          .subscribe((status, error) {
        // Handle subscription status
        _onSubscriptionStatusChanged(status, error);
      });

      // Wait a moment for connection to establish
      await Future<void>.delayed(const Duration(seconds: 2));

      // Check if we're actually connected
      if (_state == ConnectionState.connecting) {
        // Assume connected if no error occurred
        _handleSubscribed();
      }
    } catch (e) {
      debugPrint('[FolderRealtime] Connection error: $e');
      _handleConnectionError(e);
    }
  }

  /// Handle subscription status changes
  void _onSubscriptionStatusChanged(RealtimeSubscribeStatus status,
      [Object? error]) {
    debugPrint('[FolderRealtime] Subscription status: $status, error: $error');

    if (error != null) {
      _handleConnectionError(error);
    } else if (status == RealtimeSubscribeStatus.subscribed) {
      _handleSubscribed();
    } else if (status == RealtimeSubscribeStatus.closed ||
        status == RealtimeSubscribeStatus.channelError) {
      _handleDisconnected();
    } else if (status == RealtimeSubscribeStatus.timedOut) {
      _handleTimeout();
    }
  }

  /// Handle successful subscription
  void _handleSubscribed() {
    debugPrint('[FolderRealtime] Successfully subscribed');
    _setState(ConnectionState.connected);
    _reconnectAttempts = 0; // Reset backoff
    _cancelReconnect();
  }

  /// Handle disconnection
  void _handleDisconnected() {
    if (_state == ConnectionState.disconnected || _isDisposed) return;

    debugPrint('[FolderRealtime] Channel disconnected');
    _setState(ConnectionState.error);
    _scheduleReconnect();
  }

  /// Handle timeout
  void _handleTimeout() {
    debugPrint('[FolderRealtime] Channel timed out');
    _setState(ConnectionState.error);
    _scheduleReconnect();
  }

  /// Handle connection error
  void _handleConnectionError(dynamic error) {
    debugPrint('[FolderRealtime] Connection error: $error');
    _setState(ConnectionState.error);

    // Clean up failed subscription
    _cleanupSubscription();

    // Schedule reconnect with backoff
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect({bool immediate = false}) {
    if (_isDisposed || _state == ConnectionState.offline) return;

    // Cancel any existing reconnect timer
    _cancelReconnect();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[FolderRealtime] Max reconnect attempts reached, giving up');
      _setState(ConnectionState.error);
      return;
    }

    // Calculate backoff delay
    final delayMs = immediate ? 0 : _calculateBackoff();
    debugPrint('[FolderRealtime] Scheduling reconnect in ${delayMs}ms');

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!_isDisposed && _state != ConnectionState.offline) {
        _reconnectAttempts++;
        await _connect();
      }
    });
  }

  /// Calculate exponential backoff delay
  int _calculateBackoff() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
    final delay = _initialBackoffMs * math.pow(2, _reconnectAttempts).toInt();
    return math.min(delay, _maxBackoffMs);
  }

  /// Cancel reconnection timer
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Update connection state
  void _setState(ConnectionState newState) {
    if (_state != newState) {
      debugPrint('[FolderRealtime] State change: $_state → $newState');
      _state = newState;
    }
  }

  /// Handle folder change events with debouncing
  void _onFolderChanged(PostgresChangePayload payload) {
    if (_isDisposed) return;

    debugPrint('[FolderRealtime] Folder change detected: ${payload.eventType}');

    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Debounce folder refresh (300ms to coalesce rapid changes)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed) return;

      try {
        debugPrint('[FolderRealtime] Refreshing folders after change');

        // Refresh folder hierarchy (updates tree used by picker)
        // This also triggers rootFoldersProvider rebuild automatically
        await ref.read(folderHierarchyProvider.notifier).loadFolders();

        debugPrint('[FolderRealtime] Folder refresh completed');
      } catch (e) {
        debugPrint('[FolderRealtime] Error refreshing folders: $e');
      }
    });
  }

  /// Clean up subscription resources
  void _cleanupSubscription() {
    if (_subscription != null) {
      try {
        supabase.removeChannel(_subscription!);
      } catch (e) {
        debugPrint('[FolderRealtime] Error removing channel: $e');
      }
      _subscription = null;
    }
  }

  /// Clean up all resources
  Future<void> _cleanup() async {
    debugPrint('[FolderRealtime] Cleaning up resources');

    // Cancel timers
    _debounceTimer?.cancel();
    _debounceTimer = null;

    _cancelReconnect();

    // Clean up subscription
    _cleanupSubscription();

    // Reset state
    _reconnectAttempts = 0;
    _setState(ConnectionState.disconnected);
  }

  /// Stop listening for folder changes
  Future<void> stop() async {
    if (_isDisposed) return;

    debugPrint('[FolderRealtime] Stopping service');

    // Cancel connectivity monitoring
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // Clean up everything else
    await _cleanup();

    _currentUserId = null;

    debugPrint('[FolderRealtime] Service stopped');
  }

  /// Dispose of resources
  void dispose() {
    if (_isDisposed) return;

    debugPrint('[FolderRealtime] Disposing service');

    _isDisposed = true;

    // Stop everything
    stop();

    debugPrint('[FolderRealtime] Service disposed');
  }
}
