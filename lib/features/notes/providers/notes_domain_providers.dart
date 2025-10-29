import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/search/providers/search_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart' show notesCoreRepositoryProvider;
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Domain notes stream provider - provides clean stream of domain.Note entities
/// This replaces the conditional providers to fix UI-Infrastructure connectivity
final domainNotesStreamProvider = StreamProvider.autoDispose<List<domain.Note>>((ref) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  return repository.watchNotes();
});

/// Domain filtered notes provider - provides filtered domain notes with folder and filter support
final domainFilteredNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((ref) async {
  final repository = ref.watch(notesCoreRepositoryProvider);
  final currentFolder = ref.watch(currentFolderProvider);
  // TODO: Integrate filterState when filters are properly defined
  // final filterState = ref.watch(filterStateProvider);
  final sortSpec = ref.watch(currentSortSpecProvider);

  // Get base notes based on folder selection
  List<domain.Note> notes;
  if (currentFolder != null) {
    // Use watchNotes with folder filter, but get first result for FutureProvider
    notes = await repository.watchNotes(folderId: currentFolder.id).first;
  } else {
    notes = await repository.localNotes();
  }

  // Apply filters if present
  // Note: FilterState integration will be done later when filters are properly defined

  // Apply sorting
  notes.sort((a, b) {
    switch (sortSpec.field) {
      case NoteSortField.updatedAt:
        final aDate = a.updatedAt;
        final bDate = b.updatedAt;
        return sortSpec.direction == SortDirection.asc
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
      case NoteSortField.createdAt:
        final aDate = a.updatedAt;
        final bDate = b.updatedAt;
        return sortSpec.direction == SortDirection.asc
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
      case NoteSortField.title:
        final aTitle = a.title;
        final bTitle = b.title;
        return sortSpec.direction == SortDirection.asc
            ? aTitle.compareTo(bTitle)
            : bTitle.compareTo(aTitle);
      default:
        return 0;
    }
  });

  return notes;
});

/// Domain pinned notes provider - provides only pinned domain notes
final domainPinnedNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((ref) async {
  final notes = await ref.watch(domainFilteredNotesProvider.future);
  return notes.where((note) => note.isPinned).toList();
});

/// Domain unpinned notes provider - provides only unpinned domain notes
final domainUnpinnedNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((ref) async {
  final notes = await ref.watch(domainFilteredNotesProvider.future);
  return notes.where((note) => !note.isPinned).toList();
});

/// Domain notes provider - uses domain repository
final domainNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((ref) async {
  // Always use domain repository (migration complete)
  final repository = ref.watch(notesCoreRepositoryProvider);
  return repository.list();
});