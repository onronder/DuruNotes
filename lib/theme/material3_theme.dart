import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Production-grade Material 3 theme system for Duru Notes
///
/// This theme system implements the complete Material Design 3 specification
/// with dynamic color support, proper elevation, and semantic color usage.
/// Updated with exact logo colors and modern teal palette.
class DuruMaterial3Theme {
  DuruMaterial3Theme._();

  // Core color palette - Exact Logo Colors
  static const Color _primaryTeal = Color(
    0xFF048ABF,
  ); // Logo gradient start (exact)
  static const Color _accentAqua = Color(
    0xFF5FD0CB,
  ); // Logo gradient end (exact)
  static const Color _deepTeal = Color(0xFF036693); // Darker variant for depth
  static const Color _lightAqua = Color(
    0xFF7DD8D3,
  ); // Lighter variant for containers

  // Surface colors
  static const Color _lightSurface = Color(0xFFF8FAFC); // Very light surface
  static const Color _darkSurface = Color(0xFF0F1E2E); // Dark mode surface

  // Logo-based gradient definitions
  static const LinearGradient logoGradient = LinearGradient(
    colors: [_primaryTeal, _accentAqua], // Exact logo colors
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [_primaryTeal, _deepTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [_accentAqua, _lightAqua],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFCFDFE), _lightSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF122438), _darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Light theme configuration with exact logo colors
  static ThemeData get lightTheme {
    // Generate base scheme from primary teal (logo color)
    final colorScheme = ColorScheme.fromSeed(seedColor: _primaryTeal).copyWith(
      // Override with exact logo colors
      primary: _primaryTeal, // #048ABF - Logo start color
      secondary: _accentAqua, // #5FD0CB - Logo end color
      tertiary: _deepTeal, // Darker variant
      surface: _lightSurface,
      // Enhanced surface variations with logo color influence
      surfaceContainerLowest: const Color(0xFFFEFEFE),
      surfaceContainerLow: const Color(0xFFFBFCFD),
      surfaceContainer: _lightSurface,
      surfaceContainerHigh: const Color(0xFFF5F7F9),
      surfaceContainerHighest: const Color(0xFFF2F4F6),
      // Primary container with logo accent
      primaryContainer: _accentAqua.withValues(alpha: 0.12),
      onPrimaryContainer: _deepTeal,
      secondaryContainer: _lightAqua.withValues(alpha: 0.12),
      onSecondaryContainer: _primaryTeal,
      // Ensure excellent contrast
      onSurface: const Color(0xFF1A1C1E),
      onSurfaceVariant: const Color(0xFF44474E),
      onPrimary: Colors.white,
      onSecondary: const Color(0xFF1A1C1E),
      onTertiary: Colors.white,
      // Outline colors with logo tint
      outline: const Color(0xFF74777F),
      outlineVariant: _accentAqua.withValues(alpha: 0.2),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  /// Dark theme configuration with logo colors
  static ThemeData get darkTheme {
    // Generate base scheme from primary teal
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryTeal,
      brightness: Brightness.dark,
    ).copyWith(
      // Keep exact logo colors in dark mode
      primary: _primaryTeal, // #048ABF
      secondary: _accentAqua, // #5FD0CB
      tertiary: _lightAqua, // Lighter for dark mode
      surface: _darkSurface,
      // Rich dark surface variations with logo color influence
      surfaceContainerLowest: const Color(0xFF0A1420),
      surfaceContainerLow: const Color(0xFF0C1724),
      surfaceContainer: _darkSurface,
      surfaceContainerHigh: const Color(0xFF152A42),
      surfaceContainerHighest: const Color(0xFF1A2F47),
      // Primary containers in dark mode
      primaryContainer: _primaryTeal.withValues(alpha: 0.2),
      onPrimaryContainer: _accentAqua,
      secondaryContainer: _accentAqua.withValues(alpha: 0.15),
      onSecondaryContainer: _lightAqua,
      // Dark mode text colors
      onSurface: const Color(0xFFE3E3E3),
      onSurfaceVariant: const Color(0xFFC4C7C5),
      onPrimary: Colors.white,
      onSecondary: const Color(0xFF1A1C1E),
      onTertiary: const Color(0xFF1A1C1E),
      // Dark outline colors
      outline: const Color(0xFF8E918F),
      outlineVariant: _primaryTeal.withValues(alpha: 0.2),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  /// Build complete theme from color scheme
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Get Inter text theme
    final baseTextTheme = GoogleFonts.interTextTheme(
      isDark
          ? Typography.material2021().white
          : Typography.material2021().black,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,

      // Typography using Inter font
      textTheme: _buildTextTheme(baseTextTheme, colorScheme),

      // App Bar theme with logo primary color
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryTeal, // Use exact logo color
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        toolbarTextStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Scaffold theme
      scaffoldBackgroundColor: colorScheme.surface,

      // Card theme with logo color accents
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : _primaryTeal.withValues(alpha: 0.08), // Logo color shadow
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Button themes with exact logo colors
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryTeal, // Exact logo color
          foregroundColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.12,
          ),
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
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
          foregroundColor: _primaryTeal, // Logo color text
          shadowColor: _primaryTeal.withValues(alpha: 0.2),
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
          foregroundColor: _primaryTeal, // Logo color
          side: BorderSide(color: _primaryTeal.withValues(alpha: 0.5)),
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
          foregroundColor: _primaryTeal, // Logo color
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

      // FAB theme with logo gradient effect
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryTeal, // Logo primary color
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
      ),

      // Input decoration theme with logo colors
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _primaryTeal,
            width: 2,
          ), // Logo color focus
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
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      // Switch theme with logo colors
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryTeal; // Logo color for active switch
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline.withValues(alpha: 0.5);
        }),
      ),

      // Radio theme with logo selection
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryTeal; // Logo color for selection
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // Checkbox theme with logo colors
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryTeal; // Logo color for checked state
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide.none;
          }
          return BorderSide(color: colorScheme.outline, width: 2);
        }),
      ),

      // Chip theme with logo accent
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: _accentAqua.withValues(
          alpha: 0.2,
        ), // Logo accent for selection
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: _primaryTeal, // Logo color for selected text
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: _accentAqua.withValues(alpha: 0.3),
        ), // Logo accent border
      ),

      // Progress indicator theme with logo colors
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _primaryTeal, // Logo color for progress
        linearTrackColor: _accentAqua.withValues(alpha: 0.2),
        circularTrackColor: _accentAqua.withValues(alpha: 0.2),
      ),

      // Slider theme with logo colors
      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryTeal,
        inactiveTrackColor: _accentAqua.withValues(alpha: 0.3),
        thumbColor: _primaryTeal,
        overlayColor: _primaryTeal.withValues(alpha: 0.12),
        valueIndicatorColor: _primaryTeal,
        valueIndicatorTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: _accentAqua.withValues(
          alpha: 0.4,
        ), // Logo accent for handle
        elevation: 8,
        shadowColor:
            isDark ? Colors.black : _primaryTeal.withValues(alpha: 0.1),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: _primaryTeal.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        actionTextColor: _accentAqua, // Logo accent for actions
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.fixed,
        elevation: 3,
      ),

      // Navigation bar theme with logo colors
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _accentAqua.withValues(
          alpha: 0.2,
        ), // Logo accent for indicator
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
                ? _primaryTeal // Logo color for selected
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        elevation: 0,
        height: 80,
      ),

      // Tab bar theme with logo colors
      tabBarTheme: TabBarThemeData(
        labelColor: _primaryTeal, // Logo color for active tab
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: _primaryTeal, // Logo color for indicator
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // Extension themes with logo colors
      extensions: [
        _CustomColors(
          noteCardBackground: colorScheme.surfaceContainerLow,
          folderChipBackground: _accentAqua.withValues(
            alpha: 0.1,
          ), // Logo accent
          selectedNoteBackground: _primaryTeal.withValues(
            alpha: 0.08,
          ), // Logo primary
          warningContainer: const Color(0xFFFFF4E6),
          onWarningContainer: const Color(0xFF8B4513),
          logoGradientStart: _primaryTeal, // Exact logo colors
          logoGradientEnd: _accentAqua,
          accentHighlight: _lightAqua,
        ),
      ],
    );
  }

  /// Build text theme with Inter font and proper hierarchy
  static TextTheme _buildTextTheme(
    TextTheme baseTextTheme,
    ColorScheme colorScheme,
  ) {
    return baseTextTheme.copyWith(
      // Display styles - Bold for major headings
      displayLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 57,
        fontWeight: FontWeight.w700, // Bold
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 45,
        fontWeight: FontWeight.w700, // Bold
        letterSpacing: 0,
      ),
      displaySmall: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
      ),

      // Headline styles - SemiBold for section headers
      headlineLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
      ),
      headlineMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
      ),
      headlineSmall: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
      ),

      // Title styles - SemiBold for important text
      titleLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0.1,
      ),

      // Body styles - Regular weight
      bodyLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.15,
      ),
      bodyMedium: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w300, // Light for subtext
        letterSpacing: 0.4,
      ),

      // Label styles - Medium weight for buttons/actions
      labelLarge: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600, // SemiBold for button text
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w300, // Light for small labels
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Custom color extension with exact logo colors
@immutable
class _CustomColors extends ThemeExtension<_CustomColors> {
  const _CustomColors({
    required this.noteCardBackground,
    required this.folderChipBackground,
    required this.selectedNoteBackground,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.logoGradientStart,
    required this.logoGradientEnd,
    required this.accentHighlight,
  });

  final Color noteCardBackground;
  final Color folderChipBackground;
  final Color selectedNoteBackground;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color logoGradientStart; // #048ABF
  final Color logoGradientEnd; // #5FD0CB
  final Color accentHighlight; // #7DD8D3

  @override
  _CustomColors copyWith({
    Color? noteCardBackground,
    Color? folderChipBackground,
    Color? selectedNoteBackground,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? logoGradientStart,
    Color? logoGradientEnd,
    Color? accentHighlight,
  }) {
    return _CustomColors(
      noteCardBackground: noteCardBackground ?? this.noteCardBackground,
      folderChipBackground: folderChipBackground ?? this.folderChipBackground,
      selectedNoteBackground:
          selectedNoteBackground ?? this.selectedNoteBackground,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      logoGradientStart: logoGradientStart ?? this.logoGradientStart,
      logoGradientEnd: logoGradientEnd ?? this.logoGradientEnd,
      accentHighlight: accentHighlight ?? this.accentHighlight,
    );
  }

  @override
  _CustomColors lerp(ThemeExtension<_CustomColors>? other, double t) {
    if (other is! _CustomColors) {
      return this;
    }
    return _CustomColors(
      noteCardBackground: Color.lerp(
        noteCardBackground,
        other.noteCardBackground,
        t,
      )!,
      folderChipBackground: Color.lerp(
        folderChipBackground,
        other.folderChipBackground,
        t,
      )!,
      selectedNoteBackground: Color.lerp(
        selectedNoteBackground,
        other.selectedNoteBackground,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      logoGradientStart: Color.lerp(
        logoGradientStart,
        other.logoGradientStart,
        t,
      )!,
      logoGradientEnd: Color.lerp(logoGradientEnd, other.logoGradientEnd, t)!,
      accentHighlight: Color.lerp(accentHighlight, other.accentHighlight, t)!,
    );
  }
}

/// Getter extension for custom colors
extension CustomColorsExtension on ThemeData {
  _CustomColors get customColors => extension<_CustomColors>()!;
}

/// Theme gradient helpers with exact logo colors
class DuruGradients {
  DuruGradients._();

  // Exact logo color constants
  static const Color logoStart = Color(0xFF048ABF); // #048ABF
  static const Color logoEnd = Color(0xFF5FD0CB); // #5FD0CB
  static const Color deepTeal = Color(0xFF036693); // Darker variant
  static const Color lightAqua = Color(0xFF7DD8D3); // Lighter variant

  /// Exact logo gradient
  static LinearGradient getLogoGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoStart, logoEnd], // Exact logo colors
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Primary gradient using logo start color
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoStart, deepTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Accent gradient using logo end color
  static LinearGradient getAccentGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoEnd, lightAqua],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Save button gradient with logo colors
  static LinearGradient getSaveButtonGradient(
    BuildContext context, {
    bool hasChanges = false,
  }) {
    if (hasChanges) {
      return const LinearGradient(
        colors: [logoStart, logoEnd], // Full logo gradient when active
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [logoEnd.withValues(alpha: 0.3), logoEnd.withValues(alpha: 0.3)],
    );
  }

  /// Surface gradient for cards and containers
  static LinearGradient getSurfaceGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        colors: [
          Color(0xFF152A42), // Slightly lighter than base
          Color(0xFF0F1E2E), // Base dark surface
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return const LinearGradient(
      colors: [
        Colors.white,
        Color(0xFFF8FAFC), // Very light surface
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Focus border gradient with logo colors
  static LinearGradient getFocusBorderGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoStart, logoEnd], // Exact logo gradient
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Glassmorphic overlay gradient
  static LinearGradient getGlassmorphicOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return LinearGradient(
        colors: [
          logoEnd.withValues(alpha: 0.05),
          logoStart.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.8),
        logoEnd.withValues(alpha: 0.1),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Notification badge gradient
  static LinearGradient getNotificationGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoStart, deepTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Success gradient (for completed actions)
  static LinearGradient getSuccessGradient(BuildContext context) {
    return const LinearGradient(
      colors: [logoEnd, lightAqua],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// Logo color constants for easy access throughout the app
class DuruColors {
  DuruColors._();

  // Exact logo colors
  static const Color primary = Color(
    0xFF048ABF,
  ); // #048ABF - Logo gradient start
  static const Color accent = Color(0xFF5FD0CB); // #5FD0CB - Logo gradient end
  static const Color deepTeal = Color(0xFF036693); // Darker variant
  static const Color lightAqua = Color(0xFF7DD8D3); // Lighter variant

  // Semantic colors based on logo palette
  static const Color success = Color(0xFF5FD0CB); // Use logo accent for success
  static const Color warning = Color(0xFFFFA726); // Complementary orange
  static const Color error = Color(0xFFEF5350); // Standard error red
  static const Color info = Color(0xFF048ABF); // Use logo primary for info
}
