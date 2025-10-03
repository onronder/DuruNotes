import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 20: Complete Schema Synchronization with Supabase
///
/// This migration brings local SQLite database to full parity with remote Supabase schema.
/// Following production standards and best practices:
/// - All 35 tables from remote
/// - Proper indexes for performance
/// - Foreign key constraints
/// - Consistent naming conventions
/// - Security and audit tables
/// - Notification system tables
class Migration20CompleteSchemaSync {
  static const int version = 20;
  static const String description = 'Complete schema synchronization with Supabase';

  static Future<void> apply(AppDb db) async {
    final logger = LoggerFactory.instance;
    logger.info('Starting Migration 20: Complete Schema Synchronization');

    try {
      // ============================================
      // PHASE 1: CORE USER AND SECURITY TABLES
      // ============================================

      // 1. profiles table (user settings)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS profiles (
          user_id TEXT PRIMARY KEY,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          settings TEXT
        )
      ''');

      // 2. user_keys table (encryption keys)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS user_keys (
          user_id TEXT PRIMARY KEY,
          kdf TEXT NOT NULL,
          kdf_params TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          wrapped_key TEXT
        )
      ''');

      // 3. user_sessions table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS user_sessions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          session_id TEXT NOT NULL,
          device_fingerprint TEXT,
          ip_address TEXT,
          user_agent TEXT,
          is_active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          last_activity TIMESTAMP
        )
      ''');

      // 4. user_devices table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS user_devices (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          push_token TEXT,
          platform TEXT,
          app_version TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 5. devices table (legacy compatibility)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS devices (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          platform TEXT,
          model TEXT,
          app_version TEXT,
          registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          last_sync_at TIMESTAMP
        )
      ''');

      // ============================================
      // PHASE 2: SECURITY AND AUDIT TABLES
      // ============================================

      // 6. security_events table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS security_events (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          event_type TEXT NOT NULL,
          severity TEXT NOT NULL,
          description TEXT,
          metadata TEXT,
          ip_address TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 7. login_attempts table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS login_attempts (
          id TEXT PRIMARY KEY,
          email TEXT NOT NULL,
          success BOOLEAN NOT NULL,
          error_message TEXT,
          attempt_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          ip_address TEXT,
          user_agent TEXT
        )
      ''');

      // 8. password_history table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS password_history (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 9. rate_limits table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS rate_limits (
          key TEXT PRIMARY KEY,
          count INTEGER NOT NULL DEFAULT 0,
          window_start TIMESTAMP NOT NULL,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 10. rate_limit_log table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS rate_limit_log (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          operation TEXT NOT NULL,
          ip_address TEXT,
          user_agent TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // ============================================
      // PHASE 3: NOTE STRUCTURE TABLES
      // ============================================

      // 11. note_blocks table (block-based content)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS note_blocks (
          id TEXT PRIMARY KEY,
          note_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          idx INTEGER NOT NULL,
          type TEXT NOT NULL,
          content_enc TEXT,
          attrs_enc TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE
        )
      ''');

      // 12. tags table (separate from notes)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS tags (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name_enc TEXT NOT NULL,
          color TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 13. tasks table (separate task entities)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS tasks (
          id TEXT PRIMARY KEY,
          note_id TEXT,
          user_id TEXT NOT NULL,
          text_enc TEXT NOT NULL,
          due_at_enc TEXT,
          repeat_enc TEXT,
          priority INTEGER DEFAULT 0,
          done BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // ============================================
      // PHASE 4: NOTIFICATION SYSTEM
      // ============================================

      // 14. notification_events table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_events (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          event_source TEXT,
          priority TEXT,
          payload TEXT,
          scheduled_for TIMESTAMP,
          processed_at TIMESTAMP,
          status TEXT,
          retry_count INTEGER DEFAULT 0,
          max_retries INTEGER DEFAULT 3,
          dedupe_key TEXT,
          error_message TEXT,
          error_details TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 15. notification_deliveries table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_deliveries (
          id TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          channel TEXT NOT NULL,
          device_id TEXT,
          status TEXT,
          provider_response TEXT,
          provider_message_id TEXT,
          sent_at TIMESTAMP,
          delivered_at TIMESTAMP,
          opened_at TIMESTAMP,
          clicked_at TIMESTAMP,
          failed_at TIMESTAMP,
          error_code TEXT,
          error_message TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (event_id) REFERENCES notification_events(id) ON DELETE CASCADE
        )
      ''');

      // 16. notification_preferences table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_preferences (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL UNIQUE,
          enabled BOOLEAN DEFAULT TRUE,
          push_enabled BOOLEAN DEFAULT TRUE,
          email_enabled BOOLEAN DEFAULT TRUE,
          sms_enabled BOOLEAN DEFAULT FALSE,
          in_app_enabled BOOLEAN DEFAULT TRUE,
          event_preferences TEXT,
          quiet_hours_enabled BOOLEAN DEFAULT FALSE,
          quiet_hours_start TEXT,
          quiet_hours_end TEXT,
          timezone TEXT,
          dnd_enabled BOOLEAN DEFAULT FALSE,
          dnd_until TIMESTAMP,
          batch_emails BOOLEAN DEFAULT FALSE,
          batch_frequency TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 17. notification_templates table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_templates (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL UNIQUE,
          push_template TEXT,
          email_template TEXT,
          sms_template TEXT,
          enabled BOOLEAN DEFAULT TRUE,
          priority TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 18. notification_stats table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_stats (
          user_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          event_source TEXT,
          date DATE NOT NULL,
          events_created INTEGER DEFAULT 0,
          events_delivered INTEGER DEFAULT 0,
          events_failed INTEGER DEFAULT 0,
          deliveries_attempted INTEGER DEFAULT 0,
          deliveries_successful INTEGER DEFAULT 0,
          avg_delivery_time_seconds REAL,
          PRIMARY KEY (user_id, event_type, date)
        )
      ''');

      // 19. notification_analytics table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_analytics (
          id TEXT PRIMARY KEY,
          date DATE NOT NULL UNIQUE,
          metrics TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 20. notification_health_checks table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_health_checks (
          id TEXT PRIMARY KEY,
          check_time TIMESTAMP NOT NULL,
          pending_count INTEGER,
          processing_count INTEGER,
          stuck_count INTEGER,
          oldest_pending TIMESTAMP,
          is_healthy BOOLEAN,
          details TEXT
        )
      ''');

      // 21. notification_cron_jobs table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS notification_cron_jobs (
          jobname TEXT NOT NULL,
          schedule TEXT NOT NULL,
          command TEXT NOT NULL,
          nodename TEXT,
          nodeport INTEGER,
          database TEXT,
          username TEXT,
          active BOOLEAN DEFAULT TRUE,
          PRIMARY KEY (jobname, nodename, nodeport, database, username)
        )
      ''');

      // ============================================
      // PHASE 5: ANALYTICS AND MONITORING
      // ============================================

      // 22. analytics_events table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS analytics_events (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          event_type TEXT NOT NULL,
          properties TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 23. index_statistics table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS index_statistics (
          id TEXT PRIMARY KEY,
          index_name TEXT NOT NULL,
          table_name TEXT NOT NULL,
          index_size INTEGER,
          number_of_scans INTEGER DEFAULT 0,
          rows_read INTEGER DEFAULT 0,
          rows_fetched INTEGER DEFAULT 0,
          last_used TIMESTAMP,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // ============================================
      // PHASE 6: INBOX AND CLIPPER TABLES
      // ============================================

      // 24. clipper_inbox table (rename/recreate from local_inbox_items)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS clipper_inbox (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          source_type TEXT,
          title TEXT,
          content TEXT,
          html TEXT,
          metadata TEXT,
          message_id TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          converted_to_note_id TEXT,
          converted_at TIMESTAMP,
          payload_json TEXT
        )
      ''');

      // 25. inbound_aliases table
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS inbound_aliases (
          user_id TEXT NOT NULL,
          alias TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (user_id, alias)
        )
      ''');

      // 26. inbox_items_view (create as table, not view for SQLite)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS inbox_items_view (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          source_type TEXT,
          title TEXT,
          content TEXT,
          html TEXT,
          metadata TEXT,
          message_id TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          converted_to_note_id TEXT,
          converted_at TIMESTAMP,
          is_converted BOOLEAN DEFAULT FALSE,
          display_title TEXT
        )
      ''');

      // ============================================
      // PHASE 7: RENAME EXISTING TABLES TO MATCH REMOTE
      // ============================================

      // Map local tables to remote names
      await _renameTablesIfNeeded(db);

      // ============================================
      // PHASE 7.5: ADD MISSING COLUMNS TO EXISTING TABLES
      // ============================================

      // Add missing columns to renamed tables
      await _addMissingColumns(db);

      // ============================================
      // PHASE 8: CREATE CRITICAL INDEXES
      // ============================================

      // User-based queries - only create if columns exist (FIXED: Use correct table names)
      await _createIndexSafely(db, 'idx_local_notes_user_id', 'local_notes', 'user_id');
      await _createIndexSafely(db, 'idx_local_folders_user_id', 'local_folders', 'user_id');
      await _createIndexSafely(db, 'idx_local_templates_user_id', 'local_templates', 'user_id');
      await _createIndexSafely(db, 'idx_tags_user_id', 'tags', 'user_id');
      await _createIndexSafely(db, 'idx_local_attachments_user_id', 'local_attachments', 'user_id');

      // Performance indexes - only create if columns exist (FIXED: Use correct table names)
      if (await _columnExists(db, 'local_notes', 'updated_at')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_local_notes_updated_at ON local_notes(updated_at DESC)');
      }
      if (await _columnExists(db, 'local_notes', 'created_at')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_local_notes_created_at ON local_notes(created_at DESC)');
      }
      if (await _columnExists(db, 'local_notes', 'deleted')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_local_notes_deleted ON local_notes(deleted)');
      }
      if (await _columnExists(db, 'local_notes', 'is_pinned')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_local_notes_pinned ON local_notes(is_pinned)');
      }

      // Relationship indexes - check tables and columns exist
      if (await _tableExists(db, 'note_tags')) {
        // The NoteTags table has 'noteId' and 'tag' columns
        if (await _columnExists(db, 'note_tags', 'noteId')) {
          await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_tags_note_id ON note_tags(noteId)');
        }
        if (await _columnExists(db, 'note_tags', 'tag')) {
          await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag)');
        }
      }
      if (await _tableExists(db, 'note_folders')) {
        // The NoteFolders table has 'noteId' and 'folderId' columns
        if (await _columnExists(db, 'note_folders', 'noteId')) {
          await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_folders_note_id ON note_folders(noteId)');
        }
        if (await _columnExists(db, 'note_folders', 'folderId')) {
          await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_folders_folder_id ON note_folders(folderId)');
        }
      }
      if (await _tableExists(db, 'note_blocks')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_blocks_note_id ON note_blocks(note_id)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_note_blocks_idx ON note_blocks(note_id, idx)');
      }

      // Notification indexes - check tables exist
      if (await _tableExists(db, 'notification_events')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_notif_events_user_id ON notification_events(user_id)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_notif_events_status ON notification_events(status)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_notif_events_scheduled ON notification_events(scheduled_for)');
      }
      if (await _tableExists(db, 'notification_deliveries')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_notif_deliveries_event_id ON notification_deliveries(event_id)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_notif_deliveries_user_id ON notification_deliveries(user_id)');
      }

      // Security indexes - check tables exist
      if (await _tableExists(db, 'security_events')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON security_events(user_id)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at DESC)');
      }
      if (await _tableExists(db, 'login_attempts')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_login_attempts_email ON login_attempts(email)');
      }
      if (await _tableExists(db, 'user_sessions')) {
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active)');
      }

      // ============================================
      // PHASE 9: RECORD MIGRATION
      // ============================================

      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');

      logger.info('Migration 20 completed successfully - Full schema sync achieved');

    } catch (e, stack) {
      logger.error('Failed to apply Migration 20: $e\nStack: $stack');
      rethrow;
    }
  }

  static Future<void> _renameTablesIfNeeded(AppDb db) async {
    // CRITICAL FIX: Do NOT rename core app tables!
    //
    // The Drift schema expects tables named:
    // - local_notes (not notes)
    // - local_folders (not folders)
    // - local_templates (not templates)
    // - local_attachments (not attachments)
    //
    // Renaming these breaks all app queries. Instead, we:
    // 1. Keep existing table names that the app expects
    // 2. Create additional new tables for new functionality
    // 3. Ensure backward compatibility

    final logger = LoggerFactory.instance;
    logger.info('Skipping table renaming to maintain app compatibility');

    // Check if tables exist
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'"
    ).get();

    final tableNames = tables.map((t) => t.read<String>('name')).toSet();
    logger.info('Existing tables: ${tableNames.join(', ')}');

    // Only log what we found - no renaming
    if (tableNames.contains('local_notes')) {
      logger.info('✓ local_notes table exists (keeping as-is)');
    }
    if (tableNames.contains('local_folders')) {
      logger.info('✓ local_folders table exists (keeping as-is)');
    }
    if (tableNames.contains('local_templates')) {
      logger.info('✓ local_templates table exists (keeping as-is)');
    }
    if (tableNames.contains('local_attachments')) {
      logger.info('✓ local_attachments table exists (keeping as-is)');
    }
  }

  /// Add missing columns to existing tables
  static Future<void> _addMissingColumns(AppDb db) async {
    // FIXED: Use correct table names that the app expects

    // Add user_id to local_notes if it doesn't exist
    if (!await _columnExists(db, 'local_notes', 'user_id')) {
      await db.customStatement('ALTER TABLE local_notes ADD COLUMN user_id TEXT');
    }

    // Add user_id to local_folders if it doesn't exist
    if (!await _columnExists(db, 'local_folders', 'user_id')) {
      await db.customStatement('ALTER TABLE local_folders ADD COLUMN user_id TEXT');
    }

    // Add user_id to local_templates if it doesn't exist
    if (!await _columnExists(db, 'local_templates', 'user_id')) {
      await db.customStatement('ALTER TABLE local_templates ADD COLUMN user_id TEXT');
    }

    // Add user_id to local_attachments if it doesn't exist
    if (!await _columnExists(db, 'local_attachments', 'user_id')) {
      await db.customStatement('ALTER TABLE local_attachments ADD COLUMN user_id TEXT');
    }

    // Add missing columns to local_templates
    if (!await _columnExists(db, 'local_templates', 'is_system')) {
      await db.customStatement('ALTER TABLE local_templates ADD COLUMN is_system BOOLEAN DEFAULT FALSE');
    }
    if (!await _columnExists(db, 'local_templates', 'category')) {
      await db.customStatement('ALTER TABLE local_templates ADD COLUMN category TEXT');
    }
    if (!await _columnExists(db, 'local_templates', 'icon')) {
      await db.customStatement('ALTER TABLE local_templates ADD COLUMN icon TEXT');
    }

    // Add missing columns to local_attachments
    if (!await _columnExists(db, 'local_attachments', 'ocr_text_enc')) {
      await db.customStatement('ALTER TABLE local_attachments ADD COLUMN ocr_text_enc TEXT');
    }

    // Add missing columns to local_notes
    if (!await _columnExists(db, 'local_notes', 'encrypted_metadata')) {
      await db.customStatement('ALTER TABLE local_notes ADD COLUMN encrypted_metadata TEXT');
    }
    if (!await _columnExists(db, 'local_notes', 'note_type')) {
      await db.customStatement('ALTER TABLE local_notes ADD COLUMN note_type INTEGER DEFAULT 0');
    }
  }

  /// Check if a table exists
  static Future<bool> _tableExists(AppDb db, String table) async {
    try {
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'"
      ).getSingleOrNull();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if a column exists in a table
  static Future<bool> _columnExists(AppDb db, String table, String column) async {
    try {
      final result = await db.customSelect(
        "PRAGMA table_info('$table')"
      ).get();

      for (final row in result) {
        if (row.read<String>('name') == column) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Create an index safely, checking if the column exists first
  static Future<void> _createIndexSafely(AppDb db, String indexName, String table, String column) async {
    if (await _columnExists(db, table, column)) {
      await db.customStatement('CREATE INDEX IF NOT EXISTS $indexName ON $table($column)');
    }
  }

  /// Verify migration was successful
  static Future<bool> verify(AppDb db) async {
    try {
      // List of required tables (FIXED: Use correct table names the app expects)
      final requiredTables = [
        'local_notes', 'local_folders', 'local_templates', 'local_attachments', 'tags',
        'note_tags', 'note_folders', 'note_blocks', 'note_tasks',
        'profiles', 'user_keys', 'user_sessions', 'user_devices',
        'security_events', 'login_attempts', 'rate_limits',
        'notification_events', 'notification_preferences',
        'analytics_events', 'clipper_inbox'
      ];

      // Check each table exists
      for (final tableName in requiredTables) {
        final result = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'"
        ).get();

        if (result.isEmpty) {
          LoggerFactory.instance.error('Migration 20 verification failed: Table $tableName missing');
          return false;
        }
      }

      LoggerFactory.instance.info('Migration 20 verification passed - All tables present');
      return true;

    } catch (e) {
      LoggerFactory.instance.error('Migration 20 verification failed: $e');
      return false;
    }
  }
}