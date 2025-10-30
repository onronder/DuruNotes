import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

import '../helpers/security_test_setup.dart';

class _StaticAuthClient extends GoTrueClient {
  _StaticAuthClient(User user)
    : _session = Session(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: user,
      ),
      super();

  final Session _session;

  @override
  User? get currentUser => _session.user;

  @override
  Session? get currentSession => _session;
}

class _StubSupabaseClient extends SupabaseClient {
  _StubSupabaseClient(GoTrueClient authClient)
    : _authClient = authClient,
      super('https://stub.supabase.co', 'anon-key');

  final GoTrueClient _authClient;

  @override
  GoTrueClient get auth => _authClient;

  @override
  SupabaseQueryBuilder from(String table) {
    throw Exception('Remote access not available in workflow tests');
  }
}

class _WorkflowHarness {
  _WorkflowHarness()
    : db = AppDb.forTesting(NativeDatabase.memory()),
      container = ProviderContainer() {
    indexer = container.read(noteIndexerProvider);
    crypto = SecurityTestSetup.createTestCryptoBox();
  }

  final String defaultUserId = 'user-workflow';
  final AppDb db;
  final ProviderContainer container;
  late final NoteIndexer indexer;
  late final CryptoBox crypto;

  NotesCoreRepository buildRepository([String? userId]) {
    final uid = userId ?? defaultUserId;
    final authClient = _StaticAuthClient(
      User(
        id: uid,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: '$uid@example.com',
        phone: '',
        createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
        updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
        role: 'authenticated',
        identities: const [],
        factors: const [],
      ),
    );
    final client = _StubSupabaseClient(authClient);
    return NotesCoreRepository(
      db: db,
      crypto: crypto,
      client: client,
      indexer: indexer,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Integration: Notes full workflow', () {
    late _WorkflowHarness harness;

    setUp(() {
      harness = _WorkflowHarness();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'User can create, update, pin, move, and delete notes end-to-end',
      () async {
        final repo = harness.buildRepository();

        final now = DateTime.utc(2025, 1, 1);
        await harness.db
            .into(harness.db.localFolders)
            .insert(
              LocalFoldersCompanion.insert(
                id: 'folder-default',
                userId: harness.defaultUserId,
                name: 'Inbox',
                path: '/Inbox',
                createdAt: now,
                updatedAt: now,
              ),
            );

        final note = await repo.createOrUpdate(
          id: 'note-workflow',
          title: 'Initial Title',
          body: 'Encrypted body payload',
          folderId: 'folder-default',
          tags: const ['workflow', 'integration'],
          links: const [
            {'title': 'Related', 'id': 'note-2'},
          ],
          metadataJson: const {'category': 'testing'},
        );

        expect(note, isNotNull);

        final storedNote = await (harness.db.select(
          harness.db.localNotes,
        )).getSingle();
        expect(storedNote.userId, equals(harness.defaultUserId));
        expect(storedNote.isPinned, isFalse);
        expect(storedNote.deleted, isFalse);

        final folderRelation = await (harness.db.select(
          harness.db.noteFolders,
        )).getSingle();
        expect(folderRelation.folderId, equals('folder-default'));

        final tags = await (harness.db.select(harness.db.noteTags)).get();
        expect(
          tags.map((t) => t.tag).toSet(),
          equals({'workflow', 'integration'}),
        );

        final links = await (harness.db.select(harness.db.noteLinks)).get();
        expect(links.single.targetId, equals('note-2'));

        await repo.toggleNotePin('note-workflow');
        final pinned = await (harness.db.select(
          harness.db.localNotes,
        )).getSingle();
        expect(pinned.isPinned, isTrue);

        final updated = await repo.createOrUpdate(
          id: 'note-workflow',
          title: 'Updated Title',
          body: 'Updated body',
          tags: const ['workflow', 'updated'],
        );

        expect(updated, isNotNull);
        final afterUpdate = await (harness.db.select(
          harness.db.localNotes,
        )).getSingle();
        expect(afterUpdate.version, equals(2));

        await harness.db
            .into(harness.db.localFolders)
            .insert(
              LocalFoldersCompanion.insert(
                id: 'folder-archive',
                userId: harness.defaultUserId,
                name: 'Archive',
                path: '/Archive',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await repo.updateLocalNote(
          'note-workflow',
          folderId: 'folder-archive',
          updateFolder: true,
        );

        final folderAfterMove = await (harness.db.select(
          harness.db.noteFolders,
        )).getSingle();
        expect(folderAfterMove.folderId, equals('folder-archive'));

        await repo.deleteNote('note-workflow');
        final deletedNote = await (harness.db.select(
          harness.db.localNotes,
        )).getSingle();
        expect(deletedNote.deleted, isTrue);

        final pending = await (harness.db.select(harness.db.pendingOps)).get();
        expect(pending.length, greaterThanOrEqualTo(1));

        final otherRepo = harness.buildRepository('other-user');
        expect(await otherRepo.localNotes(), isEmpty);
      },
    );
  });
}
