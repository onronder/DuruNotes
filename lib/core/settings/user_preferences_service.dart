import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User preferences stored in remote database for server-side operations
///
/// This is separate from local SharedPreferences because:
/// - Server-side operations (push notifications, email processing) need access
/// - Cross-device consistency for server-sent messages
/// - Local preferences (theme, UI) remain in SharedPreferences for fast access
class UserPreferencesService {
  UserPreferencesService({
    required SupabaseClient client,
    required AppLogger logger,
  }) : _client = client,
       _logger = logger;

  final SupabaseClient _client;
  final AppLogger _logger;

  /// Sync language preference to database
  ///
  /// This ensures server-side operations (like push notifications)
  /// can send messages in the user's preferred language
  Future<void> syncLanguagePreference(String languageCode) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning(
          '[UserPreferences] Cannot sync language - user not authenticated',
        );
        return;
      }

      _logger.info(
        '[UserPreferences] Syncing language preference: $languageCode for user ${userId.substring(0, 8)}',
      );

      await _client.from('user_preferences').upsert({
        'user_id': userId,
        'language': languageCode,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _logger.info('[UserPreferences] Language preference synced successfully');
    } on PostgrestException catch (e) {
      // Database error - log but don't throw (graceful degradation)
      _logger.error(
        '[UserPreferences] Database error syncing language',
        error: e,
      );
    } catch (e) {
      // Network or other error - log but don't throw
      _logger.error(
        '[UserPreferences] Error syncing language preference',
        error: e,
      );
    }
  }

  /// Sync theme preference to database
  ///
  /// Useful for future features like web dashboard or email reports
  /// that might want to match user's theme preference
  Future<void> syncThemePreference(String theme) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning(
          '[UserPreferences] Cannot sync theme - user not authenticated',
        );
        return;
      }

      _logger.info(
        '[UserPreferences] Syncing theme preference: $theme for user ${userId.substring(0, 8)}',
      );

      await _client.from('user_preferences').upsert({
        'user_id': userId,
        'theme': theme,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _logger.info('[UserPreferences] Theme preference synced successfully');
    } on PostgrestException catch (e) {
      _logger.error('[UserPreferences] Database error syncing theme', error: e);
    } catch (e) {
      _logger.error(
        '[UserPreferences] Error syncing theme preference',
        error: e,
      );
    }
  }

  /// Sync notification preference to database
  Future<void> syncNotificationsEnabled(bool enabled) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning(
          '[UserPreferences] Cannot sync notifications - user not authenticated',
        );
        return;
      }

      _logger.info(
        '[UserPreferences] Syncing notifications enabled: $enabled for user ${userId.substring(0, 8)}',
      );

      await _client.from('user_preferences').upsert({
        'user_id': userId,
        'notifications_enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _logger.info(
        '[UserPreferences] Notifications preference synced successfully',
      );
    } on PostgrestException catch (e) {
      _logger.error(
        '[UserPreferences] Database error syncing notifications',
        error: e,
      );
    } catch (e) {
      _logger.error(
        '[UserPreferences] Error syncing notifications preference',
        error: e,
      );
    }
  }

  /// Initialize user preferences in database from local storage
  ///
  /// Called once when user first signs in or after table creation
  /// to backfill existing users' preferences
  Future<void> initializePreferences({
    String? languageCode,
    String? theme,
    bool? notificationsEnabled,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning(
          '[UserPreferences] Cannot initialize - user not authenticated',
        );
        return;
      }

      _logger.info(
        '[UserPreferences] Initializing preferences for user ${userId.substring(0, 8)}',
      );

      // Check if preferences already exist
      final existing = await _client
          .from('user_preferences')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        _logger.info(
          '[UserPreferences] Preferences already exist, skipping initialization',
        );
        return;
      }

      // Create initial preferences
      final data = <String, dynamic>{
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (languageCode != null) {
        data['language'] = languageCode;
      }
      if (theme != null) {
        data['theme'] = theme;
      }
      if (notificationsEnabled != null) {
        data['notifications_enabled'] = notificationsEnabled;
      }

      await _client.from('user_preferences').insert(data);

      _logger.info('[UserPreferences] Preferences initialized successfully');
    } on PostgrestException catch (e) {
      _logger.error(
        '[UserPreferences] Database error initializing preferences',
        error: e,
      );
    } catch (e) {
      _logger.error(
        '[UserPreferences] Error initializing preferences',
        error: e,
      );
    }
  }

  /// Get current user preferences from database
  ///
  /// Used for debugging and verification
  Future<Map<String, dynamic>?> getUserPreferences() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final data = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      _logger.error('[UserPreferences] Error fetching preferences', error: e);
      return null;
    }
  }
}
