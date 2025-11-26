import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/foundation.dart';

/// Migration 43: Add updatedAt field to NoteReminders table
///
/// **Purpose:** Support proper conflict resolution in reminder sync
///
/// **Background:**
/// Reminders can be modified after creation (snooze, update time, change location, etc.)
/// Without an updatedAt timestamp, conflict resolution defaults to createdAt, which
/// doesn't accurately reflect when a reminder was last modified.
///
/// **Changes:**
/// 1. Add nullable `updated_at` column to `note_reminders` table
/// 2. Backfill existing reminders with `updated_at = created_at`
/// 3. Future updates will set `updated_at = NOW()`
///
/// **Migration Strategy:**
/// - Column is nullable for backward compatibility
/// - Fast migration: Single ALTER TABLE statement
/// - Backfill in same transaction (safe)
/// - No data loss risk
///
/// **Performance:**
/// - Expected duration: < 1 second for 1000 reminders
/// - Single ALTER TABLE + UPDATE statement
/// - No blocking operations
///
/// **Related Issues:**
/// - Fixes: Missing NoteReminder.updatedAt field (unified_sync_service.dart:920, 1256)
/// - Enables: Proper conflict resolution based on modification time
///
/// Created: 2025-11-18
class Migration43ReminderUpdatedAt {
  static final _logger = LoggerFactory.instance;

  /// Apply Migration 43 to the local database
  static Future<void> apply(AppDb db) async {
    debugPrint('[Migration 43] Starting reminder updatedAt migration...');

    try {
      // Step 1: Add the updated_at column (nullable for backward compatibility)
      await db.customStatement(
        'ALTER TABLE note_reminders ADD COLUMN updated_at INTEGER',
      );
      debugPrint('[Migration 43] ✅ Added updated_at column');

      // Step 2: Backfill existing reminders with created_at value
      // This ensures proper conflict resolution for pre-existing reminders
      await db.customStatement(
        'UPDATE note_reminders SET updated_at = created_at WHERE updated_at IS NULL',
      );
      debugPrint(
        '[Migration 43] ✅ Backfilled updated_at for existing reminders',
      );

      // Step 3: Add index for conflict resolution queries
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_note_reminders_updated_at '
        'ON note_reminders(updated_at)',
      );
      debugPrint('[Migration 43] ✅ Created updated_at index');

      debugPrint('[Migration 43] ✅ Reminder updatedAt migration complete');
    } catch (error, stack) {
      _logger.error(
        '[Migration 43] Migration failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get migration progress statistics
  ///
  /// Returns:
  /// - total: Total number of reminders
  /// - with_updated_at: Reminders with updatedAt set
  /// - without_updated_at: Reminders missing updatedAt (should be 0 after migration)
  static Future<Map<String, int>> getProgress(AppDb db) async {
    try {
      final total = await db
          .customSelect('SELECT COUNT(*) as count FROM note_reminders')
          .getSingle();

      final withUpdatedAt = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM note_reminders WHERE updated_at IS NOT NULL',
          )
          .getSingle();

      final withoutUpdatedAt = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM note_reminders WHERE updated_at IS NULL',
          )
          .getSingle();

      return {
        'total': total.read<int>('count'),
        'with_updated_at': withUpdatedAt.read<int>('count'),
        'without_updated_at': withoutUpdatedAt.read<int>('count'),
      };
    } catch (error) {
      return {'total': 0, 'with_updated_at': 0, 'without_updated_at': 0};
    }
  }
}
