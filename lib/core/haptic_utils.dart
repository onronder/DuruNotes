import 'package:flutter/services.dart';

/// Standardized haptic feedback utilities for consistent user experience
class HapticUtils {
  HapticUtils._();

  /// Light haptic for selections, toggles, and navigation
  static Future<void> selection() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium haptic for confirmations and successful actions
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }

  /// Medium haptic for destructive actions (delete, remove)
  static Future<void> destructive() async {
    await HapticFeedback.mediumImpact();
  }

  /// Light haptic for error states
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click for rapid interactions (typing, incrementing)
  static Future<void> tap() async {
    await HapticFeedback.selectionClick();
  }
}
