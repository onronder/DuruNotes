import 'package:flutter/material.dart';

/// Helper functions for safely parsing folder icons and colors
class FolderIconHelpers {
  /// Const map of common icon codepoints to IconData
  /// This ensures all icons are compile-time constants for tree-shaking
  static const Map<int, IconData> _iconCodepointMap = {
    0xe2c7: Icons.folder, // folder
    0xe8f9: Icons.work, // work
    0xe80c: Icons.school, // school
    0xe88a: Icons.home, // home
    0xe87d: Icons.favorite, // favorite
    0xe838: Icons.star, // star
    0xe90f: Icons.lightbulb, // lightbulb
    0xe869: Icons.build, // build
    0xe8cc: Icons.shopping_cart, // shopping_cart
    0xea30: Icons.sports, // sports
    0xe55f: Icons.travel_explore, // travel_explore
    0xe405: Icons.music_note, // music_note
    0xe410: Icons.photo, // photo
    0xe865: Icons.book, // book
    0xe566: Icons.fitness_center, // fitness_center
    0xe56c: Icons.restaurant, // restaurant
    0xe8b8: Icons.palette, // palette
    0xe8d1: Icons.meeting_room, // meeting_room
    0xe616: Icons.event_note, // event_note
    0xef42: Icons.article, // article
    0xe89c: Icons.note_add, // note_add
    0xe85d: Icons.assignment, // assignment
    0xf87e: Icons.task_alt, // task_alt
    0xe873: Icons.description, // description
    0xe7ef: Icons.person, // person
    0xe24d: Icons.folder_outlined, // folder_outlined
  };

  /// Safely parse a color string (hex format) to a Color object
  static Color? parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      // Remove any leading # if present
      final cleanColor =
          colorString.startsWith('#') ? colorString.substring(1) : colorString;

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
  /// Uses const icon map for tree-shaking compatibility
  static IconData? parseIcon(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return null;
    }

    try {
      // Parse the icon codepoint
      final codePoint = int.parse(iconString);
      // Lookup from const map - returns null if not found
      return _iconCodepointMap[codePoint];
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
