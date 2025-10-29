import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Service to debounce rapid updates and prevent UI thrashing
/// This helps reduce unnecessary rebuilds and database queries
class DebouncedUpdateService {
  DebouncedUpdateService({
    this.defaultDelay = const Duration(milliseconds: 300),
  });
  final AppLogger _logger = LoggerFactory.instance;
  final Duration defaultDelay;
  final Map<String, Timer> _updateQueue = {};
  final Map<String, int> _updateCounts = {};
  final Map<String, DateTime> _lastUpdateTime = {};

  // Statistics for monitoring
  int _totalUpdatesScheduled = 0;
  int _totalUpdatesExecuted = 0;
  int _totalUpdatesCancelled = 0;

  /// Schedule an update with debouncing
  /// If an update with the same key is already scheduled, it will be cancelled
  /// and rescheduled with the new delay
  void scheduleUpdate(
    String key,
    VoidCallback update, {
    Duration? customDelay,
  }) {
    _totalUpdatesScheduled++;

    // Cancel existing timer if present
    if (_updateQueue.containsKey(key)) {
      _updateQueue[key]?.cancel();
      _totalUpdatesCancelled++;
      _logger.debug(' Cancelled existing update for: $key');
    }

    // Track update frequency
    _updateCounts[key] = (_updateCounts[key] ?? 0) + 1;

    final delay = customDelay ?? defaultDelay;

    // Schedule new update
    _updateQueue[key] = Timer(delay, () {
      try {
        _totalUpdatesExecuted++;
        _lastUpdateTime[key] = DateTime.now();

        // Execute the update
        update();

        // Clean up
        _updateQueue.remove(key);

        _logger.debug(
          ' Executed update for: $key (count: ${_updateCounts[key]})',
        );

        // Reset count after execution
        _updateCounts[key] = 0;
      } catch (e) {
        _logger.debug(' Error executing update for $key: $e');
      }
    });
  }

  /// Schedule a batch of updates that should execute together
  void scheduleBatch(
    String batchKey,
    List<VoidCallback> updates, {
    Duration? customDelay,
  }) {
    scheduleUpdate(batchKey, () {
      for (final update in updates) {
        try {
          update();
        } catch (e) {
          _logger.debug(' Error in batch update: $e');
        }
      }
    }, customDelay: customDelay);
  }

  /// Cancel a scheduled update
  void cancelUpdate(String key) {
    if (_updateQueue.containsKey(key)) {
      _updateQueue[key]?.cancel();
      _updateQueue.remove(key);
      _totalUpdatesCancelled++;
      _logger.debug(' Manually cancelled update for: $key');
    }
  }

  /// Cancel all pending updates
  void cancelAll() {
    for (final timer in _updateQueue.values) {
      timer.cancel();
      _totalUpdatesCancelled++;
    }
    _updateQueue.clear();
    _logger.debug(' Cancelled all pending updates');
  }

  /// Check if an update is pending
  bool isPending(String key) {
    return _updateQueue.containsKey(key);
  }

  /// Get the number of pending updates
  int get pendingCount => _updateQueue.length;

  /// Get statistics for monitoring
  Map<String, dynamic> getStatistics() {
    return {
      'totalScheduled': _totalUpdatesScheduled,
      'totalExecuted': _totalUpdatesExecuted,
      'totalCancelled': _totalUpdatesCancelled,
      'currentPending': _updateQueue.length,
      'efficiency': _totalUpdatesScheduled > 0
          ? '${(_totalUpdatesExecuted / _totalUpdatesScheduled * 100).toStringAsFixed(1)}%'
          : '0%',
      'hotKeys': _updateCounts.entries
          .where((e) => e.value > 5)
          .map((e) => '${e.key}: ${e.value}')
          .toList(),
    };
  }

  /// Clean up resources
  void dispose() {
    cancelAll();
    _updateCounts.clear();
    _lastUpdateTime.clear();
  }
}

/// Global instance for app-wide debouncing
class DebouncedUpdateManager {
  factory DebouncedUpdateManager() => _instance;
  DebouncedUpdateManager._internal();
  static final DebouncedUpdateManager _instance =
      DebouncedUpdateManager._internal();

  final _services = <String, DebouncedUpdateService>{};

  /// Get or create a debounced update service for a specific context
  DebouncedUpdateService getService(String context, {Duration? defaultDelay}) {
    return _services.putIfAbsent(
      context,
      () => DebouncedUpdateService(
        defaultDelay: defaultDelay ?? const Duration(milliseconds: 300),
      ),
    );
  }

  /// Get statistics for all services
  Map<String, Map<String, dynamic>> getAllStatistics() {
    return _services.map(
      (key, service) => MapEntry(key, service.getStatistics()),
    );
  }

  /// Dispose a specific service
  void disposeService(String context) {
    _services[context]?.dispose();
    _services.remove(context);
  }

  /// Dispose all services
  void disposeAll() {
    for (final service in _services.values) {
      service.dispose();
    }
    _services.clear();
  }
}
