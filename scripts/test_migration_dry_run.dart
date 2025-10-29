/* COMMENTED OUT - 4 errors - uses old APIs
 * This script uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
/// Test script to demonstrate migration dry-run functionality
///
/// This creates an in-memory database with test data and shows
/// what the migration would do.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_25_security_userid_population.dart';

Future<void> main() async {
  print('🔧 Migration Dry-Run Test');
  print('=' * 60);
  print('');

  // Create in-memory test database
  final db = AppDb(NativeDatabase.memory());

  try {
    // Create test data
    await _createTestData(db);

    // Create migration guide
    final guide = UserIdPopulationGuide(db);

    // Check if population is needed
    print('📊 Step 1: Check Status');
    print('-' * 60);
    final isNeeded = await guide.isPopulationNeeded();
    print('Migration needed: ${isNeeded ? "YES ⚠️" : "NO ✅"}');
    print('');

    // Show detailed status
    print('📈 Step 2: Detailed Status Report');
    print('-' * 60);
    final report = await guide.getStatusReport();
    print(report);

    // Show what would be changed
    print('🔍 Step 3: Preview Changes (Dry-Run)');
    print('-' * 60);

    final stats = await Migration25SecurityUserIdPopulation
        .getUserIdPopulationStats(db);

    print('Would assign userId "test-user-123" to:');
    print('');
    print('  📁 Folders:');
    print('     - Total folders: ${stats['totalFolders']}');
    print('     - Already have userId: ${stats['foldersWithUserId']}');
    print('     - Need userId: ${stats['foldersWithoutUserId']} ← WILL UPDATE');
    print('');
    print('  📄 Templates:');
    print('     - Total templates: ${stats['totalTemplates']}');
    print('     - System templates: ${stats['systemTemplates']} (userId=null)');
    print('     - User templates with userId: ${stats['userTemplatesWithUserId']}');
    print('     - User templates need userId: ${stats['userTemplatesWithoutUserId']} ← WILL UPDATE');
    print('');

    // Show folders that would be updated
    final foldersToUpdate = await Migration25SecurityUserIdPopulation
        .getFoldersWithoutUserId(db);

    if (foldersToUpdate.isNotEmpty) {
      print('  📂 Folders to be updated:');
      for (final folder in foldersToUpdate) {
        print('     • ${folder['name']} (${folder['path']})');
      }
      print('');
    }

    // Show templates that would be updated
    final templatesToUpdate = await Migration25SecurityUserIdPopulation
        .getUserTemplatesWithoutUserId(db);

    if (templatesToUpdate.isNotEmpty) {
      print('  📝 Templates to be updated:');
      for (final template in templatesToUpdate) {
        print('     • ${template['title']} (${template['category']})');
      }
      print('');
    }

    print('⚠️  DRY-RUN MODE: No changes applied');
    print('');
    print('To apply these changes in production:');
    print('  dart run scripts/populate_userid_migration.dart \\');
    print('    --user-id=YOUR_USER_ID --force');
    print('');

    // Demonstrate actual migration (in memory, for testing)
    print('🎯 Step 4: Simulate Migration (In-Memory Test)');
    print('-' * 60);

    await Migration25SecurityUserIdPopulation.populateUserIdForSingleUser(
      db,
      'test-user-123',
    );

    print('✅ Migration applied (in test database)');
    print('');

    // Validate
    final statsAfter = await Migration25SecurityUserIdPopulation
        .getUserIdPopulationStats(db);

    print('📊 Results:');
    print('  Folders with userId: ${statsAfter['foldersWithUserId']}/${statsAfter['totalFolders']}');
    final totalUserTemplates = (statsAfter['totalTemplates'] ?? 0) - (statsAfter['systemTemplates'] ?? 0);
    print('  User templates with userId: ${statsAfter['userTemplatesWithUserId']}/$totalUserTemplates');
    print('  System templates: ${statsAfter['systemTemplates']} (userId=null as expected)');
    print('');

    final isValid = await Migration25SecurityUserIdPopulation
        .validateUserIdPopulation(db);

    if (isValid) {
      print('✅ SUCCESS: All data properly assigned');
    } else {
      print('❌ VALIDATION FAILED: Some data still lacks userId');
    }

    print('');
    print('=' * 60);
    print('🎉 Dry-Run Test Complete');
    print('');
    print('This demonstrates what the migration will do in production.');
    print('No actual production data was modified.');

  } finally {
    await db.close();
  }
}

Future<void> _createTestData(AppDb db) async {
  final now = DateTime.now();

  // Create folders without userId (simulating legacy data)
  await db.into(db.localFolders).insert(LocalFoldersCompanion.insert(
    id: 'folder-1',
    name: 'Work Projects',
    path: '/Work Projects',
    color: Value('#FF5733'),
    icon: Value('work'),
    createdAt: now,
    updatedAt: now,
    // userId is null - needs migration
  ));

  await db.into(db.localFolders).insert(LocalFoldersCompanion.insert(
    id: 'folder-2',
    name: 'Personal',
    path: '/Personal',
    color: Value('#33C3FF'),
    icon: Value('person'),
    createdAt: now,
    updatedAt: now,
    // userId is null - needs migration
  ));

  await db.into(db.localFolders).insert(LocalFoldersCompanion.insert(
    id: 'folder-3',
    name: 'Archive',
    path: '/Archive',
    color: Value('#888888'),
    icon: Value('archive'),
    createdAt: now,
    updatedAt: now,
    // userId is null - needs migration
  ));

  // Create system template (should have userId=null)
  await db.into(db.localTemplates).insert(LocalTemplatesCompanion.insert(
    id: 'template-system-1',
    title: 'Meeting Notes',
    body: '# Meeting {{title}}\n\nDate: {{date}}\nAttendees: {{attendees}}',
    category: 'system',
    description: 'System template for meetings',
    icon: 'meeting',
    tags: Value('[]'),
    isSystem: Value(true),
    // userId is null for system templates
    createdAt: now,
    updatedAt: now,
  ));

  // Create user templates without userId (simulating legacy data)
  await db.into(db.localTemplates).insert(LocalTemplatesCompanion.insert(
    id: 'template-user-1',
    title: 'Daily Standup',
    body: '## Standup {{date}}\n\nYesterday: {{yesterday}}\nToday: {{today}}',
    category: 'work',
    description: 'Daily standup template',
    icon: 'calendar',
    tags: Value('[]'),
    isSystem: Value(false),
    // userId is null - needs migration
    createdAt: now,
    updatedAt: now,
  ));

  await db.into(db.localTemplates).insert(LocalTemplatesCompanion.insert(
    id: 'template-user-2',
    title: 'Project Plan',
    body: '# Project: {{name}}\n\nGoals: {{goals}}\nDeadline: {{deadline}}',
    category: 'work',
    description: 'Project planning template',
    icon: 'project',
    tags: Value('[]'),
    isSystem: Value(false),
    // userId is null - needs migration
    createdAt: now,
    updatedAt: now,
  ));

  print('✅ Created test data:');
  print('   - 3 folders (need userId)');
  print('   - 1 system template (userId=null expected)');
  print('   - 2 user templates (need userId)');
  print('');
}

*/
