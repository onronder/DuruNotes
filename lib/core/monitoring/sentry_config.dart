import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Configuration and initialization for Sentry error tracking
class SentryConfig {
  static bool _isInitialized = false;
  static EnvironmentConfig? _environment;
  static AppLogger? _logger;

  static bool get isInitialized => _isInitialized;

  /// Inject dependencies required for initialization.
  static void configure({
    required EnvironmentConfig environment,
    required AppLogger logger,
  }) {
    _environment = environment;
    _logger = logger;
  }

  /// Initialize Sentry for error tracking and performance monitoring
  static Future<void> initialize() async {
    if (_isInitialized) {
      _logger?.warning('Sentry already initialized');
      return;
    }

    final config = _environment;
    final logger = _logger;
    if (config == null || logger == null) {
      throw StateError(
        'SentryConfig.configure must be called before initialize',
      );
    }

    // Skip Sentry in debug mode unless explicitly enabled
    if (kDebugMode && !config.crashReportingEnabled) {
      logger.info('Sentry disabled in debug mode');
      return;
    }

    // Check if Sentry DSN is configured
    if (config.sentryDsn == null || config.sentryDsn!.isEmpty) {
      logger.warning('Sentry DSN not configured');
      return;
    }

    try {
      // Get package info for release tracking
      final packageInfo = await PackageInfo.fromPlatform();

      await SentryFlutter.init((options) {
        options.dsn = config.sentryDsn;

        // Environment and release tracking
        options.environment = config.environment.name;
        options.release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.dist = packageInfo.buildNumber;

        // Performance monitoring
        options.tracesSampleRate = config.sentryTracesSampleRate;

        // CRITICAL: Auto performance tracing can cause main thread hangs on iOS
        // Disable in production or when trace rate is 0
        // See Sentry error: App Hanging (Oct 1, 2025) - dart::TimelineEventRecorder
        options.enableAutoPerformanceTracing =
            !kReleaseMode && config.sentryTracesSampleRate > 0;

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

        // PERFORMANCE FIX: Native breadcrumbs add overhead
        // Only enable in debug mode to reduce main thread blocking
        options.enableAutoNativeBreadcrumbs = kDebugMode;
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

          // Add custom tags - assign directly to instance
          event.tags?.addAll({
            'app.environment': config.environment.name,
            'app.debug_mode': kDebugMode.toString(),
            'app.version': packageInfo.version,
            'app.build': packageInfo.buildNumber,
          });

          // Log to our logger as well
          logger.error(
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

      // Configure scope with additional context
      await Sentry.configureScope((scope) async {
        // Set app context
        scope.setContexts('app', {
          'environment': config.environment.name,
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

      logger.info(
        'Sentry initialized successfully',
        data: {
          'environment': config.environment.name,
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
      logger.error('Failed to initialize Sentry', error: e, stackTrace: stack);
    }
  }

  /// Update user context when user logs in
  static Future<void> setUser({
    required String userId,
    String? email,
    String? username,
  }) async {
    if (!_isInitialized) return;
    final config = _environment;

    await Sentry.configureScope((scope) {
      scope.setUser(
        SentryUser(
          id: userId,
          email: (config?.sendDefaultPii ?? false) ? email : null,
          username: (config?.sendDefaultPii ?? false) ? username : null,
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
          // Use Contexts API instead of deprecated setExtra
          scope.setContexts('extra', extra);
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
