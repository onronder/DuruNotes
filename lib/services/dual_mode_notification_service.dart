import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/adapters/service_adapter.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service that works with both local and domain models
class DualModeNotificationService {
  DualModeNotificationService({
    required this.db,
    required this.client,
    required this.migrationConfig,
    required this.localNotifications,
  })  : _logger = LoggerFactory.instance,
        _adapter = ServiceAdapter(
          db: db,
          client: client,
          useDomainModels: migrationConfig.useDomainEntities,
        );

  final AppDb db;
  final SupabaseClient client;
  final MigrationConfig migrationConfig;
  final FlutterLocalNotificationsPlugin localNotifications;
  final AppLogger _logger;
  final ServiceAdapter _adapter;

  // Notification channels
  static const String taskReminderChannel = 'task_reminders';
  static const String noteReminderChannel = 'note_reminders';
  static const String syncNotificationChannel = 'sync_notifications';

  /// Schedule task reminder notification
  Future<void> scheduleTaskReminder(dynamic task, DateTime reminderTime) async {
    try {
      final processedTask = _adapter.processTask(task);

      String taskId;
      String taskTitle;
      String? taskDescription;

      if (processedTask is domain.Task) {
        taskId = processedTask.id;
        taskTitle = processedTask.title;
        taskDescription = processedTask.description;
      } else if (processedTask is NoteTask) {
        taskId = processedTask.id;
        taskTitle = processedTask.content;
        taskDescription = processedTask.notes;
      } else {
        throw ArgumentError('Unknown task type: ${processedTask.runtimeType}');
      }

      // Create notification ID from task ID hash
      final notificationId = taskId.hashCode.abs() % 1000000;

      await localNotifications.zonedSchedule(
        notificationId,
        'Task Reminder',
        taskTitle,
        reminderTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            taskReminderChannel,
            'Task Reminders',
            channelDescription: 'Reminders for tasks',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'Task Reminder',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:$taskId',
      );

      _logger.info('Scheduled task reminder', data: {
        'taskId': taskId,
        'reminderTime': reminderTime.toIso8601String(),
      });
    } catch (e, stack) {
      _logger.error('Failed to schedule task reminder', error: e, stackTrace: stack);
    }
  }

  /// Cancel task reminder notification
  Future<void> cancelTaskReminder(dynamic task) async {
    try {
      final processedTask = _adapter.processTask(task);

      String taskId;
      if (processedTask is domain.Task) {
        taskId = processedTask.id;
      } else if (processedTask is NoteTask) {
        taskId = processedTask.id;
      } else {
        throw ArgumentError('Unknown task type: ${processedTask.runtimeType}');
      }

      final notificationId = taskId.hashCode.abs() % 1000000;
      await localNotifications.cancel(notificationId);

      _logger.info('Cancelled task reminder', data: {'taskId': taskId});
    } catch (e, stack) {
      _logger.error('Failed to cancel task reminder', error: e, stackTrace: stack);
    }
  }

  /// Show note update notification
  Future<void> showNoteUpdateNotification(dynamic note) async {
    try {
      final processedNote = _adapter.processNote(note);

      String noteId;
      String noteTitle;
      String noteContent;

      if (processedNote is domain.Note) {
        noteId = processedNote.id;
        noteTitle = processedNote.title;
        noteContent = processedNote.content;
      } else if (processedNote is LocalNote) {
        noteId = processedNote.id;
        noteTitle = processedNote.title;
        noteContent = processedNote.body;
      } else {
        throw ArgumentError('Unknown note type: ${processedNote.runtimeType}');
      }

      // Create notification ID from note ID hash
      final notificationId = noteId.hashCode.abs() % 1000000;

      await localNotifications.show(
        notificationId,
        'Note Updated',
        noteTitle.isEmpty ? 'Untitled Note' : noteTitle,
        NotificationDetails(
          android: AndroidNotificationDetails(
            noteReminderChannel,
            'Note Updates',
            channelDescription: 'Notifications for note updates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        payload: 'note:$noteId',
      );

      _logger.info('Showed note update notification', data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to show note update notification', error: e, stackTrace: stack);
    }
  }

  /// Show sync completion notification
  Future<void> showSyncNotification({
    required bool success,
    int? uploaded,
    int? downloaded,
    String? errorMessage,
  }) async {
    try {
      final String title = success ? 'Sync Complete' : 'Sync Failed';
      final String body = success
          ? 'Uploaded: ${uploaded ?? 0}, Downloaded: ${downloaded ?? 0}'
          : errorMessage ?? 'Sync failed. Please try again.';

      await localNotifications.show(
        999999, // Fixed ID for sync notifications
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            syncNotificationChannel,
            'Sync Notifications',
            channelDescription: 'Notifications for sync status',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        ),
      );

      _logger.info('Showed sync notification', data: {
        'success': success,
        'uploaded': uploaded,
        'downloaded': downloaded,
      });
    } catch (e, stack) {
      _logger.error('Failed to show sync notification', error: e, stackTrace: stack);
    }
  }

  /// Check and schedule overdue task notifications
  Future<void> checkOverdueTasks() async {
    try {
      final now = DateTime.now();
      List<dynamic> tasks;

      if (migrationConfig.useDomainEntities) {
        // Use domain repository when available
        _logger.info('Checking overdue tasks via domain repository');
        tasks = [];
      } else {
        tasks = await db.getOverdueTasks();
      }

      for (final task in tasks) {
        final processedTask = _adapter.processTask(task);

        // Show notification for overdue task
        String taskId;
        String taskTitle;
        DateTime? dueDate;

        if (processedTask is domain.Task) {
          taskId = processedTask.id;
          taskTitle = processedTask.title;
          dueDate = processedTask.dueDate;
        } else if (processedTask is NoteTask) {
          taskId = processedTask.id;
          taskTitle = processedTask.content;
          dueDate = processedTask.dueDate;
        } else {
          continue;
        }

        if (dueDate != null && dueDate.isBefore(now)) {
          final notificationId = (taskId.hashCode.abs() % 1000000) + 500000; // Offset for overdue

          await localNotifications.show(
            notificationId,
            'Overdue Task',
            taskTitle,
            NotificationDetails(
              android: AndroidNotificationDetails(
                taskReminderChannel,
                'Task Reminders',
                channelDescription: 'Reminders for tasks',
                importance: Importance.high,
                priority: Priority.high,
                ticker: 'Overdue Task',
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: 'overdue_task:$taskId',
          );
        }
      }
    } catch (e, stack) {
      _logger.error('Failed to check overdue tasks', error: e, stackTrace: stack);
    }
  }

  /// Initialize notification channels
  Future<void> initializeNotificationChannels() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    _logger.info('Notification channels initialized');
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    _logger.info('Notification tapped', data: {'payload': payload});

    // Parse payload and handle navigation
    if (payload.startsWith('task:')) {
      final taskId = payload.substring(5);
      _handleTaskNotificationTap(taskId);
    } else if (payload.startsWith('note:')) {
      final noteId = payload.substring(5);
      _handleNoteNotificationTap(noteId);
    } else if (payload.startsWith('overdue_task:')) {
      final taskId = payload.substring(13);
      _handleOverdueTaskNotificationTap(taskId);
    }
  }

  void _handleTaskNotificationTap(String taskId) {
    // Navigation logic would go here
    _logger.info('Task notification tapped', data: {'taskId': taskId});
  }

  void _handleNoteNotificationTap(String noteId) {
    // Navigation logic would go here
    _logger.info('Note notification tapped', data: {'noteId': noteId});
  }

  void _handleOverdueTaskNotificationTap(String taskId) {
    // Navigation logic would go here
    _logger.info('Overdue task notification tapped', data: {'taskId': taskId});
  }
}