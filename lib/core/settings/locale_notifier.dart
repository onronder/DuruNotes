import 'dart:ui';

import 'package:duru_notes/core/settings/user_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier for managing locale settings
///
/// Handles both local (SharedPreferences) and remote (database) storage:
/// - Local: Fast access for UI rendering
/// - Remote: Server-side operations (push notifications, email processing)
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._preferencesService) : super(null);

  final UserPreferencesService _preferencesService;

  static const String _localeKey = 'app_locale';

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('tr'), // Turkish
    Locale('es'), // Spanish
    Locale('de'), // German
    Locale('fr'), // French
  ];

  /// Load locale from SharedPreferences
  /// CRITICAL: Called after first frame to avoid blocking during widget build
  Future<void> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);

      if (localeCode != null) {
        final locale = Locale(localeCode);
        if (supportedLocales.contains(locale)) {
          state = locale;

          // Sync to database in background (fire-and-forget)
          // This ensures database is up-to-date even if it wasn't synced before
          _preferencesService.syncLanguagePreference(locale.languageCode);
        }
      }
    } catch (e) {
      // If loading fails, keep system default (null)
      state = null;
    }
  }

  /// Set the locale and persist it to both local and remote storage
  Future<void> setLocale(Locale? locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Step 1: Update local storage (fast, synchronous user feedback)
      if (locale == null) {
        await prefs.remove(_localeKey);
      } else {
        await prefs.setString(_localeKey, locale.languageCode);
      }

      // Step 2: Update UI state immediately
      state = locale;

      // Step 3: Sync to database in background (fire-and-forget)
      // This ensures push notifications are sent in correct language
      if (locale != null) {
        // Don't await - run in background to avoid blocking UI
        _preferencesService.syncLanguagePreference(locale.languageCode);
      }
    } catch (e) {
      // Handle error silently - locale change will fail but won't crash
      // Local storage error is rare but could happen if disk is full
    }
  }
}

extension LocaleExtension on Locale {
  /// Human-readable name for the locale
  String get displayName {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      default:
        return languageCode.toUpperCase();
    }
  }

  /// Flag emoji for the locale
  String get flagEmoji {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'tr':
        return '🇹🇷';
      default:
        return '🌐';
    }
  }
}
