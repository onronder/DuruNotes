// DEPRECATED: This file is being replaced by notes_pagination_providers.dart
// All conditional logic has been removed in favor of the unified architecture
// This file will be deleted once migration is complete

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/features/notes/providers/notes_pagination_providers.dart';

/// DEPRECATED: Use notesPageProvider from notes_pagination_providers.dart
@Deprecated('Use notesPageProvider from notes_pagination_providers.dart')
final conditionalNotesPageProvider = notesPageProvider;

/// DEPRECATED: Use currentNotesProvider from notes_pagination_providers.dart
@Deprecated('Use currentNotesProvider from notes_pagination_providers.dart')
final conditionalCurrentNotesProvider = Provider<List<dynamic>>((ref) {
  // Redirect to unified provider - returns whatever type currentNotesProvider returns
  final notes = ref.watch(currentNotesProvider);
  return notes.cast<dynamic>();
});

/// DEPRECATED: Use filteredNotesProvider from notes_pagination_providers.dart
@Deprecated('Use filteredNotesProvider from notes_pagination_providers.dart')
final conditionalFilteredNotesProvider = filteredNotesProvider;

/// DEPRECATED: Use hasMoreNotesProvider from notes_pagination_providers.dart
@Deprecated('Use hasMoreNotesProvider from notes_pagination_providers.dart')
final conditionalHasMoreProvider = hasMoreNotesProvider;

/// DEPRECATED: Use notesLoadingProvider from notes_pagination_providers.dart
@Deprecated('Use notesLoadingProvider from notes_pagination_providers.dart')
final conditionalNotesLoadingProvider = notesLoadingProvider;

/// Helper extension to provide conditional notifier access
/// DEPRECATED: Access notesPageProvider.notifier directly
@Deprecated('Access notesPageProvider.notifier directly')
extension ConditionalNotesNotifier on WidgetRef {
  /// Get the appropriate notes notifier based on migration config
  dynamic getNotesNotifier() {
    // Always use unified provider
    return read(notesPageProvider.notifier);
  }

  /// Refresh notes conditionally
  Future<void> refreshNotes() async {
    // Always use unified provider
    await read(notesPageProvider.notifier).refresh();
  }

  /// Load more notes conditionally
  Future<void> loadMoreNotes() async {
    // Always use unified provider
    await read(notesPageProvider.notifier).loadMore();
  }
}