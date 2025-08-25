import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/features/notes/pagination_notifier.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';

/// Provider for the notes repository
/// This should already exist in your app, but including for completeness
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  throw UnimplementedError('NotesRepository provider should be implemented in your main providers file');
});

/// Provider for paginated notes
final notesPageProvider = StateNotifierProvider<NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NotesPaginationNotifier(repo)..loadMore(); // Load first page immediately
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

/// Provider to check if there are more notes to load
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.hasMore,
    loading: () => true,
    error: (_, __) => false,
  );
});
