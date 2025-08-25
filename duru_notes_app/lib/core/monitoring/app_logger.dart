import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Log levels for the application
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Abstract logger interface for the application
abstract class AppLogger {
  /// Log an informational message
  void info(String message, {Map<String, Object?>? data});
  
  /// Log a warning message
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data});
  
  /// Log an error message
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data});
  
  /// Log a debug message (only in debug mode)
  void debug(String message, {Map<String, Object?>? data});
  
  /// Add a breadcrumb for debugging context
  void breadcrumb(String message, {Map<String, Object?>? data, String? category});
  
  /// Set user context for logging
  void setUser(String? userId, {String? email, Map<String, Object?>? extra});
  
  /// Clear user context
  void clearUser();
  
  /// Add extra context to all logs
  void setContext(String key, Map<String, Object?> context);
  
  /// Remove context
  void removeContext(String key);
}

/// Sentry implementation of the app logger
class SentryLogger implements AppLogger {

  
  @override
  void info(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('ℹ️ [INFO] $message');
      if (data != null) print('   Data: $data');
    }
    
    breadcrumb(message, data: data, category: 'info');
  }
  
  @override
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('⚠️ [WARN] $message');
      if (error != null) print('   Error: $error');
      if (data != null) print('   Data: $data');
    }
    
    Sentry.captureMessage(
      message,
      level: SentryLevel.warning,
      withScope: (scope) {
        if (data != null) {
          scope.setContexts('warning_data', data);
        }
        if (error != null) {
          scope.setTag('error_type', error.runtimeType.toString());
        }
      },
    );
    
    breadcrumb(message, data: data, category: 'warning');
  }
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('❌ [ERROR] $message');
      if (error != null) print('   Error: $error');
      if (stackTrace != null) print('   Stack: $stackTrace');
      if (data != null) print('   Data: $data');
    }
    
    Sentry.captureException(
      error ?? Exception(message),
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = SentryLevel.error;
        scope.setTag('error_context', 'app_logger');
        if (data != null) {
          scope.setContexts('error_data', data);
        }
      },
    );
    
    breadcrumb(message, data: data, category: 'error');
  }
  
  @override
  void debug(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('🐛 [DEBUG] $message');
      if (data != null) print('   Data: $data');
    }
    
    // Only add breadcrumb in debug mode to avoid noise
    if (kDebugMode) {
      breadcrumb(message, data: data, category: 'debug');
    }
  }
  
  @override
  void breadcrumb(String message, {Map<String, Object?>? data, String? category}) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        data: data,
        category: category ?? 'default',
        level: SentryLevel.info,
        timestamp: DateTime.now(),
      ),
    );
  }
  
  @override
  void setUser(String? userId, {String? email, Map<String, Object?>? extra}) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        email: email,
        data: extra,
      ));
    });
    
    if (kDebugMode) {
      print('👤 [USER] Set user context: $userId');
    }
  }
  
  @override
  void clearUser() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
    
    if (kDebugMode) {
      print('👤 [USER] Cleared user context');
    }
  }
  
  @override
  void setContext(String key, Map<String, Object?> context) {
    Sentry.configureScope((scope) {
      scope.setContexts(key, context);
    });
    
    if (kDebugMode) {
      print('📝 [CONTEXT] Set context "$key": $context');
    }
  }
  
  @override
  void removeContext(String key) {
    Sentry.configureScope((scope) {
      scope.removeContexts(key);
    });
    
    if (kDebugMode) {
      print('📝 [CONTEXT] Removed context "$key"');
    }
  }
}

/// Console-only logger for development/testing
class ConsoleLogger implements AppLogger {

  
  @override
  void info(String message, {Map<String, Object?>? data}) {
    print('ℹ️ [INFO] $message');
    if (data != null) print('   Data: $data');
  }
  
  @override
  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    print('⚠️ [WARN] $message');
    if (error != null) print('   Error: $error');
    if (data != null) print('   Data: $data');
  }
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) {
    print('❌ [ERROR] $message');
    if (error != null) print('   Error: $error');
    if (stackTrace != null) print('   Stack: $stackTrace');
    if (data != null) print('   Data: $data');
  }
  
  @override
  void debug(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) {
      print('🐛 [DEBUG] $message');
      if (data != null) print('   Data: $data');
    }
  }
  
  @override
  void breadcrumb(String message, {Map<String, Object?>? data, String? category}) {
    if (kDebugMode) {
      print('🍞 [BREADCRUMB] [$category] $message');
      if (data != null) print('   Data: $data');
    }
  }
  
  @override
  void setUser(String? userId, {String? email, Map<String, Object?>? extra}) {
    print('👤 [USER] Set user context: $userId (email: $email)');
  }
  
  @override
  void clearUser() {
    print('👤 [USER] Cleared user context');
  }
  
  @override
  void setContext(String key, Map<String, Object?> context) {
    print('📝 [CONTEXT] Set context "$key": $context');
  }
  
  @override
  void removeContext(String key) {
    print('📝 [CONTEXT] Removed context "$key"');
  }
}

/// Logger factory to create the appropriate logger instance
class LoggerFactory {
  static AppLogger? _instance;
  
  /// Get the singleton logger instance
  static AppLogger get instance {
    return _instance ?? _createLogger();
  }
  
  /// Initialize the logger with the specified type
  static void initialize({bool useSentry = true}) {
    if (useSentry) {
      _instance = SentryLogger();
    } else {
      _instance = ConsoleLogger();
    }
  }
  
  /// Create the appropriate logger based on environment
  static AppLogger _createLogger() {
    // Default to console logger if not explicitly initialized
    _instance = ConsoleLogger();
    return _instance!;
  }
  
  /// Reset the logger instance (useful for testing)
  static void reset() {
    _instance = null;
  }
}

/// Global logger instance for convenience
AppLogger get logger => LoggerFactory.instance;
