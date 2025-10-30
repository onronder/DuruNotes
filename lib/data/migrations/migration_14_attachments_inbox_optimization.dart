import 'package:duru_notes/data/local/app_db.dart';

/// Migration 14: Attachments and Inbox Items with Performance Optimization
///
/// This migration adds:
/// 1. Attachments table for file management
/// 2. Inbox Items table for external content processing
/// 3. Comprehensive performance indexes for all tables
/// 4. Query optimization covering indexes
/// 5. Foreign key constraints for new tables
///
/// Performance target: &lt;100ms query response time
class Migration14AttachmentsInboxOptimization {
  static const int version = 14;
  static const String description =
      'Add attachments, inbox items, and comprehensive performance optimization';

  /// Apply migration to database (idempotent - safe to run multiple times)
  static Future<void> apply(AppDb db) async {
    // Enable foreign key constraints and performance settings
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement('PRAGMA synchronous = NORMAL');
    await db.customStatement('PRAGMA cache_size = 10000');
    await db.customStatement('PRAGMA temp_store = MEMORY');
    await db.customStatement('PRAGMA mmap_size = 268435456'); // 256MB

    // Ensure schema_versions table exists
    await _ensureSchemaVersionsTable(db);

    // Check if migration already applied
    final migrationApplied = await _isMigrationAlreadyApplied(db);
    if (migrationApplied) {
      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');
      return;
    }

    // ============================================
    // 1. CREATE NEW TABLES
    // ============================================

    // Attachments table
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS local_attachments (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size INTEGER NOT NULL,
        url TEXT,
        local_path TEXT,
        uploaded_at TEXT NOT NULL,
        file_hash TEXT,
        thumbnail_path TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE
      )
    ''');

    // Inbox Items table
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS local_inbox_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        source_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_processed INTEGER DEFAULT 0,
        note_id TEXT,
        processed_at TEXT,
        priority INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        title TEXT,
        preview TEXT,
        source_metadata TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE SET NULL
      )
    ''');

    // ============================================
    // 2. CRITICAL PERFORMANCE INDEXES
    // ============================================

    // Primary query patterns - hot path optimization
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_active_pinned_updated
      ON local_notes(deleted, is_pinned DESC, updated_at DESC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_user_type_updated
      ON local_notes(user_id, note_type, updated_at DESC)
      WHERE deleted = 0
    ''');

    // Tag operations - most frequent N+1 query source
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tags_note_covering
      ON note_tags(note_id, tag)
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tags_lookup_covering
      ON note_tags(tag, note_id)
    ''');

    // Task queries optimization
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tasks_note_status_position
      ON note_tasks(note_id, status, position)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due
      ON note_tasks(user_id, status, due_date)
      WHERE deleted = 0 AND status != 2
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tasks_overdue_active
      ON note_tasks(due_date ASC, status)
      WHERE deleted = 0 AND status IN (0, 1) AND due_date < date('now')
    ''');

    // Reminder queries optimization
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_reminders_active_time
      ON note_reminders(is_active, remind_at ASC)
      WHERE is_active = 1 AND remind_at IS NOT NULL
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_reminders_note_active
      ON note_reminders(note_id, is_active)
      WHERE is_active = 1
    ''');

    // Folder hierarchy and navigation
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_folders_parent_order
      ON local_folders(parent_id, sort_order ASC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_folders_path_lookup
      ON local_folders(path, deleted)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_folders_folder_coverage
      ON note_folders(folder_id, note_id, added_at)
    ''');

    // ============================================
    // 3. NEW TABLE INDEXES
    // ============================================

    // Attachment indexes for efficient queries
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_attachments_note_id
      ON local_attachments(note_id, uploaded_at DESC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_attachments_type_size
      ON local_attachments(mime_type, size DESC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_attachments_hash_dedup
      ON local_attachments(file_hash)
      WHERE deleted = 0 AND file_hash IS NOT NULL
    ''');

    // Inbox item indexes for processing workflows
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_inbox_unprocessed
      ON local_inbox_items(is_processed, priority DESC, created_at ASC)
      WHERE deleted = 0 AND is_processed = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_inbox_user_source
      ON local_inbox_items(user_id, source_type, created_at DESC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_inbox_status_priority
      ON local_inbox_items(status, priority DESC, created_at ASC)
      WHERE deleted = 0
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_inbox_processed_cleanup
      ON local_inbox_items(is_processed, processed_at ASC)
      WHERE deleted = 0 AND is_processed = 1
    ''');

    // ============================================
    // 4. SEARCH AND AGGREGATION OPTIMIZATION
    // ============================================

    // Full-text search support (when enabled)
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_text_search
      ON local_notes(title, body)
      WHERE deleted = 0
    ''');

    // Tag aggregation and popularity
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tags_popularity
      ON note_tags(tag)
    ''');

    // Template usage optimization
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_templates_category_system
      ON local_templates(category, is_system, sort_order)
      WHERE deleted = 0
    ''');

    // Saved search optimization
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_saved_searches_active
      ON saved_searches(is_pinned DESC, usage_count DESC, last_used_at DESC)
    ''');

    // ============================================
    // 5. COVERING INDEXES FOR ZERO TABLE LOOKUPS
    // ============================================

    // Note list view covering index (eliminates table scans)
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_list_covering
      ON local_notes(deleted, is_pinned, updated_at, id, title, body)
      WHERE deleted = 0
    ''');

    // Task list covering index
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tasks_list_covering
      ON note_tasks(note_id, deleted, status, content, due_date, priority, position)
      WHERE deleted = 0
    ''');

    // Tag count covering index
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tags_count_covering
      ON note_tags(tag, note_id)
    ''');

    // ============================================
    // 6. PERFORMANCE STATISTICS UPDATE
    // ============================================

    // Analyze tables for query planner optimization
    await db.customStatement('ANALYZE local_notes');
    await db.customStatement('ANALYZE note_tags');
    await db.customStatement('ANALYZE note_tasks');
    await db.customStatement('ANALYZE note_reminders');
    await db.customStatement('ANALYZE local_folders');
    await db.customStatement('ANALYZE note_folders');
    await db.customStatement('ANALYZE local_attachments');
    await db.customStatement('ANALYZE local_inbox_items');

    // Update database version
    await db.customStatement('''
      INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
      VALUES ($version, CURRENT_TIMESTAMP, '$description')
    ''');
  }

  /// Rollback migration
  static Future<void> rollback(AppDb db) async {
    // Drop new table indexes
    await db.customStatement('DROP INDEX IF EXISTS idx_attachments_note_id');
    await db.customStatement('DROP INDEX IF EXISTS idx_attachments_type_size');
    await db.customStatement('DROP INDEX IF EXISTS idx_attachments_hash_dedup');
    await db.customStatement('DROP INDEX IF EXISTS idx_inbox_unprocessed');
    await db.customStatement('DROP INDEX IF EXISTS idx_inbox_user_source');
    await db.customStatement('DROP INDEX IF EXISTS idx_inbox_status_priority');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_inbox_processed_cleanup',
    );

    // Drop performance indexes
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_notes_active_pinned_updated',
    );
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_notes_user_type_updated',
    );
    await db.customStatement('DROP INDEX IF EXISTS idx_tags_note_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_tags_lookup_covering');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_tasks_note_status_position',
    );
    await db.customStatement('DROP INDEX IF EXISTS idx_tasks_user_status_due');
    await db.customStatement('DROP INDEX IF EXISTS idx_tasks_overdue_active');
    await db.customStatement('DROP INDEX IF EXISTS idx_reminders_active_time');
    await db.customStatement('DROP INDEX IF EXISTS idx_reminders_note_active');
    await db.customStatement('DROP INDEX IF EXISTS idx_folders_parent_order');
    await db.customStatement('DROP INDEX IF EXISTS idx_folders_path_lookup');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_note_folders_folder_coverage',
    );

    // Drop covering indexes
    await db.customStatement('DROP INDEX IF EXISTS idx_notes_list_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_tasks_list_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_tags_count_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_notes_text_search');
    await db.customStatement('DROP INDEX IF EXISTS idx_tags_popularity');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_templates_category_system',
    );
    await db.customStatement('DROP INDEX IF EXISTS idx_saved_searches_active');

    // Drop new tables
    await db.customStatement('DROP TABLE IF EXISTS local_attachments');
    await db.customStatement('DROP TABLE IF EXISTS local_inbox_items');

    // Update database version
    await db.customStatement('''
      DELETE FROM schema_versions WHERE version = $version
    ''');
  }

  // ============================================
  // HELPER FUNCTIONS
  // ============================================

  /// Ensure schema_versions table exists for tracking
  static Future<void> _ensureSchemaVersionsTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS schema_versions (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        description TEXT
      )
    ''');
  }

  /// Check if migration has already been applied
  static Future<bool> _isMigrationAlreadyApplied(AppDb db) async {
    try {
      // Check for existence of new tables
      final attachmentsResult = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='local_attachments'
      ''').getSingleOrNull();

      final inboxResult = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='local_inbox_items'
      ''').getSingleOrNull();

      return attachmentsResult != null && inboxResult != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate migration success
  static Future<bool> validateMigration(AppDb db) async {
    try {
      // Check tables exist
      final tables = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name IN ('local_attachments', 'local_inbox_items')
      ''').get();

      if (tables.length != 2) return false;

      // Check critical indexes exist
      final indexes = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='index' AND name IN (
          'idx_notes_active_pinned_updated',
          'idx_tags_note_covering',
          'idx_attachments_note_id',
          'idx_inbox_unprocessed'
        )
      ''').get();

      return indexes.length >= 4;
    } catch (e) {
      return false;
    }
  }

  /// Get migration performance metrics
  static Future<Map<String, dynamic>> getPerformanceMetrics(AppDb db) async {
    try {
      // Table row counts
      final noteCount = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM local_notes WHERE deleted = 0',
          )
          .getSingle();
      final tagCount = await db
          .customSelect('SELECT COUNT(*) as count FROM note_tags')
          .getSingle();
      final taskCount = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM note_tasks WHERE deleted = 0',
          )
          .getSingle();
      final attachmentCount = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM local_attachments WHERE deleted = 0',
          )
          .getSingle();
      final inboxCount = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM local_inbox_items WHERE deleted = 0',
          )
          .getSingle();

      // Index count
      final indexCount = await db.customSelect('''
        SELECT COUNT(*) as count FROM sqlite_master WHERE type='index'
        AND name LIKE 'idx_%'
      ''').getSingle();

      return {
        'notes': noteCount.read<int>('count'),
        'tags': tagCount.read<int>('count'),
        'tasks': taskCount.read<int>('count'),
        'attachments': attachmentCount.read<int>('count'),
        'inbox_items': inboxCount.read<int>('count'),
        'indexes': indexCount.read<int>('count'),
        'migration_version': version,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
