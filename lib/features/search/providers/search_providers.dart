import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show currentFolderProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:duru_notes/search/search_service.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tag repository provider
final tagRepositoryInterfaceProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);
  return TagRepository(db: db, client: client, crypto: crypto);
});

/// Search repository provider
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);
  final folderRepo = ref.watch(folderCoreRepositoryProvider);
  return SearchRepository(
    db: db,
    client: client,
    crypto: crypto,
    folderRepository: folderRepo,
  );
});

/// Search service provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final db = ref.watch(appDbProvider);
  // Use domain repository - always available
  final repo = ref.watch(notesCoreRepositoryProvider);
  final crypto = ref.watch(cryptoBoxProvider);

  // SearchService requires concrete NotesCoreRepository (aliased as NotesRepository)
  return SearchService(db: db, repo: repo, crypto: crypto);
});

/// Sort preferences service
final sortPreferencesServiceProvider = Provider<SortPreferencesService>((ref) {
  return SortPreferencesService();
});

/// Stream of saved searches from the database
final savedSearchesStreamProvider =
    StreamProvider.autoDispose<List<domain.SavedSearch>>((ref) {
      final repo = ref.watch(searchRepositoryProvider);
      return repo.watchSavedSearches();
    });

/// Current filter state for advanced filters
final filterStateProvider = StateProvider.autoDispose<FilterState?>(
  (ref) => null,
);

/// Current sort spec for the selected folder
final currentSortSpecProvider =
    StateNotifierProvider<CurrentSortSpecNotifier, NoteSortSpec>((ref) {
      final currentFolder = ref.watch(currentFolderProvider);
      final service = ref.watch(sortPreferencesServiceProvider);

      // Create a new notifier when folder changes
      final notifier = CurrentSortSpecNotifier(service, currentFolder?.id);

      // Clean up when folder changes
      ref.onDispose(() {
        // Nothing to dispose, but could add cleanup if needed
      });

      return notifier;
    });

/// Notifier for managing the current sort spec
class CurrentSortSpecNotifier extends StateNotifier<NoteSortSpec> {
  CurrentSortSpecNotifier(this._service, this._folderId)
    : super(const NoteSortSpec()) {
    _loadSortSpec();
  }

  final SortPreferencesService _service;
  final String? _folderId;

  Future<void> _loadSortSpec() async {
    final spec = await _service.getSortForFolder(_folderId);
    if (mounted) {
      state = spec;
    }
  }

  Future<void> updateSortSpec(NoteSortSpec spec) async {
    state = spec;
    await _service.setSortForFolder(_folderId, spec);
  }
}
