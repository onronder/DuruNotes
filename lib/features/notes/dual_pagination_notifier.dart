import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/migration/migration_config.dart';

/// Dual-mode pagination notifier that can work with both LocalNote and domain.Note
class DualNotesPaginationNotifier extends StateNotifier<AsyncValue<DualNotesPage>> {
  DualNotesPaginationNotifier(
    this._ref,
    this._repository,
    this._migrationConfig,
  ) : super(const AsyncValue.data(DualNotesPage(
          localNotes: [],
          domainNotes: [],
          hasMore: true,
          nextCursor: null,
        )));

  final Ref _ref;
  final NotesRepository _repository;
  final MigrationConfig _migrationConfig;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMore() async {
    if (_isLoadingMore) return;

    final currentState = state.value;
    if (currentState == null || !currentState.hasMore) return;

    _isLoadingMore = true;

    try {
      // Load from repository (always returns LocalNote)
      final newNotes = await _repository.listAfter(currentState.nextCursor);

      // Determine if there are more pages
      const pageSize = 20;
      final hasMore = newNotes.length == pageSize;
      final nextCursor = newNotes.isNotEmpty ? newNotes.last.updatedAt : null;

      // Convert to appropriate type based on migration config
      if (_migrationConfig.isFeatureEnabled('notes')) {
        // Convert LocalNotes to domain.Notes
        final domainNotes = newNotes.map(NoteMapper.toDomain).toList();

        state = AsyncValue.data(DualNotesPage(
          localNotes: [...currentState.localNotes, ...newNotes],
          domainNotes: [...currentState.domainNotes, ...domainNotes],
          hasMore: hasMore,
          nextCursor: nextCursor,
        ));
      } else {
        // Use LocalNotes directly
        state = AsyncValue.data(DualNotesPage(
          localNotes: [...currentState.localNotes, ...newNotes],
          domainNotes: [],
          hasMore: hasMore,
          nextCursor: nextCursor,
        ));
      }
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.data(DualNotesPage(
      localNotes: [],
      domainNotes: [],
      hasMore: true,
      nextCursor: null,
    ));
    await loadMore();
  }

  void deleteNote(String noteId) {
    final currentState = state.value;
    if (currentState == null) return;

    if (_migrationConfig.isFeatureEnabled('notes')) {
      state = AsyncValue.data(DualNotesPage(
        localNotes: currentState.localNotes
            .where((note) => note.id != noteId)
            .toList(),
        domainNotes: currentState.domainNotes
            .where((note) => note.id != noteId)
            .toList(),
        hasMore: currentState.hasMore,
        nextCursor: currentState.nextCursor,
      ));
    } else {
      state = AsyncValue.data(DualNotesPage(
        localNotes: currentState.localNotes
            .where((note) => note.id != noteId)
            .toList(),
        domainNotes: currentState.domainNotes,
        hasMore: currentState.hasMore,
        nextCursor: currentState.nextCursor,
      ));
    }
  }

  void updateNote(dynamic updatedNote) {
    final currentState = state.value;
    if (currentState == null) return;

    if (_migrationConfig.isFeatureEnabled('notes')) {
      // Handle domain.Note update
      if (updatedNote is domain.Note) {
        final localNote = NoteMapper.toInfrastructure(updatedNote);

        state = AsyncValue.data(DualNotesPage(
          localNotes: currentState.localNotes.map((note) {
            return note.id == localNote.id ? localNote : note;
          }).toList(),
          domainNotes: currentState.domainNotes.map((note) {
            return note.id == updatedNote.id ? updatedNote : note;
          }).toList(),
          hasMore: currentState.hasMore,
          nextCursor: currentState.nextCursor,
        ));
      }
    } else {
      // Handle LocalNote update
      if (updatedNote is LocalNote) {
        state = AsyncValue.data(DualNotesPage(
          localNotes: currentState.localNotes.map((note) {
            return note.id == updatedNote.id ? updatedNote : note;
          }).toList(),
          domainNotes: currentState.domainNotes,
          hasMore: currentState.hasMore,
          nextCursor: currentState.nextCursor,
        ));
      }
    }
  }
}

/// Dual notes page that can hold both LocalNote and domain.Note
class DualNotesPage {
  const DualNotesPage({
    required this.localNotes,
    required this.domainNotes,
    required this.hasMore,
    required this.nextCursor,
    this.isLoading = false,
  });

  final List<LocalNote> localNotes;
  final List<domain.Note> domainNotes;
  final bool hasMore;
  final DateTime? nextCursor;
  final bool isLoading;

  /// Get the appropriate notes list based on migration config
  List<dynamic> getNotes(bool useDomainModels) {
    return useDomainModels ? domainNotes : localNotes;
  }

  /// Get notes count
  int get notesCount {
    return localNotes.isNotEmpty ? localNotes.length : domainNotes.length;
  }
}