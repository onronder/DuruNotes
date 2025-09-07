import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production-grade Material 3 theme system for Duru Notes
/// 
/// This theme system implements the complete Material Design 3 specification
/// with dynamic color support, proper elevation, and semantic color usage.
class DuruMaterial3Theme {
  DuruMaterial3Theme._();

  // Core color seeds for dynamic color generation - Duru Purple Theme
  static const Color _primarySeed = Color(0xFF1976D2); // Professional blue
  static const Color _accentPurple = Color(0xFF667eea); // Glassmorphic purple
  static const Color _secondaryPurple = Color(0xFF764ba2); // Deep purple
  static const Color _errorSeed = Color(0xFFDC2626); // Modern Red
  
  // Glassmorphic surface colors
  static const Color _glassLight = Color(0x0AFFFFFF);
  static const Color _glassMedium = Color(0x14FFFFFF);
  static const Color _glassHigh = Color(0x1FFFFFFF);

  // Gradient definitions for glassmorphic design
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [_accentPurple, _secondaryPurple], // Purple gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)], // Subtle light gradient
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)], // Deep dark gradient
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Light theme configuration
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  /// Dark theme configuration with glassmorphic elements
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ).copyWith(
      // Solid dark surfaces to avoid translucent overlays
      secondary: _accentPurple,
      tertiary: _secondaryPurple,
      surface: const Color(0xFF0B0B0B),
      surfaceContainerLowest: const Color(0xFF111111),
      surfaceContainerLow: const Color(0xFF141414),
      surfaceContainer: const Color(0xFF171717),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF1E1E1E),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  /// Build complete theme from color scheme
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      
      // Typography using Material 3 type scale
      textTheme: _buildTextTheme(colorScheme, isDark),
      
      // App Bar theme with enhanced gradient-inspired styling
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E40AF) : const Color(0xFF2563EB), // Direct gradient colors
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: colorScheme.shadow.withOpacity(0.3),
        surfaceTintColor: Colors.transparent, // Remove tint for cleaner gradient effect
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark, // Always dark for blue gradient
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700, // Stronger weight for gradient design
          letterSpacing: 0.5,
        ),
        toolbarTextStyle: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Scaffold theme
      scaffoldBackgroundColor: colorScheme.surface,

      // Card theme (solid in dark mode)
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        shadowColor: isDark ? Colors.black.withOpacity(0.4) : colorScheme.shadow,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // Button themes with gradient-inspired colors
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB), // Vibrant gradient blue
          foregroundColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: 2, // Add subtle elevation for modern look
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.primary,
          shadowColor: colorScheme.shadow,
          surfaceTintColor: colorScheme.surfaceTint,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Icon button theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // FAB theme with vibrant gradient colors
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB), // Vibrant blue from gradient
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), // Slightly more rounded for modern feel
        ),
        elevation: 8, // More prominent shadow
        focusElevation: 10,
        hoverElevation: 10,
        highlightElevation: 14,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withOpacity(0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withOpacity(0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.onSurface.withOpacity(0.12),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outline),
      ),

      // Bottom sheet theme (solid in dark mode)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withOpacity(0.4),
        elevation: 8,
        shadowColor: isDark ? Colors.black : colorScheme.shadow,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 6,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
          letterSpacing: 0.1,
        ),
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.fixed,
        elevation: 3,
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        elevation: 3,
        shadowColor: colorScheme.shadow,
        height: 80,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Extension themes
      extensions: [
        _CustomColors(
          noteCardBackground: colorScheme.surfaceContainerLow,
          folderChipBackground: colorScheme.secondaryContainer.withOpacity(0.3),
          selectedNoteBackground: colorScheme.primaryContainer.withOpacity(0.3),
          warningContainer: isDark ? const Color(0xFF4A4215) : const Color(0xFFFFF8E1),
          onWarningContainer: isDark ? const Color(0xFFF9D71C) : const Color(0xFF7C6F00),
        ),
      ],
    );
  }

  /// Build Material 3 text theme
  static TextTheme _buildTextTheme(ColorScheme colorScheme, bool isDark) {
    final baseTextTheme = isDark 
        ? Typography.material2021().white 
        : Typography.material2021().black;

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Custom color extension for additional semantic colors
@immutable
class _CustomColors extends ThemeExtension<_CustomColors> {
  const _CustomColors({
    required this.noteCardBackground,
    required this.folderChipBackground,
    required this.selectedNoteBackground,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color noteCardBackground;
  final Color folderChipBackground;
  final Color selectedNoteBackground;
  final Color warningContainer;
  final Color onWarningContainer;

  @override
  _CustomColors copyWith({
    Color? noteCardBackground,
    Color? folderChipBackground,
    Color? selectedNoteBackground,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return _CustomColors(
      noteCardBackground: noteCardBackground ?? this.noteCardBackground,
      folderChipBackground: folderChipBackground ?? this.folderChipBackground,
      selectedNoteBackground: selectedNoteBackground ?? this.selectedNoteBackground,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  _CustomColors lerp(ThemeExtension<_CustomColors>? other, double t) {
    if (other is! _CustomColors) {
      return this;
    }
    return _CustomColors(
      noteCardBackground: Color.lerp(noteCardBackground, other.noteCardBackground, t)!,
      folderChipBackground: Color.lerp(folderChipBackground, other.folderChipBackground, t)!,
      selectedNoteBackground: Color.lerp(selectedNoteBackground, other.selectedNoteBackground, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

/// Getter extension for custom colors
extension CustomColorsExtension on ColorScheme {
  _CustomColors get customColors => 
      ThemeData.from(colorScheme: this).extension<_CustomColors>()!;
}

/// Theme gradient helpers for consistent gradient usage across the app
class DuruGradients {
  DuruGradients._();

  // Public color constants for gradients
  static const Color accentPurple = Color(0xFF667eea);
  static const Color secondaryPurple = Color(0xFF764ba2);
  static const Color glassMedium = Color(0x14FFFFFF);
  static const Color glassHigh = Color(0x1FFFFFFF);

  /// Primary gradient using theme colors (Blue to Purple)
  static LinearGradient getPrimaryGradient(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      colors: [
        colorScheme.primary,      // #1976D2 in light mode
        accentPurple,            // #667eea
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Secondary gradient (Purple to Deep Purple)
  static LinearGradient getSecondaryGradient(BuildContext context) {
    return LinearGradient(
      colors: [
        accentPurple,           // #667eea
        secondaryPurple,        // #764ba2
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Save button gradient (dynamic based on state)
  static LinearGradient getSaveButtonGradient(BuildContext context, {bool hasChanges = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    if (hasChanges) {
      return LinearGradient(
        colors: [
          colorScheme.primary,
          colorScheme.secondary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [
        colorScheme.primaryContainer,
        colorScheme.primaryContainer,
      ],
    );
  }

  /// Glassmorphic overlay gradient for dark mode
  static LinearGradient getGlassmorphicOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return LinearGradient(
        colors: [
          glassMedium,
          glassHigh,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return LinearGradient(
      colors: [
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.05),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Focus border gradient
  static LinearGradient getFocusBorderGradient(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      colors: [
        colorScheme.primary.withOpacity(0.3),
        colorScheme.secondary.withOpacity(0.3),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}