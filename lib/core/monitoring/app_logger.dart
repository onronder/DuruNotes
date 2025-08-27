import 'package:duru_notes_app/core/config/environment_config.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade logging interface with multiple implementations
abstract class AppLogger {
  /// Log informational messages
  void info(String message, {Map<String, Object?>? data});
  
  /// Log warning messages
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data});
  
  /// Log error messages
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data});
  
  /// Add breadcrumb for debugging
  void breadcrumb(String message, {Map<String, Object?>? data});
}

/// Sentry-based logger implementation
class SentryLogger implements AppLogger {
  final EnvironmentConfig _config;
  
  SentryLogger(this._config);
  
  @override
  void info(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[INFO] $message ${data != null ? data.toString() : ''}');
    }
    
    breadcrumb(message, data: data);
  }
  
  @override
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[WARN] $message ${error != null ? '- Error: $error' : ''} ${data != null ? data.toString() : ''}');
    }
    
    if (_config.crashReportingEnabled) {
      Sentry.captureMessage(
        message,
        level: SentryLevel.warning,
        withScope: (scope) {
          if (data != null) {
            scope.setContexts('data', data);
          }
          if (error != null) {
            scope.setTag('error_type', error.runtimeType.toString());
          }
        },
      );
    }
  }
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[ERROR] $message ${error != null ? '- Error: $error' : ''} ${data != null ? data.toString() : ''}');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
    
    if (_config.crashReportingEnabled) {
      Sentry.captureException(
        error ?? message,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (data != null) {
            scope.setContexts('data', data);
          }
          scope.setTag('error_source', 'app_logger');
        },
      );
    }
  }
  
  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    if (_config.crashReportingEnabled) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        data: data,
        timestamp: DateTime.now(),
      ));
    }
  }
}

/// Debug logger for development
class DebugLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[INFO] $message ${data != null ? data.toString() : ''}');
    }
  }
  
  @override
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[WARN] $message ${error != null ? '- Error: $error' : ''} ${data != null ? data.toString() : ''}');
    }
  }
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[ERROR] $message ${error != null ? '- Error: $error' : ''} ${data != null ? data.toString() : ''}');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }
  
  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('[BREADCRUMB] $message ${data != null ? data.toString() : ''}');
    }
  }
}

/// No-op logger for testing
class NoOpLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?>? data}) {}
  
  @override
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {}
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {}
  
  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {}
}

/// Factory for creating logger instances
class LoggerFactory {
  static AppLogger? _instance;
  
  static AppLogger get instance {
    if (_instance == null) {
      throw StateError('LoggerFactory not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  /// Initialize logger with environment config
  static void initialize(EnvironmentConfig config) {
    if (config.crashReportingEnabled) {
      _instance = SentryLogger(config);
    } else {
      _instance = DebugLogger();
    }
  }
  
  /// Initialize with specific logger (for testing)
  static void initializeWith(AppLogger logger) {
    _instance = logger;
  }
  
  /// Reset factory (for testing)
  static void reset() {
    _instance = null;
  }
}
