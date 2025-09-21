import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Configuration for the application logger based on build mode and environment.
///
/// This class ensures that:
/// - Production builds only log warnings and errors
/// - Profile builds log info and above
/// - Debug builds log everything
/// - Sensitive data is never logged in production
class LoggerConfig {
  /// Initializes the logger based on the current build mode and environment.
  static void initialize(EnvironmentConfig config) {
    if (kReleaseMode) {
      // Production: Only warnings and errors, no sensitive data
      LoggerFactory.initialize(minLevel: LogLevel.warning);

      // In production, we could also send logs to a remote service
      if (config.analyticsEnabled) {
        _initializeRemoteLogging();
      }
    } else if (kProfileMode) {
      // Profile mode: Info and above for performance testing
      LoggerFactory.initialize(minLevel: LogLevel.info);
    } else {
      // Debug mode: Everything for development
      LoggerFactory.initialize();
    }

    // Log initialization
    final logger = LoggerFactory.instance;
    logger.info(
      'Logger initialized',
      data: {
        'buildMode': _getBuildMode(),
        'environment': config.environment.name,
        'minLevel': _getMinLevel().name,
      },
    );
  }

  /// Returns the current build mode as a string.
  static String _getBuildMode() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  /// Returns the minimum log level based on build mode.
  static LogLevel _getMinLevel() {
    if (kReleaseMode) return LogLevel.warning;
    if (kProfileMode) return LogLevel.info;
    return LogLevel.debug;
  }

  /// Initializes remote logging for production (placeholder for future implementation).
  static void _initializeRemoteLogging() {
    // This could be integrated with Sentry, Crashlytics, or a custom logging service
    // For now, this is a placeholder
  }

  /// Sanitizes sensitive data from log messages in production.
  static Map<String, dynamic>? sanitizeData(Map<String, dynamic>? data) {
    if (data == null || !kReleaseMode) return data;

    // List of sensitive keys to redact
    const sensitiveKeys = [
      'password',
      'token',
      'secret',
      'key',
      'authorization',
      'cookie',
      'session',
      'credit_card',
      'ssn',
      'api_key',
    ];

    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // Check if key contains sensitive words
      var isSensitive = false;
      for (final sensitiveKey in sensitiveKeys) {
        if (key.contains(sensitiveKey)) {
          isSensitive = true;
          break;
        }
      }

      if (isSensitive) {
        // Redact sensitive values
        if (value is String && value.isNotEmpty) {
          sanitized[entry.key] = '***REDACTED***';
        } else {
          sanitized[entry.key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        // Recursively sanitize nested maps
        sanitized[entry.key] = sanitizeData(value);
      } else if (value is List) {
        // Sanitize lists
        sanitized[entry.key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return sanitizeData(item);
          }
          return item;
        }).toList();
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }
}

/// Extension to add production-safe logging methods.
extension ProductionLogger on AppLogger {
  /// Logs debug information that will be stripped in production.
  void debugProduction(String message, {Map<String, dynamic>? data}) {
    if (!kReleaseMode) {
      debug(message, data: data);
    }
  }

  /// Logs info with sanitized data.
  void infoSafe(String message, {Map<String, dynamic>? data}) {
    info(message, data: LoggerConfig.sanitizeData(data));
  }

  /// Logs warning with sanitized data.
  void warningSafe(String message, {Map<String, dynamic>? data}) {
    warning(message, data: LoggerConfig.sanitizeData(data));
  }

  /// Logs error with sanitized data.
  void errorSafe(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    this.error(
      message,
      error: error,
      stackTrace: stackTrace,
      data: LoggerConfig.sanitizeData(data),
    );
  }

  /// Logs a breadcrumb that will be stripped in production.
  void breadcrumbProduction(String message, {Map<String, dynamic>? data}) {
    if (!kReleaseMode) {
      breadcrumb(message, data: data);
    }
  }
}
