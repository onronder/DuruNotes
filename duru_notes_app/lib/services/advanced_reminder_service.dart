import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geofence_service/geofence_service.dart';

import '../core/monitoring/app_logger.dart';
import '../data/local/app_db.dart';
import '../providers.dart';
import 'analytics/analytics_service.dart';
import 'analytics/analytics_sentry.dart';

/// Enhanced reminder service supporting multiple reminder types:
/// - Time-based reminders with recurring patterns
/// - Location-based reminders (geofencing)
/// - Rich notifications with snooze functionality
class AdvancedReminderService {
  AdvancedReminderService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  
  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';
  
  static const String _locationChannelId = 'location_reminders';
  static const String _locationChannelName = 'Location Reminders';
  static const String _locationChannelDescription = 'Location-based reminders';
  
  bool _initialized = false;
  GeofenceService? _geofenceService;
  
  /// Initialize the service and create notification channels
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Create notification channels
      await _createNotificationChannels();
      
      // Initialize geofence service
      await _initializeGeofenceService();
      
      _initialized = true;
      
      logger.info('AdvancedReminderService initialized');
      analytics.event('app.feature_enabled', properties: {
        'feature': 'advanced_reminders',
      });
      
    } catch (e, stack) {
      logger.error('Failed to initialize AdvancedReminderService', error: e, stackTrace: stack);
      analytics.event('reminder.init_error', properties: {
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Create notification channels for different reminder types
  Future<void> _createNotificationChannels() async {
    // Main reminders channel
    const mainChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    // Location reminders channel
    const locationChannel = AndroidNotificationChannel(
      _locationChannelId,
      _locationChannelName,
      description: _locationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);
        
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(locationChannel);
  }
  
  /// Initialize geofence service for location-based reminders
  Future<void> _initializeGeofenceService() async {
    try {
      _geofenceService =       GeofenceService.instance.setup(
        interval: 5000,
        accuracy: 100,
        loiteringDelayMs: 60000,
        statusChangeDelayMs: 10000,
        useActivityRecognition: true,
        allowMockLocations: false,
        geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
      );
    } catch (e, stack) {
      logger.error('Failed to initialize geofence service', error: e, stackTrace: stack);
      // Don't throw - app can work without geofencing
    }
  }
  
  // ========================
  // Permission Management
  // ========================
  
  /// Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    try {
      bool granted = false;
      
      if (Platform.isIOS) {
        final result = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        granted = result ?? false;
      } else if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        granted = status.isGranted;
      }
      
      analytics.event(
        granted ? AnalyticsEvents.reminderPermissionGranted : AnalyticsEvents.reminderPermissionDenied,
        properties: {'type': 'notification', 'platform': Platform.operatingSystem},
      );
      
      return granted;
    } catch (e, stack) {
      logger.error('Failed to request notification permissions', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Request location permissions for geofencing
  Future<bool> requestLocationPermissions() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      
      if (permission == geo.LocationPermission.deniedForever) {
        analytics.event('location.permission_denied_forever');
        return false;
      }
      
      final granted = permission == geo.LocationPermission.whileInUse || 
                     permission == geo.LocationPermission.always;
      
      analytics.event(
        granted ? 'location.permission_granted' : 'location.permission_denied',
        properties: {'permission_type': permission.name},
      );
      
      return granted;
    } catch (e, stack) {
      logger.error('Failed to request location permissions', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Check if all required permissions are granted
  Future<bool> hasRequiredPermissions({bool includeLocation = false}) async {
    final notificationGranted = await hasNotificationPermissions();
    
    if (!includeLocation) {
      return notificationGranted;
    }
    
    final locationGranted = await hasLocationPermissions();
    return notificationGranted && locationGranted;
  }
  
  Future<bool> hasNotificationPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true; // iOS handles this dynamically
  }
  
  Future<bool> hasLocationPermissions() async {
    final permission = await geo.Geolocator.checkPermission();
    return permission == geo.LocationPermission.whileInUse || 
           permission == geo.LocationPermission.always;
  }
  
  // ========================
  // Time-based Reminders
  // ========================
  
  /// Create a time-based reminder
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
    if (!_initialized) {
      throw StateError('Service not initialized');
    }
    
    try {
      // Check permissions
      if (!await hasNotificationPermissions()) {
        logger.warn('Cannot create reminder - no notification permissions');
        return null;
      }
      
      // Validate time
      if (remindAtUtc.isBefore(DateTime.now().toUtc())) {
        logger.warn('Cannot create reminder - time is in the past');
        return null;
      }
      
      // Create reminder in database
      final reminderId = await _db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: noteId,
          title: Value(title),
          body: Value(body),
          type: ReminderType.time,
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
    DateTime? nextTime;
    
    switch (pattern) {
      case RecurrencePattern.daily:
        nextTime = currentTime.add(Duration(days: interval));
        break;
      case RecurrencePattern.weekly:
        nextTime = currentTime.add(Duration(days: 7 * interval));
        break;
      case RecurrencePattern.monthly:
        nextTime = DateTime(
          currentTime.year,
          currentTime.month + interval,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
        break;
      case RecurrencePattern.yearly:
        nextTime = DateTime(
          currentTime.year + interval,
          currentTime.month,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
        break;
      case RecurrencePattern.none:
        return;
    }
    
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
      }
    }
  }
  
  // ========================
  // Location-based Reminders
  // ========================
  
  /// Create a location-based reminder
  Future<int?> createLocationReminder({
    required String noteId,
    required String title,
    required String body,
    required double latitude,
    required double longitude,
    required double radius,
    String? locationName,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    if (!_initialized) {
      throw StateError('Service not initialized');
    }
    
    try {
      // Check permissions
      if (!await hasRequiredPermissions(includeLocation: true)) {
        logger.warn('Cannot create location reminder - missing permissions');
        return null;
      }
      
      // Create reminder in database
      final reminderId = await _db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: noteId,
          title: Value(title),
          body: Value(body),
          type: ReminderType.location,
          latitude: Value(latitude),
          longitude: Value(longitude),
          radius: Value(radius),
          locationName: Value(locationName),
          notificationTitle: Value(customNotificationTitle),
          notificationBody: Value(customNotificationBody),
        ),
      );
      
      // Set up geofence
      await _setupGeofence(reminderId, latitude, longitude, radius, title, body);
      
      analytics.event(AnalyticsEvents.reminderSet, properties: {
        'type': 'location',
        'radius_meters': radius.round(),
        'has_location_name': locationName != null,
      });
      
      return reminderId;
      
    } catch (e, stack) {
      logger.error('Failed to create location reminder', error: e, stackTrace: stack);
      analytics.event('reminder.create_error', properties: {
        'type': 'location',
        'error': e.toString(),
      });
      return null;
    }
  }
  
  /// Set up geofence for location reminder
  Future<void> _setupGeofence(
    int reminderId,
    double latitude,
    double longitude,
    double radius,
    String title,
    String body,
  ) async {
    if (_geofenceService == null) return;
    
    final geofence = Geofence(
      id: 'reminder_$reminderId',
      latitude: latitude,
      longitude: longitude,
      radius: [
        GeofenceRadius(id: 'radius_$reminderId', length: radius),
      ],
    );
    
    try {
      _geofenceService!.addGeofence(geofence);
      
      // TODO: Set up geofence callback - API may have changed
      // _geofenceService!.addGeofenceStatusChanged(_onGeofenceStatusChanged);
      
    } catch (e, stack) {
      logger.error('Failed to setup geofence', error: e, stackTrace: stack);
    }
  }
  
  /// Handle geofence status changes
  void _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    if (geofenceStatus == GeofenceStatus.ENTER) {
      // Extract reminder ID from geofence ID
      final geofenceId = geofence.id;
      if (geofenceId.startsWith('reminder_')) {
        final reminderIdStr = geofenceId.substring('reminder_'.length);
        final reminderId = int.tryParse(reminderIdStr);
        
        if (reminderId != null) {
          await _triggerLocationReminder(reminderId);
        }
      }
    }
  }
  
  /// Trigger a location-based reminder
  Future<void> _triggerLocationReminder(int reminderId) async {
    try {
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null || !reminder.isActive) return;
      
      // Show notification
      await _showLocationNotification(reminder);
      
      // Mark as triggered
      await _db.markReminderTriggered(reminderId);
      
      analytics.event('reminder.triggered', properties: {
        'type': 'location',
        'reminder_id': reminderId,
      });
      
    } catch (e, stack) {
      logger.error('Failed to trigger location reminder', error: e, stackTrace: stack);
    }
  }
  
  // ========================
  // Notification Management
  // ========================
  
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      
    } catch (e, stack) {
      logger.error('Failed to schedule notification', error: e, stackTrace: stack);
    }
  }
  
  /// Show location-based notification
  Future<void> _showLocationNotification(NoteReminder reminder) async {
    try {
      final notificationId = _generateNotificationId(reminder.id);
      final payload = jsonEncode({
        'reminderId': reminder.id,
        'type': 'location',
      });
      
      final locationText = reminder.locationName ?? 'location';
      final title = reminder.notificationTitle ?? '📍 Location Reminder';
      final body = reminder.notificationBody ?? 
          'You\'re near $locationText - ${reminder.title}';
      
      await _plugin.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _locationChannelId,
            _locationChannelName,
            channelDescription: _locationChannelDescription,
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
      );
      
    } catch (e, stack) {
      logger.error('Failed to show location notification', error: e, stackTrace: stack);
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
  
  // ========================
  // Snooze Functionality
  // ========================
  
  /// Snooze a reminder
  Future<void> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    try {
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null) return;
      
      final snoozeUntil = _calculateSnoozeTime(duration);
      
      // Update database
      await _db.snoozeReminder(reminderId, snoozeUntil);
      
      // Cancel current notification
      await _cancelNotification(reminderId);
      
      // Reschedule for snooze time
      if (reminder.type == ReminderType.time) {
        await _scheduleNotification(
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
      });
      
    } catch (e, stack) {
      logger.error('Failed to snooze reminder', error: e, stackTrace: stack);
    }
  }
  
  /// Calculate snooze time based on duration
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
        final tomorrow = now.add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0); // 9 AM tomorrow
    }
  }
  
  // ========================
  // Reminder Management
  // ========================
  
  /// Get all reminders for a note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    return await _db.getRemindersForNote(noteId);
  }
  
  /// Update a reminder
  Future<void> updateReminder(int reminderId, NoteRemindersCompanion updates) async {
    await _db.updateReminder(reminderId, updates);
  }
  
  /// Delete a reminder
  Future<void> deleteReminder(int reminderId) async {
    try {
      // Cancel notification
      await _cancelNotification(reminderId);
      
      // Remove geofence if location reminder
      final reminder = await _db.getReminderById(reminderId);
      if (reminder?.type == ReminderType.location) {
        await _removeGeofence(reminderId);
      }
      
      // Delete from database
      await _db.deleteReminderById(reminderId);
      
      analytics.event(AnalyticsEvents.reminderRemoved, properties: {
        'reminder_id': reminderId,
      });
      
    } catch (e, stack) {
      logger.error('Failed to delete reminder', error: e, stackTrace: stack);
    }
  }
  
  /// Cancel a notification
  Future<void> _cancelNotification(int reminderId) async {
    final notificationId = _generateNotificationId(reminderId);
    await _plugin.cancel(notificationId);
  }
  
  /// Remove a geofence
  Future<void> _removeGeofence(int reminderId) async {
    if (_geofenceService == null) return;
    
    try {
      // TODO: Fix geofence removal when API is stable
      // await _geofenceService!.removeGeofence(geofenceObject);
      logger.info('Geofence removal requested for reminder $reminderId');
    } catch (e, stack) {
      logger.error('Failed to remove geofence', error: e, stackTrace: stack);
    }
  }
  
  /// Generate stable notification ID
  int _generateNotificationId(int reminderId) {
    return reminderId.hashCode.abs();
  }
  
  /// Handle notification action responses
  Future<void> handleNotificationAction(String action, String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final reminderId = data['reminderId'] as int?;
      
      if (reminderId == null) return;
      
      switch (action) {
        case 'snooze_5':
          await snoozeReminder(reminderId, SnoozeDuration.fiveMinutes);
          break;
        case 'snooze_15':
          await snoozeReminder(reminderId, SnoozeDuration.fifteenMinutes);
          break;
        case 'complete':
          await _db.deactivateReminder(reminderId);
          analytics.event('reminder.completed_from_notification');
          break;
      }
      
    } catch (e, stack) {
      logger.error('Failed to handle notification action', error: e, stackTrace: stack);
    }
  }
  
  /// Process due reminders (call this periodically)
  Future<void> processDueReminders() async {
    try {
      final now = DateTime.now().toUtc();
      
      // Process time-based reminders
      final dueReminders = await _db.getTimeRemindersToTrigger(before: now);
      for (final reminder in dueReminders) {
        await _triggerTimeReminder(reminder);
      }
      
      // Process snoozed reminders
      final snoozedReminders = await _db.getSnoozedRemindersToReschedule(now: now);
      for (final reminder in snoozedReminders) {
        await _rescheduleSnoozedReminder(reminder);
      }
      
    } catch (e, stack) {
      logger.error('Failed to process due reminders', error: e, stackTrace: stack);
    }
  }
  
  /// Trigger a time-based reminder
  Future<void> _triggerTimeReminder(NoteReminder reminder) async {
    try {
      // Mark as triggered
      await _db.markReminderTriggered(reminder.id);
      
      // If recurring, schedule next occurrence
      if (reminder.recurrencePattern != RecurrencePattern.none && reminder.remindAt != null) {
        await _scheduleNextRecurrence(
          reminder.id,
          reminder.remindAt!,
          reminder.recurrencePattern,
          reminder.recurrenceInterval,
        );
      } else {
        // Deactivate non-recurring reminder
        await _db.deactivateReminder(reminder.id);
      }
      
      analytics.event('reminder.triggered', properties: {
        'type': 'time',
        'is_recurring': reminder.recurrencePattern != RecurrencePattern.none,
      });
      
    } catch (e, stack) {
      logger.error('Failed to trigger time reminder', error: e, stackTrace: stack);
    }
  }
  
  /// Reschedule a snoozed reminder
  Future<void> _rescheduleSnoozedReminder(NoteReminder reminder) async {
    try {
      // Clear snooze
      await _db.clearSnooze(reminder.id);
      
      if (reminder.type == ReminderType.time && reminder.snoozedUntil != null) {
        // Reschedule notification
        await _scheduleNotification(
          reminder.id,
          reminder.snoozedUntil!,
          reminder.title,
          reminder.body,
          customTitle: reminder.notificationTitle,
          customBody: reminder.notificationBody,
        );
      }
      
    } catch (e, stack) {
      logger.error('Failed to reschedule snoozed reminder', error: e, stackTrace: stack);
    }
  }
  
  /// Get reminder statistics
  Future<Map<String, int>> getReminderStats() async {
    return await _db.getReminderStats();
  }
  
  /// Cleanup and dispose
  Future<void> dispose() async {
    try {
      await _geofenceService?.stop();
    } catch (e) {
      logger.warn('Error disposing geofence service: $e');
    }
  }
}

/// Provider for AdvancedReminderService
final advancedReminderServiceProvider = Provider<AdvancedReminderService>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);
  return AdvancedReminderService(plugin, db);
});

/// Extension methods for easier snooze duration handling
extension SnoozeDurationExtensions on SnoozeDuration {
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
}

/// Extension methods for recurrence patterns
extension RecurrencePatternExtensions on RecurrencePattern {
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
}
