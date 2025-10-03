import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 22: Production-Grade Performance Optimization
///
/// This migration adds comprehensive indexes and optimizations
/// for production performance following best practices:
/// - Composite indexes for complex queries
/// - Covering indexes to reduce I/O
/// - Partial indexes for filtered queries
/// - Statistics updates for query planner
class Migration22ProductionOptimization {
  static const int version = 22;
  static const String description = 'Production-grade performance optimization';

  static Future<void> apply(AppDb db) async {
    final logger = LoggerFactory.instance;
    logger.info('Starting Migration 22: Production Performance Optimization');

    try {
      // ============================================
      // PHASE 1: COMPOSITE INDEXES FOR NOTES
      // ============================================
      logger.info('Creating composite indexes for notes...');

      // Most common query pattern: user's notes ordered by update time
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_user_updated
        ON local_notes(user_id, updated_at DESC, deleted)
        WHERE deleted = 0
      ''');

      // Pinned notes optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_user_pinned
        ON local_notes(user_id, is_pinned DESC, updated_at DESC)
        WHERE deleted = 0 AND is_pinned = 1
      ''');

      // Sync optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_sync_status
        ON local_notes(sync_status, updated_at DESC)
        WHERE deleted = 0 AND sync_status != 1
      ''');

      // Full-text search optimization
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_search
        ON local_notes(user_id, title, body)
        WHERE deleted = 0 AND note_type = 0
      ''');

      // ============================================
      // PHASE 2: TASK PERFORMANCE INDEXES
      // ============================================
      logger.info('Creating task performance indexes...');

      // Tasks by note with status
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_note_status
        ON note_tasks(note_id, status, position)
        WHERE deleted = 0
      ''');

      // Open tasks by due date
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_due_open
        ON note_tasks(due_date ASC, status)
        WHERE deleted = 0 AND status = 0 AND due_date IS NOT NULL
      ''');

      // Subtasks hierarchy
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_hierarchy
        ON note_tasks(parent_task_id, position, status)
        WHERE deleted = 0 AND parent_task_id IS NOT NULL
      ''');

      // Task priority queue
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tasks_priority_queue
        ON note_tasks(priority DESC, due_date ASC, created_at ASC)
        WHERE deleted = 0 AND status = 0
      ''');

      // ============================================
      // PHASE 3: FOLDER HIERARCHY OPTIMIZATION
      // ============================================
      logger.info('Creating folder hierarchy indexes...');

      // Folder tree navigation
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_folders_tree
        ON local_folders(user_id, parent_id, sort_order, path)
        WHERE deleted = 0
      ''');

      // Root folders fast access
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_folders_roots
        ON local_folders(user_id, sort_order)
        WHERE deleted = 0 AND parent_id IS NULL
      ''');

      // Note-folder associations
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_folders_bidirectional
        ON note_folders(folder_id, note_id)
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_folders_reverse
        ON note_folders(note_id, folder_id)
      ''');

      // ============================================
      // PHASE 4: TAG SYSTEM OPTIMIZATION
      // ============================================
      logger.info('Creating tag system indexes...');

      // Tag popularity and autocomplete
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_popularity
        ON note_tags(tag COLLATE NOCASE, note_id)
      ''');

      // Notes by tag (covering index)
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_tags_covering
        ON note_tags(tag, note_id, id)
      ''');

      // Tag co-occurrence analysis
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_tags_cooccurrence
        ON note_tags(note_id, tag)
      ''');

      // ============================================
      // PHASE 5: REMINDER & NOTIFICATION INDEXES
      // ============================================
      logger.info('Creating reminder system indexes...');

      // Active reminders
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reminders_active
        ON note_reminders(remind_at ASC, is_completed)
        WHERE is_completed = 0 AND remind_at > datetime('now')
      ''');

      // Overdue reminders
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reminders_overdue
        ON note_reminders(remind_at ASC, is_completed, note_id)
        WHERE is_completed = 0 AND remind_at <= datetime('now')
      ''');

      // ============================================
      // PHASE 6: SEARCH & SAVED SEARCHES
      // ============================================
      logger.info('Creating search optimization indexes...');

      // Saved searches by frequency
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_searches_frequency
        ON saved_searches(user_id, use_count DESC, updated_at DESC)
      ''');

      // Search by type
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_searches_type
        ON saved_searches(user_id, search_type, updated_at DESC)
      ''');

      // ============================================
      // PHASE 7: ATTACHMENT OPTIMIZATION
      // ============================================
      logger.info('Creating attachment indexes...');

      // Attachments by note
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_attachments_note
        ON local_attachments(note_id, uploaded_at DESC)
      ''');

      // Large attachments tracking
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_attachments_size
        ON local_attachments(file_size DESC)
        WHERE file_size > 1048576
      ''');

      // ============================================
      // PHASE 8: LINK GRAPH OPTIMIZATION
      // ============================================
      logger.info('Creating link graph indexes...');

      // Bidirectional link traversal
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_bidirectional
        ON note_links(source_id, target_id, link_type)
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_links_reverse
        ON note_links(target_id, source_id, link_type)
      ''');

      // ============================================
      // PHASE 9: AUDIT & MONITORING
      // ============================================
      logger.info('Creating audit trail indexes...');

      // Audit log by user and time
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_audit_user_time
        ON schema_versions(version, applied_at DESC)
      ''');

      // ============================================
      // PHASE 10: QUERY OPTIMIZATION HINTS
      // ============================================
      logger.info('Adding query optimization hints...');

      // Create triggers for automatic updated_at
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS update_note_timestamp
        AFTER UPDATE ON local_notes
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
          UPDATE local_notes
          SET updated_at = datetime('now')
          WHERE id = NEW.id;
        END
      ''');

      // Create trigger for task completion tracking
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS track_task_completion
        AFTER UPDATE ON note_tasks
        FOR EACH ROW
        WHEN OLD.status != 2 AND NEW.status = 2
        BEGIN
          UPDATE note_tasks
          SET completed_at = datetime('now')
          WHERE id = NEW.id;
        END
      ''');

      // ============================================
      // PHASE 11: STATISTICS UPDATE
      // ============================================
      logger.info('Updating database statistics...');

      // Analyze all tables for query planner
      await db.customStatement('ANALYZE local_notes');
      await db.customStatement('ANALYZE note_tasks');
      await db.customStatement('ANALYZE local_folders');
      await db.customStatement('ANALYZE note_tags');
      await db.customStatement('ANALYZE note_folders');
      await db.customStatement('ANALYZE note_reminders');
      await db.customStatement('ANALYZE local_attachments');
      await db.customStatement('ANALYZE saved_searches');

      // ============================================
      // PHASE 12: PERFORMANCE SETTINGS
      // ============================================
      logger.info('Applying performance settings...');

      // Optimize SQLite settings for performance
      await db.customStatement('PRAGMA journal_mode = WAL');
      await db.customStatement('PRAGMA synchronous = NORMAL');
      await db.customStatement('PRAGMA cache_size = -64000'); // 64MB cache
      await db.customStatement('PRAGMA temp_store = MEMORY');
      await db.customStatement('PRAGMA mmap_size = 268435456'); // 256MB mmap

      // ============================================
      // PHASE 13: RECORD MIGRATION
      // ============================================
      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');

      logger.info('Migration 22 completed successfully - Production optimizations applied');

      // Log index statistics
      final indexCount = await db.customSelect(
        "SELECT COUNT(*) as count FROM sqlite_master WHERE type='index'"
      ).getSingle();

      logger.info('Database optimization complete', data: {
        'total_indexes': indexCount.read<int>('count'),
        'migration_version': version,
      });

    } catch (e, stack) {
      logger.error('Failed to apply Migration 22: $e\nStack: $stack');
      // Don't rethrow - allow app to continue but log the issue
      logger.warning('Continuing without full optimizations - performance may be impacted');
    }
  }

  /// Verify migration was successful
  static Future<bool> verify(AppDb db) async {
    try {
      // Check critical indexes exist
      final criticalIndexes = [
        'idx_notes_user_updated',
        'idx_tasks_note_status',
        'idx_folders_tree',
        'idx_note_tags_covering',
      ];

      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index'"
      ).get();

      final indexNames = indexes.map((i) => i.read<String>('name')).toSet();

      for (final required in criticalIndexes) {
        if (!indexNames.contains(required)) {
          LoggerFactory.instance.warning('Missing critical index: $required');
          return false;
        }
      }

      LoggerFactory.instance.info('Migration 22 verification passed - All critical indexes present');
      return true;

    } catch (e) {
      LoggerFactory.instance.error('Migration 22 verification failed: $e');
      return false;
    }
  }
}