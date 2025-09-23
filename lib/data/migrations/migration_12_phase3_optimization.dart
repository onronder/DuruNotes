import 'package:duru_notes/data/local/app_db.dart';

/// Migration 12: Phase 3 Data Layer Optimization
///
/// This migration adds:
/// 1. Foreign key constraints for data integrity
/// 2. Performance indexes for common query patterns
/// 3. Additional validation constraints
///
/// Note: SQLite foreign keys must be enabled with PRAGMA foreign_keys = ON
class Migration12Phase3Optimization {
  static const int version = 12;
  static const String description = 'Phase 3: Add foreign key constraints and performance indexes';

  /// Apply migration to database (idempotent - safe to run multiple times)
  static Future<void> apply(AppDb db) async {
    // Enable foreign key constraints
    await db.customStatement('PRAGMA foreign_keys = ON');

    // Ensure schema_versions table exists
    await _ensureSchemaVersionsTable(db);

    // Check if migration already applied by looking for our specific indexes
    final migrationApplied = await _isMigrationAlreadyApplied(db);
    if (migrationApplied) {
      // Migration already applied, just update version and exit
      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at)
        VALUES ($version, CURRENT_TIMESTAMP)
      ''');
      return;
    }

    // ============================================
    // 1. FOREIGN KEY CONSTRAINTS (IDEMPOTENT)
    // ============================================

    // Note: SQLite doesn't support adding foreign keys to existing tables.
    // We need to recreate tables with constraints. Using a safe approach:
    // 1. Create new table with constraints
    // 2. Copy data
    // 3. Drop old table
    // 4. Rename new table

    // Only apply foreign key changes if tables don't already have them
    await _addForeignKeyToNoteTagsSafe(db);
    await _addForeignKeyToNoteLinksSafe(db);
    await _addForeignKeyToNoteRemindersSafe(db);
    await _addForeignKeyToNoteTasksSafe(db);
    await _addForeignKeyToNoteFoldersSafe(db);
    await _addForeignKeyToLocalFoldersSafe(db);

    // ============================================
    // 2. PERFORMANCE INDEXES
    // ============================================

    // Composite index for pinned + updated sorting (most common query)
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_notes_pinned_updated
      ON local_notes(is_pinned DESC, updated_at DESC)
      WHERE deleted = 0
    ''');

    // Composite index for note-tag queries
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tags_note_tag
      ON note_tags(note_id, tag)
    ''');

    // Index for active tasks by note
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tasks_note_status
      ON note_tasks(note_id, status)
      WHERE deleted = 0
    ''');

    // Index for active reminders by note
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_reminders_note_active
      ON note_reminders(note_id, is_active)
    ''');

    // Index for folder hierarchy navigation
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_folders_parent_sort
      ON local_folders(parent_id, sort_order)
      WHERE deleted = 0
    ''');

    // Index for note-folder relationships
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_folders_folder_note
      ON note_folders(folder_id, note_id)
    ''');

    // Index for open tasks with due dates
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tasks_open_due
      ON note_tasks(due_date ASC)
      WHERE status = 0 AND deleted = 0 AND due_date IS NOT NULL
    ''');

    // Index for active reminders by time
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_reminders_active_time
      ON note_reminders(remind_at ASC)
      WHERE is_active = 1 AND remind_at IS NOT NULL
    ''');

    // Index for saved searches by usage
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_saved_searches_usage
      ON saved_searches(is_pinned DESC, usage_count DESC, last_used_at DESC)
    ''');

    // Index for templates by category and usage
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_templates_category_usage
      ON local_templates(category, usage_count DESC)
      WHERE deleted = 0
    ''');

    // ============================================
    // 2.5. COVERING INDEXES FOR QUERY OPTIMIZATION
    // ============================================

    // Covering index for note_tags to avoid table lookups
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tags_covering
      ON note_tags(note_id, tag)
    ''');

    // Covering index for note_tasks with frequently accessed columns
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tasks_covering
      ON note_tasks(note_id, status, content, due_date, priority)
      WHERE deleted = 0
    ''');

    // Index for notes with folder relationship lookups
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_folder_lookup
      ON local_notes(id, title, updated_at)
      WHERE deleted = 0 AND note_type = 0
    ''');

    // Covering index for tag aggregation queries
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tags_aggregation
      ON note_tags(tag)
    ''');

    // Index for notes created date sorting (common query pattern)
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_created_at
      ON local_notes(created_at DESC)
      WHERE deleted = 0 AND note_type = 0
    ''');

    // ============================================
    // 3. ADDITIONAL CONSTRAINTS
    // ============================================

    // Add check constraints for enums (SQLite supports CHECK constraints)
    // Note: These would need table recreation in SQLite, so we'll validate in app code instead

    // Update database version
    await db.customStatement('''
      INSERT OR REPLACE INTO schema_versions (version, applied_at)
      VALUES ($version, CURRENT_TIMESTAMP)
    ''');
  }

  /// Rollback migration
  static Future<void> rollback(AppDb db) async {
    // Drop all indexes created by this migration
    await db.customStatement('DROP INDEX IF EXISTS idx_local_notes_pinned_updated');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_tags_note_tag');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_tasks_note_status');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_reminders_note_active');
    await db.customStatement('DROP INDEX IF EXISTS idx_local_folders_parent_sort');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_folders_folder_note');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_tasks_open_due');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_reminders_active_time');
    await db.customStatement('DROP INDEX IF EXISTS idx_saved_searches_usage');
    await db.customStatement('DROP INDEX IF EXISTS idx_local_templates_category_usage');

    // Drop covering indexes
    await db.customStatement('DROP INDEX IF EXISTS idx_note_tags_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_note_tasks_covering');
    await db.customStatement('DROP INDEX IF EXISTS idx_notes_folder_lookup');
    await db.customStatement('DROP INDEX IF EXISTS idx_tags_aggregation');
    await db.customStatement('DROP INDEX IF EXISTS idx_notes_created_at');

    // Note: Foreign key constraints cannot be easily rolled back in SQLite
    // Would need to recreate tables without constraints

    // Update database version
    await db.customStatement('''
      DELETE FROM schema_versions WHERE version = $version
    ''');
  }

  // ============================================
  // FOREIGN KEY HELPER FUNCTIONS
  // ============================================

  static Future<void> _addForeignKeyToNoteTags(AppDb db) async {
    // Create new table with foreign key
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS note_tags_new (
        note_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (note_id, tag),
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE
      )
    ''');

    // Copy data
    await db.customStatement('''
      INSERT OR IGNORE INTO note_tags_new
      SELECT * FROM note_tags
      WHERE note_id IN (SELECT id FROM local_notes)
    ''');

    // Replace old table
    await db.customStatement('DROP TABLE IF EXISTS note_tags');
    await db.customStatement('ALTER TABLE note_tags_new RENAME TO note_tags');
  }

  static Future<void> _addForeignKeyToNoteLinks(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS note_links_new (
        source_id TEXT NOT NULL,
        target_title TEXT NOT NULL,
        target_id TEXT,
        PRIMARY KEY (source_id, target_title),
        FOREIGN KEY (source_id) REFERENCES local_notes(id) ON DELETE CASCADE,
        FOREIGN KEY (target_id) REFERENCES local_notes(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      INSERT OR IGNORE INTO note_links_new
      SELECT * FROM note_links
      WHERE source_id IN (SELECT id FROM local_notes)
    ''');

    await db.customStatement('DROP TABLE IF EXISTS note_links');
    await db.customStatement('ALTER TABLE note_links_new RENAME TO note_links');
  }

  static Future<void> _addForeignKeyToNoteReminders(AppDb db) async {
    // Note: We keep the auto-increment ID, just add foreign key for note_id
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS note_reminders_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        title TEXT DEFAULT '',
        body TEXT DEFAULT '',
        type INTEGER NOT NULL,
        remind_at TEXT,
        is_active INTEGER DEFAULT 1,
        latitude REAL,
        longitude REAL,
        radius REAL,
        location_name TEXT,
        recurrence_pattern INTEGER DEFAULT 0,
        recurrence_end_date TEXT,
        recurrence_interval INTEGER DEFAULT 1,
        snoozed_until TEXT,
        snooze_count INTEGER DEFAULT 0,
        notification_title TEXT,
        notification_body TEXT,
        notification_image TEXT,
        time_zone TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_triggered TEXT,
        trigger_count INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      INSERT OR IGNORE INTO note_reminders_new
      SELECT * FROM note_reminders
      WHERE note_id IN (SELECT id FROM local_notes)
    ''');

    await db.customStatement('DROP TABLE IF EXISTS note_reminders');
    await db.customStatement('ALTER TABLE note_reminders_new RENAME TO note_reminders');
  }

  static Future<void> _addForeignKeyToNoteTasks(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS note_tasks_new (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        content TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 1,
        due_date TEXT,
        completed_at TEXT,
        completed_by TEXT,
        position INTEGER DEFAULT 0,
        content_hash TEXT NOT NULL,
        reminder_id INTEGER,
        labels TEXT,
        notes TEXT,
        estimated_minutes INTEGER,
        actual_minutes INTEGER,
        parent_task_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE,
        FOREIGN KEY (parent_task_id) REFERENCES note_tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (reminder_id) REFERENCES note_reminders(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      INSERT OR IGNORE INTO note_tasks_new
      SELECT * FROM note_tasks
      WHERE note_id IN (SELECT id FROM local_notes)
    ''');

    await db.customStatement('DROP TABLE IF EXISTS note_tasks');
    await db.customStatement('ALTER TABLE note_tasks_new RENAME TO note_tasks');
  }

  static Future<void> _addForeignKeyToNoteFolders(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS note_folders_new (
        note_id TEXT NOT NULL,
        folder_id TEXT NOT NULL,
        added_at TEXT NOT NULL,
        PRIMARY KEY (note_id),
        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE,
        FOREIGN KEY (folder_id) REFERENCES local_folders(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      INSERT OR IGNORE INTO note_folders_new
      SELECT * FROM note_folders
      WHERE note_id IN (SELECT id FROM local_notes)
        AND folder_id IN (SELECT id FROM local_folders)
    ''');

    await db.customStatement('DROP TABLE IF EXISTS note_folders');
    await db.customStatement('ALTER TABLE note_folders_new RENAME TO note_folders');
  }

  static Future<void> _addForeignKeyToLocalFolders(AppDb db) async {
    // Self-referencing foreign key for parent_id
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS local_folders_new (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        path TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        color TEXT,
        icon TEXT,
        description TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES local_folders(id) ON DELETE CASCADE
      )
    ''');

    // Copy data - need to handle parent relationships carefully
    // First insert root folders (no parent)
    await db.customStatement('''
      INSERT OR IGNORE INTO local_folders_new
      SELECT * FROM local_folders
      WHERE parent_id IS NULL
    ''');

    // Then insert child folders
    await db.customStatement('''
      INSERT OR IGNORE INTO local_folders_new
      SELECT * FROM local_folders
      WHERE parent_id IS NOT NULL
        AND parent_id IN (SELECT id FROM local_folders_new)
    ''');

    await db.customStatement('DROP TABLE IF EXISTS local_folders');
    await db.customStatement('ALTER TABLE local_folders_new RENAME TO local_folders');
  }

  // ============================================
  // IDEMPOTENT HELPER FUNCTIONS
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
      // Check for existence of our signature index
      final result = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='index' AND name='idx_local_notes_pinned_updated'
      ''').getSingleOrNull();

      return result != null;
    } catch (e) {
      // If we can't check, assume migration not applied
      return false;
    }
  }

  /// Check if table has foreign key constraints
  static Future<bool> _tableHasForeignKeys(AppDb db, String tableName) async {
    try {
      final result = await db.customSelect('''
        PRAGMA foreign_key_list($tableName)
      ''').get();

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Safe versions of foreign key functions (idempotent)
  static Future<void> _addForeignKeyToNoteTagsSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'note_tags');
    if (!hasForeignKeys) {
      await _addForeignKeyToNoteTags(db);
    }
  }

  static Future<void> _addForeignKeyToNoteLinksSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'note_links');
    if (!hasForeignKeys) {
      await _addForeignKeyToNoteLinks(db);
    }
  }

  static Future<void> _addForeignKeyToNoteRemindersSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'note_reminders');
    if (!hasForeignKeys) {
      await _addForeignKeyToNoteReminders(db);
    }
  }

  static Future<void> _addForeignKeyToNoteTasksSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'note_tasks');
    if (!hasForeignKeys) {
      await _addForeignKeyToNoteTasks(db);
    }
  }

  static Future<void> _addForeignKeyToNoteFoldersSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'note_folders');
    if (!hasForeignKeys) {
      await _addForeignKeyToNoteFolders(db);
    }
  }

  static Future<void> _addForeignKeyToLocalFoldersSafe(AppDb db) async {
    final hasForeignKeys = await _tableHasForeignKeys(db, 'local_folders');
    if (!hasForeignKeys) {
      await _addForeignKeyToLocalFolders(db);
    }
  }
}