import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Metrics collector for task synchronization
class TaskSyncMetrics {
  static TaskSyncMetrics? _instance;
  static TaskSyncMetrics get instance => _instance ??= TaskSyncMetrics._();

  TaskSyncMetrics._();

  final AppLogger _logger = LoggerFactory.instance;

  // Metrics storage
  final Map<String, _SyncMetric> _metrics = {};
  final Map<String, int> _duplicateCounts = {};
  final Map<String, DateTime> _lastSyncTimes = {};

  // Performance tracking
  final List<Duration> _syncDurations = [];
  static const int _maxDurationSamples = 100;

  // Error tracking
  int _totalErrors = 0;
  int _totalSuccesses = 0;

  /// Record the start of a sync operation
  String startSync({
    required String noteId,
    required String syncType,
    Map<String, dynamic>? metadata,
  }) {
    final syncId =
        '${syncType}_${noteId}_${DateTime.now().millisecondsSinceEpoch}';
    _metrics[syncId] = _SyncMetric(
      noteId: noteId,
      syncType: syncType,
      startTime: DateTime.now(),
      metadata: metadata ?? {},
    );

    _logger.debug(
      'Started sync operation',
      data: {
        'syncId': syncId,
        'noteId': noteId,
        'syncType': syncType,
        ...?metadata,
      },
    );

    return syncId;
  }

  /// Record the end of a sync operation
  void endSync({
    required String syncId,
    bool success = true,
    int? taskCount,
    int? duplicatesFound,
    String? error,
  }) {
    final metric = _metrics[syncId];
    if (metric == null) {
      _logger.warning(
        'Attempted to end unknown sync',
        data: {'syncId': syncId},
      );
      return;
    }

    final duration = DateTime.now().difference(metric.startTime);
    metric.endTime = DateTime.now();
    metric.duration = duration;
    metric.success = success;
    metric.taskCount = taskCount;
    metric.duplicatesFound = duplicatesFound;
    metric.error = error;

    // Update aggregates
    if (success) {
      _totalSuccesses++;
      _lastSyncTimes[metric.noteId] = DateTime.now();
    } else {
      _totalErrors++;
    }

    // Track performance
    _syncDurations.add(duration);
    if (_syncDurations.length > _maxDurationSamples) {
      _syncDurations.removeAt(0);
    }

    // Track duplicates
    if (duplicatesFound != null && duplicatesFound > 0) {
      _duplicateCounts[metric.noteId] =
          (_duplicateCounts[metric.noteId] ?? 0) + duplicatesFound;
    }

    // Log the completion
    final logData = {
      'syncId': syncId,
      'noteId': metric.noteId,
      'syncType': metric.syncType,
      'duration': duration.inMilliseconds,
      'success': success,
      'taskCount': taskCount,
      'duplicatesFound': duplicatesFound,
      ...metric.metadata,
    };

    if (success) {
      _logger.info('Completed sync operation', data: logData);
    } else {
      _logger.error(
        'Sync operation failed',
        error: error ?? 'Unknown error',
        data: logData,
      );
    }

    // Alert on anomalies
    _checkForAnomalies(metric);
  }

  /// Check for anomalies in sync operations
  void _checkForAnomalies(_SyncMetric metric) {
    // Check for excessive duplicates
    if (metric.duplicatesFound != null && metric.duplicatesFound! > 5) {
      _logger.warning(
        'High duplicate count detected',
        data: {
          'noteId': metric.noteId,
          'duplicates': metric.duplicatesFound,
          'syncType': metric.syncType,
        },
      );
    }

    // Check for slow sync
    if (metric.duration != null && metric.duration!.inMilliseconds > 1000) {
      _logger.warning(
        'Slow sync operation',
        data: {
          'noteId': metric.noteId,
          'duration': metric.duration!.inMilliseconds,
          'syncType': metric.syncType,
          'taskCount': metric.taskCount,
        },
      );
    }

    // Check for frequent errors
    final recentErrors = _metrics.values
        .where(
          (m) =>
              m.noteId == metric.noteId &&
              !m.success &&
              m.endTime != null &&
              DateTime.now().difference(m.endTime!).inMinutes < 5,
        )
        .length;

    if (recentErrors >= 3) {
      _logger.error(
        'Multiple sync failures detected',
        data: {'noteId': metric.noteId, 'recentErrors': recentErrors},
      );
    }
  }

  /// Record a duplicate task detection
  void recordDuplicate({
    required String noteId,
    required String taskId,
    required String duplicateId,
    String? reason,
  }) {
    _duplicateCounts[noteId] = (_duplicateCounts[noteId] ?? 0) + 1;

    _logger.warning(
      'Duplicate task detected',
      data: {
        'noteId': noteId,
        'taskId': taskId,
        'duplicateId': duplicateId,
        'reason': reason,
        'totalDuplicates': _duplicateCounts[noteId],
      },
    );
  }

  /// Get sync performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_syncDurations.isEmpty) {
      return {
        'averageDuration': 0,
        'minDuration': 0,
        'maxDuration': 0,
        'sampleCount': 0,
      };
    }

    final sorted = List<Duration>.from(_syncDurations)..sort();
    final total = sorted.fold<int>(0, (sum, d) => sum + d.inMilliseconds);

    return {
      'averageDuration': total ~/ sorted.length,
      'minDuration': sorted.first.inMilliseconds,
      'maxDuration': sorted.last.inMilliseconds,
      'p50Duration': sorted[sorted.length ~/ 2].inMilliseconds,
      'p95Duration': sorted[(sorted.length * 0.95).floor()].inMilliseconds,
      'sampleCount': sorted.length,
    };
  }

  /// Get sync health metrics
  Map<String, dynamic> getHealthMetrics() {
    final totalSyncs = _totalSuccesses + _totalErrors;
    final successRate = totalSyncs > 0 ? _totalSuccesses / totalSyncs : 1.0;

    return {
      'totalSyncs': totalSyncs,
      'successCount': _totalSuccesses,
      'errorCount': _totalErrors,
      'successRate': (successRate * 100).toStringAsFixed(1),
      'totalDuplicatesFound': _duplicateCounts.values.fold(0, (a, b) => a + b),
      'notesWithDuplicates': _duplicateCounts.keys.length,
    };
  }

  /// Get detailed metrics for a specific note
  Map<String, dynamic> getNoteMetrics(String noteId) {
    final noteMetrics = _metrics.values
        .where((m) => m.noteId == noteId)
        .toList();

    if (noteMetrics.isEmpty) {
      return {'noteId': noteId, 'syncCount': 0};
    }

    final successCount = noteMetrics.where((m) => m.success).length;
    final errorCount = noteMetrics.where((m) => !m.success).length;
    final lastSync = _lastSyncTimes[noteId];
    final duplicates = _duplicateCounts[noteId] ?? 0;

    return {
      'noteId': noteId,
      'syncCount': noteMetrics.length,
      'successCount': successCount,
      'errorCount': errorCount,
      'duplicatesFound': duplicates,
      'lastSyncTime': lastSync?.toIso8601String(),
      'timeSinceLastSync': lastSync != null
          ? DateTime.now().difference(lastSync).inSeconds
          : null,
    };
  }

  /// Export all metrics as JSON
  Map<String, dynamic> exportMetrics() {
    return {
      'performance': getPerformanceStats(),
      'health': getHealthMetrics(),
      'timestamp': DateTime.now().toIso8601String(),
      'recentSyncs': _metrics.values
          .where((m) => m.endTime != null)
          .toList()
          .reversed
          .take(10)
          .map(
            (m) => {
              'noteId': m.noteId,
              'syncType': m.syncType,
              'duration': m.duration?.inMilliseconds,
              'success': m.success,
              'taskCount': m.taskCount,
              'duplicatesFound': m.duplicatesFound,
              'timestamp': m.endTime?.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Clear all metrics
  void clearMetrics() {
    _metrics.clear();
    _duplicateCounts.clear();
    _lastSyncTimes.clear();
    _syncDurations.clear();
    _totalErrors = 0;
    _totalSuccesses = 0;
  }
}

class _SyncMetric {
  final String noteId;
  final String syncType;
  final DateTime startTime;
  final Map<String, dynamic> metadata;

  DateTime? endTime;
  Duration? duration;
  bool success = false;
  int? taskCount;
  int? duplicatesFound;
  String? error;

  _SyncMetric({
    required this.noteId,
    required this.syncType,
    required this.startTime,
    required this.metadata,
  });
}
