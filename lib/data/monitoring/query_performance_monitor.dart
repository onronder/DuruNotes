import 'dart:async';
import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Query Performance Monitor
///
/// Tracks database query performance and identifies slow queries.
/// Target: All queries should complete in &lt;100ms
class QueryPerformanceMonitor {
  static const int _targetResponseTimeMs = 100;
  static const int _warningThresholdMs = 50;
  static const int _maxSlowQueries = 100;

  final AppDb _db;
  final AppLogger _logger;
  final List<QueryMetric> _slowQueries = [];
  final Map<String, QueryStats> _queryStats = {};

  QueryPerformanceMonitor({
    required AppDb db,
  }) : _db = db,
       _logger = LoggerFactory.instance;

  /// Monitor a query execution
  Future<T> monitorQuery<T>(
    String queryName,
    Future<T> Function() queryFunction, {
    Map<String, dynamic>? parameters,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await queryFunction();
      stopwatch.stop();

      final executionTime = stopwatch.elapsedMilliseconds;
      await _recordQueryMetric(queryName, executionTime, true, parameters);

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      final executionTime = stopwatch.elapsedMilliseconds;

      await _recordQueryMetric(queryName, executionTime, false, parameters);
      _logger.error('Query failed: $queryName', error: error, stackTrace: stackTrace);

      rethrow;
    }
  }

  /// Record query performance metric
  Future<void> _recordQueryMetric(
    String queryName,
    int executionTime,
    bool success,
    Map<String, dynamic>? parameters,
  ) async {
    final metric = QueryMetric(
      queryName: queryName,
      executionTime: executionTime,
      timestamp: DateTime.now(),
      success: success,
      parameters: parameters,
    );

    // Update running statistics
    _updateQueryStats(queryName, executionTime, success);

    // Log slow queries
    if (executionTime > _targetResponseTimeMs) {
      _logger.warning(
        'SLOW QUERY DETECTED: $queryName took ${executionTime}ms (target: ${_targetResponseTimeMs}ms)',
        data: {
          'query': queryName,
          'execution_time_ms': executionTime,
          'parameters': parameters,
          'target_ms': _targetResponseTimeMs,
        },
      );

      _addSlowQuery(metric);
    } else if (executionTime > _warningThresholdMs) {
      _logger.info(
        'Query approaching threshold: $queryName took ${executionTime}ms',
        data: {
          'query': queryName,
          'execution_time_ms': executionTime,
          'parameters': parameters,
        },
      );
    }
  }

  /// Update running statistics for a query
  void _updateQueryStats(String queryName, int executionTime, bool success) {
    final stats = _queryStats[queryName] ?? QueryStats(queryName: queryName);

    stats.totalExecutions++;
    stats.totalExecutionTime += executionTime;

    if (success) {
      stats.successfulExecutions++;
    }

    if (executionTime > stats.maxExecutionTime) {
      stats.maxExecutionTime = executionTime;
    }

    if (stats.minExecutionTime == 0 || executionTime < stats.minExecutionTime) {
      stats.minExecutionTime = executionTime;
    }

    if (executionTime > _targetResponseTimeMs) {
      stats.slowExecutions++;
    }

    stats.lastExecuted = DateTime.now();
    _queryStats[queryName] = stats;
  }

  /// Add slow query to tracking list
  void _addSlowQuery(QueryMetric metric) {
    _slowQueries.add(metric);

    // Keep only recent slow queries
    if (_slowQueries.length > _maxSlowQueries) {
      _slowQueries.removeAt(0);
    }
  }

  /// Get performance report
  Map<String, dynamic> getPerformanceReport() {
    final totalQueries = _queryStats.values.fold<int>(0, (sum, stats) => sum + stats.totalExecutions);
    final slowQueries = _queryStats.values.fold<int>(0, (sum, stats) => sum + stats.slowExecutions);
    final failedQueries = _queryStats.values.fold<int>(0, (sum, stats) => sum + (stats.totalExecutions - stats.successfulExecutions));

    final slowestQueries = _queryStats.values.toList()
      ..sort((a, b) => b.maxExecutionTime.compareTo(a.maxExecutionTime));

    final mostFrequentQueries = _queryStats.values.toList()
      ..sort((a, b) => b.totalExecutions.compareTo(a.totalExecutions));

    return {
      'summary': {
        'total_queries': totalQueries,
        'slow_queries': slowQueries,
        'failed_queries': failedQueries,
        'success_rate': totalQueries > 0 ? (totalQueries - failedQueries) / totalQueries : 0.0,
        'slow_query_rate': totalQueries > 0 ? slowQueries / totalQueries : 0.0,
        'target_response_time_ms': _targetResponseTimeMs,
      },
      'slowest_queries': slowestQueries.take(10).map((stats) => {
        'query': stats.queryName,
        'max_time_ms': stats.maxExecutionTime,
        'avg_time_ms': stats.averageExecutionTime,
        'total_executions': stats.totalExecutions,
        'slow_executions': stats.slowExecutions,
      }).toList(),
      'most_frequent_queries': mostFrequentQueries.take(10).map((stats) => {
        'query': stats.queryName,
        'total_executions': stats.totalExecutions,
        'avg_time_ms': stats.averageExecutionTime,
        'success_rate': stats.successRate,
      }).toList(),
      'recent_slow_queries': _slowQueries.reversed.take(20).map((metric) => {
        'query': metric.queryName,
        'execution_time_ms': metric.executionTime,
        'timestamp': metric.timestamp.toIso8601String(),
        'parameters': metric.parameters,
      }).toList(),
    };
  }

  /// Get specific query statistics
  QueryStats? getQueryStats(String queryName) {
    return _queryStats[queryName];
  }

  /// Get all query statistics
  List<QueryStats> getAllQueryStats() {
    return _queryStats.values.toList();
  }

  /// Check if database is performing within targets
  bool isPerformingWithinTargets() {
    if (_queryStats.isEmpty) return true;

    final totalQueries = _queryStats.values.fold<int>(0, (sum, stats) => sum + stats.totalExecutions);
    final slowQueries = _queryStats.values.fold<int>(0, (sum, stats) => sum + stats.slowExecutions);

    final slowQueryRate = totalQueries > 0 ? slowQueries / totalQueries : 0.0;

    // Allow up to 5% of queries to be slow
    return slowQueryRate <= 0.05;
  }

  /// Run performance validation tests
  Future<Map<String, dynamic>> runPerformanceValidation() async {
    final results = <String, dynamic>{};

    try {
      // Test basic note query
      final noteQueryTime = await _measureQueryTime('basic_note_query', () async {
        // Ignore the result, just measure the query time
        await (_db.select(_db.localNotes)
          ..where((n) => n.deleted.equals(false))
          ..orderBy([($LocalNotesTable n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)])
          ..limit(20)).get();
      });
      results['basic_note_query_ms'] = noteQueryTime;

      // Test tag aggregation query
      final tagQueryTime = await _measureQueryTime('tag_aggregation', () async {
        await _db.customSelect('''
          SELECT tag, COUNT(*) as count
          FROM note_tags
          GROUP BY tag
          ORDER BY count DESC
          LIMIT 50
        ''').get();
      });
      results['tag_aggregation_ms'] = tagQueryTime;

      // Test task query with joins
      final taskQueryTime = await _measureQueryTime('task_with_notes', () async {
        await _db.customSelect('''
          SELECT t.*, n.title as note_title
          FROM note_tasks t
          JOIN local_notes n ON t.note_id = n.id
          WHERE t.deleted = 0 AND n.deleted = 0
          ORDER BY t.due_date ASC
          LIMIT 50
        ''').get();
      });
      results['task_with_notes_ms'] = taskQueryTime;

      // Test folder hierarchy query
      final folderQueryTime = await _measureQueryTime('folder_hierarchy', () async {
        await _db.customSelect('''
          SELECT f.*, COUNT(nf.note_id) as note_count
          FROM local_folders f
          LEFT JOIN note_folders nf ON f.id = nf.folder_id
          WHERE f.deleted = 0
          GROUP BY f.id, f.name, f.parent_id, f.path
          ORDER BY f.path
        ''').get();
      });
      results['folder_hierarchy_ms'] = folderQueryTime;

      // Check if all queries meet target
      final allQueriesFast = [noteQueryTime, tagQueryTime, taskQueryTime, folderQueryTime]
          .every((time) => time <= _targetResponseTimeMs);

      results['all_queries_within_target'] = allQueriesFast;
      results['target_ms'] = _targetResponseTimeMs;
      results['validation_passed'] = allQueriesFast;

    } catch (e, stackTrace) {
      results['error'] = e.toString();
      results['validation_passed'] = false;
      _logger.error('Performance validation failed', error: e, stackTrace: stackTrace);
    }

    return results;
  }

  /// Measure query execution time
  Future<int> _measureQueryTime(String queryName, Future<void> Function() query) async {
    final stopwatch = Stopwatch()..start();
    await query();
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  /// Clear performance data
  void clearData() {
    _slowQueries.clear();
    _queryStats.clear();
  }

  /// Export performance data for analysis
  Map<String, dynamic> exportData() {
    return {
      'query_stats': _queryStats.map((key, value) => MapEntry(key, value.toMap())),
      'slow_queries': _slowQueries.map((metric) => metric.toMap()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Individual query performance metric
class QueryMetric {
  final String queryName;
  final int executionTime;
  final DateTime timestamp;
  final bool success;
  final Map<String, dynamic>? parameters;

  QueryMetric({
    required this.queryName,
    required this.executionTime,
    required this.timestamp,
    required this.success,
    this.parameters,
  });

  Map<String, dynamic> toMap() {
    return {
      'query_name': queryName,
      'execution_time_ms': executionTime,
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'parameters': parameters,
    };
  }
}

/// Aggregate statistics for a specific query
class QueryStats {
  final String queryName;
  int totalExecutions = 0;
  int successfulExecutions = 0;
  int slowExecutions = 0;
  int totalExecutionTime = 0;
  int maxExecutionTime = 0;
  int minExecutionTime = 0;
  DateTime? lastExecuted;

  QueryStats({required this.queryName});

  double get averageExecutionTime {
    if (totalExecutions == 0) return 0.0;
    return totalExecutionTime / totalExecutions;
  }

  double get successRate {
    if (totalExecutions == 0) return 0.0;
    return successfulExecutions / totalExecutions;
  }

  double get slowQueryRate {
    if (totalExecutions == 0) return 0.0;
    return slowExecutions / totalExecutions;
  }

  Map<String, dynamic> toMap() {
    return {
      'query_name': queryName,
      'total_executions': totalExecutions,
      'successful_executions': successfulExecutions,
      'slow_executions': slowExecutions,
      'total_execution_time_ms': totalExecutionTime,
      'max_execution_time_ms': maxExecutionTime,
      'min_execution_time_ms': minExecutionTime,
      'average_execution_time_ms': averageExecutionTime,
      'success_rate': successRate,
      'slow_query_rate': slowQueryRate,
      'last_executed': lastExecuted?.toIso8601String(),
    };
  }
}