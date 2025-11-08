import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/performance/performance_monitor.dart';

/// Migration 40: Add timestamp columns for soft delete & trash system.
///
/// Phase 1.1: Soft Delete Enhancement - adds deletion tracking timestamps:
/// - deleted_at: When the item was soft-deleted
/// - scheduled_purge_at: When the item should be permanently deleted (30 days)
///
/// These columns enable:
/// - User-friendly "Deleted on..." display in Trash UI
/// - Auto-purge after 30-day retention period
/// - Audit trail for deletion timeline
///
/// Safety:
/// - All new columns are nullable (no data loss risk)
/// - Backfills existing deleted items using updated_at as approximation
/// - Idempotent: safe to run multiple times
class Migration40SoftDeleteTimestamps {
  static final AppLogger _logger = LoggerFactory.instance;

  /// 30-day retention period in microseconds (Drift stores DateTime as microseconds)
  static final int _retentionPeriodMicros = const Duration(days: 30).inMicroseconds;

  /// Apply soft delete timestamp columns for Phase 1.1
  static Future<void> apply(DatabaseConnectionUser db) async {
    _logger.info(
      '[Migration 40] Applying soft delete timestamp columns for Trash system',
    );

    await _addTimestampColumnsToLocalNotes(db);
    await _addTimestampColumnsToLocalFolders(db);
    await _addTimestampColumnsToNoteTasks(db);

    await _backfillExistingDeletedItems(db);

    _logger.info(
      '[Migration 40] Soft delete timestamp columns applied successfully',
    );
  }

  /// Add deleted_at and scheduled_purge_at columns to local_notes table
  static Future<void> _addTimestampColumnsToLocalNotes(
    DatabaseConnectionUser db,
  ) async {
    await _addTimestampColumns(db, tableName: 'local_notes');
  }

  /// Add deleted_at and scheduled_purge_at columns to local_folders table
  static Future<void> _addTimestampColumnsToLocalFolders(
    DatabaseConnectionUser db,
  ) async {
    await _addTimestampColumns(db, tableName: 'local_folders');
  }

  /// Add deleted_at and scheduled_purge_at columns to note_tasks table
  static Future<void> _addTimestampColumnsToNoteTasks(
    DatabaseConnectionUser db,
  ) async {
    await _addTimestampColumns(db, tableName: 'note_tasks');
  }

  /// Generic helper to add timestamp columns to any table
  static Future<void> _addTimestampColumns(
    DatabaseConnectionUser db, {
    required String tableName,
  }) async {
    // Check if columns already exist
    final columns = await _getTableColumns(db, tableName);
    final hasDeletedAt = columns.contains('deleted_at');
    final hasScheduledPurgeAt = columns.contains('scheduled_purge_at');

    if (hasDeletedAt && hasScheduledPurgeAt) {
      _logger.debug(
        '[Migration 40] Timestamp columns already exist in $tableName',
      );
      return;
    }

    // Add deleted_at column if not exists
    if (!hasDeletedAt) {
      await PerformanceMonitor().measure(
        'db.migration.add_deleted_at_$tableName',
        () => db.customStatement(
          'ALTER TABLE $tableName ADD COLUMN deleted_at INTEGER',
        ),
      );
      _logger.debug(
        '[Migration 40] Added deleted_at column to $tableName',
      );
    }

    // Add scheduled_purge_at column if not exists
    if (!hasScheduledPurgeAt) {
      await PerformanceMonitor().measure(
        'db.migration.add_scheduled_purge_at_$tableName',
        () => db.customStatement(
          'ALTER TABLE $tableName ADD COLUMN scheduled_purge_at INTEGER',
        ),
      );
      _logger.debug(
        '[Migration 40] Added scheduled_purge_at column to $tableName',
      );
    }
  }

  /// Backfill timestamp columns for existing soft-deleted items
  static Future<void> _backfillExistingDeletedItems(
    DatabaseConnectionUser db,
  ) async {
    _logger.debug(
      '[Migration 40] Backfilling timestamps for existing deleted items',
    );

    // Backfill each table independently
    await _backfillTable(db, tableName: 'local_notes');
    await _backfillTable(db, tableName: 'local_folders');
    await _backfillTable(db, tableName: 'note_tasks');

    _logger.debug(
      '[Migration 40] Backfill completed for all tables',
    );
  }

  /// Backfill timestamps for a specific table
  /// For existing deleted items: deleted_at = updated_at, scheduled_purge_at = updated_at + 30 days
  static Future<void> _backfillTable(
    DatabaseConnectionUser db, {
    required String tableName,
  }) async {
    // Count items that need backfill
    final countResult = await db.customSelect(
      'SELECT COUNT(*) as count FROM $tableName WHERE deleted = 1 AND deleted_at IS NULL',
    ).getSingle();

    final count = countResult.read<int>('count');
    if (count == 0) {
      _logger.debug(
        '[Migration 40] No items to backfill in $tableName',
      );
      return;
    }

    // Backfill: Use updated_at as approximation for deleted_at
    // Schedule purge 30 days after deletion (using microseconds for Drift DateTime)
    await PerformanceMonitor().measure(
      'db.migration.backfill_$tableName',
      () => db.customStatement(
        '''
        UPDATE $tableName
        SET
          deleted_at = updated_at,
          scheduled_purge_at = updated_at + ?
        WHERE deleted = 1 AND deleted_at IS NULL
        ''',
        [_retentionPeriodMicros],
      ),
    );

    _logger.info(
      '[Migration 40] Backfilled $count deleted items in $tableName',
      data: {'table': tableName, 'count': count},
    );
  }

  /// Get list of columns for a table
  static Future<Set<String>> _getTableColumns(
    DatabaseConnectionUser db,
    String tableName,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($tableName)').get();

    return rows
        .map((row) => row.data['name'])
        .whereType<String>()
        .map((name) => name.toLowerCase())
        .toSet();
  }
}
