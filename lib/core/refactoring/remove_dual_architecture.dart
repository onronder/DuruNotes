// Migration helper to remove dual architecture pattern
// This file provides utilities to migrate from conditional providers to a unified architecture

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';

/// Unified Note type that can represent both LocalNote and domain.Note
/// This removes the need for conditional logic based on migration status
abstract class UnifiedNote {
  String get id;
  String get title;
  String get body;
  DateTime get updatedAt;
  bool get deleted;
  bool get isPinned;

  // Factory constructors to create from different sources
  factory UnifiedNote.fromLocal(LocalNote note) = _UnifiedNoteFromLocal;
  factory UnifiedNote.fromDomain(domain.Note note) = _UnifiedNoteFromDomain;

  // Convert to the required format
  LocalNote toLocal();
  domain.Note toDomain();
}

class _UnifiedNoteFromLocal implements UnifiedNote {
  final LocalNote _note;

  _UnifiedNoteFromLocal(this._note);

  @override
  String get id => _note.id;

  @override
  String get title => _note.title;

  @override
  String get body => _note.body;

  @override
  DateTime get updatedAt => _note.updatedAt;

  @override
  bool get deleted => _note.deleted;

  @override
  bool get isPinned => _note.isPinned;

  @override
  LocalNote toLocal() => _note;

  @override
  domain.Note toDomain() => domain.Note(
    id: _note.id,
    title: _note.title,
    body: _note.body,
    updatedAt: _note.updatedAt,
    deleted: _note.deleted,
    isPinned: _note.isPinned,
    userId: _note.userId ?? '',  // Handle nullable userId
    folderId: null,
    tags: [],
    version: _note.version,
    noteType: NoteKind.note,  // Required field
    links: [],  // Required field with default empty list
  );
}

class _UnifiedNoteFromDomain implements UnifiedNote {
  final domain.Note _note;

  _UnifiedNoteFromDomain(this._note);

  @override
  String get id => _note.id;

  @override
  String get title => _note.title;

  @override
  String get body => _note.body;

  @override
  DateTime get updatedAt => _note.updatedAt;

  @override
  bool get deleted => _note.deleted;

  @override
  bool get isPinned => _note.isPinned;

  @override
  LocalNote toLocal() => LocalNote(
    id: _note.id,
    title: _note.title,
    body: _note.body,
    updatedAt: _note.updatedAt,
    deleted: _note.deleted,
    isPinned: _note.isPinned,
    userId: _note.userId,
    version: _note.version,
    noteType: _note.noteType,  // NoteKind enum
    metadata: _note.metadata,
    encryptedMetadata: _note.encryptedMetadata,
    attachmentMeta: _note.attachmentMeta,
  );

  @override
  domain.Note toDomain() => _note;
}

/// Unified pagination that works with a single type
class UnifiedNotesPage {
  final List<UnifiedNote> notes;
  final bool hasMore;
  final int currentPage;

  UnifiedNotesPage({
    required this.notes,
    required this.hasMore,
    required this.currentPage,
  });
}

/// Base repository interface that all repositories should implement
abstract class IUnifiedNotesRepository {
  Future<UnifiedNotesPage> getNotes({
    required int page,
    required int pageSize,
    String? folderId,
    String? searchQuery,
  });

  Future<void> createNote(UnifiedNote note);
  Future<void> updateNote(UnifiedNote note);
  Future<void> deleteNote(String id);
  Future<void> refresh();

  Stream<List<UnifiedNote>> watchNotes();
}

/// Migration strategy to gradually move from dual to unified
class DualArchitectureMigration {
  /// Step 1: Replace conditional providers with unified providers
  static void replaceConditionalProviders() {
    // Instead of:
    // if (config.isFeatureEnabled('notes')) {
    //   return ref.watch(dualNotesPageProvider);
    // } else {
    //   return ref.watch(notesPageProvider);
    // }

    // Use:
    // return ref.watch(unifiedNotesProvider);
  }

  /// Step 2: Remove feature flags from codebase
  static void removeFeatureFlags() {
    // Remove all calls to config.isFeatureEnabled()
    // Remove MigrationConfig usage for feature toggles
  }

  /// Step 3: Consolidate duplicate providers
  static void consolidateDuplicateProviders() {
    // Remove:
    // - notesPageProvider
    // - dualNotesPageProvider
    // - conditionalNotesPageProvider

    // Keep only:
    // - unifiedNotesProvider
  }

  /// Step 4: Update UI components to use unified types
  static void updateUIComponents() {
    // Update all UI components to work with UnifiedNote
    // Remove type checks and casting
  }
}

/// Example of how to create a unified provider
final unifiedNotesProvider = StateNotifierProvider<UnifiedNotesNotifier, AsyncValue<UnifiedNotesPage>>((ref) {
  final repository = ref.watch(unifiedRepositoryProvider);
  return UnifiedNotesNotifier(repository);
});

class UnifiedNotesNotifier extends StateNotifier<AsyncValue<UnifiedNotesPage>> {
  final IUnifiedNotesRepository _repository;
  int _currentPage = 0;

  UnifiedNotesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.getNotes(
        page: 0,
        pageSize: 20,
      );
      _currentPage = 0;
      state = AsyncValue.data(page);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! AsyncData<UnifiedNotesPage>) return;
    if (!currentState.value.hasMore) return;

    try {
      final nextPage = await _repository.getNotes(
        page: _currentPage + 1,
        pageSize: 20,
      );
      _currentPage++;

      state = AsyncValue.data(UnifiedNotesPage(
        notes: [...currentState.value.notes, ...nextPage.notes],
        hasMore: nextPage.hasMore,
        currentPage: _currentPage,
      ));
    } catch (e, s) {
      // Keep existing data but show error
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> refresh() async {
    await _repository.refresh();
    await loadInitial();
  }
}

/// Unified repository provider that automatically selects the right implementation
final unifiedRepositoryProvider = Provider<IUnifiedNotesRepository>((ref) {
  // This provider always returns the same repository type
  // No more conditional logic needed
  return UnifiedNotesRepositoryImpl(ref);
});

class UnifiedNotesRepositoryImpl implements IUnifiedNotesRepository {
  final Ref _ref;

  UnifiedNotesRepositoryImpl(this._ref);

  @override
  Future<UnifiedNotesPage> getNotes({
    required int page,
    required int pageSize,
    String? folderId,
    String? searchQuery,
  }) async {
    // Implementation that works with your current data source
    // No more checking feature flags
    throw UnimplementedError('Implement based on your current architecture');
  }

  @override
  Future<void> createNote(UnifiedNote note) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateNote(UnifiedNote note) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNote(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {
    throw UnimplementedError();
  }

  @override
  Stream<List<UnifiedNote>> watchNotes() {
    throw UnimplementedError();
  }
}

/// Migration checklist:
///
/// 1. [ ] Create UnifiedNote adapter for your existing note types
/// 2. [ ] Implement IUnifiedNotesRepository with your current data layer
/// 3. [ ] Replace conditional providers one by one with unified providers
/// 4. [ ] Update UI components to use UnifiedNote instead of dynamic
/// 5. [ ] Remove feature flag checks from the codebase
/// 6. [ ] Delete old dual/conditional providers
/// 7. [ ] Remove MigrationConfig usage for feature toggles
/// 8. [ ] Update tests to work with unified architecture
///
/// Benefits after migration:
/// - 50% less code in providers
/// - No more runtime type checking
/// - Single source of truth for each feature
/// - Easier to understand and maintain
/// - Better type safety
/// - Improved performance (no conditional checks)