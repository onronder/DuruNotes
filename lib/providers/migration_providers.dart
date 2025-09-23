import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/migration/unified_migration_coordinator.dart';
import 'package:duru_notes/data/migrations/migration_tables_setup.dart';
import 'package:duru_notes/providers.dart';

/// Provider for the unified migration coordinator
final migrationCoordinatorProvider = Provider<UnifiedMigrationCoordinator>((ref) {
  final appDb = ref.watch(appDbProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final logger = ref.watch(loggerProvider);

  return UnifiedMigrationCoordinator(
    localDb: appDb,
    supabaseClient: supabaseClient,
    logger: logger,
  );
});

/// Provider for migration status monitoring
final migrationStatusProvider = FutureProvider<MigrationStatus>((ref) async {
  final coordinator = ref.watch(migrationCoordinatorProvider);
  return coordinator.getCurrentStatus();
});

/// Provider for migration history
final migrationHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appDb = ref.watch(appDbProvider);

  // Ensure migration tables exist first
  await MigrationTablesSetup.ensureMigrationTables(appDb);

  return MigrationTablesSetup.getMigrationHistory(appDb);
});

/// Provider for checking if Phase 3 migration is needed
final needsPhase3MigrationProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(migrationStatusProvider.future);
  return status.needsMigration;
});

/// Provider for migration table integrity check
final migrationTablesIntegrityProvider = FutureProvider<bool>((ref) async {
  final appDb = ref.watch(appDbProvider);
  return MigrationTablesSetup.verifyMigrationTables(appDb);
});

/// State notifier for managing migration execution
class MigrationExecutionNotifier extends StateNotifier<AsyncValue<MigrationResult?>> {
  final UnifiedMigrationCoordinator _coordinator;

  MigrationExecutionNotifier(this._coordinator) : super(const AsyncValue.data(null));

  /// Execute Phase 3 migration
  Future<void> executePhase3Migration({
    bool dryRun = false,
    bool skipRemote = false,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await _coordinator.executePhase3Migration(
        dryRun: dryRun,
        skipRemote: skipRemote,
      );

      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Reset state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for migration execution state management
final migrationExecutionProvider = StateNotifierProvider<MigrationExecutionNotifier, AsyncValue<MigrationResult?>>((ref) {
  final coordinator = ref.watch(migrationCoordinatorProvider);
  return MigrationExecutionNotifier(coordinator);
});

/// Provider for initialization of migration tables
final migrationTablesInitProvider = FutureProvider<void>((ref) async {
  final appDb = ref.watch(appDbProvider);

  await MigrationTablesSetup.ensureMigrationTables(appDb);
  await MigrationTablesSetup.seedInitialMigrationData(appDb);
});

/// Provider for migration backup cleanup
final migrationBackupCleanupProvider = FutureProvider.family<int, int>((ref, keepDays) async {
  final appDb = ref.watch(appDbProvider);
  return MigrationTablesSetup.cleanupOldBackups(appDb, keepDays: keepDays);
});

/// Provider for specific migration sync status
final migrationSyncStatusProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, version) async {
  final appDb = ref.watch(appDbProvider);

  // Ensure migration tables exist
  await MigrationTablesSetup.ensureMigrationTables(appDb);

  return MigrationTablesSetup.getCurrentSyncStatus(appDb, version);
});