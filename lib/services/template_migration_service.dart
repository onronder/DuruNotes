import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// DEPRECATED: This migration service is obsolete after encryption migration.
///
/// This service attempted to migrate templates from local_notes to local_templates
/// by reading LocalNote.title and LocalNote.body fields, which no longer exist.
///
/// The plaintext columns (title, body) were removed in migration_12_phase3_optimization.
/// All data is now stored encrypted (titleEncrypted, bodyEncrypted).
///
/// If template migration is still needed:
/// 1. Use NotesCoreRepository to read encrypted notes and decrypt them
/// 2. Use TemplateCoreRepository to create templates
/// 3. Both repositories handle encryption/decryption automatically
///
/// This migration should have already completed before the encryption schema migration.
@Deprecated('Template migration must be reimplemented with encryption support')
class TemplateMigrationService {
  final AppLogger _logger = LoggerFactory.instance;

  TemplateMigrationService(AppDb db); // Kept for backward compatibility

  /// Migrate all templates from local_notes to local_templates
  @Deprecated('Cannot access plaintext fields - use repositories with encryption')
  Future<void> migrateTemplates() async {
    _logger.warning('Template migration service is deprecated - plaintext columns no longer exist');
    _logger.warning('If migration is needed, reimplement using NotesCoreRepository and TemplateCoreRepository');
    // No-op: Cannot access templateNote.title or templateNote.body (removed in encryption migration)
    return;
  }

  /// Check if templates need migration
  @Deprecated('Migration service is deprecated - use repositories with encryption')
  Future<bool> needsMigration() async {
    // Always return false - migration should have already occurred before encryption schema update
    return false;
  }
}
