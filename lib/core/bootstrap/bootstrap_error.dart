import 'package:flutter/foundation.dart';

/// Severity levels for bootstrap errors
enum BootstrapErrorSeverity {
  /// Non-critical error - app can continue with reduced functionality
  warning,

  /// Important error - major feature unavailable but app usable
  important,

  /// Critical error - app cannot function properly
  critical,

  /// Fatal error - app must terminate
  fatal,
}

/// Detailed bootstrap error information
class BootstrapError {
  BootstrapError({
    required this.stage,
    required this.error,
    required this.stackTrace,
    required this.severity,
    this.message,
    this.retryable = false,
    this.fallbackAvailable = false,
    this.userActionRequired = false,
    this.metadata = const {},
  });

  /// The bootstrap stage where the error occurred
  final BootstrapStage stage;

  /// The actual error object
  final Object error;

  /// Stack trace for debugging
  final StackTrace stackTrace;

  /// Severity of the error
  final BootstrapErrorSeverity severity;

  /// User-friendly error message
  final String? message;

  /// Whether this error can be retried
  final bool retryable;

  /// Whether a fallback option is available
  final bool fallbackAvailable;

  /// Whether user action is required to resolve
  final bool userActionRequired;

  /// Additional metadata about the error
  final Map<String, dynamic> metadata;

  /// Check if this is a critical or fatal error
  bool get isCritical =>
      severity == BootstrapErrorSeverity.critical ||
      severity == BootstrapErrorSeverity.fatal;

  /// Get a user-friendly description of the error
  String get userDescription {
    if (message != null) return message!;

    switch (stage) {
      case BootstrapStage.environment:
        return 'Failed to load environment configuration';
      case BootstrapStage.logging:
        return 'Failed to initialize logging system';
      case BootstrapStage.platform:
        return 'Platform-specific initialization failed';
      case BootstrapStage.monitoring:
        return 'Error reporting service unavailable';
      case BootstrapStage.firebase:
        return 'Firebase services unavailable';
      case BootstrapStage.supabase:
        return 'Database connection failed';
      case BootstrapStage.featureFlags:
        return 'Feature configuration unavailable';
      case BootstrapStage.analytics:
        return 'Analytics service unavailable';
      case BootstrapStage.adapty:
        return 'Premium features unavailable';
    }
  }

  /// Get suggested action for the user
  String get suggestedAction {
    if (userActionRequired) {
      switch (stage) {
        case BootstrapStage.supabase:
          return 'Check your internet connection and try again';
        case BootstrapStage.firebase:
          return 'Some features may be limited. Please restart the app';
        default:
          return 'Please restart the app or contact support if the problem persists';
      }
    }

    if (retryable) {
      return 'The app will retry automatically';
    }

    if (fallbackAvailable) {
      return 'Using limited functionality mode';
    }

    return 'Some features may not be available';
  }

  /// Convert to a loggable map
  Map<String, dynamic> toLogMap() {
    return {
      'stage': stage.name,
      'severity': severity.name,
      'error': error.toString(),
      'retryable': retryable,
      'fallbackAvailable': fallbackAvailable,
      'userActionRequired': userActionRequired,
      'metadata': metadata,
      if (kDebugMode) 'stackTrace': stackTrace.toString(),
    };
  }
}

/// Bootstrap stages for error tracking
enum BootstrapStage {
  environment,
  logging,
  platform,
  monitoring,
  firebase,
  supabase,
  featureFlags,
  analytics,
  adapty,
}

/// Recovery strategy for bootstrap errors
abstract class BootstrapRecoveryStrategy {
  /// Attempt to recover from the error
  Future<bool> recover(BootstrapError error);

  /// Check if this strategy can handle the given error
  bool canHandle(BootstrapError error);
}

/// Retry strategy for transient errors
class RetryRecoveryStrategy implements BootstrapRecoveryStrategy {
  RetryRecoveryStrategy({
    this.maxRetries = 3,
    this.delayMs = 1000,
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final int delayMs;
  final double backoffMultiplier;

  final Map<BootstrapStage, int> _retryCount = {};

  @override
  bool canHandle(BootstrapError error) {
    return error.retryable &&
           (_retryCount[error.stage] ?? 0) < maxRetries;
  }

  @override
  Future<bool> recover(BootstrapError error) async {
    final currentRetries = _retryCount[error.stage] ?? 0;
    _retryCount[error.stage] = currentRetries + 1;

    final delay = (delayMs *
        (currentRetries > 0 ? backoffMultiplier * currentRetries : 1))
        .round();

    await Future.delayed(Duration(milliseconds: delay));

    // Return true to signal retry should be attempted
    return true;
  }

  /// Reset retry count for a stage
  void resetStage(BootstrapStage stage) {
    _retryCount.remove(stage);
  }

  /// Reset all retry counts
  void resetAll() {
    _retryCount.clear();
  }
}

/// Fallback strategy for non-critical services
class FallbackRecoveryStrategy implements BootstrapRecoveryStrategy {
  @override
  bool canHandle(BootstrapError error) {
    return error.fallbackAvailable &&
           error.severity != BootstrapErrorSeverity.fatal;
  }

  @override
  Future<bool> recover(BootstrapError error) async {
    // Signal that fallback mode should be used
    return false; // Don't retry, use fallback
  }
}

/// Manager for bootstrap error recovery
class BootstrapErrorManager {
  BootstrapErrorManager({
    List<BootstrapRecoveryStrategy>? strategies,
  }) : _strategies = strategies ?? [
          RetryRecoveryStrategy(),
          FallbackRecoveryStrategy(),
        ];

  final List<BootstrapRecoveryStrategy> _strategies;
  final List<BootstrapError> _errors = [];

  /// Record an error
  void addError(BootstrapError error) {
    _errors.add(error);
  }

  /// Get all recorded errors
  List<BootstrapError> get errors => List.unmodifiable(_errors);

  /// Check if there are any critical errors
  bool get hasCriticalErrors =>
      _errors.any((e) => e.isCritical);

  /// Check if there are any fatal errors
  bool get hasFatalErrors =>
      _errors.any((e) => e.severity == BootstrapErrorSeverity.fatal);

  /// Get errors by severity
  List<BootstrapError> errorsBySeverity(BootstrapErrorSeverity severity) {
    return _errors.where((e) => e.severity == severity).toList();
  }

  /// Get errors by stage
  List<BootstrapError> errorsByStage(BootstrapStage stage) {
    return _errors.where((e) => e.stage == stage).toList();
  }

  /// Attempt to recover from an error
  Future<bool> tryRecover(BootstrapError error) async {
    for (final strategy in _strategies) {
      if (strategy.canHandle(error)) {
        return await strategy.recover(error);
      }
    }
    return false;
  }

  /// Clear all errors
  void clear() {
    _errors.clear();
  }

  /// Get a summary of all errors
  Map<String, dynamic> getSummary() {
    return {
      'total': _errors.length,
      'critical': _errors.where((e) => e.isCritical).length,
      'warnings': _errors.where(
        (e) => e.severity == BootstrapErrorSeverity.warning,
      ).length,
      'byStage': {
        for (final stage in BootstrapStage.values)
          stage.name: errorsByStage(stage).length,
      },
    };
  }
}