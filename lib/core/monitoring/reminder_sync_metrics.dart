import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Metrics collector for reminder synchronization
///
/// Tracks reminder sync operations including:
/// - Upload/download counts
/// - Conflict resolution outcomes
/// - Batch processing performance
/// - Linkage validation results
/// - UUID validation failures
/// - Sync duration and success rates
///
/// Usage:
/// ```dart
/// final metrics = ReminderSyncMetrics.instance;
///
/// // Start tracking a sync
/// final syncId = metrics.startSync(syncType: 'upload', reminderCount: 5);
///
/// // Record conflict resolution
/// metrics.recordConflict(
///   reminderId: 'reminder-123',
///   resolution: ConflictResolution.preferSnoozed,
/// );
///
/// // Complete sync tracking
/// metrics.endSync(
///   syncId: syncId,
///   success: true,
///   remindersProcessed: 5,
///   conflictsResolved: 1,
/// );
/// ```
class ReminderSyncMetrics {
  static ReminderSyncMetrics? _instance;
  static ReminderSyncMetrics get instance =>
      _instance ??= ReminderSyncMetrics._();

  ReminderSyncMetrics._();

  final AppLogger _logger = LoggerFactory.instance;

  // Metrics storage
  final Map<String, _ReminderSyncMetric> _metrics = {};
  final Map<String, DateTime> _lastSyncTimes = {};

  // Performance tracking
  final List<Duration> _syncDurations = [];
  static const int _maxDurationSamples = 100;

  // Conflict resolution tracking
  final Map<ConflictResolution, int> _conflictResolutions = {};
  int _totalConflicts = 0;

  // Linkage validation tracking
  int _orphanedLinksFound = 0;
  int _invalidUuidsFound = 0;

  // Batch processing tracking
  int _batchesProcessed = 0;
  int _totalItemsInBatches = 0;

  // Error and success tracking
  int _totalErrors = 0;
  int _totalSuccesses = 0;
  int _uploadCount = 0;
  int _downloadCount = 0;

  // CRITICAL #4: Encryption failure tracking
  int _encryptionFailures = 0;
  int _retryableEncryptionFailures = 0;
  int _nonRetryableEncryptionFailures = 0;

  /// Record the start of a sync operation
  String startSync({
    required String syncType,
    int? reminderCount,
    Map<String, dynamic>? metadata,
  }) {
    final syncId = '${syncType}_${DateTime.now().millisecondsSinceEpoch}';
    _metrics[syncId] = _ReminderSyncMetric(
      syncType: syncType,
      startTime: DateTime.now(),
      metadata: metadata ?? {},
      reminderCount: reminderCount,
    );

    _logger.debug(
      '[ReminderSync] Started sync operation',
      data: {
        'syncId': syncId,
        'syncType': syncType,
        'reminderCount': reminderCount,
        ...?metadata,
      },
    );

    return syncId;
  }

  /// Record the end of a sync operation
  void endSync({
    required String syncId,
    bool success = true,
    int? remindersProcessed,
    int? conflictsResolved,
    int? orphanedLinksCleared,
    int? invalidUuidsRejected,
    int? batchesProcessed,
    String? error,
  }) {
    final metric = _metrics[syncId];
    if (metric == null) {
      _logger.warning(
        '[ReminderSync] Attempted to end unknown sync',
        data: {'syncId': syncId},
      );
      return;
    }

    final duration = DateTime.now().difference(metric.startTime);
    metric.endTime = DateTime.now();
    metric.duration = duration;
    metric.success = success;
    metric.remindersProcessed = remindersProcessed;
    metric.conflictsResolved = conflictsResolved;
    metric.orphanedLinksCleared = orphanedLinksCleared;
    metric.invalidUuidsRejected = invalidUuidsRejected;
    metric.batchesProcessed = batchesProcessed;
    metric.error = error;

    // Update aggregates
    if (success) {
      _totalSuccesses++;
      _lastSyncTimes[syncId] = DateTime.now();

      // Track upload/download counts
      if (metric.syncType.contains('upload')) {
        _uploadCount += remindersProcessed ?? 0;
      } else if (metric.syncType.contains('download')) {
        _downloadCount += remindersProcessed ?? 0;
      }

      // Track batch processing
      if (batchesProcessed != null) {
        _batchesProcessed += batchesProcessed;
        _totalItemsInBatches += remindersProcessed ?? 0;
      }

      // Track validation issues
      if (orphanedLinksCleared != null) {
        _orphanedLinksFound += orphanedLinksCleared;
      }
      if (invalidUuidsRejected != null) {
        _invalidUuidsFound += invalidUuidsRejected;
      }
    } else {
      _totalErrors++;
    }

    // Track performance
    _syncDurations.add(duration);
    if (_syncDurations.length > _maxDurationSamples) {
      _syncDurations.removeAt(0);
    }

    // Log the completion
    final logData = {
      'syncId': syncId,
      'syncType': metric.syncType,
      'duration': duration.inMilliseconds,
      'success': success,
      'remindersProcessed': remindersProcessed,
      'conflictsResolved': conflictsResolved,
      'orphanedLinksCleared': orphanedLinksCleared,
      'invalidUuidsRejected': invalidUuidsRejected,
      'batchesProcessed': batchesProcessed,
      ...metric.metadata,
    };

    if (success) {
      _logger.info('[ReminderSync] Completed sync operation', data: logData);
    } else {
      _logger.error(
        '[ReminderSync] Sync operation failed',
        error: error ?? 'Unknown error',
        data: logData,
      );
    }

    // Alert on anomalies
    _checkForAnomalies(metric);
  }

  /// Record a conflict resolution
  void recordConflict({
    required String reminderId,
    required ConflictResolution resolution,
    Map<String, dynamic>? metadata,
  }) {
    _totalConflicts++;
    _conflictResolutions[resolution] =
        (_conflictResolutions[resolution] ?? 0) + 1;

    _logger.info(
      '[ReminderSync] Conflict resolved',
      data: {
        'reminderId': reminderId,
        'resolution': resolution.name,
        'totalConflicts': _totalConflicts,
        ...?metadata,
      },
    );
  }

  /// Record an orphaned reminder link detection
  void recordOrphanedLink({
    required String taskId,
    required String orphanedReminderId,
  }) {
    _orphanedLinksFound++;

    _logger.warning(
      '[ReminderSync] Orphaned reminder link detected',
      data: {
        'taskId': taskId,
        'orphanedReminderId': orphanedReminderId,
        'totalOrphanedLinks': _orphanedLinksFound,
      },
    );
  }

  /// Record an invalid UUID detection
  void recordInvalidUuid({
    required String context,
    required String invalidValue,
  }) {
    _invalidUuidsFound++;

    _logger.warning(
      '[ReminderSync] Invalid UUID detected',
      data: {
        'context': context,
        'invalidValue': invalidValue,
        'totalInvalidUuids': _invalidUuidsFound,
      },
    );
  }

  /// Record batch processing
  void recordBatch({
    required int batchNumber,
    required int itemsInBatch,
    required Duration batchDuration,
  }) {
    _batchesProcessed++;
    _totalItemsInBatches += itemsInBatch;

    _logger.debug(
      '[ReminderSync] Batch processed',
      data: {
        'batchNumber': batchNumber,
        'itemsInBatch': itemsInBatch,
        'batchDuration': batchDuration.inMilliseconds,
        'averagePerItem': batchDuration.inMilliseconds / itemsInBatch,
      },
    );
  }

  /// Record encryption failure (CRITICAL #4)
  ///
  /// Tracks encryption failures during sync operations to monitor:
  /// - Total encryption failures
  /// - Retryable vs non-retryable failures
  /// - Patterns indicating CryptoBox issues or key availability problems
  void recordEncryptionFailure({required bool isRetryable}) {
    _encryptionFailures++;
    if (isRetryable) {
      _retryableEncryptionFailures++;
    } else {
      _nonRetryableEncryptionFailures++;
    }

    _logger.warning(
      '[ReminderSync] Encryption failure recorded',
      data: {
        'isRetryable': isRetryable,
        'totalEncryptionFailures': _encryptionFailures,
        'retryableFailures': _retryableEncryptionFailures,
        'nonRetryableFailures': _nonRetryableEncryptionFailures,
      },
    );

    // Alert if too many encryption failures
    if (_encryptionFailures >= 5) {
      _logger.error(
        '[ReminderSync] High encryption failure rate detected',
        data: {
          'totalFailures': _encryptionFailures,
          'retryable': _retryableEncryptionFailures,
          'nonRetryable': _nonRetryableEncryptionFailures,
        },
      );
    }
  }

  /// Check for anomalies in sync operations
  void _checkForAnomalies(_ReminderSyncMetric metric) {
    // Check for high conflict rate
    if (metric.conflictsResolved != null &&
        metric.remindersProcessed != null &&
        metric.remindersProcessed! > 0) {
      final conflictRate =
          metric.conflictsResolved! / metric.remindersProcessed!;
      if (conflictRate > 0.3) {
        // More than 30% conflicts
        _logger.warning(
          '[ReminderSync] High conflict rate detected',
          data: {
            'conflictRate': (conflictRate * 100).toStringAsFixed(1),
            'conflictsResolved': metric.conflictsResolved,
            'remindersProcessed': metric.remindersProcessed,
            'syncType': metric.syncType,
          },
        );
      }
    }

    // Check for slow sync
    if (metric.duration != null && metric.duration!.inMilliseconds > 2000) {
      _logger.warning(
        '[ReminderSync] Slow sync operation',
        data: {
          'duration': metric.duration!.inMilliseconds,
          'syncType': metric.syncType,
          'remindersProcessed': metric.remindersProcessed,
          'batchesProcessed': metric.batchesProcessed,
        },
      );
    }

    // Check for excessive orphaned links
    if (metric.orphanedLinksCleared != null &&
        metric.orphanedLinksCleared! > 5) {
      _logger.warning(
        '[ReminderSync] High orphaned link count',
        data: {
          'orphanedLinksCleared': metric.orphanedLinksCleared,
          'syncType': metric.syncType,
        },
      );
    }

    // Check for excessive invalid UUIDs
    if (metric.invalidUuidsRejected != null &&
        metric.invalidUuidsRejected! > 3) {
      _logger.error(
        '[ReminderSync] High invalid UUID count',
        data: {
          'invalidUuidsRejected': metric.invalidUuidsRejected,
          'syncType': metric.syncType,
        },
      );
    }

    // Check for frequent errors
    final recentErrors = _metrics.values
        .where(
          (m) =>
              m.syncType == metric.syncType &&
              !m.success &&
              m.endTime != null &&
              DateTime.now().difference(m.endTime!).inMinutes < 5,
        )
        .length;

    if (recentErrors >= 3) {
      _logger.error(
        '[ReminderSync] Multiple sync failures detected',
        data: {'syncType': metric.syncType, 'recentErrors': recentErrors},
      );
    }
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
      'uploadCount': _uploadCount,
      'downloadCount': _downloadCount,
      'totalConflicts': _totalConflicts,
      'orphanedLinksFound': _orphanedLinksFound,
      'invalidUuidsFound': _invalidUuidsFound,
      'batchesProcessed': _batchesProcessed,
      'averageItemsPerBatch': _batchesProcessed > 0
          ? (_totalItemsInBatches / _batchesProcessed).toStringAsFixed(1)
          : '0',
      // CRITICAL #4: Encryption failure metrics
      'encryptionFailures': _encryptionFailures,
      'retryableEncryptionFailures': _retryableEncryptionFailures,
      'nonRetryableEncryptionFailures': _nonRetryableEncryptionFailures,
    };
  }

  /// Get conflict resolution statistics
  Map<String, dynamic> getConflictStats() {
    if (_totalConflicts == 0) {
      return {'totalConflicts': 0, 'resolutionBreakdown': <String, int>{}};
    }

    final breakdown = <String, dynamic>{};
    for (final entry in _conflictResolutions.entries) {
      final percentage = (entry.value / _totalConflicts * 100).toStringAsFixed(
        1,
      );
      breakdown[entry.key.name] = {
        'count': entry.value,
        'percentage': percentage,
      };
    }

    return {
      'totalConflicts': _totalConflicts,
      'resolutionBreakdown': breakdown,
    };
  }

  /// Get data quality metrics
  Map<String, dynamic> getDataQualityMetrics() {
    return {
      'orphanedLinksFound': _orphanedLinksFound,
      'invalidUuidsFound': _invalidUuidsFound,
      'dataQualityScore': _calculateDataQualityScore(),
    };
  }

  /// Calculate data quality score (0-100)
  double _calculateDataQualityScore() {
    final totalProcessed = _uploadCount + _downloadCount;
    if (totalProcessed == 0) return 100.0;

    final issues = _orphanedLinksFound + _invalidUuidsFound;
    final qualityRate = 1.0 - (issues / totalProcessed).clamp(0.0, 1.0);
    return (qualityRate * 100);
  }

  /// Export all metrics as JSON
  Map<String, dynamic> exportMetrics() {
    return {
      'performance': getPerformanceStats(),
      'health': getHealthMetrics(),
      'conflicts': getConflictStats(),
      'dataQuality': getDataQualityMetrics(),
      'timestamp': DateTime.now().toIso8601String(),
      'recentSyncs': _metrics.values
          .where((m) => m.endTime != null)
          .toList()
          .reversed
          .take(10)
          .map(
            (m) => {
              'syncType': m.syncType,
              'duration': m.duration?.inMilliseconds,
              'success': m.success,
              'remindersProcessed': m.remindersProcessed,
              'conflictsResolved': m.conflictsResolved,
              'orphanedLinksCleared': m.orphanedLinksCleared,
              'invalidUuidsRejected': m.invalidUuidsRejected,
              'batchesProcessed': m.batchesProcessed,
              'timestamp': m.endTime?.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Clear all metrics (for testing or reset)
  void clearMetrics() {
    _metrics.clear();
    _lastSyncTimes.clear();
    _syncDurations.clear();
    _conflictResolutions.clear();
    _totalConflicts = 0;
    _orphanedLinksFound = 0;
    _invalidUuidsFound = 0;
    _batchesProcessed = 0;
    _totalItemsInBatches = 0;
    _totalErrors = 0;
    _totalSuccesses = 0;
    _uploadCount = 0;
    _downloadCount = 0;
    // CRITICAL #4: Clear encryption failure metrics
    _encryptionFailures = 0;
    _retryableEncryptionFailures = 0;
    _nonRetryableEncryptionFailures = 0;
  }

  /// Log current metrics summary
  void logMetricsSummary() {
    _logger.info(
      '[ReminderSync] Metrics Summary',
      data: {
        'health': getHealthMetrics(),
        'performance': getPerformanceStats(),
        'conflicts': getConflictStats(),
        'dataQuality': getDataQualityMetrics(),
      },
    );
  }
}

/// Internal class to track individual sync operations
class _ReminderSyncMetric {
  final String syncType;
  final DateTime startTime;
  final Map<String, dynamic> metadata;
  final int? reminderCount;

  DateTime? endTime;
  Duration? duration;
  bool success = false;
  int? remindersProcessed;
  int? conflictsResolved;
  int? orphanedLinksCleared;
  int? invalidUuidsRejected;
  int? batchesProcessed;
  String? error;

  _ReminderSyncMetric({
    required this.syncType,
    required this.startTime,
    required this.metadata,
    this.reminderCount,
  });
}

/// Conflict resolution strategies tracked by metrics
enum ConflictResolution {
  /// Preferred snoozed_until (Strategy 1: user action priority)
  preferSnoozed,

  /// Merged trigger_count (Strategy 2: additive merge)
  mergedTriggerCount,

  /// Preferred is_active=false (Strategy 3: deactivation priority)
  preferInactive,

  /// Used newer timestamp (Strategy 4: last-write-wins fallback)
  lastWriteWins,
}
