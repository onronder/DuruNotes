import 'package:drift/drift.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/migrations/migration_32_phase1_performance_indexes.dart';

/// Migration 38: Add userId column to note_folders junction table.
class Migration38NoteFoldersUserId {
  static final AppLogger _logger = LoggerFactory.instance;

  static Future<void> run(DatabaseConnectionUser db) async {
    if (await _hasColumn(db, 'note_folders', 'user_id')) {
      _logger.debug('[Migration 38] note_folders already has user_id column');
      await Migration32Phase1PerformanceIndexes.ensureNoteFoldersIndexes(db);
      return;
    }

    _logger.info('[Migration 38] Adding user_id to note_folders');

    await db.transaction(() async {
      await db.customStatement('''
        CREATE TABLE note_folders_new (
          note_id TEXT NOT NULL,
          folder_id TEXT NOT NULL,
          added_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          user_id TEXT NOT NULL,
          PRIMARY KEY (note_id)
        )
      ''');

      await db.customStatement('''
        INSERT INTO note_folders_new (note_id, folder_id, added_at, updated_at, user_id)
        SELECT
          nf.note_id,
          nf.folder_id,
          nf.added_at,
          nf.updated_at,
          COALESCE(
            (SELECT user_id FROM local_notes WHERE id = nf.note_id LIMIT 1),
            (SELECT user_id FROM local_folders WHERE id = nf.folder_id LIMIT 1),
            ''
          )
        FROM note_folders nf
      ''');

      await db.customStatement('DROP TABLE note_folders');
      await db.customStatement(
        'ALTER TABLE note_folders_new RENAME TO note_folders',
      );
    });

    await db.customStatement("DELETE FROM note_folders WHERE user_id = ''");
    await Migration32Phase1PerformanceIndexes.ensureNoteFoldersIndexes(db);
  }

  static Future<bool> _hasColumn(
    DatabaseConnectionUser db,
    String table,
    String column,
  ) async {
    final info = await db.customSelect('PRAGMA table_info($table)').get();
    return info.any(
      (row) =>
          (row.data['name'] as String?)?.toLowerCase() == column.toLowerCase(),
    );
  }
}
