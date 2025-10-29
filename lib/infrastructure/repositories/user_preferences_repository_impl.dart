// ============================================================================
// USER PREFERENCES REPOSITORY IMPLEMENTATION
// ============================================================================

import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/user_preferences.dart';
import 'package:duru_notes/domain/repositories/i_user_preferences_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-grade implementation of user preferences repository
///
/// Features:
/// - Local caching with 5-minute TTL
/// - Optimistic locking with version tracking
/// - Reactive streams for UI updates
/// - GDPR compliance (export/import)
/// - Proper error handling with custom exceptions
class UserPreferencesRepositoryImpl implements IUserPreferencesRepository {
  UserPreferencesRepositoryImpl({required SupabaseClient client})
    : _supabase = client,
      _logger = LoggerFactory.instance;

  final SupabaseClient _supabase;
  final AppLogger _logger;

  // Cache storage
  UserPreferences? _cachedUserPreferences;
  NotificationPreferences? _cachedNotificationPreferences;
  DateTime? _userPreferencesCacheTime;
  DateTime? _notificationPreferencesCacheTime;

  // Cache TTL (5 minutes as per spec)
  static const _cacheTtl = Duration(minutes: 5);

  // Stream controllers for reactive updates
  final _userPreferencesController =
      StreamController<UserPreferences>.broadcast();
  final _notificationPreferencesController =
      StreamController<NotificationPreferences>.broadcast();

  @override
  Future<UserPreferences> getUserPreferences() async {
    final userId = _getCurrentUserId();

    // Check cache first
    if (_cachedUserPreferences != null &&
        _userPreferencesCacheTime != null &&
        DateTime.now().difference(_userPreferencesCacheTime!) < _cacheTtl) {
      debugPrint('✅ [UserPreferences] Cache hit for user: $userId');
      return _cachedUserPreferences!;
    }

    debugPrint(
      '🔄 [UserPreferences] Cache miss, fetching from database for user: $userId',
    );

    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        throw PreferencesNotFoundException(userId);
      }

      final prefs = UserPreferences.fromJson({...response, 'userId': userId});

      // Update cache
      _cachedUserPreferences = prefs;
      _userPreferencesCacheTime = DateTime.now();

      debugPrint('✅ [UserPreferences] Fetched and cached preferences');
      return prefs;
    } on PostgrestException catch (e) {
      _logger.error('Failed to get user preferences', error: e);
      throw PreferencesException(
        'Failed to get user preferences: ${e.message}',
        e,
      );
    } catch (e) {
      _logger.error('Unexpected error getting user preferences', error: e);
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async {
    final userId = _getCurrentUserId();

    // Check cache first
    if (_cachedNotificationPreferences != null &&
        _notificationPreferencesCacheTime != null &&
        DateTime.now().difference(_notificationPreferencesCacheTime!) <
            _cacheTtl) {
      debugPrint('✅ [NotificationPreferences] Cache hit for user: $userId');
      return _cachedNotificationPreferences!;
    }

    debugPrint(
      '🔄 [NotificationPreferences] Cache miss, fetching from database',
    );

    try {
      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        throw PreferencesNotFoundException(userId);
      }

      final prefs = NotificationPreferences.fromJson(response);

      // Update cache
      _cachedNotificationPreferences = prefs;
      _notificationPreferencesCacheTime = DateTime.now();

      debugPrint('✅ [NotificationPreferences] Fetched and cached preferences');
      return prefs;
    } on PostgrestException catch (e) {
      _logger.error('Failed to get notification preferences', error: e);
      throw PreferencesException(
        'Failed to get notification preferences: ${e.message}',
        e,
      );
    } catch (e) {
      _logger.error(
        'Unexpected error getting notification preferences',
        error: e,
      );
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<UserPreferences> updateUserPreferences(
    UserPreferences preferences,
  ) async {
    final userId = _getCurrentUserId();

    if (preferences.userId != userId) {
      throw PreferencesException(
        'Cannot update preferences for different user',
      );
    }

    debugPrint(
      '🔄 [UserPreferences] Updating preferences with version ${preferences.version}',
    );

    try {
      final response = await _supabase
          .from('user_preferences')
          .update({
            'language': preferences.language.name,
            'theme': preferences.theme.name,
            'timezone': preferences.timezone,
            'notifications_enabled': preferences.notificationsEnabled,
            'analytics_enabled': preferences.analyticsEnabled,
            'error_reporting_enabled': preferences.errorReportingEnabled,
            'data_collection_consent': preferences.dataCollectionConsent,
            'compact_mode': preferences.compactMode,
            'show_inline_images': preferences.showInlineImages,
            'font_size': preferences.fontSize.name,
            'version': preferences.version + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('version', preferences.version) // Optimistic locking
          .select()
          .maybeSingle();

      if (response == null) {
        // Version mismatch - someone else updated the preferences
        final current = await getUserPreferences();
        throw PreferencesConflictException(
          currentVersion: current.version,
          attemptedVersion: preferences.version,
        );
      }

      final updated = UserPreferences.fromJson({...response, 'userId': userId});

      // Invalidate cache and emit update
      _cachedUserPreferences = updated;
      _userPreferencesCacheTime = DateTime.now();
      _userPreferencesController.add(updated);

      debugPrint(
        '✅ [UserPreferences] Updated successfully to version ${updated.version}',
      );
      return updated;
    } on PostgrestException catch (e) {
      _logger.error('Failed to update user preferences', error: e);
      throw PreferencesException(
        'Failed to update user preferences: ${e.message}',
        e,
      );
    } on PreferencesConflictException {
      rethrow;
    } catch (e) {
      _logger.error('Unexpected error updating user preferences', error: e);
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final userId = _getCurrentUserId();

    if (preferences.userId != userId) {
      throw PreferencesException(
        'Cannot update preferences for different user',
      );
    }

    debugPrint(
      '🔄 [NotificationPreferences] Updating with version ${preferences.version}',
    );

    try {
      final response = await _supabase
          .from('notification_preferences')
          .update({
            'enabled': preferences.enabled,
            'push_enabled': preferences.pushEnabled,
            'email_enabled': preferences.emailEnabled,
            'in_app_enabled': preferences.inAppEnabled,
            'sms_enabled': preferences.smsEnabled,
            'quiet_hours_enabled': preferences.quietHours.enabled,
            'quiet_hours_start': preferences.quietHours.enabled
                ? preferences.quietHours.start.toIso8601()
                : null,
            'quiet_hours_end': preferences.quietHours.enabled
                ? preferences.quietHours.end.toIso8601()
                : null,
            'dnd_enabled': preferences.doNotDisturb.enabled,
            'dnd_until': preferences.doNotDisturb.until
                ?.toUtc()
                .toIso8601String(),
            'batch_notifications': preferences.batchNotifications,
            'notification_cooldown_minutes':
                preferences.notificationCooldownMinutes,
            'max_daily_notifications': preferences.maxDailyNotifications,
            'min_priority': preferences.minPriority.name,
            'event_preferences': preferences.eventPreferences,
            'timezone': preferences.timezone,
            'version': preferences.version + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('version', preferences.version) // Optimistic locking
          .select()
          .maybeSingle();

      if (response == null) {
        // Version mismatch
        final current = await getNotificationPreferences();
        throw PreferencesConflictException(
          currentVersion: current.version,
          attemptedVersion: preferences.version,
        );
      }

      final updated = NotificationPreferences.fromJson(response);

      // Invalidate cache and emit update
      _cachedNotificationPreferences = updated;
      _notificationPreferencesCacheTime = DateTime.now();
      _notificationPreferencesController.add(updated);

      debugPrint(
        '✅ [NotificationPreferences] Updated successfully to version ${updated.version}',
      );
      return updated;
    } on PostgrestException catch (e) {
      _logger.error('Failed to update notification preferences', error: e);
      throw PreferencesException(
        'Failed to update notification preferences: ${e.message}',
        e,
      );
    } on PreferencesConflictException {
      rethrow;
    } catch (e) {
      _logger.error(
        'Unexpected error updating notification preferences',
        error: e,
      );
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<UserPreferences> patchUserPreferences(
    Map<String, dynamic> updates,
  ) async {
    final userId = _getCurrentUserId();
    debugPrint('🔄 [UserPreferences] Patching with: $updates');

    try {
      final response = await _supabase
          .from('user_preferences')
          .update({
            ...updates,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();

      final updated = UserPreferences.fromJson({...response, 'userId': userId});

      // Invalidate cache and emit update
      _cachedUserPreferences = updated;
      _userPreferencesCacheTime = DateTime.now();
      _userPreferencesController.add(updated);

      debugPrint('✅ [UserPreferences] Patched successfully');
      return updated;
    } on PostgrestException catch (e) {
      _logger.error('Failed to patch user preferences', error: e);
      throw PreferencesException(
        'Failed to patch user preferences: ${e.message}',
        e,
      );
    } catch (e) {
      _logger.error('Unexpected error patching user preferences', error: e);
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<NotificationPreferences> patchNotificationPreferences(
    Map<String, dynamic> updates,
  ) async {
    final userId = _getCurrentUserId();
    debugPrint('🔄 [NotificationPreferences] Patching with: $updates');

    try {
      final response = await _supabase
          .from('notification_preferences')
          .update({
            ...updates,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();

      final updated = NotificationPreferences.fromJson(response);

      // Invalidate cache and emit update
      _cachedNotificationPreferences = updated;
      _notificationPreferencesCacheTime = DateTime.now();
      _notificationPreferencesController.add(updated);

      debugPrint('✅ [NotificationPreferences] Patched successfully');
      return updated;
    } on PostgrestException catch (e) {
      _logger.error('Failed to patch notification preferences', error: e);
      throw PreferencesException(
        'Failed to patch notification preferences: ${e.message}',
        e,
      );
    } catch (e) {
      _logger.error(
        'Unexpected error patching notification preferences',
        error: e,
      );
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<void> initializePreferences(String userId) async {
    debugPrint('🔄 [UserPreferences] Initializing for user: $userId');

    try {
      // Check if preferences already exist
      final existing = await _supabase
          .from('user_preferences')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ [UserPreferences] Already initialized');
        return;
      }

      // Initialize with defaults
      await _supabase.from('user_preferences').insert({'user_id': userId});

      await _supabase.from('notification_preferences').insert({
        'user_id': userId,
      });

      debugPrint('✅ [UserPreferences] Initialized successfully');
    } on PostgrestException catch (e) {
      // Ignore unique constraint violations (race condition)
      if (e.code != '23505') {
        _logger.error('Failed to initialize preferences', error: e);
        throw PreferencesException(
          'Failed to initialize preferences: ${e.message}',
          e,
        );
      }
      debugPrint('✅ [UserPreferences] Already initialized (race condition)');
    } catch (e) {
      _logger.error('Unexpected error initializing preferences', error: e);
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  @override
  Future<bool> shouldSendNotification({
    required String userId,
    required String eventType,
    required NotificationChannel channel,
    required NotificationPriority priority,
  }) async {
    debugPrint(
      '🔔 [Notification] Checking if should send: $eventType via ${channel.name}',
    );

    try {
      final response = await _supabase.rpc<bool>(
        'should_send_notification',
        params: {
          'p_user_id': userId,
          'p_event_type': eventType,
          'p_channel': channel.name,
          'p_priority': priority.name,
        },
      );

      final shouldSend = response;
      debugPrint('🔔 [Notification] Result: ${shouldSend ? "SEND" : "SKIP"}');
      return shouldSend;
    } on PostgrestException catch (e) {
      _logger.error('Failed to check notification permission', error: e);
      // Fail open - allow notification on error
      return true;
    } catch (e) {
      _logger.error(
        'Unexpected error checking notification permission',
        error: e,
      );
      return true;
    }
  }

  @override
  Future<void> recordNotificationSent(String userId) async {
    debugPrint(
      '🔔 [Notification] Recording notification sent for user: $userId',
    );

    try {
      await _supabase
          .from('notification_preferences')
          .update({
            'last_notification_sent_at': DateTime.now()
                .toUtc()
                .toIso8601String(),
            'daily_notification_count': 1, // Incremented by trigger
          })
          .eq('user_id', userId);

      // Invalidate cache
      _cachedNotificationPreferences = null;
      _notificationPreferencesCacheTime = null;

      debugPrint('✅ [Notification] Recorded successfully');
    } on PostgrestException catch (e) {
      _logger.error('Failed to record notification sent', error: e);
      // Non-critical error, don't throw
    } catch (e) {
      _logger.error('Unexpected error recording notification sent', error: e);
    }
  }

  @override
  void clearCache() {
    debugPrint('🗑️ [UserPreferences] Clearing all caches');
    _cachedUserPreferences = null;
    _cachedNotificationPreferences = null;
    _userPreferencesCacheTime = null;
    _notificationPreferencesCacheTime = null;
  }

  @override
  Stream<UserPreferences> watchUserPreferences() {
    debugPrint('👁️ [UserPreferences] Starting watch stream');

    // Emit current cached value immediately
    if (_cachedUserPreferences != null) {
      Future.microtask(
        () => _userPreferencesController.add(_cachedUserPreferences!),
      );
    }

    return _userPreferencesController.stream;
  }

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() {
    debugPrint('👁️ [NotificationPreferences] Starting watch stream');

    // Emit current cached value immediately
    if (_cachedNotificationPreferences != null) {
      Future.microtask(
        () => _notificationPreferencesController.add(
          _cachedNotificationPreferences!,
        ),
      );
    }

    return _notificationPreferencesController.stream;
  }

  @override
  Future<Map<String, dynamic>> exportPreferences() async {
    final userId = _getCurrentUserId();
    debugPrint('📤 [Export] Exporting preferences for user: $userId');

    try {
      final userPrefs = await getUserPreferences();
      final notificationPrefs = await getNotificationPreferences();

      final export = {
        'version': '1.0',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'userId': userId,
        'userPreferences': userPrefs.toJson(),
        'notificationPreferences': notificationPrefs.toJson(),
      };

      debugPrint('✅ [Export] Exported successfully');
      return export;
    } catch (e) {
      _logger.error('Failed to export preferences', error: e);
      throw PreferencesException('Failed to export preferences: $e', e);
    }
  }

  @override
  Future<void> importPreferences(Map<String, dynamic> data) async {
    final userId = _getCurrentUserId();
    debugPrint('📥 [Import] Importing preferences for user: $userId');

    try {
      // Validate format
      if (data['version'] != '1.0') {
        throw ValidationException(
          'Unsupported export version: ${data['version']}',
        );
      }

      // Import user preferences
      if (data['userPreferences'] != null) {
        final userPrefsData = data['userPreferences'] as Map<String, dynamic>;
        await patchUserPreferences({
          'language': userPrefsData['language'],
          'theme': userPrefsData['theme'],
          'timezone': userPrefsData['timezone'],
          'notifications_enabled': userPrefsData['notificationsEnabled'],
          'analytics_enabled': userPrefsData['analyticsEnabled'],
          'error_reporting_enabled': userPrefsData['errorReportingEnabled'],
          'compact_mode': userPrefsData['compactMode'],
          'show_inline_images': userPrefsData['showInlineImages'],
          'font_size': userPrefsData['fontSize'],
        });
      }

      // Import notification preferences
      if (data['notificationPreferences'] != null) {
        final notifPrefsData =
            data['notificationPreferences'] as Map<String, dynamic>;
        await patchNotificationPreferences({
          'enabled': notifPrefsData['enabled'],
          'push_enabled': notifPrefsData['pushEnabled'],
          'email_enabled': notifPrefsData['emailEnabled'],
          'in_app_enabled': notifPrefsData['inAppEnabled'],
          'batch_notifications': notifPrefsData['batchNotifications'],
          'max_daily_notifications': notifPrefsData['maxDailyNotifications'],
          'min_priority': notifPrefsData['minPriority'],
        });
      }

      debugPrint('✅ [Import] Imported successfully');
    } catch (e) {
      _logger.error('Failed to import preferences', error: e);
      throw PreferencesException('Failed to import preferences: $e', e);
    }
  }

  @override
  Future<void> resetToDefaults() async {
    final userId = _getCurrentUserId();
    debugPrint(
      '⚠️ [Reset] Resetting preferences to defaults for user: $userId',
    );

    try {
      // Delete existing preferences (triggers will recreate with defaults)
      await _supabase.from('user_preferences').delete().eq('user_id', userId);

      await _supabase
          .from('notification_preferences')
          .delete()
          .eq('user_id', userId);

      // Reinitialize
      await initializePreferences(userId);

      // Clear cache
      clearCache();

      debugPrint('✅ [Reset] Reset successfully');
    } on PostgrestException catch (e) {
      _logger.error('Failed to reset preferences', error: e);
      throw PreferencesException(
        'Failed to reset preferences: ${e.message}',
        e,
      );
    } catch (e) {
      _logger.error('Unexpected error resetting preferences', error: e);
      throw PreferencesException('Unexpected error: $e', e);
    }
  }

  /// Get current authenticated user ID
  String _getCurrentUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw NotAuthenticatedException();
    }
    return userId;
  }

  /// Dispose resources
  void dispose() {
    _userPreferencesController.close();
    _notificationPreferencesController.close();
  }
}
