// Production Database Configuration for Duru Notes
// Implementation of the database architecture recommendations

import 'dart:async';
import 'dart:isolate';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductionDatabaseConfig {
  // Connection Pool Configuration
  static const int maxConcurrentConnections = 8;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration queryTimeout = Duration(seconds: 60);
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxRetryAttempts = 3;

  // Real-time Configuration
  static const Duration realtimeReconnectDelay = Duration(seconds: 2);
  static const int maxRealtimeReconnectAttempts = 5;
  static const Duration realtimeBatchWindow = Duration(milliseconds: 500);

  // Performance Monitoring
  static const Duration performanceMonitoringInterval = Duration(minutes: 5);
  static const Duration metricsReportingInterval = Duration(minutes: 15);

  // Configure Supabase client with production optimizations
  static Future<SupabaseClient> createOptimizedClient({
    required String url,
    required String anonKey,
  }) async {
    return SupabaseClient(
      url,
      anonKey,
      httpOptions: const HttpOptions(
        receiveTimeout: connectionTimeout,
        sendTimeout: connectionTimeout,
      ),
      postgrestOptions: const PostgrestOptions(
        schema: 'public',
        isolate: false, // Reuse connections
      ),
      realtimeOptions: const RealtimeOptions(
        logLevel: RealtimeLogLevel.info,
        timeout: Duration(seconds: 30),
      ),
    );
  }
}

// Connection Pool Manager for Heavy Operations
class DatabaseConnectionManager {
  static final Semaphore _connectionSemaphore =
      Semaphore(ProductionDatabaseConfig.maxConcurrentConnections);

  static int _activeConnections = 0;
  static final StreamController<int> _connectionCountController =
      StreamController<int>.broadcast();

  static Stream<int> get connectionCountStream =>
      _connectionCountController.stream;

  static int get activeConnections => _activeConnections;

  static Future<T> withConnection<T>(
    Future<T> Function() operation, {
    Duration? timeout,
  }) async {
    await _connectionSemaphore.acquire();
    _activeConnections++;
    _connectionCountController.add(_activeConnections);

    try {
      return await operation().timeout(
        timeout ?? ProductionDatabaseConfig.queryTimeout,
      );
    } finally {
      _activeConnections--;
      _connectionCountController.add(_activeConnections);
      _connectionSemaphore.release();
    }
  }

  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int? maxAttempts,
    Duration? delay,
  }) async {
    final attempts = maxAttempts ?? ProductionDatabaseConfig.maxRetryAttempts;
    final retryDelay = delay ?? ProductionDatabaseConfig.retryDelay;

    for (int i = 0; i < attempts; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == attempts - 1) rethrow;

        // Exponential backoff
        await Future.delayed(retryDelay * (i + 1));
      }
    }

    throw Exception('Max retry attempts exceeded');
  }
}

// Semaphore implementation for connection limiting
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

// Optimized Real-time Manager
class OptimizedRealtimeManager {
  final SupabaseClient _client;
  final String _userId;

  RealtimeChannel? _notesChannel;
  RealtimeChannel? _foldersChannel;

  Timer? _batchTimer;
  final Set<String> _pendingNoteIds = {};
  final Set<String> _pendingFolderIds = {};

  // Connection state tracking
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  OptimizedRealtimeManager(this._client, this._userId);

  Future<void> initialize() async {
    await _initializeNotesChannel();
    await _initializeFoldersChannel();
  }

  Future<void> _initializeNotesChannel() async {
    _notesChannel = _client.channel('notes_$_userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: _userId,
        ),
        callback: _handleNoteChange,
      )
      ..onSubscribed(() {
        _isConnected = true;
        _reconnectAttempts = 0;
        print('Notes real-time channel connected');
      })
      ..onError((error) {
        _isConnected = false;
        print('Notes real-time error: $error');
        _scheduleReconnect();
      });

    await _notesChannel!.subscribe();
  }

  Future<void> _initializeFoldersChannel() async {
    _foldersChannel = _client.channel('folders_$_userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'folders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: _userId,
        ),
        callback: _handleFolderChange,
      )
      ..onSubscribed(() {
        print('Folders real-time channel connected');
      })
      ..onError((error) {
        print('Folders real-time error: $error');
      });

    await _foldersChannel!.subscribe();
  }

  void _handleNoteChange(PostgresChangePayload payload) {
    final noteId = payload.newRecord?['id'] ?? payload.oldRecord?['id'];
    if (noteId != null) {
      _pendingNoteIds.add(noteId.toString());
      _scheduleBatchUpdate();
    }
  }

  void _handleFolderChange(PostgresChangePayload payload) {
    final folderId = payload.newRecord?['id'] ?? payload.oldRecord?['id'];
    if (folderId != null) {
      _pendingFolderIds.add(folderId.toString());
      _scheduleBatchUpdate();
    }
  }

  void _scheduleBatchUpdate() {
    _batchTimer?.cancel();
    _batchTimer = Timer(
      ProductionDatabaseConfig.realtimeBatchWindow,
      _processBatchedUpdates,
    );
  }

  Future<void> _processBatchedUpdates() async {
    if (_pendingNoteIds.isEmpty && _pendingFolderIds.isEmpty) return;

    final noteIds = List.from(_pendingNoteIds);
    final folderIds = List.from(_pendingFolderIds);

    _pendingNoteIds.clear();
    _pendingFolderIds.clear();

    try {
      // Process batched updates through the sync service
      if (noteIds.isNotEmpty) {
        await _syncSpecificNotes(noteIds);
      }
      if (folderIds.isNotEmpty) {
        await _syncSpecificFolders(folderIds);
      }
    } catch (e) {
      print('Error processing batched updates: $e');
      // Re-add failed IDs for retry
      _pendingNoteIds.addAll(noteIds);
      _pendingFolderIds.addAll(folderIds);
    }
  }

  Future<void> _syncSpecificNotes(List<String> noteIds) async {
    // Implement efficient sync for specific notes
    // This should call your existing UnifiedTaskService or sync service
  }

  Future<void> _syncSpecificFolders(List<String> folderIds) async {
    // Implement efficient sync for specific folders
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= ProductionDatabaseConfig.maxRealtimeReconnectAttempts) {
      print('Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = ProductionDatabaseConfig.realtimeReconnectDelay * _reconnectAttempts;

    Timer(delay, () {
      print('Attempting reconnect $_reconnectAttempts');
      initialize();
    });
  }

  Future<void> dispose() async {
    _batchTimer?.cancel();
    await _notesChannel?.unsubscribe();
    await _foldersChannel?.unsubscribe();
  }
}

// Performance Monitor
class DatabasePerformanceMonitor {
  static Timer? _monitoringTimer;
  static Timer? _reportingTimer;

  static final Map<String, List<int>> _queryTimes = {};
  static int _totalQueries = 0;
  static int _failedQueries = 0;

  static void startMonitoring(SupabaseClient client) {
    _monitoringTimer = Timer.periodic(
      ProductionDatabaseConfig.performanceMonitoringInterval,
      (_) => _collectMetrics(client),
    );

    _reportingTimer = Timer.periodic(
      ProductionDatabaseConfig.metricsReportingInterval,
      (_) => _reportMetrics(client),
    );
  }

  static void recordQuery(String operation, int durationMs, {bool failed = false}) {
    _queryTimes.putIfAbsent(operation, () => []).add(durationMs);
    _totalQueries++;
    if (failed) _failedQueries++;

    // Keep only last 100 measurements per operation
    if (_queryTimes[operation]!.length > 100) {
      _queryTimes[operation]!.removeAt(0);
    }
  }

  static Future<void> _collectMetrics(SupabaseClient client) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Test basic connectivity
      await client.from('notes').select('id').limit(1);

      stopwatch.stop();
      recordQuery('connectivity_test', stopwatch.elapsedMilliseconds);

    } catch (e) {
      recordQuery('connectivity_test', 0, failed: true);
      print('Database connectivity test failed: $e');
    }
  }

  static Future<void> _reportMetrics(SupabaseClient client) async {
    if (_totalQueries == 0) return;

    try {
      final metrics = {
        'total_queries': _totalQueries,
        'failed_queries': _failedQueries,
        'success_rate': ((_totalQueries - _failedQueries) / _totalQueries * 100).round(),
        'active_connections': DatabaseConnectionManager.activeConnections,
        'query_stats': _queryTimes.map((operation, times) => MapEntry(
          operation,
          {
            'count': times.length,
            'avg_ms': times.isNotEmpty ? (times.reduce((a, b) => a + b) / times.length).round() : 0,
            'max_ms': times.isNotEmpty ? times.reduce((a, b) => a > b ? a : b) : 0,
          },
        )),
      };

      await client.from('analytics_events').insert({
        'user_id': client.auth.currentUser?.id,
        'event_type': 'database_performance_report',
        'properties': metrics,
      });

      // Reset counters
      _totalQueries = 0;
      _failedQueries = 0;

    } catch (e) {
      print('Failed to report performance metrics: $e');
    }
  }

  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _reportingTimer?.cancel();
    _monitoringTimer = null;
    _reportingTimer = null;
  }
}

// Database Health Check
class DatabaseHealthChecker {
  static Future<Map<String, dynamic>> performHealthCheck(SupabaseClient client) async {
    final results = <String, dynamic>{};

    try {
      // Test basic connectivity
      final connectivityStart = DateTime.now();
      await client.from('notes').select('id').limit(1);
      results['connectivity'] = {
        'status': 'healthy',
        'response_time_ms': DateTime.now().difference(connectivityStart).inMilliseconds,
      };

      // Test write operations
      final writeStart = DateTime.now();
      await client.from('analytics_events').insert({
        'user_id': client.auth.currentUser?.id,
        'event_type': 'health_check',
        'properties': {'test': true},
      });
      results['write_operations'] = {
        'status': 'healthy',
        'response_time_ms': DateTime.now().difference(writeStart).inMilliseconds,
      };

      // Check active connections
      results['connection_pool'] = {
        'active_connections': DatabaseConnectionManager.activeConnections,
        'max_connections': ProductionDatabaseConfig.maxConcurrentConnections,
        'utilization_percent': (DatabaseConnectionManager.activeConnections /
                               ProductionDatabaseConfig.maxConcurrentConnections * 100).round(),
      };

      results['overall_status'] = 'healthy';

    } catch (e) {
      results['overall_status'] = 'unhealthy';
      results['error'] = e.toString();
    }

    return results;
  }
}

// Usage Example
class DatabaseService {
  late final SupabaseClient _client;
  late final OptimizedRealtimeManager _realtimeManager;

  Future<void> initialize({
    required String url,
    required String anonKey,
    required String userId,
  }) async {
    // Initialize optimized client
    _client = await ProductionDatabaseConfig.createOptimizedClient(
      url: url,
      anonKey: anonKey,
    );

    // Initialize real-time manager
    _realtimeManager = OptimizedRealtimeManager(_client, userId);
    await _realtimeManager.initialize();

    // Start performance monitoring
    DatabasePerformanceMonitor.startMonitoring(_client);
  }

  Future<T> executeQuery<T>(Future<T> Function() query) async {
    return DatabaseConnectionManager.withConnection(() async {
      return DatabaseConnectionManager.withRetry(query);
    });
  }

  Future<void> dispose() async {
    DatabasePerformanceMonitor.stopMonitoring();
    await _realtimeManager.dispose();
  }
}