import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

import '../helpers/security_test_setup.dart';

class _FakeNotesRepositoryHarness {
  _FakeNotesRepositoryHarness()
    : db = AppDb.forTesting(NativeDatabase.memory()),
      userId = 'test-user-1',
      client = _FakeSupabaseClient('test-user-1'),
      indexer = _StubNoteIndexer() {
    crypto = SecurityTestSetup.createTestCryptoBox();
    repository = NotesCoreRepository(
      db: db,
      crypto: crypto,
      client: client,
      indexer: indexer,
    );
  }

  final AppDb db;
  final String userId;
  final _FakeSupabaseClient client;
  final NoteIndexer indexer;
  late final CryptoBox crypto;
  late final NotesCoreRepository repository;

  Future<String> encrypt(String noteId, String text) async {
    final data = await crypto.encryptStringForNote(
      userId: userId,
      noteId: noteId,
      text: text,
    );
    return base64.encode(data);
  }

  void dispose() {
    db.close();
  }
}

class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(String userId)
    : _session = Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          email: '$userId@example.com',
          phone: '',
          createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          role: 'authenticated',
          identities: const [],
          factors: const [],
        ),
      ),
      super('https://stub.supabase.co', 'anon-key');

  final Session _session;

  @override
  GoTrueClient get auth => _FakeAuthClient(_session);

  @override
  SupabaseQueryBuilder from(String table) {
    throw UnimplementedError('Remote access not required for repository tests');
  }
}

class _FakeAuthClient extends GoTrueClient {
  _FakeAuthClient(this._session);

  final Session _session;

  @override
  User? get currentUser => _session.user;

  @override
  Session? get currentSession => _session;
}

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
  Set<String> findNotesByTag(String tag) => {};

  @override
  Set<String> findNotesLinkingTo(String noteId) => {};

  @override
  Map<String, int> getIndexStats() => const {};

  @override
  Set<String> searchNotes(String query) => {};
}

domain.Note _buildDomainNote({
  required String id,
  String title = 'Title',
  String body = 'Body',
  bool isPinned = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  List<String> tags = const [],
}) {
  final created = createdAt ?? DateTime.utc(2025, 1, 1);
  final updated = updatedAt ?? created;
  return domain.Note(
    id: id,
    title: title,
    body: body,
    createdAt: created,
    updatedAt: updated,
    deleted: false,
    encryptedMetadata: null,
    isPinned: isPinned,
    noteType: NoteKind.note,
    folderId: null,
    version: 1,
    userId: 'test-user-1',
    attachmentMeta: null,
    metadata: null,
    tags: tags,
    links: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotesCoreRepository', () {
    late _FakeNotesRepositoryHarness harness;

    setUp(() async {
      await SecurityTestSetup.setupMockEncryption();
      harness = _FakeNotesRepositoryHarness();
    });

    tearDown(() {
      harness.dispose();
      SecurityTestSetup.teardownEncryption();
    });

    test(
      'getNoteById returns hydrated domain note when record exists',
      () async {
        final note = _buildDomainNote(id: 'note-1', title: 'Encrypted Note');

        await harness.db
            .into(harness.db.localNotes)
            .insert(
              LocalNotesCompanion.insert(
                id: note.id,
                titleEncrypted: Value(
                  await harness.encrypt(note.id, note.title),
                ),
                bodyEncrypted: Value(await harness.encrypt(note.id, note.body)),
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                userId: Value(harness.userId),
                noteType: Value(NoteKind.note),
                encryptionVersion: const Value(1),
              ),
            );

        final result = await harness.repository.getNoteById(note.id);

        expect(result, isNotNull);
        expect(result!.id, note.id);
        expect(result.title, note.title);
        expect(result.body, note.body);
        expect(result.isPinned, isFalse);
      },
    );

    test('getNoteById returns null for missing record', () async {
      final result = await harness.repository.getNoteById('missing');
      expect(result, isNull);
    });

    test(
      'listAfter orders pinned notes before others and respects limit',
      () async {
        final dates = List.generate(6, (i) => DateTime.utc(2025, 1, 1, 12, i));

        Future<void> insert(domain.Note note) async {
          final titleEncrypted = await harness.encrypt(note.id, note.title);
          final bodyEncrypted = await harness.encrypt(note.id, note.body);
          await harness.db
              .into(harness.db.localNotes)
              .insert(
                LocalNotesCompanion.insert(
                  id: note.id,
                  titleEncrypted: Value(titleEncrypted),
                  bodyEncrypted: Value(bodyEncrypted),
                  createdAt: note.createdAt,
                  updatedAt: note.updatedAt,
                  userId: Value(harness.userId),
                  noteType: Value(NoteKind.note),
                  encryptionVersion: const Value(1),
                  isPinned: Value(note.isPinned),
                ),
              );
        }

        await insert(
          _buildDomainNote(id: 'note-1', title: 'One', updatedAt: dates[0]),
        );
        await insert(
          _buildDomainNote(
            id: 'note-2',
            title: 'Two',
            updatedAt: dates[1],
            isPinned: true,
          ),
        );
        await insert(
          _buildDomainNote(id: 'note-3', title: 'Three', updatedAt: dates[2]),
        );

        final results = await harness.repository.listAfter(null, limit: 2);

        expect(results, hasLength(2));
        expect(
          results.first.id,
          'note-2',
          reason: 'Pinned note should come first',
        );
        expect(results.last.id, anyOf('note-1', 'note-3'));
      },
    );

    test('listAfter respects cursor and excludes deleted notes', () async {
      final base = DateTime.utc(2025, 1, 1, 10);
      Future<void> insert(
        String id, {
        bool deleted = false,
        int minutes = 0,
      }) async {
        final noteId = id;
        final titleEncrypted = await harness.encrypt(noteId, 'title-$id');
        final bodyEncrypted = await harness.encrypt(noteId, 'body-$id');
        await harness.db
            .into(harness.db.localNotes)
            .insert(
              LocalNotesCompanion.insert(
                id: noteId,
                titleEncrypted: Value(titleEncrypted),
                bodyEncrypted: Value(bodyEncrypted),
                createdAt: base.add(Duration(minutes: minutes)),
                updatedAt: base.add(Duration(minutes: minutes)),
                deleted: Value(deleted),
                userId: Value(harness.userId),
                noteType: Value(NoteKind.note),
                encryptionVersion: const Value(1),
              ),
            );
      }

      await insert('note-old', minutes: 0);
      await insert('note-new', minutes: 5);
      await insert('note-deleted', deleted: true, minutes: 6);

      final cursor = base.add(const Duration(minutes: 6));
      final results = await harness.repository.listAfter(cursor, limit: 5);

      expect(results.map((n) => n.id), ['note-new', 'note-old']);
      expect(results.every((n) => !n.deleted), isTrue);
    });

    test('createOrUpdate inserts new note when id missing', () async {
      final created = await harness.repository.createOrUpdate(
        title: 'New Title',
        body: 'New Body',
      );

      final stored = await harness.db.select(harness.db.localNotes).getSingle();
      expect(stored.titleEncrypted.isNotEmpty, isTrue);
      expect(stored.bodyEncrypted.isNotEmpty, isTrue);
      expect(stored.userId, harness.userId);
      expect(created?.title, 'New Title');
    });

    test(
      'createOrUpdate updates existing record and retains encryption version',
      () async {
        final existingId = 'existing';

        await harness.db
            .into(harness.db.localNotes)
            .insert(
              LocalNotesCompanion.insert(
                id: existingId,
                titleEncrypted: Value(
                  await harness.encrypt(existingId, 'old title'),
                ),
                bodyEncrypted: Value(
                  await harness.encrypt(existingId, 'old body'),
                ),
                createdAt: DateTime.utc(2025, 1, 1),
                updatedAt: DateTime.utc(2025, 1, 1),
                userId: Value(harness.userId),
                noteType: Value(NoteKind.note),
                encryptionVersion: const Value(99),
              ),
            );

        final updated = await harness.repository.createOrUpdate(
          id: existingId,
          title: 'Updated Title',
          body: 'Updated Body',
        );

        final stored = await harness.db
            .select(harness.db.localNotes)
            .getSingle();
        expect(stored.id, existingId);
        expect(
          stored.encryptionVersion,
          1,
          reason: 'Encryption version should reset to current version',
        );
        expect(updated?.title, 'Updated Title');
      },
    );
  });
}
