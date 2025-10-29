import 'package:duru_notes/core/security/database_encryption.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/services/fts_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Factory for creating mock repository dependencies in tests
///
/// Usage:
/// ```dart
/// // In your test file, define mocks with @GenerateNiceMocks
/// @GenerateNiceMocks([
///   MockSpec<SupabaseClient>(),
///   MockSpec<DatabaseEncryption>(),
///   MockSpec<SecureApiWrapper>(),
///   MockSpec<FtsService>(),
/// ])
///
/// // Then use this factory to create the mocks
/// final mocks = TestRepositoryFactory.createMocks<MockSupabaseClient>(
///   clientFactory: () => MockSupabaseClient(),
///   cryptoFactory: () => MockDatabaseEncryption(),
///   apiFactory: () => MockSecureApiWrapper(),
///   ftsFactory: () => MockFtsService(),
/// );
/// ```
class TestRepositoryFactory {
  /// Create a complete set of repository mocks using provided factory functions
  static RepositoryMocks createMocks<T extends SupabaseClient>({
    required T Function() clientFactory,
    required DatabaseEncryption Function() cryptoFactory,
    required SecureApiWrapper Function() apiFactory,
    required FtsService Function() ftsFactory,
  }) {
    final client = clientFactory();

    return RepositoryMocks(
      client: client,
      crypto: cryptoFactory(),
      api: apiFactory(),
      ftsService: ftsFactory(),
    );
  }
}

/// Container for all repository mock dependencies
class RepositoryMocks {
  final SupabaseClient client;
  final DatabaseEncryption crypto;
  final SecureApiWrapper api;
  final FtsService ftsService;

  RepositoryMocks({
    required this.client,
    required this.crypto,
    required this.api,
    required this.ftsService,
  });
}
