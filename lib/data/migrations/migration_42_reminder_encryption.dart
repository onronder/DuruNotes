import 'package:flutter/foundation.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Migration 42: Add Encryption to Reminders (Security Fix)
///
/// **Problem:** Reminders are currently stored in PLAINTEXT, exposing:
/// - Reminder titles (e.g., "Doctor appointment", "Call mom")
/// - Reminder bodies (detailed notes)
/// - Location names (home address, workplace)
///
/// **Solution:** Encrypt title, body, and location_name using XChaCha20-Poly1305
///
/// **Strategy:**
/// 1. Add encrypted columns (title_encrypted, body_encrypted, location_name_encrypted)
/// 2. Keep plaintext columns temporarily for zero-downtime migration
/// 3. Encrypt all existing plaintext data
/// 4. Set encryption_version = 1 for all encrypted reminders
///
/// **Zero-Downtime Guarantee:**
/// - Old app versions continue working (read/write plaintext)
/// - New app versions prefer encrypted columns, fallback to plaintext
/// - No data loss during gradual rollout
///
/// **Rollback Safety:**
/// - Plaintext columns remain intact
/// - If encryption fails, reminder still accessible via plaintext
/// - Future migration will drop plaintext columns after 100% adoption
class Migration42ReminderEncryption {
  static final _logger = LoggerFactory.instance;

  static Future<void> apply(AppDb db) async {
    debugPrint('[Migration 42] Starting reminder encryption migration...');
    _logger.info('[Migration 42] Adding encrypted columns to reminders table');

    try {
      // Step 1: Add encrypted columns (nullable for zero-downtime migration)
      await _addEncryptedColumns(db);

      debugPrint('[Migration 42] ✅ Reminder encryption migration complete');
      debugPrint(
        '[Migration 42] Note: Encryption will happen lazily when reminders are accessed',
      );
      _logger.info(
        '[Migration 42] Successfully added encrypted columns. '
        'Data encryption will occur lazily via repository layer.',
      );

      // NOTE: Data encryption happens lazily when reminders are accessed
      // This ensures:
      // 1. Migration completes quickly (no encryption overhead)
      // 2. No dependency on user session during migration
      // 3. Zero-downtime migration (old app versions still work)
      // 4. Encryption handled by repository layer (proper separation of concerns)
    } catch (error, stack) {
      // Migration failure should not block app startup
      // Log error but allow app to continue (degraded state)
      debugPrint('[Migration 42] ❌ ERROR: $error');
      _logger.error(
        '[Migration 42] Migration failed',
        error: error,
        stackTrace: stack,
      );

      // Rethrow to prevent marking migration as complete
      // This ensures migration will retry on next app restart
      rethrow;
    }
  }

  /// Step 1: Add encrypted columns to note_reminders table
  static Future<void> _addEncryptedColumns(AppDb db) async {
    debugPrint('[Migration 42] Adding encrypted columns...');

    // Add title_encrypted column
    await db.customStatement(
      'ALTER TABLE note_reminders ADD COLUMN title_encrypted BLOB',
    );

    // Add body_encrypted column
    await db.customStatement(
      'ALTER TABLE note_reminders ADD COLUMN body_encrypted BLOB',
    );

    // Add location_name_encrypted column
    await db.customStatement(
      'ALTER TABLE note_reminders ADD COLUMN location_name_encrypted BLOB',
    );

    // Add encryption_version column
    await db.customStatement(
      'ALTER TABLE note_reminders ADD COLUMN encryption_version INTEGER',
    );

    // Create index for encryption version (helps track migration progress)
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_encryption_version '
      'ON note_reminders(encryption_version) WHERE encryption_version IS NOT NULL',
    );

    debugPrint('[Migration 42] ✓ Encrypted columns added successfully');
  }

  /// Helper: Check migration progress (for debugging/monitoring)
  static Future<Map<String, int>> getProgress(AppDb db) async {
    try {
      final total = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders',
      ).getSingle();

      final encrypted = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders WHERE encryption_version = 1',
      ).getSingle();

      final plaintext = await db.customSelect(
        'SELECT COUNT(*) as count FROM note_reminders WHERE encryption_version IS NULL',
      ).getSingle();

      return {
        'total': total.read<int>('count'),
        'encrypted': encrypted.read<int>('count'),
        'plaintext': plaintext.read<int>('count'),
      };
    } catch (error) {
      debugPrint('[Migration 42] Failed to check progress: $error');
      return {'total': 0, 'encrypted': 0, 'plaintext': 0};
    }
  }
}
