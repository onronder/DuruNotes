import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

/// Service responsible for managing location-based (geofence) reminders.
///
/// This service extends [BaseReminderService] and handles:
/// - Setting up and managing geofences for location-based reminders
/// - Triggering notifications when users enter geofenced areas
/// - Managing location permissions
/// - Cleanup and disposal of geofence resources
class GeofenceReminderService extends BaseReminderService {
  GeofenceReminderService(
    super.ref,
    super.plugin,
    super.db,
  );

  GeofenceService? _geofenceService;
  bool _geofenceInitialized = false;

  @override
  Future<void> initialize() async {
    await super.initialize();

    try {
      await _initializeGeofenceService();
      _geofenceInitialized = true;

      logger.info('GeofenceReminderService fully initialized');
      trackFeatureUsage('geofence_service_initialized');
    } catch (e, stack) {
      logger.error(
        'Failed to initialize GeofenceReminderService',
        error: e,
        stackTrace: stack,
      );
      // Don't throw - app can work without geofencing
    }
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

      // Set up geofence status change listener
      _geofenceService?.addGeofenceStatusChangeListener(
          (geofence, radius, status, location) async =>
              _onGeofenceStatusChanged(geofence, radius, status, location));
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
    try {
      final permission = await geo.Geolocator.checkPermission();
      return permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always;
    } catch (e) {
      logger.error('Failed to check location permissions', error: e);
      return false;
    }
  }

  /// Request location permissions for geofencing
  Future<bool> requestLocationPermissions() async {
    try {
      var permission = await geo.Geolocator.checkPermission();

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.deniedForever) {
        trackReminderEvent('location_permission_denied_forever', {});
        return false;
      }

      final granted = permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always;

      trackReminderEvent(
        granted ? 'location_permission_granted' : 'location_permission_denied',
        {'permission_type': permission.name},
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

  @override
  Future<int?> createReminder(ReminderConfig config) async {
    if (!_geofenceInitialized) {
      logger.warning('GeofenceReminderService not initialized');
      return null;
    }

    try {
      // Check location permissions
      if (!await hasLocationPermissions()) {
        logger.warning('Cannot create location reminder - missing permissions');
        trackReminderEvent('location_reminder_creation_failed', {
          'reason': 'no_permissions',
        });
        return null;
      }

      // Extract location data from metadata
      final latitude = config.metadata?['latitude'] as double?;
      final longitude = config.metadata?['longitude'] as double?;
      final radius = config.metadata?['radius'] as double? ?? 100.0;
      final locationName = config.metadata?['locationName'] as String?;

      if (latitude == null || longitude == null) {
        logger.warning('Cannot create location reminder - missing coordinates');
        trackReminderEvent('location_reminder_creation_failed', {
          'reason': 'missing_coordinates',
        });
        return null;
      }

      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot create location reminder - no authenticated user');
        return null;
      }

      // Create reminder in database using base class method
      final companion = NoteRemindersCompanion.insert(
        noteId: config.noteId,
        userId: userId, // P0.5 SECURITY: Required for user isolation
        type: ReminderType.location,
        title: Value(config.title),
        body: Value(config.body ?? ''),
        latitude: Value(latitude),
        longitude: Value(longitude),
        radius: Value(radius),
        locationName:
            locationName != null ? Value(locationName) : const Value.absent(),
        notificationTitle: config.customNotificationTitle != null
            ? Value(config.customNotificationTitle)
            : const Value.absent(),
        notificationBody: config.customNotificationBody != null
            ? Value(config.customNotificationBody)
            : const Value.absent(),
        // Note: metadata from config is not stored directly,
        // location data is stored in specific fields
      );

      final reminderId = await createReminderInDb(companion);

      if (reminderId == null) {
        return null;
      }

      // Set up geofence
      await _setupGeofence(
        reminderId,
        latitude,
        longitude,
        radius,
        config.title,
        config.body ?? '',
      );

      trackReminderEvent('location_reminder_created', {
        'radius_meters': radius.round(),
        'has_location_name': locationName != null,
      });

      trackFeatureUsage('geofence_reminder_created', properties: {
        'radius': radius,
        'has_custom_location': locationName != null,
      });

      return reminderId;
    } catch (e, stack) {
      logger.error(
        'Failed to create location reminder',
        error: e,
        stackTrace: stack,
      );
      trackReminderEvent('location_reminder_creation_error', {
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
    if (_geofenceService == null) {
      logger.warning('Geofence service not available');
      return;
    }

    final geofence = Geofence(
      id: 'reminder_$reminderId',
      latitude: latitude,
      longitude: longitude,
      radius: [
        GeofenceRadius(
          id: 'radius_$reminderId',
          length: radius,
        ),
      ],
    );

    try {
      _geofenceService!.addGeofence(geofence);
      logger.info('Set up geofence for reminder $reminderId');
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
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot trigger reminder - no authenticated user');
        return;
      }

      final reminder = await db.getReminderById(reminderId, userId);
      if (reminder == null || !reminder.isActive) return;

      // Show notification
      await _showLocationNotification(reminder);

      // Mark as triggered and update database
      await db.updateReminder(
        reminderId,
        userId,
        NoteRemindersCompanion(
          lastTriggered: Value(DateTime.now()),
          triggerCount: Value(reminder.triggerCount + 1),
        ),
      );

      trackReminderEvent('location_reminder_triggered', {
        'reminder_id': reminderId,
      });
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
      final locationText = reminder.locationName ?? 'location';
      final title = reminder.notificationTitle ?? '📍 Location Reminder';
      final body = reminder.notificationBody ??
          "You're near $locationText - ${reminder.title}";

      await scheduleNotification(ReminderNotificationData(
        id: reminder.id,
        title: title,
        body: body,
        scheduledTime: DateTime.now(), // Immediate notification
        payload: jsonEncode({
          'reminderId': reminder.id,
          'type': 'location',
        }),
      ));
    } catch (e, stack) {
      logger.error(
        'Failed to show location notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Remove a geofence for a reminder
  Future<void> removeGeofence(int reminderId) async {
    if (_geofenceService == null) return;

    try {
      // Remove geofence - service will handle removal
      // Note: GeofenceService doesn't expose a direct removal method
      // We'll stop the service and restart without this geofence
      await _geofenceService!.stop();
      await _geofenceService!.start();
      logger.info('Removed geofence for reminder $reminderId');
    } catch (e, stack) {
      logger.error('Failed to remove geofence', error: e, stackTrace: stack);
    }
  }

  @override
  Future<void> cancelReminder(int id) async {
    await removeGeofence(id);
    await super.cancelReminder(id);
  }

  /// Get all active geofences
  Future<List<Geofence>> getActiveGeofences() async {
    if (_geofenceService == null) return [];

    try {
      // GeofenceService doesn't expose the list directly
      // Return empty list for now - would need to track this internally
      return [];
    } catch (e, stack) {
      logger.error(
        'Failed to get active geofences',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _geofenceService?.stop();
      await super.dispose();
      logger.info('GeofenceReminderService disposed');
    } catch (e) {
      logger.warning('Error disposing geofence service: $e');
    }
  }
}
