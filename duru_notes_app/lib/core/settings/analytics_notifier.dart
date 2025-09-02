import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/analytics/analytics_service.dart';

/// Notifier for managing analytics settings
class AnalyticsNotifier extends StateNotifier<bool> {
  AnalyticsNotifier(this._analyticsService) : super(true) {
    _loadAnalyticsSettings();
  }

  final AnalyticsService _analyticsService;
  static const String _analyticsEnabledKey = 'analytics_enabled';

  /// Load analytics settings from SharedPreferences
  Future<void> _loadAnalyticsSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_analyticsEnabledKey) ?? true;
      state = enabled;
      
      // Apply the setting to the analytics service
      if (enabled) {
        _analyticsService.enable();
      } else {
        _analyticsService.disable();
      }
    } catch (e) {
      // If loading fails, keep default enabled state
      state = true;
    }
  }

  /// Set analytics enabled state and persist it
  Future<void> setAnalyticsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, enabled);
      state = enabled;
      
      // Apply the setting to the analytics service
      if (enabled) {
        _analyticsService.enable();
      } else {
        _analyticsService.disable();
      }
    } catch (e) {
      // Handle error silently - analytics setting change will fail but won't crash
    }
  }
}
