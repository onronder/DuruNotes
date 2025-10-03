import 'package:drift/drift.dart';

/// Migration 23: Add local encryption columns for CryptoBox at-rest encryption
///
/// Adds encrypted versions of note and task data to enable zero-knowledge architecture
/// where local database is encrypted with the same CryptoBox system used for Supabase.
///
/// Strategy:
/// - Add titleEncrypted, bodyEncrypted, metadataEncrypted columns to notes
/// - Add contentEncrypted, labelsEncrypted, notesEncrypted columns to tasks
/// - Add encryptionVersion to track encryption state
/// - Keep existing plaintext columns for 90-day rollback safety
/// - Migration happens gradually in background
class Migration23LocalEncryption {
  static Future<void> run(Migrator m, int from) async {
    if (from < 23) {
      await _addEncryptionColumns(m);
      await _addTaskEncryptionColumns(m);
      await _createEncryptionIndexes(m);
    }
  }

  static Future<void> _addEncryptionColumns(Migrator m) async {
    // Add encrypted data columns (nullable for gradual migration)
    await m.database.customStatement(
      'ALTER TABLE local_notes ADD COLUMN title_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE local_notes ADD COLUMN body_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE local_notes ADD COLUMN metadata_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE local_notes ADD COLUMN encryption_version INTEGER DEFAULT 0;'
    );
  }

  static Future<void> _addTaskEncryptionColumns(Migrator m) async {
    // Add encrypted data columns for tasks (nullable for gradual migration)
    await m.database.customStatement(
      'ALTER TABLE note_tasks ADD COLUMN content_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE note_tasks ADD COLUMN labels_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE note_tasks ADD COLUMN notes_encrypted TEXT;'
    );
    await m.database.customStatement(
      'ALTER TABLE note_tasks ADD COLUMN encryption_version INTEGER DEFAULT 0;'
    );
  }

  static Future<void> _createEncryptionIndexes(Migrator m) async {
    // Index to quickly find unencrypted notes for background migration
    await m.database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_notes_encryption_status
      ON local_notes(encryption_version, updated_at)
      WHERE encryption_version = 0 AND deleted = 0;
    ''');

    // Partial index for encrypted notes (most queries after migration)
    await m.database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_notes_encrypted
      ON local_notes(user_id, updated_at DESC)
      WHERE encryption_version = 1 AND deleted = 0;
    ''');

    // Index to quickly find unencrypted tasks for background migration
    await m.database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tasks_encryption_status
      ON note_tasks(encryption_version, updated_at)
      WHERE encryption_version = 0 AND deleted = 0;
    ''');

    // Partial index for encrypted tasks (most queries after migration)
    await m.database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_note_tasks_encrypted
      ON note_tasks(note_id, updated_at DESC)
      WHERE encryption_version = 1 AND deleted = 0;
    ''');
  }

  /// SQL for manual execution or documentation
  static const String migrationSql = '''
    -- Migration 23: Local Encryption at Rest
    -- Adds CryptoBox encrypted columns to local_notes table

    ALTER TABLE local_notes ADD COLUMN title_encrypted TEXT;
    ALTER TABLE local_notes ADD COLUMN body_encrypted TEXT;
    ALTER TABLE local_notes ADD COLUMN metadata_encrypted TEXT;
    ALTER TABLE local_notes ADD COLUMN encryption_version INTEGER DEFAULT 0;

    -- Index for finding unencrypted notes
    CREATE INDEX idx_local_notes_encryption_status
      ON local_notes(encryption_version, updated_at)
      WHERE encryption_version = 0 AND deleted = 0;

    -- Index for encrypted notes (main query path after migration)
    CREATE INDEX idx_local_notes_encrypted
      ON local_notes(user_id, updated_at DESC)
      WHERE encryption_version = 1 AND deleted = 0;
  ''';
}