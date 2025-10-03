import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle post-login data migrations
///
/// This service runs automatically after a user successfully logs in to
/// complete any deferred data migrations that require an authenticated user.
///
/// Use case: SavedSearch userId population when user logs in after app startup
class PostLoginMigrationService {
  final AppDb db;
  final SupabaseClient supabase;
  final AppLogger logger;

  PostLoginMigrationService({
    required this.db,
    required this.supabase,
    required this.logger,
  });

  /// Run all post-login migrations
  ///
  /// This should be called immediately after successful user authentication.
  /// Returns a list of migration results for all migrations that were run.
  Future<List<PostLoginMigrationResult>> runPostLoginMigrations(
    String userId,
  ) async {
    final results = <PostLoginMigrationResult>[];

    // 1. SavedSearch userId migration
    try {
      final savedSearchResult = await _runSavedSearchMigration(userId);
      results.add(savedSearchResult);
    } catch (e, stackTrace) {
      logger.error(
        'Post-login migration: SavedSearch migration failed',
        error: e,
        stackTrace: stackTrace,
      );
      results.add(PostLoginMigrationResult(
        migrationType: PostLoginMigrationType.savedSearches,
        success: false,
        message: 'SavedSearch migration failed: ${e.toString()}',
      ));
    }

    // Future migrations can be added here
    // 2. Other migrations...

    // Log summary
    final successCount = results.where((r) => r.success).length;
    final totalCount = results.length;

    logger.info(
      'Post-login migrations completed',
      data: {
        'userId': userId,
        'totalMigrations': totalCount,
        'successful': successCount,
        'failed': totalCount - successCount,
      },
    );

    return results;
  }

  /// Run SavedSearch migration for the logged-in user
  Future<PostLoginMigrationResult> _runSavedSearchMigration(
    String userId,
  ) async {
    final migrationService = SavedSearchMigrationService(
      db: db,
      supabase: supabase,
      logger: logger,
    );

    final isMigrationNeeded = await migrationService.isMigrationNeeded();

    if (!isMigrationNeeded) {
      return PostLoginMigrationResult(
        migrationType: PostLoginMigrationType.savedSearches,
        success: true,
        message: 'No SavedSearch migration needed',
        itemsProcessed: 0,
      );
    }

    final result = await migrationService.migrateForUser(userId);

    return PostLoginMigrationResult(
      migrationType: PostLoginMigrationType.savedSearches,
      success: result.isSuccess,
      message: result.message,
      itemsProcessed: result.searchesProcessed,
    );
  }

  /// Check if any post-login migrations are pending
  Future<bool> hasPendingMigrations() async {
    // Check SavedSearch migration
    final savedSearchService = SavedSearchMigrationService(
      db: db,
      supabase: supabase,
      logger: logger,
    );

    final savedSearchNeedsMigration = await savedSearchService.isMigrationNeeded();

    // Add checks for other migrations here
    // final otherMigrationNeeded = await ...;

    return savedSearchNeedsMigration; // || otherMigrationNeeded;
  }

  /// Get count of pending migration items
  Future<int> getPendingMigrationCount() async {
    int count = 0;

    // Count SavedSearches needing migration
    final savedSearchService = SavedSearchMigrationService(
      db: db,
      supabase: supabase,
      logger: logger,
    );
    count += await savedSearchService.getSearchesNeedingMigration();

    // Add counts for other migrations here
    // count += await otherService.getItemsNeedingMigration();

    return count;
  }
}

/// Result of a post-login migration operation
class PostLoginMigrationResult {
  final PostLoginMigrationType migrationType;
  final bool success;
  final String message;
  final int? itemsProcessed;

  PostLoginMigrationResult({
    required this.migrationType,
    required this.success,
    required this.message,
    this.itemsProcessed,
  });

  @override
  String toString() {
    return 'PostLoginMigrationResult('
        'type: ${migrationType.name}, '
        'success: $success, '
        'items: $itemsProcessed, '
        'message: $message)';
  }
}

/// Types of post-login migrations
enum PostLoginMigrationType {
  savedSearches,
  // Future migration types can be added here
  // folders,
  // templates,
  // notes,
}
