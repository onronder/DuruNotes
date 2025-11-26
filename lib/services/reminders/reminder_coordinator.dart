import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/events/mutation_event_bus.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/notifications/notification_bootstrap.dart';
import 'package:duru_notes/services/permission_manager.dart';
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:duru_notes/services/reminders/geofence_reminder_service.dart';
import 'package:duru_notes/services/reminders/recurring_reminder_service.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';

/// Unified coordinator for all reminder services
///
/// This class manages the lifecycle and interactions between different reminder services:
/// - [RecurringReminderService] for time-based and recurring reminders
/// - [GeofenceReminderService] for location-based reminders
/// - [SnoozeReminderService] for snooze functionality
///
/// The coordinator uses feature flags to enable gradual rollout of the refactored services.
class ReminderCoordinator {
  ReminderCoordinator(this._ref, this._plugin, this._db, {CryptoBox? cryptoBox})
    : _cryptoBox = cryptoBox {
    // Use consolidated reminder services (Phase 1 complete)
    // MIGRATION v42: Pass CryptoBox for encryption support
    _recurringService = RecurringReminderService(
      _ref,
      _plugin,
      _db,
      cryptoBox: _cryptoBox,
    );
    _geofenceService = GeofenceReminderService(
      _ref,
      _plugin,
      _db,
      cryptoBox: _cryptoBox,
    );
    _snoozeService = SnoozeReminderService(
      _ref,
      _plugin,
      _db,
      cryptoBox: _cryptoBox,
    );
  }

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDb _db;
  final CryptoBox? _cryptoBox;

  late final BaseReminderService _recurringService;
  late final BaseReminderService _geofenceService;
  late final BaseReminderService _snoozeService;

  final Ref _ref;
  bool _initialized = false;
  AppLogger get logger => _ref.read(loggerProvider);
  AnalyticsService get analytics => _ref.read(analyticsProvider);
  final FeatureFlags _featureFlags = FeatureFlags.instance;
  final PermissionManager _permissionManager = PermissionManager.instance;
  final SecurityAuditTrail _auditTrail = SecurityAuditTrail();

  /// P0.5 SECURITY: Get current user ID for reminder operations
  String? get currentUserId {
    try {
      return _ref.read(supabaseClientProvider).auth.currentUser?.id;
    } catch (e) {
      logger.warning('Failed to get current user ID: $e');
      return null;
    }
  }

  void _audit(String action, {required bool granted, String? reason}) {
    unawaited(
      _auditTrail.logAccess(
        resource: 'reminderCoordinator.$action',
        granted: granted,
        reason: reason,
      ),
    );
  }

  /// Get the snooze service for external use
  SnoozeReminderService get snoozeService =>
      _snoozeService as SnoozeReminderService;

  /// Initialize all sub-services and notification channel
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await NotificationBootstrap.ensureInitialized(_plugin);
      // Initialize all services
      await Future.wait([
        _recurringService.initialize(),
        _geofenceService.initialize(),
        _snoozeService.initialize(),
      ]);

      _initialized = true;
      logger.info('ReminderCoordinator initialized with unified services');

      analytics.event(
        'app.feature_enabled',
        properties: {
          'feature': 'reminder_coordinator',
          'unified_services': true, // Phase 1 complete - always unified
        },
      );
    } catch (e, stack) {
      logger.error(
        'Failed to initialize ReminderCoordinator',
        error: e,
        stackTrace: stack,
      );
      // Don't throw - partial initialization is better than none
    }
  }

  // Permission Management (using unified PermissionManager)

  Future<bool> requestNotificationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      final status = await _permissionManager.request(
        PermissionType.notification,
      );
      return status == PermissionStatus.granted;
    } else {
      // Fall back to base service method
      return await _recurringService.requestNotificationPermissions();
    }
  }

  Future<bool> hasNotificationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      return await _permissionManager.hasPermission(
        PermissionType.notification,
      );
    } else {
      // Fall back to base service method
      return await _recurringService.hasNotificationPermissions();
    }
  }

  Future<bool> requestLocationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      final status = await _permissionManager.request(PermissionType.location);
      return status == PermissionStatus.granted;
    } else {
      // Fall back to geofence service method
      return await (_geofenceService as GeofenceReminderService)
          .requestLocationPermissions();
    }
  }

  Future<bool> hasLocationPermissions() async {
    if (_featureFlags.useUnifiedPermissionManager) {
      return await _permissionManager.hasPermission(PermissionType.location);
    } else {
      // Fall back to geofence service method
      return await (_geofenceService as GeofenceReminderService)
          .hasLocationPermissions();
    }
  }

  /// Check if all required permissions are granted (optionally include location)
  Future<bool> hasRequiredPermissions({bool includeLocation = false}) async {
    final notifOK = await hasNotificationPermissions();
    if (!includeLocation) return notifOK;
    final locOK = await hasLocationPermissions();
    return notifOK && locOK;
  }

  // Reminder creation and retrieval

  /// Create a time-based reminder (with optional recurrence)
  // MIGRATION v41: Changed from int to String (UUID)
  Future<String?> createTimeReminder({
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
    await initialize();

    final scheduledTime = remindAtUtc.toUtc();

    logger.debug(
      'Creating time reminder',
      data: {
        'noteId': noteId,
        'title': title,
        'remindAt': scheduledTime.toIso8601String(),
        'recurrence': recurrence.name,
        'interval': recurrenceInterval,
      },
    );

    if (!await hasNotificationPermissions()) {
      logger.warning('Cannot create reminder - no notification permissions');

      if (!await requestNotificationPermissions()) {
        analytics.event(
          'reminder.permission_denied',
          properties: {'type': 'time'},
        );
        return null;
      }
    }

    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _audit('createTimeReminder', granted: false, reason: 'missing_user');
      return null;
    }

    final config = ReminderConfig(
      noteId: noteId,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      recurrencePattern: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );

    final reminderId = await _recurringService.createReminder(config);

    if (reminderId != null) {
      logger.info(
        'Created time reminder',
        data: {'id': reminderId, 'recurrence': recurrence.name},
      );

      // PRODUCTION: Enqueue reminder for sync to Supabase
      try {
        await _db.enqueue(
          userId: userId,
          entityId: reminderId, // MIGRATION v41: Already String (UUID)
          kind: 'upsert_reminder',
          payload: jsonEncode({
            'noteId': noteId,
            'type': 'time',
            'recurrence': recurrence.name,
            'scheduledTime': scheduledTime.toIso8601String(),
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        logger.info(
          'Reminder enqueued for sync',
          data: {'reminderId': reminderId, 'type': 'time'},
        );
      } catch (enqueueError, enqueueStack) {
        logger.error(
          'Failed to enqueue reminder for sync',
          error: enqueueError,
          stackTrace: enqueueStack,
          data: {'reminderId': reminderId},
        );
        // Non-critical - reminder still created locally, will sync on next manual sync
      }

      _audit(
        'createTimeReminder',
        granted: true,
        reason: 'reminderId=$reminderId',
      );

      analytics.event(
        'reminder.created',
        properties: {'reminder_id': reminderId, 'type': 'time'},
      );

      MutationEventBus.instance.emitReminder(
        kind: MutationKind.created,
        reminderId: reminderId, // MIGRATION v41: Already String (UUID)
        noteId: noteId,
        metadata: {
          'type': 'time',
          'recurrence': recurrence.name,
          'remindAt': scheduledTime.toIso8601String(),
        },
      );

      return reminderId;
    }

    _audit('createTimeReminder', granted: false, reason: 'creation_failed');
    return reminderId;
  }

  /// Create a location-based reminder
  // MIGRATION v41: Changed from int to String (UUID)
  Future<String?> createLocationReminder({
    required String noteId,
    required String title,
    required String body,
    required double latitude,
    required double longitude,
    double radius = 100.0,
    String? locationName,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    await initialize();

    logger.debug(
      'Creating location reminder',
      data: {
        'noteId': noteId,
        'title': title,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'locationName': locationName ?? 'unnamed',
      },
    );

    if (!await hasLocationPermissions()) {
      logger.warning(
        'Cannot create location reminder - no location permissions',
      );

      if (!await requestLocationPermissions()) {
        analytics.event(
          'reminder.permission_denied',
          properties: {'type': 'location'},
        );
        return null;
      }
    }

    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _audit('createLocationReminder', granted: false, reason: 'missing_user');
      return null;
    }

    final config = ReminderConfig(
      noteId: noteId,
      title: title,
      body: body,
      scheduledTime: DateTime.now(), // Not used for location reminders
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'locationName': locationName,
      },
      customNotificationTitle: customNotificationTitle,
      customNotificationBody: customNotificationBody,
    );

    final reminderId = await _geofenceService.createReminder(config);

    if (reminderId != null) {
      logger.info(
        'Created location reminder',
        data: {'id': reminderId, 'location': locationName ?? 'unnamed'},
      );

      // PRODUCTION: Enqueue reminder for sync to Supabase
      try {
        await _db.enqueue(
          userId: userId,
          entityId: reminderId, // MIGRATION v41: Already String (UUID)
          kind: 'upsert_reminder',
          payload: jsonEncode({
            'noteId': noteId,
            'type': 'location',
            'latitude': latitude,
            'longitude': longitude,
            'radius': radius,
            'locationName': locationName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        logger.info(
          'Reminder enqueued for sync',
          data: {'reminderId': reminderId, 'type': 'location'},
        );
      } catch (enqueueError, enqueueStack) {
        logger.error(
          'Failed to enqueue reminder for sync',
          error: enqueueError,
          stackTrace: enqueueStack,
          data: {'reminderId': reminderId},
        );
        // Non-critical - reminder still created locally, will sync on next manual sync
      }

      MutationEventBus.instance.emitReminder(
        kind: MutationKind.created,
        reminderId: reminderId, // MIGRATION v41: Already String (UUID)
        noteId: noteId,
        metadata: {
          'locationName': locationName,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      _audit(
        'createLocationReminder',
        granted: true,
        reason: 'reminderId=$reminderId',
      );
      return reminderId;
    } else {
      logger.warning(
        'Failed to create location reminder',
        data: {'noteId': noteId},
      );
    }

    if (reminderId == null) {
      _audit(
        'createLocationReminder',
        granted: false,
        reason: 'creation_failed',
      );
    }
    return reminderId;
  }

  /// Snooze an existing reminder
  // MIGRATION v41: Changed from int to String (UUID)
  Future<bool> snoozeReminder(
    String reminderId,
    SnoozeDuration duration,
  ) async {
    await initialize();

    if (!await hasNotificationPermissions()) {
      logger.warning('Cannot snooze reminder - no notification permissions');
      return false;
    }

    final snoozed = await (_snoozeService as SnoozeReminderService)
        .snoozeReminder(reminderId, duration);

    if (snoozed) {
      logger.info(
        'Snoozed reminder',
        data: {'id': reminderId, 'duration': duration.name},
      );

      // PRODUCTION: Enqueue snoozed reminder for sync to Supabase
      final userId = currentUserId;
      if (userId != null) {
        try {
          await _db.enqueue(
            userId: userId,
            entityId: reminderId, // MIGRATION v41: Already String (UUID)
            kind: 'upsert_reminder',
            payload: jsonEncode({
              'operation': 'snooze',
              'duration': duration.name,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
          logger.info(
            'Snoozed reminder enqueued for sync',
            data: {'reminderId': reminderId, 'duration': duration.name},
          );
        } catch (enqueueError, enqueueStack) {
          logger.error(
            'Failed to enqueue snoozed reminder for sync',
            error: enqueueError,
            stackTrace: enqueueStack,
            data: {'reminderId': reminderId},
          );
          // Non-critical - reminder still snoozed locally, will sync on next manual sync
        }
      } else {
        logger.warning(
          'Unable to enqueue snoozed reminder sync op - no authenticated user',
          data: {'reminderId': reminderId},
        );
      }

      MutationEventBus.instance.emitReminder(
        kind: MutationKind.updated,
        reminderId: reminderId, // MIGRATION v41: Already String (UUID)
        metadata: {'snoozed': true, 'duration': duration.name},
      );
    }

    return snoozed;
  }

  /// Get all reminders for a note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot get reminders - no authenticated user');
        return [];
      }

      final reminders = await _db.getRemindersForNote(noteId, userId);
      logger.debug(
        'Fetched reminders for note',
        data: {'noteId': noteId, 'count': reminders.length},
      );
      return reminders;
    } catch (e, stack) {
      logger.error(
        'Failed to get reminders for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      return [];
    }
  }

  /// Get all active reminders
  Future<List<NoteReminder>> getActiveReminders() async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot get active reminders - no authenticated user');
        return [];
      }

      final reminders = await _db.getActiveReminders(userId);
      logger.debug(
        'Fetched active reminders',
        data: {'count': reminders.length},
      );
      return reminders;
    } catch (e, stack) {
      logger.error(
        'Failed to get active reminders',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Cancel a reminder
  // MIGRATION v41: Changed from int to String (UUID)
  Future<void> cancelReminder(String reminderId) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot cancel reminder - no authenticated user');
        _audit('cancelReminder', granted: false, reason: 'missing_user');
        return;
      }

      // Determine which service should handle the cancellation
      final reminder = await _db.getReminderById(reminderId, userId);
      if (reminder == null) {
        logger.warning(
          'Cannot cancel reminder - not found',
          data: {'id': reminderId},
        );
        _audit('cancelReminder', granted: false, reason: 'not_found');
        return;
      }

      switch (reminder.type) {
        case ReminderType.time:
        case ReminderType.recurring:
          await _recurringService.cancelReminder(reminderId);
          break;
        case ReminderType.location:
          await _geofenceService.cancelReminder(reminderId);
          break;
        default:
          // Generic cancellation
          await _recurringService.cancelNotification(reminderId);
          await _db.updateReminder(
            reminderId,
            userId,
            NoteRemindersCompanion(isActive: Value(false)),
          );
          break;
      }

      logger.info('Cancelled reminder', data: {'id': reminderId});
      _audit('cancelReminder', granted: true, reason: 'reminderId=$reminderId');

      // PRODUCTION: Enqueue reminder deletion for sync to Supabase
      try {
        await _db.enqueue(
          userId: userId,
          entityId: reminderId, // MIGRATION v41: Already String (UUID)
          kind: 'delete_reminder',
          payload: jsonEncode({
            'noteId': reminder.noteId,
            'type': reminder.type.name,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        logger.info(
          'Reminder deletion enqueued for sync',
          data: {'reminderId': reminderId},
        );
      } catch (enqueueError, enqueueStack) {
        logger.error(
          'Failed to enqueue reminder deletion for sync',
          error: enqueueError,
          stackTrace: enqueueStack,
          data: {'reminderId': reminderId},
        );
        // Non-critical - reminder still deleted locally, will sync on next manual sync
      }

      analytics.event(
        'reminder.cancelled',
        properties: {'reminder_id': reminderId, 'type': reminder.type.name},
      );

      MutationEventBus.instance.emitReminder(
        kind: MutationKind.deleted,
        reminderId: reminderId, // MIGRATION v41: Already String (UUID)
        noteId: reminder.noteId,
        metadata: {'type': reminder.type.name},
      );
    } catch (e, stack) {
      logger.error(
        'Failed to cancel reminder',
        error: e,
        stackTrace: stack,
        data: {'id': reminderId},
      );
      _audit(
        'cancelReminder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
    }
  }

  /// Cancel all reminders for a note
  Future<void> cancelRemindersForNote(String noteId) async {
    try {
      final reminders = await getRemindersForNote(noteId);

      for (final reminder in reminders) {
        await cancelReminder(reminder.id);
      }

      if (reminders.isNotEmpty) {
        logger.info(
          'Cancelled ${reminders.length} reminders for note',
          data: {'noteId': noteId},
        );
      }
    } catch (e, stack) {
      logger.error(
        'Failed to cancel reminders for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
    }
  }

  /// Process due reminders (called periodically)
  Future<void> processDueReminders() async {
    if (!_initialized) return;

    final userId = currentUserId;
    if (userId == null) {
      _audit('processDueReminders', granted: false, reason: 'missing_user');
      return;
    }

    try {
      // Process recurring reminders
      if (_recurringService is RecurringReminderService) {
        await (_recurringService).processDueReminders();
      }

      // Process snoozed reminders
      if (_snoozeService is SnoozeReminderService) {
        await (_snoozeService).processSnoozedReminders();
      }
      _audit('processDueReminders', granted: true, reason: 'user=$userId');
    } catch (e, stack) {
      logger.error(
        'Failed to process due reminders',
        error: e,
        stackTrace: stack,
      );
      _audit(
        'processDueReminders',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
    }
  }

  /// Handle notification tap
  Future<void> handleNotificationTap(String? payload) async {
    if (payload == null) return;

    try {
      // Parse payload to determine action
      // This would typically navigate to the relevant note
      logger.info('Notification tapped', data: {'payload': payload});

      analytics.event('notification.tapped', properties: {'payload': payload});
    } catch (e, stack) {
      logger.error(
        'Failed to handle notification tap',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await Future.wait([
        _recurringService.dispose(),
        _geofenceService.dispose(),
        _snoozeService.dispose(),
      ]);

      logger.info('ReminderCoordinator disposed');
    } catch (e) {
      logger.warning('Error disposing ReminderCoordinator: $e');
    }
  }

  /// Get statistics about reminders
  Future<Map<String, dynamic>> getReminderStatistics() async {
    try {
      final active = await getActiveReminders();
      final snoozeStats = await (_snoozeService as SnoozeReminderService)
          .getSnoozeStats();

      return {
        'total_active': active.length,
        'by_type': {
          'time': active.where((r) => r.type == ReminderType.time).length,
          'recurring': active
              .where((r) => r.type == ReminderType.recurring)
              .length,
          'location': active
              .where((r) => r.type == ReminderType.location)
              .length,
        },
        'snooze_stats': snoozeStats,
      };
    } catch (e, stack) {
      logger.error(
        'Failed to get reminder statistics',
        error: e,
        stackTrace: stack,
      );
      return {};
    }
  }
}
