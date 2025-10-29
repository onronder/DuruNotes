import 'package:drift/drift.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/migrations/migration_32_phase1_performance_indexes.dart';

/// Migration 37: Add userId column to note_tags and note_links for user isolation.
class Migration37NoteTagsLinksUserId {
  static final AppLogger _logger = LoggerFactory.instance;

  static Future<void> run(DatabaseConnectionUser db) async {
    final hasTagUserId = await _hasColumn(db, 'note_tags', 'user_id');
    final hasLinkUserId = await _hasColumn(db, 'note_links', 'user_id');

    if (hasTagUserId && hasLinkUserId) {
      _logger.debug(
        '[Migration 37] note_tags/note_links already have user_id column',
      );
      await Migration32Phase1PerformanceIndexes.ensureNoteTagsIndexes(db);
      await Migration32Phase1PerformanceIndexes.ensureNoteLinksIndexes(db);
      return;
    }

    _logger.info('[Migration 37] Adding user_id to note_tags and note_links');

    await db.transaction(() async {
      await _rebuildNoteTags(db);
      await _rebuildNoteLinks(db);
    });

    await Migration32Phase1PerformanceIndexes.ensureNoteTagsIndexes(db);
    await Migration32Phase1PerformanceIndexes.ensureNoteLinksIndexes(db);
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

  static Future<void> _rebuildNoteTags(DatabaseConnectionUser db) async {
    _logger.info('[Migration 37] Rebuilding note_tags with user_id');

    await db.customStatement('''
      CREATE TABLE note_tags_new (
        note_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        user_id TEXT NOT NULL,
        PRIMARY KEY (note_id, tag)
      )
    ''');

    await db.customStatement('''
      INSERT INTO note_tags_new (note_id, tag, user_id)
      SELECT
        t.note_id,
        t.tag,
        COALESCE(n.user_id, '')
      FROM note_tags t
      LEFT JOIN local_notes n ON n.id = t.note_id
    ''');

    await db.customStatement('DROP TABLE note_tags');
    await db.customStatement('ALTER TABLE note_tags_new RENAME TO note_tags');

    await db.customStatement("DELETE FROM note_tags WHERE user_id = ''");
  }

  static Future<void> _rebuildNoteLinks(DatabaseConnectionUser db) async {
    _logger.info('[Migration 37] Rebuilding note_links with user_id');

    await db.customStatement('''
      CREATE TABLE note_links_new (
        source_id TEXT NOT NULL,
        target_title TEXT NOT NULL,
        target_id TEXT NULL,
        user_id TEXT NOT NULL,
        PRIMARY KEY (source_id, target_title)
      )
    ''');

    await db.customStatement('''
      INSERT INTO note_links_new (source_id, target_title, target_id, user_id)
      SELECT
        l.source_id,
        l.target_title,
        l.target_id,
        COALESCE(n.user_id, '')
      FROM note_links l
      LEFT JOIN local_notes n ON n.id = l.source_id
    ''');

    await db.customStatement('DROP TABLE note_links');
    await db.customStatement('ALTER TABLE note_links_new RENAME TO note_links');

    await db.customStatement("DELETE FROM note_links WHERE user_id = ''");
  }
}
