import 'dart:math';

import 'package:duru_notes_app/core/config/environment_config.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade analytics service interface
abstract class AnalyticsService {
  /// Track an event with properties
  void event(String name, {Map<String, Object?> props = const {}});
  
  /// Track screen view
  void screen(String name, {Map<String, Object?> props = const {}});
  
  /// Set user identifier
  void setUser(String? userId);
  
  /// Track funnel events
  void funnelEvent(String funnelName, String stepName, {Map<String, Object?> props = const {}});
}

/// Sentry-based analytics implementation
class SentryAnalytics implements AnalyticsService {
  final EnvironmentConfig _config;
  final AppLogger _logger;
  
  SentryAnalytics(this._config, this._logger);

  bool get _enabled => _config.analyticsEnabled && _shouldSample();
  
  bool _shouldSample() {
    return Random().nextDouble() <= _config.analyticsSamplingRate;
  }

  @override
  void event(String name, {Map<String, Object?> props = const {}}) {
    if (!_enabled) return;
    
    try {
      final sanitizedProps = _sanitizeProperties(props);
      
      if (kDebugMode) {
        _logger.info('Analytics Event: $name', data: sanitizedProps);
      }
      
      if (_config.crashReportingEnabled) {
        Sentry.captureMessage(
          '[analytics] $name',
          level: SentryLevel.info,
          withScope: (scope) {
            scope.setContexts('analytics', sanitizedProps);
            scope.setTag('event_type', 'analytics');
            scope.setTag('event_name', name);
          },
        );
      }
    } catch (e) {
      _logger.warn('Failed to track analytics event', error: e, data: {'event': name});
    }
  }

  @override
  void screen(String name, {Map<String, Object?> props = const {}}) {
    event('screen.$name', props: {...props, 'screen_name': name});
  }

  @override
  void setUser(String? userId) {
    try {
      if (_config.crashReportingEnabled) {
        Sentry.configureScope((scope) {
          scope.user = userId != null 
              ? SentryUser(id: _hashUserId(userId))
              : null;
        });
      }
    } catch (e) {
      _logger.warn('Failed to set analytics user', error: e);
    }
  }

  @override
  void funnelEvent(String funnelName, String stepName, {Map<String, Object?> props = const {}}) {
    event('funnel.$funnelName.$stepName', props: {
      ...props,
      'funnel_name': funnelName,
      'step_name': stepName,
    });
  }

  /// Sanitize properties to ensure privacy
  Map<String, Object?> _sanitizeProperties(Map<String, Object?> props) {
    final sanitized = <String, Object?>{};
    
    for (final entry in props.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip potentially sensitive keys
      if (_isSensitiveKey(key)) {
        continue;
      }
      
      // Limit string values
      if (value is String) {
        sanitized[key] = value.length > 500 ? '${value.substring(0, 497)}...' : value;
      } else if (value is num || value is bool || value == null) {
        sanitized[key] = value;
      } else {
        // Convert to string and limit length
        final stringValue = value.toString();
        sanitized[key] = stringValue.length > 100 ? '${stringValue.substring(0, 97)}...' : stringValue;
      }
    }
    
    return sanitized;
  }

  /// Check if a key contains potentially sensitive information
  bool _isSensitiveKey(String key) {
    final sensitivePatterns = [
      'password', 'token', 'secret', 'key', 'auth',
      'email', 'phone', 'address', 'name', 'id',
      'content', 'message', 'note', 'text'
    ];
    
    final lowerKey = key.toLowerCase();
    return sensitivePatterns.any((pattern) => lowerKey.contains(pattern));
  }

  /// Hash user ID for privacy
  String _hashUserId(String userId) {
    // Simple hash for privacy - in production use proper hashing
    return userId.hashCode.abs().toString();
  }
}

/// No-op analytics for development/testing
class NoOpAnalytics implements AnalyticsService {
  @override
  void event(String name, {Map<String, Object?> props = const {}}) {
    if (kDebugMode) {
      print('[ANALYTICS] Event: $name with props: $props');
    }
  }

  @override
  void screen(String name, {Map<String, Object?> props = const {}}) {
    if (kDebugMode) {
      print('[ANALYTICS] Screen: $name with props: $props');
    }
  }

  @override
  void setUser(String? userId) {
    if (kDebugMode) {
      print('[ANALYTICS] Set user: $userId');
    }
  }

  @override
  void funnelEvent(String funnelName, String stepName, {Map<String, Object?> props = const {}}) {
    if (kDebugMode) {
      print('[ANALYTICS] Funnel: $funnelName.$stepName with props: $props');
    }
  }
}

/// Factory for creating analytics instances
class AnalyticsFactory {
  static AnalyticsService? _instance;
  
  static AnalyticsService get instance {
    if (_instance == null) {
      throw StateError('AnalyticsFactory not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  /// Initialize analytics with environment config
  static void initialize(EnvironmentConfig config, AppLogger logger) {
    if (config.analyticsEnabled) {
      _instance = SentryAnalytics(config, logger);
    } else {
      _instance = NoOpAnalytics();
    }
  }
  
  /// Initialize with specific analytics service (for testing)
  static void initializeWith(AnalyticsService analytics) {
    _instance = analytics;
  }
  
  /// Reset factory (for testing)
  static void reset() {
    _instance = null;
  }
}

/// Predefined analytics events for consistency
class AnalyticsEvents {
  // Import events
  static const String importSuccess = 'import.success';
  static const String importError = 'import.error';
  static const String importCancelled = 'import.cancelled';
  
  // Note events
  static const String noteCreate = 'note.create';
  static const String noteEdit = 'note.edit';
  static const String noteDelete = 'note.delete';
  static const String noteSearch = 'note.search';
  
  // Auth events
  static const String authLogin = 'auth.login';
  static const String authLogout = 'auth.logout';
  static const String authError = 'auth.error';
  
  // Settings events
  static const String settingsOpen = 'settings.open';
  static const String helpOpen = 'settings.help_opened';
  static const String cacheReset = 'settings.cache_reset';
  static const String privacyPolicyOpen = 'settings.privacy_policy_opened';
}

/// Common analytics properties
class AnalyticsProperties {
  static const String duration = 'duration_ms';
  static const String fileSize = 'file_size';
  static const String count = 'count';
  static const String error = 'error';
  static const String type = 'type';
  static const String success = 'success';
  static const String total = 'total';
  static const String errors = 'errors';
}

/// Funnel definitions for tracking user flows
class AnalyticsFunnels {
  static const String onboarding = 'onboarding';
  static const String noteCreation = 'note_creation';
  static const String import = 'import';
  static const String sync = 'sync';
}
