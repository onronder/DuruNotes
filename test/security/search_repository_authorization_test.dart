import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart' as app_db;
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'search_repository_authorization_test.mocks.dart';

const _userA = 'user-a';
const _userB = 'user-b';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<CryptoBox>(),
  MockSpec<IFolderRepository>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      // If Supabase is not yet initialized, this will throw.
      Supabase.instance.client;
    } catch (_) {
      SharedPreferences.setMockInitialValues(const {});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  late app_db.AppDb db;
  late SearchRepository repository;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCrypto;
  late MockIFolderRepository mockFolderRepository;

  setUp(() async {
    db = app_db.AppDb.forTesting(NativeDatabase.memory());
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockCrypto = MockCryptoBox();
    mockFolderRepository = MockIFolderRepository();

    when(mockClient.auth).thenReturn(mockAuth);

    repository = SearchRepository(
      db: db,
      client: mockClient,
      crypto: mockCrypto,
      folderRepository: mockFolderRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  domain.SavedSearch newSavedSearch({
    required String id,
    DateTime? createdAt,
    int displayOrder = 0,
  }) {
    final timestamp = createdAt ?? DateTime.utc(2025, 10, 29);
    return domain.SavedSearch(
      id: id,
      name: 'Search $id',
      query: 'body:$id',
      filters: null,
      isPinned: false,
      createdAt: timestamp,
      lastUsedAt: null,
      usageCount: 0,
      displayOrder: displayOrder,
    );
  }

  Future<void> seedSavedSearch({
    required String id,
    required String userId,
    bool isPinned = false,
    int usageCount = 0,
    int sortOrder = 0,
  }) async {
    final now = DateTime.utc(2025, 10, 29);
    await db.upsertSavedSearch(
      app_db.SavedSearch(
        id: id,
        userId: userId,
        name: 'Search $id',
        query: 'body:$id',
        searchType: 'text',
        parameters: null,
        sortOrder: sortOrder,
        color: null,
        icon: null,
        isPinned: isPinned,
        createdAt: now,
        lastUsedAt: null,
        usageCount: usageCount,
      ),
    );
  }

  Future<void> authenticate(String userId) async {
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn(userId);
  }

  group('SearchRepository saved search isolation', () {
    test(
      'createOrUpdateSavedSearch updates owned record and enqueues sync',
      () async {
        await seedSavedSearch(id: 'search-1', userId: _userA, sortOrder: 1);
        await authenticate(_userA);
        final search = newSavedSearch(id: 'search-1', displayOrder: 5);

        await repository.createOrUpdateSavedSearch(search);

        final stored = await db.getSavedSearchById('search-1');
        expect(stored, isNotNull);
        expect(stored!.userId, equals(_userA));
        expect(stored.sortOrder, equals(5));

        final pendingOps = await db.getPendingOpsForUser(_userA);
        expect(pendingOps, hasLength(1));
        expect(pendingOps.first.kind, equals('upsert_saved_search'));
        expect(pendingOps.first.entityId, equals('search-1'));
      },
    );

    test('createOrUpdateSavedSearch throws when unauthenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);
      final search = newSavedSearch(id: 'search-unauth');

      await expectLater(
        repository.createOrUpdateSavedSearch(search),
        throwsStateError,
      );

      final stored = await db.getSavedSearchById('search-unauth');
      expect(stored, isNull);
    });

    test('deleteSavedSearch only removes records for owning user', () async {
      await seedSavedSearch(id: 'search-owned', userId: _userA);
      await seedSavedSearch(id: 'search-other', userId: _userB);
      await authenticate(_userA);

      await repository.deleteSavedSearch('search-owned');
      await repository.deleteSavedSearch('search-other');

      final owned = await db.getSavedSearchById('search-owned');
      final other = await db.getSavedSearchById('search-other');
      expect(owned, isNull);
      expect(other, isNotNull, reason: 'Cross-user delete should not succeed');

      final pendingOps = await db.getPendingOpsForUser(_userA);
      expect(pendingOps.single.kind, equals('delete_saved_search'));
      expect(pendingOps.single.entityId, equals('search-owned'));
    });

    test('getSavedSearches returns only current user entries', () async {
      await seedSavedSearch(id: 'search-a1', userId: _userA, sortOrder: 1);
      await seedSavedSearch(id: 'search-b1', userId: _userB, sortOrder: 2);
      await authenticate(_userA);

      final results = await repository.getSavedSearches();

      expect(results, hasLength(1));
      expect(results.first.id, equals('search-a1'));
    });

    test('getSavedSearches returns empty list when unauthenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final results = await repository.getSavedSearches();

      expect(results, isEmpty);
    });

    test('toggleSavedSearchPin affects only owning user records', () async {
      await seedSavedSearch(
        id: 'search-toggle-own',
        userId: _userA,
        isPinned: false,
      );
      await seedSavedSearch(
        id: 'search-toggle-other',
        userId: _userB,
        isPinned: false,
      );
      await authenticate(_userA);

      await repository.toggleSavedSearchPin('search-toggle-own');
      await repository.toggleSavedSearchPin('search-toggle-other');

      final own = await db.getSavedSearchById('search-toggle-own');
      final other = await db.getSavedSearchById('search-toggle-other');
      expect(own!.isPinned, isTrue);
      expect(other!.isPinned, isFalse);
    });

    test('trackSavedSearchUsage updates only current user entries', () async {
      await seedSavedSearch(id: 'usage-own', userId: _userA, usageCount: 1);
      await seedSavedSearch(id: 'usage-other', userId: _userB, usageCount: 1);
      await authenticate(_userA);

      await repository.trackSavedSearchUsage('usage-own');
      await repository.trackSavedSearchUsage('usage-other');

      final own = await db.getSavedSearchById('usage-own');
      final other = await db.getSavedSearchById('usage-other');
      expect(own!.usageCount, equals(2));
      expect(other!.usageCount, equals(1));
    });

    test(
      'watchSavedSearches emits empty list for unauthenticated users',
      () async {
        when(mockAuth.currentUser).thenReturn(null);

        final values = await repository.watchSavedSearches().first;

        expect(values, isEmpty);
      },
    );

    test('watchSavedSearches streams user-scoped updates', () async {
      await authenticate(_userA);
      await seedSavedSearch(id: 'watch-search', userId: _userA);

      final stream = repository.watchSavedSearches();
      final firstEmission = await stream.first;

      expect(firstEmission.map((s) => s.id), contains('watch-search'));
    });
  });
}
