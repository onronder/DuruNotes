/// Cross-Platform Design Tokens for Duru Notes
///
/// Universal design system that adapts to platform conventions while
/// maintaining brand consistency across iOS, Android, Web, Mac, and Windows.
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform detection utility
class DuruPlatform {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWeb => kIsWeb;

  static bool get isMobile => isIOS || isAndroid;
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Get the appropriate touch target size for the current platform
  static double get touchTargetSize {
    if (isIOS) return 44.0;        // iOS Human Interface Guidelines
    if (isAndroid) return 48.0;    // Material Design Guidelines
    if (isWeb) return 44.0;        // Touch-friendly web standard
    return 32.0;                   // Desktop mouse precision
  }
}

/// Universal spacing tokens that work across all platforms
class DuruSpacing {
  // Base spacing scale (8dp grid system)
  static const double xs = 4.0;   // Micro spacing
  static const double sm = 8.0;   // Small spacing
  static const double md = 16.0;  // Standard spacing
  static const double lg = 24.0;  // Large spacing
  static const double xl = 32.0;  // Extra large spacing
  static const double xxl = 48.0; // Section spacing

  // Semantic spacing tokens
  static const double cardPadding = md;
  static const double screenPadding = md;
  static const double sectionSpacing = lg;
  static const double itemSpacing = sm;
  static const double buttonSpacing = sm;

  // Platform-adaptive spacing
  static double get listItemPadding => DuruPlatform.isMobile ? md : sm;
  static double get appBarHeight => DuruPlatform.isIOS ? 44.0 : 56.0;
  static double get tabBarHeight => DuruPlatform.isIOS ? 49.0 : 56.0;
}

/// Universal color tokens with platform-specific adaptations
class DuruColors {
  // Core brand colors (unchanged across platforms)
  static const Color primary = Color(0xFF048ABF);
  static const Color accent = Color(0xFF5FD0CB);

  // Static status colors for easier use
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color surfaceVariant = Color(0xFF9CA3AF);

  // Status colors that respect platform conventions (for compatibility)
  static Color success(BuildContext context) => accent;
  static Color info(BuildContext context) => primary;

  /// Get platform-appropriate navigation color
  static Color getNavigationColor(BuildContext context) {
    if (DuruPlatform.isIOS) {
      // iOS prefers slightly transparent navigation
      return primary.withValues(alpha: 0.9);
    } else if (DuruPlatform.isAndroid) {
      // Material Design uses full opacity
      return primary;
    } else if (DuruPlatform.isWeb) {
      // Web uses slight transparency for performance
      return primary.withValues(alpha: 0.95);
    }
    return primary; // Desktop fallback
  }

  /// Get status color based on task/note state
  static Color getStatusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return success(context);
      case 'overdue':
      case 'error':
      case 'failed':
        return error;
      case 'in_progress':
      case 'active':
        return primary;
      case 'pending':
      case 'waiting':
        return warning;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  /// Get category color that adapts to theme
  static Color getCategoryColor(BuildContext context, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.8 : 1.0;

    switch (category.toLowerCase()) {
      case 'work':
        return primary.withValues(alpha: opacity);
      case 'personal':
        return accent.withValues(alpha: opacity);
      case 'academic':
        return const Color(0xFF8B5CF6).withValues(alpha: opacity);
      case 'creative':
        return const Color(0xFFEC4899).withValues(alpha: opacity);
      case 'meeting':
        return const Color(0xFF10B981).withValues(alpha: opacity);
      case 'planning':
        return const Color(0xFFF59E0B).withValues(alpha: opacity);
      default:
        return Theme.of(context).colorScheme.primaryContainer;
    }
  }
}

/// Touch target specifications for WCAG compliance
class DuruTouchTargets {
  static const double minWCAGSize = 44.0;

  /// Get minimum touch target size for current platform
  static double get minSize => DuruPlatform.touchTargetSize;

  /// Check if a size meets WCAG standards
  static bool isWCAGCompliant(double size) => size >= minWCAGSize;

  /// Get appropriate button size for platform
  static Size get buttonSize => Size(minSize, minSize);

  /// Get appropriate list item minimum height
  static double get listItemMinHeight => DuruPlatform.isMobile ? 56.0 : 40.0;
}

/// Typography tokens with platform optimizations
class DuruTypography {
  // Base typography scale (unchanged - Inter font)
  static const String fontFamily = 'Inter';

  /// Get platform-appropriate line height
  static double getLineHeight(BuildContext context, double fontSize) {
    if (DuruPlatform.isIOS) {
      // iOS prefers slightly larger line heights for readability
      return fontSize * 1.4;
    } else if (DuruPlatform.isAndroid) {
      // Material Design standard line heights
      return fontSize * 1.3;
    } else if (DuruPlatform.isDesktop) {
      // Desktop can use tighter line heights
      return fontSize * 1.2;
    }
    return fontSize * 1.3; // Web/fallback
  }

  /// Get display text style with platform optimizations
  static TextStyle displayLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.displayLarge!;
    return base.copyWith(
      fontFamily: fontFamily,
      height: getLineHeight(context, base.fontSize ?? 32) / (base.fontSize ?? 32),
    );
  }

  /// Get headline text style with platform optimizations
  static TextStyle headlineLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineLarge!;
    return base.copyWith(
      fontFamily: fontFamily,
      height: getLineHeight(context, base.fontSize ?? 24) / (base.fontSize ?? 24),
    );
  }

  /// Get body text style with platform optimizations
  static TextStyle bodyLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    return base.copyWith(
      fontFamily: fontFamily,
      height: getLineHeight(context, base.fontSize ?? 16) / (base.fontSize ?? 16),
    );
  }
}

/// Border radius tokens for consistent rounded corners
class DuruBorderRadius {
  static const double xs = 4.0;   // Small elements
  static const double sm = 8.0;   // Cards, buttons
  static const double md = 12.0;  // Containers
  static const double lg = 16.0;  // Large cards
  static const double xl = 20.0;  // Modal sheets
  static const double circle = 50.0; // Circular elements

  /// Get platform-appropriate border radius
  static BorderRadius card() => BorderRadius.circular(sm);
  static BorderRadius button() => BorderRadius.circular(xs);
  static BorderRadius modal() => BorderRadius.circular(lg);
  static BorderRadius input() => BorderRadius.circular(sm);
}

/// Elevation and shadow system
class DuruElevation {
  /// Get platform-appropriate card elevation
  static double get card {
    if (DuruPlatform.isIOS) return 1.0;      // iOS uses subtle shadows
    if (DuruPlatform.isAndroid) return 2.0;  // Material Design elevation
    if (DuruPlatform.isWeb) return 1.0;      // Web performance optimization
    return 0.0; // Desktop uses borders instead
  }

  /// Get modal elevation
  static double get modal => DuruPlatform.isMobile ? 8.0 : 4.0;

  /// Get app bar elevation
  static double get appBar => DuruPlatform.isAndroid ? 4.0 : 0.0;
}

/// Animation durations for cross-platform consistency
class DuruAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Get platform-appropriate transition duration
  static Duration get transition {
    if (DuruPlatform.isIOS) return const Duration(milliseconds: 350);
    if (DuruPlatform.isAndroid) return standard;
    return fast; // Desktop/Web prefer faster animations
  }

  /// Get platform-appropriate curve
  static Curve get curve {
    if (DuruPlatform.isIOS) return Curves.easeInOut;
    if (DuruPlatform.isAndroid) return Curves.easeOut;
    return Curves.easeInOut; // Universal fallback
  }
}

/// Accessibility helpers
class DuruAccessibility {
  /// Get contrasting text color for background
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Check if color combination meets WCAG AA contrast ratio
  static bool meetsContrastRatio(Color foreground, Color background, {double ratio = 4.5}) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final contrastRatio = (math.max(fgLuminance, bgLuminance) + 0.05) /
                         (math.min(fgLuminance, bgLuminance) + 0.05);
    return contrastRatio >= ratio;
  }

  /// Get semantic label for screen readers
  static String getSemanticLabel(String text, {String? hint}) {
    String label = text;
    if (hint != null) {
      label += ', $hint';
    }
    return label;
  }
}

