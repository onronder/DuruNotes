import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/settings/analytics_notifier.dart';
import 'package:duru_notes/core/settings/locale_notifier.dart';
import 'package:duru_notes/core/settings/theme_mode_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

/// Locale provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Analytics settings provider
final analyticsSettingsProvider =
    StateNotifierProvider<AnalyticsNotifier, bool>((ref) {
  final analytics = ref.watch(analyticsProvider);
  return AnalyticsNotifier(analytics);
});