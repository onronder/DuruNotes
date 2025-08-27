import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/monitoring/app_logger.dart';
import 'analytics/analytics_service.dart';

/// Reminder types supported by the app
enum ReminderType {
  once,
  daily,
  weekly,
  monthly,
}

/// Reminder data class
class Reminder {
  final String id;
  final String noteId;
  final String title;
  final String? body;
  final DateTime scheduledTime;
  final ReminderType type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Reminder({
    required this.id,
    required this.noteId,
    required this.title,
    this.body,
    required this.scheduledTime,
    required this.type,
    this.isActive = true,
    required this.createdAt,
    this.completedAt,
  });

  Reminder copyWith({
    String? id,
    String? noteId,
    String? title,
    String? body,
    DateTime? scheduledTime,
    ReminderType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reminder &&
        other.id == id &&
        other.noteId == noteId &&
        other.title == title &&
        other.body == body &&
        other.scheduledTime == scheduledTime &&
        other.type == type &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        noteId,
        title,
        body,
        scheduledTime,
        type,
        isActive,
        createdAt,
        completedAt,
      );
}

/// Service for managing note reminders and notifications
class ReminderService {
  ReminderService({
    AppLogger? logger,
    AnalyticsService? analytics,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification system
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _analytics.startTiming('reminder_service_init');

      // Check notification permissions
      final notificationPermission = await Permission.notification.status;
      if (notificationPermission.isDenied) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted) {
          _logger.warning('Notification permission denied');
          return false;
        }
      }

      // Initialize platform-specific settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the notification plugin
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (!initialized) {
        throw Exception('Failed to initialize notifications');
      }

      _isInitialized = true;

      _analytics.endTiming('reminder_service_init', properties: {
        'success': true,
      });

      _logger.info('Reminder service initialized successfully');
      return true;
    } catch (e) {
      _logger.error('Failed to initialize reminder service', error: e);
      
      _analytics.endTiming('reminder_service_init', properties: {
        'success': false,
        'error': e.toString(),
      });
      
      return false;
    }
  }

  /// Schedule a reminder notification
  Future<bool> scheduleReminder(Reminder reminder) async {
    if (!_isInitialized && !await initialize()) {
      return false;
    }

    try {
      _analytics.startTiming('schedule_reminder');

      final notificationId = reminder.id.hashCode;
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'reminders',
        'Note Reminders',
        channelDescription: 'Reminders for your notes',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Note Reminder',
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification
      await _notifications.zonedSchedule(
        notificationId,
        reminder.title,
        reminder.body ?? 'Tap to view your note',
        _convertToTZDateTime(reminder.scheduledTime),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
        payload: reminder.noteId,
      );

      _analytics.endTiming('schedule_reminder', properties: {
        'success': true,
        'reminder_type': reminder.type.name,
      });

      _analytics.featureUsed('reminder_scheduled', properties: {
        'type': reminder.type.name,
        'has_body': reminder.body != null,
      });

      _logger.info('Reminder scheduled successfully', data: {
        'reminder_id': reminder.id,
        'note_id': reminder.noteId,
        'scheduled_time': reminder.scheduledTime.toIso8601String(),
      });

      return true;
    } catch (e) {
      _logger.error('Failed to schedule reminder', error: e, data: {
        'reminder_id': reminder.id,
        'note_id': reminder.noteId,
      });

      _analytics.endTiming('schedule_reminder', properties: {
        'success': false,
        'error': e.toString(),
      });

      return false;
    }
  }

  /// Cancel a scheduled reminder
  Future<bool> cancelReminder(String reminderId) async {
    if (!_isInitialized) return false;

    try {
      final notificationId = reminderId.hashCode;
      await _notifications.cancel(notificationId);

      _analytics.featureUsed('reminder_cancelled');
      
      _logger.info('Reminder cancelled', data: {
        'reminder_id': reminderId,
      });

      return true;
    } catch (e) {
      _logger.error('Failed to cancel reminder', error: e, data: {
        'reminder_id': reminderId,
      });
      return false;
    }
  }

  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    if (!_isInitialized) return [];

    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      _logger.error('Failed to get pending reminders', error: e);
      return [];
    }
  }

  /// Cancel all reminders
  Future<void> cancelAllReminders() async {
    if (!_isInitialized) return;

    try {
      await _notifications.cancelAll();
      _analytics.featureUsed('all_reminders_cancelled');
      _logger.info('All reminders cancelled');
    } catch (e) {
      _logger.error('Failed to cancel all reminders', error: e);
    }
  }

  /// Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized && !await initialize()) {
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      _analytics.featureUsed('immediate_notification_shown');
    } catch (e) {
      _logger.error('Failed to show immediate notification', error: e);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    
    _analytics.featureUsed('notification_tapped', properties: {
      'has_payload': payload != null,
    });

    _logger.info('Notification tapped', data: {
      'payload': payload,
      'notification_id': response.id,
    });

    // TODO: Navigate to the specific note
    // This would typically involve using a navigator or routing system
  }

  /// Convert DateTime to TZDateTime (simplified)
  dynamic _convertToTZDateTime(DateTime dateTime) {
    // This is a simplified implementation
    // In a real app, you'd use the timezone package for proper timezone handling
    return dateTime;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Create a quick reminder (in X minutes)
  Future<bool> scheduleQuickReminder({
    required String noteId,
    required String title,
    required int minutesFromNow,
    String? body,
  }) async {
    final scheduledTime = DateTime.now().add(Duration(minutes: minutesFromNow));
    
    final reminder = Reminder(
      id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      noteId: noteId,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      type: ReminderType.once,
      createdAt: DateTime.now(),
    );

    return await scheduleReminder(reminder);
  }

  /// Get reminder type display name
  static String getReminderTypeDisplayName(ReminderType type) {
    switch (type) {
      case ReminderType.once:
        return 'Once';
      case ReminderType.daily:
        return 'Daily';
      case ReminderType.weekly:
        return 'Weekly';
      case ReminderType.monthly:
        return 'Monthly';
    }
  }

  /// Dispose of resources
  void dispose() {
    // Clean up resources if needed
  }
}