import 'dart:async';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/monitoring/sentry_monitoring.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:stack_trace/stack_trace.dart';

/// Structured error reporting service
class ErrorReportingService {
  ErrorReportingService({required this.sentryMonitoring});

  final SentryMonitoringService sentryMonitoring;
  final _logger = LoggerFactory.instance;

  // Error statistics
  final Map<String, ErrorStatistics> _errorStats = {};
  final List<ErrorReport> _recentErrors = [];

  // Error categorization
  static const Map<Type, ErrorCategory> _errorCategories = {
    SocketException: ErrorCategory.network,
    HttpException: ErrorCategory.network,
    TimeoutException: ErrorCategory.network,
    PlatformException: ErrorCategory.platform,
    FileSystemException: ErrorCategory.filesystem,
    FormatException: ErrorCategory.parsing,
    RangeError: ErrorCategory.logic,
    StateError: ErrorCategory.state,
    AssertionError: ErrorCategory.assertion,
  };

  // ============================================================================
  // Error Reporting
  // ============================================================================

  /// Report a structured error
  Future<SentryId> reportError({
    required dynamic error,
    StackTrace? stackTrace,
    ErrorContext? context,
    ErrorSeverity? severity,
    Map<String, dynamic>? extra,
    List<Breadcrumb>? breadcrumbs,
    bool silent = false,
  }) async {
    // Create error report
    final report = _createErrorReport(
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      context: context,
      severity: severity,
      extra: extra,
    );

    // Store report
    _storeErrorReport(report);

    // Log based on severity
    if (!silent) {
      _logError(report);
    }

    // Send to Sentry with structured data
    final sentryId = await sentryMonitoring.reportError(
      error: error,
      stackTrace: stackTrace,
      message: report.message,
      level: _getSentryLevel(report.severity),
      extra: _buildSentryExtra(report),
    );

    return sentryId;
  }

  /// Report a handled exception
  Future<void> reportHandledException({
    required dynamic exception,
    StackTrace? stackTrace,
    String? operation,
    Map<String, dynamic>? data,
  }) async {
    await reportError(
      error: exception,
      stackTrace: stackTrace,
      context: ErrorContext(operation: operation, data: data, isHandled: true),
      severity: ErrorSeverity.warning,
    );
  }

  /// Report a critical error
  Future<void> reportCriticalError({
    required dynamic error,
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? context,
  }) async {
    await reportError(
      error: error,
      stackTrace: stackTrace,
      context: ErrorContext(message: message, data: context, isCritical: true),
      severity: ErrorSeverity.critical,
    );
  }

  /// Report a validation error
  Future<void> reportValidationError({
    required String field,
    required String message,
    dynamic value,
    Map<String, dynamic>? context,
  }) async {
    await reportError(
      error: ValidationError(field: field, message: message, value: value),
      context: ErrorContext(
        operation: 'validation',
        data: {'field': field, 'value': value?.toString(), ...?context},
      ),
      severity: ErrorSeverity.info,
    );
  }

  /// Report a business logic error
  Future<void> reportBusinessError({
    required String code,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await reportError(
      error: BusinessError(code: code, message: message),
      context: ErrorContext(operation: 'business_logic', data: data),
      severity: ErrorSeverity.warning,
    );
  }

  // ============================================================================
  // Error Analysis
  // ============================================================================

  /// Analyze error patterns
  ErrorAnalysis analyzeErrors({Duration? timeWindow, ErrorCategory? category}) {
    final now = DateTime.now();
    final windowStart =
        timeWindow != null ? now.subtract(timeWindow) : DateTime(1970);

    final relevantErrors = _recentErrors.where((report) {
      if (report.timestamp.isBefore(windowStart)) return false;
      if (category != null && report.category != category) return false;
      return true;
    }).toList();

    // Group errors by type
    final errorsByType = <String, List<ErrorReport>>{};
    for (final error in relevantErrors) {
      errorsByType.putIfAbsent(error.errorType, () => []).add(error);
    }

    // Find most common errors
    final sortedTypes = errorsByType.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Calculate error rate
    final errorRate = relevantErrors.length / (timeWindow?.inMinutes ?? 1);

    return ErrorAnalysis(
      totalErrors: relevantErrors.length,
      errorsByType: errorsByType,
      mostCommonErrors: sortedTypes.take(5).map((e) => e.key).toList(),
      errorRate: errorRate,
      timeWindow: timeWindow,
      category: category,
    );
  }

  /// Get error statistics
  ErrorStatistics getStatistics(String errorType) {
    return _errorStats[errorType] ?? ErrorStatistics(errorType: errorType);
  }

  /// Get recent errors
  List<ErrorReport> getRecentErrors({
    int limit = 20,
    ErrorCategory? category,
    ErrorSeverity? severity,
  }) {
    var errors = _recentErrors.toList();

    if (category != null) {
      errors = errors.where((e) => e.category == category).toList();
    }

    if (severity != null) {
      errors = errors.where((e) => e.severity == severity).toList();
    }

    return errors.take(limit).toList();
  }

  // ============================================================================
  // Error Recovery
  // ============================================================================

  /// Attempt to recover from error
  Future<bool> attemptRecovery({
    required dynamic error,
    required Future<bool> Function() recoveryAction,
    int maxAttempts = 3,
    Duration? retryDelay,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _logger.info(
          'Attempting error recovery',
          data: {
            'attempt': attempt,
            'max_attempts': maxAttempts,
            'error_type': error.runtimeType.toString(),
          },
        );

        final success = await recoveryAction();

        if (success) {
          _logger.info(
            'Error recovery successful',
            data: {
              'attempt': attempt,
              'error_type': error.runtimeType.toString(),
            },
          );

          // Report successful recovery
          sentryMonitoring.addBreadcrumb(
            message: 'Error recovery successful',
            category: 'error.recovery',
            data: {
              'error_type': error.runtimeType.toString(),
              'attempts': attempt,
            },
          );

          return true;
        }
      } catch (e) {
        _logger.warning(
          'Recovery attempt failed',
          data: {
            'attempt': attempt,
            'original_error': error.toString(),
            'exception': e.toString(),
          },
        );
      }

      if (attempt < maxAttempts && retryDelay != null) {
        await Future.delayed(retryDelay);
      }
    }

    // Report failed recovery
    await reportError(
      error: error,
      context: ErrorContext(
        operation: 'recovery_failed',
        data: {'max_attempts': maxAttempts},
      ),
      severity: ErrorSeverity.error,
    );

    return false;
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  ErrorReport _createErrorReport({
    required dynamic error,
    required StackTrace stackTrace,
    ErrorContext? context,
    ErrorSeverity? severity,
    Map<String, dynamic>? extra,
  }) {
    // Parse stack trace
    final chain = Chain.forTrace(stackTrace);
    final frames = chain.toTrace().frames;

    // Determine error category
    final category = _categorizeError(error);

    // Extract error details
    final errorType = error.runtimeType.toString();
    final errorMessage = _extractErrorMessage(error);

    // Get source location
    final sourceLocation =
        frames.isNotEmpty ? _extractSourceLocation(frames.first) : null;

    return ErrorReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      errorType: errorType,
      message: errorMessage,
      category: category,
      severity: severity ?? _determineSeverity(error, context),
      stackTrace: chain.toString(),
      sourceLocation: sourceLocation,
      context: context,
      extra: extra,
      platform: defaultTargetPlatform.toString(),
      isDebug: kDebugMode,
    );
  }

  void _storeErrorReport(ErrorReport report) {
    // Add to recent errors
    _recentErrors.insert(0, report);

    // Keep only last 100 errors
    if (_recentErrors.length > 100) {
      _recentErrors.removeLast();
    }

    // Update statistics
    final stats = _errorStats.putIfAbsent(
      report.errorType,
      () => ErrorStatistics(errorType: report.errorType),
    );
    stats.recordError(report);
  }

  void _logError(ErrorReport report) {
    final logData = {
      'error_type': report.errorType,
      'category': report.category.name,
      'severity': report.severity.name,
      'message': report.message,
      if (report.sourceLocation != null) 'location': report.sourceLocation,
      if (report.context != null) 'context': report.context!.toJson(),
    };

    switch (report.severity) {
      case ErrorSeverity.critical:
      case ErrorSeverity.error:
        _logger.error(report.message, data: logData);
        break;
      case ErrorSeverity.warning:
        _logger.warning(report.message, data: logData);
        break;
      case ErrorSeverity.info:
        _logger.info(report.message, data: logData);
        break;
    }
  }

  ErrorCategory _categorizeError(dynamic error) {
    // Check known error types
    for (final entry in _errorCategories.entries) {
      if (error.runtimeType == entry.key) {
        return entry.value;
      }
    }

    // Check error message for patterns
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return ErrorCategory.network;
    }

    if (errorString.contains('database') || errorString.contains('sqlite')) {
      return ErrorCategory.database;
    }

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return ErrorCategory.permission;
    }

    if (errorString.contains('auth') || errorString.contains('unauthorized')) {
      return ErrorCategory.authentication;
    }

    return ErrorCategory.unknown;
  }

  String _extractErrorMessage(dynamic error) {
    if (error is Error) {
      return error.toString();
    }

    if (error is Exception) {
      return error.toString();
    }

    return error?.toString() ?? 'Unknown error';
  }

  String? _extractSourceLocation(Frame frame) {
    if (frame.uri.scheme == 'package') {
      return '${frame.uri.path}:${frame.line}:${frame.column}';
    }
    return null;
  }

  ErrorSeverity _determineSeverity(dynamic error, ErrorContext? context) {
    // Critical if marked as such
    if (context?.isCritical == true) {
      return ErrorSeverity.critical;
    }

    // Info if handled
    if (context?.isHandled == true) {
      return ErrorSeverity.info;
    }

    // Check error type
    if (error is AssertionError) {
      return ErrorSeverity.critical;
    }

    if (error is StateError || error is RangeError) {
      return ErrorSeverity.error;
    }

    if (error is FormatException || error is ValidationError) {
      return ErrorSeverity.warning;
    }

    return ErrorSeverity.error;
  }

  SentryLevel _getSentryLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return SentryLevel.fatal;
      case ErrorSeverity.error:
        return SentryLevel.error;
      case ErrorSeverity.warning:
        return SentryLevel.warning;
      case ErrorSeverity.info:
        return SentryLevel.info;
    }
  }

  Map<String, dynamic> _buildSentryExtra(ErrorReport report) {
    return {
      'category': report.category.name,
      'severity': report.severity.name,
      if (report.sourceLocation != null)
        'source_location': report.sourceLocation,
      if (report.context != null) ...report.context!.toJson(),
      if (report.extra != null) ...report.extra!,
      'platform': report.platform,
      'is_debug': report.isDebug,
    };
  }
}

// ============================================================================
// Models
// ============================================================================

/// Error report model
class ErrorReport {
  const ErrorReport({
    required this.id,
    required this.timestamp,
    required this.errorType,
    required this.message,
    required this.category,
    required this.severity,
    required this.stackTrace,
    this.sourceLocation,
    this.context,
    this.extra,
    required this.platform,
    required this.isDebug,
  });

  final String id;
  final DateTime timestamp;
  final String errorType;
  final String message;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final String stackTrace;
  final String? sourceLocation;
  final ErrorContext? context;
  final Map<String, dynamic>? extra;
  final String platform;
  final bool isDebug;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'error_type': errorType,
        'message': message,
        'category': category.name,
        'severity': severity.name,
        'stack_trace': stackTrace,
        'source_location': sourceLocation,
        'context': context?.toJson(),
        'extra': extra,
        'platform': platform,
        'is_debug': isDebug,
      };
}

/// Error context model
class ErrorContext {
  const ErrorContext({
    this.operation,
    this.message,
    this.data,
    this.isHandled = false,
    this.isCritical = false,
  });

  final String? operation;
  final String? message;
  final Map<String, dynamic>? data;
  final bool isHandled;
  final bool isCritical;

  Map<String, dynamic> toJson() => {
        if (operation != null) 'operation': operation,
        if (message != null) 'message': message,
        if (data != null) 'data': data,
        'is_handled': isHandled,
        'is_critical': isCritical,
      };
}

/// Error statistics model
class ErrorStatistics {
  ErrorStatistics({required this.errorType});

  final String errorType;
  int count = 0;
  DateTime? firstOccurrence;
  DateTime? lastOccurrence;
  final Map<ErrorSeverity, int> severityCounts = {};

  void recordError(ErrorReport report) {
    count++;
    firstOccurrence ??= report.timestamp;
    lastOccurrence = report.timestamp;
    severityCounts[report.severity] =
        (severityCounts[report.severity] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() => {
        'error_type': errorType,
        'count': count,
        'first_occurrence': firstOccurrence?.toIso8601String(),
        'last_occurrence': lastOccurrence?.toIso8601String(),
        'severity_counts': severityCounts.map((k, v) => MapEntry(k.name, v)),
      };
}

/// Error analysis result
class ErrorAnalysis {
  const ErrorAnalysis({
    required this.totalErrors,
    required this.errorsByType,
    required this.mostCommonErrors,
    required this.errorRate,
    this.timeWindow,
    this.category,
  });

  final int totalErrors;
  final Map<String, List<ErrorReport>> errorsByType;
  final List<String> mostCommonErrors;
  final double errorRate;
  final Duration? timeWindow;
  final ErrorCategory? category;

  Map<String, dynamic> toJson() => {
        'total_errors': totalErrors,
        'errors_by_type': errorsByType.map((k, v) => MapEntry(k, v.length)),
        'most_common_errors': mostCommonErrors,
        'error_rate': errorRate,
        'time_window_minutes': timeWindow?.inMinutes,
        'category': category?.name,
      };
}

/// Error categories
enum ErrorCategory {
  network,
  database,
  filesystem,
  platform,
  parsing,
  logic,
  state,
  assertion,
  permission,
  authentication,
  validation,
  business,
  unknown,
}

/// Error severity levels
enum ErrorSeverity { critical, error, warning, info }

/// Custom error types
class ValidationError extends Error {
  ValidationError({required this.field, required this.message, this.value});

  final String field;
  final String message;
  final dynamic value;

  @override
  String toString() => 'ValidationError: $field - $message';
}

class BusinessError extends Error {
  BusinessError({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'BusinessError [$code]: $message';
}

/// Error reporting provider
final errorReportingProvider = Provider<ErrorReportingService>((ref) {
  final sentryMonitoring = ref.watch(sentryMonitoringProvider);
  return ErrorReportingService(sentryMonitoring: sentryMonitoring);
});
