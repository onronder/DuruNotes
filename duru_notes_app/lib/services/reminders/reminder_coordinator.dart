import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/monitoring/app_logger.dart';
import '../../data/local/app_db.dart' hide NoteReminder;
import '../../models/note_reminder.dart';
import '../../providers.dart';
import '../analytics/analytics_service.dart';
import 'geofence_reminder_service.dart';
import 'recurring_reminder_service.dart';
import 'snooze_reminder_service.dart';

/// Coordinator service that manages all reminder functionalities.
/// 
/// This service acts as a facade and coordinator for:
/// - [GeofenceReminderService] for location-based reminders
/// - [RecurringReminderService] for time-based and recurring reminders  
/// - [SnoozeReminderService] for snooze functionality
/// 
/// It provides a unified interface for reminder management while delegating
/// specific functionality to specialized services.
class ReminderCoordinator {
  ReminderCoordinator(this._plugin, this._db) {
    _geofenceService = GeofenceReminderService(_plugin, _db);
    _recurringService = RecurringReminderService(_plugin, _db);
    _snoozeService = SnoozeReminderService(_plugin, _db);
  }

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  
  late final GeofenceReminderService _geofenceService;
  late final RecurringReminderService _recurringService;
  late final SnoozeReminderService _snoozeService;
  
  static const String _channelId = 'notes_reminders';
  static const String _channelName = 'Notes Reminders';
  static const String _channelDescription = 'Reminders for your notes';
  
  bool _initialized = false;

  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  /// Initialize all reminder services
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Create main notification channel
      await _createMainNotificationChannel();
      
      // Initialize sub-services
      await _geofenceService.initialize();
      
      _initialized = true;
      
      logger.info('ReminderCoordinator initialized');
      analytics.event('app.feature_enabled', properties: {
        'feature': 'reminder_coordinator',
      });
      
    } catch (e, stack) {
      logger.error('Failed to initialize ReminderCoordinator', 
          error: e, stackTrace: stack);
      analytics.event('reminder.coordinator_init_error', properties: {
        'error': e.toString(),
      });
      rethrow;
    }
  }

  /// Create main notification channel
  Future<void> _createMainNotificationChannel() async {
    const mainChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);
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
      logger.error('Failed to request notification permissions', 
          error: e, stackTrace: stack);
      return false;
    }
  }

  /// Request location permissions for geofencing
  Future<bool> requestLocationPermissions() async {
    return await _geofenceService.requestLocationPermissions();
  }

  /// Check if all required permissions are granted
  Future<bool> hasRequiredPermissions({bool includeLocation = false}) async {
    final notificationGranted = await hasNotificationPermissions();
    
    if (!includeLocation) {
      return notificationGranted;
    }
    
    final locationGranted = await _geofenceService.hasLocationPermissions();
    return notificationGranted && locationGranted;
  }

  /// Check notification permissions
  Future<bool> hasNotificationPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true; // iOS handles this dynamically
  }

  // ========================
  // Reminder Creation
  // ========================

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
    if (!_initialized) {
      throw StateError('ReminderCoordinator not initialized');
    }
    
    // Check permissions
    if (!await hasNotificationPermissions()) {
      logger.warn('Cannot create reminder - no notification permissions');
      return null;
    }
    
    return await _recurringService.createTimeReminder(
      noteId: noteId,
      title: title,
      body: body,
      remindAtUtc: remindAtUtc,
      recurrence: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );
  }

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
      throw StateError('ReminderCoordinator not initialized');
    }
    
    return await _geofenceService.createLocationReminder(
      noteId: noteId,
      title: title,
      body: body,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      locationName: locationName,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );
  }

  // ========================
  // Reminder Management
  // ========================

  // Method implementation moved below with proper conversion

  /// Update a reminder
  Future<void> updateReminder(int reminderId, NoteRemindersCompanion updates) async {
    await _db.updateReminder(reminderId, updates);
  }

  /// Delete a reminder
  Future<void> deleteReminder(int reminderId) async {
    try {
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null) return;
      
      // Cancel notification
      await _recurringService.cancelNotification(reminderId);
      
      // Remove geofence if location reminder
      if (reminder.type == ReminderType.location) {
        await _geofenceService.removeGeofence(reminderId);
      }
      
      // Delete from database
      await _db.deleteReminderById(reminderId);
      
      analytics.event(AnalyticsEvents.reminderRemoved, properties: {
        'reminder_id': reminderId,
        'type': reminder.type.name,
      });
      
    } catch (e, stack) {
      logger.error('Failed to delete reminder', error: e, stackTrace: stack);
    }
  }

  // ========================
  // Snooze Management
  // ========================

  /// Snooze a reminder
  Future<bool> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    return await _snoozeService.snoozeReminder(reminderId, duration);
  }

  /// Clear snooze for a reminder
  Future<void> clearSnooze(int reminderId) async {
    await _snoozeService.clearSnooze(reminderId);
  }

  // ========================
  // Background Processing
  // ========================

  /// Process due reminders (call this periodically)
  Future<void> processDueReminders() async {
    try {
      // Process time-based and recurring reminders
      await _recurringService.processDueReminders();
      
      // Process snoozed reminders
      await _snoozeService.processSnoozedReminders();
      
    } catch (e, stack) {
      logger.error('Failed to process due reminders', error: e, stackTrace: stack);
    }
  }

  /// Handle notification action responses
  Future<void> handleNotificationAction(String action, String payload) async {
    try {
      // Delegate to snooze service for snooze actions
      if (action.startsWith('snooze_') || action == 'complete') {
        await _snoozeService.handleSnoozeAction(action, payload);
      }
      
    } catch (e, stack) {
      logger.error('Failed to handle notification action', 
          error: e, stackTrace: stack);
    }
  }

  // ========================
  // Statistics and Analytics
  // ========================

  /// Get reminder statistics
  Future<Map<String, dynamic>> getReminderStats() async {
    try {
      final basicStats = await _db.getReminderStats();
      final snoozeStats = await _snoozeService.getSnoozeStats();
      
      return {
        ...basicStats,
        'snooze': snoozeStats,
      };
    } catch (e, stack) {
      logger.error('Failed to get reminder stats', error: e, stackTrace: stack);
      return {};
    }
  }

  // ========================
  // Service Access
  // ========================

  /// Get geofence service for advanced location operations
  GeofenceReminderService get geofenceService => _geofenceService;

  /// Get recurring service for advanced recurrence operations  
  RecurringReminderService get recurringService => _recurringService;

  /// Get snooze service for advanced snooze operations
  SnoozeReminderService get snoozeService => _snoozeService;

  // ========================
  // Cleanup
  // ========================

  /// Get reminders for a specific note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      // Get reminders from database
      final dbReminders = await _db.getRemindersForNote(noteId);
      
      // Convert database NoteReminder objects to model NoteReminder objects
      return dbReminders.map((dbReminder) {
        return NoteReminder(
          id: dbReminder.id,
          noteId: dbReminder.noteId,
          title: dbReminder.title,
          body: dbReminder.body,
          type: dbReminder.type,
          scheduledTime: dbReminder.remindAt ?? DateTime.now(),
          remindAt: dbReminder.remindAt,
          isCompleted: false, // Not in database schema, derive from isActive or other fields if needed
          isSnoozed: dbReminder.snoozedUntil != null && dbReminder.snoozedUntil!.isAfter(DateTime.now()),
          snoozeUntil: dbReminder.snoozedUntil,
          isActive: dbReminder.isActive ?? true,
          recurrencePattern: dbReminder.recurrencePattern,
          recurrenceInterval: dbReminder.recurrenceInterval,
          recurrenceEndDate: dbReminder.recurrenceEndDate,
          latitude: dbReminder.latitude,
          longitude: dbReminder.longitude,
          radius: dbReminder.radius,
          locationName: dbReminder.locationName,
          notificationTitle: dbReminder.notificationTitle,
          notificationBody: dbReminder.notificationBody,
          timeZone: dbReminder.timeZone,
          createdAt: dbReminder.createdAt,
          updatedAt: dbReminder.lastTriggered ?? dbReminder.createdAt, // Use lastTriggered as proxy for updatedAt
        );
      }).toList();
    } catch (e, stack) {
      logger.error('Failed to get reminders for note', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Cleanup and dispose of all services
  Future<void> dispose() async {
    try {
      await _geofenceService.dispose();
      logger.info('ReminderCoordinator disposed');
    } catch (e) {
      logger.warn('Error disposing ReminderCoordinator: $e');
    }
  }
}

// Provider for ReminderCoordinator is defined in providers.dart

/// Maintain compatibility with existing code
/// Provider for ReminderCoordinator
final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  final db = ref.read(appDbProvider);
  return ReminderCoordinator(plugin, db);
});

/// Maintain compatibility with existing code
final advancedReminderServiceProvider = Provider<ReminderCoordinator>((ref) {
  return ref.read(reminderCoordinatorProvider);
});
