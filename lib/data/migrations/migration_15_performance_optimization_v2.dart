import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 15: Performance Optimization V2
///
/// This migration addresses critical performance bottlenecks:
/// 1. Missing composite indexes for high-frequency queries
/// 2. N+1 query elimination through better indexing
/// 3. Folder integrity operation optimization
/// 4. Search and filtering performance improvements
/// 5. Analytics and reporting query optimization
///
/// Performance target: &lt;50ms for critical path queries, &lt;100ms for complex operations
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
      // 1. MISSING CRITICAL COMPOSITE INDEXES
      // ============================================

      logger.info('Creating missing composite indexes...');

      // Multi-tenant folder queries with hierarchy optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_folders_user_parent_order
        ON local_folders(user_id, parent_id, sort_order)
        WHERE deleted = 0
      ''');

      // Note search with tag filtering optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_user_updated_pinned
        ON local_notes(user_id, updated_at DESC, is_pinned)
        WHERE deleted = 0
      ''');

      // Task due date optimization for active users
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_user_due_status
        ON note_tasks(user_id, due_date ASC, status)
        WHERE deleted = 0 AND due_date IS NOT NULL
      ''');

      // Template lookup optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_templates_system_category
        ON local_templates(is_system, category, sort_order)
      ''');

      // ============================================
      // 2. N+1 QUERY ELIMINATION INDEXES
      // ============================================

      logger.info('Creating N+1 query elimination indexes...');

      // Batch tag operations (critical for tag repository performance)
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_batch_lookup
        ON note_tags(note_id, tag)
      ''');

      // Tag popularity queries optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_popularity_user
        ON note_tags(tag, note_id)
      ''');

      // Batch attachment operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_attachments_batch_note
        ON local_attachments(note_id, uploaded_at DESC)
        WHERE deleted = 0
      ''');

      // Batch link operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_batch_source
        ON note_links(source_id, target_id, target_title)
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_batch_target
        ON note_links(target_id, source_id)
      ''');

      // ============================================
      // 3. FOLDER INTEGRITY OPERATION OPTIMIZATION
      // ============================================

      logger.info('Creating folder integrity operation indexes...');

      // Optimize folder existence checks for integrity operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_folders_existence_check
        ON local_folders(id, deleted)
        WHERE deleted = 0
      ''');

      // Optimize orphaned notes detection
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_folders_integrity
        ON note_folders(folder_id, note_id)
      ''');

      // ============================================
      // 4. SEARCH AND FILTERING OPTIMIZATION
      // ============================================

      logger.info('Creating search optimization indexes...');

      // Content search optimization for different note sizes
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_content_search
        ON local_notes(user_id, LENGTH(title), updated_at DESC)
        WHERE deleted = 0
      ''');

      // Saved search execution optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_searches_execution
        ON saved_searches(user_id, search_type, last_used_at DESC)
      ''');

      // ============================================
      // 5. NOTIFICATION AND REMINDER OPTIMIZATION
      // ============================================

      logger.info('Creating reminder processing indexes...');

      // Reminder processing optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reminders_processing
        ON note_reminders(is_active, remind_at ASC)
        WHERE is_active = 1 AND remind_at IS NOT NULL
      ''');

      // Snooze functionality optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reminders_snooze
        ON note_reminders(snoozed_until, is_active)
        WHERE is_active = 1 AND snoozed_until IS NOT NULL
      ''');

      // ============================================
      // 6. ANALYTICS AND REPORTING OPTIMIZATION
      // ============================================

      logger.info('Creating analytics indexes...');

      // User activity analytics
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_analytics
        ON local_notes(user_id, DATE(created_at), note_type)
        WHERE deleted = 0
      ''');

      // Task completion analytics
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_analytics
        ON note_tasks(user_id, DATE(completed_at), status)
        WHERE status = 1 AND completed_at IS NOT NULL
      ''');

      // ============================================
      // 7. MAINTENANCE AND CLEANUP OPTIMIZATION
      // ============================================

      logger.info('Creating cleanup operation indexes...');

      // Optimize deletion operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_cleanup
        ON local_notes(deleted, updated_at)
        WHERE deleted = 1
      ''');

      // Optimize task cleanup operations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_cleanup
        ON note_tasks(deleted, updated_at)
        WHERE deleted = 1
      ''');

      // ============================================
      // 8. SQLITE PERFORMANCE OPTIMIZATION
      // ============================================

      logger.info('Applying SQLite performance settings...');

      // Optimize SQLite settings for performance
      await db.customStatement('PRAGMA optimize');
      await db.customStatement('PRAGMA analysis_limit = 1000');
      await db.customStatement('PRAGMA cache_size = -64000'); // 64MB cache
      await db.customStatement('PRAGMA journal_mode = WAL');
      await db.customStatement('PRAGMA synchronous = NORMAL');
      await db.customStatement('PRAGMA temp_store = MEMORY');
      await db.customStatement('PRAGMA mmap_size = 268435456'); // 256MB

      // ============================================
      // 9. UPDATE STATISTICS
      // ============================================

      logger.info('Updating table statistics...');

      // Force SQLite to update statistics for query planner
      await db.customStatement('ANALYZE local_notes');
      await db.customStatement('ANALYZE note_tags');
      await db.customStatement('ANALYZE note_tasks');
      await db.customStatement('ANALYZE note_reminders');
      await db.customStatement('ANALYZE local_folders');
      await db.customStatement('ANALYZE note_folders');
      await db.customStatement('ANALYZE saved_searches');
      await db.customStatement('ANALYZE local_templates');
      await db.customStatement('ANALYZE local_attachments');
      await db.customStatement('ANALYZE local_inbox_items');

      // ============================================
      // 10. RECORD MIGRATION SUCCESS
      // ============================================

      await db.customStatement('''
        INSERT INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');

      logger.info('Migration 15 completed successfully');
      logger.info(
        'Applied ${_getIndexCount()} performance optimization indexes',
      );
    } catch (e, stackTrace) {
      logger.error('Migration 15 failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Ensure schema_versions table exists
  static Future<void> _ensureSchemaVersionsTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS schema_versions (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
  }

  /// Check if migration is already applied
  static Future<bool> _isMigrationAlreadyApplied(AppDb db) async {
    try {
      final result = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM schema_versions WHERE version = ?',
            variables: [Variable.withInt(version)],
          )
          .getSingleOrNull();

      return (result?.read<int>('count') ?? 0) > 0;
    } catch (e) {
      // Table might not exist yet
      return false;
    }
  }

  /// Update migration timestamp
  static Future<void> _updateMigrationTimestamp(AppDb db) async {
    await db.customStatement('''
      UPDATE schema_versions
      SET applied_at = CURRENT_TIMESTAMP
      WHERE version = $version
    ''');
  }

  /// Get count of created indexes (for logging)
  static int _getIndexCount() => 20; // Approximate number of indexes created

  /// Validate migration success
  static Future<bool> validateMigration(AppDb db) async {
    try {
      // Check that critical indexes exist
      final criticalIndexes = [
        'idx_folders_user_parent_order',
        'idx_notes_user_updated_pinned',
        'idx_tasks_user_due_status',
        'idx_tags_batch_lookup',
        'idx_attachments_batch_note',
      ];

      for (final indexName in criticalIndexes) {
        final result = await db
            .customSelect(
              '''
          SELECT COUNT(*) as count
          FROM sqlite_master
          WHERE type = 'index' AND name = ?
        ''',
              variables: [Variable.withString(indexName)],
            )
            .getSingleOrNull();

        if ((result?.read<int>('count') ?? 0) == 0) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get migration performance report
  static Future<Map<String, dynamic>> getPerformanceReport(AppDb db) async {
    try {
      // Count total indexes
      final indexResult = await db.customSelect('''
        SELECT COUNT(*) as count
        FROM sqlite_master
        WHERE type = 'index' AND name LIKE 'idx_%'
      ''').getSingleOrNull();

      // Get database page count and size
      final pageResult = await db
          .customSelect('PRAGMA page_count')
          .getSingleOrNull();
      final pageSizeResult = await db
          .customSelect('PRAGMA page_size')
          .getSingleOrNull();

      final pageCount = pageResult?.read<int>('page_count') ?? 0;
      final pageSize = pageSizeResult?.read<int>('page_size') ?? 4096;
      final dbSize = pageCount * pageSize;

      return {
        'migration_version': version,
        'total_indexes': indexResult?.read<int>('count') ?? 0,
        'database_size_mb': (dbSize / 1024 / 1024).toStringAsFixed(2),
        'page_count': pageCount,
        'page_size': pageSize,
        'optimization_complete': true,
      };
    } catch (e) {
      return {
        'migration_version': version,
        'error': e.toString(),
        'optimization_complete': false,
      };
    }
  }
}
