/// Unified reminder provider with consolidated reminder implementation
library;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = LoggerFactory.instance;

/// Unified reminder coordinator provider using the consolidated implementation
final unifiedReminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);

  _logger.debug('[Phase1] Using consolidated ReminderCoordinator');
  return ReminderCoordinator(ref, plugin, db);
});

/// Extension for convenient access to the reminder coordinator
extension ReminderCoordinatorAccess on WidgetRef {
  /// Get the reminder coordinator with type safety
  ReminderCoordinator getReminderCoordinator() {
    return read(unifiedReminderCoordinatorProvider);
  }
}
