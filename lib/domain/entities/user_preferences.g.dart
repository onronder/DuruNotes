// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    _UserPreferences(
      userId: json['userId'] as String,
      language:
          $enumDecodeNullable(_$LanguageCodeEnumMap, json['language']) ??
          LanguageCode.en,
      theme:
          $enumDecodeNullable(_$ThemePreferenceEnumMap, json['theme']) ??
          ThemePreference.system,
      timezone: json['timezone'] as String? ?? 'UTC',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      errorReportingEnabled: json['errorReportingEnabled'] as bool? ?? true,
      dataCollectionConsent: json['dataCollectionConsent'] as bool? ?? false,
      compactMode: json['compactMode'] as bool? ?? false,
      showInlineImages: json['showInlineImages'] as bool? ?? true,
      fontSize:
          $enumDecodeNullable(_$FontSizeEnumMap, json['fontSize']) ??
          FontSize.medium,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$UserPreferencesToJson(_UserPreferences instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'language': _$LanguageCodeEnumMap[instance.language]!,
      'theme': _$ThemePreferenceEnumMap[instance.theme]!,
      'timezone': instance.timezone,
      'notificationsEnabled': instance.notificationsEnabled,
      'analyticsEnabled': instance.analyticsEnabled,
      'errorReportingEnabled': instance.errorReportingEnabled,
      'dataCollectionConsent': instance.dataCollectionConsent,
      'compactMode': instance.compactMode,
      'showInlineImages': instance.showInlineImages,
      'fontSize': _$FontSizeEnumMap[instance.fontSize]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'version': instance.version,
    };

const _$LanguageCodeEnumMap = {
  LanguageCode.en: 'en',
  LanguageCode.tr: 'tr',
  LanguageCode.es: 'es',
  LanguageCode.fr: 'fr',
  LanguageCode.de: 'de',
  LanguageCode.pt: 'pt',
  LanguageCode.ru: 'ru',
  LanguageCode.zh: 'zh',
  LanguageCode.ja: 'ja',
  LanguageCode.ko: 'ko',
};

const _$ThemePreferenceEnumMap = {
  ThemePreference.light: 'light',
  ThemePreference.dark: 'dark',
  ThemePreference.system: 'system',
};

const _$FontSizeEnumMap = {
  FontSize.small: 'small',
  FontSize.medium: 'medium',
  FontSize.large: 'large',
};

_EventNotificationConfig _$EventNotificationConfigFromJson(
  Map<String, dynamic> json,
) => _EventNotificationConfig(
  enabled: json['enabled'] as bool,
  priority:
      $enumDecodeNullable(_$NotificationPriorityEnumMap, json['priority']) ??
      NotificationPriority.normal,
  channels:
      (json['channels'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$NotificationChannelEnumMap, e))
          .toList() ??
      const [],
);

Map<String, dynamic> _$EventNotificationConfigToJson(
  _EventNotificationConfig instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'priority': _$NotificationPriorityEnumMap[instance.priority]!,
  'channels': instance.channels
      .map((e) => _$NotificationChannelEnumMap[e]!)
      .toList(),
};

const _$NotificationPriorityEnumMap = {
  NotificationPriority.low: 'low',
  NotificationPriority.normal: 'normal',
  NotificationPriority.high: 'high',
  NotificationPriority.urgent: 'urgent',
};

const _$NotificationChannelEnumMap = {
  NotificationChannel.push: 'push',
  NotificationChannel.email: 'email',
  NotificationChannel.inApp: 'inApp',
  NotificationChannel.sms: 'sms',
};

_DoNotDisturb _$DoNotDisturbFromJson(Map<String, dynamic> json) =>
    _DoNotDisturb(
      enabled: json['enabled'] as bool,
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
    );

Map<String, dynamic> _$DoNotDisturbToJson(_DoNotDisturb instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'until': instance.until?.toIso8601String(),
    };

_NotificationPreferences _$NotificationPreferencesFromJson(
  Map<String, dynamic> json,
) => _NotificationPreferences(
  id: json['id'] as String,
  userId: json['userId'] as String,
  enabled: json['enabled'] as bool? ?? true,
  pushEnabled: json['pushEnabled'] as bool? ?? true,
  emailEnabled: json['emailEnabled'] as bool? ?? false,
  inAppEnabled: json['inAppEnabled'] as bool? ?? true,
  smsEnabled: json['smsEnabled'] as bool? ?? false,
  quietHours: QuietHours.fromJson(json['quietHours'] as Map<String, dynamic>),
  doNotDisturb: DoNotDisturb.fromJson(
    json['doNotDisturb'] as Map<String, dynamic>,
  ),
  batchNotifications: json['batchNotifications'] as bool? ?? false,
  notificationCooldownMinutes:
      (json['notificationCooldownMinutes'] as num?)?.toInt() ?? 5,
  maxDailyNotifications: (json['maxDailyNotifications'] as num?)?.toInt() ?? 50,
  minPriority:
      $enumDecodeNullable(_$NotificationPriorityEnumMap, json['minPriority']) ??
      NotificationPriority.low,
  eventPreferences:
      (json['eventPreferences'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          EventNotificationConfig.fromJson(e as Map<String, dynamic>),
        ),
      ) ??
      const {},
  timezone: json['timezone'] as String? ?? 'UTC',
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  lastNotificationSentAt: json['lastNotificationSentAt'] == null
      ? null
      : DateTime.parse(json['lastNotificationSentAt'] as String),
  dailyNotificationCount:
      (json['dailyNotificationCount'] as num?)?.toInt() ?? 0,
  dailyCountResetAt: DateTime.parse(json['dailyCountResetAt'] as String),
  version: (json['version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$NotificationPreferencesToJson(
  _NotificationPreferences instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'enabled': instance.enabled,
  'pushEnabled': instance.pushEnabled,
  'emailEnabled': instance.emailEnabled,
  'inAppEnabled': instance.inAppEnabled,
  'smsEnabled': instance.smsEnabled,
  'quietHours': instance.quietHours,
  'doNotDisturb': instance.doNotDisturb,
  'batchNotifications': instance.batchNotifications,
  'notificationCooldownMinutes': instance.notificationCooldownMinutes,
  'maxDailyNotifications': instance.maxDailyNotifications,
  'minPriority': _$NotificationPriorityEnumMap[instance.minPriority]!,
  'eventPreferences': instance.eventPreferences,
  'timezone': instance.timezone,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'lastNotificationSentAt': instance.lastNotificationSentAt?.toIso8601String(),
  'dailyNotificationCount': instance.dailyNotificationCount,
  'dailyCountResetAt': instance.dailyCountResetAt.toIso8601String(),
  'version': instance.version,
};
