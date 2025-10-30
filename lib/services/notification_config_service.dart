import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to configure notification actions and categories
class NotificationConfigService {
  NotificationConfigService._();

  static final NotificationConfigService _instance =
      NotificationConfigService._();
  static NotificationConfigService get instance => _instance;

  final AppLogger _logger = LoggerFactory.instance;

  /// Configure notification initialization settings with actions
  InitializationSettings getInitializationSettings() {
    return InitializationSettings(
      android: _getAndroidSettings(),
      iOS: _getIOSSettings(),
    );
  }

  /// Get Android initialization settings
  AndroidInitializationSettings _getAndroidSettings() {
    return const AndroidInitializationSettings('@mipmap/ic_launcher');
  }

  /// Get iOS initialization settings with categories
  DarwinInitializationSettings _getIOSSettings() {
    return DarwinInitializationSettings(
      notificationCategories: _getIOSCategories(),
    );
  }

  /// Define iOS notification categories and actions
  List<DarwinNotificationCategory> _getIOSCategories() {
    return [
      // Task reminder category with actions
      DarwinNotificationCategory(
        'TASK_REMINDER',
        actions: [
          DarwinNotificationAction.plain(
            'complete_task',
            'Complete',
            options: const {DarwinNotificationActionOption.destructive},
          ),
          DarwinNotificationAction.plain('snooze_task_5', '5m'),
          DarwinNotificationAction.plain('snooze_task_15', '15m'),
          DarwinNotificationAction.plain('snooze_task_1h', '1h'),
          DarwinNotificationAction.plain('snooze_task_tomorrow', 'Tomorrow'),
          DarwinNotificationAction.plain(
            'open_task',
            'Open',
            options: const {DarwinNotificationActionOption.foreground},
          ),
        ],
        options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
      ),

      // Note reminder category
      DarwinNotificationCategory(
        'NOTE_REMINDER',
        actions: [
          DarwinNotificationAction.plain(
            'open_note',
            'Open',
            options: const {DarwinNotificationActionOption.foreground},
          ),
          DarwinNotificationAction.plain('snooze_15', 'Snooze 15m'),
          DarwinNotificationAction.plain(
            'dismiss',
            'Dismiss',
            options: const {DarwinNotificationActionOption.destructive},
          ),
        ],
      ),
    ];
  }

  /// Get Android notification actions for task reminders
  List<AndroidNotificationAction> getTaskNotificationActions() {
    return const [
      AndroidNotificationAction(
        'complete_task',
        'Complete',
        cancelNotification: true,
        showsUserInterface: false,
        icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
      ),
      AndroidNotificationAction(
        'snooze_task_15',
        '15m',
        cancelNotification: true,
        showsUserInterface: false,
        icon: DrawableResourceAndroidBitmap('@drawable/ic_snooze'),
      ),
      AndroidNotificationAction(
        'snooze_task_1h',
        '1h',
        cancelNotification: true,
        showsUserInterface: false,
        icon: DrawableResourceAndroidBitmap('@drawable/ic_snooze'),
      ),
      AndroidNotificationAction(
        'snooze_task_tomorrow',
        'Tomorrow',
        cancelNotification: true,
        showsUserInterface: false,
        icon: DrawableResourceAndroidBitmap('@drawable/ic_snooze'),
      ),
      AndroidNotificationAction(
        'open_task',
        'Open',
        cancelNotification: false,
        showsUserInterface: true,
        icon: DrawableResourceAndroidBitmap('@drawable/ic_open'),
      ),
    ];
  }

  /// Handle notification response (when user taps notification or action)
  Future<void> handleNotificationResponse(
    NotificationResponse response,
    void Function(String action, String payload) onAction,
  ) async {
    try {
      _logger.info(
        'Notification response received',
        data: {
          'actionId': response.actionId,
          'payload': response.payload,
          'notificationResponseType': response.notificationResponseType
              .toString(),
        },
      );

      // Get action ID (null for simple tap, string for action button)
      final action = response.actionId ?? 'tap';
      final payload = response.payload ?? '{}';

      // Delegate to action handler
      onAction(action, payload);
    } catch (e, stack) {
      _logger.error(
        'Failed to handle notification response',
        error: e,
        stackTrace: stack,
        data: {'actionId': response.actionId, 'payload': response.payload},
      );
    }
  }
}
