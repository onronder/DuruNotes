import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/monitoring/app_logger.dart';
import '../../data/local/app_db.dart';
import '../analytics/analytics_service.dart';

/// Service responsible for managing snooze functionality for reminders.
/// 
/// This service handles:
/// - Snoozing reminders for various durations (5min, 15min, 1hr, etc.)
/// - Calculating appropriate snooze times including smart scheduling
/// - Rescheduling snoozed reminders when snooze period expires
/// - Managing snooze counts and limits
class SnoozeReminderService {
  SnoozeReminderService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  
  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';
  
  /// Maximum number of times a reminder can be snoozed
  static const int maxSnoozeCount = 5;

  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  /// Snooze a reminder for the specified duration
  Future<bool> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    try {
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null) {
        logger.warn('Cannot snooze reminder $reminderId - not found');
        return false;
      }
      
      // Check snooze limit
      if (reminder.snoozeCount >= maxSnoozeCount) {
        logger.warn('Cannot snooze reminder $reminderId - max snooze count reached');
        analytics.event('reminder.snooze_limit_reached', properties: {
          'reminder_id': reminderId,
          'snooze_count': reminder.snoozeCount,
        });
        return false;
      }
      
      final snoozeUntil = _calculateSnoozeTime(duration);
      
      // Update database with snooze information
      await _db.snoozeReminder(reminderId, snoozeUntil);
      
      // Cancel current notification
      await _cancelNotification(reminderId);
      
      // Reschedule for snooze time if it's a time-based reminder
      if (reminder.type == ReminderType.time) {
        await _scheduleSnoozeNotification(
          reminderId,
          snoozeUntil,
          reminder.title,
          reminder.body,
          customTitle: reminder.notificationTitle,
          customBody: reminder.notificationBody,
        );
      }
      
      analytics.event('reminder.snoozed', properties: {
        'duration': duration.name,
        'snooze_count': reminder.snoozeCount + 1,
        'reminder_type': reminder.type.name,
      });
      
      logger.info('Snoozed reminder $reminderId until $snoozeUntil');
      return true;
      
    } catch (e, stack) {
      logger.error('Failed to snooze reminder', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Calculate snooze time based on duration with smart scheduling
  DateTime _calculateSnoozeTime(SnoozeDuration duration) {
    final now = DateTime.now().toUtc();
    
    switch (duration) {
      case SnoozeDuration.fiveMinutes:
        return now.add(const Duration(minutes: 5));
        
      case SnoozeDuration.tenMinutes:
        return now.add(const Duration(minutes: 10));
        
      case SnoozeDuration.fifteenMinutes:
        return now.add(const Duration(minutes: 15));
        
      case SnoozeDuration.thirtyMinutes:
        return now.add(const Duration(minutes: 30));
        
      case SnoozeDuration.oneHour:
        return now.add(const Duration(hours: 1));
        
      case SnoozeDuration.twoHours:
        return now.add(const Duration(hours: 2));
        
      case SnoozeDuration.tomorrow:
        return _calculateTomorrowMorning(now);
    }
  }

  /// Calculate appropriate "tomorrow morning" time
  DateTime _calculateTomorrowMorning(DateTime now) {
    final tomorrow = now.add(const Duration(days: 1));
    
    // Smart scheduling: if it's late at night, schedule for 9 AM
    // If it's early morning, schedule for later in the morning
    int hour = 9; // Default 9 AM
    
    if (now.hour >= 22 || now.hour <= 6) {
      // Late night or very early morning - schedule for 9 AM
      hour = 9;
    } else if (now.hour <= 12) {
      // Morning - schedule for 2 PM
      hour = 14;
    } else {
      // Afternoon/evening - schedule for 9 AM next day
      hour = 9;
    }
    
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, 0);
  }

  /// Schedule a notification for when snooze period expires
  Future<void> _scheduleSnoozeNotification(
    int reminderId,
    DateTime snoozeUntil,
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
        'snoozed': true,
      });
      
      final localTime = tz.TZDateTime.from(snoozeUntil, tz.local);
      
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
            actions: _getSnoozeNotificationActions(reminderId),
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
      
      logger.info('Scheduled snooze notification for reminder $reminderId at $localTime');
      
    } catch (e, stack) {
      logger.error('Failed to schedule snooze notification', 
          error: e, stackTrace: stack);
    }
  }

  /// Get notification actions with reduced snooze options after multiple snoozes
  List<AndroidNotificationAction> _getSnoozeNotificationActions(int reminderId) {
    return [
      const AndroidNotificationAction(
        'snooze_15',
        'Snooze 15m',
        icon: DrawableResourceAndroidBitmap('ic_snooze'),
      ),
      const AndroidNotificationAction(
        'snooze_1h',
        'Snooze 1h',
        icon: DrawableResourceAndroidBitmap('ic_snooze'),
      ),
      const AndroidNotificationAction(
        'complete',
        'Mark Done',
        icon: DrawableResourceAndroidBitmap('ic_check'),
      ),
    ];
  }

  /// Process snoozed reminders that need to be rescheduled
  Future<void> processSnoozedReminders() async {
    try {
      final now = DateTime.now().toUtc();
      
      // Get snoozed reminders that should be rescheduled
      final snoozedReminders = await _db.getSnoozedRemindersToReschedule(now: now);
      
      for (final reminder in snoozedReminders) {
        await _rescheduleSnoozedReminder(reminder);
      }
      
      if (snoozedReminders.isNotEmpty) {
        logger.info('Rescheduled ${snoozedReminders.length} snoozed reminders');
      }
      
    } catch (e, stack) {
      logger.error('Failed to process snoozed reminders', 
          error: e, stackTrace: stack);
    }
  }

  /// Reschedule a snoozed reminder
  Future<void> _rescheduleSnoozedReminder(NoteReminder reminder) async {
    try {
      // Clear snooze status
      await _db.clearSnooze(reminder.id);
      
      if (reminder.type == ReminderType.time && reminder.snoozedUntil != null) {
        // Reschedule notification for the original snooze time
        await _scheduleSnoozeNotification(
          reminder.id,
          reminder.snoozedUntil!,
          reminder.title,
          reminder.body,
          customTitle: reminder.notificationTitle,
          customBody: reminder.notificationBody,
        );
      }
      
      analytics.event('reminder.snooze_expired', properties: {
        'reminder_id': reminder.id,
        'snooze_count': reminder.snoozeCount,
      });
      
    } catch (e, stack) {
      logger.error('Failed to reschedule snoozed reminder', 
          error: e, stackTrace: stack);
    }
  }

  /// Handle snooze action from notification
  Future<void> handleSnoozeAction(String action, String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final reminderId = data['reminderId'] as int?;
      
      if (reminderId == null) {
        logger.warn('Invalid payload for snooze action: missing reminderId');
        return;
      }
      
      SnoozeDuration? duration;
      switch (action) {
        case 'snooze_5':
          duration = SnoozeDuration.fiveMinutes;
          break;
        case 'snooze_15':
          duration = SnoozeDuration.fifteenMinutes;
          break;
        case 'snooze_1h':
          duration = SnoozeDuration.oneHour;
          break;
        case 'complete':
          await _db.deactivateReminder(reminderId);
          analytics.event('reminder.completed_from_notification');
          return;
      }
      
      if (duration != null) {
        await snoozeReminder(reminderId, duration);
      }
      
    } catch (e, stack) {
      logger.error('Failed to handle snooze action', error: e, stackTrace: stack);
    }
  }

  /// Cancel a notification
  Future<void> _cancelNotification(int reminderId) async {
    final notificationId = _generateNotificationId(reminderId);
    await _plugin.cancel(notificationId);
  }

  /// Generate stable notification ID
  int _generateNotificationId(int reminderId) {
    return reminderId.hashCode.abs();
  }

  /// Get snooze statistics for analytics
  Future<Map<String, dynamic>> getSnoozeStats() async {
    try {
      // TODO: Implement database methods for snooze analytics
      // final totalSnoozed = await _db.getTotalSnoozedCount();
      // final averageSnoozeCount = await _db.getAverageSnoozeCount();
      
      return {
        'total_snoozed': 0, // totalSnoozed,
        'average_snooze_count': 0.0, // averageSnoozeCount,
        'max_snooze_limit': maxSnoozeCount,
      };
    } catch (e, stack) {
      logger.error('Failed to get snooze stats', error: e, stackTrace: stack);
      return {};
    }
  }

  /// Clear all snooze data for a reminder (when manually edited)
  Future<void> clearSnooze(int reminderId) async {
    try {
      await _db.clearSnooze(reminderId);
      await _cancelNotification(reminderId);
      
      logger.info('Cleared snooze for reminder $reminderId');
    } catch (e, stack) {
      logger.error('Failed to clear snooze', error: e, stackTrace: stack);
    }
  }
}



/// Extension methods for easier snooze duration handling
extension SnoozeDurationExtensions on SnoozeDuration {
  /// Get display name for snooze duration
  String get displayName {
    switch (this) {
      case SnoozeDuration.fiveMinutes:
        return '5 minutes';
      case SnoozeDuration.tenMinutes:
        return '10 minutes';
      case SnoozeDuration.fifteenMinutes:
        return '15 minutes';
      case SnoozeDuration.thirtyMinutes:
        return '30 minutes';
      case SnoozeDuration.oneHour:
        return '1 hour';
      case SnoozeDuration.twoHours:
        return '2 hours';
      case SnoozeDuration.tomorrow:
        return 'Tomorrow morning';
    }
  }
  
  /// Get appropriate icon for snooze duration
  IconData get icon {
    switch (this) {
      case SnoozeDuration.fiveMinutes:
      case SnoozeDuration.tenMinutes:
      case SnoozeDuration.fifteenMinutes:
      case SnoozeDuration.thirtyMinutes:
        return Icons.snooze;
      case SnoozeDuration.oneHour:
      case SnoozeDuration.twoHours:
        return Icons.access_time;
      case SnoozeDuration.tomorrow:
        return Icons.today;
    }
  }

  /// Get estimated minutes for sorting/comparison
  int get estimatedMinutes {
    switch (this) {
      case SnoozeDuration.fiveMinutes:
        return 5;
      case SnoozeDuration.tenMinutes:
        return 10;
      case SnoozeDuration.fifteenMinutes:
        return 15;
      case SnoozeDuration.thirtyMinutes:
        return 30;
      case SnoozeDuration.oneHour:
        return 60;
      case SnoozeDuration.twoHours:
        return 120;
      case SnoozeDuration.tomorrow:
        return 12 * 60; // Approximate 12 hours
    }
  }
}
