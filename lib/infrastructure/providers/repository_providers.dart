import 'package:duru_notes/core/providers/auth_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_inbox_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/repositories/i_user_preferences_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/inbox_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/quick_capture_repository.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/user_preferences_repository_impl.dart';
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:duru_notes/services/search/fts_indexing_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for FTS indexing service
final ftsIndexingServiceProvider = Provider<FTSIndexingService>((ref) {
  final logger = ref.watch(loggerProvider);
  return FTSIndexingService(logger: logger);
});

/// Provider for the notes core repository.
///
/// Throws until `SecurityInitialization.initialize()` completes, which prevents
/// repositories from constructing with incomplete security context. Callers
/// that listen to this provider should retry after initialization succeeds
/// (the Auth wrapper invalidates it once security services are ready).
final notesCoreRepositoryProvider = Provider<NotesCoreRepository>((ref) {
  if (!SecurityInitialization.isInitialized) {
    throw StateError(
      '[notesCoreRepositoryProvider] Security services must be initialized before creating repositories. '
      'This provider should only be accessed after the FutureBuilder in app.dart completes SecurityInitialization.initialize().',
    );
  }

  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = Supabase.instance.client;
  final indexer = ref.watch(noteIndexerProvider);
  final secureApi = SecureApiWrapper(client);

  return NotesCoreRepository(
    db: db,
    crypto: crypto,
    client: client,
    indexer: indexer,
    secureApi: secureApi,
  );
});

/// Provider for the template repository
final templateCoreRepositoryProvider = Provider<ITemplateRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final notesRepository = ref.watch(notesCoreRepositoryProvider);

  return TemplateCoreRepository(
    db: db,
    client: client,
    notesRepository: notesRepository,
  );
});

/// Provider for note link parser service
///
/// Stateless parser that receives repository/context when invoked to avoid
/// circular dependencies with `notesCoreRepositoryProvider`.
final noteLinkParserProvider = Provider<NoteLinkParser>((ref) {
  final logger = ref.watch(loggerProvider);
  final indexer = ref.watch(noteIndexerProvider);

  return NoteLinkParser(logger: logger, noteIndexer: indexer);
});

/// Provider for the tag repository
final tagRepositoryProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);

  return TagRepository(db: db, client: client, crypto: crypto);
});

/// Provider for the search repository
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);
  final folderRepository = ref.watch(folderCoreRepositoryProvider);

  return SearchRepository(
    db: db,
    client: client,
    crypto: crypto,
    folderRepository: folderRepository,
  );
});

/// Provider for the folder repository (interface)
final folderRepositoryInterfaceProvider = Provider<IFolderRepository>((ref) {
  return ref.watch(folderCoreRepositoryProvider);
});

/// Provider for the template repository (interface)
final templateRepositoryInterfaceProvider = Provider<ITemplateRepository>((
  ref,
) {
  return ref.watch(templateCoreRepositoryProvider);
});

/// Provider for the inbox repository
final inboxRepositoryProvider = Provider<IInboxRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InboxRepository(client: client);
});

/// Provider for the user preferences repository
final userPreferencesRepositoryProvider = Provider<IUserPreferencesRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return UserPreferencesRepositoryImpl(client: client);
});

/// Provider for the quick capture repository
final quickCaptureRepositoryProvider = Provider((ref) {
  if (!SecurityInitialization.isInitialized) {
    throw StateError(
      '[quickCaptureRepositoryProvider] Security services must be initialized before creating repositories.',
    );
  }

  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);

  return QuickCaptureRepository(db: db, crypto: crypto);
});
