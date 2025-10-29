import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/cache/decryption_cache.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../helpers/test_initialization.dart';

class _MockCryptoBox extends Mock implements CryptoBox {}

class _FakeDecryptionCache implements DecryptionCache {
  const _FakeDecryptionCache();

  @override
  Future<Map<String, DecryptedContent>> decryptNotesBatch(
    List<LocalNote> notes, {
    bool useCache = true,
  }) async => <String, DecryptedContent>{};

  @override
  Future<DecryptedContent> getDecryptedNote(LocalNote note) async =>
      DecryptedContent(title: '', body: '', cachedAt: DateTime.now());

  @override
  Future<Map<String, String>> decryptTasksBatch(
    List<NoteTask> tasks, {
    bool useCache = true,
  }) async => <String, String>{};

  @override
  void invalidateNote(String noteId) {}

  @override
  void invalidateNotes(List<String> noteIds) {}

  @override
  void clear() {}

  @override
  int clearExpired() => 0;

  @override
  int get cacheSize => 0;

  @override
  Future<void> warmUp(List<LocalNote> notes) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestInitialization.initialize(initializeSupabase: true);
  });

  late AppDb db;
  late FolderCoreRepository repository;
  late SupabaseClient supabaseClient;

  setUp(() async {
    db = AppDb.forTesting(NativeDatabase.memory());
    supabaseClient = SupabaseClient('https://test.supabase.co', 'test-key');
    repository = FolderCoreRepository(
      db: db,
      client: supabaseClient,
      crypto: _MockCryptoBox(),
      decryptionCache: const _FakeDecryptionCache(),
      userIdResolver: () => 'user-123',
    );

    await _seedFolders(db);
    final seededFolders = await db.select(db.localFolders).get();
    expect(seededFolders, hasLength(3));
  });

  tearDown(() async {
    await db.close();
  });

  test('listFolders returns folders owned by the active user', () async {
    final folders = await repository.listFolders();
    final folderIds = folders.map((folder) => folder.id).toList();

    expect(folderIds, containsAll(<String>['folder-alpha', 'folder-beta']));
    expect(folderIds, isNot(contains('folder-other')));
  });

  test(
    'createFolder persists folder for current user and enqueues sync op',
    () async {
      final created = await repository.createFolder(name: 'Launch Plans');

      final stored = await db.getFolderById(created.id);
      expect(stored, isNotNull);
      expect(stored!.userId, equals('user-123'));

      final pendingOps = await db.getPendingOpsForUser('user-123');
      expect(pendingOps.any((op) => op.kind == 'upsert_folder'), isTrue);
    },
  );

  test('renameFolder enforces ownership', () async {
    final otherUserRepository = FolderCoreRepository(
      db: db,
      client: supabaseClient,
      crypto: _MockCryptoBox(),
      decryptionCache: const _FakeDecryptionCache(),
      userIdResolver: () => 'user-456',
    );

    await expectLater(
      otherUserRepository.renameFolder('folder-alpha', 'Unauthorized Rename'),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteFolder removes user folder and enqueues deletion', () async {
    await repository.deleteFolder('folder-beta');

    final remaining = await repository.listFolders();
    expect(
      remaining.map((folder) => folder.id),
      isNot(contains('folder-beta')),
    );

    final pendingOps = await db.getPendingOpsForUser('user-123');
    expect(pendingOps.any((op) => op.kind == 'delete_folder'), isTrue);
  });
}

Future<void> _seedFolders(AppDb db) async {
  final now = DateTime.utc(2025, 10, 26);

  await db
      .into(db.localFolders)
      .insert(
        LocalFoldersCompanion.insert(
          id: 'folder-alpha',
          userId: 'user-123',
          name: 'Project Mercury',
          parentId: const Value(null),
          path: '/Project Mercury',
          sortOrder: const Value(0),
          color: const Value('#FFAA00'),
          icon: const Value('rocket_launch'),
          description: const Value('Primary mission workspace'),
          createdAt: now,
          updatedAt: now,
          deleted: const Value(false),
        ),
      );

  await db
      .into(db.localFolders)
      .insert(
        LocalFoldersCompanion.insert(
          id: 'folder-beta',
          userId: 'user-123',
          name: 'Launch Logs',
          parentId: const Value('folder-alpha'),
          path: '/Project Mercury/Launch Logs',
          sortOrder: const Value(1),
          color: const Value('#00AAFF'),
          icon: const Value('auto_stories'),
          description: const Value('Detailed launch records'),
          createdAt: now,
          updatedAt: now,
          deleted: const Value(false),
        ),
      );

  await db
      .into(db.localFolders)
      .insert(
        LocalFoldersCompanion.insert(
          id: 'folder-other',
          userId: 'user-456',
          name: 'Other User Folder',
          parentId: const Value(null),
          path: '/Other',
          sortOrder: const Value(0),
          color: const Value('#CCCCCC'),
          icon: const Value('lock'),
          description: const Value('Should not appear for current user'),
          createdAt: now,
          updatedAt: now,
          deleted: const Value(false),
        ),
      );
}
