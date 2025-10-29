import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 27: Add encryption to templates table
///
/// CRITICAL SECURITY FIX:
/// - Templates were stored in plaintext but remote expects encryption
/// - This migration adds encrypted columns and migrates existing data
/// - Required for zero-knowledge architecture compliance
class Migration27EncryptTemplates {
  static Future<void> run(Migrator m) async {
    final logger = LoggerFactory.instance;
    logger.info('[Migration 27] Starting template encryption migration');

    try {
      // Step 1: Add encrypted columns to local_templates table
      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN title_encrypted TEXT NOT NULL DEFAULT ''
      ''');

      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN body_encrypted TEXT NOT NULL DEFAULT ''
      ''');

      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN tags_encrypted TEXT
      ''');

      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN description_encrypted TEXT
      ''');

      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN metadata_encrypted TEXT
      ''');

      await m.database.customStatement('''
        ALTER TABLE local_templates
        ADD COLUMN encryption_version INTEGER NOT NULL DEFAULT 1
      ''');

      logger.info('[Migration 27] Added encrypted columns to templates table');

      // Step 2: Mark existing data as requiring encryption
      // We cannot encrypt here as we don't have access to CryptoBox in migrations
      // The app will need to encrypt on first launch after migration
      await m.database.customStatement('''
        UPDATE local_templates
        SET encryption_version = 0
        WHERE title_encrypted = ''
      ''');

      // Step 3: Create trigger to prevent unencrypted inserts (after migration)
      await m.database.customStatement('''
        CREATE TRIGGER IF NOT EXISTS enforce_template_encryption
        BEFORE INSERT ON local_templates
        FOR EACH ROW
        WHEN NEW.encryption_version > 0 AND (
          NEW.title_encrypted = '' OR
          NEW.body_encrypted = ''
        )
        BEGIN
          SELECT RAISE(FAIL, 'Templates must be encrypted before insertion');
        END
      ''');

      // Step 4: Add index for efficient queries
      await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_templates_encryption_version
        ON local_templates(encryption_version)
      ''');

      // Step 5: Log migration status
      final unencryptedCount = await m.database.customSelect('''
        SELECT COUNT(*) as count
        FROM local_templates
        WHERE encryption_version = 0
      ''').getSingle();

      final count = unencryptedCount.read<int>('count');
      if (count > 0) {
        logger.warning(
          '[Migration 27] Found $count templates requiring encryption. '
          'These will be encrypted on next app launch.',
        );
      }

      logger.info('[Migration 27] Template encryption migration completed successfully');

    } catch (e, stack) {
      logger.error(
        '[Migration 27] Failed to add template encryption',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Post-migration encryption task
  /// This should be called from the app after migration completes
  /// when CryptoBox is available
  static Future<void> encryptExistingTemplates({
    required dynamic db,
    required dynamic crypto,
  }) async {
    final logger = LoggerFactory.instance;

    try {
      // Get all templates that need encryption
      final unencryptedTemplates = await db.customSelect('''
        SELECT id, title, body, tags, description, metadata
        FROM local_templates
        WHERE encryption_version = 0
      ''').get() as List<dynamic>;

      logger.info(
        '[Template Encryption] Found ${unencryptedTemplates.length} templates to encrypt',
      );

      for (final template in unencryptedTemplates) {
        final id = template.read<String>('id');
        final title = template.read<String?>('title') ?? '';
        final body = template.read<String?>('body') ?? '';
        final tags = template.read<String?>('tags');
        final description = template.read<String?>('description');
        final metadata = template.read<String?>('metadata');

        // Encrypt fields using CryptoBox
        // Note: This is pseudocode - adapt to your actual crypto implementation
        final titleEnc = await crypto.encryptStringForNote(
          userId: 'system', // Templates might be system-wide
          noteId: id,
          text: title,
        );

        final bodyEnc = await crypto.encryptStringForNote(
          userId: 'system',
          noteId: id,
          text: body,
        );

        final tagsEnc = tags != null
            ? await crypto.encryptStringForNote(
                userId: 'system',
                noteId: id,
                text: tags,
              )
            : null;

        final descriptionEnc = description != null
            ? await crypto.encryptStringForNote(
                userId: 'system',
                noteId: id,
                text: description,
              )
            : null;

        final metadataEnc = metadata != null
            ? await crypto.encryptStringForNote(
                userId: 'system',
                noteId: id,
                text: metadata,
              )
            : null;

        // Update template with encrypted data
        await db.customUpdate('''
          UPDATE local_templates
          SET
            title_encrypted = ?,
            body_encrypted = ?,
            tags_encrypted = ?,
            description_encrypted = ?,
            metadata_encrypted = ?,
            encryption_version = 1
          WHERE id = ?
        ''', [
          titleEnc,
          bodyEnc,
          tagsEnc,
          descriptionEnc,
          metadataEnc,
          id,
        ]);

        logger.debug('[Template Encryption] Encrypted template: $id');
      }

      // After successful encryption, we could drop the plaintext columns
      // But keeping them for now as fallback (can be removed in future migration)

      logger.info(
        '[Template Encryption] Successfully encrypted ${unencryptedTemplates.length} templates',
      );

    } catch (e, stack) {
      logger.error(
        '[Template Encryption] Failed to encrypt existing templates',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Template encryption failed: $e');
    }
  }
}