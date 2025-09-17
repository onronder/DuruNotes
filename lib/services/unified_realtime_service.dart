import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/connection_manager.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event types for database changes
enum DatabaseTableType { notes, folders, clipperInbox, tasks }

/// Unified database change event
class DatabaseChangeEvent {
  DatabaseChangeEvent({
    required this.table,
    required this.eventType,
    required this.newRecord,
    this.oldRecord,
    this.id,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DatabaseChangeEvent.fromPayload(
    DatabaseTableType table,
    PostgresChangePayload payload,
  ) {
    return DatabaseChangeEvent(
      table: table,
      eventType: payload.eventType,
      newRecord: payload.newRecord,
      oldRecord: payload.oldRecord,
      id: payload.newRecord['id']?.toString(),
      timestamp: DateTime.now(),
    );
  }
  final DatabaseTableType table;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic>? oldRecord;
  final String? id;
  final DateTime timestamp;

  /// Helper getter for accessing new record data
  Map<String, dynamic> get data => newRecord;
}

/// Exception types for realtime service
class RealtimeException implements Exception {
  RealtimeException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'RealtimeException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

class RealtimeConnectionException extends RealtimeException {
  RealtimeConnectionException(super.message, [super.cause]);
}

class RealtimeSubscriptionException extends RealtimeException {
  RealtimeSubscriptionException(super.message, [super.cause]);
}

/// Unified Realtime Service - Single source of truth for all realtime subscriptions
/// This replaces NotesRealtimeService, InboxRealtimeService, FolderRealtimeService,
/// and duplicate subscriptions in SyncService and ClipperInboxService
class UnifiedRealtimeService extends ChangeNotifier {
  UnifiedRealtimeService({
    required SupabaseClient supabase,
    required this.userId,
    required AppLogger logger,
    ConnectionManager? connectionManager,
    FolderSyncCoordinator? folderSyncCoordinator,
  }) : _supabase = supabase,
       _logger = logger,
       _connectionManager = connectionManager ?? ConnectionManager(),
       _folderSyncCoordinator = folderSyncCoordinator {
    // Start periodic cleanup of processed event IDs
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupProcessedIds();
    });
  }

  /// Factory constructor for creating with default dependencies
  factory UnifiedRealtimeService.withDefaults({
    required SupabaseClient supabase,
    required String userId,
  }) {
    return UnifiedRealtimeService(
      supabase: supabase,
      userId: userId,
      logger: LoggerFactory.instance,
      connectionManager: ConnectionManager(),
    );
  }
  final SupabaseClient _supabase;
  final String userId;
  final AppLogger _logger;
  final ConnectionManager _connectionManager;
  final FolderSyncCoordinator? _folderSyncCoordinator;

  // Single channel for all subscriptions
  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  bool _disposed = false;

  // Event streams for different tables
  final _notesController = StreamController<DatabaseChangeEvent>.broadcast();
  final _foldersController = StreamController<DatabaseChangeEvent>.broadcast();
  final _inboxController = StreamController<DatabaseChangeEvent>.broadcast();
  final _tasksController = StreamController<DatabaseChangeEvent>.broadcast();

  // Public streams
  Stream<DatabaseChangeEvent> get notesStream => _notesController.stream;
  Stream<DatabaseChangeEvent> get foldersStream => _foldersController.stream;
  Stream<DatabaseChangeEvent> get inboxStream => _inboxController.stream;
  Stream<DatabaseChangeEvent> get tasksStream => _tasksController.stream;

  // Connection state
  bool get isSubscribed => _isSubscribed;

  // Reconnection management
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const List<int> _backoffDelays = [1, 2, 4, 8, 16];

  // Event deduplication
  final Set<String> _processedEventIds = {};
  static const int _maxProcessedIds = 100;
  Timer? _cleanupTimer;

  // Debouncing for rapid updates
  final Map<String, Timer> _debounceTimers = {};
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  /// Start the unified realtime subscription
  Future<void> start() async {
    if (_disposed) {
      _logger.warning('Cannot start - service disposed');
      return;
    }

    if (_isSubscribed || _channel != null) {
      _logger.debug('Already subscribed, skipping start');
      return;
    }

    try {
      _logger.info('Starting unified subscription', data: {'userId': userId});

      // Create single channel with all table listeners
      _channel = await _createChannel();

      // Register with connection manager
      final registered = _connectionManager.registerRealtimeChannel(_channel!);
      if (!registered) {
        _logger.error(
          'Failed to register with ConnectionManager - limit reached',
        );
        _channel = null;
        throw RealtimeConnectionException('Realtime channel limit reached');
      }

      // Subscribe to the channel
      await _subscribeToChannel();
    } on RealtimeException {
      rethrow;
    } catch (e, stack) {
      _logger.error(
        'Unexpected error during subscription',
        error: e,
        stackTrace: stack,
      );
      _isSubscribed = false;
      if (!_disposed) {
        notifyListeners();
        await _scheduleReconnect();
      }
      throw RealtimeException('Failed to start subscription', e);
    }
  }

  /// Create the realtime channel with all table listeners
  Future<RealtimeChannel> _createChannel() async {
    return _supabase
        .channel('unified_changes_$userId')
        // Notes table changes
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              _handleChange(DatabaseTableType.notes, payload),
        )
        // Folders table changes
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'folders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              _handleChange(DatabaseTableType.folders, payload),
        )
        // Clipper inbox changes (inserts only for performance)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clipper_inbox',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              _handleChange(DatabaseTableType.clipperInbox, payload),
        )
        // Tasks table changes
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              _handleChange(DatabaseTableType.tasks, payload),
        );
  }

  /// Subscribe to the channel
  Future<void> _subscribeToChannel() async {
    if (_channel == null) {
      throw RealtimeException('Channel not initialized');
    }

    final completer = Completer<void>();

    _channel!.subscribe((status, error) {
      _handleSubscriptionStatus(status, error);

      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed) {
        if (!completer.isCompleted) {
          completer.completeError(
            RealtimeSubscriptionException(
              'Subscription failed: $status',
              error,
            ),
          );
        }
      }
    });

    // Wait for subscription with timeout
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw RealtimeSubscriptionException('Subscription timeout');
        },
      );
    } on TimeoutException catch (e) {
      throw RealtimeSubscriptionException('Subscription timeout', e);
    }
  }

  /// Handle database changes with deduplication and debouncing
  void _handleChange(DatabaseTableType table, PostgresChangePayload payload) {
    if (_disposed) return;

    try {
      // Generate unique event ID
      final eventId =
          '${table.name}_${payload.eventType.name}_${payload.newRecord['id']}_${DateTime.now().millisecondsSinceEpoch}';

      // Check for duplicate events
      if (_processedEventIds.contains(eventId)) {
        _logger.debug('Duplicate event ignored', data: {'eventId': eventId});
        return;
      }

      // Add to processed set
      _processedEventIds.add(eventId);
      if (_processedEventIds.length > _maxProcessedIds) {
        _cleanupProcessedIds();
      }

      // Create event
      final event = DatabaseChangeEvent.fromPayload(table, payload);

      // Debounce rapid updates to the same record
      final debounceKey = '${table.name}_${event.id}';
      _debounceTimers[debounceKey]?.cancel();

      if (payload.eventType == PostgresChangeEvent.update) {
        // Debounce updates to prevent rapid fire
        _debounceTimers[debounceKey] = Timer(_debounceDuration, () {
          _emitEvent(table, event);
          _debounceTimers.remove(debounceKey);
        });
      } else {
        // Emit inserts and deletes immediately
        _emitEvent(table, event);
      }

      _logger.debug(
        'Event processed',
        data: {'table': table.name, 'eventType': payload.eventType.name},
      );
    } catch (e, stack) {
      _logger.error('Error handling change event', error: e, stackTrace: stack);
    }
  }

  /// Emit event to appropriate stream
  void _emitEvent(DatabaseTableType table, DatabaseChangeEvent event) {
    if (_disposed) return;

    try {
      switch (table) {
        case DatabaseTableType.notes:
          _notesController.add(event);
          break;
        case DatabaseTableType.folders:
          _foldersController.add(event);
          // Also notify sync coordinator for conflict resolution if available
          if (_folderSyncCoordinator != null) {
            _handleFolderRealtimeUpdate(event);
          }
          break;
        case DatabaseTableType.clipperInbox:
          _inboxController.add(event);
          break;
        case DatabaseTableType.tasks:
          _tasksController.add(event);
          break;
      }

      // Notify listeners for UI updates
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e, stack) {
      _logger.error('Error emitting event', error: e, stackTrace: stack);
    }
  }

  /// Handle subscription status changes
  void _handleSubscriptionStatus(
    RealtimeSubscribeStatus status, [
    Object? error,
  ]) {
    _logger.debug(
      'Subscription status changed',
      data: {'status': status.name, 'error': error?.toString()},
    );

    if (status == RealtimeSubscribeStatus.subscribed) {
      _isSubscribed = true;
      _reconnectAttempts = 0;
      _cancelReconnectTimer();
      if (!_disposed) {
        notifyListeners();
      }
      _logger.info('Successfully subscribed to all tables');
    } else if (status == RealtimeSubscribeStatus.closed ||
        status == RealtimeSubscribeStatus.channelError) {
      _isSubscribed = false;
      if (!_disposed) {
        notifyListeners();
        // Fire and forget the reconnect scheduling
        _scheduleReconnect().catchError((Object e) {
          _logger.error('Failed to schedule reconnect', error: e);
        });
      }
    }
  }

  /// Schedule reconnection with exponential backoff
  Future<void> _scheduleReconnect() async {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) {
      _logger.warning(
        'Max reconnect attempts reached or disposed',
        data: {
          'attempts': _reconnectAttempts,
          'maxAttempts': _maxReconnectAttempts,
          'disposed': _disposed,
        },
      );
      return;
    }

    _cancelReconnectTimer();

    final delaySeconds =
        _backoffDelays[_reconnectAttempts.clamp(0, _backoffDelays.length - 1)];
    _logger.info(
      'Scheduling reconnect',
      data: {'delaySeconds': delaySeconds, 'attempt': _reconnectAttempts + 1},
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!_disposed) {
        _reconnectAttempts++;
        try {
          await stop();
          await start();
        } on RealtimeException catch (e) {
          _logger.error('Reconnect failed', error: e);
          // Continue with exponential backoff
          await _scheduleReconnect();
        } catch (e, stack) {
          _logger.error(
            'Unexpected error during reconnect',
            error: e,
            stackTrace: stack,
          );
          // Continue with exponential backoff
          await _scheduleReconnect();
        }
      }
    });
  }

  /// Stop the realtime subscription
  Future<void> stop() async {
    _logger.info('Stopping subscription');

    _cancelReconnectTimer();
    _cancelAllDebounceTimers();

    if (_channel != null) {
      try {
        // Unregister from connection manager
        _connectionManager.unregisterRealtimeChannel(_channel!);
        await _channel!.unsubscribe();
      } catch (e, stack) {
        _logger.error('Error during unsubscribe', error: e, stackTrace: stack);
      } finally {
        _channel = null;
      }
    }

    _isSubscribed = false;
    _processedEventIds.clear();
    _reconnectAttempts = 0;

    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Handle folder realtime updates with sync coordinator
  Future<void> _handleFolderRealtimeUpdate(DatabaseChangeEvent event) async {
    if (_folderSyncCoordinator == null) {
      return;
    }

    try {
      // Convert event to payload format for sync coordinator
      final payload = <String, dynamic>{
        'id': event.id,
        'name': event.data['name'],
        'parent_id': event.data['parent_id'],
        'color': event.data['color'],
        'icon': event.data['icon'],
        'description': event.data['description'],
        'updated_at': event.data['updated_at'],
        'deleted': event.data['deleted'] ?? false,
      };

      await _folderSyncCoordinator.handleRealtimeUpdate(payload);
    } catch (e, stack) {
      _logger.error(
        'Failed to handle folder realtime update',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Clean up processed event IDs to prevent memory leak
  void _cleanupProcessedIds() {
    if (_processedEventIds.length > _maxProcessedIds) {
      final toRemove = _processedEventIds.length - (_maxProcessedIds ~/ 2);
      final ids = _processedEventIds.toList();
      for (var i = 0; i < toRemove; i++) {
        _processedEventIds.remove(ids[i]);
      }
      _logger.debug(
        'Cleaned up processed event IDs',
        data: {'removed': toRemove, 'remaining': _processedEventIds.length},
      );
    }
  }

  /// Cancel reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Cancel all debounce timers
  void _cancelAllDebounceTimers() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Dispose of the service and clean up resources
  @override
  void dispose() {
    _logger.info('Disposing service');
    _disposed = true;

    // Stop subscription (fire and forget)
    stop().catchError((Object e) {
      _logger.error('Error during dispose stop', error: e);
    });

    // Cancel timers
    _cleanupTimer?.cancel();
    _cancelReconnectTimer();
    _cancelAllDebounceTimers();

    // Close stream controllers
    _notesController.close();
    _foldersController.close();
    _inboxController.close();
    _tasksController.close();

    super.dispose();
  }

  /// Get service statistics for monitoring
  Map<String, dynamic> getStatistics() {
    return {
      'isSubscribed': _isSubscribed,
      'reconnectAttempts': _reconnectAttempts,
      'processedEventsCount': _processedEventIds.length,
      'activeDebounceTimers': _debounceTimers.length,
      'userId': userId,
    };
  }
}
