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

SupabaseClient _clientForUser(String? userId) {
  final user = userId == null
      ? null
      : User(
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
        );
  final auth = _StubGoTrueClient(user);
  return _StubSupabaseClient(auth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL: RLS enforcement guards', () {
    late AppDb db;
    late ProviderContainer container;
    late NoteIndexer indexer;

    setUp(() async {
      db = AppDb.forTesting(NativeDatabase.memory());
      container = ProviderContainer();
      indexer = container.read(noteIndexerProvider);
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Unauthenticated repository cannot mutate or observe user data', () async {
      await _seedUserNotes(db);
      final crypto = SecurityTestSetup.createTestCryptoBox();

      final unauthRepo = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientForUser(null),
        indexer: indexer,
      );

      // Attempt to toggle pin without authentication should be ignored
      await unauthRepo.toggleNotePin('note-a');
      final noteA = await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-a'))).getSingle();
      expect(noteA.isPinned, isFalse, reason: 'toggleNotePin should be ignored without user');

      // Attempt to set pin should be ignored
      await unauthRepo.setNotePin('note-a', true);
      final noteAAfterSet =
          await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-a'))).getSingle();
      expect(noteAAfterSet.isPinned, isFalse, reason: 'setNotePin requires authenticated user');

      // Attempt to add pending operation (via push) should be skipped
      expect(await db.select(db.pendingOps).get(), isEmpty);
    });

    test('Authenticated repository only mutates data for its own user', () async {
      await _seedUserNotes(db);
      final crypto = SecurityTestSetup.createTestCryptoBox();

      final repoUserA = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientForUser('user-a'),
        indexer: indexer,
      );

      final repoUserB = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientForUser('user-b'),
        indexer: indexer,
      );

      await repoUserA.toggleNotePin('note-a');
      final updatedNoteA =
          await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-a'))).getSingle();
      expect(updatedNoteA.isPinned, isTrue, reason: 'User A should pin their note');

      await repoUserA.toggleNotePin('note-b');
      final noteBAfterA =
          await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-b'))).getSingle();
      expect(noteBAfterA.isPinned, isFalse, reason: 'User A must NOT mutate User B data');

      await repoUserB.setNotePin('note-b', true);
      final noteBAfterB =
          await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-b'))).getSingle();
      expect(noteBAfterB.isPinned, isTrue, reason: 'User B pins own note');
    });

    test('Authenticated repository cannot access other users tasks or reminders', () async {
      await _seedUserNotes(db);
      final crypto = SecurityTestSetup.createTestCryptoBox();

      final repoUserA = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientForUser('user-a'),
        indexer: indexer,
      );

      final repoUserB = NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientForUser('user-b'),
        indexer: indexer,
      );

      expect(await repoUserA.list(), hasLength(1));
      expect(await repoUserB.list(), hasLength(1));

      final tasksForA = await (db.select(db.noteTasks)
            ..where((tbl) => tbl.userId.equals('user-a')))
          .get();
      expect(tasksForA, hasLength(1));

      final tasksForB = await (db.select(db.noteTasks)
            ..where((tbl) => tbl.userId.equals('user-b')))
          .get();
      expect(tasksForB, hasLength(1));

      await repoUserA.deleteNote('note-b');
      final noteB =
          await (db.select(db.localNotes)..where((tbl) => tbl.id.equals('note-b'))).getSingle();
      expect(noteB.deleted, isFalse, reason: 'User A cannot delete User B note');
    });
  });
}

Future<void> _seedUserNotes(AppDb db) async {
  final now = DateTime.utc(2025, 1, 1);

  await db.batch((batch) {
    batch.insertAll(db.localNotes, [
      LocalNotesCompanion.insert(
        id: 'note-a',
        titleEncrypted: const Value('enc::A'),
        bodyEncrypted: const Value('enc::A body'),
        createdAt: now,
        updatedAt: now,
        noteType: Value(NoteKind.note),
        encryptionVersion: const Value(1),
        userId: const Value('user-a'),
      ),
      LocalNotesCompanion.insert(
        id: 'note-b',
        titleEncrypted: const Value('enc::B'),
        bodyEncrypted: const Value('enc::B body'),
        createdAt: now,
        updatedAt: now,
        noteType: Value(NoteKind.note),
        encryptionVersion: const Value(1),
        userId: const Value('user-b'),
      ),
    ]);

    batch.insertAll(db.noteTasks, [
      NoteTasksCompanion.insert(
        id: 'task-a',
        noteId: 'note-a',
        userId: 'user-a',
        contentEncrypted: 'enc::task a',
        contentHash: 'hash-a',
        createdAt: Value(now),
        updatedAt: Value(now),
        status: const Value(TaskStatus.open),
      ),
      NoteTasksCompanion.insert(
        id: 'task-b',
        noteId: 'note-b',
        userId: 'user-b',
        contentEncrypted: 'enc::task b',
        contentHash: 'hash-b',
        createdAt: Value(now),
        updatedAt: Value(now),
        status: const Value(TaskStatus.open),
      ),
    ]);
  });
}
