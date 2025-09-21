import 'package:flutter/services.dart';

/// Standardized haptic feedback utilities for consistent user experience
class HapticUtils {
  HapticUtils._();

  /// Direct wrappers around Flutter's haptic feedback API for consistency
  static Future<void> lightImpact() => HapticFeedback.lightImpact();
  static Future<void> mediumImpact() => HapticFeedback.mediumImpact();
  static Future<void> heavyImpact() => HapticFeedback.heavyImpact();
  static Future<void> selectionClick() => HapticFeedback.selectionClick();

  /// Light haptic for selections, toggles, and navigation
  static Future<void> selection() => lightImpact();

  /// Medium haptic for confirmations and successful actions
  static Future<void> success() => mediumImpact();

  /// Medium haptic for destructive actions (delete, remove)
  static Future<void> destructive() => mediumImpact();

  /// Heavy haptic for error states
  static Future<void> error() => heavyImpact();

  /// Selection click for rapid interactions (typing, incrementing)
  static Future<void> tap() => selectionClick();
}
