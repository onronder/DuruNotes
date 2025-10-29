import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/search_providers.dart' show noteIndexerProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
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

SupabaseClient _clientFor(String? userId) {
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

class _RepoHarness {
  _RepoHarness()
    : db = AppDb.forTesting(NativeDatabase.memory()),
      container = ProviderContainer() {
    indexer = container.read(noteIndexerProvider);
    crypto = SecurityTestSetup.createTestCryptoBox();
  }

  final AppDb db;
  final ProviderContainer container;
  late final NoteIndexer indexer;
  late final CryptoBox crypto;

  NotesCoreRepository buildRepo(String? userId) => NotesCoreRepository(
        db: db,
        crypto: crypto,
        client: _clientFor(userId),
        indexer: indexer,
      );

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL: User ID validation', () {
    late _RepoHarness harness;

    setUp(() {
      harness = _RepoHarness();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('createOrUpdate assigns userId to note', () async {
      final repo = harness.buildRepo('user-a');

      final result = await repo.createOrUpdate(
        title: 'Hello',
        body: 'World',
        tags: const ['security'],
      );

      expect(result, isNotNull);
      final stored =
          await (harness.db.select(harness.db.localNotes)).getSingle();
      expect(stored.userId, equals('user-a'));
    });

    test('createOrUpdate without authenticated user is rejected', () async {
      final repo = harness.buildRepo(null);

      final result = await repo.createOrUpdate(
        title: 'Should Fail',
        body: 'Missing user',
      );

      expect(result, isNull);
      final rows = await harness.db.select(harness.db.localNotes).get();
      expect(rows, isEmpty);
    });

    test('Cross-user update is ignored', () async {
      final repoUserA = harness.buildRepo('user-a');
      final repoUserB = harness.buildRepo('user-b');

      final note = await repoUserA.createOrUpdate(
        title: 'Original',
        body: 'body',
        isPinned: false,
      );
      expect(note, isNotNull);

      await repoUserB.updateLocalNote(
        note!.id,
        title: 'Intrusion',
        isPinned: true,
      );

      final stored =
          await (harness.db.select(harness.db.localNotes)).getSingle();
      expect(stored.version, equals(1));
      expect(stored.isPinned, isFalse);
    });

    test('Cross-user delete is ignored', () async {
      final repoUserA = harness.buildRepo('user-a');
      final repoUserB = harness.buildRepo('user-b');

      final note = await repoUserA.createOrUpdate(
        title: 'Sensitive',
        body: 'Data',
      );
      expect(note, isNotNull);

      await repoUserB.deleteNote(note!.id);

      final stored =
          await (harness.db.select(harness.db.localNotes)).getSingle();
      expect(stored.deleted, isFalse);
    });
  });
}
