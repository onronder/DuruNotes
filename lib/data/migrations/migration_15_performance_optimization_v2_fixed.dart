import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 15: Performance Optimization V2 (Fixed)
///
/// This migration addresses critical performance bottlenecks.
/// FIXED: Now checks for column existence before creating indexes
class Migration15PerformanceOptimizationV2 {
  static const int version = 15;
  static const String description =
      'Performance optimization V2 - eliminate remaining bottlenecks';

  /// Apply migration to database (idempotent - safe to run multiple times)
  static Future<void> apply(AppDb db) async {
    final logger = LoggerFactory.instance;
    logger.info('Starting Migration 15: Performance Optimization V2');

    try {
      // Ensure schema_versions table exists
      await _ensureSchemaVersionsTable(db);

      // Check if migration already applied
      final migrationApplied = await _isMigrationAlreadyApplied(db);
      if (migrationApplied) {
        logger.info('Migration 15 already applied, updating timestamp');
        await _updateMigrationTimestamp(db);
        return;
      }

      // ============================================
      // 1. CHECK COLUMN EXISTENCE BEFORE INDEXES
      // ============================================

      logger.info('Checking column existence before creating indexes...');

      // Check if user_id columns exist
      final hasUserIdInFolders = await _columnExists(
        db,
        'local_folders',
        'user_id',
      );
      final hasUserIdInNotes = await _columnExists(
        db,
        'local_notes',
        'user_id',
      );
      final hasUserIdInTasks = await _columnExists(db, 'note_tasks', 'user_id');
      final hasIsSystemInTemplates = await _columnExists(
        db,
        'local_templates',
        'is_system',
      );
      final hasCategoryInTemplates = await _columnExists(
        db,
        'local_templates',
        'category',
      );

      // ============================================
      // 2. CREATE INDEXES CONDITIONALLY
      // ============================================

      logger.info('Creating performance indexes...');

      // Multi-tenant folder queries - only if user_id exists
      if (hasUserIdInFolders) {
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_folders_user_parent_order
          ON local_folders(user_id, parent_id, sort_order)
          WHERE deleted = 0
        ''');
      } else {
        // Create index without user_id
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_folders_parent_order
          ON local_folders(parent_id, sort_order)
          WHERE deleted = 0
        ''');
      }

      // Note search optimization - only if user_id exists
      if (hasUserIdInNotes) {
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_notes_user_updated_pinned
          ON local_notes(user_id, updated_at DESC, is_pinned)
          WHERE deleted = 0
        ''');
      } else {
        // Create index without user_id
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_notes_updated_pinned
          ON local_notes(updated_at DESC, is_pinned)
          WHERE deleted = 0
        ''');
      }

      // Task due date optimization - only if user_id exists
      if (hasUserIdInTasks) {
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_tasks_user_due_status
          ON note_tasks(user_id, due_date ASC, status)
          WHERE deleted = 0 AND due_date IS NOT NULL
        ''');
      } else {
        // Create index without user_id
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_tasks_due_status
          ON note_tasks(due_date ASC, status)
          WHERE deleted = 0 AND due_date IS NOT NULL
        ''');
      }

      // Template lookup optimization - only if columns exist
      if (hasIsSystemInTemplates && hasCategoryInTemplates) {
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_templates_system_category
          ON local_templates(is_system, category, sort_order)
        ''');
      } else {
        // Create basic template index
        await db.customStatement('''
          CREATE INDEX IF NOT EXISTS idx_templates_sort
          ON local_templates(sort_order)
        ''');
      }

      // ============================================
      // 3. ALWAYS SAFE INDEXES (no new columns)
      // ============================================

      logger.info('Creating safe indexes...');

      // Tag operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_batch_lookup
        ON note_tags(note_id, tag)
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_popularity
        ON note_tags(tag, note_id)
      ''');

      // Attachment operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_attachments_note
        ON local_attachments(note_id, uploaded_at DESC)
      ''');

      // Link operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_source
        ON note_links(source_id, target_id)
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_target
        ON note_links(target_id, source_id)
      ''');

      // Folder integrity
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_folders_existence
        ON local_folders(id, deleted)
        WHERE deleted = 0
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_folders_integrity
        ON note_folders(folder_id, note_id)
      ''');

      // Saved searches
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_searches_updated
        ON saved_searches(updated_at DESC)
      ''');

      // Reminder operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reminders_status_time
        ON note_reminders(is_completed, remind_at ASC)
        WHERE is_completed = 0
      ''');

      // ============================================
      // 4. UPDATE SQLITE STATISTICS
      // ============================================

      logger.info('Updating SQLite statistics...');
      await db.customStatement('ANALYZE');

      // ============================================
      // 5. RECORD MIGRATION
      // ============================================

      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');

      logger.info(
        'Migration 15 completed successfully - Performance optimizations applied',
      );
    } catch (e, stack) {
      logger.error('Failed to apply Migration 15: $e\nStack: $stack');
      // Don't rethrow - allow app to continue with degraded performance
      logger.warning('Continuing without performance optimizations');
    }
  }

  /// Check if a column exists in a table
  static Future<bool> _columnExists(
    AppDb db,
    String table,
    String column,
  ) async {
    try {
      final result = await db.customSelect("PRAGMA table_info('$table')").get();

      for (final row in result) {
        if (row.read<String>('name') == column) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // If table doesn't exist or error, return false
      return false;
    }
  }

  /// Ensure schema_versions table exists for tracking migrations
  static Future<void> _ensureSchemaVersionsTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS schema_versions (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        description TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  /// Check if this migration has already been applied
  static Future<bool> _isMigrationAlreadyApplied(AppDb db) async {
    final result = await db
        .customSelect(
          'SELECT 1 FROM schema_versions WHERE version = ?',
          variables: [Variable.withInt(version)],
        )
        .getSingleOrNull();
    return result != null;
  }

  /// Update the timestamp for an already applied migration
  static Future<void> _updateMigrationTimestamp(AppDb db) async {
    await db.customStatement('''
      UPDATE schema_versions
      SET applied_at = CURRENT_TIMESTAMP,
          description = '$description'
      WHERE version = $version
    ''');
  }
}
