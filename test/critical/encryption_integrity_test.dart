import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase/supabase.dart';

import 'package:duru_notes/services/account_key_service.dart';

class _StaticGoTrueClient extends GoTrueClient {
  _StaticGoTrueClient(User? user)
    : _session = user == null
          ? null
          : Session(
              accessToken: 'stub-access',
              refreshToken: 'stub-refresh',
              tokenType: 'bearer',
              expiresIn: 3600,
              user: user,
            ),
      super();

  final Session? _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Session? get currentSession => _session;
}

class _ThrowingSupabaseClient extends SupabaseClient {
  _ThrowingSupabaseClient(this._authClient)
    : super('https://stub.supabase.co', 'anon-key');

  final GoTrueClient _authClient;

  @override
  GoTrueClient get auth => _authClient;

  @override
  SupabaseQueryBuilder from(String table) {
    throw Exception('user_keys table not available in test environment');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL: Encryption integrity', () {
    late ProviderContainer container;
    late FlutterSecureStorage storage;
    late AccountKeyService accountKeyService;

    setUp(() {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        {},
      );
      container = ProviderContainer();
      storage = const FlutterSecureStorage();
      final client = _ThrowingSupabaseClient(
        _StaticGoTrueClient(
          User(
            id: 'user-encryption',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            email: 'user@example.com',
            phone: '',
            createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
            updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
            role: 'authenticated',
            identities: const [],
            factors: const [],
          ),
        ),
      );

      final serviceProvider = Provider<AccountKeyService>((ref) {
        return AccountKeyService(ref, storage: storage, client: client);
      });

      accountKeyService = container.read(serviceProvider);
    });

    tearDown(() async {
      container.dispose();
    });

    test(
      'provisionAmkForUser stores AMK locally even if remote upsert fails',
      () async {
        await accountKeyService.provisionAmkForUser(
          passphrase: 'S3cureP@ss',
          userId: 'user-encryption',
        );

        final amk = await accountKeyService.getLocalAmk(
          userId: 'user-encryption',
        );
        expect(amk, isNotNull);
        expect(amk, hasLength(32));

        final metadata = await storage.read(key: 'amk_meta:user-encryption');
        expect(metadata, isNotNull);
      },
    );

    test('unlockAmkWithPassphrase succeeds when AMK cached locally', () async {
      final cachedAmk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await accountKeyService.setLocalAmk(cachedAmk, userId: 'user-encryption');

      final unlocked = await accountKeyService.unlockAmkWithPassphrase(
        'unused',
      );
      expect(unlocked, isTrue);
    });

    test('clearLocalAmk removes stored key and metadata', () async {
      await accountKeyService.provisionAmkForUser(
        passphrase: 'AnotherPass123',
        userId: 'user-encryption',
      );

      await accountKeyService.clearLocalAmk();

      final amk = await accountKeyService.getLocalAmk(
        userId: 'user-encryption',
      );
      expect(amk, isNull);

      final meta = await storage.read(key: 'amk_meta:user-encryption');
      expect(meta, isNull);
    });
  });
}
