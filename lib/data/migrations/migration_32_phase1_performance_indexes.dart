import 'package:drift/drift.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/performance/performance_monitor.dart';

/// Migration 32: Phase 1 performance indexes to prepare for userId filtering.
///
/// These indexes are created ahead of the userId enforcement work so that when
/// additional filters are rolled out, the queries will already have optimal
/// access paths. Each helper can be invoked independently and is safe to call
/// multiple times due to `CREATE INDEX IF NOT EXISTS`.
class Migration32Phase1PerformanceIndexes {
  static final AppLogger _logger = LoggerFactory.instance;

  /// Apply all available Phase 1 indexes.
  static Future<void> apply(DatabaseConnectionUser db) async {
    _logger.info('[Migration 32] Applying Phase 1 performance indexes');

    await _createLocalNotesIndexes(db);
    await _createLocalFoldersIndexes(db);
    await _createNoteRemindersIndexes(db);
    await _createAttachmentsIndexes(db);

    // Tables that will gain userId columns later in Phase 1. Calling these now
    // ensures Re-run safety; they will be invoked again after migrations add
    // the necessary columns.
    await _createPendingOpsIndexes(db);
    await _createNoteTasksIndexes(db);
    await _createNoteTagsIndexes(db);
    await _createNoteLinksIndexes(db);
    await _createNoteFoldersIndexes(db);
  }

  /// Exposed helpers for follow-up migrations.
  static Future<void> ensurePendingOpsIndexes(DatabaseConnectionUser db) =>
      _createPendingOpsIndexes(db);
  static Future<void> ensureNoteTasksIndexes(DatabaseConnectionUser db) =>
      _createNoteTasksIndexes(db);
  static Future<void> ensureNoteTagsIndexes(DatabaseConnectionUser db) =>
      _createNoteTagsIndexes(db);
  static Future<void> ensureNoteLinksIndexes(DatabaseConnectionUser db) =>
      _createNoteLinksIndexes(db);
  static Future<void> ensureNoteFoldersIndexes(DatabaseConnectionUser db) =>
      _createNoteFoldersIndexes(db);

  static Future<void> _createLocalNotesIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'local_notes',
      name: 'idx_local_notes_user_deleted_updated',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_notes_user_deleted_updated
        ON local_notes(user_id, deleted, updated_at DESC)
      ''',
      requiredColumns: const ['user_id', 'deleted', 'updated_at'],
    );

    await _createIndex(
      db,
      table: 'local_notes',
      name: 'idx_local_notes_user_pinned_updated',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_notes_user_pinned_updated
        ON local_notes(user_id, is_pinned DESC, updated_at DESC)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'is_pinned', 'updated_at', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'local_notes',
      name: 'idx_local_notes_user_type',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_notes_user_type
        ON local_notes(user_id, note_type)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'note_type', 'deleted'],
    );
  }

  static Future<void> _createLocalFoldersIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'local_folders',
      name: 'idx_local_folders_user_parent_order',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_folders_user_parent_order
        ON local_folders(user_id, parent_id, sort_order)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'parent_id', 'sort_order', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'local_folders',
      name: 'idx_local_folders_user_path',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_folders_user_path
        ON local_folders(user_id, path)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'path', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'local_folders',
      name: 'idx_local_folders_user_root',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_local_folders_user_root
        ON local_folders(user_id, parent_id, sort_order)
        WHERE deleted = 0 AND parent_id IS NULL
      ''',
      requiredColumns: const ['user_id', 'parent_id', 'sort_order', 'deleted'],
    );
  }

  static Future<void> _createNoteRemindersIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'note_reminders',
      name: 'idx_note_reminders_user_active_time',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_reminders_user_active_time
        ON note_reminders(user_id, is_active, remind_at)
        WHERE remind_at IS NOT NULL
      ''',
      requiredColumns: const ['user_id', 'is_active', 'remind_at'],
    );

    await _createIndex(
      db,
      table: 'note_reminders',
      name: 'idx_note_reminders_user_note',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_reminders_user_note
        ON note_reminders(user_id, note_id)
      ''',
      requiredColumns: const ['user_id', 'note_id'],
    );

    await _createIndex(
      db,
      table: 'note_reminders',
      name: 'idx_note_reminders_user_snoozed',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_reminders_user_snoozed
        ON note_reminders(user_id, snoozed_until)
        WHERE snoozed_until IS NOT NULL
      ''',
      requiredColumns: const ['user_id', 'snoozed_until'],
    );

    await _createIndex(
      db,
      table: 'note_reminders',
      name: 'idx_note_reminders_user_recurring',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_reminders_user_recurring
        ON note_reminders(user_id, recurrence_pattern)
        WHERE is_active = 1 AND recurrence_pattern != 0
      ''',
      requiredColumns: const ['user_id', 'recurrence_pattern', 'is_active'],
    );
  }

  static Future<void> _createAttachmentsIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'attachments',
      name: 'idx_attachments_user_note',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_attachments_user_note
        ON attachments(user_id, note_id)
      ''',
      requiredColumns: const ['user_id', 'note_id'],
    );

    await _createIndex(
      db,
      table: 'attachments',
      name: 'idx_attachments_user_created',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_attachments_user_created
        ON attachments(user_id, created_at DESC)
      ''',
      requiredColumns: const ['user_id', 'created_at'],
    );

    await _createIndex(
      db,
      table: 'attachments',
      name: 'idx_attachments_user_mime',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_attachments_user_mime
        ON attachments(user_id, mime_type)
      ''',
      requiredColumns: const ['user_id', 'mime_type'],
    );
  }

  static Future<void> _createPendingOpsIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'pending_ops',
      name: 'idx_pending_ops_user_created',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_pending_ops_user_created
        ON pending_ops(user_id, created_at ASC)
      ''',
      requiredColumns: const ['user_id', 'created_at'],
    );

    await _createIndex(
      db,
      table: 'pending_ops',
      name: 'idx_pending_ops_user_kind_created',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_pending_ops_user_kind_created
        ON pending_ops(user_id, kind, created_at ASC)
      ''',
      requiredColumns: const ['user_id', 'kind', 'created_at'],
    );
  }

  static Future<void> _createNoteTasksIndexes(DatabaseConnectionUser db) async {
    await _createIndex(
      db,
      table: 'note_tasks',
      name: 'idx_note_tasks_user_note_deleted',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tasks_user_note_deleted
        ON note_tasks(user_id, note_id, deleted)
      ''',
      requiredColumns: const ['user_id', 'note_id', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'note_tasks',
      name: 'idx_note_tasks_user_status_due',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status_due
        ON note_tasks(user_id, status, due_date)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'status', 'due_date', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'note_tasks',
      name: 'idx_note_tasks_user_priority_created',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tasks_user_priority_created
        ON note_tasks(user_id, priority DESC, created_at DESC)
        WHERE deleted = 0
      ''',
      requiredColumns: const ['user_id', 'priority', 'created_at', 'deleted'],
    );

    await _createIndex(
      db,
      table: 'note_tasks',
      name: 'idx_note_tasks_user_parent',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tasks_user_parent
        ON note_tasks(user_id, parent_task_id)
        WHERE deleted = 0 AND parent_task_id IS NOT NULL
      ''',
      requiredColumns: const ['user_id', 'parent_task_id', 'deleted'],
    );
  }

  static Future<void> _createNoteTagsIndexes(DatabaseConnectionUser db) async {
    await _createIndex(
      db,
      table: 'note_tags',
      name: 'idx_note_tags_user_tag',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tags_user_tag
        ON note_tags(user_id, tag)
      ''',
      requiredColumns: const ['user_id', 'tag'],
    );

    await _createIndex(
      db,
      table: 'note_tags',
      name: 'idx_note_tags_user_note',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tags_user_note
        ON note_tags(user_id, note_id)
      ''',
      requiredColumns: const ['user_id', 'note_id'],
    );

    await _createIndex(
      db,
      table: 'note_tags',
      name: 'idx_note_tags_user_tag_note',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_tags_user_tag_note
        ON note_tags(user_id, tag, note_id)
      ''',
      requiredColumns: const ['user_id', 'tag', 'note_id'],
    );
  }

  static Future<void> _createNoteLinksIndexes(DatabaseConnectionUser db) async {
    await _createIndex(
      db,
      table: 'note_links',
      name: 'idx_note_links_user_source',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_links_user_source
        ON note_links(user_id, source_id)
      ''',
      requiredColumns: const ['user_id', 'source_id'],
    );

    await _createIndex(
      db,
      table: 'note_links',
      name: 'idx_note_links_user_target',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_links_user_target
        ON note_links(user_id, target_id)
      ''',
      requiredColumns: const ['user_id', 'target_id'],
    );

    await _createIndex(
      db,
      table: 'note_links',
      name: 'idx_note_links_user_target_title',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_links_user_target_title
        ON note_links(user_id, target_title)
      ''',
      requiredColumns: const ['user_id', 'target_title'],
    );
  }

  static Future<void> _createNoteFoldersIndexes(
    DatabaseConnectionUser db,
  ) async {
    await _createIndex(
      db,
      table: 'note_folders',
      name: 'idx_note_folders_user_folder_updated',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder_updated
        ON note_folders(user_id, folder_id, updated_at DESC)
      ''',
      requiredColumns: const ['user_id', 'folder_id', 'updated_at'],
    );

    await _createIndex(
      db,
      table: 'note_folders',
      name: 'idx_note_folders_user_note',
      sql: '''
        CREATE INDEX IF NOT EXISTS idx_note_folders_user_note
        ON note_folders(user_id, note_id)
      ''',
      requiredColumns: const ['user_id', 'note_id'],
    );
  }

  static Future<void> _createIndex(
    DatabaseConnectionUser db, {
    required String table,
    required String name,
    required String sql,
    Iterable<String> requiredColumns = const [],
  }) async {
    if (requiredColumns.isNotEmpty) {
      final missingColumns = await _missingColumns(db, table, requiredColumns);
      if (missingColumns.isNotEmpty) {
        _logger.debug(
          '[Migration 32] Skipping index $name – missing columns',
          data: {'table': table, 'missingColumns': missingColumns.toList()},
        );
        return;
      }
    }

    await PerformanceMonitor().measure(
      'db.index_build.$name',
      () => db.customStatement(sql),
    );
    _logger.debug('[Migration 32] Ensured index $name', data: {'table': table});
  }

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
