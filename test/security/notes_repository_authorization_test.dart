import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
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

  group('NotesCoreRepository authorization', () {
    late AppDb db;
    late NotesCoreRepository repository;
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

      repository = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: mockSupabase,
        indexer: indexer,
        secureApi: secureApi,
      );
    });

    tearDown(() async {
      await db.close();
      SecurityTestSetup.teardownEncryption();
    });

    Future<domain.Note?> createNoteFor(MockUser? user,
        {String title = 'Title', String body = 'Body'}) async {
      activeUser = user;
      return repository.createOrUpdate(
        title: title,
        body: body,
      );
    }

    test('createOrUpdate returns null when user not authenticated', () async {
      activeUser = null;

      final created = await repository.createOrUpdate(
        title: 'Unauthenticated',
        body: 'No access',
      );

      expect(created, isNull);
      final rows = await db.select(db.localNotes).get();
      expect(rows, isEmpty);
    });

    test('createOrUpdate stores note for current user', () async {
      activeUser = mockUserA;

      final created = await repository.createOrUpdate(
        title: 'User A Note',
        body: 'Owned by user A',
      );

      expect(created, isNotNull);
      expect(created!.userId, 'user-a');

      final stored = await (db.select(db.localNotes)).getSingle();
      expect(stored.userId, 'user-a');
    });

    test('getNoteById returns null when note belongs to another user', () async {
      final created = await createNoteFor(mockUserA);
      expect(created, isNotNull);

      activeUser = mockUserB;
      final fetched = await repository.getNoteById(created!.id);
      expect(fetched, isNull);
    });

    test('localNotes returns only notes for current user', () async {
      final noteA = await createNoteFor(mockUserA, title: 'Owned by A');
      expect(noteA, isNotNull);

      final noteB = await createNoteFor(mockUserB, title: 'Owned by B');
      expect(noteB, isNotNull);

      activeUser = mockUserA;
      final notesForA = await repository.localNotes();
      expect(notesForA, isNotEmpty);
      expect(notesForA.every((note) => note.userId == 'user-a'), isTrue);
      expect(notesForA.map((note) => note.id), contains(noteA!.id));
      expect(notesForA.map((note) => note.id), isNot(contains(noteB!.id)));
    });

    test('updateLocalNote ignores updates from non-owners', () async {
      final created = await createNoteFor(mockUserA, title: 'Initial Title');
      final noteId = created!.id;

      activeUser = mockUserB;
      await repository.updateLocalNote(noteId, title: 'Hacked');

      activeUser = mockUserA;
      final refreshed = await repository.getNoteById(noteId);
      expect(refreshed, isNotNull);
      expect(refreshed!.title, 'Initial Title');
    });

    test('deleteNote only marks note deleted for owner', () async {
      final created = await createNoteFor(mockUserA, title: 'To Delete');
      final noteId = created!.id;

      activeUser = mockUserB;
      await repository.deleteNote(noteId);

      activeUser = mockUserA;
      final stillPresent = await repository.getNoteById(noteId);
      expect(stillPresent, isNotNull);

      await repository.deleteNote(noteId);
      final rawAfterDelete = await (db.select(db.localNotes)
            ..where((n) => n.id.equals(noteId)))
          .getSingle();
      expect(rawAfterDelete.deleted, isTrue);

      final visibleNotes = await repository.localNotes();
      expect(visibleNotes.map((note) => note.id), isNot(contains(noteId)));
    });
  });
}
