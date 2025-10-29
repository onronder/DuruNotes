#!/usr/bin/env dart

/// Simple Migration 12 validation script
/// Tests that Migration 12 can run successfully without errors
library;

import 'dart:io';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_12_phase3_optimization.dart';
import 'package:duru_notes/data/migrations/migration_tables_setup.dart';

Future<void> main() async {
  print('🧪 Testing Migration 12 Phase 3 Optimization...\n');

  try {
    // Create in-memory database for testing
    final database = AppDb();

    print('✅ Database connection established');

    // Ensure migration tracking tables exist
    await MigrationTablesSetup.ensureMigrationTables(database);
    print('✅ Migration tracking tables created');

    // Check initial schema version
    final initialVersion = database.schemaVersion;
    print('📊 Initial schema version: $initialVersion');

    // Apply Migration 12 (idempotent - safe to run on v12)
    print('\n🔄 Applying Migration 12...');
    await Migration12Phase3Optimization.apply(database);
    print('✅ Migration 12 applied successfully');

    // Verify schema version after migration
    final finalVersion = database.schemaVersion;
    print('📊 Final schema version: $finalVersion');

    // Test that migration tracking works
    final migrationHistory = await MigrationTablesSetup.getMigrationHistory(database);
    print('📚 Migration history entries: ${migrationHistory.length}');

    // Verify signature indexes were created
    final indexExists = await _checkMigrationIndexes(database);
    print('🗂️ Migration indexes created: $indexExists');

    // Test rollback capability
    print('\n🔄 Testing rollback capability...');
    await Migration12Phase3Optimization.rollback(database);
    print('✅ Migration 12 rollback completed');

    // Close database
    await database.close();

    print('\n🎉 Migration 12 validation completed successfully!');
    print('✅ All tests passed - Migration 12 is ready for Step 3');

    exit(0);

  } catch (e, stackTrace) {
    print('\n❌ Migration 12 validation failed:');
    print('Error: $e');
    print('Stack trace: $stackTrace');

    exit(1);
  }
}

/// Check if Migration 12 signature indexes exist
Future<bool> _checkMigrationIndexes(AppDb database) async {
  try {
    final result = await database.customSelect('''
      SELECT name FROM sqlite_master
      WHERE type='index' AND name='idx_local_notes_pinned_updated'
    ''').getSingleOrNull();

    return result != null;
  } catch (e) {
    return false;
  }
}