import 'package:duru_notes/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for batch selection operations
class BatchSelectionState {
  const BatchSelectionState({
    this.selectedNoteIds = const {},
    this.isSelectionMode = false,
    this.selectionStartTime,
  });
  final Set<String> selectedNoteIds;
  final bool isSelectionMode;
  final DateTime? selectionStartTime;

  BatchSelectionState copyWith({
    Set<String>? selectedNoteIds,
    bool? isSelectionMode,
    DateTime? selectionStartTime,
  }) {
    return BatchSelectionState(
      selectedNoteIds: selectedNoteIds ?? this.selectedNoteIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectionStartTime: selectionStartTime ?? this.selectionStartTime,
    );
  }

  int get selectedCount => selectedNoteIds.length;
  bool get hasSelection => selectedNoteIds.isNotEmpty;

  bool isSelected(String noteId) => selectedNoteIds.contains(noteId);
}

/// Notifier for managing batch selection
class BatchSelectionNotifier extends StateNotifier<BatchSelectionState> {
  BatchSelectionNotifier() : super(const BatchSelectionState());

  /// Enter selection mode
  void enterSelectionMode({String? initialNoteId}) {
    HapticFeedback.mediumImpact();

    final selectedIds = initialNoteId != null ? {initialNoteId} : <String>{};

    state = state.copyWith(
      isSelectionMode: true,
      selectedNoteIds: selectedIds,
      selectionStartTime: DateTime.now(),
    );
  }

  /// Exit selection mode
  void exitSelectionMode() {
    HapticFeedback.lightImpact();

    state = const BatchSelectionState();
  }

  /// Toggle selection of a note
  void toggleNoteSelection(String noteId) {
    HapticFeedback.selectionClick();

    final selectedIds = Set<String>.from(state.selectedNoteIds);

    if (selectedIds.contains(noteId)) {
      selectedIds.remove(noteId);
    } else {
      selectedIds.add(noteId);
    }

    // If no notes selected, exit selection mode
    if (selectedIds.isEmpty) {
      exitSelectionMode();
      return;
    }

    state = state.copyWith(selectedNoteIds: selectedIds);
  }

  /// Select all notes
  void selectAll(List<String> allNoteIds) {
    HapticFeedback.mediumImpact();

    state = state.copyWith(
      selectedNoteIds: Set<String>.from(allNoteIds),
      isSelectionMode: true,
      selectionStartTime: state.selectionStartTime ?? DateTime.now(),
    );
  }

  /// Select notes in range (for shift+click behavior)
  void selectRange(List<String> noteIds, String startId, String endId) {
    final startIndex = noteIds.indexOf(startId);
    final endIndex = noteIds.indexOf(endId);

    if (startIndex == -1 || endIndex == -1) return;

    final rangeStart = startIndex < endIndex ? startIndex : endIndex;
    final rangeEnd = startIndex < endIndex ? endIndex : startIndex;

    final selectedIds = Set<String>.from(state.selectedNoteIds);
    for (var i = rangeStart; i <= rangeEnd; i++) {
      selectedIds.add(noteIds[i]);
    }

    HapticFeedback.selectionClick();

    state = state.copyWith(
      selectedNoteIds: selectedIds,
      isSelectionMode: true,
      selectionStartTime: state.selectionStartTime ?? DateTime.now(),
    );
  }

  /// Clear selection
  void clearSelection() {
    HapticFeedback.lightImpact();

    state = state.copyWith(selectedNoteIds: <String>{});
  }

  /// Select notes by criteria
  void selectByCriteria({
    bool favorites = false,
    bool archived = false,
    bool encrypted = false,
    bool withAttachments = false,
    bool withTasks = false,
    DateTime? createdAfter,
    DateTime? modifiedAfter,
  }) {
    // This would need to be implemented with the notes repository
    // For now, just enter selection mode
    if (!state.isSelectionMode) {
      enterSelectionMode();
    }
  }

  /// Invert selection
  void invertSelection(List<String> allNoteIds) {
    HapticFeedback.mediumImpact();

    final currentSelection = state.selectedNoteIds;
    final invertedSelection = Set<String>.from(
      allNoteIds,
    ).where((id) => !currentSelection.contains(id)).toSet();

    state = state.copyWith(
      selectedNoteIds: invertedSelection,
      isSelectionMode: invertedSelection.isNotEmpty,
      selectionStartTime: state.selectionStartTime ?? DateTime.now(),
    );
  }
}

/// Provider for batch selection state
final batchSelectionProvider =
    StateNotifierProvider<BatchSelectionNotifier, BatchSelectionState>((ref) {
  return BatchSelectionNotifier();
});

/// Provider for selected notes objects
final selectedNotesProvider = Provider<List<LocalNote>>((ref) {
  final selectionState = ref.watch(batchSelectionProvider);
  final notesState = ref.watch(currentNotesProvider);

  if (selectionState.selectedNoteIds.isEmpty) return [];

  return notesState
      .where((note) => selectionState.selectedNoteIds.contains(note.id))
      .toList();
});

/// Provider for batch operation capabilities
final batchOperationCapabilitiesProvider = Provider<BatchOperationCapabilities>(
  (ref) {
    final selectedNotes = ref.watch(selectedNotesProvider);
    return BatchOperationCapabilities.fromNotes(selectedNotes);
  },
);

/// Capabilities for batch operations based on selected notes
class BatchOperationCapabilities {
  const BatchOperationCapabilities({
    required this.canMove,
    required this.canDelete,
    required this.canArchive,
    required this.canUnarchive,
    required this.canFavorite,
    required this.canUnfavorite,
    required this.canEncrypt,
    required this.canDecrypt,
    required this.canExport,
    required this.canShare,
    required this.noteCount,
  });

  factory BatchOperationCapabilities.fromNotes(List<LocalNote> notes) {
    if (notes.isEmpty) {
      return const BatchOperationCapabilities(
        canMove: false,
        canDelete: false,
        canArchive: false,
        canUnarchive: false,
        canFavorite: false,
        canUnfavorite: false,
        canEncrypt: false,
        canDecrypt: false,
        canExport: false,
        canShare: false,
        noteCount: 0,
      );
    }

    // Count different states
    const encryptedCount = 0;
    const archivedCount = 0;
    const favoriteCount = 0;

    for (final _ in notes) {
      // TODO: Add encryption support when available
      // if (note.encryptedDataKey != null) encryptedCount++;
      // TODO: Add archived and favorite fields to LocalNote
    }

    return BatchOperationCapabilities(
      canMove: true,
      canDelete: true,
      canArchive: archivedCount < notes.length,
      canUnarchive: archivedCount > 0,
      canFavorite: favoriteCount < notes.length,
      canUnfavorite: favoriteCount > 0,
      canEncrypt: encryptedCount < notes.length,
      canDecrypt: encryptedCount > 0,
      canExport: true,
      canShare: true,
      noteCount: notes.length,
    );
  }
  final bool canMove;
  final bool canDelete;
  final bool canArchive;
  final bool canUnarchive;
  final bool canFavorite;
  final bool canUnfavorite;
  final bool canEncrypt;
  final bool canDecrypt;
  final bool canExport;
  final bool canShare;
  final int noteCount;
}

/// Batch operations notifier
class BatchOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  BatchOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Move selected notes to folder
  Future<void> moveNotesToFolder(String? folderId) async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      final noteFolderNotifier = _ref.read(noteFolderProvider.notifier);

      for (final note in selectedNotes) {
        if (folderId != null) {
          await noteFolderNotifier.addNoteToFolder(note.id, folderId);
        } else {
          await noteFolderNotifier.removeNoteFromFolder(note.id);
        }
      }

      // Clear selection after successful operation
      _ref.read(batchSelectionProvider.notifier).exitSelectionMode();

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Delete selected notes
  Future<void> deleteSelectedNotes() async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(notesRepositoryProvider);

      for (final note in selectedNotes) {
        await repository.delete(note.id);
      }

      // Refresh notes list
      await _ref.read(notesPageProvider.notifier).refresh();

      // Clear selection
      _ref.read(batchSelectionProvider.notifier).exitSelectionMode();

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Archive/unarchive selected notes
  Future<void> toggleArchiveSelectedNotes(bool archive) async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      // final repository = _ref.read(notesRepositoryProvider);

      for (final _ in selectedNotes) {
        // TODO: Implement archive functionality in repository
        // await repository.setArchived(note.id, archive);
      }

      // Refresh notes list
      await _ref.read(notesPageProvider.notifier).refresh();

      // Clear selection
      _ref.read(batchSelectionProvider.notifier).exitSelectionMode();

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Toggle favorite for selected notes
  Future<void> toggleFavoriteSelectedNotes(bool favorite) async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      // final repository = _ref.read(notesRepositoryProvider);

      for (final _ in selectedNotes) {
        // TODO: Implement favorite functionality in repository
        // await repository.setFavorite(note.id, favorite);
      }

      // Refresh notes list
      await _ref.read(notesPageProvider.notifier).refresh();

      // Clear selection
      _ref.read(batchSelectionProvider.notifier).exitSelectionMode();

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Export selected notes
  Future<void> exportSelectedNotes(String format) async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      // final exportService = _ref.read(exportServiceProvider);

      // TODO: Implement batch export in export service
      // await exportService.exportNotes(selectedNotes, format);

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Share selected notes
  Future<void> shareSelectedNotes() async {
    final selectedNotes = _ref.read(selectedNotesProvider);
    if (selectedNotes.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      // TODO: Implement sharing functionality
      // This would typically use the share_plus package

      state = const AsyncValue.data(null);
      HapticFeedback.lightImpact();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      HapticFeedback.heavyImpact();
    }
  }

  /// Clear any error state
  void clearError() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for batch operations
final batchOperationsProvider =
    StateNotifierProvider<BatchOperationsNotifier, AsyncValue<void>>((ref) {
  return BatchOperationsNotifier(ref);
});

/// Helper extensions for batch selection
extension BatchSelectionExtensions on BatchSelectionNotifier {
  /// Quick select by search query
  void selectBySearch(String query, List<LocalNote> allNotes) {
    if (query.isEmpty) return;

    final matchingIds = allNotes
        .where(
          (note) =>
              note.title.toLowerCase().contains(query.toLowerCase()) ||
              note.body.toLowerCase().contains(query.toLowerCase()),
        )
        .map((note) => note.id)
        .toSet();

    if (matchingIds.isNotEmpty) {
      state = state.copyWith(
        selectedNoteIds: matchingIds,
        isSelectionMode: true,
        selectionStartTime: state.selectionStartTime ?? DateTime.now(),
      );
    }
  }

  /// Select recently modified notes
  void selectRecentlyModified(List<LocalNote> allNotes, {Duration? within}) {
    final cutoff = DateTime.now().subtract(within ?? const Duration(days: 7));

    final recentIds = allNotes
        .where((note) => note.updatedAt.isAfter(cutoff))
        .map((note) => note.id)
        .toSet();

    if (recentIds.isNotEmpty) {
      state = state.copyWith(
        selectedNoteIds: recentIds,
        isSelectionMode: true,
        selectionStartTime: state.selectionStartTime ?? DateTime.now(),
      );
    }
  }

  /// Get selection statistics
  BatchSelectionStats getSelectionStats(List<LocalNote> allNotes) {
    final selectedNotes = allNotes
        .where((note) => state.selectedNoteIds.contains(note.id))
        .toList();

    return BatchSelectionStats.fromNotes(selectedNotes);
  }
}

/// Statistics for current selection
class BatchSelectionStats {
  const BatchSelectionStats({
    required this.totalNotes,
    required this.totalWords,
    required this.totalAttachments,
    required this.encryptedNotes,
    required this.selectionTime,
    this.oldestNote,
    this.newestNote,
    this.commonTags = const [],
  });

  factory BatchSelectionStats.fromNotes(List<LocalNote> notes) {
    if (notes.isEmpty) {
      return const BatchSelectionStats(
        totalNotes: 0,
        totalWords: 0,
        totalAttachments: 0,
        encryptedNotes: 0,
        selectionTime: Duration.zero,
      );
    }

    var totalWords = 0;
    const encryptedCount = 0;
    DateTime? oldest;
    DateTime? newest;

    for (final note in notes) {
      // Count words
      totalWords += note.body.split(RegExp(r'\s+')).length;

      // Check encryption - TODO: Add encryption support when available
      // if (note.encryptedDataKey != null) encryptedCount++;

      // Track dates using updatedAt since createdAt is not available
      if (oldest == null || note.updatedAt.isBefore(oldest)) {
        oldest = note.updatedAt;
      }
      if (newest == null || note.updatedAt.isAfter(newest)) {
        newest = note.updatedAt;
      }
    }

    return BatchSelectionStats(
      totalNotes: notes.length,
      totalWords: totalWords,
      totalAttachments: 0, // TODO: Count attachments
      encryptedNotes: encryptedCount,
      selectionTime: newest != null && oldest != null
          ? newest.difference(oldest)
          : Duration.zero,
      oldestNote: oldest,
      newestNote: newest,
    );
  }
  final int totalNotes;
  final int totalWords;
  final int totalAttachments;
  final int encryptedNotes;
  final Duration selectionTime;
  final DateTime? oldestNote;
  final DateTime? newestNote;
  final List<String> commonTags;
}
