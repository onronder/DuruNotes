import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/search/search_service.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tag repository provider
final tagRepositoryInterfaceProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);
  return TagRepository(db: db);
});

/// Search repository provider
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);
  return SearchRepository(db: db);
});

/// Search service provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final db = ref.watch(appDbProvider);
  final repo = ref.watch(notesRepositoryProvider);
  return SearchService(db: db, repo: repo as NotesRepository);
});

/// Sort preferences service
final sortPreferencesServiceProvider = Provider<SortPreferencesService>((ref) {
  return SortPreferencesService();
});

/// Stream of saved searches from the database
final savedSearchesStreamProvider = StreamProvider<List<SavedSearch>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return (repo as NotesRepository).watchSavedSearches();
});

/// Current filter state for advanced filters
final filterStateProvider = StateProvider<FilterState?>((ref) => null);

/// Current sort spec for the selected folder
final currentSortSpecProvider =
    StateNotifierProvider<CurrentSortSpecNotifier, NoteSortSpec>((ref) {
  final currentFolder = ref.watch(currentFolderProvider);
  final service = ref.watch(sortPreferencesServiceProvider);

  // Create a new notifier when folder changes
  final notifier = CurrentSortSpecNotifier(service, currentFolder?.id as String?);

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