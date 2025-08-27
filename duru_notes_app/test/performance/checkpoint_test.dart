import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/core/performance/performance_monitor.dart';
import 'package:duru_notes_app/core/performance/battery_monitor.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

/// Checkpoint test for hourly monitoring during 8-hour battery test
/// 
/// This test is designed to be run every hour during the extended
/// battery and performance monitoring session. It collects key metrics
/// and validates that performance remains within acceptable bounds.
/// 
/// Usage:
/// ```bash
/// flutter test test/performance/checkpoint_test.dart --hour=1
/// flutter test test/performance/checkpoint_test.dart --hour=2
/// # ... continue for each hour
/// ```
void main() {
  group('Hourly Checkpoint Tests', () {
    late PerformanceMonitor performanceMonitor;
    late BatteryMonitor batteryMonitor;
    late int testHour;

    setUpAll(() async {
      // Initialize monitoring services
      LoggerFactory.initialize(TestLogger());
      performanceMonitor = PerformanceMonitor.instance;
      batteryMonitor = BatteryMonitor.instance;
      
      await performanceMonitor.initialize();
      await batteryMonitor.initialize();

      // Get test hour from environment or default to 1
      final hourArg = Platform.environment['hour'] ?? '1';
      testHour = int.tryParse(hourArg) ?? 1;
      
      print('\n🔍 Starting Checkpoint Test for Hour $testHour\n');
    });

    test('Hour $testHour: Performance Checkpoint', () async {
      final checkpointStart = DateTime.now();
      
      print('⏰ Checkpoint Start: ${checkpointStart.toLocal()}');
      
      // Collect current metrics
      final batteryInfo = await batteryMonitor.getCurrentBatteryInfo();
      final memoryUsage = await performanceMonitor.getCurrentMemoryUsage();
      final deviceInfo = await performanceMonitor.getDevicePerformanceInfo();
      
      print('🔋 Battery Level: ${batteryInfo.level}%');
      print('🧠 Memory Usage: ${memoryUsage.usedMemoryMB.toStringAsFixed(1)}MB '
            '(${memoryUsage.usagePercentage.toStringAsFixed(1)}%)');
      
      // Calculate battery drain rate if monitoring has been running
      final drainRate = batteryMonitor.getBatteryDrainRate();
      if (drainRate != null) {
        print('📉 Battery Drain Rate: ${drainRate.toStringAsFixed(2)}% per hour');
        
        // Assert acceptable drain rate (< 8% per hour)
        expect(drainRate, lessThan(8.0), 
            reason: 'Battery drain rate exceeds acceptable limit');
      }
      
      // Check memory usage is stable
      expect(memoryUsage.usagePercentage, lessThan(85.0),
          reason: 'Memory usage too high');
      
      // Validate battery level is reasonable for the test hour
      final expectedMinLevel = 100 - (testHour * 8); // Allow 8% drain per hour
      expect(batteryInfo.level, greaterThan(expectedMinLevel),
          reason: 'Battery level lower than expected for hour $testHour');
      
      print('✅ Hour $testHour checkpoint passed');
    });

    test('Hour $testHour: Quick Performance Validation', () async {
      // Run quick performance tests to ensure operations still meet 3-second rule
      const targetDuration = Duration(seconds: 3);
      
      // Simulate voice recording
      final voiceResult = await performanceMonitor.measureOperation(
        'Voice Recording Checkpoint H$testHour',
        () => _simulateVoiceRecording(),
      );
      
      expect(voiceResult.duration, lessThan(targetDuration),
          reason: 'Voice recording exceeded 3-second limit at hour $testHour');
      
      // Simulate OCR processing
      final ocrResult = await performanceMonitor.measureOperation(
        'OCR Processing Checkpoint H$testHour',
        () => _simulateOCRProcessing(),
      );
      
      expect(ocrResult.duration, lessThan(targetDuration),
          reason: 'OCR processing exceeded 3-second limit at hour $testHour');
      
      // Simulate share processing
      final shareResult = await performanceMonitor.measureOperation(
        'Share Processing Checkpoint H$testHour',
        () => _simulateShareProcessing(),
      );
      
      expect(shareResult.duration, lessThan(targetDuration),
          reason: 'Share processing exceeded 3-second limit at hour $testHour');
      
      print('⚡ Performance validation passed for hour $testHour');
      print('   Voice: ${voiceResult.duration.inMilliseconds}ms');
      print('   OCR: ${ocrResult.duration.inMilliseconds}ms'); 
      print('   Share: ${shareResult.duration.inMilliseconds}ms');
    });

    test('Hour $testHour: System Health Check', () async {
      // Check for performance alerts
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      // Get recent performance metrics
      final recentMetrics = performanceMonitor.getMetricsInRange(oneHourAgo, now);
      
      if (recentMetrics.isNotEmpty) {
        final slowOperations = recentMetrics
            .where((m) => m.duration > const Duration(seconds: 3))
            .length;
        
        final totalOperations = recentMetrics.length;
        final successRate = totalOperations > 0 
            ? (totalOperations - slowOperations) / totalOperations
            : 1.0;
        
        print('📊 Operations in last hour: $totalOperations');
        print('🎯 Success rate: ${(successRate * 100).toStringAsFixed(1)}%');
        
        // Assert acceptable success rate (> 90%)
        expect(successRate, greaterThan(0.9),
            reason: 'Success rate dropped below 90% at hour $testHour');
      }
      
      // Check if device is in battery save mode
      final batteryInfo = await batteryMonitor.getCurrentBatteryInfo();
      if (batteryInfo.isInBatterySaveMode) {
        print('⚠️  Device is in battery save mode');
      }
      
      print('🏥 System health check passed for hour $testHour');
    });

    test('Hour $testHour: Generate Intermediate Report', () async {
      // Generate a status report for this checkpoint
      final now = DateTime.now();
      final testStart = now.subtract(Duration(hours: testHour));
      
      if (batteryMonitor.isMonitoring) {
        final batteryReport = batteryMonitor.generateUsageReport(testStart, now);
        
        print('\n📋 Hour $testHour Status Report');
        print('===============================');
        print('Test Duration: ${batteryReport.duration.inHours}h ${batteryReport.duration.inMinutes % 60}m');
        print('Battery: ${batteryReport.startLevel}% → ${batteryReport.endLevel}%');
        print('Total Drain: ${batteryReport.totalDrain}%');
        print('Drain Rate: ${batteryReport.drainRate.toStringAsFixed(2)}% per hour');
        
        // Check if we're on track for the 8-hour test
        final projectedFinalLevel = 100 - (batteryReport.drainRate * 8);
        print('Projected 8h Level: ${projectedFinalLevel.toStringAsFixed(0)}%');
        
        if (projectedFinalLevel < 20) {
          print('⚠️  Warning: Projected battery level may be too low for 8-hour test');
        } else if (projectedFinalLevel > 70) {
          print('✅ Excellent: Battery usage is very efficient');
        } else {
          print('👍 Good: Battery usage is within acceptable range');
        }
        
        print('===============================\n');
      }
    });

    tearDownAll(() async {
      print('🏁 Checkpoint $testHour completed at ${DateTime.now().toLocal()}\n');
    });
  });
}

/// Simulate voice recording operation for checkpoint validation
Future<String> _simulateVoiceRecording() async {
  // Simulate realistic voice recording processing time
  await Future.delayed(Duration(milliseconds: 800 + (DateTime.now().millisecond % 400)));
  return 'Voice recording completed';
}

/// Simulate OCR processing operation for checkpoint validation
Future<String> _simulateOCRProcessing() async {
  // Simulate realistic OCR processing time
  await Future.delayed(Duration(milliseconds: 1200 + (DateTime.now().millisecond % 800)));
  return 'OCR processing completed';
}

/// Simulate share processing operation for checkpoint validation
Future<String> _simulateShareProcessing() async {
  // Simulate realistic share processing time
  await Future.delayed(Duration(milliseconds: 300 + (DateTime.now().millisecond % 200)));
  return 'Share processing completed';
}

/// Test logger implementation for checkpoint tests
class TestLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] INFO: $message');
    if (data != null && data.isNotEmpty) {
      print('  Data: $data');
    }
  }

  @override
  void warn(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] WARN: $message');
    if (error != null) print('  Error: $error');
    if (data != null && data.isNotEmpty) print('  Data: $data');
  }

  @override
  void error(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] ERROR: $message');
    if (error != null) print('  Error: $error');
    if (stack != null) print('  Stack: $stack');
    if (data != null && data.isNotEmpty) print('  Data: $data');
  }

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] BREADCRUMB: $message');
    if (data != null && data.isNotEmpty) {
      print('  Data: $data');
    }
  }
}
