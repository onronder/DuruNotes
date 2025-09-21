import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/permission_manager.dart';
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:duru_notes/services/reminders/geofence_reminder_service_refactored.dart';
import 'package:duru_notes/services/reminders/recurring_reminder_service_refactored.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service_refactored.dart'
    hide SnoozeDuration;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Unified coordinator for all reminder services
///
/// This class manages the lifecycle and interactions between different reminder services:
/// - [RecurringReminderService] for time-based and recurring reminders
/// - [GeofenceReminderService] for location-based reminders
/// - [SnoozeReminderService] for snooze functionality
///
/// The coordinator uses feature flags to enable gradual rollout of the refactored services.
class ReminderCoordinator {
  ReminderCoordinator(this._plugin, this._db) {
    if (_featureFlags.useUnifiedReminders) {
      // Use refactored services
      _recurringService = RecurringReminderService(_plugin, _db);
      _geofenceService = GeofenceReminderService(_plugin, _db);
      _snoozeService = SnoozeReminderService(_plugin, _db);
    } else {
      // Use legacy services (would need to import old ones)
      // For now, we'll use the refactored ones regardless
      _recurringService = RecurringReminderService(_plugin, _db);
      _geofenceService = GeofenceReminderService(_plugin, _db);
      _snoozeService = SnoozeReminderService(_plugin, _db);
    }
  }

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;

  late final BaseReminderService _recurringService;
  late final BaseReminderService _geofenceService;
  late final BaseReminderService _snoozeService;

  bool _initialized = false;
  final AppLogger logger = LoggerFactory.instance;
  final AnalyticsService analytics = AnalyticsFactory.instance;
  final FeatureFlags _featureFlags = FeatureFlags.instance;
  final PermissionManager _permissionManager = PermissionManager.instance;

  /// Get the snooze service for external use
  SnoozeReminderService get snoozeService =>
      _snoozeService as SnoozeReminderService;

  /// Initialize all sub-services and notification channel
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize all services
      await Future.wait([
        _recurringService.initialize(),
        _geofenceService.initialize(),
        _snoozeService.initialize(),
      ]);

      _initialized = true;
      logger.info('ReminderCoordinator initialized with unified services');

      analytics.event(
        'app.feature_enabled',
        properties: {
          'feature': 'reminder_coordinator',
          'unified_services': _featureFlags.useUnifiedReminders,
        },
      );
    } catch (e, stack) {
      logger.error(
        'Failed to initialize ReminderCoordinator',
        error: e,
        stackTrace: stack,
      );
      // Don't throw - partial initialization is better than none
    }
  }

  // Permission Management (using unified PermissionManager)

  Future<bool> requestNotificationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      final status =
          await _permissionManager.request(PermissionType.notification);
      return status == PermissionStatus.granted;
    } else {
      // Fall back to base service method
      return await _recurringService.requestNotificationPermissions();
    }
  }

  Future<bool> hasNotificationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      return await _permissionManager
          .hasPermission(PermissionType.notification);
    } else {
      // Fall back to base service method
      return await _recurringService.hasNotificationPermissions();
    }
  }

  Future<bool> requestLocationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      final status = await _permissionManager.request(PermissionType.location);
      return status == PermissionStatus.granted;
    } else {
      // Fall back to geofence service method
      return await (_geofenceService as GeofenceReminderService)
          .requestLocationPermissions();
    }
  }

  Future<bool> hasLocationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      return await _permissionManager.hasPermission(PermissionType.location);
    } else {
      // Fall back to geofence service method
      return await (_geofenceService as GeofenceReminderService)
          .hasLocationPermissions();
    }
  }

  /// Check if all required permissions are granted (optionally include location)
  Future<bool> hasRequiredPermissions({bool includeLocation = false}) async {
    final notifOK = await hasNotificationPermissions();
    if (!includeLocation) return notifOK;
    final locOK = await hasLocationPermissions();
    return notifOK && locOK;
  }

  // Reminder creation and retrieval

  /// Create a time-based reminder (with optional recurrence)
  Future<int?> createTimeReminder({
    required String noteId,
    required String title,
    required String body,
    required DateTime remindAtUtc,
    RecurrencePattern recurrence = RecurrencePattern.none,
    int recurrenceInterval = 1,
    DateTime? recurrenceEndDate,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    await initialize();

    if (!await hasNotificationPermissions()) {
      logger.warning('Cannot create reminder - no notification permissions');

      if (!await requestNotificationPermissions()) {
        analytics
            .event('reminder.permission_denied', properties: {'type': 'time'});
        return null;
      }
    }

    final config = ReminderConfig(
      noteId: noteId,
      title: title,
      body: body,
      scheduledTime: remindAtUtc,
      recurrencePattern: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );

    final reminderId = await _recurringService.createReminder(config);

    if (reminderId != null) {
      logger.info('Created time reminder', data: {
        'id': reminderId,
        'recurrence': recurrence.name,
      });
    }

    return reminderId;
  }

  /// Create a location-based reminder
  Future<int?> createLocationReminder({
    required String noteId,
    required String title,
    required String body,
    required double latitude,
    required double longitude,
    double radius = 100.0,
    String? locationName,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    await initialize();

    if (!await hasLocationPermissions()) {
      logger
          .warning('Cannot create location reminder - no location permissions');

      if (!await requestLocationPermissions()) {
        analytics.event('reminder.permission_denied',
            properties: {'type': 'location'});
        return null;
      }
    }

    final config = ReminderConfig(
      noteId: noteId,
      title: title,
      body: body,
      scheduledTime: DateTime.now(), // Not used for location reminders
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'locationName': locationName,
      },
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );

    final reminderId = await _geofenceService.createReminder(config);

    if (reminderId != null) {
      logger.info('Created location reminder', data: {
        'id': reminderId,
        'location': locationName ?? 'unnamed',
      });
    }

    return reminderId;
  }

  /// Snooze an existing reminder
  Future<bool> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    await initialize();

    if (!await hasNotificationPermissions()) {
      logger.warning('Cannot snooze reminder - no notification permissions');
      return false;
    }

    final snoozed = await (_snoozeService as SnoozeReminderService)
        .snoozeReminder(reminderId, duration);

    if (snoozed) {
      logger.info('Snoozed reminder', data: {
        'id': reminderId,
        'duration': duration.name,
      });
    }

    return snoozed;
  }

  /// Get all reminders for a note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      return await _db.getRemindersForNote(noteId);
    } catch (e, stack) {
      logger.error(
        'Failed to get reminders for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      return [];
    }
  }

  /// Get all active reminders
  Future<List<NoteReminder>> getActiveReminders() async {
    try {
      return await _db.getActiveReminders();
    } catch (e, stack) {
      logger.error(
        'Failed to get active reminders',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Cancel a reminder
  Future<void> cancelReminder(int reminderId) async {
    try {
      // Determine which service should handle the cancellation
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null) {
        logger.warning('Cannot cancel reminder - not found',
            data: {'id': reminderId});
        return;
      }

      switch (reminder.type) {
        case ReminderType.time:
        case ReminderType.recurring:
          await _recurringService.cancelReminder(reminderId);
          break;
        case ReminderType.location:
          await _geofenceService.cancelReminder(reminderId);
          break;
        default:
          // Generic cancellation
          await _recurringService.cancelNotification(reminderId);
          await _db.updateReminder(
            reminderId,
            NoteRemindersCompanion(isActive: Value(false)),
          );
          break;
      }

      logger.info('Cancelled reminder', data: {'id': reminderId});

      analytics.event('reminder.cancelled', properties: {
        'reminder_id': reminderId,
        'type': reminder.type.name,
      });
    } catch (e, stack) {
      logger.error(
        'Failed to cancel reminder',
        error: e,
        stackTrace: stack,
        data: {'id': reminderId},
      );
    }
  }

  /// Cancel all reminders for a note
  Future<void> cancelRemindersForNote(String noteId) async {
    try {
      final reminders = await getRemindersForNote(noteId);

      for (final reminder in reminders) {
        await cancelReminder(reminder.id);
      }

      if (reminders.isNotEmpty) {
        logger.info('Cancelled ${reminders.length} reminders for note', data: {
          'noteId': noteId,
        });
      }
    } catch (e, stack) {
      logger.error(
        'Failed to cancel reminders for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
    }
  }

  /// Process due reminders (called periodically)
  Future<void> processDueReminders() async {
    if (!_initialized) return;

    try {
      // Process recurring reminders
      if (_recurringService is RecurringReminderService) {
        await (_recurringService as RecurringReminderService)
            .processDueReminders();
      }

      // Process snoozed reminders
      if (_snoozeService is SnoozeReminderService) {
        await (_snoozeService as SnoozeReminderService)
            .processSnoozedReminders();
      }
    } catch (e, stack) {
      logger.error(
        'Failed to process due reminders',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Handle notification tap
  Future<void> handleNotificationTap(String? payload) async {
    if (payload == null) return;

    try {
      // Parse payload to determine action
      // This would typically navigate to the relevant note
      logger.info('Notification tapped', data: {'payload': payload});

      analytics.event('notification.tapped', properties: {
        'payload': payload,
      });
    } catch (e, stack) {
      logger.error(
        'Failed to handle notification tap',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await Future.wait([
        _recurringService.dispose(),
        _geofenceService.dispose(),
        _snoozeService.dispose(),
      ]);

      logger.info('ReminderCoordinator disposed');
    } catch (e) {
      logger.warning('Error disposing ReminderCoordinator: $e');
    }
  }

  /// Get statistics about reminders
  Future<Map<String, dynamic>> getReminderStatistics() async {
    try {
      final active = await getActiveReminders();
      final snoozeStats =
          await (_snoozeService as SnoozeReminderService).getSnoozeStats();

      return {
        'total_active': active.length,
        'by_type': {
          'time': active.where((r) => r.type == ReminderType.time).length,
          'recurring':
              active.where((r) => r.type == ReminderType.recurring).length,
          'location':
              active.where((r) => r.type == ReminderType.location).length,
        },
        'snooze_stats': snoozeStats,
      };
    } catch (e, stack) {
      logger.error(
        'Failed to get reminder statistics',
        error: e,
        stackTrace: stack,
      );
      return {};
    }
  }
}
