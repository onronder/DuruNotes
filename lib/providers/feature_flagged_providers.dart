/// Feature-flagged providers for gradual rollout of refactored components
///
/// This file contains providers that use feature flags to switch between
/// legacy and refactored implementations of various services and UI components.
library;

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/services/permission_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = LoggerFactory.instance;

/// Feature flag provider for easy access
final featureFlagsProvider =
    Provider<FeatureFlags>((ref) => FeatureFlags.instance);

/// Reminder coordinator provider (unified implementation)
/// Phase 1 complete - always uses refactored implementation
final featureFlaggedReminderCoordinatorProvider = Provider<dynamic>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  // Always use unified implementation (Phase 1 complete)
  _logger.debug('[FeatureFlags] ✅ Using unified ReminderCoordinator');

  final coordinator = ReminderCoordinator(ref, plugin, db);

  // Initialize on creation
  coordinator.initialize().catchError((error) {
    _logger.error('[FeatureFlags] Error initializing coordinator', error: error);
  });

  return coordinator;
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

/// Advanced reminder service provider (unified implementation)
/// Phase 1 complete - uses unified implementation
final featureFlaggedAdvancedReminderServiceProvider =
    Provider<AdvancedReminderService>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  _logger.debug('[FeatureFlags] ✅ Using unified AdvancedReminderService');

  return AdvancedReminderService(ref, plugin, db);
});

/// Helper function to check if refactored components should be used
bool shouldUseRefactoredComponents() {
  return FeatureFlags.instance.useRefactoredComponents;
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
