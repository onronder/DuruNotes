import 'package:drift/drift.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/migrations/migration_32_phase1_performance_indexes.dart';

/// Migration 33: Add userId column to pending_ops for user isolation.
///
/// This migration backfills ownership for existing pending operations and
/// rebuilds the table to enforce a non-null `user_id` column.
class Migration33PendingOpsUserId {
  static final AppLogger _logger = LoggerFactory.instance;

  static Future<void> run(DatabaseConnectionUser db) async {
    if (await _hasUserIdColumn(db)) {
      _logger.debug('[Migration 33] pending_ops already has user_id column');
      await Migration32Phase1PerformanceIndexes.ensurePendingOpsIndexes(db);
      return;
    }

    _logger.info('[Migration 33] Adding user_id to pending_ops');

    await db.transaction(() async {
      await db.customStatement('''
        CREATE TABLE pending_ops_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_id TEXT NOT NULL,
          kind TEXT NOT NULL,
          payload TEXT NULL,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          user_id TEXT NOT NULL
        )
      ''');

      await db.customStatement('''
        INSERT INTO pending_ops_new (
          id, entity_id, kind, payload, created_at, user_id
        )
        SELECT
          p.id,
          p.entity_id,
          p.kind,
          p.payload,
          p.created_at,
          COALESCE(
            (SELECT user_id FROM local_notes WHERE id = p.entity_id LIMIT 1),
            (SELECT user_id FROM note_tasks WHERE id = p.entity_id LIMIT 1),
            (SELECT user_id FROM local_folders WHERE id = p.entity_id LIMIT 1),
            (SELECT user_id FROM attachments WHERE id = p.entity_id LIMIT 1),
            (SELECT user_id FROM local_templates WHERE id = p.entity_id LIMIT 1),
            (SELECT user_id FROM saved_searches WHERE id = p.entity_id LIMIT 1),
            ''
          )
        FROM pending_ops p
      ''');

      await db.customStatement('DROP TABLE pending_ops');
      await db.customStatement(
        'ALTER TABLE pending_ops_new RENAME TO pending_ops',
      );
    });

    // Remove any orphaned operations where user_id could not be resolved.
    await db.customStatement("DELETE FROM pending_ops WHERE user_id = ''");

    await Migration32Phase1PerformanceIndexes.ensurePendingOpsIndexes(db);
  }

  static Future<bool> _hasUserIdColumn(DatabaseConnectionUser db) async {
    final columns = await db
        .customSelect('PRAGMA table_info(pending_ops)')
        .get();
    for (final column in columns) {
      final name = column.data['name'] as String?;
      if (name != null && name.toLowerCase() == 'user_id') {
        return true;
      }
    }
    return false;
  }
}
