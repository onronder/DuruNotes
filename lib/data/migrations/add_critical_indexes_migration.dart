import 'package:drift/drift.dart';

/// Critical database indexes migration to prevent performance collapse
/// Based on Database Optimizer audit recommendations
class AddCriticalIndexesMigration {
  /// Apply all critical indexes to the database
  static Future<void> apply(Migrator m) async {
    // ==============================
    // NOTES TABLE INDEXES
    // ==============================

    // Composite index for common queries
    await m.createIndex(Index(
      'idx_notes_user_deleted_updated',
      'CREATE INDEX idx_notes_user_deleted_updated ON local_notes(user_id, deleted, updated_at DESC)',
    ));

    // Index for folder queries
    await m.createIndex(Index(
      'idx_notes_folder_deleted',
      'CREATE INDEX idx_notes_folder_deleted ON local_notes(folder_id, deleted) WHERE folder_id IS NOT NULL',
    ));

    // Index for pinned notes
    await m.createIndex(Index(
      'idx_notes_pinned_deleted',
      'CREATE INDEX idx_notes_pinned_deleted ON local_notes(is_pinned, deleted) WHERE is_pinned = 1',
    ));

    // Index for version tracking (sync)
    await m.createIndex(Index(
      'idx_notes_version',
      'CREATE INDEX idx_notes_version ON local_notes(version)',
    ));

    // ==============================
    // TASKS TABLE INDEXES
    // ==============================

    // Composite index for task queries
    await m.createIndex(Index(
      'idx_tasks_note_status_deleted',
      'CREATE INDEX idx_tasks_note_status_deleted ON note_tasks(note_id, status, deleted)',
    ));

    // Index for priority queries
    await m.createIndex(Index(
      'idx_tasks_priority_status',
      'CREATE INDEX idx_tasks_priority_status ON note_tasks(priority, status) WHERE deleted = 0',
    ));

    // Index for due date queries
    await m.createIndex(Index(
      'idx_tasks_due_date',
      'CREATE INDEX idx_tasks_due_date ON note_tasks(due_date) WHERE due_date IS NOT NULL AND deleted = 0',
    ));

    // Index for completion tracking
    await m.createIndex(Index(
      'idx_tasks_completed_at',
      'CREATE INDEX idx_tasks_completed_at ON note_tasks(completed_at DESC) WHERE completed_at IS NOT NULL',
    ));

    // ==============================
    // FOLDERS TABLE INDEXES
    // ==============================

    // Index for folder hierarchy
    await m.createIndex(Index(
      'idx_folders_parent_deleted',
      'CREATE INDEX idx_folders_parent_deleted ON local_folders(parent_id, deleted)',
    ));

    // Index for folder path queries
    await m.createIndex(Index(
      'idx_folders_path',
      'CREATE INDEX idx_folders_path ON local_folders(path) WHERE deleted = 0',
    ));

    // Index for user folders
    await m.createIndex(Index(
      'idx_folders_user_deleted',
      'CREATE INDEX idx_folders_user_deleted ON local_folders(user_id, deleted)',
    ));

    // ==============================
    // NOTE_FOLDERS JOIN TABLE INDEXES
    // ==============================

    // Composite index for both directions of the relationship
    await m.createIndex(Index(
      'idx_note_folders_note_folder',
      'CREATE INDEX idx_note_folders_note_folder ON note_folders(note_id, folder_id)',
    ));

    await m.createIndex(Index(
      'idx_note_folders_folder_note',
      'CREATE INDEX idx_note_folders_folder_note ON note_folders(folder_id, note_id)',
    ));

    // ==============================
    // TAGS TABLE INDEXES
    // ==============================

    // Index for tag queries
    await m.createIndex(Index(
      'idx_tags_name',
      'CREATE INDEX idx_tags_name ON tags(name)',
    ));

    await m.createIndex(Index(
      'idx_tags_user',
      'CREATE INDEX idx_tags_user ON tags(user_id)',
    ));

    // ==============================
    // NOTE_TAGS JOIN TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_note_tags_note_tag',
      'CREATE INDEX idx_note_tags_note_tag ON note_tags(note_id, tag_id)',
    ));

    await m.createIndex(Index(
      'idx_note_tags_tag_note',
      'CREATE INDEX idx_note_tags_tag_note ON note_tags(tag_id, note_id)',
    ));

    // ==============================
    // SAVED_SEARCHES TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_saved_searches_user_pinned',
      'CREATE INDEX idx_saved_searches_user_pinned ON saved_searches(user_id, is_pinned DESC)',
    ));

    await m.createIndex(Index(
      'idx_saved_searches_usage',
      'CREATE INDEX idx_saved_searches_usage ON saved_searches(usage_count DESC, last_used DESC)',
    ));

    // ==============================
    // ATTACHMENTS TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_attachments_note',
      'CREATE INDEX idx_attachments_note ON attachments(note_id)',
    ));

    await m.createIndex(Index(
      'idx_attachments_mime_type',
      'CREATE INDEX idx_attachments_mime_type ON attachments(mime_type)',
    ));

    // ==============================
    // INBOX_ITEMS TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_inbox_items_user_processed',
      'CREATE INDEX idx_inbox_items_user_processed ON inbox_items(user_id, is_processed)',
    ));

    await m.createIndex(Index(
      'idx_inbox_items_created',
      'CREATE INDEX idx_inbox_items_created ON inbox_items(created_at DESC) WHERE is_processed = 0',
    ));

    await m.createIndex(Index(
      'idx_inbox_items_source_type',
      'CREATE INDEX idx_inbox_items_source_type ON inbox_items(source_type)',
    ));

    // ==============================
    // TEMPLATES TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_templates_user_deleted',
      'CREATE INDEX idx_templates_user_deleted ON local_templates(user_id, deleted)',
    ));

    await m.createIndex(Index(
      'idx_templates_category',
      'CREATE INDEX idx_templates_category ON local_templates(category) WHERE deleted = 0',
    ));

    // ==============================
    // REMINDERS TABLE INDEXES
    // ==============================

    await m.createIndex(Index(
      'idx_reminders_note',
      'CREATE INDEX idx_reminders_note ON note_reminders(note_id)',
    ));

    await m.createIndex(Index(
      'idx_reminders_time',
      'CREATE INDEX idx_reminders_time ON note_reminders(reminder_time) WHERE is_completed = 0',
    ));

    await m.createIndex(Index(
      'idx_reminders_user_time',
      'CREATE INDEX idx_reminders_user_time ON note_reminders(user_id, reminder_time) WHERE is_completed = 0',
    ));
  }

  /// Check if indexes exist (for idempotent migrations)
  static Future<bool> indexesExist(DatabaseConnectionUser db) async {
    try {
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      ).get();

      // Check if we have a reasonable number of custom indexes
      return result.length >= 20; // We're adding ~30 indexes
    } catch (e) {
      return false;
    }
  }

  /// Get index statistics for monitoring
  static Future<Map<String, dynamic>> getIndexStats(DatabaseConnectionUser db) async {
    final stats = <String, dynamic>{};

    try {
      // Count total indexes
      final indexCount = await db.customSelect(
        "SELECT COUNT(*) as count FROM sqlite_master WHERE type='index'",
      ).getSingle();
      stats['total_indexes'] = indexCount.read<int>('count');

      // Get table statistics
      final tables = ['local_notes', 'note_tasks', 'local_folders', 'note_folders', 'tags', 'note_tags'];
      for (final table in tables) {
        final tableIndexes = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?",
          variables: [Variable.withString(table)],
        ).get();
        stats['${table}_indexes'] = tableIndexes.length;
      }

      // Check for missing critical indexes
      final criticalIndexes = [
        'idx_notes_user_deleted_updated',
        'idx_tasks_note_status_deleted',
        'idx_folders_parent_deleted',
        'idx_note_folders_note_folder',
      ];

      final missingIndexes = <String>[];
      for (final indexName in criticalIndexes) {
        final exists = await db.customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",
          variables: [Variable.withString(indexName)],
        ).getSingleOrNull();

        if (exists == null) {
          missingIndexes.add(indexName);
        }
      }
      stats['missing_critical_indexes'] = missingIndexes;

    } catch (e) {
      stats['error'] = e.toString();
    }

    return stats;
  }
}