import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';

import '../security/authorization_service_test.mocks.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDb database;
  late NotesCoreRepository repository;
  late FolderCoreRepository folderRepository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late StubCryptoBox crypto;
  late NoteIndexer indexer;
  late NotesTestSecureApi secureApi;
  late ProviderContainer providerContainer;

  String? currentUserId;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDb.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    crypto = StubCryptoBox();
    providerContainer = ProviderContainer();
    final ref = providerContainer.read(_refProvider);
    indexer = NoteIndexer(ref);
    secureApi = NotesTestSecureApi(() => currentUserId ?? '');

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(
      mockAuth.currentUser,
    ).thenAnswer((_) => currentUserId == null ? null : mockUser);
    when(mockUser.id).thenAnswer((_) => currentUserId ?? '');

    repository = NotesCoreRepository(
      db: database,
      crypto: crypto,
      client: mockSupabase,
      indexer: indexer,
      secureApi: secureApi,
    );

    folderRepository = FolderCoreRepository(
      db: database,
      client: mockSupabase,
      crypto: crypto,
    );
  });

  Future<domain.Note?> createNote({
    required String userId,
    required String title,
  }) async {
    currentUserId = userId;
    return repository.createOrUpdate(title: title, body: 'Body for $title');
  }

  Future<void> createFolder({
    required String userId,
    required String folderId,
    String? name,
  }) async {
    final now = DateTime.now();
    final folder = db.LocalFolder(
      id: folderId,
      userId: userId,
      name: name ?? 'Folder $folderId',
      parentId: null,
      path: '/${name ?? folderId}',
      sortOrder: 0,
      color: null,
      icon: null,
      description: '',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    );
    await database.upsertFolder(folder);
  }

  Future<void> assignNoteToFolder({
    required String noteId,
    required String folderId,
    required String userId,
  }) async {
    await database.moveNoteToFolder(noteId, folderId, expectedUserId: userId);
  }

  tearDown(() async {
    await database.close();
    providerContainer.dispose();
    currentUserId = null;
  });

  test(
    'FolderCoreRepository.moveNoteToFolder enforces user isolation',
    () async {
      final note = await createNote(userId: 'user-a', title: 'Folder Move');
      await createFolder(
        userId: 'user-a',
        folderId: 'folder-a',
        name: 'Folder A',
      );

      currentUserId = 'user-b';
      await folderRepository.moveNoteToFolder(note!.id, 'folder-a');

      currentUserId = 'user-a';
      final afterUnauthorized = await repository.getNoteById(note.id);
      expect(afterUnauthorized, isNotNull);
      expect(afterUnauthorized!.folderId, isNull);

      await folderRepository.moveNoteToFolder(note.id, 'folder-a');
      final afterAuthorized = await repository.getNoteById(note.id);
      expect(afterAuthorized, isNotNull);
      expect(afterAuthorized!.folderId, 'folder-a');
    },
  );

  test(
    'FolderCoreRepository.removeNoteFromFolder requires ownership',
    () async {
      final note = await createNote(userId: 'user-a', title: 'Folder Remove');
      await createFolder(
        userId: 'user-a',
        folderId: 'folder-a',
        name: 'Folder A',
      );
      await assignNoteToFolder(
        noteId: note!.id,
        folderId: 'folder-a',
        userId: 'user-a',
      );

      currentUserId = 'user-b';
      await folderRepository.removeNoteFromFolder(note.id);

      currentUserId = 'user-a';
      final afterUnauthorized = await repository.getNoteById(note.id);
      expect(afterUnauthorized, isNotNull);
      expect(afterUnauthorized!.folderId, 'folder-a');

      await folderRepository.removeNoteFromFolder(note.id);
      final afterAuthorized = await repository.getNoteById(note.id);
      expect(afterAuthorized, isNotNull);
      expect(afterAuthorized!.folderId, isNull);
    },
  );

  test('createOrUpdate returns null when unauthenticated', () async {
    currentUserId = null;

    final result = await repository.createOrUpdate(
      title: 'Hello',
      body: 'World',
    );

    expect(result, isNull);
  });

  test('list returns notes for the authenticated user only', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Note A');
    final noteB = await createNote(userId: 'user-b', title: 'Note B');

    currentUserId = 'user-a';
    final notesForA = await repository.list();
    expect(notesForA.map((n) => n.id), [noteA!.id]);

    currentUserId = 'user-b';
    final notesForB = await repository.list();
    expect(notesForB.map((n) => n.id), [noteB!.id]);
  });

  test('getNoteById enforces ownership', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Secret Note');

    currentUserId = 'user-b';
    final unauthorized = await repository.getNoteById(noteA!.id);
    expect(unauthorized, isNull);
  });

  test('localNotesForSync and localNotes are user scoped', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Sync A');
    await createNote(userId: 'user-b', title: 'Sync B');

    currentUserId = 'user-a';
    final syncA = await repository.localNotesForSync();
    expect(syncA.map((n) => n.id), [noteA!.id]);

    final uiNotesA = await repository.localNotes();
    expect(uiNotesA.map((n) => n.id), [noteA.id]);
  });

  test('watchNotes stream emits only current user notes', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Stream A');
    currentUserId = 'user-a';

    final firstEmission = await repository.watchNotes().first;
    expect(firstEmission.map((n) => n.id), [noteA!.id]);

    await createNote(userId: 'user-b', title: 'Stream B');
    currentUserId = 'user-b';

    final secondEmission = await repository.watchNotes().first;
    expect(secondEmission.map((n) => n.userId).toSet(), {'user-b'});
  });

  test('toggleNotePin enforces user isolation', () async {
    final note = await createNote(userId: 'user-a', title: 'Pin Toggle');
    final noteId = note!.id;

    currentUserId = 'user-b';
    await repository.toggleNotePin(noteId);

    currentUserId = 'user-a';
    final afterUnauthorized = await repository.getNoteById(noteId);
    expect(afterUnauthorized, isNotNull);
    expect(afterUnauthorized!.isPinned, isFalse);

    await repository.toggleNotePin(noteId);
    final afterAuthorized = await repository.getNoteById(noteId);
    expect(afterAuthorized, isNotNull);
    expect(afterAuthorized!.isPinned, isTrue);
  });

  test('setNotePin only updates owner notes', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Pin Set A');
    final noteB = await createNote(userId: 'user-b', title: 'Pin Set B');

    currentUserId = 'user-b';
    await repository.setNotePin(noteA!.id, true);

    currentUserId = 'user-a';
    final stillUnpinned = await repository.getNoteById(noteA.id);
    expect(stillUnpinned, isNotNull);
    expect(stillUnpinned!.isPinned, isFalse);

    await repository.setNotePin(noteA.id, true);
    final pinned = await repository.getNoteById(noteA.id);
    expect(pinned, isNotNull);
    expect(pinned!.isPinned, isTrue);

    currentUserId = 'user-b';
    await repository.setNotePin(noteB!.id, true);
    final pinnedB = await repository.getNoteById(noteB.id);
    expect(pinnedB, isNotNull);
    expect(pinnedB!.isPinned, isTrue);
  });

  test('getPinnedNotes returns pins for current user only', () async {
    final noteA = await createNote(userId: 'user-a', title: 'Pinned A');
    final noteB = await createNote(userId: 'user-b', title: 'Pinned B');

    currentUserId = 'user-a';
    await repository.setNotePin(noteA!.id, true);

    currentUserId = 'user-b';
    await repository.setNotePin(noteB!.id, true);

    currentUserId = 'user-a';
    final pinnedA = await repository.getPinnedNotes();
    expect(pinnedA.map((n) => n.id), [noteA.id]);

    currentUserId = 'user-b';
    final pinnedB = await repository.getPinnedNotes();
    expect(pinnedB.map((n) => n.id), [noteB.id]);
  });

  test('folder counts and ids are scoped per user', () async {
    final noteA1 = await createNote(userId: 'user-a', title: 'Folder A1');
    final noteA2 = await createNote(userId: 'user-a', title: 'Folder A2');
    final noteB1 = await createNote(userId: 'user-b', title: 'Folder B1');

    await createFolder(
      userId: 'user-a',
      folderId: 'folder-a',
      name: 'Folder A',
    );
    await createFolder(
      userId: 'user-b',
      folderId: 'folder-b',
      name: 'Folder B',
    );

    await assignNoteToFolder(
      noteId: noteA1!.id,
      folderId: 'folder-a',
      userId: 'user-a',
    );
    await assignNoteToFolder(
      noteId: noteA2!.id,
      folderId: 'folder-a',
      userId: 'user-a',
    );
    await assignNoteToFolder(
      noteId: noteB1!.id,
      folderId: 'folder-b',
      userId: 'user-b',
    );

    currentUserId = 'user-a';
    final countA = await repository.getNotesCountInFolder('folder-a');
    expect(countA, 2);
    final idsA = await repository.getNoteIdsInFolder('folder-a');
    expect(idsA.toSet(), {noteA1.id, noteA2.id});

    // Cross-user access should not leak user A data
    currentUserId = 'user-b';
    final crossCount = await repository.getNotesCountInFolder('folder-a');
    expect(crossCount, 0);
    final crossIds = await repository.getNoteIdsInFolder('folder-a');
    expect(crossIds, isEmpty);

    final countB = await repository.getNotesCountInFolder('folder-b');
    expect(countB, 1);
    final idsB = await repository.getNoteIdsInFolder('folder-b');
    expect(idsB, [noteB1.id]);
  });

  test('CaptureNotesAdapter enforces authentication boundary', () async {
    final adapter = CaptureNotesAdapter(repository: repository, db: database);

    currentUserId = null;
    final unauthId = await adapter.createEncryptedNote(
      title: 'Inbox Note',
      body: 'Body',
      metadataJson: const {},
    );
    expect(unauthId, isEmpty);

    currentUserId = 'user-a';
    final createdId = await adapter.createEncryptedNote(
      title: 'Inbox Note',
      body: 'Body',
      metadataJson: const {'source': 'test'},
    );
    expect(createdId, isNotEmpty);

    final ownerView = await repository.getNoteById(createdId);
    expect(ownerView, isNotNull);
    expect(ownerView!.userId, 'user-a');

    currentUserId = 'user-b';
    final otherView = await repository.getNoteById(createdId);
    expect(otherView, isNull);
  });
}

class StubCryptoBox implements CryptoBox {
  Uint8List _encodeString(String value) =>
      Uint8List.fromList(utf8.encode('enc:$value'));

  Uint8List _encodeJson(Map<String, dynamic> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  String _decodeString(Uint8List data) {
    final decoded = utf8.decode(data);
    return decoded.startsWith('enc:') ? decoded.substring(4) : decoded;
  }

  Map<String, dynamic> _decodeJson(Uint8List data) =>
      jsonDecode(utf8.decode(data)) as Map<String, dynamic>;

  @override
  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async => _encodeString(text);

  @override
  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => _decodeString(data);

  @override
  Future<Uint8List> encryptJsonForNote({
    required String userId,
    required String noteId,
    required Map<String, dynamic> json,
  }) async => _encodeJson(json);

  @override
  Future<Map<String, dynamic>> decryptJsonForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => _decodeJson(data);

  @override
  Future<DecryptResult<Map<String, dynamic>>> decryptJsonForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => DecryptResult(value: _decodeJson(data), usedLegacyKey: false);

  @override
  Future<DecryptResult<String>> decryptStringForNoteWithFallback({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => DecryptResult(value: _decodeString(data), usedLegacyKey: false);

}

class NotesTestSecureApi extends SecureApiWrapper {
  NotesTestSecureApi(String Function()? resolver)
    : super.testing(
        api: _NoopSupabaseNoteApi(MockSupabaseClient()),
        userIdResolver: resolver,
      );
}

class _NoopSupabaseNoteApi extends SupabaseNoteApi {
  _NoopSupabaseNoteApi(super.client);

  @override
  Future<void> upsertEncryptedNote({
    DateTime? createdAt,
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async => [];

  @override
  Future<Set<String>> fetchAllActiveIds() async => {};

  @override
  Future<void> upsertEncryptedFolder({
    required String id,
    required Uint8List nameEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchEncryptedFolders({
    DateTime? since,
  }) async => [];

  @override
  Future<Set<String>> fetchAllActiveFolderIds() async => {};

  @override
  Future<void> upsertNoteFolderRelation({
    required String noteId,
    required String folderId,
  }) async {}

  @override
  Future<void> removeNoteFolderRelation({required String noteId}) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelations({
    DateTime? since,
  }) async => [];

  @override
  Future<void> upsertNoteTask({
    required String id,
    required String noteId,
    required String content,
    required String status,
    int priority = 0,
    int position = 0,
    DateTime? dueDate,
    DateTime? completedAt,
    String? parentId,
    Map<String, dynamic>? labels,
    Map<String, dynamic>? metadata,
    required bool deleted,
  }) async {}

  @override
  Future<void> deleteNoteTask({required String id}) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchNoteTasks({DateTime? since}) async =>
      [];

  @override
  Future<Set<String>> fetchAllActiveTaskIds() async => {};

  @override
  Future<void> upsertTemplate({
    required String id,
    required String userId,
    required String titleEnc,
    required String bodyEnc,
    String? tagsEnc,
    required bool isSystem,
    required String category,
    String? descriptionEnc,
    String? icon,
    int sortOrder = 0,
    String? propsEnc,
    required bool deleted,
  }) async {}

  @override
  Future<void> deleteTemplate({required String id}) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async =>
      [];
}
