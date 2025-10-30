import 'package:drift/drift.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/migrations/migration_32_phase1_performance_indexes.dart';

/// Migration 34: Add userId column to note_tasks for per-user isolation.
class Migration34NoteTasksUserId {
  static final AppLogger _logger = LoggerFactory.instance;

  static Future<void> run(DatabaseConnectionUser db) async {
    if (await _hasUserIdColumn(db)) {
      _logger.debug('[Migration 34] note_tasks already has user_id column');
      await Migration32Phase1PerformanceIndexes.ensureNoteTasksIndexes(db);
      return;
    }

    _logger.info('[Migration 34] Adding user_id to note_tasks');

    await db.transaction(() async {
      await db.customStatement(
        'ALTER TABLE note_tasks ADD COLUMN user_id TEXT',
      );

      // Backfill ownership from parent notes.
      await db.customStatement('''
        UPDATE note_tasks
        SET user_id = (
          SELECT user_id FROM local_notes
          WHERE local_notes.id = note_tasks.note_id
          LIMIT 1
        )
      ''');

      // Remove orphaned tasks to avoid leaking data between users.
      await db.customStatement('''
        DELETE FROM note_tasks
        WHERE user_id IS NULL OR TRIM(user_id) = ''
      ''');
    });

    await Migration32Phase1PerformanceIndexes.ensureNoteTasksIndexes(db);
  }

  static Future<bool> _hasUserIdColumn(DatabaseConnectionUser db) async {
    final results = await db
        .customSelect('PRAGMA table_info(note_tasks)')
        .get();
    for (final row in results) {
      final name = row.data['name'] as String?;
      if (name != null && name.toLowerCase() == 'user_id') {
        return true;
      }
    }
    return false;
  }
}
