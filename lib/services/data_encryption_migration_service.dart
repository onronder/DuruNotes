import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/fts_service.dart';

/// DEPRECATED: This migration service is obsolete after schema migration.
///
/// The database schema has been updated to remove plaintext columns
/// (title, body, content, labels, notes) and replace them with encrypted
/// equivalents (titleEncrypted, bodyEncrypted, contentEncrypted, etc.).
///
/// This service tried to migrate FROM plaintext TO encrypted, but since
/// plaintext columns no longer exist, it cannot function.
///
/// The migration was completed via database schema migration
/// (migration_12_phase3_optimization.dart) which:
/// 1. Added encrypted columns
/// 2. Migrated data from plaintext to encrypted
/// 3. Dropped plaintext columns
///
/// Any code attempting to use this service should be updated to work
/// directly with encrypted data via the repository layer.
@Deprecated('Migration completed via schema - this service is obsolete')
class DataEncryptionMigrationService {
  DataEncryptionMigrationService({
    required this.db,
    required this.crypto,
    required this.ftsService,
    this.batchSize = 100,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final CryptoBox crypto;
  final FtsService ftsService;
  final int batchSize;
  final AppLogger _logger;

  /// Migration result with comprehensive metrics
  MigrationResult? _lastResult;

  /// Get the last migration result
  MigrationResult? get lastResult => _lastResult;

  /// Execute full migration with all safety features
  @Deprecated('Migration already completed via schema')
  Future<MigrationResult> executeMigration({
    required String userId,
    bool dryRun = false,
    bool skipBackup = false,
    bool verifyOnly = false,
  }) async {
    _logger.warning('DataEncryptionMigrationService is deprecated - migration completed via schema');
    return MigrationResult(
      status: MigrationStatus.alreadyComplete,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      userId: userId,
      message: 'Migration already completed via database schema migration_12_phase3_optimization.dart',
    );
  }

  /// Rollback migration using backup
  @Deprecated('No rollback needed - migration completed via schema')
  Future<bool> rollback(String backupPath) async {
    _logger.warning('Rollback not supported - migration completed via schema');
    return false;
  }
}

/// Migration result
class MigrationResult {
  final MigrationStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final String userId;
  final String? backupPath;
  final String? message;
  final Map<String, dynamic>? metrics;

  MigrationResult({
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.userId,
    this.backupPath,
    this.message,
    this.metrics,
  });

  int get totalSuccessful => 0;
  int get totalFailures => 0;
  bool get isSuccess => status == MigrationStatus.success || status == MigrationStatus.alreadyComplete;
}

/// Migration status
enum MigrationStatus {
  notStarted,
  inProgress,
  success,
  failed,
  rolledBack,
  dryRunComplete,
  alreadyComplete,
}
