/* COMMENTED OUT - 8 errors - uses old APIs
 * This script uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
#!/usr/bin/env dart

/// Simple script to verify Migration 27 indexes
///
/// This script can be run standalone to verify that migration 27
/// properly creates all performance indexes.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duru_notes/data/migrations/migration_27_performance_indexes.dart';

class SimpleMigrator extends Migrator {
  final DatabaseConnectionUser db;

  SimpleMigrator(this.db);

  @override
  Future<void> createTable(TableInfo<Table, dynamic> table) async {
    // Create table SQL would go here
    // For this test, we just need to verify indexes can be created
  }

  @override
  Future<void> addColumn(TableInfo<Table, dynamic> table, GeneratedColumn column) async {
    // Add column SQL would go here
  }

  @override
  Future<void> deleteTable(String tableName) async {
    await db.customStatement('DROP TABLE IF EXISTS $tableName');
  }

  @override
  Future<void> renameColumn(
    TableInfo<Table, dynamic> table,
    String columnName,
    String newName,
  ) async {
    // Rename column SQL would go here
  }

  @override
  Future<void> alterTable(TableMigration migration) async {
    // Alter table SQL would go here
  }

  @override
  Future<void> createIndex(Index index) async {
    // Parse the SQL from the index name (stored in Index class)
    // For migration 27, the indexes are created with custom SQL
    await db.customStatement(index.name);
  }

  @override
  Future<void> renameTable(TableInfo<Table, dynamic> table, String newName) async {
    // Rename table SQL would go here
  }

  @override
  Future<void> drop(Referenceable entity) async {
    // Drop entity SQL would go here
  }

  @override
  Future<void> create(Referenceable entity) async {
    // Create entity SQL would go here
  }

  @override
  Future<void> createAll() async {
    // Create all tables
  }
}

class SimpleDb extends DatabaseConnectionUser {
  final QueryExecutor executor;

  SimpleDb(this.executor);

  @override
  QueryExecutor get resolvedEngine => executor;
}

Future<void> main() async {
  print('\n=== Migration 27 Verification Script ===\n');

  // Create in-memory database
  final db = SimpleDb(NativeDatabase.memory());

  // Create tables that indexes reference
  print('Creating base tables...');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS local_notes (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      updated_at INTEGER,
      deleted INTEGER DEFAULT 0,
      is_pinned INTEGER DEFAULT 0,
      metadata TEXT,
      version INTEGER DEFAULT 1
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS note_tags (
      id TEXT PRIMARY KEY,
      note_id TEXT,
      tag TEXT
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS note_links (
      id TEXT PRIMARY KEY,
      source_id TEXT,
      target_id TEXT
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS note_folders (
      id TEXT PRIMARY KEY,
      note_id TEXT,
      folder_id TEXT,
      updated_at INTEGER
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS note_tasks (
      id TEXT PRIMARY KEY,
      note_id TEXT,
      status TEXT,
      due_date INTEGER,
      priority INTEGER,
      deleted INTEGER DEFAULT 0
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS local_folders (
      id TEXT PRIMARY KEY,
      parent_id TEXT,
      path TEXT,
      sort_order INTEGER,
      deleted INTEGER DEFAULT 0
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS pending_ops (
      id TEXT PRIMARY KEY,
      entity_id TEXT,
      kind TEXT,
      created_at INTEGER
    )
  ''');

  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS note_reminders (
      id TEXT PRIMARY KEY,
      note_id TEXT,
      remind_at INTEGER,
      is_active INTEGER DEFAULT 1
    )
  ''');

  print('✅ Base tables created\n');

  // Apply migration
  print('Applying Migration 27...');
  final migrator = SimpleMigrator(db);

  try {
    await Migration27PerformanceIndexes.apply(migrator);
    print('✅ Migration 27 applied successfully\n');
  } catch (e) {
    print('❌ Error applying migration: $e\n');
    exit(1);
  }

  // Verify indexes
  print('Verifying indexes...');
  final hasIndexes = await Migration27PerformanceIndexes.verify(db);

  if (hasIndexes) {
    print('✅ Critical indexes verified\n');
  } else {
    print('❌ Critical indexes not found\n');
    exit(1);
  }

  // Get detailed stats
  print('Getting performance statistics...');
  final stats = await Migration27PerformanceIndexes.getPerformanceStats(db);

  print('Custom Indexes: ${stats['custom_indexes']}');
  print('Status: ${stats['status']}');
  print('Timestamp: ${stats['timestamp']}\n');

  // List all indexes
  print('All created indexes:');
  final indexQuery = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name",
  ).get();

  for (final row in indexQuery) {
    print('  - ${row.read<String>('name')}');
  }

  print('\n✅ Migration 27 verification complete!\n');
  print('All ${indexQuery.length} performance indexes created successfully.\n');

  exit(0);
}

*/
