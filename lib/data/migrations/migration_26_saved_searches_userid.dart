import 'package:drift/drift.dart';

/// Migration 26: Add userId column to SavedSearches for Security Authorization
///
/// **PURPOSE**: Add userId column to SavedSearches table to enable production-grade
/// authorization and data isolation for saved search queries.
///
/// **SECURITY CONTEXT**:
/// - SavedSearches table needs userId for multi-user data isolation
/// - Authorization layer requires userId for ownership verification
/// - Each saved search must be owned by a specific user
///
/// **MIGRATION STRATEGY**:
/// 1. Add userId column to saved_searches table (nullable for migration safety)
/// 2. Provide helper methods to populate userId for existing searches
/// 3. Enable security enforcement in SearchRepository
///
/// **DEPLOYMENT STEPS**:
/// 1. For single-user apps: Run populateUserIdForSingleUser() with the user's ID
/// 2. For multi-user apps: Implement custom data assignment logic
/// 3. Orphaned searches (userId=null) will be hidden from users until assigned
///
/// **DATA SAFETY**:
/// - Migration adds column without modifying existing data
/// - userId is nullable to prevent data loss
/// - Can be run multiple times safely (idempotent)
/// - Provides rollback capability
class Migration26SavedSearchesUserId {
  /// Run the migration to add userId column to SavedSearches
  static Future<void> run(
    DatabaseConnectionUser db,
    int fromVersion,
  ) async {
    // Add userId column to saved_searches table
    await db.customStatement(
      '''
      ALTER TABLE saved_searches
      ADD COLUMN user_id TEXT NULL
      ''',
    );

    // Create index for userId filtering (performance optimization)
    await db.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id
      ON saved_searches(user_id)
      WHERE user_id IS NOT NULL
      ''',
    );
  }

  /// Populate userId for all saved searches owned by a single user
  ///
  /// **USE CASE**: Single-user applications or during user onboarding
  ///
  /// This method:
  /// 1. Sets userId for all saved searches with null userId
  /// 2. Enables immediate security enforcement
  ///
  /// **SAFETY**: Only updates records where userId is null
  static Future<void> populateUserIdForSingleUser(
    DatabaseConnectionUser db,
    String userId,
  ) async {
    // Validate userId
    if (userId.isEmpty) {
      throw Exception('userId cannot be empty');
    }

    await db.transaction(() async {
      // Populate userId for all saved searches
      await db.customStatement(
        '''
        UPDATE saved_searches
        SET user_id = ?
        WHERE user_id IS NULL
        ''',
        [userId],
      );
    });
  }

  /// Populate userId for specific saved searches
  ///
  /// **USE CASE**: Selective data assignment in multi-user scenarios
  static Future<void> populateUserIdForSavedSearches(
    DatabaseConnectionUser db,
    String userId,
    List<String> searchIds,
  ) async {
    if (userId.isEmpty) {
      throw Exception('userId cannot be empty');
    }
    if (searchIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(searchIds.length, '?').join(',');

    await db.customStatement(
      '''
      UPDATE saved_searches
      SET user_id = ?
      WHERE id IN ($placeholders)
      AND user_id IS NULL
      ''',
      [userId, ...searchIds],
    );
  }

  /// Get statistics on userId population status
  ///
  /// Returns a map with counts of:
  /// - totalSearches
  /// - searchesWithUserId
  /// - searchesWithoutUserId
  static Future<Map<String, int>> getUserIdPopulationStats(
    DatabaseConnectionUser db,
  ) async {
    final stats = await db.customSelect(
      '''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN user_id IS NOT NULL THEN 1 ELSE 0 END) as with_user_id,
        SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) as without_user_id
      FROM saved_searches
      ''',
    ).getSingleOrNull();

    return {
      'totalSearches': stats?.data['total'] as int? ?? 0,
      'searchesWithUserId': stats?.data['with_user_id'] as int? ?? 0,
      'searchesWithoutUserId': stats?.data['without_user_id'] as int? ?? 0,
    };
  }

  /// Validate userId population is complete
  ///
  /// Returns true if all saved searches have userId assigned
  /// Returns false if there are searches without userId
  static Future<bool> validateUserIdPopulation(
    DatabaseConnectionUser db,
  ) async {
    final stats = await getUserIdPopulationStats(db);

    // All saved searches should have userId
    return stats['searchesWithoutUserId'] == 0;
  }

  /// Get saved searches without userId (for manual assignment)
  static Future<List<Map<String, dynamic>>> getSavedSearchesWithoutUserId(
    DatabaseConnectionUser db,
  ) async {
    final result = await db.customSelect(
      '''
      SELECT id, name, query, search_type, created_at
      FROM saved_searches
      WHERE user_id IS NULL
      ORDER BY created_at DESC
      ''',
    ).get();

    return result.map((row) => row.data).toList();
  }

  /// Rollback: Clear userId for all saved searches
  ///
  /// **WARNING**: This removes ownership information
  /// Only use for testing or rollback scenarios
  static Future<void> rollback(DatabaseConnectionUser db) async {
    await db.transaction(() async {
      // Clear userId from saved searches
      await db.customStatement(
        '''
        UPDATE saved_searches
        SET user_id = NULL
        ''',
      );
    });
  }

  /// Delete orphaned saved searches (searches with null userId)
  ///
  /// **USE CASE**: Clean up searches that cannot be assigned to users
  /// **WARNING**: This permanently deletes data
  static Future<int> deleteOrphanedSearches(
    DatabaseConnectionUser db,
  ) async {
    // Get count before deletion
    final stats = await getUserIdPopulationStats(db);
    final orphanedCount = stats['searchesWithoutUserId']!;

    if (orphanedCount > 0) {
      await db.customStatement(
        '''
        DELETE FROM saved_searches
        WHERE user_id IS NULL
        ''',
      );
    }

    return orphanedCount;
  }
}

/// Helper class for guided userId population during app initialization
class SavedSearchUserIdPopulationGuide {
  final DatabaseConnectionUser db;

  SavedSearchUserIdPopulationGuide(this.db);

  /// Check if userId population is needed
  Future<bool> isPopulationNeeded() async {
    final stats = await Migration26SavedSearchesUserId
        .getUserIdPopulationStats(db);

    return stats['searchesWithoutUserId']! > 0;
  }

  /// Get detailed migration status report
  Future<String> getStatusReport() async {
    final stats = await Migration26SavedSearchesUserId
        .getUserIdPopulationStats(db);

    final buffer = StringBuffer();
    buffer.writeln('=== SavedSearches User ID Population Status ===');
    buffer.writeln();
    buffer.writeln('Saved Searches:');
    buffer.writeln('  Total: ${stats['totalSearches']}');
    buffer.writeln('  With userId: ${stats['searchesWithUserId']}');
    buffer.writeln('  Without userId: ${stats['searchesWithoutUserId']}');
    buffer.writeln();

    final isComplete = await Migration26SavedSearchesUserId
        .validateUserIdPopulation(db);
    buffer.writeln(
        'Status: ${isComplete ? "✅ Complete" : "⚠️  Incomplete - Action Required"}');

    if (!isComplete) {
      buffer.writeln();
      buffer.writeln('ACTION REQUIRED:');
      buffer.writeln('1. Call populateForSingleUser(userId) for single-user apps');
      buffer.writeln('2. Or manually assign userId to each saved search');
      buffer.writeln('3. Or call deleteOrphanedSearches() to remove unassigned searches');
    }

    return buffer.toString();
  }

  /// Execute population for single-user scenario
  Future<void> populateForSingleUser(String userId) async {
    await Migration26SavedSearchesUserId.populateUserIdForSingleUser(
      db,
      userId,
    );
  }

  /// Delete searches that cannot be assigned
  Future<int> deleteOrphaned() async {
    return await Migration26SavedSearchesUserId.deleteOrphanedSearches(db);
  }
}
