import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/dual_pagination_notifier.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/features/search/providers/search_providers.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Export important types for easier importing
export 'package:duru_notes/data/local/app_db.dart' show LocalNote;
export 'package:duru_notes/features/notes/pagination_notifier.dart' show NotesPage;

/// Provider for paginated notes
final notesPageProvider = StateNotifierProvider.autoDispose<
    NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NotesPaginationNotifier(ref, repo)
    ..loadMore(); // Load first page immediately
});

/// Dual pagination provider - works with both LocalNote and domain.Note
final dualNotesPageProvider = StateNotifierProvider.autoDispose<
    DualNotesPaginationNotifier, AsyncValue<DualNotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  final config = ref.watch(migrationConfigProvider);
  return DualNotesPaginationNotifier(ref, repo, config)
    ..loadMore(); // Load first page immediately
});

/// Provider to watch just the loading state
final notesLoadingProvider = Provider<bool>((ref) {
  final notifier = ref.watch(notesPageProvider.notifier);
  return notifier.isLoadingMore;
});

/// Provider to watch just the current notes list
final currentNotesProvider = Provider<List<LocalNote>>((ref) {
  return ref.watch(notesPageProvider).when(
        data: (page) => page.items,
        loading: () => <LocalNote>[],
        error: (_, __) => <LocalNote>[],
      );
});

/// Provider to get current notes in the appropriate format
final dualCurrentNotesProvider = Provider<List<dynamic>>((ref) {
  final config = ref.watch(migrationConfigProvider);
  return ref.watch(dualNotesPageProvider).when(
    data: (page) => page.getNotes(config.isFeatureEnabled('notes')),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider to check if there are more notes to load
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref.watch(notesPageProvider).when(
        data: (page) => page.hasMore,
        loading: () => true,
        error: (_, __) => false,
      );
});

/// Helper function to batch fetch tags for multiple notes
Future<Map<String, Set<String>>> _batchFetchTags(
  NotesRepository repo,
  List<String> noteIds,
) async {
  final result = <String, Set<String>>{};

  // Batch fetch all tags in a single query
  final db = repo.db;
  final tagsQuery = db.select(db.noteTags)
    ..where((t) => t.noteId.isIn(noteIds));

  final allTags = await tagsQuery.get();

  // Group tags by note ID
  for (final tag in allTags) {
    result.putIfAbsent(tag.noteId, () => {}).add(tag.tag);
  }

  // Ensure all noteIds have an entry (even if empty)
  for (final noteId in noteIds) {
    result.putIfAbsent(noteId, () => {});
  }

  return result;
}

/// Provider for folder-filtered notes
final filteredNotesProvider = FutureProvider<List<LocalNote>>((ref) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);
  final repo = ref.watch(notesRepositoryProvider);

  // Get base notes based on folder selection
  List<LocalNote> notes;
  if (currentFolder != null) {
    notes = await repo.getNotesInFolder(currentFolder.id);
  } else {
    // IMPORTANT: Use watch instead of read to trigger rebuilds when notes update
    notes = ref.watch(currentNotesProvider);
  }

  // Apply advanced filters if active
  if (filterState != null && filterState.hasActiveFilters) {
    // Filter by pinned status
    if (filterState.pinnedOnly) {
      notes = notes.where((note) => note.isPinned).toList();
    }

    // Batch fetch tags for all notes if needed
    if (filterState.includeTags.isNotEmpty ||
        filterState.excludeTags.isNotEmpty) {
      // Batch fetch all tags at once
      final noteIds = notes.map((n) => n.id).toList();
      final noteTagsMap = await _batchFetchTags(repo, noteIds);

      // Filter by included tags
      if (filterState.includeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has ALL required tags
          return filterState.includeTags.every(tagSet.contains);
        }).toList();
      }

      // Filter by excluded tags
      if (filterState.excludeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has NONE of the excluded tags
          return !filterState.excludeTags.any(tagSet.contains);
        }).toList();
      }
    }
  }

  return notes;
});