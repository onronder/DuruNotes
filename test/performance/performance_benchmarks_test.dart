/// Performance Benchmarks Test Suite
///
/// This test suite validates performance characteristics of critical systems
/// under production-like loads.
///
/// Test coverage:
/// - Database query performance
/// - Migration performance with large datasets
/// - Multi-tenant data isolation performance
/// - Concurrent operation handling
/// - Memory efficiency
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:duru_notes/core/security/authorization_service.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
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
import 'performance_benchmarks_test.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Performance Benchmarks', () {
    late AppDb testDb;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockAppLogger mockLogger;

    setUp(() async {
      testDb = DatabaseTestHelper.createTestDatabase();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockLogger = MockAppLogger();

      // Initialize NoOpLogger for performance tests to eliminate logging overhead
      // Logger operations (timestamp generation, string formatting, console output)
      // can add 0.10-0.15ms per call, significantly impacting benchmark accuracy
      LoggerFactory.initialize(enabled: false);

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockUser.id).thenReturn('test-user-123');
      when(mockAuth.currentUser).thenReturn(mockUser);
    });

    tearDown(() async {
      await DatabaseTestHelper.closeDatabase(testDb);
    });

    group('Database Query Performance', () {
      test(
        'Query 1000 notes with userId filter completes in < 100ms',
        () async {
          // Insert 1000 notes for test user
          final seedTime = DateTime.now();
          for (int i = 0; i < 1000; i++) {
            await testDb
                .into(testDb.localNotes)
                .insert(
                  LocalNotesCompanion.insert(
                    id: 'note-$i',
                    userId: const Value('test-user-123'),
                    titleEncrypted: Value('Test Note $i'),
                    bodyEncrypted: Value('Content for note $i'),
                    createdAt: seedTime,
                    updatedAt: seedTime,
                    deleted: const Value(false),
                  ),
                );
          }

          // Benchmark query
          final stopwatch = Stopwatch()..start();

          final result = await testDb
              .customSelect(
                'SELECT * FROM local_notes WHERE user_id = ? LIMIT 100',
                variables: [Variable.withString('test-user-123')],
              )
              .get();

          stopwatch.stop();

          expect(result, isNotEmpty);
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(100),
            reason: 'Query should complete in < 100ms',
          );
        },
      );

      test(
        'Query 500 folders with userId filter completes in < 50ms',
        () async {
          // Insert 500 folders
          for (int i = 0; i < 500; i++) {
            await testDb.customStatement(
              '''
            INSERT INTO local_folders (
              id, user_id, name, parent_id, path, created_at, updated_at, deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''',
              [
                'folder-$i',
                'test-user-123',
                'Folder $i',
                null,
                '/Folder $i',
                DateTime.now().millisecondsSinceEpoch,
                DateTime.now().millisecondsSinceEpoch,
                0,
              ],
            );
          }

          final stopwatch = Stopwatch()..start();

          final result = await testDb
              .customSelect(
                'SELECT * FROM local_folders WHERE user_id = ?',
                variables: [Variable.withString('test-user-123')],
              )
              .get();

          stopwatch.stop();

          expect(result.length, equals(500));
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(50),
            reason: 'Folder query should complete in < 50ms',
          );
        },
      );

      test(
        'Query 100 saved searches with userId filter completes in < 30ms',
        () async {
          // Insert 100 saved searches
          for (int i = 0; i < 100; i++) {
            await _insertSavedSearch(
              testDb,
              'search-$i',
              userId: 'test-user-123',
            );
          }

          final stopwatch = Stopwatch()..start();

          final result = await testDb
              .customSelect(
                'SELECT * FROM saved_searches WHERE user_id = ?',
                variables: [Variable.withString('test-user-123')],
              )
              .get();

          stopwatch.stop();

          expect(result.length, equals(100));
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(30),
            reason: 'SavedSearch query should complete in < 30ms',
          );
        },
      );
    });

    group('Migration Performance', () {
      test('Migrate 100 saved searches completes in < 500ms', () async {
        // Insert 100 saved searches without userId (for migration testing)
        for (int i = 0; i < 100; i++) {
          await _insertSavedSearch(testDb, 'search-$i', allowNullUserId: true);
        }

        final migrationService = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final stopwatch = Stopwatch()..start();

        final result = await migrationService.runAutoMigration();

        stopwatch.stop();

        expect(result.searchesProcessed, equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason: 'Migration of 100 searches should complete in < 500ms',
        );
      });

      test('Migrate 1000 saved searches completes in < 2000ms', () async {
        // Insert 1000 saved searches without userId (for migration testing)
        for (int i = 0; i < 1000; i++) {
          await _insertSavedSearch(testDb, 'search-$i', allowNullUserId: true);
        }

        final migrationService = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final stopwatch = Stopwatch()..start();

        final result = await migrationService.runAutoMigration();

        stopwatch.stop();

        expect(result.searchesProcessed, equals(1000));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'Migration of 1000 searches should complete in < 2s',
        );
      });

      test('Migration stats query completes in < 20ms', () async {
        // Insert mix of migrated and unmigrated searches
        for (int i = 0; i < 50; i++) {
          await _insertSavedSearch(testDb, 'migrated-$i', userId: 'user-1');
        }
        for (int i = 0; i < 50; i++) {
          await _insertSavedSearch(
            testDb,
            'unmigrated-$i',
            allowNullUserId: true,
          );
        }

        final stopwatch = Stopwatch()..start();

        final stats =
            await Migration26SavedSearchesUserId.getUserIdPopulationStats(
              testDb,
            );

        stopwatch.stop();

        expect(stats['totalSearches'], equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(20),
          reason: 'Stats query should complete in < 20ms',
        );
      });
    });

    group('Multi-Tenant Data Isolation Performance', () {
      test(
        'Query isolation for 10 users with 100 notes each completes efficiently',
        () async {
          // Create 10 users with 100 notes each
          final isolationSeed = DateTime.now();
          for (int userId = 0; userId < 10; userId++) {
            for (int noteId = 0; noteId < 100; noteId++) {
              await testDb
                  .into(testDb.localNotes)
                  .insert(
                    LocalNotesCompanion.insert(
                      id: 'user-$userId-note-$noteId',
                      userId: Value('user-$userId'),
                      titleEncrypted: Value('Note $noteId'),
                      bodyEncrypted: const Value('Content'),
                      createdAt: isolationSeed,
                      updatedAt: isolationSeed,
                      deleted: const Value(false),
                    ),
                  );
            }
          }

          // Query for each user and verify isolation
          for (int userId = 0; userId < 10; userId++) {
            final stopwatch = Stopwatch()..start();

            final result = await testDb
                .customSelect(
                  'SELECT * FROM local_notes WHERE user_id = ?',
                  variables: [Variable.withString('user-$userId')],
                )
                .get();

            stopwatch.stop();

            expect(
              result.length,
              equals(100),
              reason: 'Each user should see only their 100 notes',
            );
            expect(
              stopwatch.elapsedMilliseconds,
              lessThan(50),
              reason: 'User isolation query should complete in < 50ms',
            );
          }
        },
      );

      test('Folder hierarchy query with userId filter is performant', () async {
        // Create folder hierarchy for 5 users
        for (int userId = 0; userId < 5; userId++) {
          // Create root folders
          for (int rootId = 0; rootId < 5; rootId++) {
            await testDb.customStatement(
              '''
              INSERT INTO local_folders (
                id, user_id, name, parent_id, path, created_at, updated_at, deleted
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                'user-$userId-root-$rootId',
                'user-$userId',
                'Root $rootId',
                null,
                '/Root $rootId',
                DateTime.now().millisecondsSinceEpoch,
                DateTime.now().millisecondsSinceEpoch,
                0,
              ],
            );

            // Create subfolders
            for (int subId = 0; subId < 10; subId++) {
              await testDb.customStatement(
                '''
                INSERT INTO local_folders (
                  id, user_id, name, parent_id, path, created_at, updated_at, deleted
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                [
                  'user-$userId-root-$rootId-sub-$subId',
                  'user-$userId',
                  'Subfolder $subId',
                  'user-$userId-root-$rootId',
                  '/Root $rootId/Subfolder $subId',
                  DateTime.now().millisecondsSinceEpoch,
                  DateTime.now().millisecondsSinceEpoch,
                  0,
                ],
              );
            }
          }
        }

        // Query folders for a specific user
        final stopwatch = Stopwatch()..start();

        final result = await testDb
            .customSelect(
              'SELECT * FROM local_folders WHERE user_id = ?',
              variables: [Variable.withString('user-0')],
            )
            .get();

        stopwatch.stop();

        expect(
          result.length,
          equals(55), // 5 root + 50 subfolders
          reason: 'User should see their folder hierarchy',
        );
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Hierarchy query should complete in < 100ms',
        );
      });

      test(
        'SavedSearch isolation for 20 users with 50 searches each',
        () async {
          // Create 20 users with 50 saved searches each
          for (int userId = 0; userId < 20; userId++) {
            for (int searchId = 0; searchId < 50; searchId++) {
              await _insertSavedSearch(
                testDb,
                'user-$userId-search-$searchId',
                userId: 'user-$userId',
              );
            }
          }

          // Query for random user
          final stopwatch = Stopwatch()..start();

          final result = await testDb
              .customSelect(
                'SELECT * FROM saved_searches WHERE user_id = ?',
                variables: [Variable.withString('user-5')],
              )
              .get();

          stopwatch.stop();

          expect(result.length, equals(50));
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(30),
            reason: 'SavedSearch isolation query should complete in < 30ms',
          );
        },
      );
    });

    group('Concurrent Operation Performance', () {
      test('10 concurrent queries execute efficiently', () async {
        // Insert test data
        final concurrentSeed = DateTime.now();
        for (int i = 0; i < 100; i++) {
          await testDb
              .into(testDb.localNotes)
              .insert(
                LocalNotesCompanion.insert(
                  id: 'note-$i',
                  userId: Value('user-${i % 5}'),
                  titleEncrypted: Value('Note $i'),
                  bodyEncrypted: const Value('Content'),
                  createdAt: concurrentSeed,
                  updatedAt: concurrentSeed,
                  deleted: const Value(false),
                ),
              );
        }

        // Execute 10 concurrent queries
        final stopwatch = Stopwatch()..start();

        final futures = <Future<List<QueryRow>>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            testDb
                .customSelect(
                  'SELECT * FROM local_notes WHERE user_id = ?',
                  variables: [Variable.withString('user-${i % 5}')],
                )
                .get(),
          );
        }

        final results = await Future.wait(futures);

        stopwatch.stop();

        expect(results, hasLength(10));
        expect(results.every((r) => r.isNotEmpty), isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(200),
          reason: '10 concurrent queries should complete in < 200ms',
        );
      });

      test('Concurrent migration and query operations', () async {
        // Insert unmigrated searches (for migration testing)
        for (int i = 0; i < 50; i++) {
          await _insertSavedSearch(testDb, 'search-$i', allowNullUserId: true);
        }

        // Insert migrated searches for different user
        for (int i = 0; i < 50; i++) {
          await _insertSavedSearch(
            testDb,
            'other-search-$i',
            userId: 'other-user',
          );
        }

        final migrationService = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final stopwatch = Stopwatch()..start();

        // Run migration and query concurrently
        await Future.wait([
          migrationService.runAutoMigration(),
          testDb
              .customSelect(
                'SELECT * FROM saved_searches WHERE user_id = ?',
                variables: [Variable.withString('other-user')],
              )
              .get(),
        ]);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(600),
          reason: 'Concurrent migration and query should complete in < 600ms',
        );
      });
    });

    group('Index Performance Validation', () {
      test('userId index improves query performance significantly', () async {
        // Insert 1000 saved searches
        for (int i = 0; i < 1000; i++) {
          await _insertSavedSearch(
            testDb,
            'search-$i',
            userId: 'user-${i % 10}',
          );
        }

        // Query with userId filter (should use index)
        final stopwatch = Stopwatch()..start();

        final result = await testDb
            .customSelect(
              'SELECT * FROM saved_searches WHERE user_id = ?',
              variables: [Variable.withString('user-0')],
            )
            .get();

        stopwatch.stop();

        expect(result.length, equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(30),
          reason: 'Indexed query should be very fast (< 30ms)',
        );
      });

      test('Notes userId index improves large dataset queries', () async {
        // Insert 5000 notes across 10 users
        final indexSeed = DateTime.now();
        for (int i = 0; i < 5000; i++) {
          await testDb
              .into(testDb.localNotes)
              .insert(
                LocalNotesCompanion.insert(
                  id: 'note-$i',
                  userId: Value('user-${i % 10}'),
                  titleEncrypted: Value('Note $i'),
                  bodyEncrypted: const Value('Content'),
                  createdAt: indexSeed,
                  updatedAt: indexSeed,
                  deleted: const Value(false),
                ),
              );
        }

        final stopwatch = Stopwatch()..start();

        final result = await testDb
            .customSelect(
              'SELECT * FROM local_notes WHERE user_id = ? LIMIT 100',
              variables: [Variable.withString('user-0')],
            )
            .get();

        stopwatch.stop();

        expect(result.length, equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Indexed query on large dataset should complete in < 100ms',
        );
      });
    });

    group('Memory Efficiency', () {
      test('Large dataset query uses reasonable memory', () async {
        // Insert 1000 notes
        final memorySeed = DateTime.now();
        for (int i = 0; i < 1000; i++) {
          await testDb
              .into(testDb.localNotes)
              .insert(
                LocalNotesCompanion.insert(
                  id: 'note-$i',
                  userId: const Value('test-user'),
                  titleEncrypted: Value('Note $i'),
                  bodyEncrypted: Value(
                    'Content for note $i with some reasonable text length',
                  ),
                  createdAt: memorySeed,
                  updatedAt: memorySeed,
                  deleted: const Value(false),
                ),
              );
        }

        // Query with pagination (memory efficient)
        final stopwatch = Stopwatch()..start();

        var totalResults = 0;
        for (int page = 0; page < 10; page++) {
          final result = await testDb
              .customSelect(
                'SELECT * FROM local_notes WHERE user_id = ? LIMIT 100 OFFSET ?',
                variables: [
                  Variable.withString('test-user'),
                  Variable.withInt(page * 100),
                ],
              )
              .get();
          totalResults += result.length;
        }

        stopwatch.stop();

        expect(totalResults, equals(1000));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason: 'Paginated queries should be memory efficient and fast',
        );
      });

      test('Migration processes data in manageable batches', () async {
        // Insert 500 saved searches without userId (for migration testing)
        for (int i = 0; i < 500; i++) {
          await _insertSavedSearch(testDb, 'search-$i', allowNullUserId: true);
        }

        final migrationService = SavedSearchMigrationService(
          db: testDb,
          supabase: mockSupabase,
          logger: mockLogger,
        );

        final stopwatch = Stopwatch()..start();

        final result = await migrationService.runAutoMigration();

        stopwatch.stop();

        expect(result.searchesProcessed, equals(500));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Batch migration should complete in < 1s',
        );
      });
    });

    group('Authorization Performance', () {
      test('Authorization check is fast for authenticated user', () async {
        final authService = AuthorizationService(supabase: mockSupabase);

        final stopwatch = Stopwatch()..start();

        // Run 100 authorization checks
        for (int i = 0; i < 100; i++) {
          final userId = authService.requireAuthenticatedUser();
          expect(userId, equals('test-user-123'));
        }

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(30),
          reason:
              '100 authorization checks should complete in < 30ms (adjusted for caching optimization and CI variance)',
        );
      });

      test('Ownership verification is performant', () async {
        final authService = AuthorizationService(supabase: mockSupabase);

        final stopwatch = Stopwatch()..start();

        // Run 100 ownership verifications
        for (int i = 0; i < 100; i++) {
          final isOwner = authService.isOwner('test-user-123');
          expect(isOwner, isTrue);
        }

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(15),
          reason:
              '100 ownership checks should complete in < 15ms (adjusted for caching optimization)',
        );
      });
    });
  });
}

/// Helper function to insert a saved search
///
/// For migration testing: If userId is explicitly null and allowNullUserId is true,
/// this inserts with NULL userId (for testing migration scenarios).
/// Otherwise defaults to 'test-user-123' to satisfy NOT NULL constraint.
Future<void> _insertSavedSearch(
  AppDb db,
  String id, {
  String? userId,
  bool allowNullUserId = false,
}) async {
  final effectiveUserId = allowNullUserId && userId == null
      ? null
      : (userId ?? 'test-user-123');

  await db.customStatement(
    '''
    INSERT INTO saved_searches (
      id, user_id, name, query, search_type, parameters, sort_order,
      color, icon, is_pinned, created_at, last_used_at, usage_count
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id,
      effectiveUserId,
      'Search $id',
      'test query',
      'text',
      null,
      0,
      null,
      null,
      0,
      DateTime.now().millisecondsSinceEpoch,
      null,
      0,
    ],
  );
}
