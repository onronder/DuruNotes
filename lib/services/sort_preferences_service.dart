import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sorting options for notes
enum NoteSortField {
  updatedAt('updated_at', 'Modified'),
  createdAt('created_at', 'Created'),
  title('title', 'Title');

  const NoteSortField(this.value, this.label);
  final String value;
  final String label;
}

/// Sort direction
enum SortDirection {
  asc('asc', 'Oldest First'),
  desc('desc', 'Newest First');

  const SortDirection(this.value, this.label);
  final String value;
  final String label;
}

/// Sort specification combining field and direction
class NoteSortSpec {
  const NoteSortSpec({
    this.field = NoteSortField.updatedAt,
    this.direction = SortDirection.desc,
  });

  /// Create from stored preference string
  factory NoteSortSpec.fromString(String? value) {
    if (value == null || value.isEmpty) {
      return const NoteSortSpec(); // Default
    }

    final parts = value.split(':');
    if (parts.length != 2) {
      return const NoteSortSpec(); // Default on invalid format
    }

    final field = NoteSortField.values.firstWhere(
      (f) => f.value == parts[0],
      orElse: () => NoteSortField.updatedAt,
    );

    final direction = SortDirection.values.firstWhere(
      (d) => d.value == parts[1],
      orElse: () => SortDirection.desc,
    );

    return NoteSortSpec(field: field, direction: direction);
  }

  final NoteSortField field;
  final SortDirection direction;

  /// Convert to string for storage
  @override
  String toString() => '${field.value}:${direction.value}';

  /// Get human-readable label
  String get label {
    switch (field) {
      case NoteSortField.updatedAt:
        return 'Modified (${direction == SortDirection.desc ? "Newest First" : "Oldest First"})';
      case NoteSortField.createdAt:
        return 'Created (${direction == SortDirection.desc ? "Newest First" : "Oldest First"})';
      case NoteSortField.title:
        return 'Title (${direction == SortDirection.asc ? "A-Z" : "Z-A"})';
    }
  }

  /// Get short label for UI
  String get shortLabel {
    switch (field) {
      case NoteSortField.updatedAt:
        return 'Modified';
      case NoteSortField.createdAt:
        return 'Created';
      case NoteSortField.title:
        return 'Title';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteSortSpec &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          direction == other.direction;

  @override
  int get hashCode => field.hashCode ^ direction.hashCode;
}

/// Service for managing sort preferences per folder
class SortPreferencesService {
  final AppLogger _logger = LoggerFactory.instance;
  static const String _keyPrefix = 'prefs.sort.folder.';
  static const String _allNotesKey = 'all';

  /// Get sort preference for a folder
  Future<NoteSortSpec> getSortForFolder(String? folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildKey(folderId);
      final value = prefs.getString(key);
      return NoteSortSpec.fromString(value);
    } catch (e) {
      _logger.debug('Error loading sort preference: $e');
      return const NoteSortSpec(); // Return default on error
    }
  }

  /// Save sort preference for a folder
  Future<bool> setSortForFolder(String? folderId, NoteSortSpec sort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildKey(folderId);
      return await prefs.setString(key, sort.toString());
    } catch (e) {
      _logger.debug('Error saving sort preference: $e');
      return false;
    }
  }

  /// Remove sort preference for a folder (e.g., when folder is deleted)
  Future<bool> removeSortForFolder(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildKey(folderId);
      return await prefs.remove(key);
    } catch (e) {
      _logger.debug('Error removing sort preference: $e');
      return false;
    }
  }

  /// Clear all sort preferences
  Future<bool> clearAllSortPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));

      for (final key in keys) {
        await prefs.remove(key);
      }

      return true;
    } catch (e) {
      _logger.debug('Error clearing sort preferences: $e');
      return false;
    }
  }

  /// Build storage key for a folder
  String _buildKey(String? folderId) {
    return '$_keyPrefix${folderId ?? _allNotesKey}';
  }

  /// Get all available sort options
  static List<NoteSortSpec> getAllSortOptions() {
    return [
      // Modified (default)
      const NoteSortSpec(),
      const NoteSortSpec(direction: SortDirection.asc),
      // Created
      const NoteSortSpec(field: NoteSortField.createdAt),
      const NoteSortSpec(
        field: NoteSortField.createdAt,
        direction: SortDirection.asc,
      ),
      // Title
      const NoteSortSpec(
        field: NoteSortField.title,
        direction: SortDirection.asc,
      ),
      const NoteSortSpec(field: NoteSortField.title),
    ];
  }
}
