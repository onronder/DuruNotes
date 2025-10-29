import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/security_test_setup.dart';
import '../repository/notes_repository_test.mocks.dart';

class _StubNoteIndexer implements NoteIndexer {
  @override
  Future<void> clearIndex() async {}

  @override
  Future<void> indexNote(domain.Note note) async {}

  @override
  Future<void> rebuildIndex(List<domain.Note> allNotes) async {}

  @override
  Future<void> removeNoteFromIndex(String noteId) async {}

  @override
  Map<String, int> getIndexStats() => const {};

  @override
  Set<String> findNotesByTag(String tag) => {};

  @override
  Set<String> findNotesLinkingTo(String noteId) => {};

  @override
  Set<String> searchNotes(String query) => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagRepository authorization', () {
    late AppDb db;
    late NotesCoreRepository notesRepository;
    late TagRepository tagRepository;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUserA;
    late MockUser mockUserB;
    late MockSupabaseNoteApi mockNoteApi;
    late _StubNoteIndexer indexer;
    late CryptoBox crypto;
    MockUser? activeUser;

    setUp(() async {
      await SecurityTestSetup.setupMockEncryption();

      db = AppDb.forTesting(NativeDatabase.memory());
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUserA = MockUser();
      mockUserB = MockUser();
      mockNoteApi = MockSupabaseNoteApi();
      indexer = _StubNoteIndexer();
      crypto = SecurityTestSetup.createTestCryptoBox();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockUserA.id).thenReturn('user-a');
      when(mockUserB.id).thenReturn('user-b');

      activeUser = mockUserA;
      when(mockAuth.currentUser).thenAnswer((_) => activeUser);

      when(mockNoteApi.fetchEncryptedNotes(since: anyNamed('since')))
          .thenAnswer((_) async => const []);
      when(mockNoteApi.fetchEncryptedFolders(since: anyNamed('since')))
          .thenAnswer((_) async => const []);
      when(mockNoteApi.fetchNoteTasks(since: anyNamed('since')))
          .thenAnswer((_) async => const []);
      when(mockNoteApi.fetchTemplates(since: anyNamed('since')))
          .thenAnswer((_) async => const []);
      when(mockNoteApi.fetchNoteFolderRelations(since: anyNamed('since')))
          .thenAnswer((_) async => const []);
      when(mockNoteApi.fetchNoteFolderRelations())
          .thenAnswer((_) async => const []);
      when(mockNoteApi.upsertEncryptedNote(
        id: anyNamed('id'),
        titleEnc: anyNamed('titleEnc'),
        propsEnc: anyNamed('propsEnc'),
        deleted: anyNamed('deleted'),
        createdAt: anyNamed('createdAt'),
      )).thenAnswer((_) async {});

      final secureApi = SecureApiWrapper.testing(
        api: mockNoteApi,
        userIdResolver: () => activeUser?.id ?? '',
      );

      notesRepository = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: mockSupabase,
        indexer: indexer,
        secureApi: secureApi,
      );

      tagRepository = TagRepository(
        db: db,
        client: mockSupabase,
        crypto: crypto,
      );
    });

    tearDown(() async {
      await db.close();
      SecurityTestSetup.teardownEncryption();
    });

    Future<domain.Note?> createNoteFor(MockUser? user, String title) async {
      activeUser = user;
      return notesRepository.createOrUpdate(
        title: title,
        body: '$title body',
      );
    }

    Future<List<String>> dbTagsFor(String noteId) async {
      final rows = await (db.select(db.noteTags)
            ..where((t) => t.noteId.equals(noteId)))
          .get();
      return rows.map((row) => row.tag).toList();
    }

    test('listTagsWithCounts returns empty when user not authenticated', () async {
      activeUser = null;

      final tags = await tagRepository.listTagsWithCounts();
      expect(tags, isEmpty);
    });

    test('addTag only persists for owning user', () async {
      final note = await createNoteFor(mockUserA, 'User A');
      final noteId = note!.id;

      activeUser = mockUserA;
      await tagRepository.addTag(noteId: noteId, tag: 'alpha');

      final afterOwnerAdd = await dbTagsFor(noteId);
      expect(afterOwnerAdd, contains('alpha'));

      activeUser = mockUserB;
      await tagRepository.addTag(noteId: noteId, tag: 'beta');

      final afterForeignAdd = await dbTagsFor(noteId);
      expect(afterForeignAdd, contains('alpha'));
      expect(afterForeignAdd, isNot(contains('beta')));

      final pendingOps =
          await (db.select(db.pendingOps)..where((op) => op.userId.equals('user-a')))
              .get();
      expect(pendingOps, isNotEmpty);
      expect(pendingOps.every((op) => op.userId == 'user-a'), isTrue);
    });

    test('removeTag ignores requests from other users', () async {
      final note = await createNoteFor(mockUserA, 'Owner');
      final noteId = note!.id;

      activeUser = mockUserA;
      await tagRepository.addTag(noteId: noteId, tag: 'alpha');
      expect(await dbTagsFor(noteId), contains('alpha'));

      activeUser = mockUserB;
      await tagRepository.removeTag(noteId: noteId, tag: 'alpha');
      expect(await dbTagsFor(noteId), contains('alpha'));

      activeUser = mockUserA;
      await tagRepository.removeTag(noteId: noteId, tag: 'alpha');
      expect(await dbTagsFor(noteId), isEmpty);
    });

    test('listTagsWithCounts isolates results per user', () async {
      final noteA = await createNoteFor(mockUserA, 'Note A');
      await tagRepository.addTag(noteId: noteA!.id, tag: 'alpha');

      final noteB = await createNoteFor(mockUserB, 'Note B');
      activeUser = mockUserB;
      await tagRepository.addTag(noteId: noteB!.id, tag: 'beta');

      activeUser = mockUserA;
      final tagsForA = await tagRepository.listTagsWithCounts();
      expect(tagsForA.map((t) => t.tag), contains('alpha'));
      expect(tagsForA.map((t) => t.tag), isNot(contains('beta')));

      activeUser = mockUserB;
      final tagsForB = await tagRepository.listTagsWithCounts();
      expect(tagsForB.map((t) => t.tag), contains('beta'));
      expect(tagsForB.map((t) => t.tag), isNot(contains('alpha')));
    });

    test('getTagsForNote only returns tags for authenticated owner', () async {
      final note = await createNoteFor(mockUserA, 'Tagged Note');
      final noteId = note!.id;

      activeUser = mockUserA;
      await tagRepository.addTag(noteId: noteId, tag: 'alpha');
      await tagRepository.addTag(noteId: noteId, tag: 'beta');

      final ownerTags = await tagRepository.getTagsForNote(noteId);
      expect(ownerTags, containsAll(['alpha', 'beta']));

      activeUser = mockUserB;
      final otherTags = await tagRepository.getTagsForNote(noteId);
      expect(otherTags, isEmpty);
    });
  });
}
