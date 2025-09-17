import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier for managing theme mode settings
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  static const String _themeModeKey = 'theme_mode';

  /// Load theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_themeModeKey);

      if (modeString != null) {
        final mode = ThemeMode.values.firstWhere(
          (e) => e.name == modeString,
          orElse: () => ThemeMode.system,
        );
        state = mode;
      }
    } catch (e) {
      // If loading fails, keep default system mode
      state = ThemeMode.system;
    }
  }

  /// Set the theme mode and persist it
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
      state = mode;
    } catch (e) {
      // Handle error silently - theme change will fail but won't crash
    }
  }
}

extension ThemeModeExtension on ThemeMode {
  /// Human-readable name for the theme mode
  String get displayName {
    switch (this) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  /// Icon for the theme mode
  IconData get icon {
    switch (this) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
