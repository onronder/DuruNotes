import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:flutter/material.dart';

// Use SnoozeDuration from app_db.dart instead of defining our own

/// Service responsible for managing snooze functionality for reminders.
///
/// This service extends [BaseReminderService] and handles:
/// - Snoozing reminders for various durations (5min, 15min, 1hr, etc.)
/// - Calculating appropriate snooze times including smart scheduling
/// - Rescheduling snoozed reminders when snooze period expires
/// - Managing snooze counts and limits
class SnoozeReminderService extends BaseReminderService {
  SnoozeReminderService(
    super.ref,
    super.plugin,
    super.db,
  );

  /// Maximum number of times a reminder can be snoozed
  static const int maxSnoozeCount = 5;

  @override
  Future<int?> createReminder(ReminderConfig config) async {
    // Snooze service doesn't create new reminders, it only modifies existing ones
    // This method is required by base class but not used
    logger.warning(
        'SnoozeReminderService.createReminder called but not implemented');
    return null;
  }

  /// Snooze a reminder for the specified duration
  Future<bool> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot snooze reminder - no authenticated user');
        return false;
      }

      final reminder = await db.getReminderById(reminderId, userId);
      if (reminder == null) {
        logger.warning('Cannot snooze reminder $reminderId - not found');
        trackReminderEvent('snooze_failed', {
          'reason': 'not_found',
          'reminder_id': reminderId,
        });
        return false;
      }

      // Check snooze limit
      if (reminder.snoozeCount >= maxSnoozeCount) {
        logger.warning(
          'Cannot snooze reminder $reminderId - max snooze count reached',
        );
        trackReminderEvent('snooze_limit_reached', {
          'reminder_id': reminderId,
          'snooze_count': reminder.snoozeCount,
        });
        return false;
      }

      // Check permissions
      if (!await hasNotificationPermissions()) {
        logger.warning('Cannot snooze reminder - no notification permissions');
        trackReminderEvent('snooze_failed', {
          'reason': 'no_permissions',
          'reminder_id': reminderId,
        });
        return false;
      }

      final snoozeUntil = _calculateSnoozeTime(duration);

      // Update database with snooze information
      // Update snooze information (P0.5 SECURITY: uses userId)
      await db.snoozeReminder(reminderId, userId, snoozeUntil);
      await db.updateReminder(
        reminderId,
        userId,
        NoteRemindersCompanion(
          snoozeCount: Value(reminder.snoozeCount + 1),
        ),
      );

      // Cancel current notification
      await cancelNotification(reminderId);

      // Reschedule for snooze time
      await scheduleNotification(ReminderNotificationData(
        id: reminderId,
        title: reminder.notificationTitle ?? reminder.title,
        body: reminder.notificationBody ?? reminder.body,
        scheduledTime: snoozeUntil,
        payload: jsonEncode({
          'reminderId': reminderId,
          'type': 'snoozed',
          'snoozed': true,
        }),
      ));

      trackReminderEvent('reminder_snoozed', {
        'duration': duration.name,
        'snooze_count': reminder.snoozeCount + 1,
        'reminder_type': reminder.type.name,
      });

      trackFeatureUsage('snooze_used', properties: {
        'duration': duration.name,
        'current_snooze_count': reminder.snoozeCount,
      });

      logger.info('Snoozed reminder $reminderId until $snoozeUntil');
      return true;
    } catch (e, stack) {
      logger.error('Failed to snooze reminder', error: e, stackTrace: stack);
      trackReminderEvent('snooze_error', {
        'reminder_id': reminderId,
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Calculate snooze time based on duration with smart scheduling
  DateTime _calculateSnoozeTime(SnoozeDuration duration) {
    final now = DateTime.now();

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
    var hour = 9; // Default 9 AM

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

    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);
  }

  /// Process snoozed reminders that need to be rescheduled
  Future<void> processSnoozedReminders() async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot process snoozed reminders - no authenticated user');
        return;
      }

      final now = DateTime.now();

      // Get snoozed reminders that should be rescheduled
      final snoozedReminders = await db.getSnoozedRemindersToReschedule(
        now: now,
        userId: userId,
      );

      for (final reminder in snoozedReminders) {
        await _rescheduleSnoozedReminder(reminder);
      }

      if (snoozedReminders.isNotEmpty) {
        logger.info('Rescheduled ${snoozedReminders.length} snoozed reminders');
        trackReminderEvent('snoozed_reminders_processed', {
          'count': snoozedReminders.length,
        });
      }
    } catch (e, stack) {
      logger.error(
        'Failed to process snoozed reminders',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Reschedule a snoozed reminder
  Future<void> _rescheduleSnoozedReminder(NoteReminder reminder) async {
    try {
      // P0.5 SECURITY: Use userId from reminder
      // Clear snooze status
      await db.clearSnooze(reminder.id, reminder.userId);

      if (reminder.snoozedUntil != null) {
        // Reschedule notification for the original snooze time
        await scheduleNotification(ReminderNotificationData(
          id: reminder.id,
          title: reminder.notificationTitle ?? reminder.title,
          body: reminder.notificationBody ?? reminder.body,
          scheduledTime: reminder.snoozedUntil!,
          payload: jsonEncode({
            'reminderId': reminder.id,
            'type': 'snoozed',
            'snooze_expired': true,
          }),
        ));
      }

      trackReminderEvent('snooze_expired', {
        'reminder_id': reminder.id,
        'snooze_count': reminder.snoozeCount,
      });
    } catch (e, stack) {
      logger.error(
        'Failed to reschedule snoozed reminder',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Handle snooze action from notification
  Future<void> handleSnoozeAction(String action, String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final reminderId = data['reminderId'] as int?;

      if (reminderId == null) {
        logger.warning('Invalid payload for snooze action: missing reminderId');
        return;
      }

      SnoozeDuration? duration;
      switch (action) {
        case 'snooze_5':
          duration = SnoozeDuration.fiveMinutes;
        case 'snooze_15':
          duration = SnoozeDuration.fifteenMinutes;
        case 'snooze_1h':
          duration = SnoozeDuration.oneHour;
        case 'complete':
          await updateReminderStatus(reminderId, false);
          trackReminderEvent('reminder_completed_from_notification', {
            'reminder_id': reminderId,
          });
          return;
      }

      if (duration != null) {
        await snoozeReminder(reminderId, duration);
      }
    } catch (e, stack) {
      logger.error(
        'Failed to handle snooze action',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Get snooze statistics for analytics
  Future<Map<String, dynamic>> getSnoozeStats() async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        return {
          'total_snoozed': 0,
          'average_snooze_count': 0.0,
          'max_snooze_limit': maxSnoozeCount,
        };
      }

      // Get basic statistics from reminder data
      final allReminders = await db.getAllReminders(userId);
      final snoozedReminders = allReminders
          .where(
            (r) => r.snoozedUntil != null && r.isActive,
          )
          .toList();
      final totalSnoozeCount = snoozedReminders.fold<int>(
        0,
        (sum, r) => sum + r.snoozeCount,
      );
      final avgSnoozeCount = snoozedReminders.isEmpty
          ? 0.0
          : totalSnoozeCount / snoozedReminders.length;

      final stats = {
        'total_snoozed': snoozedReminders.length,
        'average_snooze_count': avgSnoozeCount,
      };

      return {
        'total_snoozed': stats['total_snoozed'] ?? 0,
        'average_snooze_count': stats['average_snooze_count'] ?? 0.0,
        'max_snooze_limit': maxSnoozeCount,
      };
    } catch (e, stack) {
      logger.error('Failed to get snooze stats', error: e, stackTrace: stack);
      return {
        'total_snoozed': 0,
        'average_snooze_count': 0.0,
        'max_snooze_limit': maxSnoozeCount,
      };
    }
  }

  /// Clear all snooze data for a reminder (when manually edited)
  Future<void> clearSnooze(int reminderId) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot clear snooze - no authenticated user');
        return;
      }

      await db.clearSnooze(reminderId, userId);
      await cancelNotification(reminderId);

      logger.info('Cleared snooze for reminder $reminderId');
      trackReminderEvent('snooze_cleared', {
        'reminder_id': reminderId,
      });
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
