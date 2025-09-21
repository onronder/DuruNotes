import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';

export 'analytics_factory.dart' show AnalyticsFactory, analytics;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry implementation of the analytics service
class SentryAnalytics extends AnalyticsService {
  SentryAnalytics({
    required AppLogger logger,
    required EnvironmentConfig config,
  })  : _logger = logger,
        _config = config;

  final Map<String, DateTime> _timingEvents = {};
  String? _currentUserId;
  String? _sessionId;
  String? _appVersion;
  final AppLogger _logger;
  final EnvironmentConfig _config;

  /// Initialize the analytics service
  Future<void> initialize() async {
    try {
      // Generate session ID
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      _logger.info(
        'SentryAnalytics initialized',
        data: {
          'sessionId': _sessionId,
          'appVersion': _appVersion,
          'analyticsEnabled': _config.analyticsEnabled,
          'samplingRate': _config.analyticsSamplingRate,
        },
      );
    } catch (e) {
      _logger.error('Failed to initialize SentryAnalytics', error: e);
    }
  }

  /// Check if analytics is enabled and should be sampled
  bool get _isEnabled {
    return _config.analyticsEnabled;
  }

  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    if (!_isEnabled) return;

    try {
      final eventData = {
        ...(properties ?? {}),
        AnalyticsProperties.sessionId: _sessionId,
        AnalyticsProperties.appVersion: _appVersion,
        AnalyticsProperties.environment: _config.environment.name,
        if (_currentUserId != null) AnalyticsProperties.userId: _currentUserId,
      };

      Sentry.captureMessage(
        '[analytics] $name',
        withScope: (scope) {
          scope.setContexts('analytics_event', {
            'name': name,
            'properties': eventData,
          });
          scope.setTag('event_type', 'analytics');
          scope.setTag('analytics_event', name);
        },
      );

      _logger.breadcrumb(
        'Analytics event: $name',
        data: {'event': name, 'propertyCount': eventData.length},
      );
    } catch (e) {
      _logger.error(
        'Failed to track analytics event',
        error: e,
        data: {'eventName': name},
      );
    }
  }

  @override
  void screen(String name, {Map<String, dynamic>? properties}) {
    event(
      AnalyticsEvents.screenView,
      properties: {AnalyticsProperties.screenName: name, ...(properties ?? {})},
    );
  }

  @override
  void setUser(String? userId, {Map<String, dynamic>? properties}) {
    _currentUserId = userId;

    if (!_isEnabled) return;

    try {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId, data: properties ?? {}));
      });

      _logger.info(
        'Analytics user set',
        data: {
          'hasUserId': userId != null,
          'propertyCount': properties?.length ?? 0,
        },
      );
    } catch (e) {
      _logger.error('Failed to set analytics user', error: e);
    }
  }

  @override
  void clearUser() {
    _currentUserId = null;

    if (!_isEnabled) return;

    try {
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });

      _logger.info('Analytics user cleared');
    } catch (e) {
      _logger.error('Failed to clear analytics user', error: e);
    }
  }

  @override
  void setUserProperty(String key, Object? value) {
    if (!_isEnabled || _currentUserId == null) return;

    try {
      Sentry.configureScope((scope) {
        // For simplicity, just set as tag since user properties are complex
        if (value != null && !_isPotentialPii(key.toLowerCase())) {
          scope.setTag('user_$key', value.toString());
        }
      });
    } catch (e) {
      _logger.error(
        'Failed to set user property',
        error: e,
        data: {'property': key},
      );
    }
  }

  @override
  void startTiming(String name) {
    _timingEvents[name] = DateTime.now();

    _logger.breadcrumb('Started timing: $name');
  }

  @override
  void endTiming(String name, {Map<String, dynamic>? properties}) {
    final startTime = _timingEvents.remove(name);
    if (startTime == null) {
      _logger.warn('Attempted to end timing for non-started event: $name');
      return;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;

    event(
      'timing.$name',
      properties: {
        AnalyticsProperties.duration: duration,
        ...(properties ?? {}),
      },
    );
  }

  @override
  void funnelStep(
    String funnelName,
    String stepName, {
    Map<String, dynamic>? properties,
  }) {
    event(
      'funnel.$funnelName.$stepName',
      properties: {
        'funnel_name': funnelName,
        'step_name': stepName,
        ...(properties ?? {}),
      },
    );
  }

  @override
  void featureUsed(String featureName, {Map<String, dynamic>? properties}) {
    event(
      'feature.used',
      properties: {
        AnalyticsProperties.featureName: featureName,
        ...(properties ?? {}),
      },
    );
  }

  @override
  void engagement(
    String action, {
    String? category,
    Map<String, dynamic>? properties,
  }) {
    event(
      'engagement',
      properties: {
        AnalyticsProperties.action: action,
        if (category != null) AnalyticsProperties.category: category,
        ...(properties ?? {}),
      },
    );
  }

  @override
  void trackError(
    String error, {
    String? context,
    Map<String, dynamic>? properties,
  }) {
    event(
      AnalyticsEvents.errorOccurred,
      properties: {
        AnalyticsProperties.errorMessage: error,
        if (context != null) AnalyticsProperties.featureContext: context,
        ...(properties ?? {}),
      },
    );
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {
    if (!_isEnabled) return;

    try {
      // Set user properties in Sentry
      Sentry.configureScope((scope) {
        for (final entry in properties.entries) {
          scope.setTag(entry.key, entry.value.toString());
        }
      });
    } catch (e) {
      _logger.error('Failed to set user properties', error: e);
    }
  }

  @override
  Future<void> flush() async {
    if (!_isEnabled) return;

    try {
      await Sentry.close();
    } catch (e) {
      _logger.error('Failed to flush analytics', error: e);
    }
  }

  /// Check if a key might contain PII
  static bool _isPotentialPii(String key) {
    const piiKeys = [
      'email',
      'name',
      'phone',
      'address',
      'ip',
      'password',
      'token',
      'secret',
      'key',
    ];

    return piiKeys.any((piiKey) => key.contains(piiKey));
  }
}

/// No-op analytics implementation for when analytics is disabled
class NoOpAnalytics extends AnalyticsService {
  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void screen(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void setUser(String? userId, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void clearUser() {
    // No-op
  }

  @override
  void setUserProperty(String key, Object? value) {
    // No-op
  }

  @override
  void startTiming(String name) {
    // No-op
  }

  @override
  void endTiming(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void funnelStep(
    String funnelName,
    String stepName, {
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void featureUsed(String featureName, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void engagement(
    String action, {
    String? category,
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void trackError(
    String error, {
    String? context,
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {
    // No-op
  }

  @override
  Future<void> flush() async {
    // No-op
  }
}
