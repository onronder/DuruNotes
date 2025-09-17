import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Performance monitoring for Quick Capture Widget
/// Tracks and reports performance metrics
class WidgetPerformanceMonitor {
  // Performance thresholds (milliseconds)
  static const int captureLatencyThreshold = 500;
  static const int widgetRefreshThreshold = 100;
  static const int dataSyncThreshold = 1000;
  static const int queueProcessingThreshold = 50; // per item
  
  // Metric storage
  final Map<String, List<PerformanceMetric>> _metrics = {};
  final Queue<PerformanceEvent> _eventQueue = Queue();
  final int maxMetricsPerType = 100;
  final int maxEventQueueSize = 1000;
  
  // Real-time monitoring
  Timer? _monitoringTimer;
  final StreamController<PerformanceReport> _reportController = 
      StreamController<PerformanceReport>.broadcast();
  
  // Statistics
  final Map<String, PerformanceStats> _stats = {};

  /// Get performance report stream
  Stream<PerformanceReport> get reportStream => _reportController.stream;

  /// Start performance monitoring
  void startMonitoring({Duration interval = const Duration(minutes: 1)}) {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(interval, (_) {
      _generateReport();
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  // ============================================
  // METRIC TRACKING
  // ============================================

  /// Track a performance metric
  void trackMetric({
    required String name,
    required double value,
    required MetricType type,
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      name: name,
      value: value,
      type: type,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    
    // Store metric
    _metrics.putIfAbsent(name, () => []).add(metric);
    
    // Limit metrics storage
    if (_metrics[name]!.length > maxMetricsPerType) {
      _metrics[name]!.removeAt(0);
    }
    
    // Update statistics
    _updateStats(name, value);
    
    // Check thresholds
    _checkThresholds(metric);
    
    // Log event
    _logEvent(PerformanceEvent(
      type: 'metric',
      name: name,
      value: value,
      timestamp: DateTime.now(),
    ));
  }

  /// Track capture performance
  void trackCapturePerformance({
    required String captureId,
    required int durationMs,
    required String platform,
    String? templateId,
    int? textLength,
  }) {
    trackMetric(
      name: 'capture_latency',
      value: durationMs.toDouble(),
      type: MetricType.latency,
      metadata: {
        'capture_id': captureId,
        'platform': platform,
        if (templateId != null) 'template_id': templateId,
        if (textLength != null) 'text_length': textLength,
      },
    );
  }

  /// Track widget refresh performance
  void trackWidgetRefresh({
    required int durationMs,
    required String widgetSize,
    required int itemCount,
  }) {
    trackMetric(
      name: 'widget_refresh',
      value: durationMs.toDouble(),
      type: MetricType.latency,
      metadata: {
        'widget_size': widgetSize,
        'item_count': itemCount,
      },
    );
  }

  /// Track data sync performance
  void trackDataSync({
    required int durationMs,
    required int itemCount,
    required bool success,
  }) {
    trackMetric(
      name: 'data_sync',
      value: durationMs.toDouble(),
      type: MetricType.latency,
      metadata: {
        'item_count': itemCount,
        'success': success,
        'items_per_second': itemCount > 0 ? (itemCount * 1000 / durationMs).round() : 0,
      },
    );
  }

  /// Track offline queue processing
  void trackQueueProcessing({
    required int totalItems,
    required int processedItems,
    required int failedItems,
    required int durationMs,
  }) {
    final perItemDuration = processedItems > 0 ? durationMs / processedItems : 0;
    
    trackMetric(
      name: 'queue_processing',
      value: perItemDuration,
      type: MetricType.latency,
      metadata: {
        'total_items': totalItems,
        'processed': processedItems,
        'failed': failedItems,
        'success_rate': totalItems > 0 ? (processedItems / totalItems * 100).round() : 100,
      },
    );
  }

  /// Track memory usage
  void trackMemoryUsage() {
    // This would need platform-specific implementation
    // For now, we'll use a placeholder
    trackMetric(
      name: 'memory_usage',
      value: 0, // Would be actual memory in MB
      type: MetricType.resource,
    );
  }

  /// Track frame rate
  void trackFrameRate(double fps) {
    trackMetric(
      name: 'frame_rate',
      value: fps,
      type: MetricType.resource,
      metadata: {
        'smooth': fps >= 60,
        'jank': fps < 30,
      },
    );
  }

  // ============================================
  // PERFORMANCE ANALYSIS
  // ============================================

  /// Get performance statistics for a metric
  PerformanceStats? getStats(String metricName) {
    return _stats[metricName];
  }

  /// Get all performance statistics
  Map<String, PerformanceStats> getAllStats() {
    return Map.from(_stats);
  }

  /// Calculate percentile for a metric
  double calculatePercentile(String metricName, double percentile) {
    final metrics = _metrics[metricName];
    if (metrics == null || metrics.isEmpty) return 0;
    
    final values = metrics.map((m) => m.value).toList()..sort();
    final index = (percentile / 100 * values.length).round();
    return values[index.clamp(0, values.length - 1)];
  }

  /// Check if performance is degraded
  bool isPerformanceDegraded(String metricName) {
    final stats = _stats[metricName];
    if (stats == null) return false;
    
    // Check against thresholds
    switch (metricName) {
      case 'capture_latency':
        return stats.average > captureLatencyThreshold;
      case 'widget_refresh':
        return stats.average > widgetRefreshThreshold;
      case 'data_sync':
        return stats.average > dataSyncThreshold;
      case 'queue_processing':
        return stats.average > queueProcessingThreshold;
      default:
        return false;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  void _updateStats(String name, double value) {
    final existing = _stats[name];
    
    if (existing == null) {
      _stats[name] = PerformanceStats(
        name: name,
        count: 1,
        total: value,
        min: value,
        max: value,
        average: value,
      );
    } else {
      final newCount = existing.count + 1;
      final newTotal = existing.total + value;
      
      _stats[name] = PerformanceStats(
        name: name,
        count: newCount,
        total: newTotal,
        min: value < existing.min ? value : existing.min,
        max: value > existing.max ? value : existing.max,
        average: newTotal / newCount,
      );
    }
  }

  void _checkThresholds(PerformanceMetric metric) {
    bool exceeded = false;
    double threshold = 0;
    
    switch (metric.name) {
      case 'capture_latency':
        threshold = captureLatencyThreshold.toDouble();
        exceeded = metric.value > threshold;
        break;
      case 'widget_refresh':
        threshold = widgetRefreshThreshold.toDouble();
        exceeded = metric.value > threshold;
        break;
      case 'data_sync':
        threshold = dataSyncThreshold.toDouble();
        exceeded = metric.value > threshold;
        break;
      case 'queue_processing':
        threshold = queueProcessingThreshold.toDouble();
        exceeded = metric.value > threshold;
        break;
    }
    
    if (exceeded) {
      _logEvent(PerformanceEvent(
        type: 'threshold_exceeded',
        name: metric.name,
        value: metric.value,
        timestamp: DateTime.now(),
        metadata: {
          'threshold': threshold,
          'exceeded_by': metric.value - threshold,
        },
      ));
    }
  }

  void _logEvent(PerformanceEvent event) {
    _eventQueue.add(event);
    
    // Limit queue size
    while (_eventQueue.length > maxEventQueueSize) {
      _eventQueue.removeFirst();
    }
  }

  void _generateReport() {
    final report = PerformanceReport(
      timestamp: DateTime.now(),
      stats: Map.from(_stats),
      recentEvents: _eventQueue.toList(),
      degradedMetrics: _stats.entries
          .where((e) => isPerformanceDegraded(e.key))
          .map((e) => e.key)
          .toList(),
    );
    
    _reportController.add(report);
  }

  /// Clean up resources
  void dispose() {
    stopMonitoring();
    _reportController.close();
    _metrics.clear();
    _stats.clear();
    _eventQueue.clear();
  }
}

// ============================================
// DATA MODELS
// ============================================

/// Types of performance metrics
enum MetricType {
  latency,
  throughput,
  resource,
  counter,
}

/// Performance metric data
class PerformanceMetric {
  final String name;
  final double value;
  final MetricType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.type,
    required this.timestamp,
    this.metadata,
  });
}

/// Performance statistics
class PerformanceStats {
  final String name;
  final int count;
  final double total;
  final double min;
  final double max;
  final double average;

  PerformanceStats({
    required this.name,
    required this.count,
    required this.total,
    required this.min,
    required this.max,
    required this.average,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'count': count,
    'total': total,
    'min': min,
    'max': max,
    'average': average,
  };
}

/// Performance event
class PerformanceEvent {
  final String type;
  final String name;
  final double value;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceEvent({
    required this.type,
    required this.name,
    required this.value,
    required this.timestamp,
    this.metadata,
  });
}

/// Performance report
class PerformanceReport {
  final DateTime timestamp;
  final Map<String, PerformanceStats> stats;
  final List<PerformanceEvent> recentEvents;
  final List<String> degradedMetrics;

  PerformanceReport({
    required this.timestamp,
    required this.stats,
    required this.recentEvents,
    required this.degradedMetrics,
  });

  bool get hasIssues => degradedMetrics.isNotEmpty;
}
