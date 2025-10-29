import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider, folderUpdatesProvider;
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show folderListProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===== PHASE 5: DOMAIN ENTITY PROVIDERS (migrated from providers.dart) =====

/// Domain folders provider - switches between legacy and domain
///
/// This provider implements the dual provider pattern for gradual migration:
/// - When 'folders' feature flag is enabled: uses domain repository
/// - Otherwise: uses legacy folder list provider
final domainFoldersProvider = FutureProvider.autoDispose<List<domain.Folder>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Use domain repository
    final repository = ref.watch(folderCoreRepositoryProvider);
    return repository.listFolders();
  } else {
    // folderListProvider already returns domain.Folder
    final domainFolders = ref.watch(folderListProvider);
    return domainFolders;
  }
});

/// Domain folders stream provider - real-time updates with dual support
///
/// NOTE: Riverpod 3.0+ - Using .future and async* instead of deprecated .stream
///
/// This provider implements the dual provider pattern for gradual migration:
/// - When 'folders' feature flag is enabled: uses domain repository
/// - Otherwise: uses legacy folder list provider with updates stream
final domainFoldersStreamProvider = StreamProvider.autoDispose<List<domain.Folder>>((ref) async* {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Riverpod 3.0: Fetch initial data with .future
    await ref.watch(folderUpdatesProvider.future);
    final repository = ref.read(folderCoreRepositoryProvider);
    yield await repository.listFolders();

    // Listen for subsequent updates
    ref.listen(folderUpdatesProvider, (previous, next) async {
      // Provider will auto-rebuild when folderUpdatesProvider changes
    });
  } else {
    // folderListProvider already returns domain.Folder
    await ref.watch(folderUpdatesProvider.future);
    final domainFolders = ref.read(folderListProvider);
    yield domainFolders;

    // Listen for subsequent updates
    ref.listen(folderUpdatesProvider, (previous, next) {
      // Provider will auto-rebuild when folderUpdatesProvider changes
    });
  }
});
