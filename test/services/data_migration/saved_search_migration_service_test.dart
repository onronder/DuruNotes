import 'package:drift/drift.dart' hide isNull;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/database_test_helper.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<AppLogger>(),
])
import 'saved_search_migration_service_test.mocks.dart';

void main() {
  group('SavedSearchMigrationService', () {
    late AppDb testDb;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockAppLogger mockLogger;
    late SavedSearchMigrationService service;

    setUp(() async {
      // Ensure Flutter binding is initialized
      TestWidgetsFlutterBinding.ensureInitialized();

      // Create in-memory test database with proper initialization
      testDb = DatabaseTestHelper.createTestDatabase();

      // Check if user_id column exists, if not run migration
      try {
        await testDb
            .customSelect('SELECT user_id FROM saved_searches LIMIT 1')
            .getSingleOrNull();
        // Column exists, no need to run migration
      } catch (e) {
        // Column doesn't exist, run migration
        await Migration26SavedSearchesUserId.run(testDb, 25);
      }

      // Set up mocks
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockLogger = MockAppLogger();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockUser.id).thenReturn('test-user-123');

      // Create service
      service = SavedSearchMigrationService(
        db: testDb,
        supabase: mockSupabase,
        logger: mockLogger,
      );
    });

    tearDown(() async {
      await DatabaseTestHelper.closeDatabase(testDb);
    });

    group('runAutoMigration', () {
      test('returns notNeeded when no saved searches exist', () async {
        // No data in database

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.notNeeded));
        expect(result.searchesProcessed, equals(0));
      });

      test('returns complete when all searches have userId', () async {
        // Insert saved search with userId
        await _insertSavedSearch(testDb, 'search-1', userId: 'existing-user');

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.complete));
        expect(result.searchesProcessed, equals(0));
      });

      test(
        'returns deferred when searches exist but user not logged in',
        () async {
          // Insert saved searches without userId
          await _insertSavedSearch(testDb, 'search-1');
          await _insertSavedSearch(testDb, 'search-2');

          // No user logged in
          when(mockAuth.currentUser).thenReturn(null);

          final result = await service.runAutoMigration();

          expect(result.status, equals(MigrationStatus.deferred));
          expect(result.searchesNeedingMigration, equals(2));
        },
      );

      test('successfully migrates searches when user is logged in', () async {
        // Insert saved searches without userId
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');
        await _insertSavedSearch(testDb, 'search-3');

        // User logged in
        when(mockAuth.currentUser).thenReturn(mockUser);

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(3));

        // Verify all searches now have userId
        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['searchesWithoutUserId'], equals(0));
        expect(stats['searchesWithUserId'], equals(3));
      });

      test('only migrates searches without userId', () async {
        // Insert searches with and without userId
        await _insertSavedSearch(testDb, 'search-1', userId: 'other-user');
        await _insertSavedSearch(testDb, 'search-2'); // No userId
        await _insertSavedSearch(testDb, 'search-3'); // No userId

        when(mockAuth.currentUser).thenReturn(mockUser);

        final result = await service.runAutoMigration();

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(2));

        // Verify search-1 still has original userId
        final search1 = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-1')],
            )
            .getSingleOrNull();
        expect(search1?.data['user_id'], equals('other-user'));

        // Verify search-2 and search-3 have new userId
        final search2 = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-2')],
            )
            .getSingleOrNull();
        expect(search2?.data['user_id'], equals('test-user-123'));
      });
    });

    group('isMigrationNeeded', () {
      test('returns false when no searches need migration', () async {
        await _insertSavedSearch(testDb, 'search-1', userId: 'user-1');

        final needed = await service.isMigrationNeeded();

        expect(needed, isFalse);
      });

      test('returns true when searches need migration', () async {
        await _insertSavedSearch(testDb, 'search-1'); // No userId

        final needed = await service.isMigrationNeeded();

        expect(needed, isTrue);
      });
    });

    group('getSearchesNeedingMigration', () {
      test('returns correct count of searches without userId', () async {
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');
        await _insertSavedSearch(testDb, 'search-3', userId: 'user-1');

        final count = await service.getSearchesNeedingMigration();

        expect(count, equals(2));
      });

      test('returns 0 when all searches have userId', () async {
        await _insertSavedSearch(testDb, 'search-1', userId: 'user-1');
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-2');

        final count = await service.getSearchesNeedingMigration();

        expect(count, equals(0));
      });
    });

    group('migrateForUser', () {
      test('migrates searches for specified user', () async {
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2');

        final result = await service.migrateForUser('manual-user-456');

        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(2));

        // Verify userId assigned correctly
        final search = await testDb
            .customSelect(
              'SELECT user_id FROM saved_searches WHERE id = ?',
              variables: [Variable.withString('search-1')],
            )
            .getSingleOrNull();
        expect(search?.data['user_id'], equals('manual-user-456'));
      });

      test('fails when userId is empty', () async {
        final result = await service.migrateForUser('');

        expect(result.status, equals(MigrationStatus.failed));
        expect(result.message, contains('Invalid userId'));
      });

      test('returns notNeeded when no searches to migrate', () async {
        await _insertSavedSearch(testDb, 'search-1', userId: 'user-1');

        final result = await service.migrateForUser('user-2');

        expect(result.status, equals(MigrationStatus.notNeeded));
      });
    });

    group('deleteOrphanedSearches', () {
      test('deletes searches without userId', () async {
        await _insertSavedSearch(testDb, 'search-1'); // No userId
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-1');
        await _insertSavedSearch(testDb, 'search-3'); // No userId

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

      test('does not delete searches with userId', () async {
        await _insertSavedSearch(testDb, 'search-1', userId: 'user-1');
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-2');

        final result = await service.deleteOrphanedSearches();

        expect(result.searchesProcessed, equals(0));

        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );
        expect(stats['totalSearches'], equals(2));
      });
    });

    group('getStatusReport', () {
      test('generates correct status report', () async {
        await _insertSavedSearch(testDb, 'search-1');
        await _insertSavedSearch(testDb, 'search-2', userId: 'user-1');

        final report = await service.getStatusReport();

        expect(report, contains('Total: 2'));
        expect(report, contains('With userId: 1'));
        expect(report, contains('Without userId: 1'));
        expect(report, contains('Incomplete'));
      });
    });
  });
}

/// Helper function to insert a saved search into the database
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
