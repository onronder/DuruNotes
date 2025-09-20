import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/main.dart' show navigatorKey;
import 'package:duru_notes/services/deep_link_service.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/ui/enhanced_task_list_screen.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Bridge service that connects task management with the reminder system
class TaskReminderBridge {
  TaskReminderBridge({
    required ReminderCoordinator reminderCoordinator,
    required AdvancedReminderService advancedReminderService,
    required TaskService taskService,
    required AppDb database,
    required FlutterLocalNotificationsPlugin notificationPlugin,
  }) : _reminderCoordinator = reminderCoordinator,
       _advancedReminderService = advancedReminderService,
       _taskService = taskService,
       _db = database,
       _notificationPlugin = notificationPlugin;

  final ReminderCoordinator _reminderCoordinator;
  final AdvancedReminderService _advancedReminderService;
  final TaskService _taskService;
  final AppDb _db;
  final FlutterLocalNotificationsPlugin _notificationPlugin;
  final AppLogger _logger = LoggerFactory.instance;

  static const String _taskChannelId = 'task_reminders';
  static const String _taskChannelName = 'Task Reminders';
  static const String _taskChannelDescription = 'Reminders for your tasks';
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  bool _initialized = false;
  
  // Store pending deep link if app is not ready
  Map<String, dynamic>? _pendingDeepLink;

  /// Initialize the bridge service and create task notification channel
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Process any pending deep link
    if (_pendingDeepLink != null && navigatorKey.currentContext != null) {
      _processPendingDeepLink();
    }

    try {
      // Create dedicated notification channel for tasks
      const channel = AndroidNotificationChannel(
        _taskChannelId,
        _taskChannelName,
        description: _taskChannelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _notificationPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;
      _logger.info('TaskReminderBridge initialized');
    } catch (e, stack) {
      _logger.error(
        'Failed to initialize TaskReminderBridge',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Create a reminder for a task with due date
  Future<int?> createTaskReminder({
    required NoteTask task,
    Duration? beforeDueDate,
  }) async {
    if (task.dueDate == null) return null;

    await initialize();

    // Calculate reminder time (default 1 hour before due date)
    final reminderTime = task.dueDate!.subtract(
      beforeDueDate ?? const Duration(hours: 1),
    );

    // Don't create reminders for past times
    if (reminderTime.isBefore(DateTime.now())) {
      _logger.debug('Skipping past reminder time for task ${task.id}');
      return null;
    }

    // Retry logic for transient failures
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        // Create the reminder
        final reminderId = await _reminderCoordinator.createTimeReminder(
          noteId: task.noteId,
          title: _formatTaskReminderTitle(task),
          body: _formatTaskReminderBody(task),
          remindAtUtc: reminderTime,
          customNotificationTitle: _formatTaskNotificationTitle(task),
          customNotificationBody: _formatTaskNotificationBody(task),
        );

        if (reminderId != null) {
          // Update task with reminder ID
          await _taskService.updateTask(
            taskId: task.id,
            reminderId: reminderId,
          );

          _logger.info('Created and linked task reminder', data: {
            'taskId': task.id,
            'reminderId': reminderId,
            'reminderTime': reminderTime.toIso8601String(),
            'attempts': attempts + 1,
          });
        }

        return reminderId;
      } catch (e, stack) {
        attempts++;
        if (attempts >= _maxRetries) {
          _logger.error(
            'Failed to create task reminder after $attempts attempts',
            error: e,
            stackTrace: stack,
            data: {'taskId': task.id},
          );
          return null;
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(_retryDelay * attempts);
        _logger.warning('Retrying task reminder creation', data: {
          'taskId': task.id,
          'attempt': attempts,
          'error': e.toString(),
        });
      }
    }
    
    return null;
  }

  /// Update task reminder when task changes
  Future<void> updateTaskReminder(NoteTask task) async {
    await initialize();

    try {
      // Cancel existing reminder if it exists
      if (task.reminderId != null) {
        await cancelTaskReminder(task);
      }

      // Create new reminder if task has due date and is not completed
      if (task.dueDate != null && task.status != TaskStatus.completed) {
        final newReminderId = await createTaskReminder(task: task);
        
        // Update task with new reminder ID
        if (newReminderId != null) {
          await _taskService.updateTask(
            taskId: task.id,
            reminderId: newReminderId,
          );
        }
      }

      _logger.debug('Updated task reminder', data: {'taskId': task.id});
    } catch (e, stack) {
      _logger.error(
        'Failed to update task reminder',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
    }
  }

  /// Cancel task reminder
  Future<void> cancelTaskReminder(NoteTask task) async {
    if (task.reminderId == null) return;

    try {
      await _advancedReminderService.deleteReminder(task.reminderId!);
      
      // Clear reminder ID from task
      await _taskService.updateTask(
        taskId: task.id,
        clearReminderId: true,
      );
      
      _logger.info('Cancelled task reminder', data: {
        'taskId': task.id,
        'reminderId': task.reminderId,
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to cancel task reminder',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id, 'reminderId': task.reminderId},
      );
    }
  }

  /// Snooze a task reminder with limit checking
  Future<void> snoozeTaskReminder({
    required NoteTask task,
    required Duration snoozeDuration,
  }) async {
    if (task.reminderId == null || task.dueDate == null) return;

    try {
      // Get the reminder to check snooze count
      final reminder = await _db.getReminderById(task.reminderId!);
      if (reminder == null) {
        _logger.warning('Reminder not found for task ${task.id}');
        return;
      }
      
      // Check snooze limit using SnoozeReminderService
      final snoozeService = _reminderCoordinator.snoozeService;
      
      // Convert duration to SnoozeDuration enum
      final snoozeDurationEnum = _durationToSnoozeDuration(snoozeDuration);
      
      // Use the snooze service for consistent snooze handling
      final success = await snoozeService.snoozeReminder(
        task.reminderId!,
        snoozeDurationEnum,
      );
      
      if (!success) {
        // Max snooze limit reached or other error
        _logger.warning('Could not snooze task reminder', data: {
          'taskId': task.id,
          'reminderId': task.reminderId,
          'reason': 'Snooze limit reached or error',
        });
        
        // Notify user via notification
        await _notifyMaxSnoozeReached(task);
        return;
      }
      
      // Get the updated reminder to get new snooze time
      final updatedReminder = await _db.getReminderById(task.reminderId!);
      if (updatedReminder != null && updatedReminder.snoozedUntil != null) {
        _logger.info('Snoozed task reminder via SnoozeService', data: {
          'taskId': task.id,
          'reminderId': task.reminderId,
          'duration': snoozeDuration.inMinutes,
          'snoozedUntil': updatedReminder.snoozedUntil!.toIso8601String(),
          'snoozeCount': updatedReminder.snoozeCount,
        });
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to snooze task reminder',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
    }
  }
  
  /// Convert Duration to SnoozeDuration enum
  SnoozeDuration _durationToSnoozeDuration(Duration duration) {
    if (duration.inMinutes <= 5) return SnoozeDuration.fiveMinutes;
    if (duration.inMinutes <= 10) return SnoozeDuration.tenMinutes;
    if (duration.inMinutes <= 15) return SnoozeDuration.fifteenMinutes;
    if (duration.inMinutes <= 30) return SnoozeDuration.thirtyMinutes;
    if (duration.inHours <= 1) return SnoozeDuration.oneHour;
    if (duration.inHours <= 2) return SnoozeDuration.twoHours;
    return SnoozeDuration.tomorrow;
  }
  
  /// Snooze task to tomorrow morning with smart scheduling
  Future<void> _snoozeTaskTomorrow(NoteTask task) async {
    try {
      // Calculate tomorrow morning (9 AM by default)
      final tomorrow = _calculateTomorrowMorning();
      final duration = tomorrow.difference(DateTime.now());
      
      await snoozeTaskReminder(
        task: task,
        snoozeDuration: duration,
      );
      
      _logger.info('Snoozed task to tomorrow morning', data: {
        'taskId': task.id,
        'scheduledTime': tomorrow.toIso8601String(),
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to snooze task to tomorrow',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
    }
  }
  
  /// Calculate smart time for tomorrow morning
  DateTime _calculateTomorrowMorning() {
    final now = DateTime.now();
    var tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0); // 9 AM tomorrow
    
    // If it's already past 10 PM, schedule for 10 AM instead of 9 AM
    if (now.hour >= 22) {
      tomorrow = tomorrow.add(const Duration(hours: 1));
    }
    
    // If it's weekend, schedule for 10 AM instead of 9 AM
    if (tomorrow.weekday == DateTime.saturday || tomorrow.weekday == DateTime.sunday) {
      tomorrow = tomorrow.add(const Duration(hours: 1));
    }
    
    return tomorrow;
  }
  
  /// Notify user that max snooze limit has been reached
  Future<void> _notifyMaxSnoozeReached(NoteTask task) async {
    try {
      await _notificationPlugin.show(
        task.id.hashCode + 1000, // Different ID to avoid conflict
        '⚠️ Snooze Limit Reached',
        'Task "${task.content}" has been snoozed 5 times. Please complete or reschedule it.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _taskChannelId,
            _taskChannelName,
            channelDescription: _taskChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFFF9800), // Orange for warning
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to show max snooze notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Handle task notification actions
  Future<void> handleTaskNotificationAction({
    required String action,
    required String payload,
  }) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final taskId = data['taskId'] as String?;
      final noteId = data['noteId'] as String?;

      if (taskId == null) return;

      final task = await _db.getTaskById(taskId);
      if (task == null) return;

      switch (action) {
        case 'complete_task':
          await _completeTaskFromNotification(task);
          break;
        case 'snooze_task_5':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(minutes: 5),
          );
          break;
        case 'snooze_task_10':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(minutes: 10),
          );
          break;
        case 'snooze_task_15':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(minutes: 15),
          );
          break;
        case 'snooze_task_30':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(minutes: 30),
          );
          break;
        case 'snooze_task_1h':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(hours: 1),
          );
          break;
        case 'snooze_task_2h':
          await snoozeTaskReminder(
            task: task,
            snoozeDuration: const Duration(hours: 2),
          );
          break;
        case 'snooze_task_tomorrow':
          await _snoozeTaskTomorrow(task);
          break;
        case 'open_task':
          await _handleOpenTaskFromNotification(taskId, noteId);
          break;
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to handle task notification action',
        error: e,
        stackTrace: stack,
        data: {'action': action, 'payload': payload},
      );
    }
  }

  /// Complete task from notification
  Future<void> _completeTaskFromNotification(NoteTask task) async {
    try {
      await _taskService.completeTask(task.id);
      await cancelTaskReminder(task);

      // Show completion notification
      await _showTaskCompletionNotification(task);

      _logger.info('Completed task from notification', data: {'taskId': task.id});
    } catch (e, stack) {
      _logger.error(
        'Failed to complete task from notification',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
    }
  }

  /// Process pending deep link when app becomes ready
  Future<void> _processPendingDeepLink() async {
    if (_pendingDeepLink == null) return;
    
    final pending = _pendingDeepLink!;
    _pendingDeepLink = null; // Clear it
    
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Navigate directly without DeepLinkService
        final data = pending;
        final type = data['type'] as String?;
        
        if (type == 'task' || type == 'task_reminder') {
          final taskId = data['taskId'] as String?;
          if (taskId != null) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EnhancedTaskListScreen(),
              ),
            );
          }
        }
        
        _logger.info('Processed pending deep link', data: pending);
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to process pending deep link',
        error: e,
        stackTrace: stack,
        data: pending,
      );
    }
  }
  
  /// Handle opening task from notification (deep linking)
  Future<void> _handleOpenTaskFromNotification(String taskId, String? noteId) async {
    try {
      _logger.info('Opening task from notification', data: {
        'taskId': taskId,
        'noteId': noteId,
      });

      // Get the navigator context from the global key
      final context = navigatorKey.currentContext;
      
      if (context != null) {
        // Navigate directly to task or note
        if (taskId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const EnhancedTaskListScreen(),
            ),
          );
        } else if (noteId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ModernEditNoteScreen(
                noteId: noteId,
              ),
            ),
          );
        }
      } else {
        // Store for later if app not ready
        _pendingDeepLink = {
          'type': 'task_reminder',
          'taskId': taskId,
          'noteId': noteId,
        };
        
        _logger.info('Stored pending deep link for later', data: {
          'taskId': taskId,
          'noteId': noteId,
        });
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to open task from notification',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'noteId': noteId},
      );
    }
  }

  /// Show task completion notification
  Future<void> _showTaskCompletionNotification(NoteTask task) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4CAF50), // Green for completion
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationPlugin.show(
        task.id.hashCode,
        '✅ Task Completed',
        task.content,
        details,
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to show task completion notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Schedule task reminder with rich notification
  Future<void> scheduleTaskNotification({
    required NoteTask task,
    required DateTime reminderTime,
  }) async {
    await initialize();

    try {
      final payload = jsonEncode({
        'taskId': task.id,
        'noteId': task.noteId,
        'type': 'task_reminder',
      });

      final androidDetails = AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(_getPriorityColorValue(task.priority)),
        actions: [
          const AndroidNotificationAction(
            'complete_task',
            'Complete',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          const AndroidNotificationAction(
            'snooze_task_15',
            'Snooze 15m',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          const AndroidNotificationAction(
            'open_task',
            'Open',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'TASK_REMINDER',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationPlugin.zonedSchedule(
        task.id.hashCode,
        _formatTaskNotificationTitle(task),
        _formatTaskNotificationBody(task),
        _toTZDateTime(reminderTime),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      _logger.info('Scheduled task notification', data: {
        'taskId': task.id,
        'reminderTime': reminderTime.toIso8601String(),
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to schedule task notification',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
    }
  }

  /// Format task reminder title
  String _formatTaskReminderTitle(NoteTask task, {bool isSnoozed = false}) {
    final prefix = isSnoozed ? 'Snoozed Task Reminder' : 'Task Reminder';
    return '$prefix: ${_getPriorityPrefix(task.priority)}';
  }

  /// Format task reminder body
  String _formatTaskReminderBody(NoteTask task) {
    final dueText = task.dueDate != null 
        ? ' (Due: ${_formatDueTime(task.dueDate!)})'
        : '';
    return '${task.content}$dueText';
  }

  /// Format task notification title
  String _formatTaskNotificationTitle(NoteTask task, {bool isSnoozed = false}) {
    final priorityEmoji = _getPriorityEmoji(task.priority);
    final prefix = isSnoozed ? '⏰ Snoozed Task' : '📋 Task Reminder';
    return '$prefix $priorityEmoji';
  }

  /// Format task notification body
  String _formatTaskNotificationBody(NoteTask task) {
    final buffer = StringBuffer();
    buffer.write(task.content);
    
    if (task.dueDate != null) {
      final timeUntilDue = task.dueDate!.difference(DateTime.now());
      if (timeUntilDue.isNegative) {
        buffer.write(' • Overdue!');
      } else if (timeUntilDue.inMinutes < 60) {
        buffer.write(' • Due in ${timeUntilDue.inMinutes}m');
      } else if (timeUntilDue.inHours < 24) {
        buffer.write(' • Due in ${timeUntilDue.inHours}h');
      } else {
        buffer.write(' • Due ${_formatDueTime(task.dueDate!)}');
      }
    }

    if (task.estimatedMinutes != null) {
      buffer.write(' • Est: ${_formatDuration(task.estimatedMinutes!)}');
    }

    return buffer.toString();
  }

  /// Get priority color value for notifications
  int _getPriorityColorValue(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 0xFF4CAF50; // Green
      case TaskPriority.medium:
        return 0xFFFF9800; // Orange
      case TaskPriority.high:
        return 0xFFF44336; // Red
      case TaskPriority.urgent:
        return 0xFF9C27B0; // Purple
    }
  }

  /// Get priority prefix for titles
  String _getPriorityPrefix(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low Priority';
      case TaskPriority.medium:
        return '';
      case TaskPriority.high:
        return 'High Priority';
      case TaskPriority.urgent:
        return 'URGENT';
    }
  }

  /// Get priority emoji for notifications
  String _getPriorityEmoji(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return '🟢';
      case TaskPriority.medium:
        return '🟡';
      case TaskPriority.high:
        return '🔴';
      case TaskPriority.urgent:
        return '🚨';
    }
  }

  /// Format due time for display
  String _formatDueTime(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDay.isAtSameMomentAs(today)) {
      return 'today at ${_formatTime(dueDate)}';
    } else if (dueDay.isAtSameMomentAs(tomorrow)) {
      return 'tomorrow at ${_formatTime(dueDate)}';
    } else {
      return '${dueDate.day}/${dueDate.month} at ${_formatTime(dueDate)}';
    }
  }

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format duration for display
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }

  /// Convert DateTime to TZDateTime for scheduling
  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Auto-manage reminders for task lifecycle events
  Future<void> onTaskCreated(NoteTask task) async {
    if (task.dueDate != null) {
      await createTaskReminder(task: task);
    }
  }

  Future<void> onTaskUpdated(NoteTask oldTask, NoteTask newTask) async {
    // Handle due date changes
    if (oldTask.dueDate != newTask.dueDate) {
      await updateTaskReminder(newTask);
    }
    
    // Handle completion status changes
    if (oldTask.status != newTask.status) {
      if (newTask.status == TaskStatus.completed) {
        await cancelTaskReminder(newTask);
      } else if (oldTask.status == TaskStatus.completed && newTask.dueDate != null) {
        await createTaskReminder(task: newTask);
      }
    }
  }

  Future<void> onTaskDeleted(NoteTask task) async {
    await cancelTaskReminder(task);
  }

  /// Get all task reminders
  Future<List<NoteTask>> getTasksWithReminders() async {
    try {
      final tasks = await _taskService.getOpenTasks();
      return tasks.where((task) => task.reminderId != null).toList();
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks with reminders',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Bulk update reminders for multiple tasks
  Future<void> bulkUpdateTaskReminders(List<NoteTask> tasks) async {
    await initialize();

    for (final task in tasks) {
      try {
        await updateTaskReminder(task);
      } catch (e) {
        _logger.error(
          'Failed to update reminder for task ${task.id}',
          error: e,
        );
        // Continue with other tasks
      }
    }
  }

  /// Clean up orphaned reminders
  Future<void> cleanupOrphanedReminders() async {
    try {
      // Get all tasks with reminder IDs
      final tasksWithReminders = await getTasksWithReminders();
      final activeReminderIds = tasksWithReminders
          .where((task) => task.reminderId != null)
          .map((task) => task.reminderId!)
          .toSet();

      // Get all reminders from database
      final allReminders = await _db.getAllReminders();
      
      // Find orphaned reminders (reminders without corresponding tasks)
      for (final reminder in allReminders) {
        if (!activeReminderIds.contains(reminder.id)) {
          // Check if this reminder is task-related
          if (reminder.title.contains('Task Reminder') || 
              reminder.notificationTitle?.contains('Task') == true) {
            await _advancedReminderService.deleteReminder(reminder.id);
            _logger.info('Cleaned up orphaned task reminder', data: {
              'reminderId': reminder.id,
            });
          }
        }
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to cleanup orphaned reminders',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _logger.info('TaskReminderBridge disposed');
  }
}
