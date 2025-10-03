import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/features/search/providers/search_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Export important types for easier importing
export 'package:duru_notes/data/local/app_db.dart' show LocalNote;
export 'package:duru_notes/features/notes/pagination_notifier.dart' show NotesPage;

/// Provider for paginated notes (domain architecture)
///
/// **PRODUCTION NOTE**: Legacy pagination has been removed.
/// This now uses the domain repository exclusively.
final notesPageProvider = StateNotifierProvider.autoDispose<
    NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NotesPaginationNotifier(ref, repo)
    ..loadMore(); // Load first page immediately
});

/// Dual pagination provider - alias for backwards compatibility
///
/// **PRODUCTION NOTE**: This is now an alias to notesPageProvider.
/// The dual pagination system has been removed.
final dualNotesPageProvider = notesPageProvider;

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
/// Returns domain notes for consistency across the app
final dualCurrentNotesProvider = Provider<List<domain.Note>>((ref) {
  return ref.watch(currentNotesProvider).cast<domain.Note>();
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
  INotesRepository repo,
  List<String> noteIds,
) async {
  final result = <String, Set<String>>{};

  // Get all notes with tags from repository
  // For now, fetch individually since batch operation is not in interface
  for (final noteId in noteIds) {
    final note = await repo.getNoteById(noteId);
    if (note != null) {
      result[noteId] = note.tags.toSet();
    } else {
      result[noteId] = {};
    }
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