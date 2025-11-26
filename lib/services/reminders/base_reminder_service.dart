import 'dart:io';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
// NoteReminder is imported from app_db.dart
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/services/reminders/encryption_lock_manager.dart';
import 'package:duru_notes/services/reminders/encryption_verification_helper.dart'
    as encryption_helper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Configuration for creating reminders
class ReminderConfig {
  final String noteId;
  final String title;
  final String? body;
  final DateTime scheduledTime;
  final RecurrencePattern recurrencePattern;
  final int recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final String? customNotificationTitle;
  final String? customNotificationBody;
  final Map<String, dynamic>? metadata;

  const ReminderConfig({
    required this.noteId,
    required this.title,
    this.body,
    required this.scheduledTime,
    this.recurrencePattern = RecurrencePattern.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.customNotificationTitle,
    this.customNotificationBody,
    this.metadata,
  });

  /// Convert to database companion for insertion (plaintext only)
  ///
  /// P0.5 SECURITY: Requires userId to prevent cross-user reminder creation
  /// DEPRECATED: Use toCompanionWithEncryption() for Migration v42 compliance
  NoteRemindersCompanion toCompanion(ReminderType reminderType, String userId) {
    return NoteRemindersCompanion.insert(
      noteId: noteId, // Required, passed directly
      userId: userId, // P0.5 SECURITY: Required for user isolation
      type: reminderType, // Required, passed directly
      title: Value(title),
      body: Value(body ?? ''),
      remindAt: Value(scheduledTime),
      recurrencePattern: Value(recurrencePattern),
      recurrenceInterval: Value(recurrenceInterval),
      recurrenceEndDate: recurrenceEndDate != null
          ? Value(recurrenceEndDate)
          : const Value.absent(),
      notificationTitle: customNotificationTitle != null
          ? Value(customNotificationTitle)
          : const Value.absent(),
      notificationBody: customNotificationBody != null
          ? Value(customNotificationBody)
          : const Value.absent(),
      // Metadata fields should be handled separately by specific services
      // (e.g., latitude, longitude for geofence reminders)
    );
  }

  /// Convert to database companion with encryption (Migration v42)
  ///
  /// SECURITY: Encrypts title, body, and location_name using XChaCha20-Poly1305
  /// P0.5 SECURITY: Requires userId to prevent cross-user reminder creation
  ///
  /// **Zero-Downtime Migration**: Writes BOTH plaintext and encrypted fields
  /// - Old app versions can read plaintext
  /// - New app versions prefer encrypted fields
  /// - Future migration will drop plaintext columns
  Future<NoteRemindersCompanion> toCompanionWithEncryption(
    ReminderType reminderType,
    String userId,
    CryptoBox? cryptoBox, {
    String? locationName,
  }) async {
    // Start with base plaintext companion
    var companion = toCompanion(reminderType, userId);

    // Add location_name if provided
    if (locationName != null && locationName.isNotEmpty) {
      companion = companion.copyWith(locationName: Value(locationName));
    }

    // Encrypt fields if CryptoBox is available
    if (cryptoBox != null) {
      try {
        // Encrypt title (required field)
        final titleEncrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: title,
        );

        // Encrypt body (may be empty)
        final bodyText = body ?? '';
        final bodyEncrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: bodyText,
        );

        // Encrypt location_name if provided
        Uint8List? locationNameEncrypted;
        if (locationName != null && locationName.isNotEmpty) {
          locationNameEncrypted = await cryptoBox.encryptStringForNote(
            userId: userId,
            noteId: noteId,
            text: locationName,
          );
        }

        // Add encrypted fields to companion
        companion = companion.copyWith(
          titleEncrypted: Value(titleEncrypted),
          bodyEncrypted: Value(bodyEncrypted),
          locationNameEncrypted: locationNameEncrypted != null
              ? Value(locationNameEncrypted)
              : const Value.absent(),
          encryptionVersion: const Value(1),
        );
      } catch (e, stack) {
        // Log encryption failure but continue with plaintext
        // This ensures reminders can still be created if encryption fails
        LoggerFactory.instance.error(
          'Failed to encrypt reminder fields',
          error: e,
          stackTrace: stack,
          data: {'noteId': noteId, 'userId': userId},
        );
      }
    }

    return companion;
  }
}

/// Data for scheduling notifications
class ReminderNotificationData {
  // MIGRATION v41: Changed from int to String (UUID)
  final String id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String? payload;
  final Map<String, dynamic>? extras;

  const ReminderNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
    this.extras,
  });
}

/// Base class for all reminder services
///
/// This class provides common functionality for different types of reminders
/// including permission management, database operations, and analytics.
///
/// Subclasses should override [createReminder] to implement specific logic.
///
/// Example:
/// ```dart
/// class MyReminderService extends BaseReminderService {
///   @override
///   Future<int?> createReminder(ReminderConfig config) {
///     // Implementation
///   }
/// }
/// ```
abstract class BaseReminderService {
  BaseReminderService(
    this._ref,
    this.plugin,
    this.db, {
    CryptoBox? cryptoBox,
    ReminderServiceConfig? reminderConfig,
  }) : _cryptoBox = cryptoBox,
       _reminderConfig =
           reminderConfig ?? ReminderServiceConfig.defaultConfig(),
       _encryptionLockManager = EncryptionLockManager(
         reminderConfig ?? ReminderServiceConfig.defaultConfig(),
       );

  // Shared dependencies
  final Ref _ref;
  final FlutterLocalNotificationsPlugin plugin;
  final AppDb db;
  final CryptoBox? _cryptoBox;
  final ReminderServiceConfig _reminderConfig;

  /// CRITICAL #6: Lock manager to prevent concurrent encryption race conditions
  final EncryptionLockManager _encryptionLockManager;

  AppLogger get logger => _ref.read(loggerProvider);
  AnalyticsService get analytics => _ref.read(analyticsProvider);

  /// Configuration for reminder service operations
  @protected
  ReminderServiceConfig get config => _reminderConfig;

  /// P0.5 SECURITY: Get current user ID for reminder operations
  String? get currentUserId {
    try {
      return _ref.read(supabaseClientProvider).auth.currentUser?.id;
    } catch (e) {
      logger.warning('Failed to get current user ID: $e');
      return null;
    }
  }

  /// Check if a reminder is already encrypted
  ///
  /// A reminder is considered encrypted if it has both title and body encrypted
  /// and the encryption version is set to 1.
  bool _isReminderEncrypted(NoteReminder reminder) {
    return reminder.titleEncrypted != null &&
        reminder.bodyEncrypted != null &&
        reminder.encryptionVersion == 1;
  }

  /// Handle verification failure by logging error and throwing
  ///
  /// This consolidates the error handling logic for encryption verification failures.
  /// Logs the error with relevant context and throws a StateError.
  void _handleVerificationFailure(
    encryption_helper.VerificationResult verification,
    String reminderId,
    String fieldName,
  ) {
    logger.error(
      '$fieldName encryption verification failed for reminder $reminderId',
      data: {
        'originalLength': verification.originalLength,
        'decryptedLength': verification.decryptedLength,
        'error': verification.error?.toString(),
      },
    );
    throw StateError(
      'Encryption verification failed: $fieldName roundtrip mismatch',
    );
  }

  /// Validate and return current user ID with logging
  ///
  /// Returns userId if authenticated, null otherwise.
  /// Logs warning if not authenticated for the given operation.
  ///
  /// Usage:
  /// ```dart
  /// final userId = validateUserId('createReminder');
  /// if (userId == null) return null; // or handle error
  /// ```
  @protected
  String? validateUserId(String operation) {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      logger.warning('Cannot $operation - no authenticated user');
      return null;
    }
    return userId;
  }

  // MIGRATION v42: Encryption helpers

  /// Decrypt reminder fields if encrypted (Migration v42)
  ///
  /// **Backward Compatibility**: Prefers encrypted fields, falls back to plaintext
  /// - If reminder has encrypted fields, decrypt and return decrypted data
  /// - If no encrypted fields, return plaintext data
  /// - If decryption fails, fallback to plaintext
  ///
  /// Returns a map with decrypted strings:
  /// - 'title': Decrypted or plaintext title
  /// - 'body': Decrypted or plaintext body
  /// - 'locationName': Decrypted or plaintext location_name (if present)
  Future<Map<String, String>> decryptReminderFields(
    NoteReminder reminder,
  ) async {
    // Check if reminder has encrypted data
    if (reminder.titleEncrypted != null &&
        reminder.bodyEncrypted != null &&
        reminder.encryptionVersion == 1 &&
        _cryptoBox != null) {
      try {
        // Decrypt encrypted fields
        final title = await _cryptoBox.decryptStringForNote(
          userId: reminder.userId,
          noteId: reminder.noteId,
          data: reminder.titleEncrypted!,
        );

        final body = await _cryptoBox.decryptStringForNote(
          userId: reminder.userId,
          noteId: reminder.noteId,
          data: reminder.bodyEncrypted!,
        );

        String? locationName;
        if (reminder.locationNameEncrypted != null) {
          locationName = await _cryptoBox.decryptStringForNote(
            userId: reminder.userId,
            noteId: reminder.noteId,
            data: reminder.locationNameEncrypted!,
          );
        }

        return {
          'title': title,
          'body': body,
          if (locationName != null) 'locationName': locationName,
        };
      } catch (e, stack) {
        logger.error(
          'Failed to decrypt reminder ${reminder.id}, falling back to plaintext',
          error: e,
          stackTrace: stack,
        );
        analytics.event(
          'reminder_decryption_failed',
          properties: {'reminder_id': reminder.id, 'error': e.toString()},
        );
        // Fall through to plaintext fallback
      }
    }

    // Return plaintext data (either no encrypted data or decryption failed)
    return {
      'title': reminder.title,
      'body': reminder.body,
      if (reminder.locationName != null && reminder.locationName!.isNotEmpty)
        'locationName': reminder.locationName!,
    };
  }

  /// Lazy encryption: Encrypt plaintext reminder fields if not already encrypted
  ///
  /// **Migration Strategy**: Gradually encrypt existing plaintext reminders
  /// - Check if reminder has encrypted fields
  /// - If not encrypted and CryptoBox available, encrypt and update DB
  /// - This allows migration to happen incrementally as reminders are accessed
  ///
  /// **CRITICAL #6: Race Condition Prevention**:
  /// - Uses lock manager to prevent concurrent encryption of same reminder
  /// - Double-check pattern: check → lock → check again → encrypt
  /// - Lock automatically released even if operation throws
  ///
  /// Returns true if encryption was performed and DB was updated
  Future<bool> ensureReminderEncrypted(NoteReminder reminder) async {
    // FIRST CHECK: Skip if already encrypted (before acquiring lock)
    if (_isReminderEncrypted(reminder)) {
      return false;
    }

    // Skip if no CryptoBox available
    if (_cryptoBox == null) {
      logger.debug('CryptoBox not available, skipping lazy encryption');
      analytics.event(
        'reminder_encryption_skipped',
        properties: {
          'reminder_id': reminder.id,
          'reason': 'cryptobox_unavailable',
        },
      );
      return false;
    }

    // Skip if no current user
    final userId = currentUserId;
    if (userId == null || userId != reminder.userId) {
      logger.warning(
        'Cannot encrypt reminder - user mismatch or not authenticated',
      );
      analytics.event(
        'reminder_encryption_skipped',
        properties: {
          'reminder_id': reminder.id,
          'reason': userId == null ? 'no_user' : 'user_mismatch',
        },
      );
      return false;
    }

    // CRITICAL #6: Acquire lock to prevent concurrent encryption
    return await _encryptionLockManager.withLock(reminder.id, () async {
      // DOUBLE-CHECK: Re-fetch reminder to see if another thread already encrypted it
      final currentReminder = await db.getReminderByIdIncludingDeleted(
        reminder.id,
        userId,
      );

      // If reminder was deleted while we waited for lock, skip
      if (currentReminder == null) {
        logger.debug(
          'Reminder ${reminder.id} was deleted while waiting for lock',
        );
        analytics.event(
          'reminder_encryption_skipped',
          properties: {
            'reminder_id': reminder.id,
            'reason': 'deleted_while_locked',
          },
        );
        return false;
      }

      // If another thread already encrypted it while we waited, skip
      if (_isReminderEncrypted(currentReminder)) {
        logger.debug(
          'Reminder ${reminder.id} was already encrypted by another thread',
        );
        analytics.event(
          'reminder_encryption_skipped',
          properties: {
            'reminder_id': reminder.id,
            'reason': 'already_encrypted_by_other_thread',
          },
        );
        return false;
      }

      try {
        logger.info('Lazily encrypting reminder ${reminder.id}');

        // Encrypt plaintext fields (use current data, not stale data)
        final titleEncrypted = await _cryptoBox!.encryptStringForNote(
          userId: currentReminder.userId,
          noteId: currentReminder.noteId,
          text: currentReminder.title,
        );

        final bodyEncrypted = await _cryptoBox!.encryptStringForNote(
          userId: currentReminder.userId,
          noteId: currentReminder.noteId,
          text: currentReminder.body,
        );

        Uint8List? locationNameEncrypted;
        if (currentReminder.locationName != null &&
            currentReminder.locationName!.isNotEmpty) {
          locationNameEncrypted = await _cryptoBox!.encryptStringForNote(
            userId: currentReminder.userId,
            noteId: currentReminder.noteId,
            text: currentReminder.locationName!,
          );
        }

        // CRITICAL #7: Verify encryption roundtrip before saving to database
        // This ensures encrypted data can be decrypted back to original
        logger.debug(
          'Verifying encryption roundtrip for reminder ${reminder.id}',
        );

        final titleVerification =
            await encryption_helper.EncryptionVerificationHelper.verifyField(
              cryptoBox: _cryptoBox!,
              userId: currentReminder.userId,
              noteId: currentReminder.noteId,
              originalValue: currentReminder.title,
              encryptedValue: titleEncrypted,
              fieldName: 'title',
            );

        if (!titleVerification.success) {
          _handleVerificationFailure(titleVerification, reminder.id, 'Title');
        }

        final bodyVerification =
            await encryption_helper.EncryptionVerificationHelper.verifyField(
              cryptoBox: _cryptoBox!,
              userId: currentReminder.userId,
              noteId: currentReminder.noteId,
              originalValue: currentReminder.body,
              encryptedValue: bodyEncrypted,
              fieldName: 'body',
            );

        if (!bodyVerification.success) {
          _handleVerificationFailure(bodyVerification, reminder.id, 'Body');
        }

        // Verify location name if encrypted
        if (locationNameEncrypted != null &&
            currentReminder.locationName != null) {
          final locationVerification =
              await encryption_helper.EncryptionVerificationHelper.verifyField(
                cryptoBox: _cryptoBox!,
                userId: currentReminder.userId,
                noteId: currentReminder.noteId,
                originalValue: currentReminder.locationName!,
                encryptedValue: locationNameEncrypted,
                fieldName: 'locationName',
              );

          if (!locationVerification.success) {
            _handleVerificationFailure(
              locationVerification,
              reminder.id,
              'Location name',
            );
          }
        }

        logger.debug(
          'Encryption verification passed for reminder ${reminder.id}',
        );

        // Update database with encrypted fields
        await db.updateReminder(
          currentReminder.id,
          userId,
          NoteRemindersCompanion(
            titleEncrypted: Value(titleEncrypted),
            bodyEncrypted: Value(bodyEncrypted),
            locationNameEncrypted: locationNameEncrypted != null
                ? Value(locationNameEncrypted)
                : const Value.absent(),
            encryptionVersion: const Value(1),
          ),
        );

        logger.info(
          'Successfully encrypted and verified reminder ${reminder.id}',
        );
        analytics.event(
          'reminder_lazy_encrypted',
          properties: {'reminder_id': reminder.id},
        );

        return true;
      } catch (e, stack) {
        logger.error(
          'Failed to lazily encrypt reminder ${reminder.id}',
          error: e,
          stackTrace: stack,
        );
        analytics.event(
          'reminder_lazy_encryption_failed',
          properties: {'reminder_id': reminder.id, 'error': e.toString()},
        );
        return false;
      }
    });
  }

  /// Get encryption lock statistics for monitoring and debugging
  ///
  /// CRITICAL #6: Monitor lock contention and wait times
  ///
  /// Returns metrics including:
  /// - totalLockAcquisitions: Total number of locks acquired
  /// - averageWaitTimeMs: Average time spent waiting for locks
  /// - contentionRatePercent: Percentage of acquisitions that had to wait
  /// - lockTimeouts: Number of times lock acquisition timed out
  /// - activeLocksCount: Number of currently held locks
  Map<String, dynamic> getEncryptionLockStats() {
    return _encryptionLockManager.getStats();
  }

  // Channel configuration
  static const String channelId = 'notes_reminders';
  static const String channelName = 'Notes Reminders';
  static const String channelDescription = 'Reminders for your notes';

  // Common permission management

  /// Request notification permissions based on platform
  Future<bool> requestNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        final result = await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        logger.info('iOS notification permission result: $result');
        analytics.event(
          'permission_requested',
          properties: {
            'type': 'notification',
            'platform': 'iOS',
            'granted': result ?? false,
          },
        );
        return result ?? false;
      } else {
        final status = await Permission.notification.request();
        final granted = status.isGranted;

        logger.info('Android notification permission status: $status');
        analytics.event(
          'permission_requested',
          properties: {
            'type': 'notification',
            'platform': 'Android',
            'granted': granted,
          },
        );
        return granted;
      }
    } catch (e, stack) {
      logger.error(
        'Failed to request notification permissions',
        error: e,
        stackTrace: stack,
      );
      analytics.event(
        'permission_request_failed',
        properties: {'type': 'notification', 'error': e.toString()},
      );
      return false;
    }
  }

  /// Check if notification permissions are granted
  Future<bool> hasNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      // iOS handles permissions differently, assume true if initialized
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed to check notification permissions',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  // Shared database operations

  /// Create a reminder in the database
  // MIGRATION v41: Changed from int to String (UUID)
  Future<String?> createReminderInDb(NoteRemindersCompanion companion) async {
    try {
      analytics.startTiming('db_create_reminder');

      final reminderId = await db.createReminder(companion);

      analytics.endTiming('db_create_reminder', properties: {'success': true});

      logger.info('Created reminder in database', data: {'id': reminderId});
      return reminderId;
    } catch (e, stack) {
      logger.error(
        'Failed to create reminder in database',
        error: e,
        stackTrace: stack,
      );
      analytics.endTiming(
        'db_create_reminder',
        properties: {'success': false, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Update reminder active status in the database
  // MIGRATION v41: Changed from int to String (UUID)
  Future<void> updateReminderStatus(String id, bool isActive) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot update reminder status - no authenticated user');
        return;
      }

      await db.updateReminder(
        id,
        userId,
        NoteRemindersCompanion(isActive: Value(isActive)),
      );

      logger.info(
        'Updated reminder status',
        data: {'id': id, 'isActive': isActive},
      );

      analytics.event(
        'reminder_status_updated',
        properties: {'reminder_id': id, 'is_active': isActive},
      );
    } catch (e, stack) {
      logger.error(
        'Failed to update reminder status',
        error: e,
        stackTrace: stack,
        data: {'id': id, 'isActive': isActive},
      );
    }
  }

  /// Get all reminders for a note
  ///
  /// **Migration v42**: Applies lazy encryption to plaintext reminders
  /// - Fetches reminders from database
  /// - Attempts to encrypt any plaintext reminders (background operation)
  /// - Returns reminders immediately (doesn't wait for encryption)
  Future<List<NoteReminder>> getRemindersForNote(String noteId) async {
    try {
      // P0.5 SECURITY: Get current userId
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('Cannot get reminders - no authenticated user');
        return [];
      }

      final reminders = await db.getRemindersForNote(noteId, userId);

      // MIGRATION v42: Apply lazy encryption in background
      // Don't await - encryption happens asynchronously
      _applyLazyEncryption(reminders);

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

  /// Apply lazy encryption to reminders in background
  ///
  /// **Migration v42**: Encrypts plaintext reminders as they're accessed
  /// - Runs asynchronously without blocking the caller
  /// - Skips reminders that are already encrypted
  /// - Logs errors but doesn't fail
  Future<void> _applyLazyEncryption(List<NoteReminder> reminders) async {
    if (_cryptoBox == null || reminders.isEmpty) return;

    for (final reminder in reminders) {
      try {
        await ensureReminderEncrypted(reminder);
      } catch (e, stack) {
        // Continue with other reminders - lazy encryption is best-effort
        logger.error(
          'Lazy encryption failed for reminder ${reminder.id}',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  // Common notification scheduling

  /// Schedule a notification using the local notifications plugin
  Future<void> scheduleNotification(ReminderNotificationData data) async {
    try {
      analytics.startTiming('schedule_notification');

      // Ensure timezone is initialized
      if (tz.local.name == 'UTC') {
        logger.warning('Timezone not initialized, using UTC');
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Note Reminder',
        icon: '@mipmap/ic_launcher',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'Snooze',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'complete',
            'Complete',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder_category',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzDate = tz.TZDateTime.from(data.scheduledTime, tz.local);

      // MIGRATION v41: Convert String UUID to int for notification plugin
      final notificationId = data.id.hashCode.abs();

      await plugin.zonedSchedule(
        notificationId,
        data.title,
        data.body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: data.payload,
        // iOS specific parameter removed - deprecated in newer versions
      );

      analytics.endTiming(
        'schedule_notification',
        properties: {'success': true},
      );

      logger.info(
        'Scheduled notification',
        data: {
          'id': data.id,
          'scheduledTime': data.scheduledTime.toIso8601String(),
        },
      );
    } catch (e, stack) {
      logger.error(
        'Failed to schedule notification',
        error: e,
        stackTrace: stack,
        data: {'id': data.id},
      );

      analytics.endTiming(
        'schedule_notification',
        properties: {'success': false, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Cancel a scheduled notification
  // MIGRATION v41: Changed from int to String (UUID)
  Future<void> cancelNotification(String id) async {
    try {
      // Convert String UUID to int for notification plugin
      final notificationId = id.hashCode.abs();
      await plugin.cancel(notificationId);

      logger.info('Cancelled notification', data: {'id': id});
      analytics.event(
        'notification_cancelled',
        properties: {'notification_id': id},
      );
    } catch (e, stack) {
      logger.error(
        'Failed to cancel notification',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
    }
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await plugin.pendingNotificationRequests();
    } catch (e, stack) {
      logger.error(
        'Failed to get pending notifications',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  // Analytics tracking

  /// Track a reminder-related event
  void trackReminderEvent(String event, Map<String, dynamic> properties) {
    analytics.event(event, properties: properties);
  }

  /// Track feature usage
  void trackFeatureUsage(String feature, {Map<String, dynamic>? properties}) {
    analytics.featureUsed(feature, properties: properties ?? {});
  }

  // Template methods for subclasses

  /// Create a reminder with the given configuration
  ///
  /// Subclasses must implement this method to provide specific reminder logic
  // MIGRATION v41: Changed from int to String (UUID)
  Future<String?> createReminder(ReminderConfig config);

  /// Cancel a reminder by ID
  ///
  /// Default implementation cancels the notification and deactivates the reminder
  // MIGRATION v41: Changed from int to String (UUID)
  Future<void> cancelReminder(String id) async {
    await cancelNotification(id);
    await updateReminderStatus(id, false);

    trackReminderEvent('reminder_cancelled', {'reminder_id': id});
  }

  /// Initialize the service
  ///
  /// Subclasses can override to add specific initialization logic
  Future<void> initialize() async {
    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    logger.info('$runtimeType initialized');
    analytics.event(
      'service_initialized',
      properties: {'service': runtimeType.toString()},
    );
  }

  /// Clean up resources
  ///
  /// Subclasses can override to add specific cleanup logic
  Future<void> dispose() async {
    logger.info('$runtimeType disposed');
  }
}
