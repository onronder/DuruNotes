import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Comprehensive battery monitoring service for tracking power consumption
///
/// This service provides detailed battery monitoring capabilities specifically
/// designed for validating the power efficiency of geofencing and reminder
/// services over extended periods (8+ hours).
///
/// Features:
/// - Real-time battery level tracking
/// - Power consumption estimation
/// - Background service impact monitoring
/// - Battery drain alerts and reporting
/// - Long-term battery usage analysis
class BatteryMonitor {
  BatteryMonitor._();
  static BatteryMonitor? _instance;
  static BatteryMonitor get instance => _instance ??= BatteryMonitor._();

  final AppLogger _logger = LoggerFactory.instance;
  final Battery _battery = Battery();

  Timer? _monitoringTimer;
  Timer? _reportingTimer;

  final List<BatteryReading> _readings = [];
  BatteryReading? _lastReading;
  DateTime? _monitoringStartTime;
  bool _isMonitoring = false;

  /// Configuration for battery monitoring
  static const Duration _defaultMonitoringInterval = Duration(minutes: 1);
  static const Duration _reportingInterval = Duration(minutes: 15);
  static const int _maxReadings = 1440; // 24 hours at 1-minute intervals

  /// Stream controller for battery alerts
  final StreamController<BatteryAlert> _alertController =
      StreamController.broadcast();

  /// Stream of battery alerts
  Stream<BatteryAlert> get alerts => _alertController.stream;

  /// Current battery monitoring status
  bool get isMonitoring => _isMonitoring;

  /// Duration of current monitoring session
  Duration? get monitoringDuration => _monitoringStartTime != null
      ? DateTime.now().difference(_monitoringStartTime!)
      : null;

  /// Initialize battery monitoring
  Future<void> initialize() async {
    try {
      final config = EnvironmentConfig.current;
      if (!config.isPerformanceMonitoringEnabled) {
        _logger.info('Battery monitoring disabled in configuration');
        return;
      }

      // Get initial battery state
      final initialLevel = await _battery.batteryLevel;
      final initialState = await _battery.batteryState;

      _logger.info(
        'Battery monitoring initialized',
        data: {
          'initial_level': initialLevel,
          'initial_state': initialState.toString(),
        },
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to initialize battery monitoring',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Start battery monitoring
  Future<void> startMonitoring({
    Duration interval = _defaultMonitoringInterval,
    String? testSessionName,
  }) async {
    if (_isMonitoring) {
      _logger.warn('Battery monitoring already active');
      return;
    }

    try {
      _isMonitoring = true;
      _monitoringStartTime = DateTime.now();

      // Clear old readings
      _readings.clear();

      // Take initial reading
      await _takeBatteryReading(testSessionName: testSessionName);

      // Start periodic monitoring
      _monitoringTimer = Timer.periodic(interval, (_) async {
        await _takeBatteryReading(testSessionName: testSessionName);
      });

      // Start periodic reporting
      _reportingTimer = Timer.periodic(_reportingInterval, (_) {
        _generatePeriodicReport();
      });

      _logger.info(
        'Battery monitoring started',
        data: {
          'interval_seconds': interval.inSeconds,
          'session_name': testSessionName,
        },
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to start battery monitoring',
        error: e,
        stackTrace: stack,
      );
      _isMonitoring = false;
    }
  }

  /// Stop battery monitoring and generate final report
  Future<BatteryMonitoringReport> stopMonitoring() async {
    if (!_isMonitoring) {
      throw StateError('Battery monitoring is not active');
    }

    try {
      _monitoringTimer?.cancel();
      _reportingTimer?.cancel();

      // Take final reading
      await _takeBatteryReading();

      final report = _generateFinalReport();

      _isMonitoring = false;
      _monitoringStartTime = null;

      _logger.info(
        'Battery monitoring stopped',
        data: {
          'total_readings': _readings.length,
          'duration_hours': report.totalDuration.inHours,
          'total_drain_percent': report.totalBatteryDrain,
        },
      );

      return report;
    } catch (e, stack) {
      _logger.error(
        'Failed to stop battery monitoring',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get current battery information
  Future<BatteryInfo> getCurrentBatteryInfo() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isInBatterySaveMode = await _battery.isInBatterySaveMode;

      return BatteryInfo(
        level: level,
        state: state,
        isInBatterySaveMode: isInBatterySaveMode,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error('Failed to get battery info', error: e, stackTrace: stack);
      return BatteryInfo.unknown();
    }
  }

  /// Get battery readings within a time range
  List<BatteryReading> getReadingsInRange(DateTime start, DateTime end) {
    return _readings
        .where(
          (reading) =>
              reading.timestamp.isAfter(start) &&
              reading.timestamp.isBefore(end),
        )
        .toList();
  }

  /// Get battery drain rate (percentage per hour)
  double? getBatteryDrainRate() {
    if (_readings.length < 2) return null;

    final firstReading = _readings.first;
    final lastReading = _readings.last;

    final timeDifference = lastReading.timestamp.difference(
      firstReading.timestamp,
    );
    final levelDifference =
        firstReading.batteryLevel - lastReading.batteryLevel;

    if (timeDifference.inMinutes == 0) return null;

    final hoursElapsed = timeDifference.inMinutes / 60.0;
    return levelDifference / hoursElapsed;
  }

  /// Estimate time remaining based on current drain rate
  Duration? getEstimatedTimeRemaining() {
    final drainRate = getBatteryDrainRate();
    if (drainRate == null || drainRate <= 0) return null;

    final currentLevel = _lastReading?.batteryLevel ?? 0;
    final hoursRemaining = currentLevel / drainRate;

    return Duration(minutes: (hoursRemaining * 60).round());
  }

  /// Check if battery drain is within acceptable limits
  bool isBatteryDrainAcceptable({
    double maxDrainPerHour = 5.0, // 5% per hour default
  }) {
    final drainRate = getBatteryDrainRate();
    return drainRate == null || drainRate <= maxDrainPerHour;
  }

  /// Generate battery usage report for a specific time period
  BatteryUsageReport generateUsageReport(DateTime start, DateTime end) {
    final readings = getReadingsInRange(start, end);
    if (readings.isEmpty) {
      return BatteryUsageReport.empty(start, end);
    }

    final startLevel = readings.first.batteryLevel;
    final endLevel = readings.last.batteryLevel;
    final totalDrain = startLevel - endLevel;
    final duration = end.difference(start);

    final drainRate = duration.inMinutes > 0
        ? (totalDrain / (duration.inMinutes / 60.0))
        : 0.0;

    return BatteryUsageReport(
      startTime: start,
      endTime: end,
      startLevel: startLevel,
      endLevel: endLevel,
      totalDrain: totalDrain,
      drainRate: drainRate,
      readings: readings,
    );
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _reportingTimer?.cancel();
    _alertController.close();
    _isMonitoring = false;
  }

  /// Take a battery reading and store it
  Future<void> _takeBatteryReading({String? testSessionName}) async {
    try {
      final batteryInfo = await getCurrentBatteryInfo();

      final reading = BatteryReading(
        batteryLevel: batteryInfo.level,
        batteryState: batteryInfo.state,
        isInBatterySaveMode: batteryInfo.isInBatterySaveMode,
        timestamp: batteryInfo.timestamp,
        testSessionName: testSessionName,
      );

      _readings.add(reading);
      _lastReading = reading;

      // Trim old readings to prevent memory issues
      if (_readings.length > _maxReadings) {
        _readings.removeAt(0);
      }

      // Check for alerts
      _checkBatteryAlerts(reading);

      _logger.breadcrumb(
        'Battery reading taken',
        data: {
          'level': reading.batteryLevel,
          'state': reading.batteryState.toString(),
          'battery_save_mode': reading.isInBatterySaveMode,
        },
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to take battery reading',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Check for battery-related alerts
  void _checkBatteryAlerts(BatteryReading reading) {
    // Low battery alert
    if (reading.batteryLevel <= 20 && reading.batteryLevel > 10) {
      _alertController.add(
        BatteryAlert(
          type: BatteryAlertType.lowBattery,
          message: 'Battery level is ${reading.batteryLevel}%',
          severity: BatteryAlertSeverity.warning,
          batteryLevel: reading.batteryLevel,
        ),
      );
    } else if (reading.batteryLevel <= 10) {
      _alertController.add(
        BatteryAlert(
          type: BatteryAlertType.criticalBattery,
          message: 'Battery level is critically low: ${reading.batteryLevel}%',
          severity: BatteryAlertSeverity.critical,
          batteryLevel: reading.batteryLevel,
        ),
      );
    }

    // High drain rate alert
    final drainRate = getBatteryDrainRate();
    if (drainRate != null && drainRate > 10.0) {
      // >10% per hour
      _alertController.add(
        BatteryAlert(
          type: BatteryAlertType.highDrainRate,
          message:
              'High battery drain rate: ${drainRate.toStringAsFixed(1)}% per hour',
          severity: drainRate > 20.0
              ? BatteryAlertSeverity.critical
              : BatteryAlertSeverity.warning,
          drainRate: drainRate,
        ),
      );
    }

    // Battery save mode alert
    if (reading.isInBatterySaveMode) {
      _alertController.add(
        BatteryAlert(
          type: BatteryAlertType.batterySaveMode,
          message: 'Device entered battery save mode',
          severity: BatteryAlertSeverity.info,
          batteryLevel: reading.batteryLevel,
        ),
      );
    }
  }

  /// Generate periodic battery report
  void _generatePeriodicReport() {
    if (_readings.length < 2) return;

    final now = DateTime.now();
    final fifteenMinutesAgo = now.subtract(_reportingInterval);
    final recentReadings = getReadingsInRange(fifteenMinutesAgo, now);

    if (recentReadings.length >= 2) {
      final startLevel = recentReadings.first.batteryLevel;
      final endLevel = recentReadings.last.batteryLevel;
      final drain = startLevel - endLevel;
      final drainRate = drain / (_reportingInterval.inMinutes / 60.0);

      _logger.info(
        'Periodic battery report',
        data: {
          'period_minutes': _reportingInterval.inMinutes,
          'start_level': startLevel,
          'end_level': endLevel,
          'drain_percent': drain,
          'drain_rate_per_hour': drainRate,
          'readings_count': recentReadings.length,
        },
      );
    }
  }

  /// Generate final monitoring report
  BatteryMonitoringReport _generateFinalReport() {
    if (_readings.isEmpty || _monitoringStartTime == null) {
      return BatteryMonitoringReport.empty();
    }

    final totalDuration = DateTime.now().difference(_monitoringStartTime!);
    final startLevel = _readings.first.batteryLevel;
    final endLevel = _readings.last.batteryLevel;
    final totalDrain = startLevel - endLevel;
    final averageDrainRate = getBatteryDrainRate() ?? 0.0;

    // Calculate statistics
    final batteryLevels = _readings.map((r) => r.batteryLevel).toList();
    final minLevel = batteryLevels.reduce((a, b) => a < b ? a : b);
    final maxLevel = batteryLevels.reduce((a, b) => a > b ? a : b);

    // Count state changes
    final stateChanges = <BatteryState, int>{};
    for (final reading in _readings) {
      stateChanges[reading.batteryState] =
          (stateChanges[reading.batteryState] ?? 0) + 1;
    }

    return BatteryMonitoringReport(
      startTime: _monitoringStartTime!,
      endTime: DateTime.now(),
      totalDuration: totalDuration,
      startBatteryLevel: startLevel,
      endBatteryLevel: endLevel,
      totalBatteryDrain: totalDrain,
      averageDrainRate: averageDrainRate,
      minBatteryLevel: minLevel,
      maxBatteryLevel: maxLevel,
      totalReadings: _readings.length,
      stateChanges: stateChanges,
      readings: List.from(_readings),
    );
  }
}

/// Individual battery reading
class BatteryReading {
  const BatteryReading({
    required this.batteryLevel,
    required this.batteryState,
    required this.isInBatterySaveMode,
    required this.timestamp,
    this.testSessionName,
  });
  final int batteryLevel;
  final BatteryState batteryState;
  final bool isInBatterySaveMode;
  final DateTime timestamp;
  final String? testSessionName;

  @override
  String toString() {
    return 'BatteryReading(level: $batteryLevel%, state: $batteryState, '
        'batterySave: $isInBatterySaveMode, time: $timestamp)';
  }
}

/// Current battery information
class BatteryInfo {
  const BatteryInfo({
    required this.level,
    required this.state,
    required this.isInBatterySaveMode,
    required this.timestamp,
  });

  factory BatteryInfo.unknown() => BatteryInfo(
    level: 0,
    state: BatteryState.unknown,
    isInBatterySaveMode: false,
    timestamp: DateTime.now(),
  );
  final int level;
  final BatteryState state;
  final bool isInBatterySaveMode;
  final DateTime timestamp;

  @override
  String toString() {
    return 'BatteryInfo(level: $level%, state: $state, '
        'batterySave: $isInBatterySaveMode)';
  }
}

/// Battery usage report for a specific time period
class BatteryUsageReport {
  const BatteryUsageReport({
    required this.startTime,
    required this.endTime,
    required this.startLevel,
    required this.endLevel,
    required this.totalDrain,
    required this.drainRate,
    required this.readings,
  });

  factory BatteryUsageReport.empty(DateTime start, DateTime end) =>
      BatteryUsageReport(
        startTime: start,
        endTime: end,
        startLevel: 0,
        endLevel: 0,
        totalDrain: 0,
        drainRate: 0,
        readings: [],
      );
  final DateTime startTime;
  final DateTime endTime;
  final int startLevel;
  final int endLevel;
  final int totalDrain;
  final double drainRate; // Percentage per hour
  final List<BatteryReading> readings;

  Duration get duration => endTime.difference(startTime);

  @override
  String toString() {
    return 'BatteryUsageReport(duration: ${duration.inHours}h, '
        'drain: $totalDrain%, rate: ${drainRate.toStringAsFixed(1)}%/h)';
  }
}

/// Comprehensive battery monitoring report
class BatteryMonitoringReport {
  const BatteryMonitoringReport({
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.totalBatteryDrain,
    required this.averageDrainRate,
    required this.minBatteryLevel,
    required this.maxBatteryLevel,
    required this.totalReadings,
    required this.stateChanges,
    required this.readings,
  });

  factory BatteryMonitoringReport.empty() {
    final now = DateTime.now();
    return BatteryMonitoringReport(
      startTime: now,
      endTime: now,
      totalDuration: Duration.zero,
      startBatteryLevel: 0,
      endBatteryLevel: 0,
      totalBatteryDrain: 0,
      averageDrainRate: 0,
      minBatteryLevel: 0,
      maxBatteryLevel: 0,
      totalReadings: 0,
      stateChanges: {},
      readings: [],
    );
  }
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final int totalBatteryDrain;
  final double averageDrainRate;
  final int minBatteryLevel;
  final int maxBatteryLevel;
  final int totalReadings;
  final Map<BatteryState, int> stateChanges;
  final List<BatteryReading> readings;

  /// Get formatted summary string
  String getSummary() {
    return '''
Battery Monitoring Report
========================
Duration: ${totalDuration.inHours}h ${totalDuration.inMinutes % 60}m
Battery Level: $startBatteryLevel% → $endBatteryLevel%
Total Drain: $totalBatteryDrain%
Average Drain Rate: ${averageDrainRate.toStringAsFixed(2)}% per hour
Min/Max Levels: $minBatteryLevel%/$maxBatteryLevel%
Total Readings: $totalReadings
''';
  }

  @override
  String toString() {
    return 'BatteryMonitoringReport(duration: ${totalDuration.inHours}h, '
        'drain: $totalBatteryDrain%, rate: ${averageDrainRate.toStringAsFixed(1)}%/h)';
  }
}

/// Battery alert
class BatteryAlert {
  BatteryAlert({
    required this.type,
    required this.message,
    required this.severity,
    this.batteryLevel,
    this.drainRate,
  }) : timestamp = DateTime.now();
  final BatteryAlertType type;
  final String message;
  final BatteryAlertSeverity severity;
  final DateTime timestamp;
  final int? batteryLevel;
  final double? drainRate;

  @override
  String toString() {
    return 'BatteryAlert($severity: $message)';
  }
}

/// Battery alert types
enum BatteryAlertType {
  lowBattery,
  criticalBattery,
  highDrainRate,
  batterySaveMode,
}

/// Battery alert severity levels
enum BatteryAlertSeverity { info, warning, critical }
