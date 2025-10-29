import 'package:duru_notes/core/settings/user_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier for managing theme mode settings
///
/// Handles both local (SharedPreferences) and remote (database) storage:
/// - Local: Fast access for UI rendering
/// - Remote: Future features (web dashboard, email reports matching theme)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._preferencesService) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  final UserPreferencesService _preferencesService;

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

        // Sync to database in background (fire-and-forget)
        // This ensures database is up-to-date even if it wasn't synced before
        _preferencesService.syncThemePreference(mode.name);
      }
    } catch (e) {
      // If loading fails, keep default system mode
      state = ThemeMode.system;
    }
  }

  /// Set the theme mode and persist it to both local and remote storage
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Step 1: Update local storage (fast, synchronous user feedback)
      await prefs.setString(_themeModeKey, mode.name);

      // Step 2: Update UI state immediately
      state = mode;

      // Step 3: Sync to database in background (fire-and-forget)
      // This enables future features like web dashboard matching theme
      // Don't await - run in background to avoid blocking UI
      _preferencesService.syncThemePreference(mode.name);
    } catch (e) {
      // Handle error silently - theme change will fail but won't crash
      // Local storage error is rare but could happen if disk is full
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
