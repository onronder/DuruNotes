// Utilities for determining which date to display for notes and tasks
//
// **Problem Solved:**
// When displaying notes/tasks on the home page, we need to show:
// - Creation date for items that have never been edited
// - Last update date for items that have been edited
//
// This ensures consistent behavior across:
// - App reinstalls
// - Device transfers
// - Cross-device sync
// - Bulk operations
//
// **Technical Approach:**
// Compare `createdAt` and `updatedAt` timestamps. If they're the same
// (within a small tolerance for rounding), the item was never edited,
// so we show the creation date. Otherwise, show the update date.

/// Returns the appropriate date to display for a note or task
///
/// **Logic:**
/// - If `createdAt` == `updatedAt` (±1s tolerance): Returns `createdAt`
///   - Item was never edited by user
///   - Show original creation timestamp
///
/// - If `updatedAt` > `createdAt`: Returns `updatedAt`
///   - Item was edited by user
///   - Show last modification timestamp
///
/// **Why 1-second tolerance?**
/// - Database precision may vary (milliseconds vs seconds)
/// - Sync operations may introduce minimal clock drift
/// - Creation/update in same transaction may have tiny time difference
///
/// **Guarantees:**
/// - Device-agnostic: Based only on database timestamps
/// - Sync-safe: Timestamps replicate correctly via Supabase
/// - Deterministic: Same input always produces same output
/// - Backward compatible: Works with existing data
///
/// **Example Usage:**
/// ```dart
/// // In UI components:
/// final displayDate = getDisplayDate(
///   createdAt: note.createdAt,
///   updatedAt: note.updatedAt,
/// );
/// Text(_formatDate(displayDate));
/// ```
///
/// **Test Scenarios:**
/// ```dart
/// // Never edited - shows creation date
/// getDisplayDate(
///   createdAt: DateTime(2024, 1, 1, 12, 0, 0),
///   updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
/// ) // => DateTime(2024, 1, 1, 12, 0, 0)
///
/// // Edited - shows update date
/// getDisplayDate(
///   createdAt: DateTime(2024, 1, 1, 12, 0, 0),
///   updatedAt: DateTime(2024, 1, 5, 15, 30, 0),
/// ) // => DateTime(2024, 1, 5, 15, 30, 0)
///
/// // Tolerance handling (1s difference treated as "same")
/// getDisplayDate(
///   createdAt: DateTime(2024, 1, 1, 12, 0, 0),
///   updatedAt: DateTime(2024, 1, 1, 12, 0, 1),
/// ) // => DateTime(2024, 1, 1, 12, 0, 0)
/// ```
DateTime getDisplayDate({
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  // Calculate absolute difference between timestamps
  final difference = updatedAt.difference(createdAt).abs();

  // If timestamps are effectively the same (within 1-second tolerance)
  // This means the record was never edited by the user
  if (difference.inSeconds <= 1) {
    return createdAt; // Show original creation date
  }

  // Record has been meaningfully updated
  return updatedAt; // Show last modification date
}

/// Safe version of getDisplayDate that handles potential null timestamps
///
/// **When to use this:**
/// - When dealing with data from external sources
/// - When you're unsure if timestamps might be null
/// - For defensive programming in production code
///
/// **Fallback Logic:**
/// - If both timestamps exist: use [getDisplayDate] logic
/// - If only updatedAt exists: use updatedAt
/// - If only createdAt exists: use createdAt
/// - If neither exists: use current time (last resort)
///
/// **Note**: For LocalNotes and NoteTasks, both timestamps are required by schema,
/// so this is primarily for safety/defensive programming.
DateTime getSafeDisplayDate({DateTime? createdAt, DateTime? updatedAt}) {
  // Both timestamps available - use standard logic
  if (createdAt != null && updatedAt != null) {
    return getDisplayDate(createdAt: createdAt, updatedAt: updatedAt);
  }

  // Fallback chain if data is corrupted or from external source
  if (updatedAt != null) return updatedAt;
  if (createdAt != null) return createdAt;

  // Last resort: current time (should never happen with proper schema)
  return DateTime.now();
}

/// Extension on Note entities for convenient access to display date
extension NoteDisplayDate on Object {
  /// Returns the appropriate date to display for this note
  ///
  /// Uses [getSafeDisplayDate] internally to safely handle edge cases.
  ///
  /// Example:
  /// ```dart
  /// Text(_formatDate(note.displayDate))
  /// ```
  DateTime get displayDate {
    // Extract createdAt and updatedAt dynamically
    // This works with any object that has these fields
    final dynamic obj = this;

    try {
      final DateTime? createdAt = obj.createdAt as DateTime?;
      final DateTime? updatedAt = obj.updatedAt as DateTime?;

      return getSafeDisplayDate(createdAt: createdAt, updatedAt: updatedAt);
    } catch (e) {
      // Ultimate fallback: if fields don't exist or wrong type
      // Try to return any available timestamp
      try {
        return obj.updatedAt as DateTime? ??
            obj.createdAt as DateTime? ??
            DateTime.now();
      } catch (_) {
        return DateTime.now();
      }
    }
  }
}
