import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Production-grade Material 3 theme system for Duru Notes
/// 
/// This theme system implements the complete Material Design 3 specification
/// with dynamic color support, proper elevation, and semantic color usage.
/// Updated with modern teal palette and Inter typography.
class DuruMaterial3Theme {
  DuruMaterial3Theme._();

  // Core color palette - Modern Teal Theme
  static const Color _lightTeal = Color(0xFF048ABF);  // Primary gradient start
  static const Color _deepTeal = Color(0xFF036693);   // Primary gradient end
  static const Color _softAqua = Color(0xFF5FD0CB);   // Flat accent color
  
  // Surface colors
  static const Color _lightSurface = Color(0xFFF2F2F2);  // Light mode surface
  static const Color _darkSurface = Color(0xFF0F1E2E);   // Dark mode surface
  
  // Gradient definitions for modern design
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [_lightTeal, _deepTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF2F2F2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF0F1E2E), Color(0xFF0A1828)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Light theme configuration
  static ThemeData get lightTheme {
    // Generate base scheme from light teal seed
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _lightTeal,
      brightness: Brightness.light,
    ).copyWith(
      // Override with exact brand colors
      primary: _lightTeal,
      secondary: _deepTeal,
      tertiary: _softAqua,
      surface: _lightSurface,
      // Subtle surface variations
      surfaceContainerLowest: const Color(0xFFFAFAFA),
      surfaceContainerLow: const Color(0xFFF7F7F7),
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHigh: const Color(0xFFF2F2F2),
      surfaceContainerHighest: const Color(0xFFEFEFEF),
      // Ensure good contrast for text
      onSurface: const Color(0xFF1D1D1D),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: const Color(0xFF1D1D1D),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  /// Dark theme configuration with modern dark surfaces
  static ThemeData get darkTheme {
    // Generate base scheme from teal seed
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _lightTeal,
      brightness: Brightness.dark,
    ).copyWith(
      // Keep brand colors consistent in dark mode
      primary: _lightTeal,
      secondary: _deepTeal,
      tertiary: _softAqua,
      surface: _darkSurface,
      // Rich dark surface variations
      surfaceContainerLowest: const Color(0xFF0A1420),
      surfaceContainerLow: const Color(0xFF0C1724),
      surfaceContainer: const Color(0xFF0F1E2E),
      surfaceContainerHigh: const Color(0xFF122438),
      surfaceContainerHighest: const Color(0xFF152A42),
      // Ensure white text on dark backgrounds
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFE0E0E0),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: const Color(0xFF1D1D1D),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  /// Build complete theme from color scheme
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Get Inter text theme
    final baseTextTheme = GoogleFonts.interTextTheme(
      isDark ? Typography.material2021().white : Typography.material2021().black,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      
      // Typography using Inter font
      textTheme: _buildTextTheme(baseTextTheme, colorScheme),
      
      // App Bar theme with teal gradient colors
      appBarTheme: AppBarTheme(
        backgroundColor: _deepTeal,  // Use deep teal for app bars
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: colorScheme.shadow.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,  // SemiBold
          letterSpacing: 0,
        ),
        toolbarTextStyle: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.95),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Scaffold theme
      scaffoldBackgroundColor: colorScheme.surface,

      // Card theme
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        shadowColor: isDark ? Colors.black.withOpacity(0.4) : colorScheme.shadow.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),  // Slightly less rounded for modern look
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Button themes with teal colors
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lightTeal,  // Use primary teal
          foregroundColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundColor: colorScheme.primary,
          shadowColor: colorScheme.shadow,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
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
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
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

      // FAB theme with primary teal
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w300,  // Light weight for hints
          fontStyle: FontStyle.italic,  // Italic for hints
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
        ),
        leadingAndTrailingTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // Switch theme with teal colors
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withOpacity(0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
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
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline.withOpacity(0.5);
        }),
      ),

      // Radio theme with teal selection
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withOpacity(0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.onSurface.withOpacity(0.12),
        labelStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: colorScheme.onPrimaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withOpacity(0.4),
        elevation: 8,
        shadowColor: isDark ? Colors.black : colorScheme.shadow,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
          letterSpacing: 0.1,
        ),
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(
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
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        elevation: 0,
        height: 80,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),

      // Extension themes
      extensions: [
        _CustomColors(
          noteCardBackground: colorScheme.surfaceContainerLow,
          folderChipBackground: colorScheme.primaryContainer.withOpacity(0.3),
          selectedNoteBackground: colorScheme.primaryContainer.withOpacity(0.4),
          warningContainer: isDark ? const Color(0xFF4A4215) : const Color(0xFFFFF8E1),
          onWarningContainer: isDark ? const Color(0xFFF9D71C) : const Color(0xFF7C6F00),
        ),
      ],
    );
  }

  /// Build Material 3 text theme with Inter font
  static TextTheme _buildTextTheme(TextTheme baseTextTheme, ColorScheme colorScheme) {
    return baseTextTheme.copyWith(
      // Display styles
      displayLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      displaySmall: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      
      // Headline styles - SemiBold for headers
      headlineLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0,
      ),
      headlineMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0,
      ),
      headlineSmall: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0,
      ),
      
      // Title styles - SemiBold for important text
      titleLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w600,  // SemiBold
        letterSpacing: 0.1,
      ),
      
      // Body styles - Regular weight
      bodyLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w400,  // Regular
        letterSpacing: 0.15,
      ),
      bodyMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,  // Regular
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w300,  // Light for subtext
        letterSpacing: 0.4,
      ),
      
      // Label styles - Medium weight for buttons/actions
      labelLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,  // SemiBold for button text
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,  // Medium
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w300,  // Light for small labels
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
extension CustomColorsExtension on ThemeData {
  _CustomColors get customColors => extension<_CustomColors>()!;
}

/// Theme gradient helpers for consistent gradient usage across the app
class DuruGradients {
  DuruGradients._();

  // Public color constants for gradients
  static const Color lightTeal = Color(0xFF048ABF);
  static const Color deepTeal = Color(0xFF036693);
  static const Color softAqua = Color(0xFF5FD0CB);
  
  /// Primary gradient using teal colors
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return const LinearGradient(
      colors: [lightTeal, deepTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Accent gradient (teal to aqua)
  static LinearGradient getAccentGradient(BuildContext context) {
    return const LinearGradient(
      colors: [deepTeal, softAqua],
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

  /// Surface gradient for cards and containers
  static LinearGradient getSurfaceGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        colors: [
          Color(0xFF122438),  // Slightly lighter than base
          Color(0xFF0F1E2E),  // Base dark surface
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return const LinearGradient(
      colors: [
        Colors.white,
        Color(0xFFF2F2F2),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Focus border gradient
  static LinearGradient getFocusBorderGradient(BuildContext context) {
    return const LinearGradient(
      colors: [
        lightTeal,
        softAqua,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Glassmorphic overlay gradient (for special effects)
  static LinearGradient getGlassmorphicOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return LinearGradient(
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return LinearGradient(
      colors: [
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0.5),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
}