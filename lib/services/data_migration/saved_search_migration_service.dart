import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle automatic population of userId for SavedSearches
///
/// This service runs during app initialization to ensure all saved searches
/// are associated with the correct user. It implements intelligent logic
/// to handle various scenarios:
/// - Single-user apps: Auto-assign to the logged-in user
/// - Multi-user apps: Preserve existing assignments, prompt for unassigned
/// - No user logged in: Skip migration until user logs in
class SavedSearchMigrationService {
  final AppDb db;
  final SupabaseClient? supabase;
  final AppLogger logger;

  SavedSearchMigrationService({
    required this.db,
    required this.supabase,
    required this.logger,
  });

  /// Run automatic migration during app startup
  ///
  /// Returns true if migration was successful or not needed
  /// Returns false if migration is needed but cannot be completed
  Future<SavedSearchMigrationResult> runAutoMigration() async {
    try {
      // Check if migration is needed
      final stats = await Migration26SavedSearchesUserId
          .getUserIdPopulationStats(db);

      final totalSearches = stats['totalSearches'] ?? 0;
      final searchesWithoutUserId = stats['searchesWithoutUserId'] ?? 0;

      // No saved searches at all - migration not needed
      if (totalSearches == 0) {
        logger.info('SavedSearch migration: No saved searches found');
        return SavedSearchMigrationResult(
          status: MigrationStatus.notNeeded,
          searchesProcessed: 0,
          message: 'No saved searches to migrate',
        );
      }

      // All searches already have userId - migration complete
      if (searchesWithoutUserId == 0) {
        logger.info(
          'SavedSearch migration: All searches already have userId',
          data: {'totalSearches': totalSearches},
        );
        return SavedSearchMigrationResult(
          status: MigrationStatus.complete,
          searchesProcessed: 0,
          message: 'All saved searches already have userId assigned',
        );
      }

      // Get current authenticated user
      final currentUser = supabase?.auth.currentUser;

      if (currentUser == null) {
        logger.warning(
          'SavedSearch migration: User not logged in, migration deferred',
          data: {'searchesWithoutUserId': searchesWithoutUserId},
        );
        return SavedSearchMigrationResult(
          status: MigrationStatus.deferred,
          searchesProcessed: 0,
          message: 'Please log in to complete saved search migration',
          searchesNeedingMigration: searchesWithoutUserId,
        );
      }

      // User is logged in - assign all unassigned searches to this user
      logger.info(
        'SavedSearch migration: Assigning $searchesWithoutUserId searches to user ${currentUser.id}',
        data: {
          'userId': currentUser.id,
          'searchesToMigrate': searchesWithoutUserId,
        },
      );

      await Migration26SavedSearchesUserId.populateUserIdForSingleUser(
        db,
        currentUser.id,
      );

      // Verify migration completed
      final verificationStats = await Migration26SavedSearchesUserId
          .getUserIdPopulationStats(db);
      final remainingWithoutUserId = verificationStats['searchesWithoutUserId'] ?? 0;

      if (remainingWithoutUserId > 0) {
        logger.error(
          'SavedSearch migration: Migration incomplete',
          data: {
            'expected': 0,
            'actual': remainingWithoutUserId,
          },
        );
        return SavedSearchMigrationResult(
          status: MigrationStatus.failed,
          searchesProcessed: searchesWithoutUserId - remainingWithoutUserId,
          message: 'Migration partially completed',
          searchesNeedingMigration: remainingWithoutUserId,
        );
      }

      logger.info(
        'SavedSearch migration: Successfully migrated $searchesWithoutUserId searches',
        data: {'userId': currentUser.id},
      );

      return SavedSearchMigrationResult(
        status: MigrationStatus.success,
        searchesProcessed: searchesWithoutUserId,
        message: 'Successfully migrated $searchesWithoutUserId saved searches',
      );
    } catch (e, stackTrace) {
      logger.error(
        'SavedSearch migration: Unexpected error',
        error: e,
        stackTrace: stackTrace,
      );
      return SavedSearchMigrationResult(
        status: MigrationStatus.failed,
        searchesProcessed: 0,
        message: 'Migration failed: ${e.toString()}',
      );
    }
  }

  /// Get detailed migration status report
  Future<String> getStatusReport() async {
    final guide = SavedSearchUserIdPopulationGuide(db);
    return await guide.getStatusReport();
  }

  /// Check if migration is needed
  Future<bool> isMigrationNeeded() async {
    final stats = await Migration26SavedSearchesUserId
        .getUserIdPopulationStats(db);
    return (stats['searchesWithoutUserId'] ?? 0) > 0;
  }

  /// Get count of searches needing migration
  Future<int> getSearchesNeedingMigration() async {
    final stats = await Migration26SavedSearchesUserId
        .getUserIdPopulationStats(db);
    return stats['searchesWithoutUserId'] ?? 0;
  }

  /// Manually trigger migration for a specific user
  /// Use case: User logs in after app launch
  Future<SavedSearchMigrationResult> migrateForUser(String userId) async {
    try {
      if (userId.isEmpty) {
        return SavedSearchMigrationResult(
          status: MigrationStatus.failed,
          searchesProcessed: 0,
          message: 'Invalid userId provided',
        );
      }

      final searchesNeedingMigration = await getSearchesNeedingMigration();

      if (searchesNeedingMigration == 0) {
        return SavedSearchMigrationResult(
          status: MigrationStatus.notNeeded,
          searchesProcessed: 0,
          message: 'No searches need migration',
        );
      }

      await Migration26SavedSearchesUserId.populateUserIdForSingleUser(
        db,
        userId,
      );

      logger.info(
        'SavedSearch migration: Manually migrated searches for user',
        data: {
          'userId': userId,
          'searchesMigrated': searchesNeedingMigration,
        },
      );

      return SavedSearchMigrationResult(
        status: MigrationStatus.success,
        searchesProcessed: searchesNeedingMigration,
        message: 'Successfully migrated $searchesNeedingMigration saved searches',
      );
    } catch (e, stackTrace) {
      logger.error(
        'SavedSearch migration: Manual migration failed',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SavedSearchMigrationResult(
        status: MigrationStatus.failed,
        searchesProcessed: 0,
        message: 'Migration failed: ${e.toString()}',
      );
    }
  }

  /// Delete orphaned searches (searches without userId)
  /// WARNING: This permanently deletes data
  Future<SavedSearchMigrationResult> deleteOrphanedSearches() async {
    try {
      final count = await Migration26SavedSearchesUserId
          .deleteOrphanedSearches(db);

      logger.warning(
        'SavedSearch migration: Deleted orphaned searches',
        data: {'count': count},
      );

      return SavedSearchMigrationResult(
        status: MigrationStatus.success,
        searchesProcessed: count,
        message: 'Deleted $count orphaned saved searches',
      );
    } catch (e, stackTrace) {
      logger.error(
        'SavedSearch migration: Failed to delete orphaned searches',
        error: e,
        stackTrace: stackTrace,
      );
      return SavedSearchMigrationResult(
        status: MigrationStatus.failed,
        searchesProcessed: 0,
        message: 'Failed to delete orphaned searches: ${e.toString()}',
      );
    }
  }
}

/// Result of a saved search migration operation
class SavedSearchMigrationResult {
  final MigrationStatus status;
  final int searchesProcessed;
  final String message;
  final int? searchesNeedingMigration;

  SavedSearchMigrationResult({
    required this.status,
    required this.searchesProcessed,
    required this.message,
    this.searchesNeedingMigration,
  });

  bool get isSuccess => status == MigrationStatus.success;
  bool get isComplete => status == MigrationStatus.complete;
  bool get needsUserAction => status == MigrationStatus.deferred;
  bool get hasFailed => status == MigrationStatus.failed;
}

/// Status of the saved search migration
enum MigrationStatus {
  /// Migration completed successfully
  success,

  /// Migration not needed (no searches to migrate)
  notNeeded,

  /// Migration already complete (all searches have userId)
  complete,

  /// Migration deferred (waiting for user to log in)
  deferred,

  /// Migration failed
  failed,
}
