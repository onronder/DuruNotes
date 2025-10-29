import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Production-grade Centralized Error Logging Service
/// Provides comprehensive error tracking, analytics, and reporting
/// Features:
/// - Multi-channel logging (console, file, remote)
/// - Error categorization and prioritization
/// - Performance impact tracking
/// - User session correlation
/// - Offline error queuing
/// - Automatic error deduplication
/// - Error trends and analytics
class ErrorLoggingService {
  static final ErrorLoggingService _instance = ErrorLoggingService._internal();
  factory ErrorLoggingService() => _instance;
  ErrorLoggingService._internal();

  // Configuration
  static const int _maxLocalErrors = 1000;
  static const int _maxErrorsPerSession = 100;
  static const Duration _errorAggregationWindow = Duration(minutes: 5);
  static const Duration _uploadInterval = Duration(minutes: 1);

  // State
  bool _initialized = false;
  String? _userId;
  String? _sessionId;
  DeviceInfo? _deviceInfo;
  AppInfo? _appInfo;

  // Error storage
  final Queue<ErrorLogEntry> _errorQueue = Queue();
  final Map<String, ErrorAggregation> _errorAggregations = {};
  final List<ErrorLogEntry> _sessionErrors = [];

  // Performance tracking
  final Map<String, PerformanceMetrics> _performanceMetrics = {};

  // Timers
  Timer? _uploadTimer;
  Timer? _aggregationTimer;

  // File logging
  File? _logFile;
  IOSink? _logSink;

  /// Initialize the error logging service
  Future<void> initialize({
    required String userId,
    String? sessionId,
    bool enableFileLogging = true,
    bool enableRemoteLogging = true,
  }) async {
    if (_initialized) return;

    _userId = userId;
    _sessionId = sessionId ?? _generateSessionId();

    // Load device and app info
    await _loadDeviceInfo();
    await _loadAppInfo();

    // Initialize file logging
    if (enableFileLogging) {
      await _initializeFileLogging();
    }

    // Initialize remote logging
    if (enableRemoteLogging) {
      await _initializeRemoteLogging();
    }

    // Start background tasks
    _startBackgroundTasks();

    // Load persisted errors
    await _loadPersistedErrors();

    _initialized = true;

    logInfo('ErrorLoggingService initialized', {
      'userId': _userId,
      'sessionId': _sessionId,
      'device': _deviceInfo?.toJson(),
      'app': _appInfo?.toJson(),
    });
  }

  /// Log an error with full context
  Future<void> logError(
    Object error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? category,
    Map<String, dynamic>? metadata,
    bool shouldNotifyUser = false,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('ErrorLoggingService not initialized. Error: $error');
      }
      return;
    }

    // Create error entry
    final entry = ErrorLogEntry(
      id: _generateErrorId(),
      timestamp: DateTime.now(),
      userId: _userId,
      sessionId: _sessionId,
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      severity: severity,
      category: category ?? _categorizeError(error),
      metadata: {
        ...?metadata,
        'deviceInfo': _deviceInfo?.toJson(),
        'appInfo': _appInfo?.toJson(),
        'memoryUsage': _getMemoryUsage(),
        'errorType': error.runtimeType.toString(),
      },
      shouldNotifyUser: shouldNotifyUser,
    );

    // Add to session errors
    _sessionErrors.add(entry);
    if (_sessionErrors.length > _maxErrorsPerSession) {
      _sessionErrors.removeAt(0);
    }

    // Add to queue
    _errorQueue.add(entry);
    if (_errorQueue.length > _maxLocalErrors) {
      _errorQueue.removeFirst();
    }

    // Aggregate similar errors
    _aggregateError(entry);

    // Track performance impact
    _trackPerformanceImpact(entry);

    // Log to different channels
    await _logToConsole(entry);
    await _logToFile(entry);
    await _logToRemote(entry);

    // Persist for offline scenarios
    await _persistError(entry);

    // Notify listeners if critical
    if (severity == ErrorSeverity.critical) {
      _notifyCriticalError(entry);
    }
  }

  /// Log informational message
  Future<void> logInfo(String message, [Map<String, dynamic>? metadata]) async {
    await logError(
      InfoMessage(message),
      null,
      severity: ErrorSeverity.info,
      metadata: metadata,
    );
  }

  /// Log warning message
  Future<void> logWarning(String message, [Map<String, dynamic>? metadata]) async {
    await logError(
      WarningMessage(message),
      null,
      severity: ErrorSeverity.warning,
      metadata: metadata,
    );
  }

  /// Log debug message
  Future<void> logDebug(String message, [Map<String, dynamic>? metadata]) async {
    if (kDebugMode) {
      await logError(
        DebugMessage(message),
        null,
        severity: ErrorSeverity.debug,
        metadata: metadata,
      );
    }
  }

  /// Get error statistics
  ErrorStatistics getStatistics() {
    final now = DateTime.now();
    final recentErrors = _sessionErrors.where((e) {
      return now.difference(e.timestamp) <= const Duration(hours: 1);
    }).toList();

    // Count by severity
    final severityCounts = <ErrorSeverity, int>{};
    for (final severity in ErrorSeverity.values) {
      severityCounts[severity] = recentErrors
          .where((e) => e.severity == severity)
          .length;
    }

    // Count by category
    final categoryCounts = <String, int>{};
    for (final error in recentErrors) {
      final category = error.category ?? 'Unknown';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    // Get top errors
    final topErrors = _errorAggregations.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return ErrorStatistics(
      totalErrors: _sessionErrors.length,
      recentErrors: recentErrors.length,
      severityCounts: severityCounts,
      categoryCounts: categoryCounts,
      topErrors: topErrors.take(10).toList(),
      performanceMetrics: Map.from(_performanceMetrics),
    );
  }

  /// Get recent errors
  List<ErrorLogEntry> getRecentErrors({
    int limit = 50,
    ErrorSeverity? minSeverity,
    String? category,
  }) {
    var errors = _sessionErrors.reversed.toList();

    if (minSeverity != null) {
      errors = errors.where((e) => e.severity.index >= minSeverity.index).toList();
    }

    if (category != null) {
      errors = errors.where((e) => e.category == category).toList();
    }

    return errors.take(limit).toList();
  }

  /// Export error logs
  Future<String> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
    ExportFormat format = ExportFormat.json,
  }) async {
    final errors = _sessionErrors.where((e) {
      if (startDate != null && e.timestamp.isBefore(startDate)) return false;
      if (endDate != null && e.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();

    switch (format) {
      case ExportFormat.json:
        return _exportAsJson(errors);
      case ExportFormat.csv:
        return _exportAsCsv(errors);
      case ExportFormat.plainText:
        return _exportAsPlainText(errors);
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _errorQueue.clear();
    _sessionErrors.clear();
    _errorAggregations.clear();
    _performanceMetrics.clear();

    await _clearPersistedErrors();
    await _clearLogFile();

    logInfo('Error logs cleared');
  }

  // Private methods

  Future<void> _loadDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      _deviceInfo = DeviceInfo(
        platform: 'Android',
        model: info.model,
        manufacturer: info.manufacturer,
        osVersion: info.version.release,
        sdkVersion: info.version.sdkInt.toString(),
      );
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      _deviceInfo = DeviceInfo(
        platform: 'iOS',
        model: info.model,
        manufacturer: 'Apple',
        osVersion: info.systemVersion,
        sdkVersion: info.systemVersion,
      );
    }
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _appInfo = AppInfo(
      name: packageInfo.appName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
    );
  }

  Future<void> _initializeFileLogging() async {
    try {
      final directory = await resolveAppDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logDir.path}/error_log_$timestamp.log');
      _logSink = _logFile!.openWrite(mode: FileMode.append);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize file logging: $e');
      }
    }
  }

  Future<void> _initializeRemoteLogging() async {
    // Initialize Sentry or other remote logging service
    // This is handled by SentryFlutter.init in main.dart
  }

  void _startBackgroundTasks() {
    // Upload timer
    _uploadTimer = Timer.periodic(_uploadInterval, (_) {
      _uploadPendingErrors();
    });

    // Aggregation cleanup timer
    _aggregationTimer = Timer.periodic(_errorAggregationWindow, (_) {
      _cleanupOldAggregations();
    });
  }

  Future<void> _loadPersistedErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorsJson = prefs.getStringList('persisted_errors') ?? [];

      for (final json in errorsJson) {
        final entry = ErrorLogEntry.fromJson(jsonDecode(json) as Map<String, dynamic>);
        _errorQueue.add(entry);
      }

      // Clear persisted errors after loading
      await prefs.remove('persisted_errors');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load persisted errors: $e');
      }
    }
  }

  Future<void> _persistError(ErrorLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errors = prefs.getStringList('persisted_errors') ?? [];

      errors.add(jsonEncode(entry.toJson()));

      // Keep only recent errors
      if (errors.length > 100) {
        errors.removeRange(0, errors.length - 100);
      }

      await prefs.setStringList('persisted_errors', errors);
    } catch (e) {
      // Ignore persistence failures
    }
  }

  Future<void> _clearPersistedErrors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persisted_errors');
  }

  Future<void> _clearLogFile() async {
    await _logSink?.close();
    await _logFile?.delete();
    await _initializeFileLogging();
  }

  Future<void> _logToConsole(ErrorLogEntry entry) async {
    if (!kDebugMode) return;

    final severityEmoji = _getSeverityEmoji(entry.severity);
    final message = '$severityEmoji [${entry.severity.name}] ${entry.error}';

    debugPrint(message);

    if (entry.stackTrace != null && entry.severity.index >= ErrorSeverity.error.index) {
      debugPrint('Stack trace:\n${entry.stackTrace}');
    }
  }

  Future<void> _logToFile(ErrorLogEntry entry) async {
    if (_logSink == null) return;

    try {
      final logLine = '${jsonEncode(entry.toJson())}\n';
      _logSink!.write(logLine);
      await _logSink!.flush();
    } catch (e) {
      // Ignore file logging failures
    }
  }

  Future<void> _logToRemote(ErrorLogEntry entry) async {
    if (entry.severity.index < ErrorSeverity.warning.index) return;

    try {
      await Sentry.captureMessage(
        entry.error,
        level: _mapToSentryLevel(entry.severity),
        withScope: (scope) {
          scope.setUser(SentryUser(id: _userId));
          scope.setTag('sessionId', _sessionId ?? 'unknown');
          scope.setTag('category', entry.category ?? 'unknown');

          if (entry.metadata != null) {
            // Use Contexts API instead of deprecated setExtra
            scope.setContexts('metadata', entry.metadata!);
          }
        },
      );
    } catch (e) {
      // Ignore remote logging failures
    }
  }

  void _aggregateError(ErrorLogEntry entry) {
    final key = '${entry.error.hashCode}_${entry.category}';

    _errorAggregations.putIfAbsent(
      key,
      () => ErrorAggregation(
        firstOccurrence: entry.timestamp,
        error: entry.error,
        category: entry.category,
      ),
    ).addOccurrence(entry.timestamp);
  }

  void _cleanupOldAggregations() {
    final cutoff = DateTime.now().subtract(_errorAggregationWindow * 2);

    _errorAggregations.removeWhere((key, aggregation) {
      return aggregation.lastOccurrence.isBefore(cutoff);
    });
  }

  void _trackPerformanceImpact(ErrorLogEntry entry) {
    final category = entry.category ?? 'Unknown';

    _performanceMetrics.putIfAbsent(
      category,
      () => PerformanceMetrics(category: category),
    ).recordError(entry.severity);
  }

  Future<void> _uploadPendingErrors() async {
    // Upload queued errors to remote service
    // This would be implemented based on your backend
  }

  void _notifyCriticalError(ErrorLogEntry entry) {
    // Notify app components about critical errors
    // Could use event bus or stream controller
  }

  String _categorizeError(Object error) {
    if (error is SocketException) return 'Network';
    if (error is FormatException) return 'DataFormat';
    if (error is FileSystemException) return 'FileSystem';
    if (error is TimeoutException) return 'Timeout';
    if (error is StateError) return 'State';
    if (error is ArgumentError) return 'Argument';
    if (error is RangeError) return 'Range';
    if (error is UnsupportedError) return 'Unsupported';
    return 'General';
  }

  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_$_userId';
  }

  String _generateErrorId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  Map<String, dynamic> _getMemoryUsage() {
    return {
      'rss': ProcessInfo.currentRss,
      'maxRss': ProcessInfo.maxRss,
    };
  }

  String _getSeverityEmoji(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.debug:
        return '🔍';
      case ErrorSeverity.info:
        return 'ℹ️';
      case ErrorSeverity.warning:
        return '⚠️';
      case ErrorSeverity.error:
        return '❌';
      case ErrorSeverity.critical:
        return '🔴';
    }
  }

  SentryLevel _mapToSentryLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.debug:
        return SentryLevel.debug;
      case ErrorSeverity.info:
        return SentryLevel.info;
      case ErrorSeverity.warning:
        return SentryLevel.warning;
      case ErrorSeverity.error:
        return SentryLevel.error;
      case ErrorSeverity.critical:
        return SentryLevel.fatal;
    }
  }

  String _exportAsJson(List<ErrorLogEntry> errors) {
    return jsonEncode(errors.map((e) => e.toJson()).toList());
  }

  String _exportAsCsv(List<ErrorLogEntry> errors) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Severity,Category,Error,User,Session');

    for (final error in errors) {
      buffer.writeln([
        error.timestamp.toIso8601String(),
        error.severity.name,
        error.category ?? '',
        '"${error.error.replaceAll('"', '""')}"',
        error.userId ?? '',
        error.sessionId ?? '',
      ].join(','));
    }

    return buffer.toString();
  }

  String _exportAsPlainText(List<ErrorLogEntry> errors) {
    final buffer = StringBuffer();

    for (final error in errors) {
      buffer.writeln('=' * 50);
      buffer.writeln('Time: ${error.timestamp}');
      buffer.writeln('Severity: ${error.severity.name}');
      buffer.writeln('Category: ${error.category}');
      buffer.writeln('Error: ${error.error}');

      if (error.stackTrace != null) {
        buffer.writeln('Stack Trace:');
        buffer.writeln(error.stackTrace);
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  void dispose() {
    _uploadTimer?.cancel();
    _aggregationTimer?.cancel();
    _logSink?.close();
  }
}

// Data models

enum ErrorSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

enum ExportFormat {
  json,
  csv,
  plainText,
}

class ErrorLogEntry {
  final String id;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;
  final String error;
  final String? stackTrace;
  final ErrorSeverity severity;
  final String? category;
  final Map<String, dynamic>? metadata;
  final bool shouldNotifyUser;

  ErrorLogEntry({
    required this.id,
    required this.timestamp,
    this.userId,
    this.sessionId,
    required this.error,
    this.stackTrace,
    required this.severity,
    this.category,
    this.metadata,
    this.shouldNotifyUser = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'sessionId': sessionId,
    'error': error,
    'stackTrace': stackTrace,
    'severity': severity.name,
    'category': category,
    'metadata': metadata,
    'shouldNotifyUser': shouldNotifyUser,
  };

  factory ErrorLogEntry.fromJson(Map<String, dynamic> json) => ErrorLogEntry(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    userId: json['userId'] as String?,
    sessionId: json['sessionId'] as String?,
    error: json['error'] as String,
    stackTrace: json['stackTrace'] as String?,
    severity: ErrorSeverity.values.firstWhere((e) => e.name == json['severity']),
    category: json['category'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
    shouldNotifyUser: json['shouldNotifyUser'] as bool? ?? false,
  );
}

class ErrorAggregation {
  final DateTime firstOccurrence;
  final String error;
  final String? category;
  DateTime lastOccurrence;
  int count = 0;

  ErrorAggregation({
    required this.firstOccurrence,
    required this.error,
    this.category,
  }) : lastOccurrence = firstOccurrence;

  void addOccurrence(DateTime timestamp) {
    count++;
    lastOccurrence = timestamp;
  }
}

class PerformanceMetrics {
  final String category;
  int errorCount = 0;
  int warningCount = 0;
  int criticalCount = 0;
  DateTime? lastErrorTime;

  PerformanceMetrics({required this.category});

  void recordError(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        warningCount++;
        break;
      case ErrorSeverity.error:
        errorCount++;
        break;
      case ErrorSeverity.critical:
        criticalCount++;
        break;
      default:
        break;
    }
    lastErrorTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'errorCount': errorCount,
    'warningCount': warningCount,
    'criticalCount': criticalCount,
    'lastErrorTime': lastErrorTime?.toIso8601String(),
  };
}

class ErrorStatistics {
  final int totalErrors;
  final int recentErrors;
  final Map<ErrorSeverity, int> severityCounts;
  final Map<String, int> categoryCounts;
  final List<ErrorAggregation> topErrors;
  final Map<String, PerformanceMetrics> performanceMetrics;

  ErrorStatistics({
    required this.totalErrors,
    required this.recentErrors,
    required this.severityCounts,
    required this.categoryCounts,
    required this.topErrors,
    required this.performanceMetrics,
  });
}

class DeviceInfo {
  final String platform;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final String? sdkVersion;

  DeviceInfo({
    required this.platform,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.sdkVersion,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'model': model,
    'manufacturer': manufacturer,
    'osVersion': osVersion,
    'sdkVersion': sdkVersion,
  };
}

class AppInfo {
  final String name;
  final String version;
  final String buildNumber;
  final String packageName;

  AppInfo({
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.packageName,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'buildNumber': buildNumber,
    'packageName': packageName,
  };
}

// Message types
class InfoMessage {
  final String message;
  InfoMessage(this.message);
  @override
  String toString() => message;
}

class WarningMessage {
  final String message;
  WarningMessage(this.message);
  @override
  String toString() => message;
}

class DebugMessage {
  final String message;
  DebugMessage(this.message);
  @override
  String toString() => message;
}
