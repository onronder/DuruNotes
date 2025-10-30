import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/settings/user_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes user preferences in database from local storage
///
/// Called once when:
/// - User first signs in
/// - App starts after user_preferences table is created
/// - Ensures existing users' preferences are synced to database
class PreferencesInitializer {
  PreferencesInitializer({
    required UserPreferencesService preferencesService,
    required AppLogger logger,
  }) : _preferencesService = preferencesService,
       _logger = logger;

  final UserPreferencesService _preferencesService;
  final AppLogger _logger;

  /// Initialize preferences from local storage to database
  ///
  /// This is a one-time operation that:
  /// 1. Reads current locale and theme from SharedPreferences
  /// 2. Syncs them to database if not already present
  /// 3. Ensures push notifications use correct language from day 1
  Future<void> initialize() async {
    try {
      _logger.info(
        '[PreferencesInitializer] Starting preferences initialization',
      );

      // Load local preferences
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString('app_locale');
      final themeMode = prefs.getString('theme_mode');

      _logger.info(
        '[PreferencesInitializer] Found local preferences - locale: $localeCode, theme: $themeMode',
      );

      // Initialize in database
      await _preferencesService.initializePreferences(
        languageCode: localeCode,
        theme: themeMode,
        notificationsEnabled: true, // Default to enabled
      );

      _logger.info(
        '[PreferencesInitializer] Preferences initialization completed',
      );
    } catch (e) {
      // Don't throw - this is a non-critical operation
      // If it fails, preferences will sync when user changes settings
      _logger.error(
        '[PreferencesInitializer] Error during initialization',
        error: e,
      );
    }
  }

  /// Check if preferences need initialization
  ///
  /// Returns true if user has local preferences but no database record
  Future<bool> needsInitialization() async {
    try {
      // Check if user has database preferences
      final dbPrefs = await _preferencesService.getUserPreferences();
      if (dbPrefs != null) {
        _logger.info(
          '[PreferencesInitializer] Database preferences exist, no initialization needed',
        );
        return false;
      }

      // Check if user has local preferences
      final prefs = await SharedPreferences.getInstance();
      final hasLocalPreferences =
          prefs.getString('app_locale') != null ||
          prefs.getString('theme_mode') != null;

      if (hasLocalPreferences) {
        _logger.info(
          '[PreferencesInitializer] Local preferences exist but no database record - initialization needed',
        );
        return true;
      }

      _logger.info(
        '[PreferencesInitializer] No preferences found - will initialize on first change',
      );
      return false;
    } catch (e) {
      _logger.error(
        '[PreferencesInitializer] Error checking initialization status',
        error: e,
      );
      return false;
    }
  }
}
