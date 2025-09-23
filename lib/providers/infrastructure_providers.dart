import 'package:duru_notes/core/bootstrap/bootstrap_error.dart';
import 'package:duru_notes/core/bootstrap/enhanced_app_bootstrap.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the bootstrap result
final bootstrapResultProvider = Provider<EnhancedBootstrapResult?>((ref) {
  // This will be overridden at app startup with the actual bootstrap result
  return null;
});

/// Provider for environment configuration
final environmentConfigProvider = Provider<EnvironmentConfig>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  if (bootstrap == null) {
    // Fallback for testing or edge cases
    return EnvironmentConfig.fallback();
  }
  return bootstrap.environment;
});

/// Provider for application logger
final loggerProvider = Provider<AppLogger>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  if (bootstrap == null) {
    // Fallback logger for early initialization
    return const ConsoleLogger();
  }
  return bootstrap.logger;
});

/// Provider for analytics service
final analyticsProvider = Provider<AnalyticsService>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  if (bootstrap == null) {
    // Return a NoOp analytics service if not initialized
    return _NoOpAnalytics();
  }
  return bootstrap.analytics;
});

/// Provider for navigator key
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

/// Provider for checking if app is in degraded mode
final degradedModeProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  return bootstrap?.degradedMode ?? true;
});

/// Provider for checking if app is in offline mode
final offlineModeProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  return bootstrap?.offlineMode ?? true;
});

/// Provider for bootstrap errors
final bootstrapErrorsProvider = Provider<List<BootstrapError>>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  return bootstrap?.errorManager.errors ?? [];
});

/// Provider for checking if premium features are enabled
final premiumFeaturesEnabledProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  return bootstrap?.adaptyEnabled ?? false;
});

/// Provider for checking if monitoring is enabled
final monitoringEnabledProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(bootstrapResultProvider);
  return bootstrap?.sentryEnabled ?? false;
});

/// Extension methods for easy provider access
extension LoggerExtension on WidgetRef {
  AppLogger get logger => read(loggerProvider);
}

extension AnalyticsExtension on WidgetRef {
  AnalyticsService get analytics => read(analyticsProvider);
}

/// Helper methods for console providers
extension ConsumerLoggerExtension on Ref {
  AppLogger get logger => read(loggerProvider);
  AnalyticsService get analytics => read(analyticsProvider);
}

/// NoOp analytics implementation for fallback
class _NoOpAnalytics extends AnalyticsService {
  @override
  bool get isEnabled => false;

  @override
  void enable() {
    // No operation
  }

  @override
  void disable() {
    // No operation
  }

  @override
  void startTiming(String eventName) {
    // No operation
  }

  @override
  void endTiming(String eventName, {Map<String, dynamic>? properties}) {
    // No operation
  }

  @override
  void featureUsed(String featureName, {Map<String, dynamic>? properties}) {
    // No operation
  }

  @override
  void trackError(
    String message, {
    String? context,
    Map<String, dynamic>? properties,
  }) {
    // No operation
  }

  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    // No operation
  }

  // These methods don't exist in the base class, so they're removed
  Future<void> setUserProperty(String key, dynamic value) async {}
  Future<void> setUserId(String? userId) async {}
  Future<void> resetUser() async {}
  Future<void> screenView(String screenName) async {}
  Future<void> recordError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool fatal = false,
  }) async {}
  Future<void> flush() async {}
}

/// Provider override helper for setting bootstrap result
class BootstrapProviderScope extends ConsumerWidget {
  const BootstrapProviderScope({
    super.key,
    required this.bootstrapResult,
    required this.child,
  });

  final EnhancedBootstrapResult bootstrapResult;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        bootstrapResultProvider.overrideWithValue(bootstrapResult),
      ],
      child: child,
    );
  }
}

/// Convenience method for migrating from LoggerFactory.instance
AppLogger getLogger(Ref ref) => ref.read(loggerProvider);

/// Convenience method for migrating from AnalyticsFactory.instance
AnalyticsService getAnalytics(Ref ref) => ref.read(analyticsProvider);

// Migration helpers - these will be removed after full migration
/// @deprecated Use loggerProvider instead
AppLogger get deprecatedLogger => LoggerFactory.instance;

/// @deprecated Use analyticsProvider instead
AnalyticsService get deprecatedAnalytics => AnalyticsFactory.instance;