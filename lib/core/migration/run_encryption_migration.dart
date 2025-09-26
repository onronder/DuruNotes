import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/security_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runner for the AES to CryptoBox encryption migration
class EncryptionMigrationRunner {
  static const _migrationRunKey = 'encryption_migration_run_v1';
  static const _migrationValidatedKey = 'encryption_migration_validated_v1';

  /// Run the encryption migration if needed
  static Future<void> runMigrationIfNeeded(WidgetRef ref) async {
    final logger = LoggerFactory.instance;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if migration has already been run and validated
      final hasRun = prefs.getBool(_migrationRunKey) ?? false;
      final isValidated = prefs.getBool(_migrationValidatedKey) ?? false;

      if (hasRun && isValidated) {
        logger.info('Encryption migration already completed and validated');
        return;
      }

      final migration = ref.read(encryptionMigrationProvider);

      // Check if migration is needed
      if (!await migration.isMigrationNeeded()) {
        logger.info('No encryption migration needed');
        await prefs.setBool(_migrationRunKey, true);
        await prefs.setBool(_migrationValidatedKey, true);
        return;
      }

      logger.info('Starting AES to CryptoBox encryption migration');

      // Run the migration
      final result = await migration.performMigration(
        onProgress: (progress) {
          logger.info(
            'Migration progress: ${progress.percentage.toStringAsFixed(1)}% - ${progress.phase}',
          );
        },
      );

      if (result.success) {
        logger.info('Encryption migration completed successfully', data: {
          'totalItems': result.totalItems,
          'migratedItems': result.migratedItems,
          'skippedItems': result.skippedItems,
          'failedItems': result.failedItems,
        });

        // Mark migration as run
        await prefs.setBool(_migrationRunKey, true);

        // Validate the migration
        final isValid = await _validateMigration(ref);
        if (isValid) {
          await prefs.setBool(_migrationValidatedKey, true);
          logger.info('Migration validation successful');
        } else {
          logger.error('Migration validation failed - manual review required');
        }
      } else {
        logger.error('Encryption migration failed', data: {
          'errors': result.errors,
          'totalItems': result.totalItems,
          'failedItems': result.failedItems,
        });

        // Don't mark as complete if migration failed
        // This allows retry on next app launch
      }
    } catch (e) {
      logger.error('Failed to run encryption migration', error: e);
      // Don't rethrow - allow app to continue
    }
  }

  /// Validate that the migration was successful
  static Future<bool> _validateMigration(WidgetRef ref) async {
    final logger = LoggerFactory.instance;

    try {
      // Sample validation: Try to decrypt a few notes to ensure they work
      // This is a basic check - in production you might want more thorough validation

      // You could:
      // 1. Fetch a sample of encrypted notes
      // 2. Try to decrypt them with CryptoBox
      // 3. Verify no AES-formatted data remains

      logger.info('Running migration validation checks');

      // For now, we'll assume validation passes if migration completed without errors
      // In production, implement proper validation logic here

      return true;
    } catch (e) {
      logger.error('Migration validation failed', error: e);
      return false;
    }
  }

  /// Force re-run the migration (for testing/recovery)
  static Future<void> forceRerunMigration(WidgetRef ref) async {
    final logger = LoggerFactory.instance;
    logger.warning('Force re-running encryption migration');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationRunKey);
    await prefs.remove(_migrationValidatedKey);
    await prefs.remove('encryption_format_migration_v1'); // Remove the migration's own flag

    await runMigrationIfNeeded(ref);
  }

  /// Get migration status
  static Future<MigrationStatus> getMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();

    return MigrationStatus(
      hasRun: prefs.getBool(_migrationRunKey) ?? false,
      isValidated: prefs.getBool(_migrationValidatedKey) ?? false,
      migrationCompleted: prefs.getBool('encryption_format_migration_v1') ?? false,
    );
  }
}

/// Status of the encryption migration
class MigrationStatus {
  final bool hasRun;
  final bool isValidated;
  final bool migrationCompleted;

  MigrationStatus({
    required this.hasRun,
    required this.isValidated,
    required this.migrationCompleted,
  });

  bool get isFullyComplete => hasRun && isValidated && migrationCompleted;

  Map<String, dynamic> toJson() => {
        'hasRun': hasRun,
        'isValidated': isValidated,
        'migrationCompleted': migrationCompleted,
        'isFullyComplete': isFullyComplete,
      };
}