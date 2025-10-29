#!/usr/bin/env dart

/// Simple verification that Migration 27 is properly integrated into app_db.dart
///
/// This script checks:
/// 1. Schema version is 27
/// 2. Migration 27 import exists
/// 3. Migration 27 is called in onUpgrade
/// 4. All expected index names are defined in migration file
library;

import 'dart:io';

void main() async {
  print('\n=== Migration 27 Integration Verification ===\n');

  final appDbPath = 'lib/data/local/app_db.dart';
  final migration27Path = 'lib/data/migrations/migration_27_performance_indexes.dart';

  // Check files exist
  if (!File(appDbPath).existsSync()) {
    print('❌ ERROR: $appDbPath not found');
    exit(1);
  }

  if (!File(migration27Path).existsSync()) {
    print('❌ ERROR: $migration27Path not found');
    exit(1);
  }

  final appDbContent = await File(appDbPath).readAsString();
  final migration27Content = await File(migration27Path).readAsString();

  var passed = 0;
  var failed = 0;

  // Test 1: Check schema version
  print('Test 1: Schema version is 27');
  if (appDbContent.contains('schemaVersion => 27')) {
    print('  ✅ PASS: Schema version is set to 27\n');
    passed++;
  } else {
    print('  ❌ FAIL: Schema version is not 27\n');
    failed++;
  }

  // Test 2: Check import statement
  print('Test 2: Migration 27 import exists');
  if (appDbContent.contains("import 'package:duru_notes/data/migrations/migration_27_performance_indexes.dart'")) {
    print('  ✅ PASS: Migration 27 import found\n');
    passed++;
  } else {
    print('  ❌ FAIL: Migration 27 import not found\n');
    failed++;
  }

  // Test 3: Check migration is called in onUpgrade
  print('Test 3: Migration 27 is called in onUpgrade');
  if (appDbContent.contains('if (from < 27)') &&
      appDbContent.contains('Migration27PerformanceIndexes.apply')) {
    print('  ✅ PASS: Migration 27 is called in onUpgrade\n');
    passed++;
  } else {
    print('  ❌ FAIL: Migration 27 not called in onUpgrade\n');
    failed++;
  }

  // Test 4: Check migration file structure
  print('Test 4: Migration file has apply method');
  if (migration27Content.contains('static Future<void> apply(Migrator m)')) {
    print('  ✅ PASS: Migration apply method exists\n');
    passed++;
  } else {
    print('  ❌ FAIL: Migration apply method not found\n');
    failed++;
  }

  // Test 5: Check migration has verify method
  print('Test 5: Migration file has verify method');
  if (migration27Content.contains('static Future<bool> verify(DatabaseConnectionUser db)')) {
    print('  ✅ PASS: Migration verify method exists\n');
    passed++;
  } else {
    print('  ❌ FAIL: Migration verify method not found\n');
    failed++;
  }

  // Test 6: Check critical indexes are defined
  print('Test 6: Critical indexes are defined');
  final criticalIndexes = [
    'idx_note_tags_batch_load',
    'idx_note_links_batch_load',
    'idx_note_folders_batch_load',
    'idx_notes_user_updated_composite',
    'idx_tasks_note_status_composite',
  ];

  var allIndexesFound = true;
  for (final index in criticalIndexes) {
    if (!migration27Content.contains(index)) {
      print('  ❌ Missing index: $index');
      allIndexesFound = false;
    }
  }

  if (allIndexesFound) {
    print('  ✅ PASS: All critical indexes defined\n');
    passed++;
  } else {
    print('  ❌ FAIL: Some critical indexes missing\n');
    failed++;
  }

  // Test 7: Count total indexes
  print('Test 7: Verify expected number of indexes');
  final indexMatches = RegExp(r"'idx_\w+'").allMatches(migration27Content);
  final uniqueIndexes = indexMatches.map((m) => m.group(0)).toSet();

  print('  Found ${uniqueIndexes.length} unique indexes');
  if (uniqueIndexes.length >= 15) {
    print('  ✅ PASS: Expected number of indexes (15+) found\n');
    passed++;
  } else {
    print('  ❌ FAIL: Less than 15 indexes found\n');
    failed++;
  }

  // Test 8: Check verification utility exists
  print('Test 8: Index verification utility exists');
  final verifyIndexesPath = 'lib/infrastructure/benchmarks/verify_indexes.dart';
  if (File(verifyIndexesPath).existsSync()) {
    print('  ✅ PASS: Index verification utility exists\n');
    passed++;
  } else {
    print('  ❌ FAIL: Index verification utility not found\n');
    failed++;
  }

  // Summary
  print('=' * 50);
  print('SUMMARY:');
  print('  Passed: $passed');
  print('  Failed: $failed');
  print('  Total:  ${passed + failed}');
  print('=' * 50);

  if (failed == 0) {
    print('\n✅ SUCCESS: Migration 27 is properly integrated!\n');
    print('Next steps:');
    print('  1. Run the app and verify indexes are created');
    print('  2. Check database with: SELECT name FROM sqlite_master WHERE type=\'index\' AND name LIKE \'idx_%\'');
    print('  3. Monitor query performance improvements\n');
    exit(0);
  } else {
    print('\n❌ FAILURE: Migration 27 integration has issues\n');
    exit(1);
  }
}
