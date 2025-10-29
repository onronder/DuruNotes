import 'dart:async';
import 'dart:collection';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages connection pooling and rate limiting for Supabase operations
/// Ensures we don't overwhelm the database with too many concurrent connections
class ConnectionManager {
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();
  // Singleton pattern
  static final ConnectionManager _instance = ConnectionManager._internal();

  final AppLogger _logger = LoggerFactory.instance;

  // Connection limits
  static const int maxRealtimeChannels =
      1; // Force single channel via unified service
  static const int maxConcurrentQueries = 5;
  static const int maxQueriesPerSecond = 10;

  // Active connection tracking
  int _activeRealtimeChannels = 0;
  int _activeQueries = 0;
  final Queue<_QueuedRequest<dynamic>> _queryQueue = Queue<_QueuedRequest<dynamic>>();

  // Rate limiting
  final List<DateTime> _queryTimestamps = [];
  Timer? _queueProcessor;

  // Statistics
  int _totalQueriesExecuted = 0;
  int _totalQueriesQueued = 0;
  int _totalQueriesRejected = 0;

  // Realtime channel management
  RealtimeChannel? _unifiedChannel;

  /// Register a realtime channel
  bool registerRealtimeChannel(RealtimeChannel channel) {
    if (_activeRealtimeChannels >= maxRealtimeChannels) {
      _logger.debug(
        '[ConnectionManager] Rejected realtime channel - limit reached',
      );
      _totalQueriesRejected++;
      return false;
    }

    _activeRealtimeChannels++;
    _unifiedChannel = channel;
    _logger.debug(
      '[ConnectionManager] Registered realtime channel (active: $_activeRealtimeChannels)',
    );
    return true;
  }

  /// Unregister a realtime channel
  void unregisterRealtimeChannel(RealtimeChannel channel) {
    if (_unifiedChannel == channel) {
      _unifiedChannel = null;
      _activeRealtimeChannels--;
      _logger.debug(
        '[ConnectionManager] Unregistered realtime channel (active: $_activeRealtimeChannels)',
      );
    }
  }

  /// Execute a database query with connection pooling and rate limiting
  Future<T> executeQuery<T>(
    String queryName,
    Future<T> Function() query, {
    bool priority = false,
  }) async {
    // Clean old timestamps
    _cleanOldTimestamps();

    // Check rate limit
    if (_queryTimestamps.length >= maxQueriesPerSecond) {
      // Queue the request
      return _queueQuery(queryName, query, priority);
    }

    // Check concurrent limit
    if (_activeQueries >= maxConcurrentQueries) {
      // Queue the request
      return _queueQuery(queryName, query, priority);
    }

    // Execute immediately
    return _executeNow(queryName, query);
  }

  /// Execute query immediately
  Future<T> _executeNow<T>(String queryName, Future<T> Function() query) async {
    _activeQueries++;
    _queryTimestamps.add(DateTime.now());
    _totalQueriesExecuted++;

    try {
      _logger.debug(
        '[ConnectionManager] Executing query: $queryName (active: $_activeQueries)',
      );
      final result = await query();
      return result;
    } catch (e) {
      _logger.debug('[ConnectionManager] Query failed: $queryName - $e');
      rethrow;
    } finally {
      _activeQueries--;
      _processQueue();
    }
  }

  /// Queue a query for later execution
  Future<T> _queueQuery<T>(
    String queryName,
    Future<T> Function() query,
    bool priority,
  ) async {
    final completer = Completer<T>();
    final request = _QueuedRequest<T>(
      name: queryName,
      query: query,
      completer: completer,
      priority: priority,
      queuedAt: DateTime.now(),
    );

    if (priority) {
      // Add to front of queue
      final tempQueue = Queue<_QueuedRequest<dynamic>>.from(_queryQueue);
      _queryQueue.clear();
      _queryQueue.add(request);
      _queryQueue.addAll(tempQueue);
    } else {
      _queryQueue.add(request);
    }

    _totalQueriesQueued++;
    _logger.debug(
      '[ConnectionManager] Queued query: $queryName (queue size: ${_queryQueue.length})',
    );

    // Start queue processor if not running
    _startQueueProcessor();

    return completer.future;
  }

  /// Process queued requests
  void _processQueue() {
    if (_queryQueue.isEmpty) return;

    _cleanOldTimestamps();

    // Check if we can process more requests
    while (_queryQueue.isNotEmpty &&
        _activeQueries < maxConcurrentQueries &&
        _queryTimestamps.length < maxQueriesPerSecond) {
      final request = _queryQueue.removeFirst();

      // Check if request is too old (timeout after 30 seconds)
      if (DateTime.now().difference(request.queuedAt).inSeconds > 30) {
        request.completer.completeError(
          TimeoutException('Query timed out in queue: ${request.name}'),
        );
        continue;
      }

      // Execute the queued request
      _activeQueries++;
      _queryTimestamps.add(DateTime.now());
      _totalQueriesExecuted++;

      _logger.debug(
        '[ConnectionManager] Processing queued query: ${request.name}',
      );

      request
          .query()
          .then(request.completer.complete)
          .catchError(request.completer.completeError)
          .whenComplete(() {
        _activeQueries--;
        _processQueue(); // Process next in queue
      });
    }
  }

  /// Start the queue processor timer
  void _startQueueProcessor() {
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _processQueue();
    });
  }

  /// Clean timestamps older than 1 second
  void _cleanOldTimestamps() {
    final now = DateTime.now();
    _queryTimestamps.removeWhere((timestamp) {
      return now.difference(timestamp).inSeconds >= 1;
    });
  }

  /// Get connection statistics
  Map<String, dynamic> getStatistics() {
    return {
      'activeRealtimeChannels': _activeRealtimeChannels,
      'activeQueries': _activeQueries,
      'queuedQueries': _queryQueue.length,
      'totalExecuted': _totalQueriesExecuted,
      'totalQueued': _totalQueriesQueued,
      'totalRejected': _totalQueriesRejected,
      'currentQPS': _queryTimestamps.length,
    };
  }

  /// Reset statistics
  void resetStatistics() {
    _totalQueriesExecuted = 0;
    _totalQueriesQueued = 0;
    _totalQueriesRejected = 0;
  }

  /// Dispose of resources
  void dispose() {
    _queueProcessor?.cancel();
    _queryQueue.clear();
    _queryTimestamps.clear();
  }
}

/// Queued request wrapper
class _QueuedRequest<T> {
  _QueuedRequest({
    required this.name,
    required this.query,
    required this.completer,
    required this.priority,
    required this.queuedAt,
  });
  final String name;
  final Future<T> Function() query;
  final Completer<T> completer;
  final bool priority;
  final DateTime queuedAt;
}

/// Extension to wrap Supabase queries with connection management
extension ConnectionManagedQuery on SupabaseClient {
  /// Execute a query with connection management
  Future<T> managedQuery<T>(
    String queryName,
    Future<T> Function() query, {
    bool priority = false,
  }) {
    return ConnectionManager().executeQuery(
      queryName,
      query,
      priority: priority,
    );
  }
}

/// Mixin for classes that need connection management
mixin ConnectionManaged {
  final _connectionManager = ConnectionManager();

  /// Execute a managed query
  Future<T> managedQuery<T>(
    String queryName,
    Future<T> Function() query, {
    bool priority = false,
  }) {
    return _connectionManager.executeQuery(
      queryName,
      query,
      priority: priority,
    );
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return _connectionManager.getStatistics();
  }
}
