import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/analytics/analytics_sentry.dart';

/// Coordinates initialization of the analytics layer.
class AnalyticsFactory {
  static EnvironmentConfig? _config;
  static AppLogger? _logger;
  static AnalyticsService? _instance;

  /// Register dependencies required before calling [initialize].
  static void configure({
    required EnvironmentConfig config,
    required AppLogger logger,
  }) {
    _config = config;
    _logger = logger;
  }

  /// Initialize the analytics implementation based on the current config.
  static Future<AnalyticsService> initialize() async {
    final config = _config;
    final logger = _logger;

    if (config == null || logger == null) {
      throw StateError(
        'AnalyticsFactory.configure must be called before initialize',
      );
    }

    if (config.analyticsEnabled && config.isSentryConfigured) {
      final sentryAnalytics = SentryAnalytics(logger: logger, config: config);
      await sentryAnalytics.initialize();
      _instance = sentryAnalytics;
    } else {
      _instance = NoOpAnalytics();
    }

    logger.info(
      'Analytics service initialized',
      data: {
        'type': _instance.runtimeType.toString(),
        'enabled': config.analyticsEnabled,
        'sentryConfigured': config.isSentryConfigured,
      },
    );

    return _instance!;
  }

  /// Current analytics instance. A no-op implementation is returned until
  /// [initialize] completes successfully.
  static AnalyticsService get instance => _instance ??= NoOpAnalytics();

  /// Reset the cached instance (primarily for tests).
  static void reset() {
    _instance = null;
  }
}

/// Backwards-compatible accessor for modules that still read a global analytics handle.
AnalyticsService get analytics => AnalyticsFactory.instance;
