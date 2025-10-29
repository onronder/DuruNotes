import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/search_providers.dart' show noteIndexerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/security_test_setup.dart';

class _StubGoTrueClient extends GoTrueClient {
  _StubGoTrueClient(User? user)
    : _session = user == null
            ? null
            : Session(
                accessToken: 'stub-access-token',
                refreshToken: 'stub-refresh-token',
                tokenType: 'bearer',
                expiresIn: 3600,
                user: user,
              ),
      super(
        url: 'https://stub.supabase.co/auth/v1',
        headers: const {},
        autoRefreshToken: false,
      );

  final Session? _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Session? get currentSession => _session;
}

class _StubSupabaseClient extends SupabaseClient {
  _StubSupabaseClient(GoTrueClient auth)
    : _auth = auth,
      super(
        'https://stub.supabase.co',
        'stub-public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        realtimeClientOptions:
            const RealtimeClientOptions(logLevel: RealtimeLogLevel.error),
      );

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL: Database isolation integration', () {
    late AppDb db;
    late ProviderContainer container;
    late NoteIndexer indexer;

    setUp(() async {
      db = AppDb.forTesting(NativeDatabase.memory());
      container = ProviderContainer();
      indexer = container.read(noteIndexerProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('NotesCoreRepository returns data scoped to authenticated user', () async {
      await _seedSampleData(db);

      final crypto = SecurityTestSetup.createTestCryptoBox();

      final repoUserA = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _stubClientFor(userId: 'user-a'),
        indexer: indexer,
      );

      final repoUserB = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _stubClientFor(userId: 'user-b'),
        indexer: indexer,
      );

      final userALocal = await repoUserA.localNotes();
      expect(
        userALocal.map((n) => n.id).toList(),
        equals(['note-a-1', 'note-a-2']),
        reason: 'User A should see only their notes',
      );

      final userBLocal = await repoUserB.localNotes();
      expect(
        userBLocal.map((n) => n.id).toList(),
        equals(['note-b-1']),
        reason: 'User B should see only their notes',
      );

      final userAIds =
          await repoUserA.getNoteIdsInFolder('folder-a-projects');
      expect(userAIds, equals(['note-a-1']));

      final userBIds =
          await repoUserB.getNoteIdsInFolder('folder-b-research');
      expect(userBIds, equals(['note-b-1']));

      expect(
        await repoUserA.getNotesCountInFolder('folder-b-research'),
        equals(0),
        reason: 'User A must not access User B folders',
      );
    });

    test('NotesCoreRepository returns empty results when unauthenticated', () async {
      await _seedSampleData(db);
      final crypto = SecurityTestSetup.createTestCryptoBox();

      final repo = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _stubClientFor(userId: null),
        indexer: indexer,
      );

      expect(await repo.localNotes(), isEmpty);
      expect(await repo.localNotesForSync(), isEmpty);
    });
  });
}

SupabaseClient _stubClientFor({required String? userId}) {
  final user = userId == null
      ? null
      : User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          email: '$userId@example.com',
          phone: '',
          role: 'authenticated',
          identities: const [],
          factors: const [],
        );
  final auth = _StubGoTrueClient(user);
  return _StubSupabaseClient(auth);
}

Future<void> _seedSampleData(AppDb db) async {
  final now = DateTime.utc(2025, 1, 1);

  // User A notes (two notes, one in folder)
  await db.batch((batch) {
    batch.insertAll(db.localNotes, [
      LocalNotesCompanion.insert(
        id: 'note-a-1',
        titleEncrypted: const Value('enc::A1'),
        bodyEncrypted: const Value('enc::A1 body'),
        createdAt: now,
        updatedAt: now,
        noteType: Value(NoteKind.note),
        encryptionVersion: const Value(1),
        userId: const Value('user-a'),
      ),
      LocalNotesCompanion.insert(
        id: 'note-a-2',
        titleEncrypted: const Value('enc::A2'),
        bodyEncrypted: const Value('enc::A2 body'),
        createdAt: now,
        updatedAt: now,
        noteType: Value(NoteKind.note),
        encryptionVersion: const Value(1),
        userId: const Value('user-a'),
      ),
    ]);

    batch.insertAll(db.localFolders, [
      LocalFoldersCompanion.insert(
        id: 'folder-a-projects',
        userId: 'user-a',
        name: 'Projects',
        path: '/Projects',
        createdAt: now,
        updatedAt: now,
      ),
      LocalFoldersCompanion.insert(
        id: 'folder-b-research',
        userId: 'user-b',
        name: 'Research',
        path: '/Research',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    batch.insertAll(db.noteFolders, [
      NoteFoldersCompanion.insert(
        noteId: 'note-a-1',
        folderId: 'folder-a-projects',
        addedAt: now,
      ),
      NoteFoldersCompanion.insert(
        noteId: 'note-b-1',
        folderId: 'folder-b-research',
        addedAt: now,
      ),
    ]);
  });

  await db.into(db.noteTasks).insert(
        NoteTasksCompanion.insert(
          id: 'task-a-1',
          noteId: 'note-a-1',
          userId: 'user-a',
          contentEncrypted: 'enc::task',
          contentHash: 'hash-a',
          status: const Value(TaskStatus.open),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db.into(db.noteTags).insert(
        NoteTagsCompanion.insert(
          noteId: 'note-a-1',
          tag: 'priority',
        ),
      );

  await db.into(db.noteReminders).insert(
        NoteRemindersCompanion.insert(
          noteId: 'note-a-2',
          userId: 'user-a',
          type: ReminderType.time,
        ),
      );

  // User B note
  await db.into(db.localNotes).insert(
        LocalNotesCompanion.insert(
          id: 'note-b-1',
          titleEncrypted: const Value('enc::B1'),
          bodyEncrypted: const Value('enc::B1 body'),
          createdAt: now,
          updatedAt: now,
          noteType: Value(NoteKind.note),
          encryptionVersion: const Value(1),
          userId: const Value('user-b'),
        ),
      );
}
