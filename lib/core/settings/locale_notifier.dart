import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier for managing locale settings
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  static const String _localeKey = 'app_locale';

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('tr'), // Turkish
  ];

  /// Load locale from SharedPreferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);

      if (localeCode != null) {
        final locale = Locale(localeCode);
        if (supportedLocales.contains(locale)) {
          state = locale;
        }
      }
    } catch (e) {
      // If loading fails, keep system default (null)
      state = null;
    }
  }

  /// Set the locale and persist it
  Future<void> setLocale(Locale? locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (locale == null) {
        await prefs.remove(_localeKey);
      } else {
        await prefs.setString(_localeKey, locale.languageCode);
      }

      state = locale;
    } catch (e) {
      // Handle error silently - locale change will fail but won't crash
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
