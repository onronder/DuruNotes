import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/features/search/providers/search_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Export important types for easier importing
export 'package:duru_notes/data/local/app_db.dart' show LocalNote;
export 'package:duru_notes/features/notes/pagination_notifier.dart'
    show NotesPage;

/// Provider for paginated notes (domain architecture)
///
/// **PRODUCTION NOTE**: Legacy pagination has been removed.
/// This now uses the domain repository exclusively.
final notesPageProvider =
    StateNotifierProvider.autoDispose<
      NotesPaginationNotifier,
      AsyncValue<NotesPage>
    >((ref) {
      // Use domain repository - always available
      // Repository handles auth internally and returns empty data when not authenticated
      final repo = ref.watch(notesCoreRepositoryProvider);

      final notifier = NotesPaginationNotifier(ref, repo)..loadMore();
      return notifier;
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
///
/// POST-ENCRYPTION: Now returns domain.Note with decrypted content
final currentNotesProvider = Provider<List<domain.Note>>((ref) {
  final result = ref
      .watch(notesPageProvider)
      .when(
        data: (page) {
          debugPrint(
            '📄 currentNotesProvider: Loaded ${page.items.length} notes from page',
          );
          return page.items;
        },
        loading: () {
          debugPrint('📄 currentNotesProvider: Loading...');
          return <domain.Note>[];
        },
        error: (error, stackTrace) {
          debugPrint('📄 currentNotesProvider: Error - $error');
          return <domain.Note>[];
        },
      );
  return result;
});

/// DEPRECATED: Use currentNotesProvider directly - it now returns domain.Note
@Deprecated('Use currentNotesProvider - both now return domain.Note')
final dualCurrentNotesProvider = Provider<List<domain.Note>>((ref) {
  return ref.watch(currentNotesProvider); // No cast needed anymore
});

/// Provider to check if there are more notes to load
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref
      .watch(notesPageProvider)
      .when(
        data: (page) => page.hasMore,
        loading: () => true,
        error: (_, _) => false,
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
///
/// POST-ENCRYPTION: Now returns domain.Note with decrypted content
final filteredNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((
  ref,
) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);
  // Use domain repository - always available
  final repo = ref.watch(notesCoreRepositoryProvider);
  final folderRepo = ref.watch(folderCoreRepositoryProvider);

  // Keep provider in sync with pagination stream updates.
  ref.watch(notesPageProvider);

  // Get base notes based on folder selection
  List<domain.Note> notes;
  if (currentFolder != null) {
    // Fetch folder notes via repository to avoid client-side filtering on encrypted data.
    notes = await folderRepo.getNotesInFolder(currentFolder.id);

    debugPrint(
      '🔍 FOLDER FILTER ACTIVE: ${currentFolder.name} (${currentFolder.id}) → ${notes.length} notes',
    );
  } else {
    // IMPORTANT: Use watch instead of read to trigger rebuilds when notes update
    notes = ref.watch(currentNotesProvider);

    // DEBUG: Log no folder filter
    debugPrint('🔍 NO FOLDER FILTER: Total notes ${notes.length}');
  }

  // DEBUG: Log before advanced filters
  debugPrint('🔍 [Filter] BEFORE: ${notes.length} notes');
  if (filterState != null) {
    debugPrint(
      '🔍 [Filter] State: pinnedOnly=${filterState.pinnedOnly}, includeTags=${filterState.includeTags}, excludeTags=${filterState.excludeTags}',
    );
  }

  // Apply advanced filters if active
  if (filterState != null && filterState.hasActiveFilters) {
    // Filter by pinned status
    if (filterState.pinnedOnly) {
      notes = notes.where((note) => note.isPinned).toList();
      debugPrint('🔍 [Filter] After pinnedOnly: ${notes.length} notes');
    }

    // Batch fetch tags for all notes if needed
    if (filterState.includeTags.isNotEmpty ||
        filterState.excludeTags.isNotEmpty) {
      // Batch fetch all tags at once
      final noteIds = notes.map((n) => n.id).toList();
      final noteTagsMap = await _batchFetchTags(repo, noteIds);

      // DEBUG: Show tag distribution
      final tagCounts = <String, int>{};
      noteTagsMap.forEach((noteId, tags) {
        for (final tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      });
      debugPrint('🔍 [Filter] Tag distribution: $tagCounts');

      // Filter by included tags
      if (filterState.includeTags.isNotEmpty) {
        final beforeCount = notes.length;
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has ALL required tags
          final hasAllTags = filterState.includeTags.every(tagSet.contains);
          if (!hasAllTags && tagSet.isNotEmpty) {
            debugPrint(
              '🔍 [Filter] Note excluded: has $tagSet but needs ${filterState.includeTags}',
            );
          }
          return hasAllTags;
        }).toList();
        debugPrint(
          '🔍 [Filter] After includeTags filter: ${notes.length}/$beforeCount notes (filtered: ${filterState.includeTags})',
        );
      }

      // Filter by excluded tags
      if (filterState.excludeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has NONE of the excluded tags
          return !filterState.excludeTags.any(tagSet.contains);
        }).toList();
        debugPrint(
          '🔍 [Filter] After excludeTags filter: ${notes.length} notes',
        );
      }
    }
  }

  // DEBUG: Final count
  debugPrint('🔍 [Filter] FINAL: ${notes.length} notes');

  return notes;
});
