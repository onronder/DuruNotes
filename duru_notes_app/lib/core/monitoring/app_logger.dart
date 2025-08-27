import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log levels for the application
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Application logger interface
abstract class AppLogger {
  /// Log a debug message
  void debug(String message, {Map<String, dynamic>? data});
  
  /// Log an info message
  void info(String message, {Map<String, dynamic>? data});
  
  /// Log a warning message
  void warning(String message, {Map<String, dynamic>? data});
  
  /// Log a warning message (alias for warning)
  void warn(String message, {Map<String, dynamic>? data}) => warning(message, data: data);
  
  /// Log an error message
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data});
  
  /// Log a breadcrumb (for debugging user flows)
  void breadcrumb(String message, {Map<String, dynamic>? data});
  
  /// Flush any pending logs
  Future<void> flush();
}

/// Console logger implementation
class ConsoleLogger implements AppLogger {
  final LogLevel _minLevel;
  
  const ConsoleLogger({LogLevel minLevel = LogLevel.debug}) : _minLevel = minLevel;
  
  @override
  void debug(String message, {Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.debug)) {
      _log('DEBUG', message, data: data);
    }
  }
  
  @override
  void info(String message, {Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.info)) {
      _log('INFO', message, data: data);
    }
  }
  
  @override
  void warning(String message, {Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.warning)) {
      _log('WARNING', message, data: data);
    }
  }
  
  @override
  void warn(String message, {Map<String, dynamic>? data}) => warning(message, data: data);
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.error)) {
      _log('ERROR', message, data: data, error: error, stackTrace: stackTrace);
    }
  }
  
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.debug)) {
      _log('BREADCRUMB', message, data: data);
    }
  }
  
  @override
  Future<void> flush() async {
    // Console logging doesn't need flushing
  }
  
  bool _shouldLog(LogLevel level) {
    return level.index >= _minLevel.index;
  }
  
  void _log(String level, String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = data?.isNotEmpty == true 
        ? ' | DATA: ${data!.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    
    final logMessage = '[$timestamp] $level: $message$dataStr';
    
    if (kDebugMode) {
      developer.log(
        logMessage,
        name: 'DuruNotes',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      print(logMessage);
      if (error != null) {
        print('ERROR: $error');
      }
      if (stackTrace != null) {
        print('STACK: $stackTrace');
      }
    }
  }
}

/// No-op logger for production when logging is disabled
class NoOpLogger implements AppLogger {
  const NoOpLogger();
  
  @override
  void debug(String message, {Map<String, dynamic>? data}) {}
  
  @override
  void info(String message, {Map<String, dynamic>? data}) {}
  
  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
  
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {}
  
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}
  
  @override
  Future<void> flush() async {}
}

/// Logger factory for creating logger instances
class LoggerFactory {
  static AppLogger? _instance;
  
  static void initialize({LogLevel minLevel = LogLevel.debug, bool enabled = true}) {
    if (enabled) {
      _instance = ConsoleLogger(minLevel: minLevel);
    } else {
      _instance = const NoOpLogger();
    }
  }
  
  static AppLogger get instance {
    return _instance ?? const ConsoleLogger();
  }
}

/// Global logger instance for easy access
final logger = LoggerFactory.instance;