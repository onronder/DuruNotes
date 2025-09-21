import 'dart:async';
import 'dart:collection';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Performance monitoring service for tracking app performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal() {
    _initialize();
  }

  final _logger = LoggerFactory.instance;
  final _metrics = PerformanceMetrics();
  final _transactions = <String, ISentrySpan>{};
  final _timers = <String, Stopwatch>{};

  // Frame tracking
  int _frameCount = 0;
  int _droppedFrames = 0;
  DateTime? _frameTrackingStart;

  // Memory tracking
  Timer? _memoryMonitorTimer;
  final _memorySnapshots = Queue<MemorySnapshot>();

  void _initialize() {
    // Start frame tracking
    _startFrameTracking();

    // Start memory monitoring
    _startMemoryMonitoring();

    // Register with Sentry for performance monitoring
    if (!kDebugMode) {
      Sentry.configureScope((scope) {
        scope.setContexts('performance', _metrics.toJson());
      });
    }
  }

  /// Start a performance transaction
  ISentrySpan? startTransaction(String operation, String description) {
    try {
      final transaction = Sentry.startTransaction(operation, description);
      _transactions[operation] = transaction;

      // Also track locally
      _timers[operation] = Stopwatch()..start();

      _logger.debug('Started transaction: $operation');
      return transaction;
    } catch (e) {
      _logger.error('Failed to start transaction', error: e);
      return null;
    }
  }

  /// End a performance transaction
  void endTransaction(String operation, {SpanStatus? status}) {
    final transaction = _transactions.remove(operation);
    final timer = _timers.remove(operation);

    if (transaction != null) {
      transaction.status = status ?? const SpanStatus.ok();
      transaction.finish();
    }

    if (timer != null) {
      timer.stop();
      _metrics.recordOperation(operation, timer.elapsedMilliseconds);

      _logger.debug(
          'Ended transaction: $operation (${timer.elapsedMilliseconds}ms)');
    }
  }

  /// Measure the duration of an operation
  Future<T> measure<T>(String operation, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await action();
      stopwatch.stop();

      _metrics.recordOperation(operation, stopwatch.elapsedMilliseconds);

      // Log slow operations
      if (stopwatch.elapsedMilliseconds > 1000) {
        _logger.warning('Slow operation detected', data: {
          'operation': operation,
          'duration_ms': stopwatch.elapsedMilliseconds,
        });
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      _metrics.recordOperation(operation, stopwatch.elapsedMilliseconds,
          success: false);
      rethrow;
    }
  }

  /// Measure sync operation
  T measureSync<T>(String operation, T Function() action) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = action();
      stopwatch.stop();

      _metrics.recordOperation(operation, stopwatch.elapsedMilliseconds);

      return result;
    } catch (e) {
      stopwatch.stop();
      _metrics.recordOperation(operation, stopwatch.elapsedMilliseconds,
          success: false);
      rethrow;
    }
  }

  /// Start frame tracking
  void _startFrameTracking() {
    _frameTrackingStart = DateTime.now();

    SchedulerBinding.instance.addTimingsCallback((timings) {
      _frameCount++;

      for (final timing in timings) {
        // Frame took longer than 16ms (60fps threshold)
        if (timing.totalSpan.inMilliseconds > 16) {
          _droppedFrames++;

          if (timing.totalSpan.inMilliseconds > 100) {
            _logger.warning('Severe frame drop detected', data: {
              'duration_ms': timing.totalSpan.inMilliseconds,
              'build_ms': timing.buildDuration.inMilliseconds,
              'raster_ms': timing.rasterDuration.inMilliseconds,
            });
          }
        }
      }

      _updateFrameMetrics();
    });
  }

  void _updateFrameMetrics() {
    if (_frameTrackingStart == null) return;

    final duration = DateTime.now().difference(_frameTrackingStart!);
    if (duration.inSeconds > 0) {
      _metrics.fps = _frameCount / duration.inSeconds;
      _metrics.droppedFrameRate = _droppedFrames / _frameCount;
    }
  }

  /// Start memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _captureMemorySnapshot();
    });

    // Initial snapshot
    _captureMemorySnapshot();
  }

  void _captureMemorySnapshot() {
    try {
      // Get memory info from platform
      const platform = MethodChannel('com.example.duru_notes/performance');
      platform.invokeMethod<Map>('getMemoryInfo').then((info) {
        if (info != null) {
          final snapshot = MemorySnapshot(
            timestamp: DateTime.now(),
            usedMemoryBytes: info['used'] as int? ?? 0,
            totalMemoryBytes: info['total'] as int? ?? 0,
          );

          _memorySnapshots.add(snapshot);

          // Keep only last 10 snapshots
          while (_memorySnapshots.length > 10) {
            _memorySnapshots.removeFirst();
          }

          _updateMemoryMetrics();
        }
      }).catchError((error) {
        // Platform channel not available, use Dart memory info
        final snapshot = MemorySnapshot(
          timestamp: DateTime.now(),
          usedMemoryBytes: 0, // Would need platform-specific implementation
          totalMemoryBytes: 0,
        );
        _memorySnapshots.add(snapshot);
      });
    } catch (e) {
      _logger.debug('Memory monitoring not available');
    }
  }

  void _updateMemoryMetrics() {
    if (_memorySnapshots.isEmpty) return;

    final latest = _memorySnapshots.last;
    _metrics.memoryUsageMB = latest.usedMemoryBytes / (1024 * 1024);

    // Check for memory leaks (continuous growth)
    if (_memorySnapshots.length >= 3) {
      final growth =
          latest.usedMemoryBytes - _memorySnapshots.first.usedMemoryBytes;
      final duration =
          latest.timestamp.difference(_memorySnapshots.first.timestamp);

      if (duration.inMinutes > 0) {
        final growthRate = growth / duration.inMinutes; // Bytes per minute

        if (growthRate > 1024 * 1024) {
          // More than 1MB per minute
          _logger.warning('Potential memory leak detected', data: {
            'growth_rate_mb_per_min': growthRate / (1024 * 1024),
            'total_growth_mb': growth / (1024 * 1024),
          });
        }
      }
    }
  }

  /// Record a custom metric
  void recordMetric(String name, double value, {String? unit}) {
    _metrics.customMetrics[name] = CustomMetric(
      name: name,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
    );

    // Send to Sentry as breadcrumb
    if (!kDebugMode) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Metric: $name',
        category: 'performance',
        data: {
          'value': value,
          if (unit != null) 'unit': unit,
        },
        level: SentryLevel.info,
      ));
    }
  }

  /// Get current performance metrics
  PerformanceMetrics get metrics => _metrics;

  /// Generate performance report
  PerformanceReport generateReport() {
    return PerformanceReport(
      metrics: _metrics,
      operations: Map.from(_metrics.operationDurations),
      memorySnapshots: _memorySnapshots.toList(),
      timestamp: DateTime.now(),
    );
  }

  /// Clear all metrics
  void reset() {
    _metrics.reset();
    _frameCount = 0;
    _droppedFrames = 0;
    _frameTrackingStart = DateTime.now();
    _memorySnapshots.clear();
    _transactions.clear();
    _timers.clear();
  }

  void dispose() {
    _memoryMonitorTimer?.cancel();
    for (final transaction in _transactions.values) {
      transaction.finish();
    }
  }
}

/// Performance metrics container
class PerformanceMetrics {
  double fps = 60.0;
  double droppedFrameRate = 0.0;
  double memoryUsageMB = 0.0;
  int operationCount = 0;
  int slowOperationCount = 0;
  final Map<String, OperationMetric> operationDurations = {};
  final Map<String, CustomMetric> customMetrics = {};

  void recordOperation(String operation, int durationMs,
      {bool success = true}) {
    operationCount++;

    if (durationMs > 1000) {
      slowOperationCount++;
    }

    operationDurations.update(
      operation,
      (existing) => existing.update(durationMs, success),
      ifAbsent: () => OperationMetric(
        name: operation,
        count: 1,
        totalDuration: durationMs,
        minDuration: durationMs,
        maxDuration: durationMs,
        failures: success ? 0 : 1,
      ),
    );
  }

  void reset() {
    fps = 60.0;
    droppedFrameRate = 0.0;
    memoryUsageMB = 0.0;
    operationCount = 0;
    slowOperationCount = 0;
    operationDurations.clear();
    customMetrics.clear();
  }

  Map<String, dynamic> toJson() => {
        'fps': fps.toStringAsFixed(1),
        'dropped_frame_rate': (droppedFrameRate * 100).toStringAsFixed(2),
        'memory_usage_mb': memoryUsageMB.toStringAsFixed(2),
        'operation_count': operationCount,
        'slow_operation_count': slowOperationCount,
        'operations': operationDurations.map((k, v) => MapEntry(k, v.toJson())),
        'custom_metrics': customMetrics.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Operation performance metric
class OperationMetric {
  OperationMetric({
    required this.name,
    required this.count,
    required this.totalDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.failures,
  });

  final String name;
  int count;
  int totalDuration;
  int minDuration;
  int maxDuration;
  int failures;

  double get averageDuration => count > 0 ? totalDuration / count : 0;
  double get successRate => count > 0 ? (count - failures) / count : 0;

  OperationMetric update(int duration, bool success) {
    count++;
    totalDuration += duration;
    minDuration = duration < minDuration ? duration : minDuration;
    maxDuration = duration > maxDuration ? duration : maxDuration;
    if (!success) failures++;
    return this;
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'average_ms': averageDuration.toStringAsFixed(2),
        'min_ms': minDuration,
        'max_ms': maxDuration,
        'total_ms': totalDuration,
        'success_rate': (successRate * 100).toStringAsFixed(2),
      };
}

/// Custom metric
class CustomMetric {
  const CustomMetric({
    required this.name,
    required this.value,
    this.unit,
    required this.timestamp,
  });

  final String name;
  final double value;
  final String? unit;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'value': value,
        if (unit != null) 'unit': unit,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Memory snapshot
class MemorySnapshot {
  const MemorySnapshot({
    required this.timestamp,
    required this.usedMemoryBytes,
    required this.totalMemoryBytes,
  });

  final DateTime timestamp;
  final int usedMemoryBytes;
  final int totalMemoryBytes;

  double get usedMemoryMB => usedMemoryBytes / (1024 * 1024);
  double get totalMemoryMB => totalMemoryBytes / (1024 * 1024);
  double get usagePercentage =>
      totalMemoryBytes > 0 ? (usedMemoryBytes / totalMemoryBytes) * 100 : 0;
}

/// Performance report
class PerformanceReport {
  const PerformanceReport({
    required this.metrics,
    required this.operations,
    required this.memorySnapshots,
    required this.timestamp,
  });

  final PerformanceMetrics metrics;
  final Map<String, OperationMetric> operations;
  final List<MemorySnapshot> memorySnapshots;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'metrics': metrics.toJson(),
        'memory_trend': _getMemoryTrend(),
        'top_slow_operations': _getTopSlowOperations(),
        'recommendations': _getRecommendations(),
      };

  Map<String, dynamic> _getMemoryTrend() {
    if (memorySnapshots.length < 2) {
      return {'trend': 'insufficient_data'};
    }

    final first = memorySnapshots.first;
    final last = memorySnapshots.last;
    final growth = last.usedMemoryBytes - first.usedMemoryBytes;
    final duration = last.timestamp.difference(first.timestamp);

    return {
      'growth_mb': (growth / (1024 * 1024)).toStringAsFixed(2),
      'duration_minutes': duration.inMinutes,
      'trend': growth > 0 ? 'increasing' : 'stable',
    };
  }

  List<Map<String, dynamic>> _getTopSlowOperations() {
    final sorted = operations.entries.toList()
      ..sort(
          (a, b) => b.value.averageDuration.compareTo(a.value.averageDuration));

    return sorted
        .take(5)
        .map((e) => {
              'operation': e.key,
              'average_ms': e.value.averageDuration.toStringAsFixed(2),
              'count': e.value.count,
            })
        .toList();
  }

  List<String> _getRecommendations() {
    final recommendations = <String>[];

    if (metrics.droppedFrameRate > 0.05) {
      recommendations.add(
          'High frame drop rate detected (${(metrics.droppedFrameRate * 100).toStringAsFixed(1)}%). Consider optimizing heavy UI operations.');
    }

    if (metrics.memoryUsageMB > 200) {
      recommendations.add(
          'High memory usage (${metrics.memoryUsageMB.toStringAsFixed(0)}MB). Consider clearing caches or optimizing data structures.');
    }

    if (metrics.slowOperationCount > 10) {
      recommendations.add(
          'Multiple slow operations detected (${metrics.slowOperationCount}). Review operation performance.');
    }

    final slowestOp = operations.entries
        .reduce((a, b) => a.value.maxDuration > b.value.maxDuration ? a : b);

    if (slowestOp.value.maxDuration > 5000) {
      recommendations.add(
          'Operation "${slowestOp.key}" took ${slowestOp.value.maxDuration}ms. Consider optimizing or adding progress indicators.');
    }

    return recommendations;
  }
}

/// Performance monitor provider
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

/// Performance metrics provider
final performanceMetricsProvider = Provider<PerformanceMetrics>((ref) {
  final monitor = ref.watch(performanceMonitorProvider);
  return monitor.metrics;
});

/// Performance report provider
final performanceReportProvider = Provider<PerformanceReport>((ref) {
  final monitor = ref.watch(performanceMonitorProvider);
  return monitor.generateReport();
});
