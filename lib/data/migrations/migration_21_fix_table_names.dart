import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 21: Fix Table Names Recovery
///
/// This migration fixes databases that were affected by the broken Migration 20.
/// It ensures all tables have the correct names that the Drift schema expects:
/// - notes → local_notes
/// - folders → local_folders
/// - templates → local_templates
/// - attachments → local_attachments
///
/// This migration is idempotent and safe to run multiple times.
class Migration21FixTableNames {
  static const int version = 21;
  static const String description = 'Recovery: Fix table names to match Drift schema';

  static Future<void> apply(AppDb db) async {
    final logger = LoggerFactory.instance;
    logger.info('Starting Migration 21: Table Names Recovery');

    try {
      // Get current table names
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table'"
      ).get();

      final tableNames = tables.map((t) => t.read<String>('name')).toSet();
      logger.info('Current tables: ${tableNames.join(', ')}');

      // ============================================
      // RECOVERY: Rename tables back to expected names
      // ============================================

      // If notes exists but local_notes doesn't, rename it back
      if (tableNames.contains('notes') && !tableNames.contains('local_notes')) {
        logger.info('Recovering: Renaming notes → local_notes');
        await db.customStatement('ALTER TABLE notes RENAME TO local_notes');
      }

      // If folders exists but local_folders doesn't, rename it back
      if (tableNames.contains('folders') && !tableNames.contains('local_folders')) {
        logger.info('Recovering: Renaming folders → local_folders');
        await db.customStatement('ALTER TABLE folders RENAME TO local_folders');
      }

      // If templates exists but local_templates doesn't, rename it back
      if (tableNames.contains('templates') && !tableNames.contains('local_templates')) {
        logger.info('Recovering: Renaming templates → local_templates');
        await db.customStatement('ALTER TABLE templates RENAME TO local_templates');
      }

      // If attachments exists but local_attachments doesn't, rename it back
      if (tableNames.contains('attachments') && !tableNames.contains('local_attachments')) {
        logger.info('Recovering: Renaming attachments → local_attachments');
        await db.customStatement('ALTER TABLE attachments RENAME TO local_attachments');
      }

      // ============================================
      // Verify all expected tables exist now
      // ============================================

      final expectedTables = ['local_notes', 'local_folders', 'local_templates', 'local_attachments'];
      bool allGood = true;

      for (final tableName in expectedTables) {
        final result = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'"
        ).get();

        if (result.isEmpty) {
          logger.error('CRITICAL: Table $tableName is missing after recovery!');
          allGood = false;
        } else {
          logger.info('✓ Table $tableName exists');
        }
      }

      if (!allGood) {
        throw Exception('Migration 21 failed: Some expected tables are missing');
      }

      // ============================================
      // Record the migration
      // ============================================

      await db.customStatement('''
        INSERT OR REPLACE INTO schema_versions (version, applied_at, description)
        VALUES ($version, CURRENT_TIMESTAMP, '$description')
      ''');

      logger.info('Migration 21 completed successfully - Database recovered');

    } catch (e, stack) {
      logger.error('Failed to apply Migration 21: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Verify migration was successful
  static Future<bool> verify(AppDb db) async {
    try {
      // Check that all expected tables exist
      final expectedTables = ['local_notes', 'local_folders', 'local_templates', 'local_attachments'];

      for (final tableName in expectedTables) {
        final result = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'"
        ).get();

        if (result.isEmpty) {
          LoggerFactory.instance.error('Migration 21 verification failed: Table $tableName missing');
          return false;
        }
      }

      // Note: It's OK if old renamed tables (notes, folders, etc.) still exist
      // as long as the local_ versions also exist. The app expects local_ table names.

      LoggerFactory.instance.info('Migration 21 verification passed - All tables correctly named');
      return true;

    } catch (e) {
      LoggerFactory.instance.error('Migration 21 verification failed: $e');
      return false;
    }
  }
}