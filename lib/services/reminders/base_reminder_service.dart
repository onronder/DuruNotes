import 'dart:io';

import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Configuration for creating reminders
class ReminderConfig {
  final String noteId;
  final String title;
  final String? body;
  final DateTime scheduledTime;
  final RecurrencePattern recurrencePattern;
  final int recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final String? customNotificationTitle;
  final String? customNotificationBody;
  final Map<String, dynamic>? metadata;

  const ReminderConfig({
    required this.noteId,
    required this.title,
    this.body,
    required this.scheduledTime,
    this.recurrencePattern = RecurrencePattern.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.customNotificationTitle,
    this.customNotificationBody,
    this.metadata,
  });

  /// Convert to database companion for insertion
  ///
  /// P0.5 SECURITY: Requires userId to prevent cross-user reminder creation
  NoteRemindersCompanion toCompanion(ReminderType reminderType, String userId) {
    return NoteRemindersCompanion.insert(
      noteId: noteId, // Required, passed directly
      userId: userId, // P0.5 SECURITY: Required for user isolation
      type: reminderType, // Required, passed directly
      title: Value(title),
      body: Value(body ?? ''),
      remindAt: Value(scheduledTime),
      recurrencePattern: Value(recurrencePattern),
      recurrenceInterval: Value(recurrenceInterval),
      recurrenceEndDate: recurrenceEndDate != null
          ? Value(recurrenceEndDate)
          : const Value.absent(),
      notificationTitle: customNotificationTitle != null
          ? Value(customNotificationTitle)
          : const Value.absent(),
      notificationBody: customNotificationBody != null
          ? Value(customNotificationBody)
          : const Value.absent(),
      // Metadata fields should be handled separately by specific services
      // (e.g., latitude, longitude for geofence reminders)
    );
  }
}

/// Data for scheduling notifications
class ReminderNotificationData {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String? payload;
  final Map<String, dynamic>? extras;

  const ReminderNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
    this.extras,
  });
}

/// Base class for all reminder services
///
/// This class provides common functionality for different types of reminders
/// including permission management, database operations, and analytics.
///
/// Subclasses should override [createReminder] to implement specific logic.
///
/// Example:
/// ```dart
/// class MyReminderService extends BaseReminderService {
///   @override
///   Future<int?> createReminder(ReminderConfig config) {
///     // Implementation
///   }
/// }
/// ```
abstract class BaseReminderService {
  BaseReminderService(this._ref, this.plugin, this.db);

  // Shared dependencies
  final Ref _ref;
  final FlutterLocalNotificationsPlugin plugin;
  final AppDb db;
  AppLogger get logger => _ref.read(loggerProvider);
  AnalyticsService get analytics => _ref.read(analyticsProvider);

  /// P0.5 SECURITY: Get current user ID for reminder operations
  String? get currentUserId {
    try {
      return _ref.read(supabaseClientProvider).auth.currentUser?.id;
    } catch (e) {
      logger.warning('Failed to get current user ID: $e');
      return null;
    }
  }

  // Channel configuration
  static const String channelId = 'notes_reminders';
  static const String channelName = 'Notes Reminders';
  static const String channelDescription = 'Reminders for your notes';

  // Common permission management

  /// Request notification permissions based on platform
  Future<bool> requestNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        final result = await plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        logger.info('iOS notification permission result: $result');
        analytics.event(
          'permission_requested',
          properties: {
            'type': 'notification',
            'platform': 'iOS',
            'granted': result ?? false,
          },
        );
        return result ?? false;
      } else {
        final status = await Permission.notification.request();
        final granted = status.isGranted;

        logger.info('Android notification permission status: $status');
        analytics.event(
          'permission_requested',
          properties: {
            'type': 'notification',
            'platform': 'Android',
            'granted': granted,
          },
        );
        return granted;
      }
    } catch (e, stack) {
      logger.error(
        'Failed to request notification permissions',
        error: e,
        stackTrace: stack,
      );
      analytics.event(
        'permission_request_failed',
        properties: {
          'type': 'notification',
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Check if notification permissions are granted
  Future<bool> hasNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      // iOS handles permissions differently, assume true if initialized
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed to check notification permissions',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  // Shared database operations

  /// Create a reminder in the database
  Future<int?> createReminderInDb(NoteRemindersCompanion companion) async {
    try {
      analytics.startTiming('db_create_reminder');

      final reminderId = await db.createReminder(companion);

      analytics.endTiming(
        'db_create_reminder',
        properties: {'success': true},
      );

      logger.info('Created reminder in database', data: {'id': reminderId});
      return reminderId;
    } catch (e, stack) {
      logger.error(
        'Failed to create reminder in database',
        error: e,
        stackTrace: stack,
      );
      analytics.endTiming(
        'db_create_reminder',
        properties: {'success': false, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Update reminder active status in the database
  Future<void> updateReminderStatus(int id, bool isActive) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot update reminder status - no authenticated user');
        return;
      }

      await db.updateReminder(
        id,
        userId,
        NoteRemindersCompanion(isActive: Value(isActive)),
      );

      logger.info('Updated reminder status', data: {
        'id': id,
        'isActive': isActive,
      });

      analytics.event(
        'reminder_status_updated',
        properties: {
          'reminder_id': id,
          'is_active': isActive,
        },
      );
    } catch (e, stack) {
      logger.error(
        'Failed to update reminder status',
        error: e,
        stackTrace: stack,
        data: {'id': id, 'isActive': isActive},
      );
    }
  }

  /// Get all reminders for a note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot get reminders - no authenticated user');
        return [];
      }

      return await db.getRemindersForNote(noteId, userId);
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

  // Common notification scheduling

  /// Schedule a notification using the local notifications plugin
  Future<void> scheduleNotification(ReminderNotificationData data) async {
    try {
      analytics.startTiming('schedule_notification');

      // Ensure timezone is initialized
      if (tz.local.name == 'UTC') {
        logger.warning('Timezone not initialized, using UTC');
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Note Reminder',
        icon: '@mipmap/ic_launcher',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'Snooze',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'complete',
            'Complete',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder_category',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzDate = tz.TZDateTime.from(data.scheduledTime, tz.local);

      await plugin.zonedSchedule(
        data.id,
        data.title,
        data.body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: data.payload,
        // iOS specific parameter removed - deprecated in newer versions
      );

      analytics.endTiming(
        'schedule_notification',
        properties: {'success': true},
      );

      logger.info('Scheduled notification', data: {
        'id': data.id,
        'scheduledTime': data.scheduledTime.toIso8601String(),
      });
    } catch (e, stack) {
      logger.error(
        'Failed to schedule notification',
        error: e,
        stackTrace: stack,
        data: {'id': data.id},
      );

      analytics.endTiming(
        'schedule_notification',
        properties: {'success': false, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    try {
      await plugin.cancel(id);

      logger.info('Cancelled notification', data: {'id': id});
      analytics.event(
        'notification_cancelled',
        properties: {'notification_id': id},
      );
    } catch (e, stack) {
      logger.error(
        'Failed to cancel notification',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
    }
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await plugin.pendingNotificationRequests();
    } catch (e, stack) {
      logger.error(
        'Failed to get pending notifications',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  // Analytics tracking

  /// Track a reminder-related event
  void trackReminderEvent(String event, Map<String, dynamic> properties) {
    analytics.event(event, properties: properties);
  }

  /// Track feature usage
  void trackFeatureUsage(String feature, {Map<String, dynamic>? properties}) {
    analytics.featureUsed(
      feature,
      properties: properties ?? {},
    );
  }

  // Template methods for subclasses

  /// Create a reminder with the given configuration
  ///
  /// Subclasses must implement this method to provide specific reminder logic
  Future<int?> createReminder(ReminderConfig config);

  /// Cancel a reminder by ID
  ///
  /// Default implementation cancels the notification and deactivates the reminder
  Future<void> cancelReminder(int id) async {
    await cancelNotification(id);
    await updateReminderStatus(id, false);

    trackReminderEvent('reminder_cancelled', {'reminder_id': id});
  }

  /// Initialize the service
  ///
  /// Subclasses can override to add specific initialization logic
  Future<void> initialize() async {
    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    logger.info('$runtimeType initialized');
    analytics.event(
      'service_initialized',
      properties: {'service': runtimeType.toString()},
    );
  }

  /// Clean up resources
  ///
  /// Subclasses can override to add specific cleanup logic
  Future<void> dispose() async {
    logger.info('$runtimeType disposed');
  }
}
