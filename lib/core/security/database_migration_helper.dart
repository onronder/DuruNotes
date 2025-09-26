import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:duru_notes/core/security/database_encryption.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Helper class to migrate unencrypted database to encrypted SQLCipher database
class DatabaseMigrationHelper {
  DatabaseMigrationHelper() : _logger = LoggerFactory.instance;

  final AppLogger _logger;

  /// Check if migration is needed and perform it if necessary
  Future<void> migrateToEncryptedDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final oldDbFile = File(p.join(dir.path, 'duru.sqlite'));
      final newDbFile = File(p.join(dir.path, 'duru_encrypted.sqlite'));

      // If old database doesn't exist, nothing to migrate
      if (!await oldDbFile.exists()) {
        _logger.info('No unencrypted database found, skipping migration');
        return;
      }

      // If new database already exists, migration already done
      if (await newDbFile.exists()) {
        _logger.info('Encrypted database already exists, skipping migration');
        // Optionally delete old database to save space
        await _deleteOldDatabase(oldDbFile);
        return;
      }

      _logger.info('Starting database encryption migration');

      // Get encryption key
      final dbEncryption = DatabaseEncryption();
      final encryptionKey = await dbEncryption.getDatabaseKey();

      // Perform the migration
      await _performMigration(oldDbFile, newDbFile, encryptionKey);

      // Verify the migration was successful
      if (await _verifyMigration(newDbFile, encryptionKey)) {
        _logger.info('Database migration successful, removing old database');
        await _deleteOldDatabase(oldDbFile);
      } else {
        _logger.error('Database migration verification failed');
        // Delete potentially corrupted new database
        if (await newDbFile.exists()) {
          await newDbFile.delete();
        }
        throw Exception('Database migration verification failed');
      }
    } catch (e) {
      _logger.error('Database migration failed', error: e);
      // Don't rethrow - allow app to continue with unencrypted database
      // The connection code will handle this gracefully
    }
  }

  /// Perform the actual migration from unencrypted to encrypted database
  Future<void> _performMigration(
    File oldDbFile,
    File newDbFile,
    String encryptionKey,
  ) async {
    Database? oldDb;
    Database? newDb;

    try {
      // Open unencrypted database
      oldDb = sqlite3.open(oldDbFile.path);

      // Create new encrypted database
      newDb = sqlite3.open(newDbFile.path);

      // Set up encryption for new database
      newDb.execute("PRAGMA key = '$encryptionKey'");
      newDb.execute('PRAGMA cipher_page_size = 4096');
      newDb.execute('PRAGMA kdf_iter = 64000');
      newDb.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA256');
      newDb.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA256');

      // Attach old database and copy all data
      newDb.execute("ATTACH DATABASE '${oldDbFile.path}' AS old_db KEY ''");

      // Get all tables from old database
      final tables = oldDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      // Copy each table
      for (final table in tables) {
        final tableName = table['name'] as String;
        _logger.info('Migrating table: $tableName');

        // Get table schema
        final createStatement = oldDb
            .select(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='$tableName'",
            )
            .first['sql'] as String;

        // Create table in new database
        newDb.execute(createStatement);

        // Copy data
        newDb.execute("INSERT INTO main.$tableName SELECT * FROM old_db.$tableName");
      }

      // Copy indices
      final indices = oldDb.select(
        "SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL",
      );
      for (final index in indices) {
        final createStatement = index['sql'] as String;
        newDb.execute(createStatement);
      }

      // Copy triggers
      final triggers = oldDb.select(
        "SELECT sql FROM sqlite_master WHERE type='trigger' AND sql IS NOT NULL",
      );
      for (final trigger in triggers) {
        final createStatement = trigger['sql'] as String;
        newDb.execute(createStatement);
      }

      // Detach old database
      newDb.execute('DETACH DATABASE old_db');

      _logger.info('Database migration completed');
    } finally {
      oldDb?.dispose();
      newDb?.dispose();
    }
  }

  /// Verify the migration was successful
  Future<bool> _verifyMigration(File newDbFile, String encryptionKey) async {
    Database? db;
    try {
      // Try to open the encrypted database
      db = sqlite3.open(newDbFile.path);
      db.execute("PRAGMA key = '$encryptionKey'");

      // Try to query a table to verify encryption is working
      final tables = db.select(
        "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table'",
      );

      final tableCount = tables.first['count'] as int;
      _logger.info('Verified encrypted database has $tableCount tables');

      return tableCount > 0;
    } catch (e) {
      _logger.error('Migration verification failed', error: e);
      return false;
    } finally {
      db?.dispose();
    }
  }

  /// Delete the old unencrypted database
  Future<void> _deleteOldDatabase(File oldDbFile) async {
    try {
      // Delete main database file
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }

      // Delete associated files (WAL, SHM)
      final walFile = File('${oldDbFile.path}-wal');
      final shmFile = File('${oldDbFile.path}-shm');

      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      _logger.info('Old unencrypted database deleted');
    } catch (e) {
      _logger.error('Failed to delete old database', error: e);
      // Non-critical error, don't throw
    }
  }
}