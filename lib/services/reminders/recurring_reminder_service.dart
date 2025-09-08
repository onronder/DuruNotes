import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service responsible for managing recurring time-based reminders.
/// 
/// This service handles:
/// - Creating and scheduling recurring reminders (daily, weekly, monthly, yearly)
/// - Calculating next occurrence times for recurring patterns
/// - Managing recurrence end dates and intervals
/// - Scheduling notifications for time-based reminders
class RecurringReminderService {
  RecurringReminderService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  
  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';

  final AppLogger logger = LoggerFactory.instance;
  final AnalyticsService analytics = AnalyticsFactory.instance;

  /// Create a time-based reminder with optional recurrence
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
    try {
      // Validate time
      if (remindAtUtc.isBefore(DateTime.now().toUtc())) {
        logger.warn('Cannot create reminder - time is in the past');
        return null;
      }
      
      // Validate recurrence parameters
      if (recurrence != RecurrencePattern.none && recurrenceInterval < 1) {
        logger.warn('Invalid recurrence interval: $recurrenceInterval');
        return null;
      }
      
      // Create reminder in database
      final reminderId = await _db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: noteId,
          title: Value(title),
          body: Value(body),
          type: ReminderType.recurring,
          remindAt: Value(remindAtUtc),
          recurrencePattern: Value(recurrence),
          recurrenceInterval: Value(recurrenceInterval),
          recurrenceEndDate: Value(recurrenceEndDate),
          notificationTitle: Value(customNotificationTitle),
          notificationBody: Value(customNotificationBody),
          timeZone: Value(DateTime.now().timeZoneName),
        ),
      );
      
      // Schedule the notification
      await _scheduleNotification(reminderId, remindAtUtc, title, body, 
          customTitle: customNotificationTitle, customBody: customNotificationBody);
      
      // If recurring, schedule next occurrence
      if (recurrence != RecurrencePattern.none) {
        await _scheduleNextRecurrence(reminderId, remindAtUtc, recurrence, recurrenceInterval);
      }
      
      analytics.event(AnalyticsEvents.reminderSet, properties: {
        'type': 'time',
        'has_recurrence': recurrence != RecurrencePattern.none,
        'recurrence_pattern': recurrence.name,
        'hours_from_now': remindAtUtc.difference(DateTime.now().toUtc()).inHours,
      });
      
      return reminderId;
      
    } catch (e, stack) {
      logger.error('Failed to create time reminder', error: e, stackTrace: stack);
      analytics.event('reminder.create_error', properties: {
        'type': 'time',
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Schedule next occurrence for recurring reminders
  Future<void> _scheduleNextRecurrence(
    int reminderId, 
    DateTime currentTime, 
    RecurrencePattern pattern, 
    int interval,
  ) async {
    final nextTime = calculateNextOccurrence(currentTime, pattern, interval);
    
    if (nextTime != null) {
      // Update the reminder with next occurrence time
      await _db.updateReminder(reminderId, NoteRemindersCompanion(
        remindAt: Value(nextTime.toUtc()),
      ));
      
      // Schedule the next notification
      final reminder = await _db.getReminderById(reminderId);
      if (reminder != null) {
        await _scheduleNotification(
          reminderId, 
          nextTime.toUtc(), 
          reminder.title, 
          reminder.body,
          customTitle: reminder.notificationTitle,
          customBody: reminder.notificationBody,
        );
        
        logger.info('Scheduled next recurrence for reminder $reminderId at $nextTime');
      }
    }
  }

  /// Calculate the next occurrence time for a recurring pattern
  DateTime? calculateNextOccurrence(
    DateTime currentTime, 
    RecurrencePattern pattern, 
    int interval,
  ) {
    switch (pattern) {
      case RecurrencePattern.daily:
        return currentTime.add(Duration(days: interval));
        
      case RecurrencePattern.weekly:
        return currentTime.add(Duration(days: 7 * interval));
        
      case RecurrencePattern.monthly:
        final nextMonth = DateTime(
          currentTime.year,
          currentTime.month + interval,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
        // Handle edge case where day doesn't exist in next month (e.g., Jan 31 -> Feb)
        return _adjustForValidDate(nextMonth);
        
      case RecurrencePattern.yearly:
        final nextYear = DateTime(
          currentTime.year + interval,
          currentTime.month,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
        // Handle leap year edge case (Feb 29)
        return _adjustForValidDate(nextYear);
        
      case RecurrencePattern.none:
        return null;
    }
  }

  /// Adjust date to handle edge cases like Feb 29 or days that don't exist in a month
  DateTime _adjustForValidDate(DateTime date) {
    try {
      // Try to create the date - this will throw if invalid
      return DateTime(date.year, date.month, date.day, date.hour, date.minute);
    } catch (e) {
      // If date is invalid (e.g., Feb 29 in non-leap year), use last day of month
      final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
      return DateTime(
        date.year, 
        date.month, 
        lastDayOfMonth.day, 
        date.hour, 
        date.minute,
      );
    }
  }

  /// Schedule a time-based notification
  Future<void> _scheduleNotification(
    int reminderId,
    DateTime remindAtUtc,
    String title,
    String body, {
    String? customTitle,
    String? customBody,
  }) async {
    try {
      final notificationId = _generateNotificationId(reminderId);
      final payload = jsonEncode({
        'reminderId': reminderId,
        'type': 'time',
      });
      
      final localTime = tz.TZDateTime.from(remindAtUtc, tz.local);
      
      await _plugin.zonedSchedule(
        notificationId,
        customTitle ?? title,
        customBody ?? body,
        localTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: _getNotificationActions(),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      
      logger.info('Scheduled notification for reminder $reminderId at $localTime');
      
    } catch (e, stack) {
      logger.error('Failed to schedule notification', error: e, stackTrace: stack);
    }
  }

  /// Get notification action buttons
  List<AndroidNotificationAction> _getNotificationActions() {
    return [
      const AndroidNotificationAction(
        'snooze_5',
        'Snooze 5m',
        icon: DrawableResourceAndroidBitmap('ic_snooze'),
      ),
      const AndroidNotificationAction(
        'snooze_15',
        'Snooze 15m',
        icon: DrawableResourceAndroidBitmap('ic_snooze'),
      ),
      const AndroidNotificationAction(
        'complete',
        'Mark Done',
        icon: DrawableResourceAndroidBitmap('ic_check'),
      ),
    ];
  }

  /// Process due reminders and trigger recurring notifications
  Future<void> processDueReminders() async {
    try {
      final now = DateTime.now().toUtc();
      
      // Get time-based reminders that are due
      final dueReminders = await _db.getTimeRemindersToTrigger(before: now);
      
      for (final reminder in dueReminders) {
        await _triggerTimeReminder(reminder);
      }
      
      if (dueReminders.isNotEmpty) {
        logger.info('Processed ${dueReminders.length} due reminders');
      }
      
    } catch (e, stack) {
      logger.error('Failed to process due reminders', error: e, stackTrace: stack);
    }
  }

  /// Trigger a time-based reminder and handle recurrence
  Future<void> _triggerTimeReminder(NoteReminder reminder) async {
    try {
      // Mark as triggered
      await _db.markReminderTriggered(reminder.id);
      
      // If recurring, schedule next occurrence
      if (reminder.recurrencePattern != RecurrencePattern.none && reminder.remindAt != null) {
        // Check if recurrence has ended
        if (reminder.recurrenceEndDate != null && 
            DateTime.now().toUtc().isAfter(reminder.recurrenceEndDate!)) {
          // Recurrence period has ended, deactivate reminder
          await _db.deactivateReminder(reminder.id);
          logger.info('Recurrence ended for reminder ${reminder.id}');
        } else {
          // Schedule next occurrence
          await _scheduleNextRecurrence(
            reminder.id,
            reminder.remindAt!,
            reminder.recurrencePattern,
            reminder.recurrenceInterval,
          );
        }
      } else {
        // Deactivate non-recurring reminder
        await _db.deactivateReminder(reminder.id);
      }
      
      analytics.event('reminder.triggered', properties: {
        'type': 'time',
        'is_recurring': reminder.recurrencePattern != RecurrencePattern.none,
        'recurrence_pattern': reminder.recurrencePattern.name,
      });
      
    } catch (e, stack) {
      logger.error('Failed to trigger time reminder', error: e, stackTrace: stack);
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int reminderId) async {
    final notificationId = _generateNotificationId(reminderId);
    await _plugin.cancel(notificationId);
    logger.info('Cancelled notification for reminder $reminderId');
  }

  /// Generate stable notification ID from reminder ID
  int _generateNotificationId(int reminderId) {
    return reminderId.hashCode.abs();
  }

  /// Update a recurring reminder's pattern or interval
  Future<void> updateRecurrencePattern({
    required int reminderId,
    required RecurrencePattern newPattern,
    required int newInterval,
    DateTime? newEndDate,
  }) async {
    try {
      // Update database
      await _db.updateReminder(reminderId, NoteRemindersCompanion(
        recurrencePattern: Value(newPattern),
        recurrenceInterval: Value(newInterval),
        recurrenceEndDate: Value(newEndDate),
      ));
      
      // Cancel existing notification
      await cancelNotification(reminderId);
      
      // If pattern is not none, reschedule with new pattern
      if (newPattern != RecurrencePattern.none) {
        final reminder = await _db.getReminderById(reminderId);
        if (reminder?.remindAt != null) {
          await _scheduleNextRecurrence(
            reminderId, 
            reminder!.remindAt!, 
            newPattern, 
            newInterval,
          );
        }
      }
      
      logger.info('Updated recurrence pattern for reminder $reminderId');
      
    } catch (e, stack) {
      logger.error('Failed to update recurrence pattern', 
          error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get next few occurrences for a recurring reminder (for preview)
  List<DateTime> getUpcomingOccurrences(
    DateTime startTime,
    RecurrencePattern pattern,
    int interval, {
    int count = 5,
    DateTime? endDate,
  }) {
    final occurrences = <DateTime>[];
    var current = startTime;
    
    for (var i = 0; i < count; i++) {
      final next = calculateNextOccurrence(current, pattern, interval);
      if (next == null) break;
      
      // Check if we've exceeded the end date
      if (endDate != null && next.isAfter(endDate)) break;
      
      occurrences.add(next);
      current = next;
    }
    
    return occurrences;
  }
}

/// Extension methods for recurrence patterns
extension RecurrencePatternExtensions on RecurrencePattern {
  /// Get display name for recurrence pattern
  String get displayName {
    switch (this) {
      case RecurrencePattern.none:
        return 'No repeat';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
      case RecurrencePattern.yearly:
        return 'Yearly';
    }
  }

  /// Get description with interval
  String getDisplayNameWithInterval(int interval) {
    if (interval <= 1) return displayName;
    
    switch (this) {
      case RecurrencePattern.none:
        return 'No repeat';
      case RecurrencePattern.daily:
        return 'Every $interval days';
      case RecurrencePattern.weekly:
        return 'Every $interval weeks';
      case RecurrencePattern.monthly:
        return 'Every $interval months';
      case RecurrencePattern.yearly:
        return 'Every $interval years';
    }
  }
}
