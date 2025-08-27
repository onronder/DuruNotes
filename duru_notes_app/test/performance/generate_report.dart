import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/core/performance/performance_monitor.dart';
import 'package:duru_notes_app/core/performance/battery_monitor.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

/// Test report generator for comprehensive performance and battery analysis
/// 
/// This test generates detailed reports from extended testing sessions,
/// providing analysis, recommendations, and production readiness assessment.
/// 
/// Usage:
/// ```bash
/// flutter test test/performance/generate_report.dart --test-session=8h_battery_test
/// ```
void main() {
  group('Performance Test Report Generation', () {
    late PerformanceMonitor performanceMonitor;
    late BatteryMonitor batteryMonitor;
    late String testSessionName;

    setUpAll(() async {
      // Initialize monitoring services
      LoggerFactory.initialize(TestLogger());
      performanceMonitor = PerformanceMonitor.instance;
      batteryMonitor = BatteryMonitor.instance;
      
      await performanceMonitor.initialize();
      await batteryMonitor.initialize();

      // Get test session name from environment
      testSessionName = Platform.environment['test-session'] ?? 'performance_test';
      
      print('\n📊 Generating Test Report for Session: $testSessionName\n');
    });

    test('Generate Comprehensive Performance Report', () async {
      final reportGenerationStart = DateTime.now();
      
      print('🔄 Starting report generation...');
      
      // Stop monitoring if still active and get final report
      BatteryMonitoringReport? batteryReport;
      if (batteryMonitor.isMonitoring) {
        batteryReport = await batteryMonitor.stopMonitoring();
        print('✅ Battery monitoring stopped, report generated');
      }
      
      // Collect all performance metrics
      final endTime = DateTime.now();
      final startTime = batteryReport?.startTime ?? 
          endTime.subtract(const Duration(hours: 8)); // Default 8-hour window
      
      final allMetrics = performanceMonitor.getMetricsInRange(startTime, endTime);
      print('📈 Collected ${allMetrics.length} performance metrics');
      
      // Generate detailed analysis
      final report = await _generateDetailedReport(
        testSessionName,
        startTime,
        endTime,
        batteryReport,
        allMetrics,
      );
      
      // Save report to file
      final reportFile = await _saveReportToFile(report, testSessionName);
      print('💾 Report saved to: ${reportFile.path}');
      
      // Print executive summary to console
      _printExecutiveSummary(report);
      
      // Validate test success criteria
      _validateTestResults(report);
      
      final reportGenerationTime = DateTime.now().difference(reportGenerationStart);
      print('\n⏱️  Report generation completed in ${reportGenerationTime.inMilliseconds}ms');
    });

    test('Validate Test Success Criteria', () async {
      // This test validates that all success criteria were met
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(hours: 8));
      
      final allMetrics = performanceMonitor.getMetricsInRange(startTime, endTime);
      
      // Test 3-second capture principle compliance
      final slowOperations = allMetrics
          .where((m) => m.duration > const Duration(seconds: 3))
          .toList();
      
      final successRate = allMetrics.isNotEmpty 
          ? (allMetrics.length - slowOperations.length) / allMetrics.length
          : 1.0;
      
      print('🎯 3-Second Compliance: ${(successRate * 100).toStringAsFixed(1)}%');
      
      // Assert minimum success rate (95%)
      expect(successRate, greaterThanOrEqualTo(0.95),
          reason: 'Success rate ${(successRate * 100).toStringAsFixed(1)}% is below required 95%');
      
      // Test battery consumption if available
      if (batteryMonitor.isMonitoring || 
          batteryMonitor.monitoringDuration != null) {
        final drainRate = batteryMonitor.getBatteryDrainRate();
        if (drainRate != null) {
          print('🔋 Battery Drain Rate: ${drainRate.toStringAsFixed(2)}% per hour');
          
          // Assert acceptable drain rate (< 5% per hour for 8-hour test)
          expect(drainRate, lessThan(5.0),
              reason: 'Battery drain rate ${drainRate.toStringAsFixed(2)}% per hour exceeds limit');
        }
      }
      
      print('✅ All success criteria validated');
    });

    test('Generate Recommendations', () async {
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(hours: 8));
      
      final allMetrics = performanceMonitor.getMetricsInRange(startTime, endTime);
      final recommendations = _generateRecommendations(allMetrics);
      
      print('\n💡 Performance Recommendations:');
      for (int i = 0; i < recommendations.length; i++) {
        print('   ${i + 1}. ${recommendations[i]}');
      }
      
      expect(recommendations, isNotEmpty,
          reason: 'Should generate at least some recommendations');
    });
  });
}

/// Generate detailed performance and battery test report
Future<TestReport> _generateDetailedReport(
  String sessionName,
  DateTime startTime,
  DateTime endTime,
  BatteryMonitoringReport? batteryReport,
  List<PerformanceMetric> metrics,
) async {
  print('🔍 Analyzing test data...');
  
  // Calculate performance statistics
  final performanceStats = _calculatePerformanceStatistics(metrics);
  
  // Analyze operation types
  final operationAnalysis = _analyzeOperationTypes(metrics);
  
  // Calculate success metrics
  final successMetrics = _calculateSuccessMetrics(metrics);
  
  // Generate device info
  final deviceInfo = await PerformanceMonitor.instance.getDevicePerformanceInfo();
  
  // Create comprehensive report
  return TestReport(
    sessionName: sessionName,
    startTime: startTime,
    endTime: endTime,
    testDuration: endTime.difference(startTime),
    deviceInfo: deviceInfo,
    batteryReport: batteryReport,
    performanceStatistics: performanceStats,
    operationAnalysis: operationAnalysis,
    successMetrics: successMetrics,
    recommendations: _generateRecommendations(metrics),
    generatedAt: DateTime.now(),
  );
}

/// Calculate overall performance statistics
PerformanceStatistics _calculatePerformanceStatistics(List<PerformanceMetric> metrics) {
  if (metrics.isEmpty) {
    return PerformanceStatistics.empty();
  }
  
  final durations = metrics.map((m) => m.duration.inMilliseconds).toList();
  durations.sort();
  
  final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
  final minDuration = durations.first;
  final maxDuration = durations.last;
  final medianDuration = durations[durations.length ~/ 2];
  
  // Calculate percentiles
  final p95Index = (durations.length * 0.95).floor();
  final p99Index = (durations.length * 0.99).floor();
  final p95Duration = durations[p95Index];
  final p99Duration = durations[p99Index];
  
  return PerformanceStatistics(
    totalOperations: metrics.length,
    averageDurationMs: avgDuration,
    minDurationMs: minDuration.toDouble(),
    maxDurationMs: maxDuration.toDouble(),
    medianDurationMs: medianDuration.toDouble(),
    p95DurationMs: p95Duration.toDouble(),
    p99DurationMs: p99Duration.toDouble(),
  );
}

/// Analyze performance by operation type
Map<String, OperationTypeAnalysis> _analyzeOperationTypes(List<PerformanceMetric> metrics) {
  final operationGroups = <String, List<PerformanceMetric>>{};
  
  // Group metrics by operation name
  for (final metric in metrics) {
    operationGroups.putIfAbsent(metric.operationName, () => []).add(metric);
  }
  
  final analysis = <String, OperationTypeAnalysis>{};
  
  for (final entry in operationGroups.entries) {
    final operationName = entry.key;
    final operationMetrics = entry.value;
    
    final durations = operationMetrics.map((m) => m.duration.inMilliseconds).toList();
    final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
    
    final slowOperations = operationMetrics
        .where((m) => m.duration > const Duration(seconds: 3))
        .length;
    
    final successRate = (operationMetrics.length - slowOperations) / operationMetrics.length;
    
    analysis[operationName] = OperationTypeAnalysis(
      operationName: operationName,
      totalOperations: operationMetrics.length,
      averageDurationMs: avgDuration,
      successRate: successRate,
      slowOperations: slowOperations,
    );
  }
  
  return analysis;
}

/// Calculate success metrics
SuccessMetrics _calculateSuccessMetrics(List<PerformanceMetric> metrics) {
  if (metrics.isEmpty) {
    return SuccessMetrics.empty();
  }
  
  final threeSecondThreshold = const Duration(seconds: 3);
  final operationsUnderThreshold = metrics
      .where((m) => m.duration <= threeSecondThreshold)
      .length;
  
  final complianceRate = operationsUnderThreshold / metrics.length;
  
  // Calculate error rate (assuming metadata contains success/error info)
  final successfulOperations = metrics
      .where((m) => m.metadata['success'] != false)
      .length;
  
  final errorRate = 1.0 - (successfulOperations / metrics.length);
  
  return SuccessMetrics(
    threeSecondComplianceRate: complianceRate,
    overallSuccessRate: successfulOperations / metrics.length,
    errorRate: errorRate,
    totalOperations: metrics.length,
    operationsUnderThreshold: operationsUnderThreshold,
  );
}

/// Generate improvement recommendations based on test results
List<String> _generateRecommendations(List<PerformanceMetric> metrics) {
  final recommendations = <String>[];
  
  if (metrics.isEmpty) {
    recommendations.add('No performance data available for analysis');
    return recommendations;
  }
  
  // Analyze slow operations
  final slowOperations = metrics
      .where((m) => m.duration > const Duration(seconds: 3))
      .toList();
  
  if (slowOperations.isNotEmpty) {
    final slowOperationTypes = <String, int>{};
    for (final op in slowOperations) {
      slowOperationTypes[op.operationName] = 
          (slowOperationTypes[op.operationName] ?? 0) + 1;
    }
    
    final mostProblematicOperation = slowOperationTypes.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    recommendations.add(
        'Optimize ${mostProblematicOperation.key} operations '
        '(${mostProblematicOperation.value} slow instances detected)'
    );
  }
  
  // Check for memory-related issues
  final memoryIntensiveOps = metrics
      .where((m) => m.metadata['memory_usage_mb'] != null &&
                    (m.metadata['memory_usage_mb'] as num) > 200)
      .toList();
  
  if (memoryIntensiveOps.isNotEmpty) {
    recommendations.add(
        'Consider memory optimization for operations using >200MB '
        '(${memoryIntensiveOps.length} instances detected)'
    );
  }
  
  // Check operation consistency
  final operationGroups = <String, List<int>>{};
  for (final metric in metrics) {
    operationGroups.putIfAbsent(metric.operationName, () => [])
        .add(metric.duration.inMilliseconds);
  }
  
  for (final entry in operationGroups.entries) {
    if (entry.value.length < 3) continue;
    
    final durations = entry.value;
    final avg = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations
        .map((d) => (d - avg) * (d - avg))
        .reduce((a, b) => a + b) / durations.length;
    
    final standardDeviation = math.sqrt(variance);
    final coefficientOfVariation = standardDeviation / avg;
    
    if (coefficientOfVariation > 0.5) { // High variability
      recommendations.add(
          'Improve consistency of ${entry.key} operations '
          '(high performance variability detected)'
      );
    }
  }
  
  // Battery optimization recommendations
  final longRunningOps = metrics
      .where((m) => m.duration > const Duration(seconds: 2))
      .length;
  
  if (longRunningOps > metrics.length * 0.1) { // >10% are slow
    recommendations.add(
        'Consider background processing for long-running operations '
        'to improve battery efficiency'
    );
  }
  
  // General performance recommendations
  if (recommendations.isEmpty) {
    recommendations.add('Performance is excellent! Consider monitoring trends over time.');
    recommendations.add('Implement performance regression testing for continuous validation.');
    recommendations.add('Consider A/B testing performance optimizations before deployment.');
  }
  
  return recommendations;
}

/// Save report to file
Future<File> _saveReportToFile(TestReport report, String sessionName) async {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final fileName = 'performance_report_${sessionName}_$timestamp.json';
  final file = File('test_reports/$fileName');
  
  // Create directory if it doesn't exist
  await file.parent.create(recursive: true);
  
  // Convert report to JSON
  final jsonReport = report.toJson();
  final jsonString = const JsonEncoder.withIndent('  ').convert(jsonReport);
  
  // Write to file
  await file.writeAsString(jsonString);
  
  return file;
}

/// Print executive summary to console
void _printExecutiveSummary(TestReport report) {
  print('\n' + '=' * 60);
  print('📋 PERFORMANCE TEST EXECUTIVE SUMMARY');
  print('=' * 60);
  
  print('📅 Test Session: ${report.sessionName}');
  print('⏱️  Duration: ${report.testDuration.inHours}h ${report.testDuration.inMinutes % 60}m');
  print('📱 Device: ${report.deviceInfo.platform} ${report.deviceInfo.model}');
  
  // Performance Summary
  final stats = report.performanceStatistics;
  print('\n🎯 PERFORMANCE METRICS:');
  print('   Total Operations: ${stats.totalOperations}');
  print('   Average Duration: ${stats.averageDurationMs.toStringAsFixed(0)}ms');
  print('   95th Percentile: ${stats.p95DurationMs.toStringAsFixed(0)}ms');
  
  // Success Metrics
  final success = report.successMetrics;
  print('\n✅ SUCCESS METRICS:');
  print('   3-Second Compliance: ${(success.threeSecondComplianceRate * 100).toStringAsFixed(1)}%');
  print('   Overall Success Rate: ${(success.overallSuccessRate * 100).toStringAsFixed(1)}%');
  print('   Error Rate: ${(success.errorRate * 100).toStringAsFixed(2)}%');
  
  // Battery Summary (if available)
  if (report.batteryReport != null) {
    final battery = report.batteryReport!;
    print('\n🔋 BATTERY METRICS:');
    print('   Total Drain: ${battery.totalBatteryDrain}%');
    print('   Average Drain Rate: ${battery.averageDrainRate.toStringAsFixed(2)}% per hour');
    print('   Final Level: ${battery.endBatteryLevel}%');
  }
  
  // Overall Grade
  final grade = _calculateOverallGrade(report);
  print('\n🏆 OVERALL GRADE: $grade');
  
  // Top Recommendations
  print('\n💡 TOP RECOMMENDATIONS:');
  final topRecommendations = report.recommendations.take(3);
  for (int i = 0; i < topRecommendations.length; i++) {
    print('   ${i + 1}. ${topRecommendations.elementAt(i)}');
  }
  
  print('\n' + '=' * 60);
}

/// Validate test results against success criteria
void _validateTestResults(TestReport report) {
  print('\n🔍 VALIDATING SUCCESS CRITERIA:');
  
  final success = report.successMetrics;
  
  // Check 3-second compliance
  if (success.threeSecondComplianceRate >= 0.95) {
    print('✅ 3-Second Compliance: PASS (${(success.threeSecondComplianceRate * 100).toStringAsFixed(1)}%)');
  } else {
    print('❌ 3-Second Compliance: FAIL (${(success.threeSecondComplianceRate * 100).toStringAsFixed(1)}%)');
  }
  
  // Check success rate
  if (success.overallSuccessRate >= 0.90) {
    print('✅ Success Rate: PASS (${(success.overallSuccessRate * 100).toStringAsFixed(1)}%)');
  } else {
    print('❌ Success Rate: FAIL (${(success.overallSuccessRate * 100).toStringAsFixed(1)}%)');
  }
  
  // Check battery drain (if available)
  if (report.batteryReport != null) {
    final drainRate = report.batteryReport!.averageDrainRate;
    if (drainRate <= 5.0) {
      print('✅ Battery Efficiency: PASS (${drainRate.toStringAsFixed(2)}% per hour)');
    } else {
      print('❌ Battery Efficiency: FAIL (${drainRate.toStringAsFixed(2)}% per hour)');
    }
  }
  
  print('');
}

/// Calculate overall performance grade
String _calculateOverallGrade(TestReport report) {
  double score = 0.0;
  
  // 3-second compliance (40% weight)
  score += report.successMetrics.threeSecondComplianceRate * 40;
  
  // Success rate (30% weight)
  score += report.successMetrics.overallSuccessRate * 30;
  
  // Battery efficiency (20% weight, if available)
  if (report.batteryReport != null) {
    final drainRate = report.batteryReport!.averageDrainRate;
    final batteryScore = (5.0 - drainRate.clamp(0.0, 5.0)) / 5.0; // Invert and normalize
    score += batteryScore * 20;
  } else {
    score += 15; // Partial credit if no battery data
  }
  
  // Performance consistency (10% weight)
  final stats = report.performanceStatistics;
  if (stats.totalOperations > 0) {
    final consistencyScore = 1.0 - ((stats.p95DurationMs - stats.averageDurationMs) / stats.averageDurationMs).clamp(0.0, 1.0);
    score += consistencyScore * 10;
  }
  
  // Convert to letter grade
  if (score >= 90) return 'A (Excellent)';
  if (score >= 80) return 'B (Good)';
  if (score >= 70) return 'C (Acceptable)';
  if (score >= 60) return 'D (Needs Improvement)';
  return 'F (Unacceptable)';
}

// Data classes for report structure
class TestReport {
  final String sessionName;
  final DateTime startTime;
  final DateTime endTime;
  final Duration testDuration;
  final DevicePerformanceInfo deviceInfo;
  final BatteryMonitoringReport? batteryReport;
  final PerformanceStatistics performanceStatistics;
  final Map<String, OperationTypeAnalysis> operationAnalysis;
  final SuccessMetrics successMetrics;
  final List<String> recommendations;
  final DateTime generatedAt;

  TestReport({
    required this.sessionName,
    required this.startTime,
    required this.endTime,
    required this.testDuration,
    required this.deviceInfo,
    this.batteryReport,
    required this.performanceStatistics,
    required this.operationAnalysis,
    required this.successMetrics,
    required this.recommendations,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'sessionName': sessionName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'testDurationMs': testDuration.inMilliseconds,
    'deviceInfo': deviceInfo.toString(), // Simplified for JSON
    'batteryReport': batteryReport?.toString(),
    'performanceStatistics': performanceStatistics.toJson(),
    'operationAnalysis': operationAnalysis.map((k, v) => MapEntry(k, v.toJson())),
    'successMetrics': successMetrics.toJson(),
    'recommendations': recommendations,
    'generatedAt': generatedAt.toIso8601String(),
  };
}

class PerformanceStatistics {
  final int totalOperations;
  final double averageDurationMs;
  final double minDurationMs;
  final double maxDurationMs;
  final double medianDurationMs;
  final double p95DurationMs;
  final double p99DurationMs;

  PerformanceStatistics({
    required this.totalOperations,
    required this.averageDurationMs,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.medianDurationMs,
    required this.p95DurationMs,
    required this.p99DurationMs,
  });

  factory PerformanceStatistics.empty() => PerformanceStatistics(
    totalOperations: 0,
    averageDurationMs: 0,
    minDurationMs: 0,
    maxDurationMs: 0,
    medianDurationMs: 0,
    p95DurationMs: 0,
    p99DurationMs: 0,
  );

  Map<String, dynamic> toJson() => {
    'totalOperations': totalOperations,
    'averageDurationMs': averageDurationMs,
    'minDurationMs': minDurationMs,
    'maxDurationMs': maxDurationMs,
    'medianDurationMs': medianDurationMs,
    'p95DurationMs': p95DurationMs,
    'p99DurationMs': p99DurationMs,
  };
}

class OperationTypeAnalysis {
  final String operationName;
  final int totalOperations;
  final double averageDurationMs;
  final double successRate;
  final int slowOperations;

  OperationTypeAnalysis({
    required this.operationName,
    required this.totalOperations,
    required this.averageDurationMs,
    required this.successRate,
    required this.slowOperations,
  });

  Map<String, dynamic> toJson() => {
    'operationName': operationName,
    'totalOperations': totalOperations,
    'averageDurationMs': averageDurationMs,
    'successRate': successRate,
    'slowOperations': slowOperations,
  };
}

class SuccessMetrics {
  final double threeSecondComplianceRate;
  final double overallSuccessRate;
  final double errorRate;
  final int totalOperations;
  final int operationsUnderThreshold;

  SuccessMetrics({
    required this.threeSecondComplianceRate,
    required this.overallSuccessRate,
    required this.errorRate,
    required this.totalOperations,
    required this.operationsUnderThreshold,
  });

  factory SuccessMetrics.empty() => SuccessMetrics(
    threeSecondComplianceRate: 0,
    overallSuccessRate: 0,
    errorRate: 0,
    totalOperations: 0,
    operationsUnderThreshold: 0,
  );

  Map<String, dynamic> toJson() => {
    'threeSecondComplianceRate': threeSecondComplianceRate,
    'overallSuccessRate': overallSuccessRate,
    'errorRate': errorRate,
    'totalOperations': totalOperations,
    'operationsUnderThreshold': operationsUnderThreshold,
  };
}

/// Test logger implementation
class TestLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] INFO: $message');
  }

  @override
  void warn(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] WARN: $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] ERROR: $message');
  }

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    // Suppress breadcrumbs in report generation to reduce noise
  }
}

// Add missing import
import 'dart:math' as math;
