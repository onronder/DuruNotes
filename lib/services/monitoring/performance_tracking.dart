import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/monitoring/sentry_monitoring.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Performance tracking service for monitoring app performance
class PerformanceTrackingService {
  PerformanceTrackingService({
    required this.sentryMonitoring,
  });

  final SentryMonitoringService sentryMonitoring;
  final _logger = LoggerFactory.instance;
  
  // Active transactions
  final Map<String, ISentrySpan> _activeTransactions = {};
  final Map<String, DateTime> _transactionStartTimes = {};
  
  // Performance metrics
  final Map<String, PerformanceMetric> _metrics = {};
  
  // Thresholds for performance warnings
  static const Duration slowTransactionThreshold = Duration(seconds: 3);
  static const Duration slowSpanThreshold = Duration(seconds: 1);
  static const Duration slowDatabaseThreshold = Duration(milliseconds: 100);
  static const Duration slowNetworkThreshold = Duration(seconds: 2);
  
  // ============================================================================
  // App Lifecycle Tracking
  // ============================================================================
  
  /// Track app startup performance
  ISentrySpan trackAppStartup() {
    final transaction = sentryMonitoring.startTransaction(
      name: 'app.startup',
      operation: 'app.lifecycle',
      data: {
        'cold_start': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    _activeTransactions['app_startup'] = transaction;
    _transactionStartTimes['app_startup'] = DateTime.now();
    
    return transaction;
  }
  
  /// Track app resume performance
  ISentrySpan trackAppResume() {
    final transaction = sentryMonitoring.startTransaction(
      name: 'app.resume',
      operation: 'app.lifecycle',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    _activeTransactions['app_resume'] = transaction;
    _transactionStartTimes['app_resume'] = DateTime.now();
    
    return transaction;
  }
  
  /// Finish app lifecycle tracking
  void finishAppLifecycle(String type) {
    final transaction = _activeTransactions.remove(type);
    final startTime = _transactionStartTimes.remove(type);
    
    if (transaction != null) {
      sentryMonitoring.finishSpan(transaction);
      
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        _recordMetric(
          name: 'app.$type',
          duration: duration,
          category: MetricCategory.lifecycle,
        );
      }
    }
  }
  
  // ============================================================================
  // Navigation Tracking
  // ============================================================================
  
  /// Track navigation between screens
  ISentrySpan trackNavigation({
    required String from,
    required String to,
    Map<String, dynamic>? extra,
  }) {
    final transaction = sentryMonitoring.startTransaction(
      name: 'navigation',
      operation: 'navigation',
      data: {
        'from': from,
        'to': to,
        ...?extra,
      },
    );
    
    // Add navigation breadcrumb
    sentryMonitoring.addNavigationBreadcrumb(
      from: from,
      to: to,
      data: extra,
    );
    
    return transaction;
  }
  
  // ============================================================================
  // Database Operations Tracking
  // ============================================================================
  
  /// Track database query performance
  Future<T> trackDatabaseQuery<T>({
    required String operation,
    required String table,
    required Future<T> Function() query,
    Map<String, dynamic>? extra,
  }) async {
    final span = sentryMonitoring.startSpan(
      operation: 'db.$operation',
      description: 'Database operation on $table',
    );
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await query();
      stopwatch.stop();
      
      // Add database breadcrumb
      sentryMonitoring.addDatabaseBreadcrumb(
        operation: operation,
        table: table,
        duration: stopwatch.elapsed,
      );
      
      // Record metric
      _recordMetric(
        name: 'db.$operation.$table',
        duration: stopwatch.elapsed,
        category: MetricCategory.database,
      );
      
      // Check for slow queries
      if (stopwatch.elapsed > slowDatabaseThreshold) {
        _logSlowOperation(
          type: 'database',
          operation: '$operation on $table',
          duration: stopwatch.elapsed,
        );
      }
      
      sentryMonitoring.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (e) {
      stopwatch.stop();
      sentryMonitoring.finishSpan(span, status: const SpanStatus.internalError());
      
      // Report database error
      await sentryMonitoring.reportError(
        error: e,
        stackTrace: StackTrace.current,
        message: 'Database operation failed',
        extra: {
          'operation': operation,
          'table': table,
          'duration_ms': stopwatch.elapsedMilliseconds,
          ...?extra,
        },
      );
      
      rethrow;
    }
  }
  
  // ============================================================================
  // Network Operations Tracking
  // ============================================================================
  
  /// Track network request performance
  Future<T> trackNetworkRequest<T>({
    required String url,
    required String method,
    required Future<T> Function() request,
    Map<String, dynamic>? headers,
  }) async {
    final span = sentryMonitoring.startSpan(
      operation: 'http.$method',
      description: url,
    );
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await request();
      stopwatch.stop();
      
      // Add HTTP breadcrumb
      sentryMonitoring.addHttpBreadcrumb(
        url: url,
        method: method,
        statusCode: 200, // Assume success
        duration: stopwatch.elapsed,
      );
      
      // Record metric
      _recordMetric(
        name: 'http.$method',
        duration: stopwatch.elapsed,
        category: MetricCategory.network,
        tags: {'url': url},
      );
      
      // Check for slow requests
      if (stopwatch.elapsed > slowNetworkThreshold) {
        _logSlowOperation(
          type: 'network',
          operation: '$method $url',
          duration: stopwatch.elapsed,
        );
      }
      
      sentryMonitoring.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (e) {
      stopwatch.stop();
      
      // Determine status based on error
      final status = _getSpanStatusFromError(e);
      sentryMonitoring.finishSpan(span, status: status);
      
      // Add error breadcrumb
      sentryMonitoring.addHttpBreadcrumb(
        url: url,
        method: method,
        statusCode: _getStatusCodeFromError(e),
        duration: stopwatch.elapsed,
      );
      
      rethrow;
    }
  }
  
  // ============================================================================
  // UI Operations Tracking
  // ============================================================================
  
  /// Track UI rendering performance
  ISentrySpan trackUIRendering({
    required String widget,
    Map<String, dynamic>? extra,
  }) {
    return sentryMonitoring.startSpan(
      operation: 'ui.render',
      description: widget,
    );
  }
  
  /// Track user interaction
  ISentrySpan trackUserInteraction({
    required String action,
    required String target,
    Map<String, dynamic>? extra,
  }) {
    final span = sentryMonitoring.startSpan(
      operation: 'ui.action',
      description: '$action on $target',
    );
    
    // Add user action breadcrumb
    sentryMonitoring.addUserActionBreadcrumb(
      action: action,
      target: target,
      data: extra,
    );
    
    return span;
  }
  
  /// Track animation performance
  Future<void> trackAnimation({
    required String name,
    required Future<void> Function() animation,
  }) async {
    final span = sentryMonitoring.startSpan(
      operation: 'ui.animation',
      description: name,
    );
    
    final stopwatch = Stopwatch()..start();
    
    try {
      await animation();
      stopwatch.stop();
      
      _recordMetric(
        name: 'ui.animation.$name',
        duration: stopwatch.elapsed,
        category: MetricCategory.ui,
      );
      
      sentryMonitoring.finishSpan(span, status: const SpanStatus.ok());
    } catch (e) {
      sentryMonitoring.finishSpan(span, status: const SpanStatus.internalError());
      rethrow;
    }
  }
  
  // ============================================================================
  // Custom Operations Tracking
  // ============================================================================
  
  /// Track custom operation
  Future<T> trackOperation<T>({
    required String name,
    required String category,
    required Future<T> Function() operation,
    Map<String, dynamic>? extra,
  }) async {
    final span = sentryMonitoring.startSpan(
      operation: '$category.$name',
      description: name,
    );
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      _recordMetric(
        name: '$category.$name',
        duration: stopwatch.elapsed,
        category: MetricCategory.custom,
        tags: extra,
      );
      
      sentryMonitoring.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (e) {
      stopwatch.stop();
      sentryMonitoring.finishSpan(span, status: const SpanStatus.internalError());
      rethrow;
    }
  }
  
  // ============================================================================
  // Performance Metrics
  // ============================================================================
  
  /// Record a performance metric
  void _recordMetric({
    required String name,
    required Duration duration,
    required MetricCategory category,
    Map<String, dynamic>? tags,
  }) {
    final metric = _metrics.putIfAbsent(
      name,
      () => PerformanceMetric(name: name, category: category),
    );
    
    metric.record(duration);
    
    // Log if in debug mode
    if (kDebugMode) {
      _logger.debug('Performance metric: $name = ${duration.inMilliseconds}ms');
    }
    
    // Send to Sentry as custom metric
    if (duration.inMilliseconds > 0) {
      sentryMonitoring.addBreadcrumb(
        message: 'Performance metric',
        category: 'performance.metric',
        data: {
          'name': name,
          'duration_ms': duration.inMilliseconds,
          'category': category.name,
          ...?tags,
        },
      );
    }
  }
  
  /// Get performance metrics summary
  Map<String, dynamic> getMetricsSummary() {
    final summary = <String, dynamic>{};
    
    for (final entry in _metrics.entries) {
      summary[entry.key] = entry.value.toJson();
    }
    
    return summary;
  }
  
  /// Get metrics by category
  List<PerformanceMetric> getMetricsByCategory(MetricCategory category) {
    return _metrics.values
        .where((metric) => metric.category == category)
        .toList();
  }
  
  /// Clear all metrics
  void clearMetrics() {
    _metrics.clear();
  }
  
  // ============================================================================
  // Helper Methods
  // ============================================================================
  
  SpanStatus _getSpanStatusFromError(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('404')) {
      return const SpanStatus.notFound();
    } else if (errorString.contains('401') || errorString.contains('403')) {
      return const SpanStatus.unauthenticated();
    } else if (errorString.contains('500')) {
      return const SpanStatus.internalError();
    } else if (errorString.contains('timeout')) {
      return const SpanStatus.deadlineExceeded();
    }
    
    return const SpanStatus.unknownError();
  }
  
  int? _getStatusCodeFromError(dynamic error) {
    final errorString = error.toString();
    
    // Try to extract status code from error message
    final regex = RegExp(r'\b\d{3}\b');
    final match = regex.firstMatch(errorString);
    
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    
    return null;
  }
  
  void _logSlowOperation({
    required String type,
    required String operation,
    required Duration duration,
  }) {
    _logger.warning('Slow $type operation detected', data: {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
    });
    
    // Report to Sentry
    sentryMonitoring.reportMessage(
      message: 'Slow $type operation: $operation took ${duration.inMilliseconds}ms',
      level: SentryLevel.warning,
      extra: {
        'type': type,
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
      },
    );
  }
}

/// Performance metric model
class PerformanceMetric {
  PerformanceMetric({
    required this.name,
    required this.category,
  });

  final String name;
  final MetricCategory category;
  
  int _count = 0;
  Duration _totalDuration = Duration.zero;
  Duration _minDuration = const Duration(days: 365);
  Duration _maxDuration = Duration.zero;
  
  void record(Duration duration) {
    _count++;
    _totalDuration += duration;
    
    if (duration < _minDuration) {
      _minDuration = duration;
    }
    
    if (duration > _maxDuration) {
      _maxDuration = duration;
    }
  }
  
  Duration get averageDuration {
    if (_count == 0) return Duration.zero;
    return _totalDuration ~/ _count;
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.name,
    'count': _count,
    'total_ms': _totalDuration.inMilliseconds,
    'average_ms': averageDuration.inMilliseconds,
    'min_ms': _minDuration.inMilliseconds,
    'max_ms': _maxDuration.inMilliseconds,
  };
}

/// Metric categories
enum MetricCategory {
  lifecycle,
  navigation,
  database,
  network,
  ui,
  custom,
}

/// Performance tracking provider
final performanceTrackingProvider = Provider<PerformanceTrackingService>((ref) {
  final sentryMonitoring = ref.watch(sentryMonitoringProvider);
  return PerformanceTrackingService(sentryMonitoring: sentryMonitoring);
});
