import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Performance monitoring service for tracking app performance metrics
///
/// This service provides comprehensive performance tracking capabilities:
/// - Operation timing and profiling
/// - Memory usage monitoring
/// - Battery consumption tracking
/// - Device performance characteristics
/// - Real-time performance alerts
///
/// Used for validating the 3-second capture principle and monitoring
/// long-running operations like geofencing and reminder services.
class PerformanceMonitor {
  PerformanceMonitor._();
  static PerformanceMonitor? _instance;
  static PerformanceMonitor get instance =>
      _instance ??= PerformanceMonitor._();

  final AppLogger _logger = LoggerFactory.instance;
  final Map<String, Stopwatch> _activeOperations = {};
  final List<PerformanceMetric> _metrics = [];
  final StreamController<PerformanceAlert> _alertController =
      StreamController.broadcast();

  Timer? _memoryMonitoringTimer;
  Timer? _batteryMonitoringTimer;
  bool _isMonitoring = false;

  /// Stream of performance alerts
  Stream<PerformanceAlert> get alerts => _alertController.stream;

  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (_isMonitoring) return;

    try {
      if (!kDebugMode) {
        _logger.info('Performance monitoring disabled outside debug mode');
        return;
      }

      _isMonitoring = true;

      // Start periodic monitoring
      _startMemoryMonitoring();
      _startBatteryMonitoring();

      _logger.info('Performance monitoring initialized');
    } catch (e, stack) {
      _logger.error(
        'Failed to initialize performance monitoring',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _memoryMonitoringTimer?.cancel();
    _batteryMonitoringTimer?.cancel();
    _alertController.close();
    _isMonitoring = false;
  }

  /// Start timing an operation
  void startOperation(String operationName, {Map<String, dynamic>? metadata}) {
    final stopwatch = Stopwatch()..start();
    _activeOperations[operationName] = stopwatch;

    _logger.breadcrumb(
      'Performance: Started operation $operationName',
      data: metadata,
    );
  }

  /// End timing an operation and record the metric
  PerformanceMetric? endOperation(
    String operationName, {
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = _activeOperations.remove(operationName);
    if (stopwatch == null) {
      _logger.warn(
        'Attempted to end operation that was not started: $operationName',
      );
      return null;
    }

    stopwatch.stop();
    final metric = PerformanceMetric(
      operationName: operationName,
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    _metrics.add(metric);
    _logger.breadcrumb(
      'Performance: Completed operation $operationName in ${stopwatch.elapsedMilliseconds}ms',
      data: metadata,
    );

    // Check for performance alerts
    _checkPerformanceThresholds(metric);

    return metric;
  }

  /// Measure and record an operation
  Future<T> measureOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    startOperation(operationName, metadata: metadata);
    try {
      final result = await operation();
      endOperation(operationName, metadata: metadata);
      return result;
    } catch (e) {
      endOperation(
        operationName,
        metadata: {...?metadata, 'error': e.toString(), 'success': false},
      );
      rethrow;
    }
  }

  /// Get current memory usage
  Future<MemoryUsage> getCurrentMemoryUsage() async {
    try {
      // Platform-specific memory monitoring
      if (Platform.isAndroid) {
        return await _getAndroidMemoryUsage();
      } else if (Platform.isIOS) {
        return await _getIOSMemoryUsage();
      } else {
        return MemoryUsage.unknown();
      }
    } catch (e, stack) {
      _logger.error('Failed to get memory usage', error: e, stackTrace: stack);
      return MemoryUsage.unknown();
    }
  }

  /// Get current battery level
  Future<double?> getCurrentBatteryLevel() async {
    try {
      const platform = MethodChannel('duru_notes.performance/battery');
      final level = await platform.invokeMethod<double>('getBatteryLevel');
      return level;
    } catch (e) {
      _logger.warn('Failed to get battery level: $e');
      return null;
    }
  }

  /// Get device performance characteristics
  Future<DevicePerformanceInfo> getDevicePerformanceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return DevicePerformanceInfo(
          platform: 'Android',
          model: info.model,
          version: info.version.release,
          cpuCores: _estimateCpuCores(info.hardware),
          ramSizeGB: _estimateRamSize(info),
          performanceClass: _classifyPerformance(info),
        );
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return DevicePerformanceInfo(
          platform: 'iOS',
          model: info.model,
          version: info.systemVersion,
          cpuCores: _estimateIOSCpuCores(info.model),
          ramSizeGB: _estimateIOSRamSize(info.model),
          performanceClass: _classifyIOSPerformance(info.model),
        );
      }

      return DevicePerformanceInfo.unknown();
    } catch (e, stack) {
      _logger.error(
        'Failed to get device performance info',
        error: e,
        stackTrace: stack,
      );
      return DevicePerformanceInfo.unknown();
    }
  }

  /// Get performance metrics for a specific operation
  List<PerformanceMetric> getMetricsForOperation(String operationName) {
    return _metrics.where((m) => m.operationName == operationName).toList();
  }

  /// Get all performance metrics within a time range
  List<PerformanceMetric> getMetricsInRange(DateTime start, DateTime end) {
    return _metrics
        .where((m) => m.timestamp.isAfter(start) && m.timestamp.isBefore(end))
        .toList();
  }

  /// Get performance summary for an operation
  PerformanceSummary getOperationSummary(String operationName) {
    final metrics = getMetricsForOperation(operationName);
    if (metrics.isEmpty) {
      return PerformanceSummary.empty(operationName);
    }

    final durations = metrics.map((m) => m.duration).toList();
    final avgDuration = Duration(
      microseconds:
          (durations.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
                  durations.length)
              .round(),
    );

    final minDuration = durations.reduce((a, b) => a < b ? a : b);
    final maxDuration = durations.reduce((a, b) => a > b ? a : b);

    return PerformanceSummary(
      operationName: operationName,
      totalOperations: metrics.length,
      averageDuration: avgDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      successRate:
          metrics.where((m) => m.metadata['success'] != false).length /
          metrics.length,
    );
  }

  /// Clear old metrics (keep last 1000 entries)
  void clearOldMetrics() {
    if (_metrics.length > 1000) {
      _metrics.removeRange(0, _metrics.length - 1000);
    }
  }

  /// Start periodic memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitoringTimer = Timer.periodic(const Duration(minutes: 1), (
      _,
    ) async {
      final memoryUsage = await getCurrentMemoryUsage();

      _logger.breadcrumb(
        'Memory usage',
        data: {
          'used_mb': memoryUsage.usedMemoryMB,
          'available_mb': memoryUsage.availableMemoryMB,
          'usage_percentage': memoryUsage.usagePercentage,
        },
      );

      // Alert on high memory usage
      if (memoryUsage.usagePercentage > 85) {
        _alertController.add(
          PerformanceAlert(
            type: AlertType.highMemoryUsage,
            message:
                'Memory usage is ${memoryUsage.usagePercentage.toStringAsFixed(1)}%',
            severity: memoryUsage.usagePercentage > 95
                ? AlertSeverity.critical
                : AlertSeverity.warning,
            data: {'memory_usage': memoryUsage},
          ),
        );
      }
    });
  }

  /// Start periodic battery monitoring
  void _startBatteryMonitoring() {
    _batteryMonitoringTimer = Timer.periodic(const Duration(minutes: 5), (
      _,
    ) async {
      final batteryLevel = await getCurrentBatteryLevel();
      if (batteryLevel != null) {
        _logger.breadcrumb(
          'Battery level',
          data: {'level_percentage': batteryLevel},
        );
      }
    });
  }

  /// Check performance thresholds and trigger alerts
  void _checkPerformanceThresholds(PerformanceMetric metric) {
    const threeSecondThreshold = Duration(seconds: 3);

    // Alert on operations exceeding 3-second threshold
    if (metric.duration > threeSecondThreshold) {
      _alertController.add(
        PerformanceAlert(
          type: AlertType.slowOperation,
          message:
              '${metric.operationName} took ${metric.duration.inMilliseconds}ms',
          severity: metric.duration > const Duration(seconds: 5)
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          data: {'metric': metric},
        ),
      );
    }

    // Alert on consecutive slow operations
    final recentMetrics = getMetricsForOperation(metric.operationName)
        .where(
          (m) =>
              DateTime.now().difference(m.timestamp) <
              const Duration(minutes: 5),
        )
        .toList();

    if (recentMetrics.length >= 3 &&
        recentMetrics.every(
          (m) => m.duration > const Duration(milliseconds: 2000),
        )) {
      _alertController.add(
        PerformanceAlert(
          type: AlertType.consistentSlowness,
          message:
              '${metric.operationName} consistently slow (${recentMetrics.length} recent operations)',
          severity: AlertSeverity.warning,
          data: {'recent_metrics': recentMetrics},
        ),
      );
    }
  }

  /// Get Android memory usage
  Future<MemoryUsage> _getAndroidMemoryUsage() async {
    try {
      const platform = MethodChannel('duru_notes.performance/memory');
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getMemoryUsage',
      );

      if (result != null) {
        return MemoryUsage(
          usedMemoryMB: (result['used'] as num?)?.toDouble() ?? 0,
          availableMemoryMB: (result['available'] as num?)?.toDouble() ?? 0,
          totalMemoryMB: (result['total'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (e) {
      _logger.warn('Failed to get Android memory usage: $e');
    }

    return MemoryUsage.unknown();
  }

  /// Get iOS memory usage
  Future<MemoryUsage> _getIOSMemoryUsage() async {
    try {
      const platform = MethodChannel('duru_notes.performance/memory');
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getMemoryUsage',
      );

      if (result != null) {
        return MemoryUsage(
          usedMemoryMB: (result['used'] as num?)?.toDouble() ?? 0,
          availableMemoryMB: (result['available'] as num?)?.toDouble() ?? 0,
          totalMemoryMB: (result['total'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (e) {
      _logger.warn('Failed to get iOS memory usage: $e');
    }

    return MemoryUsage.unknown();
  }

  /// Estimate CPU cores from hardware info
  int _estimateCpuCores(String? hardware) {
    if (hardware == null) return 4; // Default assumption

    // Common patterns for core count estimation
    if (hardware.contains('octa')) return 8;
    if (hardware.contains('hexa')) return 6;
    if (hardware.contains('quad')) return 4;
    if (hardware.contains('dual')) return 2;

    return 4; // Default
  }

  /// Estimate RAM size from Android device info
  int _estimateRamSize(dynamic androidInfo) {
    // This would require additional native code to get actual RAM
    // For now, estimate based on device characteristics
    return 4; // Default 4GB assumption
  }

  /// Estimate iOS CPU cores from model
  int _estimateIOSCpuCores(String model) {
    // Modern iPhones typically have 6 cores (2 performance + 4 efficiency)
    // iPads may have 8 cores
    if (model.toLowerCase().contains('ipad')) return 8;
    return 6;
  }

  /// Estimate iOS RAM size from model
  int _estimateIOSRamSize(String model) {
    // Modern iOS devices typically have 4-8GB RAM
    if (model.toLowerCase().contains('pro')) return 8;
    return 4;
  }

  /// Classify Android device performance
  PerformanceClass _classifyPerformance(dynamic androidInfo) {
    // Classification based on API level, hardware, etc.
    final sdkInt = androidInfo.version.sdkInt as int;

    if (sdkInt >= 31) return PerformanceClass.high;
    if (sdkInt >= 28) return PerformanceClass.medium;
    return PerformanceClass.low;
  }

  /// Classify iOS device performance
  PerformanceClass _classifyIOSPerformance(String model) {
    // Simple classification based on model name
    if (model.contains('Pro') ||
        model.contains('13') ||
        model.contains('14') ||
        model.contains('15')) {
      return PerformanceClass.high;
    }
    if (model.contains('11') ||
        model.contains('12') ||
        model.contains('XR') ||
        model.contains('XS')) {
      return PerformanceClass.medium;
    }
    return PerformanceClass.low;
  }
}

/// Performance metric data class
class PerformanceMetric {
  const PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
    required this.metadata,
  });
  final String operationName;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  @override
  String toString() {
    return 'PerformanceMetric(operation: $operationName, '
        'duration: ${duration.inMilliseconds}ms, '
        'timestamp: $timestamp)';
  }
}

/// Memory usage information
class MemoryUsage {
  const MemoryUsage({
    required this.usedMemoryMB,
    required this.availableMemoryMB,
    required this.totalMemoryMB,
  });

  factory MemoryUsage.unknown() => const MemoryUsage(
    usedMemoryMB: 0,
    availableMemoryMB: 0,
    totalMemoryMB: 0,
  );
  final double usedMemoryMB;
  final double availableMemoryMB;
  final double totalMemoryMB;

  double get usagePercentage =>
      totalMemoryMB > 0 ? (usedMemoryMB / totalMemoryMB) * 100 : 0;

  @override
  String toString() {
    return 'MemoryUsage(used: ${usedMemoryMB.toStringAsFixed(1)}MB, '
        'available: ${availableMemoryMB.toStringAsFixed(1)}MB, '
        'total: ${totalMemoryMB.toStringAsFixed(1)}MB, '
        'usage: ${usagePercentage.toStringAsFixed(1)}%)';
  }
}

/// Device performance information
class DevicePerformanceInfo {
  const DevicePerformanceInfo({
    required this.platform,
    required this.model,
    required this.version,
    required this.cpuCores,
    required this.ramSizeGB,
    required this.performanceClass,
  });

  factory DevicePerformanceInfo.unknown() => const DevicePerformanceInfo(
    platform: 'Unknown',
    model: 'Unknown',
    version: 'Unknown',
    cpuCores: 4,
    ramSizeGB: 4,
    performanceClass: PerformanceClass.medium,
  );
  final String platform;
  final String model;
  final String version;
  final int cpuCores;
  final int ramSizeGB;
  final PerformanceClass performanceClass;

  @override
  String toString() {
    return 'DevicePerformanceInfo(platform: $platform, model: $model, '
        'version: $version, cores: $cpuCores, ram: ${ramSizeGB}GB, '
        'class: $performanceClass)';
  }
}

/// Performance summary for an operation
class PerformanceSummary {
  const PerformanceSummary({
    required this.operationName,
    required this.totalOperations,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.successRate,
  });

  factory PerformanceSummary.empty(String operationName) => PerformanceSummary(
    operationName: operationName,
    totalOperations: 0,
    averageDuration: Duration.zero,
    minDuration: Duration.zero,
    maxDuration: Duration.zero,
    successRate: 0,
  );
  final String operationName;
  final int totalOperations;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final double successRate;

  @override
  String toString() {
    return 'PerformanceSummary(operation: $operationName, '
        'operations: $totalOperations, '
        'avg: ${averageDuration.inMilliseconds}ms, '
        'min: ${minDuration.inMilliseconds}ms, '
        'max: ${maxDuration.inMilliseconds}ms, '
        'success: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Performance alert
class PerformanceAlert {
  PerformanceAlert({
    required this.type,
    required this.message,
    required this.severity,
    required this.data,
  }) : timestamp = DateTime.now();
  final AlertType type;
  final String message;
  final AlertSeverity severity;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  @override
  String toString() {
    return 'PerformanceAlert($severity: $message)';
  }
}

/// Alert types
enum AlertType {
  slowOperation,
  highMemoryUsage,
  consistentSlowness,
  batteryDrain,
}

/// Alert severity levels
enum AlertSeverity { info, warning, critical }

/// Device performance classification
enum PerformanceClass { low, medium, high }
