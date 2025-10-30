import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/settings/analytics_notifier.dart';
import 'package:duru_notes/core/settings/locale_notifier.dart';
import 'package:duru_notes/core/settings/theme_mode_notifier.dart';
import 'package:duru_notes/core/settings/user_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Logger provider - imported from bootstrap for settings features
final loggerProvider = bootstrapLoggerProvider;

/// User preferences service provider
///
/// Manages remote storage of user preferences (language, theme, notifications)
/// Required for server-side operations like push notifications
final userPreferencesServiceProvider = Provider<UserPreferencesService>((ref) {
  final client = Supabase.instance.client;
  final logger = ref.watch(loggerProvider);

  return UserPreferencesService(client: client, logger: logger);
});

/// Theme mode provider with database sync
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final preferencesService = ref.watch(userPreferencesServiceProvider);
  return ThemeModeNotifier(preferencesService);
});

/// Locale provider with database sync
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final preferencesService = ref.watch(userPreferencesServiceProvider);
  return LocaleNotifier(preferencesService);
});

/// Analytics settings provider
final analyticsSettingsProvider =
    StateNotifierProvider<AnalyticsNotifier, bool>((ref) {
      final analytics = ref.watch(analyticsProvider);
      return AnalyticsNotifier(analytics);
    });
