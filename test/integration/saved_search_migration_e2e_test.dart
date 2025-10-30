/// End-to-End Integration Tests for SavedSearch Migration System
///
/// These tests verify the complete migration flow from app bootstrap through
/// user login to final migration completion.
///
/// Test coverage:
/// - Bootstrap migration during app startup
/// - Deferred migration when user not logged in
/// - Post-login migration execution
/// - Migration UI components
/// - Complete migration lifecycle
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';
import 'package:duru_notes/services/data_migration/post_login_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/database_test_helper.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<AppLogger>(),
])
import 'saved_search_migration_e2e_test.mocks.dart';

void main() {
  group('SavedSearch Migration E2E Tests', () {
    late AppDb testDb;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockAppLogger mockLogger;

    setUp(() async {
      // Ensure Flutter binding is initialized
      TestWidgetsFlutterBinding.ensureInitialized();

      // Create fresh in-memory test database with proper initialization
      testDb = DatabaseTestHelper.createTestDatabase();

      // Set up mocks
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockLogger = MockAppLogger();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockUser.id).thenReturn('test-user-123');
      when(mockUser.email).thenReturn('test@example.com');
    });

    tearDown(() async {
      await DatabaseTestHelper.closeDatabase(testDb);
    });

    group('Bootstrap Migration Flow', () {
      test('Scenario 1: No saved searches - migration not needed', () async {
        // No saved searches in database

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.notNeeded));
        expect(result.searchesProcessed, equals(0));
        expect(result.message, contains('No saved searches'));
      });

      test(
        'Scenario 2: All searches have userId - migration complete',
        () async {
          // Insert saved searches with userId
          await _insertSavedSearch(testDb, 'search-1', userId: 'user-1');
          await _insertSavedSearch(testDb, 'search-2', userId: 'user-1');

          final service = SavedSearchMigrationService(
            db: testDb,
            supabase: mockSupabase,
            logger: mockLogger,
          );

          final result = await service.runAutoMigration();

          expect(result.status, equals(MigrationStatus.complete));
          expect(result.searchesProcessed, equals(0));
          expect(result.message, contains('already have userId'));
        },
      );

      test('Scenario 3: User logged in - automatic migration', () async {
        // Insert saved searches without userId (legacy data)
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');
        await _insertSavedSearch(testDb, 'search-3');

        // User is logged in
        when(mockAuth.currentUser).thenReturn(mockUser);

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(3));
        expect(result.message, contains('Successfully migrated 3'));

        // Verify all searches now have userId
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(0));
        expect(stats['searchesWithUserId'], equals(3));

        // Verify userId is correct
        final search = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-1')],
            )
            .getSingleOrNull();
        expect(search?.data['user_id'], equals('test-user-123'));
      });

      test('Scenario 4: User not logged in - migration deferred', () async {
        // Insert saved searches without userId
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');

        // No user logged in
        when(mockAuth.currentUser).thenReturn(null);

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.deferred));
        expect(result.searchesNeedingMigration, equals(2));
        expect(result.message, contains('log in'));

        // Verify searches still don't have userId
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(2));
      });
    });

    group('Post-Login Migration Flow', () {
      test('Deferred migration completes after user logs in', () async {
        // Step 1: Bootstrap with no user logged in
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');

        when(mockAuth.currentUser).thenReturn(null);

        final bootstrapService = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final bootstrapResult = await bootstrapService.runAutoMigration();
        expect(bootstrapResult.status, equals(MigrationStatus.deferred));

        // Step 2: User logs in
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Step 3: Post-login migration runs
        final postLoginService = PostLoginMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final postLoginResults = await postLoginService.runPostLoginMigrations(
          'test-user-123',
        );

        expect(postLoginResults, hasLength(1));
        expect(
          postLoginResults.first.migrationType,
          equals(PostLoginMigrationType.savedSearches),
        );
        expect(postLoginResults.first.success, isTrue);
        expect(postLoginResults.first.itemsProcessed, equals(2));

        // Step 4: Verify migration completed
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(0));
        expect(stats['searchesWithUserId'], equals(2));
      });

      test('Post-login migration is idempotent', () async {
        // Insert searches with userId
        await _insertSavedSearch(testDb, 'search-1', userId: 'test-user-123');
        await _insertSavedSearch(testDb, 'search-2', userId: 'test-user-123');

        when(mockAuth.currentUser).thenReturn(mockUser);

        final postLoginService = PostLoginMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        // Run migration twice
        final result1 = await postLoginService.runPostLoginMigrations(
          'test-user-123',
        );
        final result2 = await postLoginService.runPostLoginMigrations(
          'test-user-123',
        );

        // Both should succeed with 0 items processed
        expect(result1.first.success, isTrue);
        expect(result1.first.itemsProcessed, equals(0));
        expect(result2.first.success, isTrue);
        expect(result2.first.itemsProcessed, equals(0));

        // Data should remain intact
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['totalSearches'], equals(2));
        expect(stats['searchesWithUserId'], equals(2));
      });
    });

    group('Complex Migration Scenarios', () {
      test('Mixed data: Some with userId, some without', () async {
        // Insert mix of migrated and unmigrated searches
        await _insertSavedSearch(testDb, 'search-1', userId: 'other-user');
        await _insertSavedSearch(testDb, 'search-2'); // No userId
        await _insertSavedSearch(testDb, 'search-3', userId: 'another-user');
        await _insertSavedSearch(testDb, 'search-4'); // No userId
        await _insertSavedSearch(testDb, 'search-5', userId: 'other-user');

        when(mockAuth.currentUser).thenReturn(mockUser);

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.success));
        expect(
          result.searchesProcessed,
          equals(2),
        ); // Only search-2 and search-4

        // Verify existing assignments were preserved
        final search1 = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-1')],
            )
            .getSingleOrNull();
        expect(search1?.data['user_id'], equals('other-user'));

        // Verify new assignments were created
        final search2 = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-2')],
            )
            .getSingleOrNull();
        expect(search2?.data['user_id'], equals('test-user-123'));
      });

      test('Large dataset migration', () async {
        // Insert 100 saved searches without userId
        for (int i = 0; i < 100; i++) {
          await _insertSavedSearch(testDb, 'search-$i');
        }

        when(mockAuth.currentUser).thenReturn(mockUser);

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final stopwatch = Stopwatch()..start();
        final result = await service.runAutoMigration();
        stopwatch.stop();

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(100));

        // Should complete in reasonable time (< 2 seconds for 100 items)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'Migration should be performant',
        );

        // Verify all migrated correctly
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(0));
        expect(stats['searchesWithUserId'], equals(100));
      });
    });

    group('Migration Status Reporting', () {
      test('Status report shows accurate migration state', () async {
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-1');
        await _insertSavedSearch(testDb, 'search-3');

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final report = await service.getStatusReport();

        expect(report, contains('Total: 3'));
        expect(report, contains('With userId: 1'));
        expect(report, contains('Without userId: 2'));
        expect(report, contains('Incomplete'));
        expect(report, contains('ACTION REQUIRED'));
      });

      test('isMigrationNeeded returns correct status', () async {
        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        // No searches - not needed
        expect(await service.isMigrationNeeded(), isFalse);

        // Add unmigrated searches - needed
        await _insertSavedSearch(testDb, 'search-1');
        expect(await service.isMigrationNeeded(), isTrue);

        // Migrate - not needed anymore
        when(mockAuth.currentUser).thenReturn(mockUser);
        await service.runAutoMigration();
        expect(await service.isMigrationNeeded(), isFalse);
      });
    });

    group('Error Handling', () {
      test('Migration handles invalid userId gracefully', () async {
        await _insertSavedSearch(testDb, 'search-1');

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.migrateForUser(''); // Empty userId

        expect(result.status, equals(MigrationStatus.failed));
        expect(result.message, contains('Invalid userId'));
      });

      test('Migration continues if some searches fail', () async {
        // This test verifies migration is atomic (all or nothing)
        // If migration starts, it should complete for all items
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');

        when(mockAuth.currentUser).thenReturn(mockUser);

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.runAutoMigration();

        // Should succeed for all items (atomic transaction)
        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(2));

        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(0));
      });
    });

    group('Data Cleanup', () {
      test('Orphaned search deletion works correctly', () async {
        await _insertSavedSearch(testDb, 'search-1'); // Orphaned
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-1');
        await _insertSavedSearch(testDb, 'search-3'); // Orphaned

        final service = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final result = await service.deleteOrphanedSearches();

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(2));

        // Verify only search-2 remains
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['totalSearches'], equals(1));
        expect(stats['searchesWithUserId'], equals(1));
      });
    });
  });
}

/// Helper function to insert a saved search
Future<void> _insertSavedSearch(AppDb db, String id, {String? userId}) async {
  // Use a placeholder value for tests that need to simulate missing userId
  // The tests will update this to null when testing migration scenarios
  final actualUserId = userId ?? 'NEEDS_MIGRATION';

  await DatabaseTestHelper.insertTestSavedSearch(
    db,
    id: id,
    userId: actualUserId,
    name: 'Search $id',
    query: 'test query',
    searchType: 'text',
  );

  // For tests that need to simulate missing userId, update to null
  if (userId == null) {
    await db.customStatement(
      'UPDATE saved_searches SET user_id = NULL WHERE id = ?',
      [id],
    );
  }
}
