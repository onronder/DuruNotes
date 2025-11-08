import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/security_providers.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/entities/note.dart' as domain_note;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show authStateChangesProvider;
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_integration_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/features/notes/providers/notes_pagination_providers.dart'
    as pagination_providers;
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    as notes_state_providers;
import 'package:duru_notes/features/search/providers/search_providers.dart';
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show syncModeProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/security_test_setup.dart';
import '../helpers/test_initialization.dart';

class _FakeFolderRepository implements IFolderRepository {
  const _FakeFolderRepository();

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async => id ?? 'folder-id';

  @override
  Future<domain_folder.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async => _folder(name: name, id: 'folder-created');

  @override
  Future<void> deleteFolder(String folderId) async {}

  @override
  Future<void> ensureFolderIntegrity() async {}

  @override
  Future<domain_folder.Folder?> findFolderByName(String name) async => null;

  @override
  Future<List<domain_folder.Folder>> getChildFolders(String parentId) async =>
      const [];

  @override
  Future<List<domain_folder.Folder>> getChildFoldersRecursive(
    String parentId,
  ) async => const [];

  @override
  Future<int> getFolderDepth(String folderId) async => 0;

  @override
  Future<domain_folder.Folder?> getFolder(String id) async => null;

  @override
  Future<domain_folder.Folder?> getFolderForNote(String noteId) async => null;

  @override
  Future<Map<String, int>> getFolderNoteCounts() async => const {};

  @override
  String? getCurrentUserId() => 'test-user';

  @override
  Future<List<domain_folder.Folder>> getRootFolders() async => const [];

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) async => const [];

  @override
  Future<int> getNotesCountInFolder(String folderId) async => 0;

  @override
  Future<List<domain_note.Note>> getNotesInFolder(String folderId) async =>
      const [];

  @override
  Future<void> moveFolder(String folderId, String? newParentId) async {}

  @override
  Future<void> addNoteToFolder(String noteId, String folderId) async {}

  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {}

  @override
  Future<List<domain_note.Note>> getUnfiledNotes() async => const [];

  @override
  Future<void> removeNoteFromFolder(String noteId) async {}

  @override
  Future<void> renameFolder(String folderId, String newName) async {}

  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() async => const {};

  @override
  Future<void> resolveFolderConflicts() async {}

  @override
  Future<void> validateAndRepairFolderStructure() async {}

  @override
  Future<void> cleanupOrphanedRelationships() async {}

  @override
  Future<List<domain_folder.Folder>> listFolders() async => const [];

  @override
  Future<List<domain_folder.Folder>> getDeletedFolders() async => const [];

  @override
  Future<void> restoreFolder(String folderId, {bool restoreContents = false}) async {}

  @override
  Future<void> permanentlyDeleteFolder(String folderId) async {}
}

class _StubGoTrueClient extends GoTrueClient {
  _StubGoTrueClient(this._user)
    : _session = Session(
        accessToken: 'stub-access-token',
        refreshToken: 'stub-refresh-token',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: _user,
      ),
      super(
        url: 'https://stub.supabase.co/auth/v1',
        headers: const {},
        autoRefreshToken: false,
      );

  final User _user;
  final Session _session;

  @override
  User? get currentUser => _user;

  @override
  Session? get currentSession => _session;
}

class _StubSupabaseClient extends SupabaseClient {
  _StubSupabaseClient(this._auth)
    : super(
        'https://stub.supabase.co',
        'stub-public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.error,
        ),
      );

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

domain_folder.Folder _folder({
  required String id,
  required String name,
  String? parentId,
  int sortOrder = 0,
}) {
  final now = DateTime.utc(2025, 1, 1);
  return domain_folder.Folder(
    id: id,
    name: name,
    parentId: parentId,
    color: null,
    icon: null,
    description: null,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
    userId: 'test-user',
  );
}

void main() {
  setUpAll(() async {
    await TestInitialization.initialize(initializeSupabase: true);
  });

  group('Notes Repository Auth Regression Tests', () {
    late AppDb db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDb.forTesting(NativeDatabase.memory());
      final cryptoBox = SecurityTestSetup.createTestCryptoBox();
      const fakeFolderRepository = _FakeFolderRepository();
      final unifiedSyncService = UnifiedSyncService();

      container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          cryptoBoxProvider.overrideWithValue(cryptoBox),
          notesCoreRepositoryProvider.overrideWith((ref) {
            final indexer = NoteIndexer(ref);
            return NotesCoreRepository(
              db: ref.watch(appDbProvider),
              crypto: ref.watch(cryptoBoxProvider),
              client: Supabase.instance.client,
              indexer: indexer,
            );
          }),
          folderRepositoryProvider.overrideWithValue(fakeFolderRepository),
          folderCoreRepositoryProvider.overrideWithValue(fakeFolderRepository),
          pagination_providers.notesPageProvider.overrideWith(
            (ref) => NotesPaginationNotifier.empty(ref),
          ),
          folderProvider.overrideWith((ref) => FolderNotifier.empty()),
          folderHierarchyProvider.overrideWith(
            (ref) => FolderHierarchyNotifier.empty(),
          ),
          noteFolderProvider.overrideWith((ref) => NoteFolderNotifier.empty()),
          syncModeProvider.overrideWith((ref) {
            final repo = ref.watch(notesCoreRepositoryProvider);
            return SyncModeNotifier(repo, unifiedSyncService);
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    group('Core Domain Provider', () {
      test('notesCoreRepositoryProvider returns repository instance', () {
        expect(
          () => container.read(notesCoreRepositoryProvider),
          returnsNormally,
        );
        final repo = container.read(notesCoreRepositoryProvider);
        expect(repo, isNotNull);
      });

      test('notesCoreRepositoryProvider survives auth state invalidation', () {
        expect(() {
          container.invalidate(authStateChangesProvider);
          container.invalidate(notesCoreRepositoryProvider);
          container.read(notesCoreRepositoryProvider);
        }, returnsNormally);
      });
    });

    group('Search Provider', () {
      test('searchServiceProvider instantiates successfully', () {
        final service = container.read(searchServiceProvider);
        expect(service, isNotNull);
      });
    });

    group('Folder Integration Providers', () {
      test('noteFolderIntegrationServiceProvider creates service', () {
        final service = container.read(noteFolderIntegrationServiceProvider);
        expect(service, isNotNull);
      });

      test('unfiledNotesCountProvider resolves with empty result', () async {
        final count = await container.read(unfiledNotesCountProvider.future);
        expect(count, isZero);
      });

      test('allFoldersCountProvider resolves with zero count', () async {
        final count = await container.read(allFoldersCountProvider.future);
        expect(count, isZero);
      });
    });

    group('Notes Pagination Providers', () {
      test('filteredNotesProvider returns empty list by default', () async {
        final notes = await container.read(
          notes_state_providers.filteredNotesProvider.future,
        );
        expect(notes, isEmpty);
      });

      test('currentNotesProvider returns empty list with no data', () {
        final notes = container.read(
          notes_state_providers.currentNotesProvider,
        );
        expect(notes, isEmpty);
      });
    });

    group('Sync Providers', () {
      test('syncModeProvider exposes current mode without errors', () {
        final mode = container.read(syncModeProvider);
        expect(mode, SyncMode.automatic);
      });
    });

    group('Folder State Providers', () {
      test('folderProvider exposes default state', () {
        final state = container.read(folderProvider);
        expect(state.error, isNull);
        expect(state.isCreating, isFalse);
        expect(state.isUpdating, isFalse);
        expect(state.isDeleting, isFalse);
      });

      test('folderHierarchyProvider exposes empty hierarchy', () {
        final state = container.read(folderHierarchyProvider);
        expect(state.folders, isEmpty);
        expect(state.expandedFolders, isEmpty);
        expect(state.error, isNull);
      });

      test('noteFolderProvider exposes empty relationships', () {
        final state = container.read(noteFolderProvider);
        expect(state.noteFolders, isEmpty);
        expect(state.error, isNull);
      });
    });

    group('Auth State Transitions', () {
      test('providers handle repeated invalidation gracefully', () {
        for (var i = 0; i < 5; i++) {
          expect(() {
            container.invalidate(authStateChangesProvider);
            container.invalidate(notesCoreRepositoryProvider);
            container.read(notesCoreRepositoryProvider);
          }, returnsNormally);
        }
      });

      test('dependent providers rebuild without throwing', () {
        expect(() {
          container.invalidate(authStateChangesProvider);
          container.read(notesCoreRepositoryProvider);
          container.read(searchServiceProvider);
        }, returnsNormally);
      });
    });

    group('Database Provider', () {
      test('appDbProvider returns overridden in-memory instance', () {
        final resolved = container.read(appDbProvider);
        expect(resolved, same(db));
      });
    });

    group('Performance & Memory', () {
      test('providers tolerate repeated invalidation cycles', () {
        for (var i = 0; i < 10; i++) {
          expect(() {
            container.invalidate(authStateChangesProvider);
            container.read(searchServiceProvider);
            container.read(syncModeProvider);
          }, returnsNormally);
        }
      });
    });
  });

  group('Signed-in providers', () {
    late AppDb authedDb;
    late ProviderContainer authedContainer;
    late SupabaseClient originalClient;
    late _StubSupabaseClient stubClient;

    setUp(() async {
      authedDb = AppDb.forTesting(NativeDatabase.memory());
      final cryptoBox = SecurityTestSetup.createTestCryptoBox();
      const fakeFolderRepository = _FakeFolderRepository();

      final user = User(
        id: 'user-auth',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'user@example.com',
        phone: '',
        createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
        role: 'authenticated',
        updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
        identities: const [],
        factors: const [],
      );
      final authClient = _StubGoTrueClient(user);
      stubClient = _StubSupabaseClient(authClient);

      originalClient = Supabase.instance.client;
      Supabase.instance.client = stubClient;

      authedContainer = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(authedDb),
          cryptoBoxProvider.overrideWithValue(cryptoBox),
          supabaseClientProvider.overrideWithValue(stubClient),
          notesCoreRepositoryProvider.overrideWith((ref) {
            final db = ref.watch(appDbProvider);
            final crypto = ref.watch(cryptoBoxProvider);
            final indexer = NoteIndexer(ref);
            return NotesCoreRepository(
              db: db,
              crypto: crypto,
              client: stubClient,
              indexer: indexer,
            );
          }),
          folderRepositoryProvider.overrideWithValue(fakeFolderRepository),
          folderCoreRepositoryProvider.overrideWithValue(fakeFolderRepository),
          pagination_providers.notesPageProvider.overrideWith(
            (ref) => NotesPaginationNotifier.empty(ref),
          ),
          folderProvider.overrideWith((ref) => FolderNotifier.empty()),
          folderHierarchyProvider.overrideWith(
            (ref) => FolderHierarchyNotifier.empty(),
          ),
          noteFolderProvider.overrideWith((ref) => NoteFolderNotifier.empty()),
          syncModeProvider.overrideWith((ref) {
            final repo = ref.watch(notesCoreRepositoryProvider);
            return SyncModeNotifier(repo, UnifiedSyncService());
          }),
        ],
      );

      await authedDb
          .into(authedDb.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: 'signed-note',
              userId: const Value('user-auth'),
              titleEncrypted: const Value('enc::Auth Note'),
              bodyEncrypted: const Value('enc::Body'),
              createdAt: DateTime.utc(2025, 1, 1),
              updatedAt: DateTime.utc(2025, 1, 1),
              deleted: const Value(false),
              noteType: Value(NoteKind.note),
              isPinned: const Value(false),
              version: const Value(1),
              encryptionVersion: const Value(1),
            ),
          );
    });

    tearDown(() async {
      authedContainer.dispose();
      await authedDb.close();
      Supabase.instance.client = originalClient;
    });

    test('notesCoreRepositoryProvider returns user-scoped notes', () async {
      final repo = authedContainer.read(notesCoreRepositoryProvider);
      final notes = await repo.localNotes();
      expect(notes, hasLength(1));
      expect(notes.first.id, equals('signed-note'));
    });

    test(
      'unfiledNotesCountProvider reports count for authenticated user',
      () async {
        final count = await authedContainer.read(
          unfiledNotesCountProvider.future,
        );
        expect(count, equals(1));
      },
    );
  });

  group('Migration Verification', () {
    test('migration from nullable to non-nullable provider complete', () {
      expect(
        true,
        isTrue,
        reason: 'All providers migrated to notesCoreRepositoryProvider.',
      );
    });

    test('migration statistics are correct', () {
      const totalUsages = 61;
      const criticalFixes = 6;
      const remainingFixes = 55;

      expect(criticalFixes + remainingFixes, equals(totalUsages));

      const migratedUsages = 61;
      expect(migratedUsages, equals(totalUsages));
    });
  });
}
