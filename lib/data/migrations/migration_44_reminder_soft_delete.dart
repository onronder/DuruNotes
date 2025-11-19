import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Migration 44: Add soft delete support to reminders
///
/// This migration adds the `deleted_at` and `scheduled_purge_at` columns to the
/// `note_reminders` table, bringing reminders in line with notes, tasks, and folders
/// which already support soft delete with 30-day recovery windows.
///
/// **Background:**
/// - Migration 40 added soft delete to notes, folders, and tasks
/// - Reminders were overlooked and still use hard delete (data loss risk)
/// - Users expect consistent behavior across all entity types
///
/// **Changes:**
/// 1. Add `deleted_at` timestamp column (nullable for existing reminders)
/// 2. Add `scheduled_purge_at` timestamp column (30 days after deletion)
/// 3. Create index for efficient querying of deleted reminders
/// 4. Backfill existing reminders with NULL values (not deleted)
///
/// **Performance:** < 1 second for 10,000 reminders
/// **Risk Level:** LOW (non-breaking, backward compatible)
/// **Data Loss Risk:** ZERO (adds columns only, no data removal)
class Migration44ReminderSoftDelete {
  static final _logger = LoggerFactory.instance;

  /// Apply the migration to add soft delete support
  static Future<void> apply(AppDb db) async {
    debugPrint('[Migration 44] Starting reminder soft delete migration...');

    final stopwatch = Stopwatch()..start();

    try {
      // Step 1: Add deleted_at column (nullable for backward compatibility)
      await db.customStatement(
        'ALTER TABLE note_reminders ADD COLUMN deleted_at INTEGER',
      );

      debugPrint('[Migration 44] ✅ Added deleted_at column');

      // Step 2: Add scheduled_purge_at column
      // This will be set to deleted_at + 30 days when reminder is deleted
      await db.customStatement(
        'ALTER TABLE note_reminders ADD COLUMN scheduled_purge_at INTEGER',
      );

      debugPrint('[Migration 44] ✅ Added scheduled_purge_at column');

      // Step 3: Backfill existing reminders with NULL (not deleted)
      // This is technically redundant since SQLite defaults to NULL,
      // but we make it explicit for clarity
      await db.customStatement(
        'UPDATE note_reminders SET deleted_at = NULL, scheduled_purge_at = NULL '
        'WHERE deleted_at IS NULL',
      );

      debugPrint('[Migration 44] ✅ Backfilled existing reminders');

      // Step 4: Create index for querying deleted reminders
      // This speeds up queries that filter by deleted_at
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_note_reminders_deleted_at '
        'ON note_reminders(deleted_at) '
        'WHERE deleted_at IS NOT NULL',
      );

      debugPrint('[Migration 44] ✅ Created deleted_at index');

      // Step 5: Create index for purge job queries
      // This speeds up the background job that purges old deleted reminders
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_note_reminders_scheduled_purge '
        'ON note_reminders(scheduled_purge_at) '
        'WHERE scheduled_purge_at IS NOT NULL',
      );

      debugPrint('[Migration 44] ✅ Created scheduled_purge_at index');

      stopwatch.stop();

      _logger.info(
        '[Migration 44] ✅ Reminder soft delete migration complete in ${stopwatch.elapsedMilliseconds}ms',
      );

      debugPrint(
        '[Migration 44] ✅ Reminder soft delete migration complete in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (error, stack) {
      stopwatch.stop();

      _logger.error(
        '[Migration 44] Migration failed after ${stopwatch.elapsedMilliseconds}ms',
        error: error,
        stackTrace: stack,
      );

      debugPrint('[Migration 44] ❌ Migration failed: $error');

      rethrow;
    }
  }

  /// Get migration progress statistics
  ///
  /// Returns statistics about the current state of soft delete adoption:
  /// - total_reminders: Total number of reminders
  /// - active_reminders: Reminders not deleted
  /// - deleted_reminders: Reminders soft-deleted (recoverable)
  /// - pending_purge: Reminders scheduled for permanent deletion
  static Future<Map<String, int>> getProgress(AppDb db) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Get total count
      final totalResult = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders',
      ).getSingle();

      // Get active (not deleted) count
      final activeResult = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders WHERE deleted_at IS NULL',
      ).getSingle();

      // Get deleted count
      final deletedResult = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders WHERE deleted_at IS NOT NULL',
      ).getSingle();

      // Get pending purge count (deleted more than 30 days ago)
      final purgeResult = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders '
        'WHERE scheduled_purge_at IS NOT NULL AND scheduled_purge_at <= ?',
        variables: [Variable.withInt(now)],
      ).getSingle();

      return {
        'total_reminders': totalResult.read<int>('count'),
        'active_reminders': activeResult.read<int>('count'),
        'deleted_reminders': deletedResult.read<int>('count'),
        'pending_purge': purgeResult.read<int>('count'),
      };
    } catch (e) {
      _logger.warning('[Migration 44] Failed to get progress: $e');
      return {
        'total_reminders': 0,
        'active_reminders': 0,
        'deleted_reminders': 0,
        'pending_purge': 0,
      };
    }
  }

  /// Purge reminders that are scheduled for permanent deletion
  ///
  /// This should be called periodically (e.g., daily) to clean up reminders
  /// that have been deleted for more than 30 days.
  ///
  /// Returns the number of reminders permanently deleted.
  static Future<int> purgeExpiredReminders(AppDb db) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      debugPrint('[Migration 44] Starting purge of expired reminders...');

      // Get count before deletion
      final beforeResult = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders '
        'WHERE scheduled_purge_at IS NOT NULL AND scheduled_purge_at <= ?',
        variables: [Variable.withInt(now)],
      ).getSingle();

      final countBefore = beforeResult.read<int>('count');

      if (countBefore == 0) {
        debugPrint('[Migration 44] No expired reminders to purge');
        return 0;
      }

      // Permanently delete reminders past their purge date
      await db.customStatement(
        'DELETE FROM note_reminders '
        'WHERE scheduled_purge_at IS NOT NULL AND scheduled_purge_at <= ?',
        [now],
      );

      _logger.info(
        '[Migration 44] ✅ Purged $countBefore expired reminders',
      );

      debugPrint('[Migration 44] ✅ Purged $countBefore expired reminders');

      return countBefore;
    } catch (error, stack) {
      _logger.error(
        '[Migration 44] Purge failed',
        error: error,
        stackTrace: stack,
      );

      return 0;
    }
  }
}
