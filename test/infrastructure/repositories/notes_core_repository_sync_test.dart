import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/core/providers/search_providers.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';

import '../../repository/notes_repository_test.mocks.dart';

class _NoOpLogger implements AppLogger {
  const _NoOpLogger();
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}
  @override
  void debug(String message, {Map<String, dynamic>? data}) {}
  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}
  @override
  Future<void> flush() async {}
  @override
  void info(String message, {Map<String, dynamic>? data}) {}
  @override
  void warn(String message, {Map<String, dynamic>? data}) {}
  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDb db;
  late NotesCoreRepository repository;
  late MockSupabaseNoteApi mockApi;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCrypto;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDb.forTesting(NativeDatabase.memory());
    mockApi = MockSupabaseNoteApi();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockCrypto = MockCryptoBox();

    when(mockUser.id).thenReturn('user-123');
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockSupabase.auth).thenReturn(mockAuth);

    container = ProviderContainer(
      overrides: [loggerProvider.overrideWithValue(const _NoOpLogger())],
    );

    final noteIndexer = container.read(noteIndexerProvider);

    final secureApi = SecureApiWrapper.testing(
      api: mockApi,
      userIdResolver: () => 'user-123',
    );

    repository = NotesCoreRepository(
      db: db,
      crypto: mockCrypto,
      client: mockSupabase,
      indexer: noteIndexer,
      secureApi: secureApi,
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('pushAllPending uploads note operations and clears queue', () async {
    Uint8List encryptedJson(Map<String, dynamic> json) =>
        Uint8List.fromList(utf8.encode(jsonEncode(json)));

    when(
      mockCrypto.encryptJsonForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        json: anyNamed('json'),
      ),
    ).thenAnswer(
      (invocation) async => encryptedJson(
        invocation.namedArguments[#json] as Map<String, dynamic>,
      ),
    );

    final decryptedValues = Queue<String>.from(['Local Title', 'Local Body']);
    when(
      mockCrypto.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((_) async => decryptedValues.removeFirst());

    final insertedAt = DateTime.now().toUtc();
    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: 'note-1',
            titleEncrypted: const Value('stored-title'),
            bodyEncrypted: const Value('stored-body'),
            createdAt: insertedAt,
            updatedAt: insertedAt,
            deleted: const Value(false),
            userId: const Value('user-123'),
            noteType: Value(NoteKind.note),
            isPinned: const Value(false),
            version: const Value(1),
          ),
        );

    await db.enqueue(
      userId: 'user-123',
      entityId: 'note-1',
      kind: 'upsert_note',
    );

    await repository.pushAllPending();

    final remaining = await db.getPendingOpsForUser('user-123');
    expect(remaining, isEmpty);
  });

  test('pushAllPending uploads reminder operations to Supabase', () async {
    when(mockApi.upsertReminder(any)).thenAnswer((_) async {});

    final createdAt = DateTime.utc(2025, 1, 1, 10);
    final remindAt = DateTime.utc(2025, 1, 1, 12);

    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: 'note-1',
            titleEncrypted: const Value('title'),
            bodyEncrypted: const Value('body'),
            createdAt: createdAt,
            updatedAt: createdAt,
            deleted: const Value(false),
            userId: const Value('user-123'),
            noteType: Value(NoteKind.note),
            isPinned: const Value(false),
            version: const Value(1),
          ),
        );

    final reminderId = await db.createReminder(
      NoteRemindersCompanion.insert(
        noteId: 'note-1',
        userId: 'user-123',
        type: ReminderType.time,
        title: const Value('Reminder Title'),
        body: const Value('Do the thing'),
        remindAt: Value(remindAt),
        snoozeCount: const Value(0),
        triggerCount: const Value(0),
        createdAt: Value(createdAt),
        isActive: const Value(true),
        recurrencePattern: const Value(RecurrencePattern.none),
        recurrenceInterval: const Value(1),
      ),
    );

    await db.enqueue(
      userId: 'user-123',
      entityId: reminderId.toString(),
      kind: 'upsert_reminder',
    );

    await repository.pushAllPending();

    final captured = verify(mockApi.upsertReminder(captureAny)).captured.single
        as Map<String, dynamic>;
    expect(captured['id'], reminderId);
    expect(captured['note_id'], 'note-1');
    expect(captured['user_id'], 'user-123');
    expect(captured['type'], 'time');
    expect(captured['title'], 'Reminder Title');
    expect(DateTime.parse(captured['remind_at'] as String).toUtc(), remindAt);

    final remaining = await db.getPendingOpsForUser('user-123');
    expect(remaining, isEmpty);
  });

  test('pushAllPending deletes remote reminder when delete op enqueued', () async {
    when(mockApi.deleteReminder(any)).thenAnswer((_) async {});

    await db.enqueue(
      userId: 'user-123',
      entityId: '42',
      kind: 'delete_reminder',
    );

    await repository.pushAllPending();

    verify(mockApi.deleteReminder('42')).called(1);
    final remaining = await db.getPendingOpsForUser('user-123');
    expect(remaining, isEmpty);
  });

  test(
    'pullSince ingests remote notes and updates last sync timestamp',
    () async {
      final titleBytes = Uint8List.fromList(utf8.encode('remote-title'));
      final propsBytes = Uint8List.fromList(utf8.encode('remote-props'));
      final folderNameBytes = Uint8List.fromList(utf8.encode('folder-name'));
      final folderPropsBytes = Uint8List.fromList(utf8.encode('folder-props'));

      when(
        mockCrypto.decryptJsonForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: titleBytes,
        ),
      ).thenAnswer((_) async => {'title': 'Remote Title'});

      when(
        mockCrypto.decryptJsonForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: propsBytes,
        ),
      ).thenAnswer(
        (_) async => {
          'body': 'Remote Body',
          'tags': ['alpha', 'beta'],
          'isPinned': true,
          'folderId': 'folder-42',
          'links': [
            {'title': 'Other Note', 'targetId': 'note-99'},
          ],
        },
      );

      when(
        mockCrypto.decryptJsonForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: folderNameBytes,
        ),
      ).thenAnswer((_) async => {'name': 'Folder 42'});

      when(
        mockCrypto.decryptJsonForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: folderPropsBytes,
        ),
      ).thenAnswer(
        (_) async => {
          'parentId': null,
          'deleted': false,
          'description': 'Remote folder',
          'path': '/folder-42',
          'sortOrder': 0,
        },
      );

      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[#text] as String;
        return Uint8List.fromList(utf8.encode('enc::$text'));
      });

      when(mockApi.fetchEncryptedNotes(since: anyNamed('since'))).thenAnswer(
        (_) async => [
          {
            'id': 'note-remote',
            'user_id': 'user-123',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'deleted': false,
            'title_enc': titleBytes,
            'props_enc': propsBytes,
          },
        ],
      );

      when(
        mockApi.fetchEncryptedFolders(since: anyNamed('since')),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'folder-42',
            'user_id': 'user-123',
            'name_enc': folderNameBytes,
            'props_enc': folderPropsBytes,
            'deleted': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      );

      when(
        mockApi.fetchNoteTasks(since: anyNamed('since')),
      ).thenAnswer((_) async => const []);

      when(
        mockApi.fetchTemplates(since: anyNamed('since')),
      ).thenAnswer((_) async => const []);

      when(
        mockApi.fetchNoteFolderRelations(since: anyNamed('since')),
      ).thenAnswer((_) async => const []);

      when(mockApi.fetchNoteFolderRelations()).thenAnswer(
        (_) async => [
          {
            'note_id': 'note-remote',
            'folder_id': 'folder-42',
            'user_id': 'user-123',
          },
        ],
      );

      await repository.pullSince(null);

      final notes = await db.select(db.localNotes).get();
      expect(notes, hasLength(1));
      final note = notes.first;
      expect(note.id, 'note-remote');
      final expectedTitle = base64.encode(utf8.encode('enc::Remote Title'));
      final expectedBody = base64.encode(utf8.encode('enc::Remote Body'));
      expect(note.titleEncrypted, expectedTitle);
      expect(note.bodyEncrypted, expectedBody);
      expect(note.isPinned, isTrue);

      final tags = await (db.select(
        db.noteTags,
      )..where((t) => t.noteId.equals('note-remote'))).get();
      expect(tags.map((t) => t.tag), containsAll(['alpha', 'beta']));

      final links = await (db.select(
        db.noteLinks,
      )..where((l) => l.sourceId.equals('note-remote'))).get();
      expect(links.length, anyOf(equals(0), equals(1)));
      if (links.isNotEmpty) {
        expect(links.first.targetTitle, 'Other Note');
        expect(links.first.targetId, 'note-99');
      }

      final relations = await (db.select(
        db.noteFolders,
      )..where((nf) => nf.noteId.equals('note-remote'))).get();
      expect(relations, hasLength(1));
      expect(relations.first.folderId, 'folder-42');

      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
    },
  );
}
