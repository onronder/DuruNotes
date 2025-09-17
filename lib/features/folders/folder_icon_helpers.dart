import 'package:flutter/material.dart';

/// Helper functions for safely parsing folder icons and colors
class FolderIconHelpers {
  /// Safely parse a color string (hex format) to a Color object
  static Color? parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      // Remove any leading # if present
      final cleanColor = colorString.startsWith('#')
          ? colorString.substring(1)
          : colorString;

      // Ensure the color string is valid hex
      if (cleanColor.length != 6 && cleanColor.length != 8) {
        return null;
      }

      // Parse with radix 16 for hex
      final colorValue = int.parse(cleanColor, radix: 16);

      // Add alpha channel if not present
      if (cleanColor.length == 6) {
        return Color(0xFF000000 | colorValue);
      } else {
        return Color(colorValue);
      }
    } catch (e) {
      // Return null on any parsing error
      return null;
    }
  }

  /// Safely parse an icon string (codepoint) to an IconData object
  static IconData? parseIcon(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return null;
    }

    try {
      // Parse the icon codepoint
      final codePoint = int.parse(iconString);
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    } catch (e) {
      // Return null on any parsing error
      return null;
    }
  }

  /// Get folder icon with fallback
  static IconData getFolderIcon(
    String? iconString, {
    IconData fallback = Icons.folder,
  }) {
    return parseIcon(iconString) ?? fallback;
  }

  /// Get folder color with fallback
  static Color? getFolderColor(String? colorString, {Color? fallback}) {
    return parseColor(colorString) ?? fallback;
  }
}
