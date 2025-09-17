import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Error tracking service for Quick Capture Widget
/// Integrates with Sentry for production error monitoring
class WidgetErrorTracker {
  static const String _environment = kReleaseMode ? 'production' : 'development';
  static const String _release = 'quick-capture-widget@1.0.0';
  
  // Error categories
  static const String categoryCapture = 'capture';
  static const String categorySync = 'sync';
  static const String categoryPlatform = 'platform';
  static const String categoryNetwork = 'network';
  static const String categoryValidation = 'validation';
  static const String categoryPerformance = 'performance';

  /// Initialize Sentry for widget error tracking
  static Future<void> initialize({
    required String dsn,
    bool debug = false,
  }) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.debug = debug;
        options.environment = _environment;
        options.release = _release;
        options.tracesSampleRate = 0.3; // 30% of transactions
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;
        
        // Set up performance monitoring
        options.enableAutoPerformanceTracing = true;
        
        // Configure integrations
        options.enableAutoNativeBreadcrumbs = true;
        options.enableAutoSessionTracking = true;
        options.autoSessionTrackingInterval = const Duration(seconds: 30);
        
        // Set tags
        options.beforeSend = (event, hint) async {
          event = event.copyWith(
            tags: {
              ...?event.tags,
              'component': 'quick_capture_widget',
              'platform': defaultTargetPlatform.name,
            },
          );
          return event;
        };
      },
    );
  }

  /// Capture an error with context
  static Future<void> captureError(
    dynamic error,
    StackTrace? stackTrace, {
    required String category,
    String? message,
    Map<String, dynamic>? extra,
    SentryLevel? level,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        // Set error category
        scope.setTag('error.category', category);
        
        // Set level
        if (level != null) {
          scope.level = level;
        }
        
        // Add context
        scope.setContexts('widget', {
          'category': category,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Add extra data
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
        
        // Add breadcrumb
        scope.addBreadcrumb(
          Breadcrumb(
            message: message ?? error.toString(),
            category: 'widget.$category',
            level: level ?? SentryLevel.error,
            timestamp: DateTime.now(),
            data: extra,
          ),
        );
      },
    );
  }

  /// Capture a message (non-error event)
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
    String? category,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (category != null) {
          scope.setTag('message.category', category);
        }
        
        if (extra != null) {
          extra.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
      },
    );
  }

  /// Track a performance transaction
  static ISentrySpan? startTransaction(
    String name,
    String operation, {
    Map<String, dynamic>? data,
  }) {
    final transaction = Sentry.startTransaction(
      name,
      operation,
      bindToScope: true,
    );
    
    if (data != null) {
      data.forEach((key, value) {
        transaction.setData(key, value);
      });
    }
    
    return transaction;
  }

  /// Track widget capture performance
  static Future<T> trackCapturePerformance<T>({
    required String operation,
    required Future<T> Function() task,
    Map<String, dynamic>? data,
  }) async {
    final transaction = startTransaction(
      'widget.capture.$operation',
      operation,
      data: data,
    );
    
    try {
      final result = await task();
      transaction?.status = const SpanStatus.ok();
      return result;
    } catch (error, stackTrace) {
      transaction?.status = const SpanStatus.internalError();
      transaction?.throwable = error;
      
      await captureError(
        error,
        stackTrace,
        category: categoryCapture,
        message: 'Capture operation failed: $operation',
        level: SentryLevel.error,
      );
      
      rethrow;
    } finally {
      await transaction?.finish();
    }
  }

  /// Add a breadcrumb for tracking user actions
  static void addBreadcrumb({
    required String message,
    required String category,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: 'widget.$category',
        level: level,
        timestamp: DateTime.now(),
        data: data,
      ),
    );
  }

  /// Set user context for error tracking
  static void setUserContext({
    required String userId,
    String? email,
    Map<String, dynamic>? extra,
  }) {
    Sentry.configureScope((scope) {
      scope.setUser(
        SentryUser(
          id: userId,
          email: email,
          data: extra,
        ),
      );
    });
  }

  /// Clear user context (on logout)
  static void clearUserContext() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Track widget-specific metrics
  static void trackWidgetMetrics({
    required int captureCount,
    required int errorCount,
    required Map<String, int> templateUsage,
    required Map<String, int> platformUsage,
  }) {
    Sentry.configureScope((scope) {
      scope.setContexts('widget_metrics', {
        'capture_count': captureCount,
        'error_count': errorCount,
        'error_rate': captureCount > 0 ? (errorCount / captureCount * 100).round() : 0,
        'template_usage': templateUsage,
        'platform_usage': platformUsage,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Handle platform-specific errors
  static Future<void> handlePlatformError(
    String platform,
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
  }) async {
    await captureError(
      error,
      stackTrace,
      category: categoryPlatform,
      message: 'Platform error on $platform',
      extra: {
        'platform': platform,
        ...?extra,
      },
      level: SentryLevel.error,
    );
  }

  /// Handle network errors
  static Future<void> handleNetworkError(
    dynamic error,
    StackTrace? stackTrace, {
    String? url,
    int? statusCode,
    String? method,
    Map<String, dynamic>? extra,
  }) async {
    await captureError(
      error,
      stackTrace,
      category: categoryNetwork,
      message: 'Network error',
      extra: {
        if (url != null) 'url': url,
        if (statusCode != null) 'status_code': statusCode,
        if (method != null) 'method': method,
        ...?extra,
      },
      level: SentryLevel.warning,
    );
  }

  /// Handle validation errors
  static Future<void> handleValidationError(
    String field,
    String message, {
    Map<String, dynamic>? extra,
  }) async {
    await captureMessage(
      'Validation error: $field - $message',
      level: SentryLevel.warning,
      category: categoryValidation,
      extra: {
        'field': field,
        'validation_message': message,
        ...?extra,
      },
    );
  }

  /// Track offline queue errors
  static Future<void> trackOfflineQueueError(
    dynamic error,
    StackTrace? stackTrace, {
    int? queueSize,
    int? failedCount,
  }) async {
    await captureError(
      error,
      stackTrace,
      category: categorySync,
      message: 'Offline queue sync error',
      extra: {
        if (queueSize != null) 'queue_size': queueSize,
        if (failedCount != null) 'failed_count': failedCount,
      },
      level: SentryLevel.warning,
    );
  }

  /// Monitor widget performance issues
  static void monitorPerformance({
    required String metric,
    required double value,
    required double threshold,
  }) {
    if (value > threshold) {
      captureMessage(
        'Performance degradation: $metric',
        level: SentryLevel.warning,
        category: categoryPerformance,
        extra: {
          'metric': metric,
          'value': value,
          'threshold': threshold,
          'exceeded_by': value - threshold,
        },
      );
    }
  }

  /// Create error boundary for widgets
  static Widget errorBoundary({
    required Widget child,
    Widget? fallback,
  }) {
    return SentryWidget(
      child: child,
    );
  }

  /// Wrap async operations with error tracking
  static Future<T> wrapAsync<T>({
    required Future<T> Function() operation,
    required String context,
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      await captureError(
        error,
        stackTrace,
        category: categoryCapture,
        message: 'Async operation failed: $context',
        extra: extra,
      );
      rethrow;
    }
  }
}
