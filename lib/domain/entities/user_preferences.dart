// ============================================================================
// PRODUCTION-GRADE USER PREFERENCES DOMAIN MODEL
// ============================================================================

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

/// Language codes supported by the app
enum LanguageCode {
  en,
  tr,
  es,
  fr,
  de,
  pt,
  ru,
  zh,
  ja,
  ko;

  String get displayName {
    switch (this) {
      case LanguageCode.en:
        return 'English';
      case LanguageCode.tr:
        return 'Türkçe';
      case LanguageCode.es:
        return 'Español';
      case LanguageCode.fr:
        return 'Français';
      case LanguageCode.de:
        return 'Deutsch';
      case LanguageCode.pt:
        return 'Português';
      case LanguageCode.ru:
        return 'Русский';
      case LanguageCode.zh:
        return '中文';
      case LanguageCode.ja:
        return '日本語';
      case LanguageCode.ko:
        return '한국어';
    }
  }

  String get localeName {
    switch (this) {
      case LanguageCode.en:
        return 'en_US';
      case LanguageCode.tr:
        return 'tr_TR';
      case LanguageCode.es:
        return 'es_ES';
      case LanguageCode.fr:
        return 'fr_FR';
      case LanguageCode.de:
        return 'de_DE';
      case LanguageCode.pt:
        return 'pt_PT';
      case LanguageCode.ru:
        return 'ru_RU';
      case LanguageCode.zh:
        return 'zh_CN';
      case LanguageCode.ja:
        return 'ja_JP';
      case LanguageCode.ko:
        return 'ko_KR';
    }
  }
}

/// Theme preference options
enum ThemePreference {
  light,
  dark,
  system;

  String get displayName {
    switch (this) {
      case ThemePreference.light:
        return 'Light';
      case ThemePreference.dark:
        return 'Dark';
      case ThemePreference.system:
        return 'System Default';
    }
  }
}

/// Font size options
enum FontSize {
  small,
  medium,
  large;

  double get multiplier {
    switch (this) {
      case FontSize.small:
        return 0.9;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.1;
    }
  }
}

/// User preferences domain entity
@freezed
abstract class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    required String userId,
    @Default(LanguageCode.en) LanguageCode language,
    @Default(ThemePreference.system) ThemePreference theme,
    @Default('UTC') String timezone,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool analyticsEnabled,
    @Default(true) bool errorReportingEnabled,
    @Default(false) bool dataCollectionConsent,
    @Default(false) bool compactMode,
    @Default(true) bool showInlineImages,
    @Default(FontSize.medium) FontSize fontSize,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastSyncedAt,
    @Default(1) int version,
  }) = _UserPreferences;

  const UserPreferences._();

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);

  /// Create default preferences for a new user
  factory UserPreferences.newUser(String userId) {
    final now = DateTime.now();
    return UserPreferences(userId: userId, createdAt: now, updatedAt: now);
  }

  /// Check if preferences are stale and need syncing
  bool get needsSync {
    if (lastSyncedAt == null) return true;
    final staleDuration = DateTime.now().difference(lastSyncedAt!);
    return staleDuration.inMinutes > 5; // Sync every 5 minutes
  }

  /// Check if GDPR consent is required
  bool get needsGdprConsent {
    return !dataCollectionConsent;
  }
}

/// Notification channel types
enum NotificationChannel {
  push,
  email,
  inApp,
  sms;

  String get displayName {
    switch (this) {
      case NotificationChannel.push:
        return 'Push Notifications';
      case NotificationChannel.email:
        return 'Email';
      case NotificationChannel.inApp:
        return 'In-App';
      case NotificationChannel.sms:
        return 'SMS';
    }
  }
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  int get value => index;
}

/// Event-specific notification configuration
@freezed
abstract class EventNotificationConfig with _$EventNotificationConfig {
  const factory EventNotificationConfig({
    required bool enabled,
    @Default(NotificationPriority.normal) NotificationPriority priority,
    @Default([]) List<NotificationChannel> channels,
  }) = _EventNotificationConfig;

  const EventNotificationConfig._();

  factory EventNotificationConfig.fromJson(Map<String, dynamic> json) =>
      _$EventNotificationConfigFromJson(json);

  /// Check if a specific channel is enabled for this event
  bool hasChannel(NotificationChannel channel) {
    return channels.contains(channel);
  }
}

/// Quiet hours configuration
@Freezed(toJson: false, fromJson: false)
abstract class QuietHours with _$QuietHours {
  const factory QuietHours({
    required bool enabled,
    required TimeOfDay start,
    required TimeOfDay end,
  }) = _QuietHours;

  const QuietHours._();

  /// Check if current time is within quiet hours
  bool isQuietTime() {
    if (!enabled) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Normal case: quiet hours within same day
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      // Quiet hours span midnight
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      enabled: json['enabled'] as bool? ?? false,
      start: json['start'] != null
          ? TimeOfDay(
              hour: int.parse((json['start'] as String).split(':')[0]),
              minute: int.parse((json['start'] as String).split(':')[1]),
            )
          : const TimeOfDay(hour: 22, minute: 0),
      end: json['end'] != null
          ? TimeOfDay(
              hour: int.parse((json['end'] as String).split(':')[0]),
              minute: int.parse((json['end'] as String).split(':')[1]),
            )
          : const TimeOfDay(hour: 7, minute: 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'start':
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      'end':
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
    };
  }
}

/// Do Not Disturb configuration
@freezed
abstract class DoNotDisturb with _$DoNotDisturb {
  const factory DoNotDisturb({required bool enabled, DateTime? until}) =
      _DoNotDisturb;

  const DoNotDisturb._();

  factory DoNotDisturb.fromJson(Map<String, dynamic> json) =>
      _$DoNotDisturbFromJson(json);

  /// Check if DND is currently active
  bool get isActive {
    if (!enabled) return false;
    if (until == null) return false; // Indefinite DND not supported
    return DateTime.now().isBefore(until!);
  }

  /// Get remaining duration
  Duration? get remaining {
    if (!isActive) return null;
    return until!.difference(DateTime.now());
  }
}

/// Notification preferences domain entity
@freezed
abstract class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    required String id,
    required String userId,
    @Default(true) bool enabled,
    @Default(true) bool pushEnabled,
    @Default(false) bool emailEnabled,
    @Default(true) bool inAppEnabled,
    @Default(false) bool smsEnabled,
    required QuietHours quietHours,
    required DoNotDisturb doNotDisturb,
    @Default(false) bool batchNotifications,
    @Default(5) int notificationCooldownMinutes,
    @Default(50) int maxDailyNotifications,
    @Default(NotificationPriority.low) NotificationPriority minPriority,
    @Default({}) Map<String, EventNotificationConfig> eventPreferences,
    @Default('UTC') String timezone,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastNotificationSentAt,
    @Default(0) int dailyNotificationCount,
    required DateTime dailyCountResetAt,
    @Default(1) int version,
  }) = _NotificationPreferences;

  const NotificationPreferences._();

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);

  /// Create default notification preferences for a new user
  factory NotificationPreferences.newUser(String userId) {
    final now = DateTime.now();
    return NotificationPreferences(
      id: '', // Generated by database
      userId: userId,
      quietHours: const QuietHours(
        enabled: false,
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 7, minute: 0),
      ),
      doNotDisturb: const DoNotDisturb(enabled: false),
      createdAt: now,
      updatedAt: now,
      dailyCountResetAt: DateTime(now.year, now.month, now.day),
    );
  }

  /// Check if a notification should be sent
  bool shouldSendNotification({
    required String eventType,
    required NotificationChannel channel,
    required NotificationPriority priority,
  }) {
    // Master toggle
    if (!enabled) return false;

    // Do Not Disturb
    if (doNotDisturb.isActive) {
      // Only urgent notifications during DND
      if (priority != NotificationPriority.urgent) return false;
    }

    // Daily limit reached
    if (dailyNotificationCount >= maxDailyNotifications) return false;

    // Priority threshold
    if (priority.value < minPriority.value) return false;

    // Channel disabled
    if (channel == NotificationChannel.push && !pushEnabled) return false;
    if (channel == NotificationChannel.email && !emailEnabled) return false;
    if (channel == NotificationChannel.inApp && !inAppEnabled) return false;
    if (channel == NotificationChannel.sms && !smsEnabled) return false;

    // Quiet hours (allow urgent notifications)
    if (quietHours.isQuietTime() && priority != NotificationPriority.urgent) {
      return false;
    }

    // Event-specific preferences
    final eventConfig = eventPreferences[eventType];
    if (eventConfig != null) {
      if (!eventConfig.enabled) return false;
      if (!eventConfig.hasChannel(channel)) return false;
    }

    return true;
  }

  /// Check if daily limit needs reset
  bool get needsDailyReset {
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).isAfter(dailyCountResetAt);
  }

  /// Get configuration for a specific event
  EventNotificationConfig? getEventConfig(String eventType) {
    return eventPreferences[eventType];
  }
}

// ============================================================================
// TIME OF DAY EXTENSION (Helper for TimeOfDay serialization)
// ============================================================================

extension TimeOfDayExtension on TimeOfDay {
  static TimeOfDay now() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }

  String toIso8601() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay fromIso8601(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
