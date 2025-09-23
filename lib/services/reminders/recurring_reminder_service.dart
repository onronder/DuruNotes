import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/reminders/base_reminder_service.dart';

/// Service responsible for managing recurring time-based reminders.
///
/// This service extends [BaseReminderService] and handles:
/// - Creating and scheduling recurring reminders (daily, weekly, monthly, yearly)
/// - Calculating next occurrence times for recurring patterns
/// - Managing recurrence end dates and intervals
/// - Scheduling notifications for time-based reminders
class RecurringReminderService extends BaseReminderService {
  RecurringReminderService(
    super.ref,
    super.plugin,
    super.db,
  );

  @override
  Future<int?> createReminder(ReminderConfig config) async {
    try {
      // Validate time
      if (config.scheduledTime.isBefore(DateTime.now())) {
        logger.warning('Cannot create reminder - time is in the past');
        trackReminderEvent('reminder_creation_failed', {
          'reason': 'past_time',
          'type': 'recurring',
        });
        return null;
      }

      // Validate recurrence parameters
      if (config.recurrencePattern != RecurrencePattern.none &&
          config.recurrenceInterval < 1) {
        logger.warning(
            'Invalid recurrence interval: ${config.recurrenceInterval}');
        trackReminderEvent('reminder_creation_failed', {
          'reason': 'invalid_interval',
          'type': 'recurring',
        });
        return null;
      }

      // Check permissions
      if (!await hasNotificationPermissions()) {
        logger.warning('Cannot create reminder - no notification permissions');
        trackReminderEvent('reminder_creation_failed', {
          'reason': 'no_permissions',
          'type': 'recurring',
        });
        return null;
      }

      // Create reminder in database using base class method
      final reminderType = config.recurrencePattern != RecurrencePattern.none
          ? ReminderType.recurring
          : ReminderType.time;
      final reminderId =
          await createReminderInDb(config.toCompanion(reminderType));

      if (reminderId == null) {
        return null;
      }

      // Schedule the notification
      await scheduleNotification(ReminderNotificationData(
        id: reminderId,
        title: config.customNotificationTitle ?? config.title,
        body: config.customNotificationBody ??
            config.body ??
            'Tap to view your note',
        scheduledTime: config.scheduledTime,
        payload: jsonEncode({'reminderId': reminderId, 'type': 'recurring'}),
      ));

      // If recurring, schedule next occurrence
      if (config.recurrencePattern != RecurrencePattern.none) {
        await _scheduleNextRecurrence(
          reminderId,
          config.scheduledTime,
          config.recurrencePattern,
          config.recurrenceInterval,
          config.recurrenceEndDate,
        );
      }

      trackReminderEvent('reminder_created', {
        'type': 'recurring',
        'has_recurrence': config.recurrencePattern != RecurrencePattern.none,
        'recurrence_pattern': config.recurrencePattern.name,
        'hours_from_now':
            config.scheduledTime.difference(DateTime.now()).inHours,
      });

      trackFeatureUsage('recurring_reminder_created', properties: {
        'pattern': config.recurrencePattern.name,
        'interval': config.recurrenceInterval,
      });

      return reminderId;
    } catch (e, stack) {
      logger.error(
        'Failed to create recurring reminder',
        error: e,
        stackTrace: stack,
      );
      trackReminderEvent('reminder_creation_error', {
        'type': 'recurring',
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
    DateTime? endDate,
  ) async {
    final nextTime = calculateNextOccurrence(currentTime, pattern, interval);

    if (nextTime != null) {
      // Check if we've exceeded the end date
      if (endDate != null && nextTime.isAfter(endDate)) {
        await updateReminderStatus(reminderId, false);
        logger.info(
            'Recurrence ended for reminder $reminderId - exceeded end date');
        return;
      }

      // Update the reminder with next occurrence time
      await db.updateReminder(
        reminderId,
        NoteRemindersCompanion(remindAt: Value(nextTime)),
      );

      // Schedule the next notification
      final reminder = await db.getReminderById(reminderId);
      if (reminder != null) {
        await scheduleNotification(ReminderNotificationData(
          id: reminderId,
          title: reminder.notificationTitle ?? reminder.title,
          body: reminder.notificationBody ??
              reminder.body ??
              'Tap to view your note',
          scheduledTime: nextTime,
          payload: jsonEncode({'reminderId': reminderId, 'type': 'recurring'}),
        ));

        logger.info(
          'Scheduled next recurrence for reminder $reminderId at $nextTime',
        );
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
      case RecurrencePattern.none:
        return null;

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

  /// Process due reminders and trigger recurring notifications
  Future<void> processDueReminders() async {
    try {
      final now = DateTime.now();

      // Get time-based reminders that are due
      final dueReminders = await db.getTimeRemindersToTrigger(before: now);

      for (final reminder in dueReminders) {
        await _triggerTimeReminder(reminder);
      }

      if (dueReminders.isNotEmpty) {
        logger.info('Processed ${dueReminders.length} due reminders');
        trackReminderEvent('reminders_processed', {
          'count': dueReminders.length,
          'type': 'recurring',
        });
      }
    } catch (e, stack) {
      logger.error(
        'Failed to process due reminders',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Trigger a time-based reminder and handle recurrence
  Future<void> _triggerTimeReminder(NoteReminder reminder) async {
    try {
      // Mark as triggered
      // Mark as triggered (but keep active for recurring reminders)
      await db.updateReminder(
        reminder.id,
        NoteRemindersCompanion(
          lastTriggered: Value(DateTime.now()),
          triggerCount: Value(reminder.triggerCount + 1),
        ),
      );

      // If recurring, schedule next occurrence
      if (reminder.recurrencePattern != RecurrencePattern.none &&
          reminder.remindAt != null) {
        // Check if recurrence has ended
        if (reminder.recurrenceEndDate != null &&
            DateTime.now().isAfter(reminder.recurrenceEndDate!)) {
          // Recurrence period has ended, deactivate reminder
          await updateReminderStatus(reminder.id, false);
          logger.info('Recurrence ended for reminder ${reminder.id}');
        } else {
          // Schedule next occurrence
          await _scheduleNextRecurrence(
            reminder.id,
            reminder.remindAt!,
            reminder.recurrencePattern,
            reminder.recurrenceInterval,
            reminder.recurrenceEndDate,
          );
        }
      } else {
        // Deactivate non-recurring reminder
        await updateReminderStatus(reminder.id, false);
      }

      trackReminderEvent('reminder_triggered', {
        'type': 'recurring',
        'is_recurring': reminder.recurrencePattern != RecurrencePattern.none,
        'recurrence_pattern': reminder.recurrencePattern.name,
      });
    } catch (e, stack) {
      logger.error(
        'Failed to trigger time reminder',
        error: e,
        stackTrace: stack,
      );
    }
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
      await db.updateReminder(
        reminderId,
        NoteRemindersCompanion(
          recurrencePattern: Value(newPattern),
          recurrenceInterval: Value(newInterval),
          recurrenceEndDate: Value(newEndDate),
        ),
      );

      // Cancel existing notification
      await cancelNotification(reminderId);

      // If pattern is not none, reschedule with new pattern
      if (newPattern != RecurrencePattern.none) {
        final reminder = await db.getReminderById(reminderId);
        if (reminder?.remindAt != null) {
          await _scheduleNextRecurrence(
            reminderId,
            reminder!.remindAt!,
            newPattern,
            newInterval,
            newEndDate,
          );
        }
      }

      logger.info('Updated recurrence pattern for reminder $reminderId');
      trackReminderEvent('recurrence_updated', {
        'reminder_id': reminderId,
        'new_pattern': newPattern.name,
        'new_interval': newInterval,
      });
    } catch (e, stack) {
      logger.error(
        'Failed to update recurrence pattern',
        error: e,
        stackTrace: stack,
      );
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
