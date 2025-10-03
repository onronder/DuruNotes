// MIGRATION NOTICE: This file has been refactored to use domain architecture
//
// The unified repository pattern has been replaced with clean domain architecture.
// All unified providers now delegate to the domain-based implementation.
//
// Instead of using this file directly, import from:
// - notes_repository_providers.dart (for repository access)
// - notes_pagination_providers.dart (for pagination logic)
// - notes_domain_providers.dart (for domain entities)
//
// This file is kept for backward compatibility and will be removed in a future release.

// NOTE: Exports must come before other declarations
export 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show currentFolderProvider;
export 'package:duru_notes/features/search/providers/search_providers.dart'
    show filterStateProvider;

import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/features/notes/providers/notes_pagination_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DEPRECATED: Use notesCoreRepositoryProvider instead
/// This is kept for backward compatibility
@Deprecated('Use notesCoreRepositoryProvider from notes_repository_providers.dart')
final unifiedNotesRepositoryProvider = notesCoreRepositoryProvider;

/// DEPRECATED: Use notesPageProvider instead
/// This is kept for backward compatibility
@Deprecated('Use notesPageProvider from notes_pagination_providers.dart')
final notesPageProviderUnified = notesPageProvider;

/// DEPRECATED: Use currentNotesProvider instead
/// This is kept for backward compatibility
@Deprecated('Use currentNotesProvider from notes_pagination_providers.dart')
final currentNotesProviderUnified = currentNotesProvider;

/// DEPRECATED: Use filteredNotesProvider instead
/// Returns domain.Note for backward compatibility
@Deprecated('Use filteredNotesProvider from notes_pagination_providers.dart')
final filteredNotesProviderUnified = filteredNotesProvider;

/// DEPRECATED: Use hasMoreNotesProvider instead
@Deprecated('Use hasMoreNotesProvider from notes_pagination_providers.dart')
final hasMoreNotesProviderUnified = hasMoreNotesProvider;

/// DEPRECATED: Use notesLoadingProvider instead
@Deprecated('Use notesLoadingProvider from notes_pagination_providers.dart')
final notesLoadingProviderUnified = notesLoadingProvider;

/// DEPRECATED: Total notes count provider
/// Returns count of currently loaded notes
@Deprecated('Use currentNotesProvider.length instead')
final totalNotesCountProvider = Provider<int>((ref) {
  return ref.watch(currentNotesProvider).length;
});

/// DEPRECATED: Search notes provider
/// Use the domain repository's list functionality with filtering instead
@Deprecated('Use notesCoreRepositoryProvider.list() with filtering')
final searchNotesProvider = FutureProvider.family<List<domain.Note>, String>((ref, query) async {
  final repository = ref.watch(notesCoreRepositoryProvider);

  // Use list() and filter locally
  final allNotes = await repository.list();
  final lowerQuery = query.toLowerCase();

  return allNotes.where((note) {
    return note.title.toLowerCase().contains(lowerQuery) ||
           note.body.toLowerCase().contains(lowerQuery);
  }).toList();
});

/// DEPRECATED: Notes in folder provider
/// Use the domain repository's watchNotes with folderId parameter instead
@Deprecated('Use notesCoreRepositoryProvider.watchNotes(folderId: id)')
final notesInFolderProvider = FutureProvider.family<List<domain.Note>, String>((ref, folderId) async {
  final repository = ref.watch(notesCoreRepositoryProvider);

  // Use watchNotes with folderId filter, convert stream to future
  return await repository.watchNotes(folderId: folderId).first;
});

/// DEPRECATED: Watch notes stream
/// Use the domain repository's watchNotes functionality instead
@Deprecated('Use notesCoreRepositoryProvider.watchNotes() directly')
final watchNotesProvider = StreamProvider<List<domain.Note>>((ref) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  return repository.watchNotes();
});

/// DEPRECATED: Watch notes in folder stream
/// Use the domain repository's watchNotes with folderId parameter instead
@Deprecated('Use notesCoreRepositoryProvider.watchNotes(folderId: id)')
final watchNotesInFolderProvider = StreamProvider.family<List<domain.Note>, String>((ref, folderId) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  return repository.watchNotes(folderId: folderId);
});
