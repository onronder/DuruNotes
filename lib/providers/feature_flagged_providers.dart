/// Feature-flagged providers for gradual rollout of refactored components
///
/// This file contains providers that use feature flags to switch between
/// legacy and refactored implementations of various services and UI components.
library;

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart'
    as legacy;
import 'package:duru_notes/services/reminders/reminder_coordinator_refactored.dart'
    as refactored;
import 'package:duru_notes/services/permission_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = LoggerFactory.instance;

/// Feature flag provider for easy access
final featureFlagsProvider =
    Provider<FeatureFlags>((ref) => FeatureFlags.instance);

/// Feature-flagged reminder coordinator provider
/// Returns either legacy or refactored implementation based on feature flag
final featureFlaggedReminderCoordinatorProvider = Provider<dynamic>((ref) {
  final featureFlags = ref.watch(featureFlagsProvider);
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  if (featureFlags.useUnifiedReminders) {
    // Log for debugging
    _logger.debug('[FeatureFlags] ✅ Using REFACTORED ReminderCoordinator');

    final coordinator = refactored.ReminderCoordinator(plugin, db);

    // Initialize on creation
    coordinator.initialize().catchError((error) {
      _logger.error('[FeatureFlags] Error initializing refactored coordinator',
          error: error);
    });

    return coordinator;
  } else {
    // Log for debugging
    _logger.debug('[FeatureFlags] ⚠️ Using LEGACY ReminderCoordinator');

    final coordinator = legacy.ReminderCoordinator(plugin, db);

    // Initialize on creation
    coordinator.initialize().catchError((error) {
      _logger.error('[FeatureFlags] Error initializing legacy coordinator',
          error: error);
    });

    return coordinator;
  }
});

/// Feature-flagged permission manager provider
final featureFlaggedPermissionManagerProvider =
    Provider<PermissionManager>((ref) {
  final featureFlags = ref.watch(featureFlagsProvider);

  if (featureFlags.useUnifiedPermissionManager) {
    _logger.debug('[FeatureFlags] ✅ Using unified PermissionManager');
    return PermissionManager.instance;
  } else {
    _logger.debug('[FeatureFlags] ⚠️ Using legacy permission handling');
    // For now, return the same instance as we only have one implementation
    // In a real scenario, this would return a legacy permission handler
    return PermissionManager.instance;
  }
});

/// Feature-flagged advanced reminder service provider
/// This can switch between different reminder implementations
final featureFlaggedAdvancedReminderServiceProvider =
    Provider<AdvancedReminderService>((ref) {
  final featureFlags = ref.watch(featureFlagsProvider);
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  if (featureFlags.useUnifiedReminders) {
    _logger.debug('[FeatureFlags] ✅ Using refactored AdvancedReminderService');
  } else {
    _logger.debug('[FeatureFlags] ⚠️ Using legacy AdvancedReminderService');
  }

  // Currently both use the same implementation
  // In future, this could return different implementations
  return AdvancedReminderService(plugin, db);
});

/// Helper function to check if refactored components should be used
bool shouldUseRefactoredComponents() {
  return FeatureFlags.instance.useRefactoredComponents;
}

/// Helper function to check if unified reminders should be used
bool shouldUseUnifiedReminders() {
  return FeatureFlags.instance.useUnifiedReminders;
}

/// Helper function to check if new block editor should be used
bool shouldUseNewBlockEditor() {
  return FeatureFlags.instance.useNewBlockEditor;
}

/// Extension on WidgetRef for easy feature flag access
extension FeatureFlagExtensions on WidgetRef {
  /// Check if refactored components should be used
  bool get useRefactoredComponents =>
      read(featureFlagsProvider).useRefactoredComponents;

  /// Check if unified reminders should be used
  bool get useUnifiedReminders =>
      read(featureFlagsProvider).useUnifiedReminders;

  /// Check if new block editor should be used
  bool get useNewBlockEditor => read(featureFlagsProvider).useNewBlockEditor;

  /// Check if unified permission manager should be used
  bool get useUnifiedPermissionManager =>
      read(featureFlagsProvider).useUnifiedPermissionManager;

  /// Get the appropriate reminder coordinator based on feature flags
  dynamic getReminderCoordinator() =>
      read(featureFlaggedReminderCoordinatorProvider);

  /// Get the appropriate permission manager based on feature flags
  PermissionManager getPermissionManager() =>
      read(featureFlaggedPermissionManagerProvider);
}
