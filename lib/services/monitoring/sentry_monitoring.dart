import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry/sentry.dart' show SentryFeedback;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced Sentry monitoring service with breadcrumbs and performance tracking
class SentryMonitoringService {
  static final SentryMonitoringService _instance =
      SentryMonitoringService._internal();
  factory SentryMonitoringService() => _instance;
  SentryMonitoringService._internal();

  final _logger = LoggerFactory.instance;
  final _breadcrumbQueue = <Breadcrumb>[];
  final _transactionStack = <ISentrySpan>[];
  final _spanOperations = <ISentrySpan, String>{};

  // Configuration
  static const int maxBreadcrumbs = 100;
  static const double traceSampleRate =
      1.0; // 100% in debug, should be lower in production
  static const double profilesSampleRate = 1.0;

  // Device and app info cache
  Map<String, dynamic>? _deviceContext;
  Map<String, dynamic>? _appContext;

  /// Initialize Sentry with enhanced configuration
  static Future<void> initialize({
    required String dsn,
    required String environment,
  }) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;

        // Performance monitoring
        options.tracesSampleRate = kDebugMode ? traceSampleRate : 0.2;
        options.profilesSampleRate = kDebugMode ? profilesSampleRate : 0.1;

        // Enhanced error capture
        options.attachStacktrace = true;
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;

        // Breadcrumb configuration
        options.maxBreadcrumbs = maxBreadcrumbs;
        options.enableAutoSessionTracking = true;
        options.autoSessionTrackingInterval = const Duration(seconds: 30);

        // Release tracking
        options.release = 'duru-notes@1.0.0';
        options.dist = '1';

        // Before send callback for filtering
        options.beforeSend = (event, hint) async {
          // Filter out certain errors in production
          if (!kDebugMode) {
            if (_shouldFilterError(event)) {
              return null;
            }
          }

          // Enhance event with additional context
          event = await _enhanceEvent(event);

          return event;
        };

        // Before breadcrumb callback
        options.beforeBreadcrumb = (breadcrumb, hint) {
          // Filter sensitive information
          breadcrumb = _sanitizeBreadcrumb(breadcrumb);
          return breadcrumb;
        };
      },
      appRunner: () async {
        // Initialize service after Sentry
        await _instance._initialize();
      },
    );
  }

  Future<void> _initialize() async {
    // Gather device and app context
    await _gatherDeviceContext();
    await _gatherAppContext();

    // Set initial user context
    await _setUserContext();

    // Set global tags
    _setGlobalTags();

    _logger.info('Sentry monitoring initialized');
  }

  /// Gather device context information
  Future<void> _gatherDeviceContext() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceContext = {
          'model': iosInfo.model,
          'system_version': iosInfo.systemVersion,
          'name': iosInfo.name,
          'identifier': iosInfo.identifierForVendor,
          'is_physical': iosInfo.isPhysicalDevice,
        };
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceContext = {
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'android_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'is_physical': androidInfo.isPhysicalDevice,
        };
      }

      // Add to Sentry context
      if (_deviceContext != null) {
        Sentry.configureScope((scope) {
          scope.setContexts('device_info', _deviceContext!);
        });
      }
    } catch (e) {
      _logger.warning(
        'Failed to gather device context',
        data: {'error': e.toString()},
      );
    }
  }

  /// Gather app context information
  Future<void> _gatherAppContext() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appContext = {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      };

      // Add to Sentry context
      if (_appContext != null) {
        Sentry.configureScope((scope) {
          scope.setContexts('app_info', _appContext!);
        });
      }
    } catch (e) {
      _logger.warning(
        'Failed to gather app context',
        data: {'error': e.toString()},
      );
    }
  }

  /// Set user context
  Future<void> _setUserContext({
    String? userId,
    String? email,
    String? username,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(
        SentryUser(
          id: userId ?? 'anonymous',
          email: email,
          username: username,
          ipAddress: '{{auto}}',
        ),
      );
    });
  }

  /// Set global tags
  void _setGlobalTags() {
    Sentry.configureScope((scope) {
      scope.setTag('platform', defaultTargetPlatform.toString());
      scope.setTag('debug_mode', kDebugMode.toString());
      scope.setTag('locale', PlatformDispatcher.instance.locale.toString());
    });
  }

  /// Should filter this error
  static bool _shouldFilterError(SentryEvent event) {
    // Filter network errors in offline mode
    if (event.throwable?.toString().contains('SocketException') ?? false) {
      return true;
    }

    // Filter common Flutter errors
    if (event.message?.formatted?.contains(
          'setState() called after dispose()',
        ) ??
        false) {
      return true;
    }

    return false;
  }

  /// Enhance event with additional context
  static Future<SentryEvent> _enhanceEvent(SentryEvent event) async {
    // Add connectivity status
    try {
      final connectivity = await Connectivity().checkConnectivity();
      event.contexts['connectivity'] = {
        'type': connectivity.toString(),
        'is_connected': connectivity != ConnectivityResult.none,
      };
    } catch (_) {}

    // Add memory info
    event.contexts['memory'] = {'used_memory': _getUsedMemory()};

    return event;
  }

  /// Sanitize breadcrumb to remove sensitive data
  static Breadcrumb? _sanitizeBreadcrumb(Breadcrumb? breadcrumb) {
    if (breadcrumb == null) return null;

    // Remove sensitive data from breadcrumb
    if (breadcrumb.data != null) {
      final sanitizedData = Map<String, dynamic>.from(breadcrumb.data!);

      // Remove password, token, etc.
      final sensitiveKeys = [
        'password',
        'token',
        'secret',
        'api_key',
        'authorization',
      ];
      for (final key in sensitiveKeys) {
        if (sanitizedData.containsKey(key)) {
          sanitizedData[key] = '[REDACTED]';
        }
      }

      return breadcrumb.copyWith(data: sanitizedData);
    }

    return breadcrumb;
  }

  static int _getUsedMemory() {
    // This is a placeholder - actual implementation would be platform specific
    return 0;
  }

  // ============================================================================
  // Breadcrumb Management
  // ============================================================================

  /// Add a navigation breadcrumb
  void addNavigationBreadcrumb({
    required String from,
    required String to,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(
      message: 'Navigation',
      category: 'navigation',
      data: {'from': from, 'to': to, ...?data},
      level: SentryLevel.info,
    );
  }

  /// Add a user action breadcrumb
  void addUserActionBreadcrumb({
    required String action,
    String? target,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(
      message: action,
      category: 'user_action',
      data: {if (target != null) 'target': target, ...?data},
      level: SentryLevel.info,
    );
  }

  /// Add a system event breadcrumb
  void addSystemBreadcrumb({
    required String event,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(
      message: event,
      category: 'system',
      data: data,
      level: SentryLevel.info,
    );
  }

  /// Add an HTTP breadcrumb
  void addHttpBreadcrumb({
    required String url,
    required String method,
    int? statusCode,
    int? responseSize,
    Duration? duration,
  }) {
    addBreadcrumb(
      message: '$method $url',
      category: 'http',
      data: {
        'url': url,
        'method': method,
        if (statusCode != null) 'status_code': statusCode,
        if (responseSize != null) 'response_size': responseSize,
        if (duration != null) 'duration_ms': duration.inMilliseconds,
      },
      level: statusCode != null && statusCode >= 400
          ? SentryLevel.error
          : SentryLevel.info,
    );
  }

  /// Add a database breadcrumb
  void addDatabaseBreadcrumb({
    required String operation,
    String? table,
    int? affectedRows,
    Duration? duration,
  }) {
    addBreadcrumb(
      message: 'Database: $operation',
      category: 'database',
      data: {
        'operation': operation,
        if (table != null) 'table': table,
        if (affectedRows != null) 'affected_rows': affectedRows,
        if (duration != null) 'duration_ms': duration.inMilliseconds,
      },
      level: SentryLevel.info,
    );
  }

  /// Add a custom breadcrumb
  void addBreadcrumb({
    required String message,
    required String category,
    Map<String, dynamic>? data,
    SentryLevel? level,
  }) {
    final breadcrumb = Breadcrumb(
      message: message,
      category: category,
      data: data,
      level: level ?? SentryLevel.info,
      timestamp: DateTime.now(),
    );

    // Add to Sentry
    Sentry.addBreadcrumb(breadcrumb);

    // Keep local copy for debugging
    _breadcrumbQueue.add(breadcrumb);
    if (_breadcrumbQueue.length > maxBreadcrumbs) {
      _breadcrumbQueue.removeAt(0);
    }
  }

  // ============================================================================
  // Performance Tracking
  // ============================================================================

  /// Start a performance transaction
  ISentrySpan startTransaction({
    required String name,
    required String operation,
    Map<String, dynamic>? data,
  }) {
    final transaction = Sentry.startTransaction(name, operation);
    _spanOperations[transaction] = name;

    // Add custom data
    if (data != null) {
      data.forEach((key, value) {
        transaction.setData(key, value);
      });
    }

    // Track in stack
    _transactionStack.add(transaction);

    // Add breadcrumb
    addBreadcrumb(
      message: 'Transaction started: $name',
      category: 'performance',
      data: {'operation': operation, ...?data},
    );

    return transaction;
  }

  /// Start a child span
  ISentrySpan startSpan({
    required String operation,
    String? description,
    ISentrySpan? parent,
  }) {
    final parentSpan = parent ?? _transactionStack.lastOrNull;

    if (parentSpan == null) {
      // Create a new transaction if no parent
      return startTransaction(name: operation, operation: operation);
    }

    final span = parentSpan.startChild(operation, description: description);
    _spanOperations[span] = description ?? operation;
    return span;
  }

  /// Finish a span or transaction
  void finishSpan(ISentrySpan span, {SpanStatus? status}) {
    span.status = status ?? const SpanStatus.ok();
    span.finish();

    // Remove from stack if it's a transaction
    _transactionStack.remove(span);

    // Add breadcrumb
    addBreadcrumb(
      message: 'Span finished: ${_spanOperations[span] ?? 'unknown'}',
      category: 'performance',
      data: {
        'status': span.status?.toString(),
        'duration_ms': span.endTimestamp != null && span.startTimestamp != null
            ? span.endTimestamp!.difference(span.startTimestamp).inMilliseconds
            : null,
      },
    );

    _spanOperations.remove(span);
  }

  /// Measure an async operation
  Future<T> measureAsync<T>({
    required String operation,
    required Future<T> Function() task,
    Map<String, dynamic>? data,
  }) async {
    final span = startSpan(operation: operation);

    try {
      final result = await task();
      finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (e) {
      finishSpan(span, status: const SpanStatus.internalError());
      rethrow;
    }
  }

  /// Measure a sync operation
  T measureSync<T>({
    required String operation,
    required T Function() task,
    Map<String, dynamic>? data,
  }) {
    final span = startSpan(operation: operation);

    try {
      final result = task();
      finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (e) {
      finishSpan(span, status: const SpanStatus.internalError());
      rethrow;
    }
  }

  // ============================================================================
  // Error Reporting
  // ============================================================================

  /// Report an error with context
  Future<SentryId> reportError({
    required dynamic error,
    required StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? extra,
    SentryLevel? level,
    String? transaction,
  }) async {
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        // Add message
        if (message != null) {
          scope.setTag('error_message', message);
        }

        // Add extra context
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }

        // Set level
        if (level != null) {
          scope.level = level;
        }

        // Set transaction
        if (transaction != null) {
          scope.transaction = transaction;
        }

        // Add recent breadcrumbs
        for (final breadcrumb in _breadcrumbQueue.take(20)) {
          scope.addBreadcrumb(breadcrumb);
        }
      },
    );
    return sentryId;
  }

  /// Report a message
  Future<SentryId> reportMessage({
    required String message,
    SentryLevel? level,
    Map<String, dynamic>? extra,
  }) async {
    final sentryId = await Sentry.captureMessage(
      message,
      level: level ?? SentryLevel.info,
      withScope: (scope) {
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
      },
    );
    return sentryId;
  }

  /// Report user feedback
  Future<void> reportUserFeedback({
    required String message,
    String? email,
    String? name,
    SentryId? eventId,
  }) async {
    final feedback = SentryFeedback(
      message: message,
      contactEmail: email,
      name: name,
      associatedEventId: eventId,
    );

    await Sentry.captureFeedback(feedback);
  }

  /// Clear user context
  Future<void> clearUserContext() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Get recent breadcrumbs for debugging
  List<Breadcrumb> getRecentBreadcrumbs({int count = 20}) {
    return _breadcrumbQueue.take(count).toList();
  }
}

/// Sentry monitoring provider
final sentryMonitoringProvider = Provider<SentryMonitoringService>((ref) {
  return SentryMonitoringService();
});

/// Extension for easy error reporting
extension SentryErrorExtension on Object {
  Future<void> reportToSentry({
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? extra,
  }) async {
    await SentryMonitoringService().reportError(
      error: this,
      stackTrace: stackTrace,
      message: message,
      extra: extra,
    );
  }
}
