import 'package:duru_notes/data/local/app_db.dart';

/// Setup migration tracking tables for unified migration system
///
/// These tables track migration history, backups, and coordination
/// between local SQLite and remote PostgreSQL databases.
class MigrationTablesSetup {
  /// Create migration tracking tables if they don't exist
  static Future<void> ensureMigrationTables(AppDb db) async {
    await _createMigrationHistoryTable(db);
    await _createMigrationBackupsTable(db);
    await _createMigrationSyncStatusTable(db);
  }

  /// Create migration history table
  static Future<void> _createMigrationHistoryTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS migration_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version TEXT NOT NULL,
        applied_at TEXT NOT NULL,
        migration_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        execution_time_ms INTEGER,
        rollback_applied_at TEXT,
        metadata TEXT, -- JSON string for additional data

        UNIQUE(version, migration_type)
      )
    ''');

    // Create index for faster lookups
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_history_version
      ON migration_history(version, status)
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_history_applied_at
      ON migration_history(applied_at DESC)
    ''');
  }

  /// Create migration backups table
  static Future<void> _createMigrationBackupsTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS migration_backups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backup_id TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        migration_version TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'created',
        backup_size_bytes INTEGER,
        restoration_verified INTEGER DEFAULT 0,
        cleanup_at TEXT,
        metadata TEXT, -- JSON string for backup details

        CHECK (status IN ('created', 'verified', 'restored', 'rollback_applied', 'cleanup_scheduled', 'deleted'))
      )
    ''');

    // Create index for backup management
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_backups_backup_id
      ON migration_backups(backup_id)
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_backups_status
      ON migration_backups(status, created_at)
    ''');
  }

  /// Create migration sync status table
  static Future<void> _createMigrationSyncStatusTable(AppDb db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS migration_sync_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        migration_version TEXT NOT NULL,
        local_status TEXT NOT NULL DEFAULT 'pending',
        remote_status TEXT NOT NULL DEFAULT 'pending',
        local_applied_at TEXT,
        remote_applied_at TEXT,
        local_rollback_at TEXT,
        remote_rollback_at TEXT,
        sync_conflict_detected INTEGER DEFAULT 0,
        conflict_resolution TEXT,
        last_sync_check TEXT,
        metadata TEXT, -- JSON for coordination data

        UNIQUE(migration_version),
        CHECK (local_status IN ('pending', 'in_progress', 'completed', 'failed', 'rolled_back')),
        CHECK (remote_status IN ('pending', 'in_progress', 'completed', 'failed', 'rolled_back', 'skipped'))
      )
    ''');

    // Create index for sync coordination
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_sync_status_version
      ON migration_sync_status(migration_version)
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_migration_sync_status_conflict
      ON migration_sync_status(sync_conflict_detected, migration_version)
      WHERE sync_conflict_detected = 1
    ''');
  }

  /// Insert initial migration records for tracking
  static Future<void> seedInitialMigrationData(AppDb db) async {
    // Record current schema version as baseline
    final currentVersion = await db.schemaVersion;

    await db.customStatement('''
      INSERT OR IGNORE INTO migration_history (
        version, applied_at, migration_type, status, metadata
      ) VALUES (?, ?, ?, ?, ?)
    ''', [
      'baseline_v$currentVersion',
      DateTime.now().toIso8601String(),
      'initial_schema',
      'completed',
      '{"source": "migration_tables_setup", "baseline": true}'
    ]);

    // Initialize sync status for upcoming Phase 3 migration
    await db.customStatement('''
      INSERT OR IGNORE INTO migration_sync_status (
        migration_version, local_status, remote_status, metadata
      ) VALUES (?, ?, ?, ?)
    ''', [
      '3.0.0',
      'pending',
      'pending',
      '{"phase": "3", "description": "Data Layer Optimization", "auto_created": true}'
    ]);
  }

  /// Get migration history for analysis
  static Future<List<Map<String, dynamic>>> getMigrationHistory(AppDb db) async {
    final result = await db.customSelect('''
      SELECT * FROM migration_history
      ORDER BY applied_at DESC
    ''').get();

    return result.map((row) => row.data).toList();
  }

  /// Get current migration sync status
  static Future<Map<String, dynamic>?> getCurrentSyncStatus(
    AppDb db,
    String migrationVersion
  ) async {
    final result = await db.customSelect('''
      SELECT * FROM migration_sync_status
      WHERE migration_version = '$migrationVersion'
    ''').getSingleOrNull();

    return result?.data;
  }

  /// Update migration sync status
  static Future<void> updateSyncStatus(
    AppDb db,
    String migrationVersion, {
    String? localStatus,
    String? remoteStatus,
    bool? syncConflictDetected,
    String? conflictResolution,
    Map<String, dynamic>? metadata,
  }) async {
    final updates = <String>[];
    final params = <dynamic>[];

    if (localStatus != null) {
      updates.add('local_status = ?');
      params.add(localStatus);

      if (localStatus == 'completed') {
        updates.add('local_applied_at = ?');
        params.add(DateTime.now().toIso8601String());
      } else if (localStatus == 'rolled_back') {
        updates.add('local_rollback_at = ?');
        params.add(DateTime.now().toIso8601String());
      }
    }

    if (remoteStatus != null) {
      updates.add('remote_status = ?');
      params.add(remoteStatus);

      if (remoteStatus == 'completed') {
        updates.add('remote_applied_at = ?');
        params.add(DateTime.now().toIso8601String());
      } else if (remoteStatus == 'rolled_back') {
        updates.add('remote_rollback_at = ?');
        params.add(DateTime.now().toIso8601String());
      }
    }

    if (syncConflictDetected != null) {
      updates.add('sync_conflict_detected = ?');
      params.add(syncConflictDetected ? 1 : 0);
    }

    if (conflictResolution != null) {
      updates.add('conflict_resolution = ?');
      params.add(conflictResolution);
    }

    if (metadata != null) {
      updates.add('metadata = ?');
      params.add(metadata.toString()); // Convert to JSON string
    }

    updates.add('last_sync_check = ?');
    params.add(DateTime.now().toIso8601String());

    params.add(migrationVersion); // For WHERE clause

    if (updates.isNotEmpty) {
      await db.customStatement('''
        UPDATE migration_sync_status
        SET ${updates.join(', ')}
        WHERE migration_version = ?
      ''', params);
    }
  }

  /// Clean up old migration backups
  static Future<int> cleanupOldBackups(AppDb db, {int keepDays = 30}) async {
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: keepDays))
        .toIso8601String();

    // Mark for cleanup
    await db.customStatement('''
      UPDATE migration_backups
      SET status = 'cleanup_scheduled', cleanup_at = ?
      WHERE created_at < ? AND status NOT IN ('rollback_applied', 'cleanup_scheduled', 'deleted')
    ''', [DateTime.now().toIso8601String(), cutoffDate]);

    // Count affected rows
    final result = await db.customSelect('''
      SELECT COUNT(*) as count
      FROM migration_backups
      WHERE status = 'cleanup_scheduled'
    ''').getSingle();

    return result.read<int>('count') ?? 0;
  }

  /// Verify migration table integrity
  static Future<bool> verifyMigrationTables(AppDb db) async {
    try {
      // Check all tables exist
      final tables = ['migration_history', 'migration_backups', 'migration_sync_status'];

      for (final table in tables) {
        final result = await db.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type='table' AND name='$table'
        ''').getSingleOrNull();

        if (result == null) {
          return false;
        }
      }

      // Check indexes exist
      final indexes = [
        'idx_migration_history_version',
        'idx_migration_history_applied_at',
        'idx_migration_backups_backup_id',
        'idx_migration_backups_status',
        'idx_migration_sync_status_version',
        'idx_migration_sync_status_conflict',
      ];

      for (final index in indexes) {
        final result = await db.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type='index' AND name='$index'
        ''').getSingleOrNull();

        if (result == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}