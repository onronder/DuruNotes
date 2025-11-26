import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/performance/performance_monitor.dart';

/// Migration 39: Add missing soft delete indexes for Trash functionality.
///
/// Phase 1.1: Soft Delete & Trash System requires efficient queries for:
/// - Listing deleted folders (WHERE deleted = true)
/// - Filtering active items (WHERE deleted = false)
///
/// Existing indexes from Migration 32:
/// - local_notes: idx_local_notes_user_deleted_updated ✅
/// - note_tasks: idx_note_tasks_user_note_deleted ✅
///
/// Missing:
/// - local_folders: needs (user_id, deleted) index for Trash queries
class Migration39SoftDeleteIndexes {
  static final AppLogger _logger = LoggerFactory.instance;

  /// Apply soft delete indexes for Phase 1.1
  static Future<void> apply(DatabaseConnectionUser db) async {
    _logger.info(
      '[Migration 39] Applying soft delete indexes for Trash system',
    );

    await _createLocalFoldersDeletedIndex(db);

    _logger.info('[Migration 39] Soft delete indexes applied successfully');
  }

  /// Create composite index on local_folders (user_id, deleted, updated_at)
  /// for efficient Trash folder queries and active folder filtering
  static Future<void> _createLocalFoldersDeletedIndex(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'local_folders',
      name: 'idx_local_folders_user_deleted_updated',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_folders_user_deleted_updated
        ON local_folders(user_id, deleted, updated_at DESC)
      ''',
      requiredColumns: const ['user_id', 'deleted', 'updated_at'],
    );
  }

  /// Helper to create index with column validation
  static Future<void> _createIndex(
    DatabaseConnectionUser db, {
    required String table,
    required String name,
    required String sql,
    Iterable<String> requiredColumns = const [],
  }) async {
    // Validate required columns exist
    if (requiredColumns.isNotEmpty) {
      final missingColumns = await _missingColumns(db, table, requiredColumns);
      if (missingColumns.isNotEmpty) {
        _logger.debug(
          '[Migration 39] Skipping index $name – missing columns',
          data: {'table': table, 'missingColumns': missingColumns.toList()},
        );
        return;
      }
    }

    // Create index with performance monitoring
    await PerformanceMonitor().measure(
      'db.index_build.$name',
      () => db.customStatement(sql),
    );

    _logger.debug('[Migration 39] Created index $name', data: {'table': table});
  }

  /// Check which required columns are missing from table
  static Future<Iterable<String>> _missingColumns(
    DatabaseConnectionUser db,
    String table,
    Iterable<String> requiredColumns,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();

    final existingColumns = rows
        .map((row) => row.data['name'])
        .whereType<String>()
        .map((name) => name.toLowerCase())
        .toSet();

    return requiredColumns.where(
      (column) => !existingColumns.contains(column.toLowerCase()),
    );
  }
}
