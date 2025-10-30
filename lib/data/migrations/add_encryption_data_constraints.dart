import 'package:drift/drift.dart';

/// Critical database constraints migration to prevent corrupted encrypted data
/// This migration adds constraints to prevent the [91, 93] corruption issue
class AddEncryptionDataConstraints {
  /// Apply all encryption data integrity constraints to the database
  static Future<void> apply(Migrator m) async {
    // ==============================
    // ENCRYPTED METADATA CONSTRAINTS
    // ==============================

    // Note: We're recreating the table with constraints since SQLite doesn't
    // support ALTER TABLE ADD CONSTRAINT directly
    await (m as dynamic).database.customStatement('''
      -- Create a new table with constraints
      CREATE TABLE local_notes_new (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        encrypted_metadata TEXT NULL
          CHECK (encrypted_metadata IS NULL OR
                 (length(encrypted_metadata) > 10 AND
                  encrypted_metadata != '[]' AND
                  encrypted_metadata NOT LIKE '%[91,93]%' AND
                  encrypted_metadata NOT LIKE '%"[]"%')),
        is_pinned INTEGER NOT NULL DEFAULT 0,
        note_type INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1,
        user_id TEXT NULL,
        attachment_meta TEXT NULL,
        metadata TEXT NULL
      )
    ''');

    // Copy existing data (excluding corrupted records)
    await (m as dynamic).database.customStatement('''
      INSERT INTO local_notes_new
      SELECT id, title, body, updated_at, deleted,
             CASE
               WHEN encrypted_metadata = '[]' THEN NULL
               WHEN encrypted_metadata LIKE '%[91,93]%' THEN NULL
               WHEN encrypted_metadata IS NOT NULL AND length(encrypted_metadata) <= 10 THEN NULL
               ELSE encrypted_metadata
             END as encrypted_metadata,
             is_pinned, note_type, version, user_id, attachment_meta, metadata
      FROM local_notes
    ''');

    // Drop old table and rename new one
    await (m as dynamic).database.customStatement('DROP TABLE local_notes');
    await (m as dynamic).database.customStatement(
      'ALTER TABLE local_notes_new RENAME TO local_notes',
    );

    // Recreate indexes (if any were lost)
    await (m as dynamic).database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_user_deleted_updated
      ON local_notes(user_id, deleted, updated_at DESC)
    ''');

    await (m as dynamic).database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_pinned_deleted
      ON local_notes(is_pinned, deleted) WHERE is_pinned = 1
    ''');

    await (m as dynamic).database.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notes_version
      ON local_notes(version)
    ''');

    // ==============================
    // ADDITIONAL INTEGRITY CHECKS
    // ==============================

    // Create a trigger to prevent insertion of corrupted data
    await (m as dynamic).database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS prevent_corrupted_metadata
      BEFORE INSERT ON local_notes
      FOR EACH ROW
      WHEN NEW.encrypted_metadata IS NOT NULL
           AND (NEW.encrypted_metadata = '[]'
                OR NEW.encrypted_metadata LIKE '%[91,93]%'
                OR length(NEW.encrypted_metadata) <= 10)
      BEGIN
        UPDATE local_notes SET encrypted_metadata = NULL WHERE id = NEW.id;
      END
    ''');

    // Create a trigger to prevent updates with corrupted data
    await (m as dynamic).database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS prevent_corrupted_metadata_update
      BEFORE UPDATE ON local_notes
      FOR EACH ROW
      WHEN NEW.encrypted_metadata IS NOT NULL
           AND (NEW.encrypted_metadata = '[]'
                OR NEW.encrypted_metadata LIKE '%[91,93]%'
                OR length(NEW.encrypted_metadata) <= 10)
      BEGIN
        SELECT RAISE(ABORT, 'Cannot update with corrupted encrypted_metadata. Use NULL instead.');
      END
    ''');
  }

  /// Clean up existing corrupted data
  static Future<void> cleanupCorruptedData(DatabaseConnectionUser db) async {
    try {
      // Count corrupted records before cleanup
      final corruptedCount = await db.customSelect('''
        SELECT COUNT(*) as count FROM local_notes
        WHERE encrypted_metadata IS NOT NULL
          AND (encrypted_metadata = '[]'
               OR encrypted_metadata LIKE '%[91,93]%'
               OR length(encrypted_metadata) <= 10)
      ''').getSingle();

      final count = corruptedCount.read<int>('count');
      print('🧹 Found $count corrupted encrypted_metadata records to clean up');

      // Set corrupted records to NULL
      await db.customStatement('''
        UPDATE local_notes
        SET encrypted_metadata = NULL
        WHERE encrypted_metadata IS NOT NULL
          AND (encrypted_metadata = '[]'
               OR encrypted_metadata LIKE '%[91,93]%'
               OR length(encrypted_metadata) <= 10)
      ''');

      print('✅ Cleaned up $count corrupted encrypted_metadata records');
    } catch (e) {
      print('❌ Error during corrupted data cleanup: $e');
    }
  }

  /// Check if constraints exist (for idempotent migrations)
  static Future<bool> constraintsExist(DatabaseConnectionUser db) async {
    try {
      // Check if the trigger exists
      final result = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='trigger' AND name='prevent_corrupted_metadata'
      ''').getSingleOrNull();

      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Get corruption statistics for monitoring
  static Future<Map<String, dynamic>> getCorruptionStats(
    DatabaseConnectionUser db,
  ) async {
    final stats = <String, dynamic>{};

    try {
      // Count total notes
      final totalNotes = await db
          .customSelect('SELECT COUNT(*) as count FROM local_notes')
          .getSingle();
      stats['total_notes'] = totalNotes.read<int>('count');

      // Count notes with encrypted metadata
      final encryptedNotes = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM local_notes WHERE encrypted_metadata IS NOT NULL',
          )
          .getSingle();
      stats['encrypted_notes'] = encryptedNotes.read<int>('count');

      // Count potential corrupted records
      final corruptedRecords = await db.customSelect('''
        SELECT COUNT(*) as count FROM local_notes
        WHERE encrypted_metadata IS NOT NULL
          AND (encrypted_metadata = '[]'
               OR encrypted_metadata LIKE '%[91,93]%'
               OR length(encrypted_metadata) <= 10)
      ''').getSingle();
      stats['corrupted_records'] = corruptedRecords.read<int>('count');

      // Count properly formatted encrypted records (should contain 'n', 'c', 'm' keys)
      final validEncrypted = await db.customSelect('''
        SELECT COUNT(*) as count FROM local_notes
        WHERE encrypted_metadata IS NOT NULL
          AND encrypted_metadata LIKE '%"n":%'
          AND encrypted_metadata LIKE '%"c":%'
          AND encrypted_metadata LIKE '%"m":%'
          AND length(encrypted_metadata) > 100
      ''').getSingle();
      stats['valid_encrypted_records'] = validEncrypted.read<int>('count');

      final corruptedCount = stats['corrupted_records'] as int;
      final encryptedCount = stats['encrypted_notes'] as int;
      stats['corruption_rate'] = (corruptedCount > 0 && encryptedCount > 0)
          ? ((corruptedCount / encryptedCount) * 100).toStringAsFixed(2)
          : '0.00';
    } catch (e) {
      stats['error'] = e.toString();
    }

    return stats;
  }
}
