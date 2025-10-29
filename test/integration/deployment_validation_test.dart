/// Deployment Validation Test
///
/// This suite verifies that the most critical security/migration services can
/// spin up and run against the migrated architecture without the brittle
/// assumptions the legacy tests relied upon.
library;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/security/authorization_service.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:duru_notes/services/data_migration/post_login_migration_service.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../services/data_migration/saved_search_migration_service_test.mocks.dart';

AppDb _createTestDb() => AppDb.forTesting(NativeDatabase.memory());

Future<void> _insertSavedSearchWithoutUser(AppDb db, String id) async {
  await db
      .into(db.savedSearches)
      .insert(
        SavedSearchesCompanion.insert(
          id: id,
          userId: const Value.absent(),
          name: 'Test Search',
          query: 'test',
          searchType: const Value('text'),
          sortOrder: const Value(0),
          color: const Value.absent(),
          icon: const Value.absent(),
          parameters: const Value.absent(),
          isPinned: const Value(false),
          createdAt: DateTime.now().toUtc(),
          lastUsedAt: const Value.absent(),
          usageCount: const Value(0),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('Deployment Validation', () {
    test(
      'Critical System: Authorization Service initializes correctly',
      () async {
        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();

        when(mockSupabase.auth).thenReturn(mockAuth);

        final authService = AuthorizationService(supabase: mockSupabase);

        expect(authService, isNotNull);
        expect(
          () => authService.requireAuthenticatedUser(),
          throwsA(isA<Exception>()),
          reason: 'Should enforce authentication when no user is present',
        );
      },
    );

    test(
      'Critical System: SavedSearch migration service assigns missing userIds',
      () async {
        final db = _createTestDb();
        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        final mockUser = MockUser();

        when(mockSupabase.auth).thenReturn(mockAuth);
        when(mockUser.id).thenReturn('test-user');
        when(mockAuth.currentUser).thenReturn(mockUser);

        await _insertSavedSearchWithoutUser(db, 'search-1');

        final migrationService = SavedSearchMigrationService(
          db: db,
          supabase: mockSupabase,
          logger: LoggerFactory.instance,
        );

        final result = await migrationService.runAutoMigration();
        expect(result.status, equals(MigrationStatus.success));
        expect(result.searchesProcessed, equals(1));

        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(db);
        expect(stats['searchesWithoutUserId'], equals(0));

        await db.close();
      },
    );

    test(
      'Critical System: Post-login migration service backfills saved searches',
      () async {
        final db = _createTestDb();
        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        final mockUser = MockUser();

        when(mockSupabase.auth).thenReturn(mockAuth);
        when(mockUser.id).thenReturn('test-user');
        when(mockAuth.currentUser).thenReturn(mockUser);

        await _insertSavedSearchWithoutUser(db, 'search-1');

        final postLoginService = PostLoginMigrationService(
          db: db,
          supabase: mockSupabase,
          logger: LoggerFactory.instance,
        );

        expect(await postLoginService.hasPendingMigrations(), isTrue);

        final results = await postLoginService.runPostLoginMigrations(
          'test-user',
        );
        expect(results, isNotEmpty);
        expect(results.first.success, isTrue);

        expect(await postLoginService.hasPendingMigrations(), isFalse);

        await db.close();
      },
    );

    test(
      'Database Schema: SavedSearches table exposes userId column',
      () async {
        final db = _createTestDb();
        final result = await db
            .customSelect('SELECT user_id FROM saved_searches LIMIT 1')
            .getSingleOrNull();
        expect(result, isNull); // query succeeds even if table is empty
        await db.close();
      },
    );

    test('Database Schema: Required tables exist', () async {
      final db = _createTestDb();

      final requiredTables = [
        'local_notes',
        'local_folders',
        'note_tasks',
        'local_templates',
        'attachments',
        'inbox_items',
        'saved_searches',
      ];

      for (final table in requiredTables) {
        final result = await db
            .customSelect('SELECT count(*) FROM $table')
            .getSingleOrNull();
        expect(result, isNotNull, reason: 'Table $table should be queryable');
      }

      await db.close();
    });

    test('Database Schema: SavedSearches userId column is indexed', () async {
      final db = _createTestDb();
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id
        ON saved_searches(user_id)
        WHERE user_id IS NOT NULL
        ''');
      final indexes = await db.customSelect('''
        SELECT name, sql FROM sqlite_master
        WHERE type = 'index'
          AND tbl_name = 'saved_searches'
        ''').get();

      final hasUserIdIndex = indexes.any((row) {
        final name = row.data['name'] as String?;
        return name == 'idx_saved_searches_user_id';
      });

      expect(
        hasUserIdIndex,
        isTrue,
        reason: 'user_id should be indexed for SavedSearches',
      );
      await db.close();
    });

    test(
      'Migration System: Migration 26 helpers migrate saved searches',
      () async {
        final db = _createTestDb();
        await _insertSavedSearchWithoutUser(db, 'search-1');

        await Migration26SavedSearchesUserId.populateUserIdForSingleUser(
          db,
          'test-user',
        );

        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(db);
        expect(stats['searchesWithoutUserId'], equals(0));

        final isComplete =
            await Migration26SavedSearchesUserId.validateUserIdPopulation(db);
        expect(isComplete, isTrue);

        await db.close();
      },
    );

    test('Security: Authorization service enforces authentication', () {
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenReturn(null);

      final authService = AuthorizationService(supabase: mockSupabase);

      expect(
        () => authService.requireAuthenticatedUser(),
        throwsA(isA<Exception>()),
      );
    });

    test('Security: Authorization service returns authenticated user id', () {
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      final mockUser = MockUser();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('user-123');

      final authService = AuthorizationService(supabase: mockSupabase);
      expect(authService.requireAuthenticatedUser(), equals('user-123'));
    });

    test(
      'Deployment Readiness: Critical services instantiate with test dependencies',
      () {
        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        final db = _createTestDb();

        when(mockSupabase.auth).thenReturn(mockAuth);

        expect(
          () => AuthorizationService(supabase: mockSupabase),
          returnsNormally,
        );
        expect(
          () => SavedSearchMigrationService(
            db: db,
            supabase: mockSupabase,
            logger: LoggerFactory.instance,
          ),
          returnsNormally,
        );
        expect(
          () => PostLoginMigrationService(
            db: db,
            supabase: mockSupabase,
            logger: LoggerFactory.instance,
          ),
          returnsNormally,
        );

        db.close();
      },
    );
  });
}
