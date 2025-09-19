import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Notification action types
enum NotificationAction { 
  open, 
  reply, 
  markAsRead, 
  dismiss, 
  custom,
  // Task-specific actions
  completeTask,
  snoozeTask,
  openTask,
}

/// Notification payload data
class NotificationPayload {
  const NotificationPayload({
    required this.eventId,
    required this.eventType,
    required this.title,
    required this.body,
    this.data = const {},
    this.action,
    this.deepLink,
    this.imageUrl,
  });

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      eventId: (json['event_id'] as String?) ?? '',
      eventType: (json['event_type'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      action: json['action'] != null
          ? NotificationAction.values.firstWhere(
              (e) => e.name == json['action'],
              orElse: () => NotificationAction.open,
            )
          : null,
      deepLink: json['deep_link'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  final String eventId;
  final String eventType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final NotificationAction? action;
  final String? deepLink;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'event_type': eventType,
    'title': title,
    'body': body,
    'data': data,
    'action': action?.name,
    'deep_link': deepLink,
    'image_url': imageUrl,
  };
}

/// Service for handling push notifications and displaying them
class NotificationHandlerService {
  NotificationHandlerService({
    SupabaseClient? client,
    AppLogger? logger,
    PushNotificationService? pushService,
  }) : _client = client ?? Supabase.instance.client,
       _logger = logger ?? LoggerFactory.instance,
       _pushService = pushService ?? PushNotificationService();

  final SupabaseClient _client;
  final AppLogger _logger;
  final PushNotificationService _pushService;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream controllers for notification events
  final _notificationTapSubject = BehaviorSubject<NotificationPayload>();
  final _notificationActionSubject = BehaviorSubject<NotificationPayload>();
  final _foregroundMessageSubject = BehaviorSubject<RemoteMessage>();

  // Public streams
  Stream<NotificationPayload> get onNotificationTap =>
      _notificationTapSubject.stream;
  Stream<NotificationPayload> get onNotificationAction =>
      _notificationActionSubject.stream;
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageSubject.stream;

  // Notification channels
  static const String _defaultChannelId = 'duru_notes_default';
  static const String _defaultChannelName = 'General Notifications';
  static const String _emailChannelId = 'duru_notes_email';
  static const String _emailChannelName = 'Email Notifications';
  static const String _reminderChannelId = 'duru_notes_reminder';
  static const String _reminderChannelName = 'Reminders';

  // State
  bool _isInitialized = false;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;

  /// Initialize the notification handler service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing notification handler service');

      // Initialize push notification service
      await _pushService.initialize();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up Firebase message handlers
      await _setupFirebaseHandlers();

      // Load notification preferences
      await _loadPreferences();

      _isInitialized = true;
      _logger.info('Notification handler service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize notification handler service: $e');
      rethrow;
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We handle this via Firebase
      requestBadgePermission: false,
      requestSoundPermission: false,
      // onDidReceiveLocalNotification removed in newer versions
    );

    // Platform settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with callback for notification taps
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Default channel
    const defaultChannel = AndroidNotificationChannel(
      _defaultChannelId,
      _defaultChannelName,
      description: 'General app notifications',
      importance: Importance.high,
    );

    // Email channel
    const emailChannel = AndroidNotificationChannel(
      _emailChannelId,
      _emailChannelName,
      description: 'Notifications for new emails',
      importance: Importance.high,
    );

    // Reminder channel
    const reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      description: 'Note reminders',
      importance: Importance.max,
      enableLights: true,
    );

    await androidPlugin.createNotificationChannel(defaultChannel);
    await androidPlugin.createNotificationChannel(emailChannel);
    await androidPlugin.createNotificationChannel(reminderChannel);
  }

  /// Set up Firebase message handlers
  Future<void> _setupFirebaseHandlers() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (error) {
        _logger.error('Error in foreground message stream: $error');
      },
    );

    // Handle message opened app (when app was in background)
    _backgroundMessageSubscription = FirebaseMessaging.onMessageOpenedApp
        .listen(
          _handleMessageOpenedApp,
          onError: (error) {
            _logger.error('Error in message opened app stream: $error');
          },
        );

    // Check if app was opened from a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleInitialMessage(initialMessage);
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Received foreground message: ${message.messageId}');

    // Emit to stream for app handling
    _foregroundMessageSubject.add(message);

    // Parse notification data
    final payload = _parseRemoteMessage(message);

    // Check if we should show local notification
    final shouldShow = await _shouldShowNotification(payload);
    if (!shouldShow) {
      _logger.info('Notification suppressed based on preferences');
      return;
    }

    // Display local notification
    await _showLocalNotification(payload);

    // Update delivery status
    await _updateDeliveryStatus(
      payload.eventId,
      'delivered',
      metadata: {'displayed_locally': true},
    );
  }

  /// Handle message that opened the app
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    _logger.info('App opened from notification: ${message.messageId}');

    final payload = _parseRemoteMessage(message);

    // Emit tap event
    _notificationTapSubject.add(payload);

    // Update analytics
    await _updateDeliveryStatus(
      payload.eventId,
      'opened',
      metadata: {'opened_at': DateTime.now().toIso8601String()},
    );
  }

  /// Handle initial message (app was terminated)
  Future<void> _handleInitialMessage(RemoteMessage message) async {
    _logger.info('App launched from notification: ${message.messageId}');

    final payload = _parseRemoteMessage(message);

    // Delay to ensure app is ready
    await Future.delayed(const Duration(seconds: 1));

    // Emit tap event
    _notificationTapSubject.add(payload);

    // Update analytics
    await _updateDeliveryStatus(
      payload.eventId,
      'opened',
      metadata: {
        'opened_at': DateTime.now().toIso8601String(),
        'cold_start': true,
      },
    );
  }

  /// Parse RemoteMessage to NotificationPayload
  NotificationPayload _parseRemoteMessage(RemoteMessage message) {
    final data = message.data;

    return NotificationPayload(
      eventId: (data['event_id'] as String?) ?? '',
      eventType: (data['event_type'] as String?) ?? '',
      title:
          message.notification?.title ??
          (data['title'] as String?) ??
          'Notification',
      body: message.notification?.body ?? (data['body'] as String?) ?? '',
      data: data,
      deepLink: data['deep_link'] as String?,
      imageUrl:
          message.notification?.android?.imageUrl ??
          message.notification?.apple?.imageUrl,
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification(NotificationPayload payload) async {
    try {
      // Select channel based on event type
      var channelId = _defaultChannelId;
      if (payload.eventType == 'email_received') {
        channelId = _emailChannelId;
      } else if (payload.eventType == 'reminder_due') {
        channelId = _reminderChannelId;
      }

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.high,
        priority: Priority.high,
        when: DateTime.now().millisecondsSinceEpoch,
        enableLights: true,
        styleInformation: BigTextStyleInformation(
          payload.body,
          contentTitle: payload.title,
          summaryText: _getEventTypeSummary(payload.eventType),
        ),
        category: _getAndroidCategory(payload.eventType),
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        threadIdentifier: 'duru_notes',
      );

      // Platform details
      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique ID
      final notificationId = payload.eventId.hashCode;

      // Show notification
      await _localNotifications.show(
        notificationId,
        payload.title,
        payload.body,
        platformDetails,
        payload: jsonEncode(payload.toJson()),
      );

      _logger.info('Local notification shown: ${payload.eventId}');
    } catch (e) {
      _logger.error('Failed to show local notification: $e');
    }
  }

  /// Handle notification response (tap/action)
  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    try {
      if (response.payload == null) return;

      final payload = NotificationPayload.fromJson(
        jsonDecode(response.payload!) as Map<String, dynamic>,
      );

      // Handle based on action type
      if (response.actionId != null) {
        // Custom action button was pressed
        await _handleNotificationAction(payload, response.actionId!);
      } else {
        // Notification was tapped
        _notificationTapSubject.add(payload);
      }

      // Update analytics
      await _updateDeliveryStatus(
        payload.eventId,
        'clicked',
        metadata: {
          'clicked_at': DateTime.now().toIso8601String(),
          'action': response.actionId,
        },
      );
    } catch (e) {
      _logger.error('Failed to handle notification response: $e');
    }
  }

  /// Handle notification action
  Future<void> _handleNotificationAction(
    NotificationPayload payload,
    String actionId,
  ) async {
    _logger.info('Notification action: $actionId for ${payload.eventId}');

    // Emit action event
    final actionPayload = NotificationPayload(
      eventId: payload.eventId,
      eventType: payload.eventType,
      title: payload.title,
      body: payload.body,
      data: {...payload.data, 'action_id': actionId},
      action: _parseAction(actionId),
      deepLink: payload.deepLink,
    );

    _notificationActionSubject.add(actionPayload);
  }

  /// Parse action ID to enum
  NotificationAction _parseAction(String actionId) {
    switch (actionId) {
      case 'reply':
        return NotificationAction.reply;
      case 'mark_read':
        return NotificationAction.markAsRead;
      case 'dismiss':
        return NotificationAction.dismiss;
      case 'complete_task':
        return NotificationAction.completeTask;
      case 'snooze_task_15':
      case 'snooze_task_1h':
        return NotificationAction.snoozeTask;
      case 'open_task':
        return NotificationAction.openTask;
      default:
        return NotificationAction.custom;
    }
  }

  /// Check if notification should be shown based on preferences
  Future<bool> _shouldShowNotification(NotificationPayload payload) async {
    try {
      // Get user preferences from Supabase
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // No preferences, show by default
        return true;
      }

      // Check if notifications are enabled
      if (response['enabled'] != true) {
        return false;
      }

      // Check event-specific preferences
      final eventPrefs = response['event_preferences'] as Map<String, dynamic>?;
      if (eventPrefs != null && eventPrefs.containsKey(payload.eventType)) {
        final eventEnabled =
            (eventPrefs[payload.eventType]['enabled'] as bool?) ?? true;
        if (!eventEnabled) {
          return false;
        }
      }

      // Check quiet hours
      if (response['quiet_hours_enabled'] == true) {
        final now = DateTime.now();
        final startTime = response['quiet_hours_start'] as String?;
        final endTime = response['quiet_hours_end'] as String?;

        if (startTime != null && endTime != null) {
          // Parse times and check if in quiet hours
          final start = _parseTime(startTime);
          final end = _parseTime(endTime);
          final currentMinutes = now.hour * 60 + now.minute;

          if (currentMinutes >= start && currentMinutes <= end) {
            return false; // In quiet hours
          }
        }
      }

      // Check DND
      if (response['dnd_enabled'] == true) {
        final dndUntil = response['dnd_until'] as String?;
        if (dndUntil != null) {
          final dndEnd = DateTime.parse(dndUntil);
          if (DateTime.now().isBefore(dndEnd)) {
            return false; // Still in DND
          }
        }
      }

      return true;
    } catch (e) {
      _logger.error('Failed to check notification preferences: $e');
      // Show by default on error
      return true;
    }
  }

  /// Parse time string (HH:MM) to minutes
  int _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return hours * 60 + minutes;
  }

  /// Update delivery status in database
  Future<void> _updateDeliveryStatus(
    String eventId,
    String status, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (eventId.isEmpty) return;

      await _client
          .from('notification_deliveries')
          .update({
            'status': status,
            '${status}_at': DateTime.now().toIso8601String(),
            if (metadata != null) 'provider_response': metadata,
          })
          .eq('event_id', eventId);
    } catch (e) {
      _logger.error('Failed to update delivery status: $e');
    }
  }

  /// Load user preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load any cached preferences
      // This can be used for offline support
    } catch (e) {
      _logger.error('Failed to load preferences: $e');
    }
  }

  /// Get channel name for channel ID
  String _getChannelName(String channelId) {
    switch (channelId) {
      case _emailChannelId:
        return _emailChannelName;
      case _reminderChannelId:
        return _reminderChannelName;
      default:
        return _defaultChannelName;
    }
  }

  /// Get channel description for channel ID
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _emailChannelId:
        return 'Notifications for new emails';
      case _reminderChannelId:
        return 'Note reminders';
      default:
        return 'General app notifications';
    }
  }

  /// Get event type summary text
  String _getEventTypeSummary(String eventType) {
    switch (eventType) {
      case 'email_received':
        return 'New Email';
      case 'web_clip_saved':
        return 'Web Clip';
      case 'note_shared':
        return 'Shared Note';
      case 'reminder_due':
        return 'Reminder';
      default:
        return 'DuruNotes';
    }
  }

  /// Get Android notification category
  AndroidNotificationCategory? _getAndroidCategory(String eventType) {
    switch (eventType) {
      case 'email_received':
        return AndroidNotificationCategory.email;
      case 'reminder_due':
        return AndroidNotificationCategory.reminder;
      case 'note_shared':
        return AndroidNotificationCategory.social;
      default:
        return null;
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    _logger.info('All notifications cleared');
  }

  /// Clear specific notification
  Future<void> clearNotification(String eventId) async {
    await _localNotifications.cancel(eventId.hashCode);
    _logger.info('Notification cleared: $eventId');
  }

  /// Update badge count (iOS)
  Future<void> updateBadgeCount(int count) async {
    if (Platform.isIOS) {
      // This would typically be handled by the iOS plugin
      _logger.info('Badge count updated: $count');
    }
  }

  /// Dispose of resources
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _backgroundMessageSubscription?.cancel();
    _notificationTapSubject.close();
    _notificationActionSubject.close();
    _foregroundMessageSubject.close();
  }
}

/// Background message handler (top-level function required by Firebase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // Note: This runs in an isolate, so we need minimal processing here

  debugPrint('Background message received: ${message.messageId}');

  // You can store the message for later processing or show a notification
  // But keep this handler lightweight
}

/// Background notification response handler
@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {
  // Handle notification actions in background
  debugPrint('Background notification response: ${response.actionId}');
}
