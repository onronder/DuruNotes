import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log levels for the application
enum LogLevel { debug, info, warning, error }

/// Application logger interface
abstract class AppLogger {
  void debug(String message, {Map<String, dynamic>? data});
  void info(String message, {Map<String, dynamic>? data});
  void warning(String message, {Map<String, dynamic>? data});
  void warn(String message, {Map<String, dynamic>? data});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  });
  void breadcrumb(String message, {Map<String, dynamic>? data});
  Future<void> flush();
}

/// Console logger implementation
class ConsoleLogger implements AppLogger {
  const ConsoleLogger({LogLevel minLevel = LogLevel.debug})
    : _minLevel = minLevel;
  final LogLevel _minLevel;

  bool _shouldLog(LogLevel level) => level.index >= _minLevel.index;

  void _log(
    String level,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = (data != null && data.isNotEmpty)
        ? ' | DATA: ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
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
      debugPrint(logMessage);
      if (error != null) debugPrint('ERROR: $error');
      if (stackTrace != null) debugPrint('STACK: $stackTrace');
    }
  }

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
  void warn(String message, {Map<String, dynamic>? data}) =>
      warning(message, data: data);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
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
    // No buffering in console logger
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
  void warn(String message, {Map<String, dynamic>? data}) {}
  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}
  @override
  Future<void> flush() async {}
}

/// Logger factory to create a global logger instance
class LoggerFactory {
  static AppLogger? _instance;
  static void initialize({
    LogLevel minLevel = LogLevel.debug,
    bool enabled = true,
  }) {
    _instance = enabled
        ? ConsoleLogger(minLevel: minLevel)
        : const NoOpLogger();
  }

  static AppLogger get instance => _instance ?? const ConsoleLogger();
}

/// Global logger instance for easy access - DEPRECATED
/// Use loggerProvider from infrastructure_providers.dart instead
