import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/monitoring/app_logger.dart';
import '../data/local/app_db.dart';
import 'analytics/analytics_service.dart';
import 'analytics/analytics_sentry.dart';

/// Service for scheduling and managing local notifications for note reminders.
/// 
/// Handles:
/// - Notification permissions
/// - Scheduling time-based reminders 
/// - Canceling reminders
/// - Deep link payload for routing to notes
class ReminderService {
  ReminderService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  
  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';
  
  bool _initialized = false;
  
  /// Initialize the service and create notification channels
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Android notification channel
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Create the channel
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
      _initialized = true;
      
      logger.info('ReminderService initialized');
      analytics.event('app.feature_enabled', properties: {
        'feature': 'reminders',
      });
      
    } catch (e, stack) {
      logger.error('Failed to initialize ReminderService', error: e, stackTrace: stack);
      analytics.event('reminder.init_error', properties: {
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      bool granted = false;
      
      if (Platform.isIOS) {
        // iOS permissions
        final result = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        granted = result ?? false;
      } else if (Platform.isAndroid) {
        // Android 13+ permissions
        final status = await Permission.notification.request();
        granted = status.isGranted;
      }
      
      logger.info('Notification permission requested', data: {
        'granted': granted,
        'platform': Platform.operatingSystem,
      });
      
      analytics.event(
        granted ? AnalyticsEvents.reminderPermissionGranted : AnalyticsEvents.reminderPermissionDenied,
        properties: {'platform': Platform.operatingSystem},
      );
      
      return granted;
    } catch (e, stack) {
      logger.error('Failed to request notification permissions', error: e, stackTrace: stack);
      analytics.event('reminder.permission_error', properties: {
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Check if notification permissions are granted
  Future<bool> hasPermissions() async {
    try {
      if (Platform.isIOS) {
        // For iOS, we need to check via the plugin
        // This is a simplified check - in real app you might want to store the permission state
        return true; // Assume granted for now - iOS will show permission dialog if needed
      } else if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    } catch (e) {
      logger.warn('Failed to check notification permissions', error: e);
      return false;
    }
  }
  
  /// Schedule a reminder notification
  Future<bool> schedule({
    required String noteId,
    required DateTime remindAtUtc,
    String? title,
    String? body,
  }) async {
    if (!_initialized) {
      throw StateError('ReminderService not initialized. Call init() first.');
    }
    
    try {
      // Check permissions
      if (!await hasPermissions()) {
        logger.warn('Cannot schedule reminder - no permissions');
        analytics.event(AnalyticsEvents.reminderPermissionDenied);
        return false;
      }
      
      // Check if time is in the future
      if (remindAtUtc.isBefore(DateTime.now().toUtc())) {
        logger.warn('Cannot schedule reminder - time is in the past');
        analytics.event('reminder.schedule_past_time');
        return false;
      }
      
      // Generate stable notification ID from noteId
      final notificationId = _generateNotificationId(noteId);
      
      // Create notification payload
      final payload = jsonEncode({'noteId': noteId});
      
      // Convert UTC to device timezone for scheduling
      final localTime = tz.TZDateTime.from(remindAtUtc, tz.local);
      
      // Schedule the notification
      await _plugin.zonedSchedule(
        notificationId,
        title ?? 'Note Reminder',
        body ?? 'You have a note reminder',
        localTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      
      logger.info('Reminder scheduled successfully', data: {
        'noteId': noteId,
        'remindAt': remindAtUtc.toIso8601String(),
        'localTime': localTime.toIso8601String(),
        'notificationId': notificationId,
      });
      
      analytics.event(AnalyticsEvents.reminderScheduled, properties: {
        'hoursFromNow': remindAtUtc.difference(DateTime.now().toUtc()).inHours,
      });
      
      return true;
      
    } catch (e, stack) {
      logger.error('Failed to schedule reminder', error: e, stackTrace: stack, data: {
        'noteId': noteId,
        'remindAt': remindAtUtc.toIso8601String(),
      });
      
      analytics.event('reminder.schedule_error', properties: {
        'error': e.toString(),
      });
      
      return false;
    }
  }
  
  /// Cancel a scheduled reminder
  Future<void> cancel(String noteId) async {
    try {
      final notificationId = _generateNotificationId(noteId);
      await _plugin.cancel(notificationId);
      
      logger.info('Reminder canceled', data: {
        'noteId': noteId,
        'notificationId': notificationId,
      });
      
      analytics.event(AnalyticsEvents.reminderCanceled);
      
    } catch (e, stack) {
      logger.error('Failed to cancel reminder', error: e, stackTrace: stack, data: {
        'noteId': noteId,
      });
      
      analytics.event('reminder.cancel_error', properties: {
        'error': e.toString(),
      });
    }
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      
      logger.info('All reminders canceled');
      analytics.event('reminder.canceled_all');
      
    } catch (e, stack) {
      logger.error('Failed to cancel all reminders', error: e, stackTrace: stack);
      analytics.event('reminder.cancel_all_error', properties: {
        'error': e.toString(),
      });
    }
  }
  
  /// Cancel reminders for deleted notes
  Future<void> cancelAllForDeletedNotes(Set<String> deletedNoteIds) async {
    try {
      for (final noteId in deletedNoteIds) {
        await cancel(noteId);
      }
      
      logger.info('Canceled reminders for deleted notes', data: {
        'count': deletedNoteIds.length,
      });
      
      analytics.event('reminder.cleanup_deleted', properties: {
        'count': deletedNoteIds.length,
      });
      
    } catch (e, stack) {
      logger.error('Failed to cancel reminders for deleted notes', error: e, stackTrace: stack);
    }
  }
  
  /// Reschedule all reminders (useful after timezone changes)
  Future<void> rescheduleAll() async {
    try {
      // Get all reminders from database
      final reminders = await _db.getAllReminders();
      
      // Cancel all existing notifications
      await cancelAll();
      
      // Reschedule each one
      for (final reminder in reminders) {
        // Get note details for notification content
        final note = await _db.findNote(reminder.noteId);
        if (note != null && !note.deleted) {
          await schedule(
            noteId: reminder.noteId,
            remindAtUtc: reminder.remindAt,
            title: 'Note Reminder',
            body: note.title.isNotEmpty ? note.title : 'You have a note reminder',
          );
        }
      }
      
      logger.info('Rescheduled all reminders', data: {
        'count': reminders.length,
      });
      
      analytics.event('reminder.rescheduled_all', properties: {
        'count': reminders.length,
      });
      
    } catch (e, stack) {
      logger.error('Failed to reschedule all reminders', error: e, stackTrace: stack);
    }
  }
  
  /// Generate a stable notification ID from noteId
  int _generateNotificationId(String noteId) {
    // Use hashCode for a stable integer ID
    return noteId.hashCode.abs();
  }
  
  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      logger.warn('Failed to get pending notifications', error: e);
      return [];
    }
  }
}

/// Provider for ReminderService
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);
  return ReminderService(plugin, db);
});

/// Provider for the database
final appDbProvider = Provider<AppDb>((ref) {
  return AppDb();
});
