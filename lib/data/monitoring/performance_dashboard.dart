import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/cache/enhanced_cache_strategy.dart';
import 'package:duru_notes/data/monitoring/query_performance_monitor.dart';

/// Performance monitoring dashboard for database optimization
///
/// Provides real-time performance metrics and alerts for:
/// - Query execution times
/// - Cache hit ratios
/// - Database health
/// - Performance regressions
class PerformanceDashboard {
  PerformanceDashboard({
    required this.queryMonitor,
    required this.cacheStrategy,
    AppLogger? logger,
  }) : _logger = logger ?? LoggerFactory.instance;

  final QueryPerformanceMonitor queryMonitor;
  final EnhancedCacheStrategy cacheStrategy;
  final AppLogger _logger;

  Timer? _monitoringTimer;

  // Performance thresholds
  static const int criticalQueryThresholdMs = 50;
  static const int complexQueryThresholdMs = 100;
  static const double minimumCacheHitRatio = 0.8;

  /// Start continuous performance monitoring
  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _monitoringTimer?.cancel();

    _monitoringTimer = Timer.periodic(interval, (_) {
      _checkPerformanceMetrics();
    });

    _logger.info('Performance monitoring started', data: {
      'interval_minutes': interval.inMinutes,
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _logger.info('Performance monitoring stopped');
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    final queryStats = queryMonitor.getPerformanceReport();
    final cacheStats = cacheStrategy.getCacheStatistics();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'query_performance': queryStats,
      'cache_performance': cacheStats,
      'health_status': _getHealthStatus(queryStats, cacheStats),
      'recommendations': _getOptimizationRecommendations(queryStats, cacheStats),
    };
  }

  /// Check performance metrics and alert if thresholds exceeded
  void _checkPerformanceMetrics() {
    try {
      final report = getPerformanceReport();
      final healthStatus = report['health_status'] as Map<String, dynamic>;

      // Check for performance issues
      final issues = <String>[];

      if (healthStatus['slow_queries'] == true) {
        issues.add('Slow queries detected');
      }

      if (healthStatus['low_cache_hit_ratio'] == true) {
        issues.add('Low cache hit ratio');
      }

      if (healthStatus['memory_pressure'] == true) {
        issues.add('Memory pressure detected');
      }

      if (issues.isNotEmpty) {
        _logger.warning('Performance issues detected', data: {
          'issues': issues,
          'report': report,
        });

        // Trigger optimization if needed
        _triggerAutoOptimization(report);
      } else {
        _logger.debug('Performance monitoring: All metrics within thresholds');
      }

    } catch (e, stackTrace) {
      _logger.error('Performance monitoring failed', error: e, stackTrace: stackTrace);
    }
  }

  /// Get system health status
  Map<String, dynamic> _getHealthStatus(
    Map<String, dynamic> queryStats,
    Map<String, dynamic> cacheStats,
  ) {
    final summary = queryStats['summary'] as Map<String, dynamic>? ?? {};
    final avgQueryTime = summary['avg_execution_time'] as num? ?? 0;
    final slowQueryRate = summary['slow_query_rate'] as num? ?? 0;
    final cacheHitRatio = cacheStats['hit_ratio'] as num? ?? 0;

    return {
      'overall_status': _getOverallStatus(avgQueryTime, slowQueryRate, cacheHitRatio),
      'slow_queries': avgQueryTime > complexQueryThresholdMs || slowQueryRate > 0.1,
      'low_cache_hit_ratio': cacheHitRatio < minimumCacheHitRatio,
      'memory_pressure': _checkMemoryPressure(cacheStats),
      'database_healthy': avgQueryTime < complexQueryThresholdMs && slowQueryRate < 0.05,
    };
  }

  /// Get overall system status
  String _getOverallStatus(num avgQueryTime, num slowQueryRate, num cacheHitRatio) {
    if (avgQueryTime < criticalQueryThresholdMs &&
        slowQueryRate < 0.02 &&
        cacheHitRatio > 0.9) {
      return 'excellent';
    } else if (avgQueryTime < complexQueryThresholdMs &&
               slowQueryRate < 0.05 &&
               cacheHitRatio > minimumCacheHitRatio) {
      return 'good';
    } else if (avgQueryTime < complexQueryThresholdMs * 1.5 &&
               slowQueryRate < 0.1 &&
               cacheHitRatio > 0.6) {
      return 'fair';
    } else {
      return 'poor';
    }
  }

  /// Check for memory pressure in caching system
  bool _checkMemoryPressure(Map<String, dynamic> cacheStats) {
    final l1Caches = cacheStats['l1_caches'] as List<dynamic>? ?? [];

    for (final cache in l1Caches) {
      final cacheMap = cache as Map<String, dynamic>;
      final size = cacheMap['size'] as int? ?? 0;
      final maxSize = cacheMap['maxSize'] as int? ?? 100;

      if (size / maxSize > 0.9) {
        return true; // Cache is >90% full
      }
    }

    return false;
  }

  /// Get optimization recommendations based on performance data
  List<String> _getOptimizationRecommendations(
    Map<String, dynamic> queryStats,
    Map<String, dynamic> cacheStats,
  ) {
    final recommendations = <String>[];
    final summary = queryStats['summary'] as Map<String, dynamic>? ?? {};

    // Query performance recommendations
    final avgQueryTime = summary['avg_execution_time'] as num? ?? 0;
    final slowQueryRate = summary['slow_query_rate'] as num? ?? 0;

    if (avgQueryTime > complexQueryThresholdMs) {
      recommendations.add('Consider adding indexes for frequently executed queries');
    }

    if (slowQueryRate > 0.1) {
      recommendations.add('Review and optimize slow queries identified in monitoring');
    }

    // Cache performance recommendations
    final cacheHitRatio = cacheStats['hit_ratio'] as num? ?? 0;

    if (cacheHitRatio < 0.7) {
      recommendations.add('Increase cache sizes or implement cache warming strategy');
    }

    if (cacheHitRatio < 0.5) {
      recommendations.add('Review cache invalidation patterns and TTL settings');
    }

    // Memory recommendations
    if (_checkMemoryPressure(cacheStats)) {
      recommendations.add('Consider implementing cache eviction or increasing memory limits');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal - no immediate action required');
    }

    return recommendations;
  }

  /// Trigger automatic performance optimizations
  void _triggerAutoOptimization(Map<String, dynamic> report) {
    try {
      final cacheStats = report['cache_performance'] as Map<String, dynamic>;
      final cacheHitRatio = cacheStats['hit_ratio'] as num? ?? 0;

      // Auto-optimize cache if hit ratio is low
      if (cacheHitRatio < 0.6) {
        _logger.info('Triggering automatic cache optimization');
        cacheStrategy.optimizeCachePerformance();
      }

      // Additional auto-optimizations can be added here

    } catch (e) {
      _logger.warning('Auto-optimization failed: $e');
    }
  }

  /// Export performance data for analysis
  Future<String> exportPerformanceData({
    Duration? period,
  }) async {
    try {
      final report = getPerformanceReport();

      // Add historical context if available
      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'period_analyzed': period?.inHours ?? 'current_snapshot',
        'performance_report': report,
        'system_info': await _getSystemInfo(),
      };

      return exportData.toString();
    } catch (e, stackTrace) {
      _logger.error('Performance data export failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get system information for context
  Future<Map<String, dynamic>> _getSystemInfo() async {
    // This would collect system information relevant to performance
    return {
      'platform': 'flutter',
      'database_type': 'sqlite',
      'cache_implementation': 'enhanced_multi_level',
      'monitoring_version': '2.0',
    };
  }

  /// Dispose the performance dashboard
  void dispose() {
    stopMonitoring();
    _logger.info('Performance dashboard disposed');
  }
}