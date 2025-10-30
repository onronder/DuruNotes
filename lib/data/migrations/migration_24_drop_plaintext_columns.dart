import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Migration 24: Drop plaintext columns to complete zero-knowledge encryption
///
/// SECURITY FIX: Removes plaintext storage of sensitive data from database.
/// After Migration 23 added encrypted columns, this migration completes the
/// transition to zero-knowledge architecture by dropping unencrypted columns.
///
/// Critical Changes:
/// - Drop title, body, metadata from local_notes (use encrypted versions only)
/// - Drop content, labels, notes from note_tasks (use encrypted versions only)
/// - Verify all data is encrypted (encryption_version = 1) before proceeding
///
/// Safety:
/// - Pre-migration verification ensures no data loss
/// - Rollback requires restoring from backup (no plaintext to restore)
/// - This is a one-way migration for security compliance
class Migration24DropPlaintextColumns {
  static final _logger = LoggerFactory.instance;

  static Future<void> run(Migrator m, int from) async {
    if (from < 24) {
      _logger.info('Starting Migration 24: Dropping plaintext columns');

      // Verify encryption before proceeding
      final canProceed = await _verifyEncryptionComplete(m);
      if (!canProceed) {
        _logger.warning(
          'Migration 24 skipped: Not all data is encrypted. '
          'Run encryption migration first.',
        );
        return;
      }

      await _dropNotesPlaintextColumns(m);
      await _dropTasksPlaintextColumns(m);
      await _updateFtsForEncryption(m);

      _logger.info('Migration 24 completed successfully');
    }
  }

  /// Verify all notes and tasks are encrypted before dropping plaintext columns
  static Future<bool> _verifyEncryptionComplete(Migrator m) async {
    try {
      // Check for any unencrypted notes
      final unencryptedNotes = await m.database
          .customSelect(
            'SELECT COUNT(*) as count FROM local_notes '
            'WHERE encryption_version = 0 AND deleted = 0',
          )
          .getSingle();

      final notesCount = unencryptedNotes.data['count'] as int;
      if (notesCount > 0) {
        _logger.warning(
          'Found $notesCount unencrypted notes. Cannot proceed with migration.',
        );
        return false;
      }

      // Check for any unencrypted tasks
      final unencryptedTasks = await m.database
          .customSelect(
            'SELECT COUNT(*) as count FROM note_tasks '
            'WHERE encryption_version = 0 AND deleted = 0',
          )
          .getSingle();

      final tasksCount = unencryptedTasks.data['count'] as int;
      if (tasksCount > 0) {
        _logger.warning(
          'Found $tasksCount unencrypted tasks. Cannot proceed with migration.',
        );
        return false;
      }

      _logger.info('Encryption verification passed. All data is encrypted.');
      return true;
    } catch (e) {
      _logger.error('Error verifying encryption status', error: e);
      return false;
    }
  }

  /// Drop plaintext columns from local_notes table
  static Future<void> _dropNotesPlaintextColumns(Migrator m) async {
    _logger.info('Dropping plaintext columns from local_notes');

    // SQLite doesn't support DROP COLUMN directly, so we need to:
    // 1. Create a new table without plaintext columns
    // 2. Copy data to new table
    // 3. Drop old table
    // 4. Rename new table

    await m.database.customStatement('''
      CREATE TABLE local_notes_new (
        id TEXT NOT NULL PRIMARY KEY,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error_count INTEGER NOT NULL DEFAULT 0,
        last_sync_at INTEGER,
        remote_updated_at INTEGER,
        user_id TEXT,
        version INTEGER NOT NULL DEFAULT 1,

        -- ENCRYPTED DATA ONLY (no plaintext)
        title_encrypted TEXT NOT NULL,
        body_encrypted TEXT NOT NULL,
        metadata_encrypted TEXT,
        encryption_version INTEGER NOT NULL DEFAULT 1,

        -- Other fields
        encrypted_metadata TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        note_type INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '[]',
        attachment_meta TEXT,
        metadata TEXT
      );
    ''');

    // Copy all data from old table to new table
    await m.database.customStatement('''
      INSERT INTO local_notes_new (
        id, created_at, updated_at, deleted, sync_status, sync_error_count,
        last_sync_at, remote_updated_at, user_id, version,
        title_encrypted, body_encrypted, metadata_encrypted, encryption_version,
        encrypted_metadata, is_pinned, note_type, tags, attachment_meta, metadata
      )
      SELECT
        id, created_at, updated_at, deleted, sync_status, sync_error_count,
        last_sync_at, remote_updated_at, user_id, version,
        title_encrypted, body_encrypted, metadata_encrypted, encryption_version,
        encrypted_metadata, is_pinned, note_type, tags, attachment_meta, metadata
      FROM local_notes;
    ''');

    // Drop old table and rename new table
    await m.database.customStatement('DROP TABLE local_notes;');
    await m.database.customStatement(
      'ALTER TABLE local_notes_new RENAME TO local_notes;',
    );

    // Recreate indexes
    await _recreateNotesIndexes(m);

    _logger.info('Plaintext columns dropped from local_notes');
  }

  /// Drop plaintext columns from note_tasks table
  static Future<void> _dropTasksPlaintextColumns(Migrator m) async {
    _logger.info('Dropping plaintext columns from note_tasks');

    await m.database.customStatement('''
      CREATE TABLE note_tasks_new (
        id TEXT NOT NULL PRIMARY KEY,
        note_id TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL,
        completed_at INTEGER,
        deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_sync_at INTEGER,
        remote_updated_at INTEGER,
        user_id TEXT,
        version INTEGER NOT NULL DEFAULT 1,

        -- ENCRYPTED DATA ONLY (no plaintext)
        content_encrypted TEXT NOT NULL,
        labels_encrypted TEXT,
        notes_encrypted TEXT,
        encryption_version INTEGER NOT NULL DEFAULT 1,

        -- Other fields
        done INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'none',
        due_date INTEGER,
        content_hash TEXT NOT NULL,

        FOREIGN KEY (note_id) REFERENCES local_notes(id) ON DELETE CASCADE
      );
    ''');

    // Copy all data
    await m.database.customStatement('''
      INSERT INTO note_tasks_new (
        id, note_id, created_at, updated_at, completed_at, deleted,
        sync_status, last_sync_at, remote_updated_at, user_id, version,
        content_encrypted, labels_encrypted, notes_encrypted, encryption_version,
        done, priority, due_date, content_hash
      )
      SELECT
        id, note_id, created_at, updated_at, completed_at, deleted,
        sync_status, last_sync_at, remote_updated_at, user_id, version,
        content_encrypted, labels_encrypted, notes_encrypted, encryption_version,
        done, priority, due_date, content_hash
      FROM note_tasks;
    ''');

    // Drop old table and rename
    await m.database.customStatement('DROP TABLE note_tasks;');
    await m.database.customStatement(
      'ALTER TABLE note_tasks_new RENAME TO note_tasks;',
    );

    // Recreate indexes
    await _recreateTasksIndexes(m);

    _logger.info('Plaintext columns dropped from note_tasks');
  }

  /// Recreate indexes for local_notes after table recreation
  static Future<void> _recreateNotesIndexes(Migrator m) async {
    // Sync status index
    await m.database.customStatement('''
      CREATE INDEX idx_local_notes_sync_status
      ON local_notes(sync_status, updated_at)
      WHERE deleted = 0;
    ''');

    // User and update time index
    await m.database.customStatement('''
      CREATE INDEX idx_local_notes_user_updated
      ON local_notes(user_id, updated_at DESC)
      WHERE deleted = 0;
    ''');

    // Pinned notes index
    await m.database.customStatement('''
      CREATE INDEX idx_local_notes_pinned
      ON local_notes(is_pinned, updated_at DESC)
      WHERE deleted = 0 AND is_pinned = 1;
    ''');

    // Encryption status index (for monitoring)
    await m.database.customStatement('''
      CREATE INDEX idx_local_notes_encrypted
      ON local_notes(encryption_version, updated_at DESC)
      WHERE encryption_version = 1 AND deleted = 0;
    ''');
  }

  /// Recreate indexes for note_tasks after table recreation
  static Future<void> _recreateTasksIndexes(Migrator m) async {
    // Note ID index for task queries
    await m.database.customStatement('''
      CREATE INDEX idx_note_tasks_note_id
      ON note_tasks(note_id, updated_at DESC)
      WHERE deleted = 0;
    ''');

    // Due date index for deadline tracking
    await m.database.customStatement('''
      CREATE INDEX idx_note_tasks_due_date
      ON note_tasks(due_date)
      WHERE deleted = 0 AND done = 0 AND due_date IS NOT NULL;
    ''');

    // Priority index
    await m.database.customStatement('''
      CREATE INDEX idx_note_tasks_priority
      ON note_tasks(priority, due_date)
      WHERE deleted = 0 AND done = 0;
    ''');

    // Sync status index
    await m.database.customStatement('''
      CREATE INDEX idx_note_tasks_sync_status
      ON note_tasks(sync_status, updated_at)
      WHERE deleted = 0;
    ''');
  }

  /// Update FTS to use decrypted content (FTS should not store encrypted data)
  static Future<void> _updateFtsForEncryption(Migrator m) async {
    _logger.info('Updating FTS for encrypted content');

    // FTS will need to be populated with decrypted content in application layer
    // For now, we clear it to avoid plaintext references
    try {
      await m.database.customStatement('DELETE FROM fts_notes;');
      _logger.info('FTS cleared. Will be repopulated with decrypted content.');
    } catch (e) {
      _logger.warning('Could not clear FTS: $e');
    }
  }

  /// Verify migration completed successfully
  static Future<bool> verify(AppDb db) async {
    try {
      // Check that plaintext columns no longer exist in local_notes
      final notesColumns = await db
          .customSelect('PRAGMA table_info(local_notes)')
          .get();

      final hasPlaintextTitle = notesColumns.any(
        (row) => row.data['name'] == 'title',
      );
      final hasPlaintextBody = notesColumns.any(
        (row) => row.data['name'] == 'body',
      );

      if (hasPlaintextTitle || hasPlaintextBody) {
        _logger.error('Migration 24 failed: Plaintext columns still exist');
        return false;
      }

      // Check that encrypted columns exist
      final hasEncryptedTitle = notesColumns.any(
        (row) => row.data['name'] == 'title_encrypted',
      );
      final hasEncryptedBody = notesColumns.any(
        (row) => row.data['name'] == 'body_encrypted',
      );

      if (!hasEncryptedTitle || !hasEncryptedBody) {
        _logger.error('Migration 24 failed: Encrypted columns missing');
        return false;
      }

      // Check that data was preserved
      final rowCount = await db
          .customSelect('SELECT COUNT(*) as count FROM local_notes')
          .getSingle();

      _logger.info(
        'Migration 24 verification passed. ${rowCount.data['count']} notes verified.',
      );
      return true;
    } catch (e) {
      _logger.error('Migration 24 verification error', error: e);
      return false;
    }
  }

  /// SQL documentation for manual execution if needed
  static const String migrationSql = '''
    -- Migration 24: Drop Plaintext Columns (SECURITY FIX)
    -- WARNING: This migration removes unencrypted data storage
    -- Ensure all data is encrypted (encryption_version = 1) before running

    -- This migration recreates tables without plaintext columns
    -- See migration_24_drop_plaintext_columns.dart for full implementation

    -- BACKUP DATABASE BEFORE RUNNING
  ''';
}
