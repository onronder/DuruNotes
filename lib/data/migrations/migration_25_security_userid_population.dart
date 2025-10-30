import 'package:drift/drift.dart';

/// Migration 25: Populate userId for Security Authorization
///
/// **PURPOSE**: Populate userId column for existing folders and templates to enable
/// production-grade authorization and data isolation.
///
/// **SECURITY CONTEXT**:
/// - Folders and Templates tables now have userId column (added in previous migrations)
/// - Authorization layer requires userId for ownership verification
/// - System templates (isSystem=true) should have userId=null
/// - User templates and folders must have valid userId
///
/// **MIGRATION STRATEGY**:
/// This migration provides helper methods to populate userId, but cannot automatically
/// assign ownership because:
/// 1. Migrations run without authentication context
/// 2. Multiple users may have data in the same database
/// 3. Ownership assignment requires business logic
///
/// **DEPLOYMENT STEPS**:
/// 1. For single-user apps: Run populateUserIdForSingleUser() with the user's ID
/// 2. For multi-user apps: Implement custom data assignment logic
/// 3. System templates are automatically marked (userId=null)
///
/// **DATA SAFETY**:
/// - Migration does not delete or modify existing data
/// - Only populates null userId values
/// - Can be run multiple times safely (idempotent)
/// - Provides rollback capability
class Migration25SecurityUserIdPopulation {
  /// Populate userId for all folders and templates owned by a single user
  ///
  /// **USE CASE**: Single-user applications or during user onboarding
  ///
  /// This method:
  /// 1. Sets userId for all folders with null userId
  /// 2. Sets userId for all user templates (isSystem=false) with null userId
  /// 3. Ensures system templates (isSystem=true) have userId=null
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
      // 1. Populate userId for folders
      await db.customStatement(
        '''
        UPDATE local_folders
        SET user_id = ?
        WHERE user_id IS NULL
        ''',
        [userId],
      );

      // 2. Populate userId for user templates (not system templates)
      await db.customStatement(
        '''
        UPDATE local_templates
        SET user_id = ?
        WHERE user_id IS NULL
        AND is_system = 0
        ''',
        [userId],
      );

      // 3. Ensure system templates have userId = null
      await db.customStatement('''
        UPDATE local_templates
        SET user_id = NULL
        WHERE is_system = 1
        ''');
    });
  }

  /// Populate userId for specific folders
  ///
  /// **USE CASE**: Selective data assignment in multi-user scenarios
  static Future<void> populateUserIdForFolders(
    DatabaseConnectionUser db,
    String userId,
    List<String> folderIds,
  ) async {
    if (userId.isEmpty) {
      throw Exception('userId cannot be empty');
    }
    if (folderIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(folderIds.length, '?').join(',');

    await db.customStatement(
      '''
      UPDATE local_folders
      SET user_id = ?
      WHERE id IN ($placeholders)
      AND user_id IS NULL
      ''',
      [userId, ...folderIds],
    );
  }

  /// Populate userId for specific templates
  ///
  /// **USE CASE**: Selective data assignment in multi-user scenarios
  static Future<void> populateUserIdForTemplates(
    DatabaseConnectionUser db,
    String userId,
    List<String> templateIds,
  ) async {
    if (userId.isEmpty) {
      throw Exception('userId cannot be empty');
    }
    if (templateIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(templateIds.length, '?').join(',');

    await db.customStatement(
      '''
      UPDATE local_templates
      SET user_id = ?
      WHERE id IN ($placeholders)
      AND user_id IS NULL
      AND is_system = 0
      ''',
      [userId, ...templateIds],
    );
  }

  /// Get statistics on userId population status
  ///
  /// Returns a map with counts of:
  /// - totalFolders
  /// - foldersWithUserId
  /// - foldersWithoutUserId
  /// - totalTemplates
  /// - userTemplatesWithUserId
  /// - userTemplatesWithoutUserId
  /// - systemTemplates
  static Future<Map<String, int>> getUserIdPopulationStats(
    DatabaseConnectionUser db,
  ) async {
    // Get folder stats
    final folderStats = await db.customSelect('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN user_id IS NOT NULL THEN 1 ELSE 0 END) as with_user_id,
        SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) as without_user_id
      FROM local_folders
      ''').getSingleOrNull();

    // Get template stats
    final templateStats = await db.customSelect('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN is_system = 1 THEN 1 ELSE 0 END) as system_templates,
        SUM(CASE WHEN is_system = 0 AND user_id IS NOT NULL THEN 1 ELSE 0 END) as user_with_user_id,
        SUM(CASE WHEN is_system = 0 AND user_id IS NULL THEN 1 ELSE 0 END) as user_without_user_id
      FROM local_templates
      ''').getSingleOrNull();

    return {
      'totalFolders': folderStats?.data['total'] as int? ?? 0,
      'foldersWithUserId': folderStats?.data['with_user_id'] as int? ?? 0,
      'foldersWithoutUserId': folderStats?.data['without_user_id'] as int? ?? 0,
      'totalTemplates': templateStats?.data['total'] as int? ?? 0,
      'systemTemplates': templateStats?.data['system_templates'] as int? ?? 0,
      'userTemplatesWithUserId':
          templateStats?.data['user_with_user_id'] as int? ?? 0,
      'userTemplatesWithoutUserId':
          templateStats?.data['user_without_user_id'] as int? ?? 0,
    };
  }

  /// Validate userId population is complete
  ///
  /// Returns true if all user data has userId assigned
  /// Returns false if there are templates or folders without userId
  static Future<bool> validateUserIdPopulation(
    DatabaseConnectionUser db,
  ) async {
    final stats = await getUserIdPopulationStats(db);

    // All folders should have userId
    final foldersValid = stats['foldersWithoutUserId'] == 0;

    // All user templates (non-system) should have userId
    final templatesValid = stats['userTemplatesWithoutUserId'] == 0;

    return foldersValid && templatesValid;
  }

  /// Get folders without userId (for manual assignment)
  static Future<List<Map<String, dynamic>>> getFoldersWithoutUserId(
    DatabaseConnectionUser db,
  ) async {
    final result = await db.customSelect('''
      SELECT id, name, path, created_at
      FROM local_folders
      WHERE user_id IS NULL
      ORDER BY created_at DESC
      ''').get();

    return result.map((row) => row.data).toList();
  }

  /// Get user templates without userId (for manual assignment)
  static Future<List<Map<String, dynamic>>> getUserTemplatesWithoutUserId(
    DatabaseConnectionUser db,
  ) async {
    final result = await db.customSelect('''
      SELECT id, title, category, created_at
      FROM local_templates
      WHERE user_id IS NULL
      AND is_system = 0
      ORDER BY created_at DESC
      ''').get();

    return result.map((row) => row.data).toList();
  }

  /// Rollback: Clear userId for all folders and user templates
  ///
  /// **WARNING**: This removes ownership information
  /// Only use for testing or rollback scenarios
  static Future<void> rollback(DatabaseConnectionUser db) async {
    await db.transaction(() async {
      // Clear userId from folders
      await db.customStatement('''
        UPDATE local_folders
        SET user_id = NULL
        ''');

      // Clear userId from user templates
      await db.customStatement('''
        UPDATE local_templates
        SET user_id = NULL
        WHERE is_system = 0
        ''');

      // Ensure system templates have userId = null
      await db.customStatement('''
        UPDATE local_templates
        SET user_id = NULL
        WHERE is_system = 1
        ''');
    });
  }
}

/// Helper class for guided userId population during app initialization
class UserIdPopulationGuide {
  final DatabaseConnectionUser db;

  UserIdPopulationGuide(this.db);

  /// Check if userId population is needed
  Future<bool> isPopulationNeeded() async {
    final stats =
        await Migration25SecurityUserIdPopulation.getUserIdPopulationStats(db);

    return stats['foldersWithoutUserId']! > 0 ||
        stats['userTemplatesWithoutUserId']! > 0;
  }

  /// Get detailed migration status report
  Future<String> getStatusReport() async {
    final stats =
        await Migration25SecurityUserIdPopulation.getUserIdPopulationStats(db);

    final buffer = StringBuffer();
    buffer.writeln('=== User ID Population Status ===');
    buffer.writeln();
    buffer.writeln('Folders:');
    buffer.writeln('  Total: ${stats['totalFolders']}');
    buffer.writeln('  With userId: ${stats['foldersWithUserId']}');
    buffer.writeln('  Without userId: ${stats['foldersWithoutUserId']}');
    buffer.writeln();
    buffer.writeln('Templates:');
    buffer.writeln('  Total: ${stats['totalTemplates']}');
    buffer.writeln('  System templates: ${stats['systemTemplates']}');
    buffer.writeln(
      '  User templates with userId: ${stats['userTemplatesWithUserId']}',
    );
    buffer.writeln(
      '  User templates without userId: ${stats['userTemplatesWithoutUserId']}',
    );
    buffer.writeln();

    final isComplete =
        await Migration25SecurityUserIdPopulation.validateUserIdPopulation(db);
    buffer.writeln(
      'Status: ${isComplete ? "✅ Complete" : "⚠️  Incomplete - Action Required"}',
    );

    return buffer.toString();
  }

  /// Execute population for single-user scenario
  Future<void> populateForSingleUser(String userId) async {
    await Migration25SecurityUserIdPopulation.populateUserIdForSingleUser(
      db,
      userId,
    );
  }
}
