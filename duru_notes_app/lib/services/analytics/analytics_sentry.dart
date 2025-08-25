
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/environment_config.dart';
import '../../core/monitoring/app_logger.dart';
import 'analytics_service.dart';

/// Sentry implementation of the analytics service
class SentryAnalytics implements AnalyticsService {
  final Map<String, DateTime> _timingEvents = {};
  String? _currentUserId;
  String? _sessionId;
  String? _appVersion;
  
  /// Initialize the analytics service
  Future<void> initialize() async {
    try {
      // Generate session ID
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      
      logger.info('SentryAnalytics initialized', data: {
        'sessionId': _sessionId,
        'appVersion': _appVersion,
        'analyticsEnabled': EnvironmentConfig.analyticsEnabled,
        'samplingRate': EnvironmentConfig.analyticsSamplingRate,
      });
    } catch (e) {
      logger.error('Failed to initialize SentryAnalytics', error: e);
    }
  }
  
  /// Check if analytics is enabled and should be sampled
  bool get _isEnabled {
    return EnvironmentConfig.analyticsEnabled && 
           AnalyticsHelper.shouldSample(EnvironmentConfig.analyticsSamplingRate);
  }
  
  @override
  void event(String name, {Map<String, Object?> properties = const {}}) {
    if (!_isEnabled) return;
    
    try {
      final sanitizedProperties = AnalyticsHelper.sanitizeProperties(properties);
      final eventData = {
        ...AnalyticsHelper.getStandardProperties(),
        ...sanitizedProperties,
        AnalyticsProperties.sessionId: _sessionId,
        AnalyticsProperties.appVersion: _appVersion,
        AnalyticsProperties.environment: EnvironmentConfig.currentEnvironment.name,
        if (_currentUserId != null) AnalyticsProperties.userId: _currentUserId,
      };
      
      Sentry.captureMessage(
        '[analytics] $name',
        level: SentryLevel.info,
        withScope: (scope) {
          scope.setContexts('analytics_event', {
            'name': name,
            'properties': eventData,
          });
          scope.setTag('event_type', 'analytics');
          scope.setTag('analytics_event', name);
        },
      );
      
      logger.breadcrumb('Analytics event: $name', data: {
        'event': name,
        'propertyCount': eventData.length,
      });
    } catch (e) {
      logger.error('Failed to track analytics event', error: e, data: {
        'eventName': name,
      });
    }
  }
  
  @override
  void screen(String name, {Map<String, Object?> properties = const {}}) {
    event(AnalyticsEvents.screenView, properties: {
      AnalyticsProperties.screenName: name,
      ...properties,
    });
  }
  
  @override
  void setUser(String? userId, {Map<String, Object?> properties = const {}}) {
    _currentUserId = userId;
    
    if (!_isEnabled) return;
    
    try {
          Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        data: AnalyticsHelper.sanitizeProperties(properties),
      ));
    });
      
      logger.info('Analytics user set', data: {
        'hasUserId': userId != null,
        'propertyCount': properties.length,
      });
    } catch (e) {
      logger.error('Failed to set analytics user', error: e);
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
      
      logger.info('Analytics user cleared');
    } catch (e) {
      logger.error('Failed to clear analytics user', error: e);
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
      logger.error('Failed to set user property', error: e, data: {
        'property': key,
      });
    }
  }
  
  @override
  void startTiming(String name) {
    _timingEvents[name] = DateTime.now();
    
    logger.breadcrumb('Started timing: $name');
  }
  
  @override
  void endTiming(String name, {Map<String, Object?> properties = const {}}) {
    final startTime = _timingEvents.remove(name);
    if (startTime == null) {
      logger.warn('Attempted to end timing for non-started event: $name');
      return;
    }
    
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    
    event('timing.$name', properties: {
      AnalyticsProperties.duration: duration,
      ...properties,
    });
  }
  
  @override
  void funnelStep(String funnelName, String stepName, {Map<String, Object?> properties = const {}}) {
    event('funnel.$funnelName.$stepName', properties: {
      'funnel_name': funnelName,
      'step_name': stepName,
      ...properties,
    });
  }
  
  @override
  void featureUsed(String featureName, {Map<String, Object?> properties = const {}}) {
    event('feature.used', properties: {
      AnalyticsProperties.featureName: featureName,
      ...properties,
    });
  }
  
  @override
  void engagement(String action, {String? category, Map<String, Object?> properties = const {}}) {
    event('engagement', properties: {
      AnalyticsProperties.action: action,
      if (category != null) AnalyticsProperties.category: category,
      ...properties,
    });
  }
  
  @override
  void trackError(String error, {String? context, Map<String, Object?> properties = const {}}) {
    event(AnalyticsEvents.errorOccurred, properties: {
      AnalyticsProperties.errorMessage: error,
      if (context != null) AnalyticsProperties.featureContext: context,
      ...properties,
    });
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
class NoOpAnalytics implements AnalyticsService {
  @override
  void event(String name, {Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void screen(String name, {Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void setUser(String? userId, {Map<String, Object?> properties = const {}}) {
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
  void endTiming(String name, {Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void funnelStep(String funnelName, String stepName, {Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void featureUsed(String featureName, {Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void engagement(String action, {String? category, Map<String, Object?> properties = const {}}) {
    // No-op
  }
  
  @override
  void trackError(String error, {String? context, Map<String, Object?> properties = const {}}) {
    // No-op
  }
}

/// Analytics factory to create the appropriate analytics service
class AnalyticsFactory {
  static AnalyticsService? _instance;
  
  /// Get the singleton analytics instance
  static AnalyticsService get instance {
    return _instance ?? _createAnalytics();
  }
  
  /// Initialize the analytics service
  static Future<void> initialize() async {
    if (EnvironmentConfig.analyticsEnabled && EnvironmentConfig.isSentryConfigured) {
      final sentryAnalytics = SentryAnalytics();
      await sentryAnalytics.initialize();
      _instance = sentryAnalytics;
    } else {
      _instance = NoOpAnalytics();
    }
    
    logger.info('Analytics service initialized', data: {
      'type': _instance.runtimeType.toString(),
      'enabled': EnvironmentConfig.analyticsEnabled,
    });
  }
  
  /// Create the appropriate analytics service
  static AnalyticsService _createAnalytics() {
    // Default to no-op if not explicitly initialized
    _instance = NoOpAnalytics();
    return _instance!;
  }
  
  /// Reset the analytics instance (useful for testing)
  static void reset() {
    _instance = null;
  }
}

/// Global analytics instance for convenience
AnalyticsService get analytics => AnalyticsFactory.instance;
