import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Configuration and initialization for Sentry error tracking
class SentryConfig {
  static bool _isInitialized = false;

  /// Initialize Sentry for error tracking and performance monitoring
  static Future<void> initialize() async {
    if (_isInitialized) {
      LoggerFactory.instance.warning('Sentry already initialized');
      return;
    }

    final config = EnvironmentConfig.current;

    // Skip Sentry in debug mode unless explicitly enabled
    if (kDebugMode && !config.crashReportingEnabled) {
      LoggerFactory.instance.info('Sentry disabled in debug mode');
      return;
    }

    // Check if Sentry DSN is configured
    if (config.sentryDsn == null || config.sentryDsn!.isEmpty) {
      LoggerFactory.instance.warning('Sentry DSN not configured');
      return;
    }

    try {
      // Get package info for release tracking
      final packageInfo = await PackageInfo.fromPlatform();

      await SentryFlutter.init((options) {
        options.dsn = config.sentryDsn;

        // Environment and release tracking
        options.environment = config.currentEnvironment.name;
        options.release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.dist = packageInfo.buildNumber;

        // Performance monitoring
        options.tracesSampleRate = config.sentryTracesSampleRate;
        options.enableAutoPerformanceTracing = true;

        // Session tracking
        options.enableAutoSessionTracking = config.enableAutoSessionTracking;

        // Error handling
        options.attachStacktrace = true;
        options.attachThreads = true;
        options.attachScreenshot = !kReleaseMode; // Only in debug/profile
        options.attachViewHierarchy = !kReleaseMode;

        // Privacy
        options.sendDefaultPii = config.sendDefaultPii;

        // Breadcrumbs
        options.maxBreadcrumbs = 100;
        options.enableAutoNativeBreadcrumbs = true;
        options.enableAppLifecycleBreadcrumbs = true;

        // Debug options
        options.debug = kDebugMode;
        options.diagnosticLevel = kDebugMode
            ? SentryLevel.debug
            : SentryLevel.error;

        // Before send callback for filtering
        options.beforeSend = (event, hint) async {
          // Filter out certain errors in production
          if (kReleaseMode) {
            // Don't send network timeouts in production (too noisy)
            if (event.throwable?.toString().contains('TimeoutException') ??
                false) {
              return null;
            }

            // Don't send cancelled operations
            if (event.throwable?.toString().contains('cancelled') ?? false) {
              return null;
            }
          }

          // Add custom tags
          event = event.copyWith(
            tags: {
              ...?event.tags,
              'app.environment': config.currentEnvironment.name,
              'app.debug_mode': kDebugMode.toString(),
              'app.version': packageInfo.version,
              'app.build': packageInfo.buildNumber,
            },
          );

          // Log to our logger as well
          LoggerFactory.instance.error(
            'Sentry capturing exception',
            error: event.throwable,
            data: {'level': event.level?.name, 'tags': event.tags},
          );

          return event;
        };

        // Integrations
        options.enableDartSymbolication = true;
        options.considerInAppFramesByDefault = true;
      });

      // Configure scope with user and additional context
      await Sentry.configureScope((scope) async {
        // Set user if authenticated
        final userId = EnvironmentConfig
            .current
            .supabaseUrl; // Replace with actual user ID when available
        scope.setUser(
          SentryUser(
            id: userId,
            // Don't set email/username unless sendDefaultPii is true
          ),
        );

        // Set app context
        scope.setContexts('app', {
          'environment': config.currentEnvironment.name,
          'debug_mode': kDebugMode,
          'crash_reporting': config.crashReportingEnabled,
          'analytics': config.analyticsEnabled,
        });

        // Set device context
        scope.setContexts('device', {
          'platform': defaultTargetPlatform.name,
          'debug_mode': kDebugMode,
        });
      });

      _isInitialized = true;

      LoggerFactory.instance.info(
        'Sentry initialized successfully',
        data: {
          'environment': config.currentEnvironment.name,
          'release': '${packageInfo.version}+${packageInfo.buildNumber}',
          'tracesSampleRate': config.sentryTracesSampleRate,
          'sessionTracking': config.enableAutoSessionTracking,
        },
      );

      // Send a test event in debug mode
      if (kDebugMode) {
        Sentry.captureMessage('Sentry initialized successfully');
      }
    } catch (e, stack) {
      LoggerFactory.instance.error(
        'Failed to initialize Sentry',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Update user context when user logs in
  static Future<void> setUser({
    required String userId,
    String? email,
    String? username,
  }) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(
        SentryUser(
          id: userId,
          email: EnvironmentConfig.current.sendDefaultPii ? email : null,
          username: EnvironmentConfig.current.sendDefaultPii ? username : null,
        ),
      );
    });
  }

  /// Clear user context when user logs out
  static Future<void> clearUser() async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Add a breadcrumb for tracking user actions
  static void addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
    SentryLevel? level,
  }) {
    if (!_isInitialized) return;

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level ?? SentryLevel.info,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Start a performance transaction
  static ISentrySpan? startTransaction(
    String name,
    String operation, {
    String? description,
  }) {
    if (!_isInitialized) return null;

    return Sentry.startTransaction(name, operation, description: description);
  }

  /// Capture an exception with additional context
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
    SentryLevel? level,
  }) async {
    if (!_isInitialized) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }

        if (tags != null) {
          tags.forEach((key, value) {
            scope.setTag(key, value);
          });
        }

        if (level != null) {
          scope.level = level;
        }
      },
    );
  }
}
