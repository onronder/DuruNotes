/// Unified reminder provider that switches between legacy and refactored implementations
/// based on feature flags

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/logging/logger_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart'
    as legacy;
import 'package:duru_notes/services/reminders/reminder_coordinator_refactored.dart'
    as refactored;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = LoggerFactory.instance;

/// Unified reminder coordinator provider that uses feature flags
final unifiedReminderCoordinatorProvider = Provider<dynamic>((ref) {
  final featureFlags = FeatureFlags.instance;
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  if (featureFlags.useUnifiedReminders) {
    // Use refactored implementation
    _logger.debug('[FeatureFlags] Using REFACTORED ReminderCoordinator');
    return refactored.ReminderCoordinator(plugin, db);
  } else {
    // Use legacy implementation
    _logger.debug('[FeatureFlags] Using LEGACY ReminderCoordinator');
    return legacy.ReminderCoordinator(plugin, db);
  }
});

/// Extension to help with type safety when accessing the coordinator
extension ReminderCoordinatorAccess on WidgetRef {
  /// Get the reminder coordinator with proper type based on feature flags
  T getReminderCoordinator<T>() {
    final coordinator = read(unifiedReminderCoordinatorProvider);
    if (coordinator is T) {
      return coordinator;
    }
    throw StateError('Reminder coordinator is not of expected type $T');
  }
}
