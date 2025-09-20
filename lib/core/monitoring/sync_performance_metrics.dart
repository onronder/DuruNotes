import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Tracks performance metrics for task synchronization
class SyncPerformanceMetrics {
  static final SyncPerformanceMetrics _instance = SyncPerformanceMetrics._();
  static SyncPerformanceMetrics get instance => _instance;
  
  SyncPerformanceMetrics._();
  
  final AppLogger _logger = LoggerFactory.instance;
  
  // Metrics storage
  int _pendingSyncs = 0;
  int _completedSyncs = 0;
  int _failedSyncs = 0;
  Duration _totalSyncTime = Duration.zero;
  Duration _maxSyncTime = Duration.zero;
  Duration _minSyncTime = const Duration(days: 1); // Start with large value
  
  // Track rapid toggles
  final Map<String, List<DateTime>> _toggleHistory = {};
  static const _rapidToggleWindow = Duration(seconds: 5);
  static const _rapidToggleThreshold = 5;
  
  // Track sync queue depth
  final Map<String, int> _queueDepth = {};
  int _maxQueueDepth = 0;
  
  /// Start tracking a sync operation
  String startSync({
    required String noteId,
    required String syncType,
    Map<String, dynamic>? metadata,
  }) {
    final syncId = '${noteId}_${DateTime.now().millisecondsSinceEpoch}';
    _pendingSyncs++;
    
    // Track queue depth
    _queueDepth[noteId] = (_queueDepth[noteId] ?? 0) + 1;
    if (_queueDepth[noteId]! > _maxQueueDepth) {
      _maxQueueDepth = _queueDepth[noteId]!;
    }
    
    _logger.debug('Sync started', data: {
      'syncId': syncId,
      'noteId': noteId,
      'syncType': syncType,
      'pendingSyncs': _pendingSyncs,
      'queueDepth': _queueDepth[noteId],
      ...?metadata,
    });
    
    return syncId;
  }
  
  /// Record sync completion
  void recordSync({
    required String syncId,
    required Duration duration,
    required bool success,
    String? error,
  }) {
    _pendingSyncs--;
    
    if (success) {
      _completedSyncs++;
      _totalSyncTime += duration;
      
      if (duration > _maxSyncTime) {
        _maxSyncTime = duration;
      }
      if (duration < _minSyncTime) {
        _minSyncTime = duration;
      }
    } else {
      _failedSyncs++;
    }
    
    // Update queue depth
    final noteId = syncId.split('_').first;
    if (_queueDepth.containsKey(noteId)) {
      _queueDepth[noteId] = (_queueDepth[noteId]! - 1).clamp(0, 999);
    }
    
    _logger.debug('Sync completed', data: {
      'syncId': syncId,
      'duration': duration.inMilliseconds,
      'success': success,
      'error': error,
      'pendingSyncs': _pendingSyncs,
      'totalCompleted': _completedSyncs,
      'totalFailed': _failedSyncs,
    });
  }
  
  /// Record a task toggle event
  void recordToggle(String taskId) {
    final now = DateTime.now();
    _toggleHistory[taskId] ??= [];
    _toggleHistory[taskId]!.add(now);
    
    // Clean up old entries
    _toggleHistory[taskId]!.removeWhere(
      (time) => now.difference(time) > _rapidToggleWindow,
    );
    
    // Check for rapid toggling
    if (_toggleHistory[taskId]!.length >= _rapidToggleThreshold) {
      _logger.warning('Rapid task toggling detected', data: {
        'taskId': taskId,
        'toggleCount': _toggleHistory[taskId]!.length,
        'windowSeconds': _rapidToggleWindow.inSeconds,
      });
    }
  }
  
  /// Get average sync time
  double get averageSyncTime {
    if (_completedSyncs == 0) return 0;
    return _totalSyncTime.inMilliseconds / _completedSyncs;
  }
  
  /// Get success rate
  double get successRate {
    final total = _completedSyncs + _failedSyncs;
    if (total == 0) return 1.0;
    return _completedSyncs / total;
  }
  
  /// Get current metrics summary
  Map<String, dynamic> getMetricsSummary() {
    return {
      'pendingSyncs': _pendingSyncs,
      'completedSyncs': _completedSyncs,
      'failedSyncs': _failedSyncs,
      'successRate': successRate,
      'averageSyncTime': averageSyncTime,
      'maxSyncTime': _maxSyncTime.inMilliseconds,
      'minSyncTime': _minSyncTime.inMilliseconds,
      'maxQueueDepth': _maxQueueDepth,
      'currentQueueDepths': Map.from(_queueDepth),
    };
  }
  
  /// Reset metrics (for testing or periodic reset)
  void reset() {
    _pendingSyncs = 0;
    _completedSyncs = 0;
    _failedSyncs = 0;
    _totalSyncTime = Duration.zero;
    _maxSyncTime = Duration.zero;
    _minSyncTime = const Duration(days: 1);
    _toggleHistory.clear();
    _queueDepth.clear();
    _maxQueueDepth = 0;
  }
  
  /// Log current metrics
  void logMetrics() {
    _logger.info('Sync Performance Metrics', data: getMetricsSummary());
  }
}

/// Helper class to time operations
class SyncTimer {
  final Stopwatch _stopwatch = Stopwatch();
  final String syncId;
  final SyncPerformanceMetrics _metrics;
  
  SyncTimer(this.syncId, this._metrics) {
    _stopwatch.start();
  }
  
  /// Stop timer and record metrics
  void stop({required bool success, String? error}) {
    _stopwatch.stop();
    _metrics.recordSync(
      syncId: syncId,
      duration: _stopwatch.elapsed,
      success: success,
      error: error,
    );
  }
}
