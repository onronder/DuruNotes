import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/services/data_encryption_migration_service.dart';
import 'package:duru_notes/services/providers/fts_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the data encryption migration service
///
/// This service handles migrating plaintext data to encrypted format
/// with production-grade safety features:
/// - Automatic backups
/// - Batch processing
/// - Progress tracking
/// - Rollback capability
/// - Comprehensive validation
final dataEncryptionMigrationServiceProvider =
    Provider<DataEncryptionMigrationService>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final ftsService = ref.watch(ftsServiceProvider);

  return DataEncryptionMigrationService(
    db: db,
    crypto: crypto,
    ftsService: ftsService,
    batchSize: 100, // Default batch size
  );
});

/// Provider for migration service with custom batch size
Provider<DataEncryptionMigrationService> dataEncryptionMigrationServiceWithBatchSize(
  int batchSize,
) {
  return Provider<DataEncryptionMigrationService>((ref) {
    final db = ref.watch(appDbProvider);
    final crypto = ref.watch(cryptoBoxProvider);
    final ftsService = ref.watch(ftsServiceProvider);

    return DataEncryptionMigrationService(
      db: db,
      crypto: crypto,
      ftsService: ftsService,
      batchSize: batchSize,
    );
  });
}
