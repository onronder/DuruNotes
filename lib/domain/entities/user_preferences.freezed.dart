// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserPreferences {

 String get userId; LanguageCode get language; ThemePreference get theme; String get timezone; bool get notificationsEnabled; bool get analyticsEnabled; bool get errorReportingEnabled; bool get dataCollectionConsent; bool get compactMode; bool get showInlineImages; FontSize get fontSize; DateTime get createdAt; DateTime get updatedAt; DateTime? get lastSyncedAt; int get version;
/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPreferencesCopyWith<UserPreferences> get copyWith => _$UserPreferencesCopyWithImpl<UserPreferences>(this as UserPreferences, _$identity);

  /// Serializes this UserPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPreferences&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.language, language) || other.language == language)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled)&&(identical(other.analyticsEnabled, analyticsEnabled) || other.analyticsEnabled == analyticsEnabled)&&(identical(other.errorReportingEnabled, errorReportingEnabled) || other.errorReportingEnabled == errorReportingEnabled)&&(identical(other.dataCollectionConsent, dataCollectionConsent) || other.dataCollectionConsent == dataCollectionConsent)&&(identical(other.compactMode, compactMode) || other.compactMode == compactMode)&&(identical(other.showInlineImages, showInlineImages) || other.showInlineImages == showInlineImages)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,language,theme,timezone,notificationsEnabled,analyticsEnabled,errorReportingEnabled,dataCollectionConsent,compactMode,showInlineImages,fontSize,createdAt,updatedAt,lastSyncedAt,version);

@override
String toString() {
  return 'UserPreferences(userId: $userId, language: $language, theme: $theme, timezone: $timezone, notificationsEnabled: $notificationsEnabled, analyticsEnabled: $analyticsEnabled, errorReportingEnabled: $errorReportingEnabled, dataCollectionConsent: $dataCollectionConsent, compactMode: $compactMode, showInlineImages: $showInlineImages, fontSize: $fontSize, createdAt: $createdAt, updatedAt: $updatedAt, lastSyncedAt: $lastSyncedAt, version: $version)';
}


}

/// @nodoc
abstract mixin class $UserPreferencesCopyWith<$Res>  {
  factory $UserPreferencesCopyWith(UserPreferences value, $Res Function(UserPreferences) _then) = _$UserPreferencesCopyWithImpl;
@useResult
$Res call({
 String userId, LanguageCode language, ThemePreference theme, String timezone, bool notificationsEnabled, bool analyticsEnabled, bool errorReportingEnabled, bool dataCollectionConsent, bool compactMode, bool showInlineImages, FontSize fontSize, DateTime createdAt, DateTime updatedAt, DateTime? lastSyncedAt, int version
});




}
/// @nodoc
class _$UserPreferencesCopyWithImpl<$Res>
    implements $UserPreferencesCopyWith<$Res> {
  _$UserPreferencesCopyWithImpl(this._self, this._then);

  final UserPreferences _self;
  final $Res Function(UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? language = null,Object? theme = null,Object? timezone = null,Object? notificationsEnabled = null,Object? analyticsEnabled = null,Object? errorReportingEnabled = null,Object? dataCollectionConsent = null,Object? compactMode = null,Object? showInlineImages = null,Object? fontSize = null,Object? createdAt = null,Object? updatedAt = null,Object? lastSyncedAt = freezed,Object? version = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as LanguageCode,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,analyticsEnabled: null == analyticsEnabled ? _self.analyticsEnabled : analyticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,errorReportingEnabled: null == errorReportingEnabled ? _self.errorReportingEnabled : errorReportingEnabled // ignore: cast_nullable_to_non_nullable
as bool,dataCollectionConsent: null == dataCollectionConsent ? _self.dataCollectionConsent : dataCollectionConsent // ignore: cast_nullable_to_non_nullable
as bool,compactMode: null == compactMode ? _self.compactMode : compactMode // ignore: cast_nullable_to_non_nullable
as bool,showInlineImages: null == showInlineImages ? _self.showInlineImages : showInlineImages // ignore: cast_nullable_to_non_nullable
as bool,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as FontSize,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPreferences].
extension UserPreferencesPatterns on UserPreferences {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPreferences value)  $default,){
final _that = this;
switch (_that) {
case _UserPreferences():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  LanguageCode language,  ThemePreference theme,  String timezone,  bool notificationsEnabled,  bool analyticsEnabled,  bool errorReportingEnabled,  bool dataCollectionConsent,  bool compactMode,  bool showInlineImages,  FontSize fontSize,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastSyncedAt,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.userId,_that.language,_that.theme,_that.timezone,_that.notificationsEnabled,_that.analyticsEnabled,_that.errorReportingEnabled,_that.dataCollectionConsent,_that.compactMode,_that.showInlineImages,_that.fontSize,_that.createdAt,_that.updatedAt,_that.lastSyncedAt,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  LanguageCode language,  ThemePreference theme,  String timezone,  bool notificationsEnabled,  bool analyticsEnabled,  bool errorReportingEnabled,  bool dataCollectionConsent,  bool compactMode,  bool showInlineImages,  FontSize fontSize,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastSyncedAt,  int version)  $default,) {final _that = this;
switch (_that) {
case _UserPreferences():
return $default(_that.userId,_that.language,_that.theme,_that.timezone,_that.notificationsEnabled,_that.analyticsEnabled,_that.errorReportingEnabled,_that.dataCollectionConsent,_that.compactMode,_that.showInlineImages,_that.fontSize,_that.createdAt,_that.updatedAt,_that.lastSyncedAt,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  LanguageCode language,  ThemePreference theme,  String timezone,  bool notificationsEnabled,  bool analyticsEnabled,  bool errorReportingEnabled,  bool dataCollectionConsent,  bool compactMode,  bool showInlineImages,  FontSize fontSize,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastSyncedAt,  int version)?  $default,) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.userId,_that.language,_that.theme,_that.timezone,_that.notificationsEnabled,_that.analyticsEnabled,_that.errorReportingEnabled,_that.dataCollectionConsent,_that.compactMode,_that.showInlineImages,_that.fontSize,_that.createdAt,_that.updatedAt,_that.lastSyncedAt,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserPreferences extends UserPreferences {
  const _UserPreferences({required this.userId, this.language = LanguageCode.en, this.theme = ThemePreference.system, this.timezone = 'UTC', this.notificationsEnabled = true, this.analyticsEnabled = true, this.errorReportingEnabled = true, this.dataCollectionConsent = false, this.compactMode = false, this.showInlineImages = true, this.fontSize = FontSize.medium, required this.createdAt, required this.updatedAt, this.lastSyncedAt, this.version = 1}): super._();
  factory _UserPreferences.fromJson(Map<String, dynamic> json) => _$UserPreferencesFromJson(json);

@override final  String userId;
@override@JsonKey() final  LanguageCode language;
@override@JsonKey() final  ThemePreference theme;
@override@JsonKey() final  String timezone;
@override@JsonKey() final  bool notificationsEnabled;
@override@JsonKey() final  bool analyticsEnabled;
@override@JsonKey() final  bool errorReportingEnabled;
@override@JsonKey() final  bool dataCollectionConsent;
@override@JsonKey() final  bool compactMode;
@override@JsonKey() final  bool showInlineImages;
@override@JsonKey() final  FontSize fontSize;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? lastSyncedAt;
@override@JsonKey() final  int version;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPreferencesCopyWith<_UserPreferences> get copyWith => __$UserPreferencesCopyWithImpl<_UserPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPreferences&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.language, language) || other.language == language)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled)&&(identical(other.analyticsEnabled, analyticsEnabled) || other.analyticsEnabled == analyticsEnabled)&&(identical(other.errorReportingEnabled, errorReportingEnabled) || other.errorReportingEnabled == errorReportingEnabled)&&(identical(other.dataCollectionConsent, dataCollectionConsent) || other.dataCollectionConsent == dataCollectionConsent)&&(identical(other.compactMode, compactMode) || other.compactMode == compactMode)&&(identical(other.showInlineImages, showInlineImages) || other.showInlineImages == showInlineImages)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,language,theme,timezone,notificationsEnabled,analyticsEnabled,errorReportingEnabled,dataCollectionConsent,compactMode,showInlineImages,fontSize,createdAt,updatedAt,lastSyncedAt,version);

@override
String toString() {
  return 'UserPreferences(userId: $userId, language: $language, theme: $theme, timezone: $timezone, notificationsEnabled: $notificationsEnabled, analyticsEnabled: $analyticsEnabled, errorReportingEnabled: $errorReportingEnabled, dataCollectionConsent: $dataCollectionConsent, compactMode: $compactMode, showInlineImages: $showInlineImages, fontSize: $fontSize, createdAt: $createdAt, updatedAt: $updatedAt, lastSyncedAt: $lastSyncedAt, version: $version)';
}


}

/// @nodoc
abstract mixin class _$UserPreferencesCopyWith<$Res> implements $UserPreferencesCopyWith<$Res> {
  factory _$UserPreferencesCopyWith(_UserPreferences value, $Res Function(_UserPreferences) _then) = __$UserPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String userId, LanguageCode language, ThemePreference theme, String timezone, bool notificationsEnabled, bool analyticsEnabled, bool errorReportingEnabled, bool dataCollectionConsent, bool compactMode, bool showInlineImages, FontSize fontSize, DateTime createdAt, DateTime updatedAt, DateTime? lastSyncedAt, int version
});




}
/// @nodoc
class __$UserPreferencesCopyWithImpl<$Res>
    implements _$UserPreferencesCopyWith<$Res> {
  __$UserPreferencesCopyWithImpl(this._self, this._then);

  final _UserPreferences _self;
  final $Res Function(_UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? language = null,Object? theme = null,Object? timezone = null,Object? notificationsEnabled = null,Object? analyticsEnabled = null,Object? errorReportingEnabled = null,Object? dataCollectionConsent = null,Object? compactMode = null,Object? showInlineImages = null,Object? fontSize = null,Object? createdAt = null,Object? updatedAt = null,Object? lastSyncedAt = freezed,Object? version = null,}) {
  return _then(_UserPreferences(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as LanguageCode,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,analyticsEnabled: null == analyticsEnabled ? _self.analyticsEnabled : analyticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,errorReportingEnabled: null == errorReportingEnabled ? _self.errorReportingEnabled : errorReportingEnabled // ignore: cast_nullable_to_non_nullable
as bool,dataCollectionConsent: null == dataCollectionConsent ? _self.dataCollectionConsent : dataCollectionConsent // ignore: cast_nullable_to_non_nullable
as bool,compactMode: null == compactMode ? _self.compactMode : compactMode // ignore: cast_nullable_to_non_nullable
as bool,showInlineImages: null == showInlineImages ? _self.showInlineImages : showInlineImages // ignore: cast_nullable_to_non_nullable
as bool,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as FontSize,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$EventNotificationConfig {

 bool get enabled; NotificationPriority get priority; List<NotificationChannel> get channels;
/// Create a copy of EventNotificationConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventNotificationConfigCopyWith<EventNotificationConfig> get copyWith => _$EventNotificationConfigCopyWithImpl<EventNotificationConfig>(this as EventNotificationConfig, _$identity);

  /// Serializes this EventNotificationConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventNotificationConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.channels, channels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,priority,const DeepCollectionEquality().hash(channels));

@override
String toString() {
  return 'EventNotificationConfig(enabled: $enabled, priority: $priority, channels: $channels)';
}


}

/// @nodoc
abstract mixin class $EventNotificationConfigCopyWith<$Res>  {
  factory $EventNotificationConfigCopyWith(EventNotificationConfig value, $Res Function(EventNotificationConfig) _then) = _$EventNotificationConfigCopyWithImpl;
@useResult
$Res call({
 bool enabled, NotificationPriority priority, List<NotificationChannel> channels
});




}
/// @nodoc
class _$EventNotificationConfigCopyWithImpl<$Res>
    implements $EventNotificationConfigCopyWith<$Res> {
  _$EventNotificationConfigCopyWithImpl(this._self, this._then);

  final EventNotificationConfig _self;
  final $Res Function(EventNotificationConfig) _then;

/// Create a copy of EventNotificationConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? priority = null,Object? channels = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<NotificationChannel>,
  ));
}

}


/// Adds pattern-matching-related methods to [EventNotificationConfig].
extension EventNotificationConfigPatterns on EventNotificationConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventNotificationConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventNotificationConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventNotificationConfig value)  $default,){
final _that = this;
switch (_that) {
case _EventNotificationConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventNotificationConfig value)?  $default,){
final _that = this;
switch (_that) {
case _EventNotificationConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  NotificationPriority priority,  List<NotificationChannel> channels)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventNotificationConfig() when $default != null:
return $default(_that.enabled,_that.priority,_that.channels);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  NotificationPriority priority,  List<NotificationChannel> channels)  $default,) {final _that = this;
switch (_that) {
case _EventNotificationConfig():
return $default(_that.enabled,_that.priority,_that.channels);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  NotificationPriority priority,  List<NotificationChannel> channels)?  $default,) {final _that = this;
switch (_that) {
case _EventNotificationConfig() when $default != null:
return $default(_that.enabled,_that.priority,_that.channels);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventNotificationConfig extends EventNotificationConfig {
  const _EventNotificationConfig({required this.enabled, this.priority = NotificationPriority.normal, final  List<NotificationChannel> channels = const []}): _channels = channels,super._();
  factory _EventNotificationConfig.fromJson(Map<String, dynamic> json) => _$EventNotificationConfigFromJson(json);

@override final  bool enabled;
@override@JsonKey() final  NotificationPriority priority;
 final  List<NotificationChannel> _channels;
@override@JsonKey() List<NotificationChannel> get channels {
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_channels);
}


/// Create a copy of EventNotificationConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventNotificationConfigCopyWith<_EventNotificationConfig> get copyWith => __$EventNotificationConfigCopyWithImpl<_EventNotificationConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventNotificationConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventNotificationConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._channels, _channels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,priority,const DeepCollectionEquality().hash(_channels));

@override
String toString() {
  return 'EventNotificationConfig(enabled: $enabled, priority: $priority, channels: $channels)';
}


}

/// @nodoc
abstract mixin class _$EventNotificationConfigCopyWith<$Res> implements $EventNotificationConfigCopyWith<$Res> {
  factory _$EventNotificationConfigCopyWith(_EventNotificationConfig value, $Res Function(_EventNotificationConfig) _then) = __$EventNotificationConfigCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, NotificationPriority priority, List<NotificationChannel> channels
});




}
/// @nodoc
class __$EventNotificationConfigCopyWithImpl<$Res>
    implements _$EventNotificationConfigCopyWith<$Res> {
  __$EventNotificationConfigCopyWithImpl(this._self, this._then);

  final _EventNotificationConfig _self;
  final $Res Function(_EventNotificationConfig) _then;

/// Create a copy of EventNotificationConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? priority = null,Object? channels = null,}) {
  return _then(_EventNotificationConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<NotificationChannel>,
  ));
}


}

/// @nodoc
mixin _$QuietHours {

 bool get enabled; TimeOfDay get start; TimeOfDay get end;
/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<QuietHours> get copyWith => _$QuietHoursCopyWithImpl<QuietHours>(this as QuietHours, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuietHours&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,start,end);

@override
String toString() {
  return 'QuietHours(enabled: $enabled, start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class $QuietHoursCopyWith<$Res>  {
  factory $QuietHoursCopyWith(QuietHours value, $Res Function(QuietHours) _then) = _$QuietHoursCopyWithImpl;
@useResult
$Res call({
 bool enabled, TimeOfDay start, TimeOfDay end
});




}
/// @nodoc
class _$QuietHoursCopyWithImpl<$Res>
    implements $QuietHoursCopyWith<$Res> {
  _$QuietHoursCopyWithImpl(this._self, this._then);

  final QuietHours _self;
  final $Res Function(QuietHours) _then;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? start = null,Object? end = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as TimeOfDay,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as TimeOfDay,
  ));
}

}


/// Adds pattern-matching-related methods to [QuietHours].
extension QuietHoursPatterns on QuietHours {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuietHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuietHours value)  $default,){
final _that = this;
switch (_that) {
case _QuietHours():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuietHours value)?  $default,){
final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  TimeOfDay start,  TimeOfDay end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that.enabled,_that.start,_that.end);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  TimeOfDay start,  TimeOfDay end)  $default,) {final _that = this;
switch (_that) {
case _QuietHours():
return $default(_that.enabled,_that.start,_that.end);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  TimeOfDay start,  TimeOfDay end)?  $default,) {final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that.enabled,_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc


class _QuietHours extends QuietHours {
  const _QuietHours({required this.enabled, required this.start, required this.end}): super._();
  

@override final  bool enabled;
@override final  TimeOfDay start;
@override final  TimeOfDay end;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuietHoursCopyWith<_QuietHours> get copyWith => __$QuietHoursCopyWithImpl<_QuietHours>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuietHours&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,start,end);

@override
String toString() {
  return 'QuietHours(enabled: $enabled, start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$QuietHoursCopyWith<$Res> implements $QuietHoursCopyWith<$Res> {
  factory _$QuietHoursCopyWith(_QuietHours value, $Res Function(_QuietHours) _then) = __$QuietHoursCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, TimeOfDay start, TimeOfDay end
});




}
/// @nodoc
class __$QuietHoursCopyWithImpl<$Res>
    implements _$QuietHoursCopyWith<$Res> {
  __$QuietHoursCopyWithImpl(this._self, this._then);

  final _QuietHours _self;
  final $Res Function(_QuietHours) _then;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? start = null,Object? end = null,}) {
  return _then(_QuietHours(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as TimeOfDay,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as TimeOfDay,
  ));
}


}


/// @nodoc
mixin _$DoNotDisturb {

 bool get enabled; DateTime? get until;
/// Create a copy of DoNotDisturb
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DoNotDisturbCopyWith<DoNotDisturb> get copyWith => _$DoNotDisturbCopyWithImpl<DoNotDisturb>(this as DoNotDisturb, _$identity);

  /// Serializes this DoNotDisturb to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DoNotDisturb&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.until, until) || other.until == until));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,until);

@override
String toString() {
  return 'DoNotDisturb(enabled: $enabled, until: $until)';
}


}

/// @nodoc
abstract mixin class $DoNotDisturbCopyWith<$Res>  {
  factory $DoNotDisturbCopyWith(DoNotDisturb value, $Res Function(DoNotDisturb) _then) = _$DoNotDisturbCopyWithImpl;
@useResult
$Res call({
 bool enabled, DateTime? until
});




}
/// @nodoc
class _$DoNotDisturbCopyWithImpl<$Res>
    implements $DoNotDisturbCopyWith<$Res> {
  _$DoNotDisturbCopyWithImpl(this._self, this._then);

  final DoNotDisturb _self;
  final $Res Function(DoNotDisturb) _then;

/// Create a copy of DoNotDisturb
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? until = freezed,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,until: freezed == until ? _self.until : until // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [DoNotDisturb].
extension DoNotDisturbPatterns on DoNotDisturb {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DoNotDisturb value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DoNotDisturb() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DoNotDisturb value)  $default,){
final _that = this;
switch (_that) {
case _DoNotDisturb():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DoNotDisturb value)?  $default,){
final _that = this;
switch (_that) {
case _DoNotDisturb() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  DateTime? until)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DoNotDisturb() when $default != null:
return $default(_that.enabled,_that.until);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  DateTime? until)  $default,) {final _that = this;
switch (_that) {
case _DoNotDisturb():
return $default(_that.enabled,_that.until);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  DateTime? until)?  $default,) {final _that = this;
switch (_that) {
case _DoNotDisturb() when $default != null:
return $default(_that.enabled,_that.until);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DoNotDisturb extends DoNotDisturb {
  const _DoNotDisturb({required this.enabled, this.until}): super._();
  factory _DoNotDisturb.fromJson(Map<String, dynamic> json) => _$DoNotDisturbFromJson(json);

@override final  bool enabled;
@override final  DateTime? until;

/// Create a copy of DoNotDisturb
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DoNotDisturbCopyWith<_DoNotDisturb> get copyWith => __$DoNotDisturbCopyWithImpl<_DoNotDisturb>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DoNotDisturbToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DoNotDisturb&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.until, until) || other.until == until));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,until);

@override
String toString() {
  return 'DoNotDisturb(enabled: $enabled, until: $until)';
}


}

/// @nodoc
abstract mixin class _$DoNotDisturbCopyWith<$Res> implements $DoNotDisturbCopyWith<$Res> {
  factory _$DoNotDisturbCopyWith(_DoNotDisturb value, $Res Function(_DoNotDisturb) _then) = __$DoNotDisturbCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, DateTime? until
});




}
/// @nodoc
class __$DoNotDisturbCopyWithImpl<$Res>
    implements _$DoNotDisturbCopyWith<$Res> {
  __$DoNotDisturbCopyWithImpl(this._self, this._then);

  final _DoNotDisturb _self;
  final $Res Function(_DoNotDisturb) _then;

/// Create a copy of DoNotDisturb
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? until = freezed,}) {
  return _then(_DoNotDisturb(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,until: freezed == until ? _self.until : until // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$NotificationPreferences {

 String get id; String get userId; bool get enabled; bool get pushEnabled; bool get emailEnabled; bool get inAppEnabled; bool get smsEnabled; QuietHours get quietHours; DoNotDisturb get doNotDisturb; bool get batchNotifications; int get notificationCooldownMinutes; int get maxDailyNotifications; NotificationPriority get minPriority; Map<String, EventNotificationConfig> get eventPreferences; String get timezone; DateTime get createdAt; DateTime get updatedAt; DateTime? get lastNotificationSentAt; int get dailyNotificationCount; DateTime get dailyCountResetAt; int get version;
/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesCopyWith<NotificationPreferences> get copyWith => _$NotificationPreferencesCopyWithImpl<NotificationPreferences>(this as NotificationPreferences, _$identity);

  /// Serializes this NotificationPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferences&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.pushEnabled, pushEnabled) || other.pushEnabled == pushEnabled)&&(identical(other.emailEnabled, emailEnabled) || other.emailEnabled == emailEnabled)&&(identical(other.inAppEnabled, inAppEnabled) || other.inAppEnabled == inAppEnabled)&&(identical(other.smsEnabled, smsEnabled) || other.smsEnabled == smsEnabled)&&(identical(other.quietHours, quietHours) || other.quietHours == quietHours)&&(identical(other.doNotDisturb, doNotDisturb) || other.doNotDisturb == doNotDisturb)&&(identical(other.batchNotifications, batchNotifications) || other.batchNotifications == batchNotifications)&&(identical(other.notificationCooldownMinutes, notificationCooldownMinutes) || other.notificationCooldownMinutes == notificationCooldownMinutes)&&(identical(other.maxDailyNotifications, maxDailyNotifications) || other.maxDailyNotifications == maxDailyNotifications)&&(identical(other.minPriority, minPriority) || other.minPriority == minPriority)&&const DeepCollectionEquality().equals(other.eventPreferences, eventPreferences)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastNotificationSentAt, lastNotificationSentAt) || other.lastNotificationSentAt == lastNotificationSentAt)&&(identical(other.dailyNotificationCount, dailyNotificationCount) || other.dailyNotificationCount == dailyNotificationCount)&&(identical(other.dailyCountResetAt, dailyCountResetAt) || other.dailyCountResetAt == dailyCountResetAt)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,enabled,pushEnabled,emailEnabled,inAppEnabled,smsEnabled,quietHours,doNotDisturb,batchNotifications,notificationCooldownMinutes,maxDailyNotifications,minPriority,const DeepCollectionEquality().hash(eventPreferences),timezone,createdAt,updatedAt,lastNotificationSentAt,dailyNotificationCount,dailyCountResetAt,version]);

@override
String toString() {
  return 'NotificationPreferences(id: $id, userId: $userId, enabled: $enabled, pushEnabled: $pushEnabled, emailEnabled: $emailEnabled, inAppEnabled: $inAppEnabled, smsEnabled: $smsEnabled, quietHours: $quietHours, doNotDisturb: $doNotDisturb, batchNotifications: $batchNotifications, notificationCooldownMinutes: $notificationCooldownMinutes, maxDailyNotifications: $maxDailyNotifications, minPriority: $minPriority, eventPreferences: $eventPreferences, timezone: $timezone, createdAt: $createdAt, updatedAt: $updatedAt, lastNotificationSentAt: $lastNotificationSentAt, dailyNotificationCount: $dailyNotificationCount, dailyCountResetAt: $dailyCountResetAt, version: $version)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesCopyWith<$Res>  {
  factory $NotificationPreferencesCopyWith(NotificationPreferences value, $Res Function(NotificationPreferences) _then) = _$NotificationPreferencesCopyWithImpl;
@useResult
$Res call({
 String id, String userId, bool enabled, bool pushEnabled, bool emailEnabled, bool inAppEnabled, bool smsEnabled, QuietHours quietHours, DoNotDisturb doNotDisturb, bool batchNotifications, int notificationCooldownMinutes, int maxDailyNotifications, NotificationPriority minPriority, Map<String, EventNotificationConfig> eventPreferences, String timezone, DateTime createdAt, DateTime updatedAt, DateTime? lastNotificationSentAt, int dailyNotificationCount, DateTime dailyCountResetAt, int version
});


$QuietHoursCopyWith<$Res> get quietHours;$DoNotDisturbCopyWith<$Res> get doNotDisturb;

}
/// @nodoc
class _$NotificationPreferencesCopyWithImpl<$Res>
    implements $NotificationPreferencesCopyWith<$Res> {
  _$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final NotificationPreferences _self;
  final $Res Function(NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? enabled = null,Object? pushEnabled = null,Object? emailEnabled = null,Object? inAppEnabled = null,Object? smsEnabled = null,Object? quietHours = null,Object? doNotDisturb = null,Object? batchNotifications = null,Object? notificationCooldownMinutes = null,Object? maxDailyNotifications = null,Object? minPriority = null,Object? eventPreferences = null,Object? timezone = null,Object? createdAt = null,Object? updatedAt = null,Object? lastNotificationSentAt = freezed,Object? dailyNotificationCount = null,Object? dailyCountResetAt = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,pushEnabled: null == pushEnabled ? _self.pushEnabled : pushEnabled // ignore: cast_nullable_to_non_nullable
as bool,emailEnabled: null == emailEnabled ? _self.emailEnabled : emailEnabled // ignore: cast_nullable_to_non_nullable
as bool,inAppEnabled: null == inAppEnabled ? _self.inAppEnabled : inAppEnabled // ignore: cast_nullable_to_non_nullable
as bool,smsEnabled: null == smsEnabled ? _self.smsEnabled : smsEnabled // ignore: cast_nullable_to_non_nullable
as bool,quietHours: null == quietHours ? _self.quietHours : quietHours // ignore: cast_nullable_to_non_nullable
as QuietHours,doNotDisturb: null == doNotDisturb ? _self.doNotDisturb : doNotDisturb // ignore: cast_nullable_to_non_nullable
as DoNotDisturb,batchNotifications: null == batchNotifications ? _self.batchNotifications : batchNotifications // ignore: cast_nullable_to_non_nullable
as bool,notificationCooldownMinutes: null == notificationCooldownMinutes ? _self.notificationCooldownMinutes : notificationCooldownMinutes // ignore: cast_nullable_to_non_nullable
as int,maxDailyNotifications: null == maxDailyNotifications ? _self.maxDailyNotifications : maxDailyNotifications // ignore: cast_nullable_to_non_nullable
as int,minPriority: null == minPriority ? _self.minPriority : minPriority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,eventPreferences: null == eventPreferences ? _self.eventPreferences : eventPreferences // ignore: cast_nullable_to_non_nullable
as Map<String, EventNotificationConfig>,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastNotificationSentAt: freezed == lastNotificationSentAt ? _self.lastNotificationSentAt : lastNotificationSentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dailyNotificationCount: null == dailyNotificationCount ? _self.dailyNotificationCount : dailyNotificationCount // ignore: cast_nullable_to_non_nullable
as int,dailyCountResetAt: null == dailyCountResetAt ? _self.dailyCountResetAt : dailyCountResetAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<$Res> get quietHours {
  
  return $QuietHoursCopyWith<$Res>(_self.quietHours, (value) {
    return _then(_self.copyWith(quietHours: value));
  });
}/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DoNotDisturbCopyWith<$Res> get doNotDisturb {
  
  return $DoNotDisturbCopyWith<$Res>(_self.doNotDisturb, (value) {
    return _then(_self.copyWith(doNotDisturb: value));
  });
}
}


/// Adds pattern-matching-related methods to [NotificationPreferences].
extension NotificationPreferencesPatterns on NotificationPreferences {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPreferences value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  bool enabled,  bool pushEnabled,  bool emailEnabled,  bool inAppEnabled,  bool smsEnabled,  QuietHours quietHours,  DoNotDisturb doNotDisturb,  bool batchNotifications,  int notificationCooldownMinutes,  int maxDailyNotifications,  NotificationPriority minPriority,  Map<String, EventNotificationConfig> eventPreferences,  String timezone,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastNotificationSentAt,  int dailyNotificationCount,  DateTime dailyCountResetAt,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.id,_that.userId,_that.enabled,_that.pushEnabled,_that.emailEnabled,_that.inAppEnabled,_that.smsEnabled,_that.quietHours,_that.doNotDisturb,_that.batchNotifications,_that.notificationCooldownMinutes,_that.maxDailyNotifications,_that.minPriority,_that.eventPreferences,_that.timezone,_that.createdAt,_that.updatedAt,_that.lastNotificationSentAt,_that.dailyNotificationCount,_that.dailyCountResetAt,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  bool enabled,  bool pushEnabled,  bool emailEnabled,  bool inAppEnabled,  bool smsEnabled,  QuietHours quietHours,  DoNotDisturb doNotDisturb,  bool batchNotifications,  int notificationCooldownMinutes,  int maxDailyNotifications,  NotificationPriority minPriority,  Map<String, EventNotificationConfig> eventPreferences,  String timezone,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastNotificationSentAt,  int dailyNotificationCount,  DateTime dailyCountResetAt,  int version)  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences():
return $default(_that.id,_that.userId,_that.enabled,_that.pushEnabled,_that.emailEnabled,_that.inAppEnabled,_that.smsEnabled,_that.quietHours,_that.doNotDisturb,_that.batchNotifications,_that.notificationCooldownMinutes,_that.maxDailyNotifications,_that.minPriority,_that.eventPreferences,_that.timezone,_that.createdAt,_that.updatedAt,_that.lastNotificationSentAt,_that.dailyNotificationCount,_that.dailyCountResetAt,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  bool enabled,  bool pushEnabled,  bool emailEnabled,  bool inAppEnabled,  bool smsEnabled,  QuietHours quietHours,  DoNotDisturb doNotDisturb,  bool batchNotifications,  int notificationCooldownMinutes,  int maxDailyNotifications,  NotificationPriority minPriority,  Map<String, EventNotificationConfig> eventPreferences,  String timezone,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastNotificationSentAt,  int dailyNotificationCount,  DateTime dailyCountResetAt,  int version)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.id,_that.userId,_that.enabled,_that.pushEnabled,_that.emailEnabled,_that.inAppEnabled,_that.smsEnabled,_that.quietHours,_that.doNotDisturb,_that.batchNotifications,_that.notificationCooldownMinutes,_that.maxDailyNotifications,_that.minPriority,_that.eventPreferences,_that.timezone,_that.createdAt,_that.updatedAt,_that.lastNotificationSentAt,_that.dailyNotificationCount,_that.dailyCountResetAt,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationPreferences extends NotificationPreferences {
  const _NotificationPreferences({required this.id, required this.userId, this.enabled = true, this.pushEnabled = true, this.emailEnabled = false, this.inAppEnabled = true, this.smsEnabled = false, required this.quietHours, required this.doNotDisturb, this.batchNotifications = false, this.notificationCooldownMinutes = 5, this.maxDailyNotifications = 50, this.minPriority = NotificationPriority.low, final  Map<String, EventNotificationConfig> eventPreferences = const {}, this.timezone = 'UTC', required this.createdAt, required this.updatedAt, this.lastNotificationSentAt, this.dailyNotificationCount = 0, required this.dailyCountResetAt, this.version = 1}): _eventPreferences = eventPreferences,super._();
  factory _NotificationPreferences.fromJson(Map<String, dynamic> json) => _$NotificationPreferencesFromJson(json);

@override final  String id;
@override final  String userId;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool pushEnabled;
@override@JsonKey() final  bool emailEnabled;
@override@JsonKey() final  bool inAppEnabled;
@override@JsonKey() final  bool smsEnabled;
@override final  QuietHours quietHours;
@override final  DoNotDisturb doNotDisturb;
@override@JsonKey() final  bool batchNotifications;
@override@JsonKey() final  int notificationCooldownMinutes;
@override@JsonKey() final  int maxDailyNotifications;
@override@JsonKey() final  NotificationPriority minPriority;
 final  Map<String, EventNotificationConfig> _eventPreferences;
@override@JsonKey() Map<String, EventNotificationConfig> get eventPreferences {
  if (_eventPreferences is EqualUnmodifiableMapView) return _eventPreferences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_eventPreferences);
}

@override@JsonKey() final  String timezone;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? lastNotificationSentAt;
@override@JsonKey() final  int dailyNotificationCount;
@override final  DateTime dailyCountResetAt;
@override@JsonKey() final  int version;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesCopyWith<_NotificationPreferences> get copyWith => __$NotificationPreferencesCopyWithImpl<_NotificationPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferences&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.pushEnabled, pushEnabled) || other.pushEnabled == pushEnabled)&&(identical(other.emailEnabled, emailEnabled) || other.emailEnabled == emailEnabled)&&(identical(other.inAppEnabled, inAppEnabled) || other.inAppEnabled == inAppEnabled)&&(identical(other.smsEnabled, smsEnabled) || other.smsEnabled == smsEnabled)&&(identical(other.quietHours, quietHours) || other.quietHours == quietHours)&&(identical(other.doNotDisturb, doNotDisturb) || other.doNotDisturb == doNotDisturb)&&(identical(other.batchNotifications, batchNotifications) || other.batchNotifications == batchNotifications)&&(identical(other.notificationCooldownMinutes, notificationCooldownMinutes) || other.notificationCooldownMinutes == notificationCooldownMinutes)&&(identical(other.maxDailyNotifications, maxDailyNotifications) || other.maxDailyNotifications == maxDailyNotifications)&&(identical(other.minPriority, minPriority) || other.minPriority == minPriority)&&const DeepCollectionEquality().equals(other._eventPreferences, _eventPreferences)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastNotificationSentAt, lastNotificationSentAt) || other.lastNotificationSentAt == lastNotificationSentAt)&&(identical(other.dailyNotificationCount, dailyNotificationCount) || other.dailyNotificationCount == dailyNotificationCount)&&(identical(other.dailyCountResetAt, dailyCountResetAt) || other.dailyCountResetAt == dailyCountResetAt)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,enabled,pushEnabled,emailEnabled,inAppEnabled,smsEnabled,quietHours,doNotDisturb,batchNotifications,notificationCooldownMinutes,maxDailyNotifications,minPriority,const DeepCollectionEquality().hash(_eventPreferences),timezone,createdAt,updatedAt,lastNotificationSentAt,dailyNotificationCount,dailyCountResetAt,version]);

@override
String toString() {
  return 'NotificationPreferences(id: $id, userId: $userId, enabled: $enabled, pushEnabled: $pushEnabled, emailEnabled: $emailEnabled, inAppEnabled: $inAppEnabled, smsEnabled: $smsEnabled, quietHours: $quietHours, doNotDisturb: $doNotDisturb, batchNotifications: $batchNotifications, notificationCooldownMinutes: $notificationCooldownMinutes, maxDailyNotifications: $maxDailyNotifications, minPriority: $minPriority, eventPreferences: $eventPreferences, timezone: $timezone, createdAt: $createdAt, updatedAt: $updatedAt, lastNotificationSentAt: $lastNotificationSentAt, dailyNotificationCount: $dailyNotificationCount, dailyCountResetAt: $dailyCountResetAt, version: $version)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesCopyWith<$Res> implements $NotificationPreferencesCopyWith<$Res> {
  factory _$NotificationPreferencesCopyWith(_NotificationPreferences value, $Res Function(_NotificationPreferences) _then) = __$NotificationPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, bool enabled, bool pushEnabled, bool emailEnabled, bool inAppEnabled, bool smsEnabled, QuietHours quietHours, DoNotDisturb doNotDisturb, bool batchNotifications, int notificationCooldownMinutes, int maxDailyNotifications, NotificationPriority minPriority, Map<String, EventNotificationConfig> eventPreferences, String timezone, DateTime createdAt, DateTime updatedAt, DateTime? lastNotificationSentAt, int dailyNotificationCount, DateTime dailyCountResetAt, int version
});


@override $QuietHoursCopyWith<$Res> get quietHours;@override $DoNotDisturbCopyWith<$Res> get doNotDisturb;

}
/// @nodoc
class __$NotificationPreferencesCopyWithImpl<$Res>
    implements _$NotificationPreferencesCopyWith<$Res> {
  __$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final _NotificationPreferences _self;
  final $Res Function(_NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? enabled = null,Object? pushEnabled = null,Object? emailEnabled = null,Object? inAppEnabled = null,Object? smsEnabled = null,Object? quietHours = null,Object? doNotDisturb = null,Object? batchNotifications = null,Object? notificationCooldownMinutes = null,Object? maxDailyNotifications = null,Object? minPriority = null,Object? eventPreferences = null,Object? timezone = null,Object? createdAt = null,Object? updatedAt = null,Object? lastNotificationSentAt = freezed,Object? dailyNotificationCount = null,Object? dailyCountResetAt = null,Object? version = null,}) {
  return _then(_NotificationPreferences(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,pushEnabled: null == pushEnabled ? _self.pushEnabled : pushEnabled // ignore: cast_nullable_to_non_nullable
as bool,emailEnabled: null == emailEnabled ? _self.emailEnabled : emailEnabled // ignore: cast_nullable_to_non_nullable
as bool,inAppEnabled: null == inAppEnabled ? _self.inAppEnabled : inAppEnabled // ignore: cast_nullable_to_non_nullable
as bool,smsEnabled: null == smsEnabled ? _self.smsEnabled : smsEnabled // ignore: cast_nullable_to_non_nullable
as bool,quietHours: null == quietHours ? _self.quietHours : quietHours // ignore: cast_nullable_to_non_nullable
as QuietHours,doNotDisturb: null == doNotDisturb ? _self.doNotDisturb : doNotDisturb // ignore: cast_nullable_to_non_nullable
as DoNotDisturb,batchNotifications: null == batchNotifications ? _self.batchNotifications : batchNotifications // ignore: cast_nullable_to_non_nullable
as bool,notificationCooldownMinutes: null == notificationCooldownMinutes ? _self.notificationCooldownMinutes : notificationCooldownMinutes // ignore: cast_nullable_to_non_nullable
as int,maxDailyNotifications: null == maxDailyNotifications ? _self.maxDailyNotifications : maxDailyNotifications // ignore: cast_nullable_to_non_nullable
as int,minPriority: null == minPriority ? _self.minPriority : minPriority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,eventPreferences: null == eventPreferences ? _self._eventPreferences : eventPreferences // ignore: cast_nullable_to_non_nullable
as Map<String, EventNotificationConfig>,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastNotificationSentAt: freezed == lastNotificationSentAt ? _self.lastNotificationSentAt : lastNotificationSentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dailyNotificationCount: null == dailyNotificationCount ? _self.dailyNotificationCount : dailyNotificationCount // ignore: cast_nullable_to_non_nullable
as int,dailyCountResetAt: null == dailyCountResetAt ? _self.dailyCountResetAt : dailyCountResetAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<$Res> get quietHours {
  
  return $QuietHoursCopyWith<$Res>(_self.quietHours, (value) {
    return _then(_self.copyWith(quietHours: value));
  });
}/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DoNotDisturbCopyWith<$Res> get doNotDisturb {
  
  return $DoNotDisturbCopyWith<$Res>(_self.doNotDisturb, (value) {
    return _then(_self.copyWith(doNotDisturb: value));
  });
}
}

// dart format on
