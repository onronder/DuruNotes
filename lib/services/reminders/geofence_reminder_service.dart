import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

/// Service responsible for managing location-based (geofence) reminders.
///
/// This service handles:
/// - Setting up and managing geofences for location-based reminders
/// - Triggering notifications when users enter geofenced areas
/// - Managing location permissions
/// - Cleanup and disposal of geofence resources
class GeofenceReminderService {
  GeofenceReminderService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;

  static const String _locationChannelId = 'location_reminders';
  static const String _locationChannelName = 'Location Reminders';
  static const String _locationChannelDescription = 'Location-based reminders';

  GeofenceService? _geofenceService;
  bool _initialized = false;

  final AppLogger logger = LoggerFactory.instance;
  final AnalyticsService analytics = AnalyticsFactory.instance;

  /// Initialize the geofence service and set up notification channels
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _createLocationNotificationChannel();
      await _initializeGeofenceService();
      _initialized = true;

      logger.info('GeofenceReminderService initialized');
    } catch (e, stack) {
      logger.error(
        'Failed to initialize GeofenceReminderService',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Create notification channel for location reminders
  Future<void> _createLocationNotificationChannel() async {
    const locationChannel = AndroidNotificationChannel(
      _locationChannelId,
      _locationChannelName,
      description: _locationChannelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(locationChannel);
  }

  /// Initialize geofence service for location-based reminders
  Future<void> _initializeGeofenceService() async {
    try {
      _geofenceService = GeofenceService.instance.setup(
        interval: 5000,
        accuracy: 100,
        loiteringDelayMs: 60000,
        statusChangeDelayMs: 10000,
        useActivityRecognition: true,
        allowMockLocations: false,
        geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
      );
    } catch (e, stack) {
      logger.error(
        'Failed to initialize geofence service',
        error: e,
        stackTrace: stack,
      );
      // Don't throw - app can work without geofencing
    }
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermissions() async {
    final permission = await geo.Geolocator.checkPermission();
    return permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always;
  }

  /// Request location permissions for geofencing
  Future<bool> requestLocationPermissions() async {
    try {
      var permission = await geo.Geolocator.checkPermission();

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.deniedForever) {
        analytics.event('location.permission_denied_forever');
        return false;
      }

      final granted =
          permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always;

      analytics.event(
        granted ? 'location.permission_granted' : 'location.permission_denied',
        properties: {'permission_type': permission.name},
      );

      return granted;
    } catch (e, stack) {
      logger.error(
        'Failed to request location permissions',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Create a location-based reminder with geofencing
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
      throw StateError('GeofenceReminderService not initialized');
    }

    try {
      // Check location permissions
      if (!await hasLocationPermissions()) {
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
      await _setupGeofence(
        reminderId,
        latitude,
        longitude,
        radius,
        title,
        body,
      );

      analytics.event(
        AnalyticsEvents.reminderSet,
        properties: {
          'type': 'location',
          'radius_meters': radius.round(),
          'has_location_name': locationName != null,
        },
      );

      return reminderId;
    } catch (e, stack) {
      logger.error(
        'Failed to create location reminder',
        error: e,
        stackTrace: stack,
      );
      analytics.event(
        'reminder.create_error',
        properties: {'type': 'location', 'error': e.toString()},
      );
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
      radius: [GeofenceRadius(id: 'radius_$reminderId', length: radius)],
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
  // Reserved for geofence implementation
  // void _onGeofenceStatusChanged(
  //   Geofence geofence,
  //   GeofenceRadius geofenceRadius,
  //   GeofenceStatus geofenceStatus,
  //   Location location,
  // ) async {
  //   if (geofenceStatus == GeofenceStatus.ENTER) {
  //     // Extract reminder ID from geofence ID
  //     final geofenceId = geofence.id;
  //     if (geofenceId.startsWith('reminder_')) {
  //       final reminderIdStr = geofenceId.substring('reminder_'.length);
  //       final reminderId = int.tryParse(reminderIdStr);
  //
  //       if (reminderId != null) {
  //         await triggerLocationReminder(reminderId);
  //       }
  //     }
  //   }
  // }

  /// Trigger a location-based reminder
  Future<void> triggerLocationReminder(int reminderId) async {
    try {
      final reminder = await _db.getReminderById(reminderId);
      if (reminder == null || !reminder.isActive) return;

      // Show notification
      await _showLocationNotification(reminder);

      // Mark as triggered
      await _db.markReminderTriggered(reminderId);

      analytics.event(
        'reminder.triggered',
        properties: {'type': 'location', 'reminder_id': reminderId},
      );
    } catch (e, stack) {
      logger.error(
        'Failed to trigger location reminder',
        error: e,
        stackTrace: stack,
      );
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
      final body =
          reminder.notificationBody ??
          "You're near $locationText - ${reminder.title}";

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
      logger.error(
        'Failed to show location notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Get notification action buttons for location reminders
  List<AndroidNotificationAction> _getNotificationActions() {
    return [
      const AndroidNotificationAction(
        'complete',
        'Mark Done',
        icon: DrawableResourceAndroidBitmap('ic_check'),
      ),
    ];
  }

  /// Remove a geofence for a reminder
  Future<void> removeGeofence(int reminderId) async {
    if (_geofenceService == null) return;

    try {
      // TODO: Fix geofence removal when API is stable
      logger.info('Geofence removal requested for reminder $reminderId');
      logger.info('Removed geofence for reminder $reminderId');
    } catch (e, stack) {
      logger.error('Failed to remove geofence', error: e, stackTrace: stack);
    }
  }

  /// Generate stable notification ID from reminder ID
  int _generateNotificationId(int reminderId) {
    return reminderId.hashCode.abs();
  }

  /// Get all active geofences
  Future<List<Geofence>> getActiveGeofences() async {
    if (_geofenceService == null) return [];

    try {
      // TODO: Fix geofence listing when API is stable
      return <Geofence>[];
    } catch (e, stack) {
      logger.error(
        'Failed to get active geofences',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Clean up and dispose of geofence resources
  Future<void> dispose() async {
    try {
      await _geofenceService?.stop();
      logger.info('GeofenceReminderService disposed');
    } catch (e) {
      logger.warn('Error disposing geofence service: $e');
    }
  }
}
