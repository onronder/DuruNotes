// lib/services/reminder_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Timezone handling
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/monitoring/app_logger.dart';
import '../services/analytics/analytics_service.dart';

// If your enum lives in your DB layer, import it here.
import '../data/local/app_db.dart' show ReminderType;

/// Domain model (kept as-is, with minor nits cleaned)
class Reminder {
  final String id;
  final String noteId;
  final String title;
  final String? body;
  final DateTime scheduledTime; // local wall time
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == id &&
          other.noteId == noteId &&
          other.title == title &&
          other.body == body &&
          other.scheduledTime == scheduledTime &&
          other.type == type &&
          other.isActive == isActive &&
          other.createdAt == createdAt &&
          other.completedAt == completedAt);
}

class ReminderService {
  ReminderService({
    AppLogger? logger,
    AnalyticsService? analytics,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _tzReady = false;

  // ---------------- Public API ----------------

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _analytics.startTiming('reminder_service_init');

      // 1) Notifications permission
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted) {
          _logger.warning('Notification permission denied');
          _analytics.endTiming('reminder_service_init',
              properties: {'success': false, 'denied': true});
          return false;
        }
      }

      // 2) Android exact alarm permission (Android 12+)
      if (Platform.isAndroid) {
        await _maybeRequestExactAlarmPermission();
      }

      // 3) Timezone
      await _ensureTimezone();

      // 4) Platform initialization
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      final ok = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      if (ok != true) {
        throw Exception('Failed to initialize notifications');
      }

      // 5) Explicit channels (Android 8+ reliability)
      await _createAndroidChannelsIfNeeded();

      _isInitialized = true;
      _analytics.endTiming('reminder_service_init',
          properties: {'success': true});
      _logger.info('Reminder service initialized successfully');
      return true;
    } catch (e, st) {
      _logger.error('Failed to initialize reminder service',
          error: e, stackTrace: st);
      _analytics.endTiming('reminder_service_init',
          properties: {'success': false, 'error': e.toString()});
      return false;
    }
  }

  Future<bool> scheduleReminder(Reminder reminder) async {
    if (!_isInitialized && !await initialize()) return false;

    try {
      _analytics.startTiming('schedule_reminder');

      final now = DateTime.now();
      if (reminder.scheduledTime.isBefore(now)) {
        _logger.warning('Attempted to schedule in the past; aborting',
            data: {
              'scheduled': reminder.scheduledTime.toIso8601String(),
              'now': now.toIso8601String(),
            });
        _analytics.endTiming('schedule_reminder',
            properties: {'success': false, 'reason': 'past_time'});
        return false;
      }
      if (!_tzReady) await _ensureTimezone();

      final id = _stableNotificationId(reminder.id);

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
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzDate =
          tz.TZDateTime.from(reminder.scheduledTime, tz.local); // local wall time

      await _notifications.zonedSchedule(
        id,
        reminder.title,
        reminder.body ?? 'Tap to view your note',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.noteId,
      );

      _analytics.endTiming('schedule_reminder',
          properties: {'success': true, 'reminder_type': reminder.type.name});
      _analytics.featureUsed('reminder_scheduled',
          properties: {'type': reminder.type.name, 'has_body': reminder.body != null});
      _logger.info('Reminder scheduled', data: {
        'reminder_id': reminder.id,
        'note_id': reminder.noteId,
        'scheduled_time': reminder.scheduledTime.toIso8601String(),
        'tz': tz.local.name,
      });
      return true;
    } catch (e, st) {
      _logger.error('Failed to schedule reminder',
          error: e, stackTrace: st, data: {
        'reminder_id': reminder.id,
        'note_id': reminder.noteId,
      });
      _analytics.endTiming('schedule_reminder',
          properties: {'success': false, 'error': e.toString()});
      return false;
    }
  }

  Future<bool> cancelReminder(String reminderId) async {
    if (!_isInitialized) return false;
    try {
      final id = _stableNotificationId(reminderId);
      await _notifications.cancel(id);
      _analytics.featureUsed('reminder_cancelled');
      _logger.info('Reminder cancelled', data: {'reminder_id': reminderId});
      return true;
    } catch (e, st) {
      _logger.error('Failed to cancel reminder',
          error: e, stackTrace: st, data: {'reminder_id': reminderId});
      return false;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    if (!_isInitialized) return <PendingNotificationRequest>[];
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e, st) {
      _logger.error('Failed to get pending reminders', error: e, stackTrace: st);
      return <PendingNotificationRequest>[];
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_isInitialized) return;
    try {
      await _notifications.cancelAll();
      _analytics.featureUsed('all_reminders_cancelled');
      _logger.info('All reminders cancelled');
    } catch (e, st) {
      _logger.error('Failed to cancel all reminders', error: e, stackTrace: st);
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized && !await initialize()) return;
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
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
      _analytics.featureUsed('immediate_notification_shown');
    } catch (e, st) {
      _logger.error('Failed to show immediate notification', error: e, stackTrace: st);
    }
  }

  Future<bool> areNotificationsEnabled() async =>
      (await Permission.notification.status).isGranted;

  Future<bool> requestNotificationPermissions() async =>
      (await Permission.notification.request()).isGranted;

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
      type: ReminderType.time,
      createdAt: DateTime.now(),
    );
    return scheduleReminder(reminder);
  }

  static String getReminderTypeDisplayName(ReminderType type) {
    switch (type) {
      case ReminderType.time:
        return 'Time-based';
      case ReminderType.location:
        return 'Location-based';
      case ReminderType.recurring:
        return 'Recurring';
    }
  }

  void dispose() {}

  // ---------------- internals ----------------

  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _tzReady = true;
      _logger.debug('Timezone initialized', data: {'tz': name});
    } catch (e, st) {
      _logger.error('Failed to initialize timezone; falling back to UTC',
          error: e, stackTrace: st);
      tz.setLocalLocation(tz.getLocation('UTC'));
      _tzReady = true;
    }
  }

  Future<void> _createAndroidChannelsIfNeeded() async {
    if (!Platform.isAndroid) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channel = AndroidNotificationChannel(
      'reminders',
      'Note Reminders',
      description: 'Reminders for your notes',
      importance: Importance.high,
    );
    await android.createNotificationChannel(channel);

    const general = AndroidNotificationChannel(
      'general',
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.high,
    );
    await android.createNotificationChannel(general);
  }

  Future<void> _maybeRequestExactAlarmPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final granted = await android.canScheduleExactNotifications();
    if (granted == false) {
      await android.requestExactAlarmsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    _analytics.featureUsed('notification_tapped',
        properties: {'has_payload': payload != null});
    _logger.info('Notification tapped',
        data: {'payload': payload, 'notification_id': response.id});
    // TODO: Navigate to the specific note using your router/nav singleton.
  }

  /// Stable 31-bit hash for String IDs (don’t use String.hashCode)
  int _stableNotificationId(String s) {
    int hash = 0;
    for (final c in s.codeUnits) {
      hash = (hash + c) & 0x1fffffff;
      hash = (hash + (hash << 10)) & 0x1fffffff;
      hash ^= (hash >> 6);
    }
    hash = (hash + (hash << 3)) & 0x1fffffff;
    hash ^= (hash >> 11);
    hash = (hash + (hash << 15)) & 0x1fffffff;
    return hash == 0 ? 1 : hash;
  }
}
