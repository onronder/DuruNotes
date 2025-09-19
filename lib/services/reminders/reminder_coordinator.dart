import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart' hide NoteReminder;
import 'package:duru_notes/models/note_reminder.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/reminders/geofence_reminder_service.dart';
import 'package:duru_notes/services/reminders/recurring_reminder_service.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Coordinator service that manages all reminder functionalities.
///
/// Acts as a facade for:
/// - [GeofenceReminderService] for location-based reminders
/// - [RecurringReminderService] for time-based & recurring reminders
/// - [SnoozeReminderService] for snooze functionality
class ReminderCoordinator {
  ReminderCoordinator(this._plugin, this._db) {
    _geofenceService = GeofenceReminderService(_plugin, _db);
    _recurringService = RecurringReminderService(_plugin, _db);
    // _snoozeService = SnoozeReminderService(_plugin, _db);  // Reserved for snooze functionality
  }

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  late final GeofenceReminderService _geofenceService;
  late final RecurringReminderService _recurringService;
  // late final SnoozeReminderService _snoozeService;  // Reserved for snooze functionality

  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';

  bool _initialized = false;
  final AppLogger logger = LoggerFactory.instance;
  final AnalyticsService analytics = AnalyticsFactory.instance;

  /// Initialize all sub-services and notification channel
  Future<void> initialize() async {
    if (_initialized) return;
    // Create main notification channel for reminders
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Initialize geofence sub-service (recurring and snooze may initialize on demand)
    try {
      await _geofenceService.initialize();
    } catch (e, stack) {
      logger.error(
        'Failed to initialize geofence service',
        error: e,
        stackTrace: stack,
      );
    }
    _initialized = true;
    logger.info('ReminderCoordinator initialized');
    analytics.event(
      'app.feature_enabled',
      properties: {'feature': 'reminder_coordinator'},
    );
  }

  // Permission Management

  Future<bool> requestNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        final result = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return result ?? false;
      } else {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
    } catch (e, stack) {
      logger.error(
        'Failed to request notification permissions',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<bool> hasNotificationPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true; // iOS handles notifications via requestPermissions
  }

  Future<bool> requestLocationPermissions() async {
    return _geofenceService.requestLocationPermissions();
  }

  Future<bool> hasLocationPermissions() async {
    return _geofenceService.hasLocationPermissions();
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
      // Ensure notification permission
      await requestNotificationPermissions();
    }
    // Delegate to recurring service
    return _recurringService.createTimeReminder(
      noteId: noteId,
      title: title,
      body: body,
      remindAtUtc: remindAtUtc,
      recurrence: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );
  }

  /// Create a location-based reminder (geofence)
  Future<int?> createLocationReminder({
    required String noteId,
    required String title,
    required String body,
    required double latitude,
    required double longitude,
    required double radius,
    String? locationName,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    await initialize();
    if (!await hasNotificationPermissions()) {
      await requestNotificationPermissions();
    }
    // Delegate to geofence service
    return _geofenceService.createLocationReminder(
      noteId: noteId,
      title: title,
      body: body,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      locationName: locationName,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );
  }

  /// Get all reminders for a specific note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      final dbReminders = await _db.getRemindersForNote(noteId);
      // Convert database NoteReminder objects to domain NoteReminder objects
      return dbReminders.map((r) {
        return NoteReminder(
          id: r.id,
          noteId: r.noteId,
          title: r.title,
          body: r.body,
          type: r.type,
          scheduledTime: r.remindAt ?? DateTime.now(),
          remindAt: r.remindAt,
          isSnoozed:
              r.snoozedUntil != null && r.snoozedUntil!.isAfter(DateTime.now()),
          snoozedUntil: r.snoozedUntil,
          isActive: r.isActive ?? true,
          recurrencePattern: r.recurrencePattern,
          recurrenceInterval: r.recurrenceInterval,
          recurrenceEndDate: r.recurrenceEndDate,
          latitude: r.latitude,
          longitude: r.longitude,
          radius: r.radius,
          locationName: r.locationName,
          notificationTitle: r.notificationTitle,
          notificationBody: r.notificationBody,
          timeZone: r.timeZone,
          createdAt: r.createdAt,
          updatedAt: r.lastTriggered ?? r.createdAt,
        );
      }).toList();
    } catch (e, stack) {
      logger.error(
        'Failed to get reminders for note',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Dispose of sub-services
  Future<void> dispose() async {
    try {
      await _geofenceService.dispose();
      logger.info('ReminderCoordinator disposed');
    } catch (e) {
      logger.warning('Error disposing ReminderCoordinator: $e');
    }
  }
}

/// Provider for `ReminderCoordinator`
final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);
  return ReminderCoordinator(plugin, db);
});

// Note: Use advancedReminderServiceProvider from advanced_reminder_service.dart
// This provider is deprecated - use reminderCoordinatorProvider directly

/// Provider for the local database (Drift AppDb instance)
final appDbProvider = Provider<AppDb>((ref) => AppDb());
