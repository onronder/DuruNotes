import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Comprehensive analytics tracker for Quick Capture Widget
/// Tracks all widget-related events, performance metrics, and user behavior
class WidgetAnalyticsTracker {
  final AnalyticsService _analytics;
  final AppLogger _logger;
  
  // Event tracking
  static const String _eventPrefix = 'widget.quick_capture';
  
  // Performance tracking
  final Map<String, Stopwatch> _performanceTrackers = {};
  
  // Usage metrics
  int _captureCount = 0;
  int _errorCount = 0;
  final Map<String, int> _templateUsage = {};
  final Map<String, int> _platformUsage = {};
  
  // Session tracking
  DateTime? _sessionStart;
  String? _sessionId;
  
  WidgetAnalyticsTracker({
    required AnalyticsService analytics,
    required AppLogger logger,
  })  : _analytics = analytics,
        _logger = logger;

  // ============================================
  // SESSION MANAGEMENT
  // ============================================
  
  /// Start a new widget session
  void startSession({String? source}) {
    _sessionStart = DateTime.now();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _analytics.event('$_eventPrefix.session_start', properties: {
      'session_id': _sessionId,
      'source': source ?? 'unknown',
      'timestamp': _sessionStart!.toIso8601String(),
    });
    
    _logger.info('Widget session started: $_sessionId');
  }
  
  /// End the current session
  void endSession() {
    if (_sessionStart == null || _sessionId == null) return;
    
    final duration = DateTime.now().difference(_sessionStart!);
    
    _analytics.event('$_eventPrefix.session_end', properties: {
      'session_id': _sessionId,
      'duration_seconds': duration.inSeconds,
      'captures_count': _captureCount,
      'errors_count': _errorCount,
    });
    
    _logger.info('Widget session ended: $_sessionId (${duration.inSeconds}s)');
    
    // Reset session
    _sessionStart = null;
    _sessionId = null;
    _captureCount = 0;
    _errorCount = 0;
  }

  // ============================================
  // CAPTURE EVENTS
  // ============================================
  
  /// Track note capture initiation
  void trackCaptureStarted({
    required String platform,
    required String captureType,
    String? templateId,
    Map<String, dynamic>? metadata,
  }) {
    final trackingId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Start performance tracking
    _performanceTrackers[trackingId] = Stopwatch()..start();
    
    _analytics.event('$_eventPrefix.capture_started', properties: {
      'tracking_id': trackingId,
      'platform': platform,
      'capture_type': captureType,
      'template_id': templateId,
      'session_id': _sessionId,
      ...?metadata,
    });
    
    // Update platform usage
    _platformUsage[platform] = (_platformUsage[platform] ?? 0) + 1;
    
    // Update template usage if applicable
    if (templateId != null) {
      _templateUsage[templateId] = (_templateUsage[templateId] ?? 0) + 1;
    }
  }
  
  /// Track successful capture completion
  void trackCaptureCompleted({
    required String trackingId,
    required String noteId,
    int? textLength,
    int? attachmentCount,
    bool? offline,
  }) {
    // Stop performance tracking
    final stopwatch = _performanceTrackers.remove(trackingId);
    final duration = stopwatch?.elapsedMilliseconds ?? 0;
    
    _captureCount++;
    
    _analytics.event('$_eventPrefix.capture_completed', properties: {
      'tracking_id': trackingId,
      'note_id': noteId,
      'duration_ms': duration,
      'text_length': textLength,
      'attachment_count': attachmentCount ?? 0,
      'offline': offline ?? false,
      'session_id': _sessionId,
    });
    
    // Track performance metrics
    if (duration > 0) {
      trackPerformanceMetric('capture_duration', duration.toDouble());
    }
  }
  
  /// Track capture failure
  void trackCaptureFailed({
    required String trackingId,
    required String error,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) {
    // Stop performance tracking
    _performanceTrackers.remove(trackingId);
    
    _errorCount++;
    
    _analytics.event('$_eventPrefix.capture_failed', properties: {
      'tracking_id': trackingId,
      'error': error,
      'error_code': errorCode,
      'session_id': _sessionId,
      ...?metadata,
    });
    
    _logger.error('Widget capture failed', error: error);
  }

  // ============================================
  // WIDGET INTERACTIONS
  // ============================================
  
  /// Track widget opened/viewed
  void trackWidgetOpened({
    required String widgetSize,
    required String platform,
  }) {
    _analytics.event('$_eventPrefix.widget_opened', properties: {
      'widget_size': widgetSize,
      'platform': platform,
      'session_id': _sessionId,
    });
  }
  
  /// Track widget configuration changed
  void trackConfigurationChanged({
    required Map<String, dynamic> configuration,
  }) {
    _analytics.event('$_eventPrefix.configuration_changed', properties: {
      'configuration': configuration,
      'session_id': _sessionId,
    });
  }
  
  /// Track widget refresh
  void trackWidgetRefresh({
    required String source,
    bool? manual,
  }) {
    _analytics.event('$_eventPrefix.widget_refreshed', properties: {
      'source': source,
      'manual': manual ?? false,
      'session_id': _sessionId,
    });
  }
  
  /// Track template selection
  void trackTemplateSelected({
    required String templateId,
    required String platform,
  }) {
    _templateUsage[templateId] = (_templateUsage[templateId] ?? 0) + 1;
    
    _analytics.event('$_eventPrefix.template_selected', properties: {
      'template_id': templateId,
      'platform': platform,
      'usage_count': _templateUsage[templateId],
      'session_id': _sessionId,
    });
  }

  // ============================================
  // PERFORMANCE METRICS
  // ============================================
  
  /// Track a performance metric
  void trackPerformanceMetric(String metric, double value) {
    _analytics.event('$_eventPrefix.performance', properties: {
      'metric': metric,
      'value': value,
      'session_id': _sessionId,
    });
    
    // Log if performance is degraded
    if (metric == 'capture_duration' && value > 1000) {
      _logger.warning('Slow widget capture: ${value}ms');
    }
  }
  
  /// Track widget data sync performance
  void trackDataSyncPerformance({
    required int itemCount,
    required int durationMs,
    required bool success,
  }) {
    _analytics.event('$_eventPrefix.data_sync', properties: {
      'item_count': itemCount,
      'duration_ms': durationMs,
      'success': success,
      'items_per_second': itemCount > 0 ? (itemCount * 1000 / durationMs).round() : 0,
      'session_id': _sessionId,
    });
  }

  // ============================================
  // OFFLINE QUEUE METRICS
  // ============================================
  
  /// Track offline queue status
  void trackOfflineQueueStatus({
    required int queueSize,
    required int processed,
    required int failed,
  }) {
    _analytics.event('$_eventPrefix.offline_queue', properties: {
      'queue_size': queueSize,
      'processed': processed,
      'failed': failed,
      'success_rate': queueSize > 0 ? (processed / queueSize * 100).round() : 100,
      'session_id': _sessionId,
    });
  }

  // ============================================
  // ERROR TRACKING
  // ============================================
  
  /// Track widget-specific errors
  void trackError({
    required String error,
    required String context,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _errorCount++;
    
    _analytics.event('$_eventPrefix.error', properties: {
      'error': error,
      'context': context,
      'session_id': _sessionId,
      ...?metadata,
    });
    
    _logger.error('Widget error in $context', 
      error: error, 
      stackTrace: stackTrace
    );
  }

  // ============================================
  // RATE LIMITING
  // ============================================
  
  /// Track rate limit events
  void trackRateLimitHit({
    required String userId,
    required int requestCount,
    required int limitRemaining,
  }) {
    _analytics.event('$_eventPrefix.rate_limit', properties: {
      'user_id': userId,
      'request_count': requestCount,
      'limit_remaining': limitRemaining,
      'session_id': _sessionId,
    });
    
    if (limitRemaining == 0) {
      _logger.warning('User hit rate limit: $userId');
    }
  }

  // ============================================
  // USAGE ANALYTICS
  // ============================================
  
  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'total_captures': _captureCount,
      'total_errors': _errorCount,
      'error_rate': _captureCount > 0 ? (_errorCount / _captureCount * 100).round() : 0,
      'platform_usage': _platformUsage,
      'template_usage': _templateUsage,
      'session_duration': _sessionStart != null 
        ? DateTime.now().difference(_sessionStart!).inSeconds 
        : 0,
    };
  }
  
  /// Track daily active widget users
  void trackDailyActiveUser({
    required String userId,
    required String platform,
  }) {
    _analytics.event('$_eventPrefix.dau', properties: {
      'user_id': userId,
      'platform': platform,
      'date': DateTime.now().toIso8601String().split('T')[0],
    });
  }
  
  /// Track feature usage
  void trackFeatureUsage({
    required String feature,
    Map<String, dynamic>? metadata,
  }) {
    _analytics.event('$_eventPrefix.feature_usage', properties: {
      'feature': feature,
      'session_id': _sessionId,
      ...?metadata,
    });
  }

  // ============================================
  // A/B TESTING
  // ============================================
  
  /// Track A/B test exposure
  void trackExperiment({
    required String experimentId,
    required String variant,
    Map<String, dynamic>? metadata,
  }) {
    _analytics.event('$_eventPrefix.experiment', properties: {
      'experiment_id': experimentId,
      'variant': variant,
      'session_id': _sessionId,
      ...?metadata,
    });
  }

  // ============================================
  // FUNNEL TRACKING
  // ============================================
  
  /// Track funnel step completion
  void trackFunnelStep({
    required String funnel,
    required String step,
    required int stepNumber,
    Map<String, dynamic>? metadata,
  }) {
    _analytics.event('$_eventPrefix.funnel', properties: {
      'funnel': funnel,
      'step': step,
      'step_number': stepNumber,
      'session_id': _sessionId,
      ...?metadata,
    });
  }

  // ============================================
  // CLEANUP
  // ============================================
  
  /// Clean up resources
  void dispose() {
    if (_sessionStart != null) {
      endSession();
    }
    _performanceTrackers.clear();
    _templateUsage.clear();
    _platformUsage.clear();
  }
}
