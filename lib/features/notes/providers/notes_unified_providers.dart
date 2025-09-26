// Unified Notes Providers - No more dual architecture!
// These providers replace all conditional providers with a single, consistent interface

import 'package:duru_notes/providers.dart'; // Import main providers for appDbProvider and supabaseClientProvider
import 'package:duru_notes/infrastructure/repositories/unified_notes_repository.dart';
import 'package:duru_notes/infrastructure/repositories/unified_tasks_repository.dart';
import 'package:duru_notes/infrastructure/repositories/unified_folders_repository.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unified notes repository provider
final unifiedNotesRepositoryProvider = Provider<UnifiedNotesRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = ref.watch(supabaseClientProvider);
  return UnifiedNotesRepository(db: db, client: client);
});

/// Unified tasks repository provider
final unifiedTasksRepositoryProvider = Provider<UnifiedTasksRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = ref.watch(supabaseClientProvider);
  return UnifiedTasksRepository(db: db, client: client);
});

/// Unified folders repository provider
final unifiedFoldersRepositoryProvider = Provider<UnifiedFoldersRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = ref.watch(supabaseClientProvider);
  return UnifiedFoldersRepository(db: db, client: client);
});

/// Main notes page state using UnifiedNote type
final notesPageProvider = StateNotifierProvider<NotesPageNotifier, AsyncValue<UnifiedNotesPage>>((ref) {
  final repository = ref.watch(unifiedNotesRepositoryProvider);
  return NotesPageNotifier(repository, ref);
});

class NotesPageNotifier extends StateNotifier<AsyncValue<UnifiedNotesPage>> {
  final UnifiedNotesRepository _repository;
  final Ref _ref;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  String? _currentFolderId;
  String? _currentSearchQuery;

  NotesPageNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    _currentPage = 0;
    _isLoadingMore = false;

    try {
      final page = await _repository.getNotesPage(
        page: 0,
        pageSize: 20,
        folderId: _currentFolderId,
        searchQuery: _currentSearchQuery,
      );
      state = AsyncValue.data(page);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    final currentState = state;
    if (currentState is! AsyncData<UnifiedNotesPage>) return;
    if (!currentState.value.hasMore) return;

    _isLoadingMore = true;
    
    try {
      final nextPage = await _repository.getNotesPage(
        page: _currentPage + 1,
        pageSize: 20,
        folderId: _currentFolderId,
        searchQuery: _currentSearchQuery,
      );
      _currentPage++;

      state = AsyncValue.data(UnifiedNotesPage(
        notes: [...currentState.value.notes, ...nextPage.notes],
        hasMore: nextPage.hasMore,
        currentPage: _currentPage,
        totalCount: nextPage.totalCount,
      ));
    } catch (e, stack) {
      // Keep existing data but show error
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  void setFolder(String? folderId) {
    _currentFolderId = folderId;
    loadInitial();
  }

  void setSearchQuery(String? query) {
    _currentSearchQuery = query;
    loadInitial();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await refresh();
  }

  Future<void> createNote(UnifiedNote note) async {
    await _repository.createUnified(note);
    await refresh();
  }

  Future<void> updateNote(UnifiedNote note) async {
    await _repository.updateUnified(note);
    await refresh();
  }
}

/// Current notes provider - no more conditional logic!
final currentNotesProvider = Provider<List<UnifiedNote>>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.notes,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Filtered notes provider - single implementation
final filteredNotesProvider = FutureProvider<List<UnifiedNote>>((ref) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);
  final repository = ref.watch(unifiedNotesRepositoryProvider);

  List<UnifiedNote> notes;

  // Get notes based on current folder
  if (currentFolder != null) {
    notes = await repository.getNotesInFolder(currentFolder.id as String);
  } else {
    notes = ref.watch(currentNotesProvider);
  }

  // Apply advanced filters if active
  if (filterState != null && filterState.hasActiveFilters) {
    // Filter by pinned status
    if (filterState.pinnedOnly) {
      notes = notes.where((note) => note.isPinned).toList();
    }

    // Filter by tags if needed
    if (filterState.includeTags.isNotEmpty || filterState.excludeTags.isNotEmpty) {
      // Filter by included tags
      if (filterState.includeTags.isNotEmpty) {
        notes = notes.where((note) {
          final noteTags = note.tags;
          return filterState.includeTags.every(noteTags.contains);
        }).toList();
      }

      // Filter by excluded tags
      if (filterState.excludeTags.isNotEmpty) {
        notes = notes.where((note) {
          final noteTags = note.tags;
          return !filterState.excludeTags.any(noteTags.contains);
        }).toList();
      }
    }
  }

  return notes;
});

/// Has more notes provider - simple and direct
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.hasMore,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Notes loading provider - simple and direct
final notesLoadingProvider = Provider<bool>((ref) {
  final notifier = ref.watch(notesPageProvider.notifier);
  return notifier.isLoadingMore;
});

/// Total notes count provider
final totalNotesCountProvider = Provider<int>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.totalCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Search notes provider
final searchNotesProvider = FutureProvider.family<List<UnifiedNote>, String>((ref, query) async {
  final repository = ref.watch(unifiedNotesRepositoryProvider);
  return await repository.searchUnified(query);
});

/// Notes in folder provider
final notesInFolderProvider = FutureProvider.family<List<UnifiedNote>, String>((ref, folderId) async {
  final repository = ref.watch(unifiedNotesRepositoryProvider);
  return await repository.getNotesInFolder(folderId);
});

/// Watch notes stream
final watchNotesProvider = StreamProvider<List<UnifiedNote>>((ref) {
  final repository = ref.watch(unifiedNotesRepositoryProvider);
  return repository.watchNotesUnified();
});

/// Watch notes in folder stream
final watchNotesInFolderProvider = StreamProvider.family<List<UnifiedNote>, String>((ref, folderId) {
  final repository = ref.watch(unifiedNotesRepositoryProvider);
  return repository.watchNotesInFolderUnified(folderId);
});

// Placeholder providers that need to be defined elsewhere
final currentFolderProvider = StateProvider<dynamic>((ref) => null);
final filterStateProvider = StateProvider<FilterState?>((ref) => null);