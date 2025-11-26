import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/core/events/mutation_event_bus.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notes UI state providers
///
/// This file contains providers that manage UI state for the notes feature,
/// including filtering, sorting, and pagination.

/// Current folder filter provider
///
/// DEPRECATED: Use folders_state_providers.dart instead for new code.
/// This provider is maintained here for backward compatibility with existing UI.
/// It tracks which folder is currently selected in the notes list view.
final currentFolderProvider =
    StateNotifierProvider<CurrentFolderNotifier, domain_folder.Folder?>((ref) {
      return CurrentFolderNotifier();
    });

/// Current filter state for advanced filters
///
/// Manages the active filter state including:
/// - Pinned-only filtering
/// - Tag inclusion filters
/// - Tag exclusion filters
///
/// This is a nullable state provider - null means no filters are active.
final filterStateProvider = StateProvider.autoDispose<FilterState?>(
  (ref) => null,
);

/// Provider for folder-filtered notes
///
/// This provider combines folder selection and advanced filtering to
/// return the appropriate list of notes for display.
///
/// Filtering logic:
/// 1. If a folder is selected, get notes from that folder
/// 2. Otherwise, use the current paginated notes list
/// 3. Apply advanced filters if active (pinned, tags, etc.)
final filteredNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((
  ref,
) async {
  // CRITICAL FIX: Safety check to prevent crashes during startup
  if (!SecurityInitialization.isInitialized) {
    debugPrint(
      '[filteredNotesProvider] Security not initialized, returning empty',
    );
    return <domain.Note>[];
  }

  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);

  // Get base notes based on folder selection
  List<domain.Note> notes;
  if (currentFolder != null) {
    final folderRepo = ref.watch(folderCoreRepositoryProvider);
    notes = await folderRepo.getNotesInFolder(currentFolder.id);
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

    // Filter by tags (domain.Note already has tags property)
    if (filterState.includeTags.isNotEmpty) {
      notes = notes.where((note) {
        // Check if note has ALL required tags
        return filterState.includeTags.every(note.tags.contains);
      }).toList();
    }

    if (filterState.excludeTags.isNotEmpty) {
      notes = notes.where((note) {
        // Check if note has NONE of the excluded tags
        return !filterState.excludeTags.any(note.tags.contains);
      }).toList();
    }
  }

  return notes;
});

/// Sort preferences service
///
/// Service for managing note sorting preferences per folder.
/// Persists user's preferred sort order for each folder.
final sortPreferencesServiceProvider = Provider<SortPreferencesService>((ref) {
  return SortPreferencesService();
});

/// Current sort spec for the selected folder
///
/// Manages the current sorting specification for the active folder.
/// Automatically loads the saved preference when the folder changes.
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
///
/// This state notifier manages the sorting specification for notes,
/// including loading saved preferences and persisting changes.
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

/// Provider to watch just the current notes list
///
/// POST-ENCRYPTION: Now returns domain.Note with decrypted content
/// This is a convenience provider that extracts just the notes list
/// from the paginated notes provider.
final currentNotesProvider = Provider<List<domain.Note>>((ref) {
  return ref
      .watch(notesPageProvider)
      .when(
        data: (page) => page.items,
        loading: () => <domain.Note>[],
        error: (_, _) => <domain.Note>[],
      );
});

/// Provider for paginated notes
///
/// This is the main provider for the notes list screen.
/// It manages pagination, loading states, and note updates.
///
/// NOTE: This provider is re-exported here for convenience.
/// The actual definition is in notes_pagination_providers.dart
final notesPageProvider =
    StateNotifierProvider.autoDispose<
      NotesPaginationNotifier,
      AsyncValue<NotesPage>
    >((ref) {
      // PHASE 5 FIX: Lazy provider initialization with security check
      // This prevents race conditions during app startup where the provider
      // might be created before security services are ready
      if (!SecurityInitialization.isInitialized) {
        debugPrint(
          '[notesPageProvider] Security not initialized, returning empty notifier',
        );
        // Return empty notifier that no-ops all operations until security is ready
        return NotesPaginationNotifier.empty(ref);
      }

      final repo = ref.watch(notesCoreRepositoryProvider);
      final mutationBus = MutationEventBus.instance;

      // PHASE 5 FIX: Create notifier WITHOUT calling loadMore() immediately
      // Let the UI explicitly trigger the first load when it's ready
      // This prevents database queries during the critical startup path
      debugPrint(
        '[notesPageProvider] Creating active notifier (loadMore deferred to UI)',
      );
      return NotesPaginationNotifier(ref, repo, mutationBus: mutationBus);
    });

/// Provider to check if there are more notes to load
///
/// Returns true if pagination has more pages available.
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref
      .watch(notesPageProvider)
      .when(
        data: (page) => page.hasMore,
        loading: () => true,
        error: (_, _) => false,
      );
});

/// Provider to watch just the loading state
///
/// Returns true if notes are currently being loaded.
final notesLoadingProvider = Provider<bool>((ref) {
  final notifier = ref.watch(notesPageProvider.notifier);
  return notifier.isLoadingMore;
});

/// Trash providers for Phase 1.1 soft delete functionality

/// Provider for deleted notes
///
/// Fetches all soft-deleted notes from the repository for display in the Trash screen.
/// Notes are ordered by updated_at (deletion time) in descending order.
final deletedNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((
  ref,
) async {
  final repo = ref.watch(notesCoreRepositoryProvider);
  return repo.getDeletedNotes();
});

/// Provider for deleted folders
///
/// Fetches all soft-deleted folders from the repository for display in the Trash screen.
final deletedFoldersProvider =
    FutureProvider.autoDispose<List<domain_folder.Folder>>((ref) async {
      final repo = ref.watch(folderCoreRepositoryProvider);
      return repo.getDeletedFolders();
    });

/// Provider for deleted tasks
///
/// Fetches all soft-deleted tasks from the repository for display in the Trash screen.
final deletedTasksProvider = FutureProvider.autoDispose<List<domain_task.Task>>(
  (ref) async {
    final repo = ref.watch(taskCoreRepositoryProvider);
    if (repo == null) {
      return <domain_task.Task>[];
    }
    return repo.getDeletedTasks();
  },
);

/// Provider for total count of deleted items across all types
///
/// Returns the sum of deleted notes, folders, and tasks for display in UI.
final deletedItemsCountProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  final notesAsync = ref.watch(deletedNotesProvider);
  final foldersAsync = ref.watch(deletedFoldersProvider);
  final tasksAsync = ref.watch(deletedTasksProvider);

  // Wait for all providers to load
  return notesAsync.whenData((notes) {
    return foldersAsync.whenData((folders) {
          return tasksAsync.whenData((tasks) {
                return notes.length + folders.length + tasks.length;
              }).valueOrNull ??
              0;
        }).valueOrNull ??
        0;
  });
});
