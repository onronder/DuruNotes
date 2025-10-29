#!/usr/bin/env dart

import 'dart:io';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'package:duru_notes/data/local/app_db.dart';

/// Security Audit Script: Verify Encryption Status
///
/// This script checks the current encryption status of all entities
/// in the local database to identify security vulnerabilities.
///
/// Run with: dart scripts/verify_encryption_status.dart

void main() async {
  print('🔒 ENCRYPTION STATUS VERIFICATION');
  print('=' * 50);

  // Find the database file
  final dbPath = p.join(Directory.current.path, 'duru.db');
  if (!File(dbPath).existsSync()) {
    print('❌ Database not found at: $dbPath');
    print('Please run the app first to create the database.');
    exit(1);
  }

  print('📁 Database found: $dbPath');

  // Open database connection
  final db = AppDb.forTesting(NativeDatabase(File(dbPath)));

  try {
    // Check Notes encryption
    print('\n📝 NOTES ENCRYPTION STATUS:');
    final notesResult = await db.customSelect('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN title_encrypted = '' OR title_encrypted IS NULL THEN 1 ELSE 0 END) as unencrypted_title,
        SUM(CASE WHEN body_encrypted = '' OR body_encrypted IS NULL THEN 1 ELSE 0 END) as unencrypted_body,
        SUM(CASE WHEN encryption_version IS NULL OR encryption_version = 0 THEN 1 ELSE 0 END) as no_version
      FROM local_notes
      WHERE deleted = 0
    ''').getSingle();

    final notesTotal = notesResult.read<int>('total');
    final notesUnencryptedTitle = notesResult.read<int>('unencrypted_title');
    final notesUnencryptedBody = notesResult.read<int>('unencrypted_body');
    final notesNoVersion = notesResult.read<int>('no_version');

    print('  Total active notes: $notesTotal');
    print('  Unencrypted titles: $notesUnencryptedTitle ${_getStatus(notesUnencryptedTitle)}');
    print('  Unencrypted bodies: $notesUnencryptedBody ${_getStatus(notesUnencryptedBody)}');
    print('  Missing encryption version: $notesNoVersion ${_getStatus(notesNoVersion)}');

    // Check Tasks encryption
    print('\n✅ TASKS ENCRYPTION STATUS:');
    final tasksResult = await db.customSelect('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN content_encrypted = '' OR content_encrypted IS NULL THEN 1 ELSE 0 END) as unencrypted_content,
        SUM(CASE WHEN encryption_version IS NULL OR encryption_version = 0 THEN 1 ELSE 0 END) as no_version
      FROM note_tasks
      WHERE deleted = 0
    ''').getSingle();

    final tasksTotal = tasksResult.read<int>('total');
    final tasksUnencryptedContent = tasksResult.read<int>('unencrypted_content');
    final tasksNoVersion = tasksResult.read<int>('no_version');

    print('  Total active tasks: $tasksTotal');
    print('  Unencrypted content: $tasksUnencryptedContent ${_getStatus(tasksUnencryptedContent)}');
    print('  Missing encryption version: $tasksNoVersion ${_getStatus(tasksNoVersion)}');

    // Check Templates encryption - CRITICAL VULNERABILITY
    print('\n📋 TEMPLATES ENCRYPTION STATUS:');

    // First check if encrypted columns exist
    final templateColumns = await db.customSelect('''
      PRAGMA table_info(local_templates)
    ''').get();

    final hasEncryptedColumns = templateColumns.any((col) =>
      col.read<String>('name').contains('_encrypted'));

    if (!hasEncryptedColumns) {
      print('  ❌ CRITICAL: No encrypted columns exist!');
      print('  ⚠️  Templates are stored in PLAINTEXT');

      final templateCount = await db.customSelect('''
        SELECT COUNT(*) as total FROM local_templates
      ''').getSingle();

      final total = templateCount.read<int>('total');
      print('  📊 Total templates at risk: $total');

      if (total > 0) {
        print('  🚨 IMMEDIATE ACTION REQUIRED: All templates are exposed!');
      }
    } else {
      // Check encryption status if columns exist
      final templatesResult = await db.customSelect('''
        SELECT
          COUNT(*) as total,
          SUM(CASE WHEN title_encrypted = '' OR title_encrypted IS NULL THEN 1 ELSE 0 END) as unencrypted_title,
          SUM(CASE WHEN body_encrypted = '' OR body_encrypted IS NULL THEN 1 ELSE 0 END) as unencrypted_body
        FROM local_templates
        WHERE deleted = 0
      ''').getSingle();

      final templatesTotal = templatesResult.read<int>('total');
      final templatesUnencryptedTitle = templatesResult.read<int>('unencrypted_title');
      final templatesUnencryptedBody = templatesResult.read<int>('unencrypted_body');

      print('  Total active templates: $templatesTotal');
      print('  Unencrypted titles: $templatesUnencryptedTitle ${_getStatus(templatesUnencryptedTitle)}');
      print('  Unencrypted bodies: $templatesUnencryptedBody ${_getStatus(templatesUnencryptedBody)}');
    }

    // Check Folders (local storage is plaintext by design, remote is encrypted)
    print('\n📁 FOLDERS STATUS:');
    final foldersResult = await db.customSelect('''
      SELECT COUNT(*) as total FROM local_folders WHERE deleted = 0
    ''').getSingle();

    final foldersTotal = foldersResult.read<int>('total');
    print('  Total active folders: $foldersTotal');
    print('  ℹ️  Folders are encrypted during sync, plaintext locally (by design)');

    // Check Reminders encryption
    print('\n⏰ REMINDERS ENCRYPTION STATUS:');

    // Check if reminders table exists
    final remindersTables = await db.customSelect('''
      SELECT name FROM sqlite_master
      WHERE type='table' AND name='reminders'
    ''').get();

    var remindersTotal = 0;
    if (remindersTables.isNotEmpty) {
      final remindersResult = await db.customSelect('''
        SELECT
          COUNT(*) as total,
          COUNT(DISTINCT note_id) as unique_notes
        FROM reminders
        WHERE deleted = 0
      ''').getSingle();

      remindersTotal = remindersResult.read<int>('total');
      final remindersNotes = remindersResult.read<int>('unique_notes');

      print('  Total active reminders: $remindersTotal');
      print('  Notes with reminders: $remindersNotes');
      print('  ⚠️  Reminders use PLAINTEXT title/body fields');

      if (remindersTotal > 0) {
        print('  🔓 Risk: Reminder content is not encrypted');
      }
    } else {
      print('  ℹ️  Reminders table not found');
    }

    // Summary and Risk Assessment
    print('\n${'=' * 50}');
    print('🎯 RISK ASSESSMENT SUMMARY:\n');

    int criticalIssues = 0;
    int highIssues = 0;
    int moderateIssues = 0;

    // Check for critical issues
    if (!hasEncryptedColumns && foldersTotal > 0) {
      print('🚨 CRITICAL: Templates have NO encryption columns');
      criticalIssues++;
    }

    if (notesUnencryptedTitle > 0 || notesUnencryptedBody > 0) {
      print('⚠️  HIGH: Some notes are not encrypted');
      highIssues++;
    }

    if (tasksUnencryptedContent > 0) {
      print('⚠️  HIGH: Some tasks are not encrypted');
      highIssues++;
    }

    if (remindersTotal > 0) {
      print('⚠️  MODERATE: Reminders are not encrypted');
      moderateIssues++;
    }

    // Final verdict
    print('\n📊 SECURITY POSTURE:');
    if (criticalIssues > 0) {
      print('  🚨 CRITICAL - Production deployment should be BLOCKED');
      print('  Fix templates encryption immediately!');
    } else if (highIssues > 0) {
      print('  ⚠️  HIGH RISK - Address within 24 hours');
    } else if (moderateIssues > 0) {
      print('  ⚠️  MODERATE RISK - Address within 1 week');
    } else {
      print('  ✅ SECURE - All entities properly encrypted');
    }

    print('\n📝 RECOMMENDATIONS:');
    if (!hasEncryptedColumns) {
      print('  1. Add encrypted columns to templates table');
      print('  2. Migrate existing template data');
      print('  3. Update template repository with encryption');
    }
    if (remindersTotal > 0) {
      print('  4. Consider encrypting reminder content');
    }

  } catch (e) {
    print('❌ Error checking encryption status: $e');
    exit(1);
  } finally {
    await db.close();
  }

  print('\n✅ Audit complete');
}

String _getStatus(int count) {
  if (count == 0) return '✅';
  if (count < 5) return '⚠️';
  return '❌';
}
