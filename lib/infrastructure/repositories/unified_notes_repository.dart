// Unified Notes Repository that eliminates dual architecture
// Works with UnifiedNote type to provide consistent interface

import 'dart:convert';

import 'package:duru_notes/core/models/unified_note.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/optimized_notes_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified repository that provides a single interface for notes
/// No more conditional logic or feature flags
class UnifiedNotesRepository implements INotesRepository {
  final AppDb db;
  final SupabaseClient? client;
  final NotesCoreRepository _coreRepository;
  final OptimizedNotesRepository _optimizedRepository;

  UnifiedNotesRepository({
    required this.db,
    this.client,
  })  : _coreRepository = NotesCoreRepository(
          db: db,
          api: null, // Will be initialized if client is available
          crypto: null, // Will be initialized if client is available
          indexer: null, // Will be initialized if client is available
        ),
        _optimizedRepository = OptimizedNotesRepository(db: db);

  /// Get notes with pagination - returns UnifiedNotesPage
  Future<UnifiedNotesPage> getNotesPage({
    required int page,
    required int pageSize,
    String? folderId,
    String? searchQuery,
  }) async {
    try {
      // Use optimized repository for fast queries
      final notes = await _optimizedRepository.getPaginated(
        page: page,
        pageSize: pageSize,
        folderId: folderId,
      );

      // Convert to UnifiedNotes
      final unifiedNotes = notes.map((n) => UnifiedNote.from(n)).toList();

      // Check if there are more notes
      final totalCount = await _optimizedRepository.getCount(
        folderId: folderId,
      );
      final hasMore = (page + 1) * pageSize < totalCount;

      return UnifiedNotesPage(
        notes: unifiedNotes,
        hasMore: hasMore,
        currentPage: page,
        totalCount: totalCount,
      );
    } catch (e) {
      // Fallback to core repository if optimized fails
      return _getNotesPageFromCore(
        page: page,
        pageSize: pageSize,
        folderId: folderId,
      );
    }
  }

  Future<UnifiedNotesPage> _getNotesPageFromCore({
    required int page,
    required int pageSize,
    String? folderId,
    String? searchQuery,
  }) async {
    final allNotes = await _coreRepository.listNotes();

    // Filter by folder if needed
    final filteredNotes = folderId != null
        ? allNotes.where((n) => n.folderId == folderId).toList()
        : allNotes;

    // Apply pagination manually
    final startIndex = page * pageSize;
    final endIndex = (page + 1) * pageSize;
    final paginatedNotes = filteredNotes.skip(startIndex).take(pageSize).toList();

    // Convert to UnifiedNotes
    final unifiedNotes = paginatedNotes.map((n) => UnifiedNote.from(n)).toList();

    return UnifiedNotesPage(
      notes: unifiedNotes,
      hasMore: endIndex < filteredNotes.length,
      currentPage: page,
      totalCount: filteredNotes.length,
    );
  }

  Future<domain.Note> createNote(domain.Note note) async {
    final id = await _coreRepository.createNote(note);
    final created = await _coreRepository.getNoteById(id);
    return created!;
  }

  Future<domain.Note> updateNote(domain.Note note) async {
    final id = await _coreRepository.updateNote(note);
    final updated = await _coreRepository.getNoteById(id);
    return updated!;
  }

  @override
  Future<void> deleteNote(String id) async {
    await _coreRepository.deleteNote(id);
  }

  @override
  Future<domain.Note?> getNoteById(String id) async {
    return await _coreRepository.getNoteById(id);
  }

  @override
  Future<domain.Note?> getById(String id) async {
    return await getNoteById(id);
  }

  Future<List<domain.Note>> listNotes({
    String? folderId,
    String? searchQuery,
  }) async {
    // Get all notes first
    final allNotes = await _coreRepository.listNotes();

    // Filter by folder if needed
    var filteredNotes = allNotes;
    if (folderId != null) {
      filteredNotes = filteredNotes.where((n) => n.folderId == folderId).toList();
    }

    // Filter by search query if needed
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredNotes = filteredNotes.where((n) =>
        (n.title?.toLowerCase().contains(query) ?? false) ||
        (n.body?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filteredNotes;
  }

  Future<List<domain.Note>> searchNotes(String query) async {
    return await _coreRepository.searchNotes(query);
  }

  @override
  Future<List<domain.Note>> search(String query) async {
    return await searchNotes(query);
  }

  Future<void> syncNotes() async {
    await _coreRepository.syncNotes();
  }

  @override
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
  }) async {
    final note = await getNoteById(id);
    if (note != null) {
      final updated = note.copyWith(
        title: title ?? note.title,
        body: body ?? note.body,
        folderId: folderId ?? note.folderId,
        isPinned: isPinned ?? note.isPinned,
        deleted: deleted ?? note.deleted,
        metadata: (metadata != null ? jsonEncode(metadata) : note.metadata) as String?,
        attachmentMeta: (attachmentMeta != null ? jsonEncode(attachmentMeta) : note.attachmentMeta) as String?,
      );
      await updateNote(updated);
    }
  }

  @override
  Future<List<domain.Note>> localNotes() async {
    return await listNotes();
  }

  @override
  Future<List<domain.Note>> getAll() async {
    // Alias for localNotes
    return localNotes();
  }

  @override
  Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
    final notes = await listNotes();
    // Sort by updatedAt and take limit
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes.take(limit).toList();
  }

  @override
  Future<List<domain.Note>> listAfter(DateTime? cursor, {int limit = 20}) async {
    final notes = await listNotes();
    if (cursor != null) {
      return notes
          .where((n) => n.updatedAt.isAfter(cursor))
          .take(limit)
          .toList();
    }
    return notes.take(limit).toList();
  }

  @override
  Future<void> toggleNotePin(String noteId) async {
    final note = await getNoteById(noteId);
    if (note != null) {
      await setNotePin(noteId, !note.isPinned);
    }
  }

  @override
  Future<void> setNotePin(String noteId, bool isPinned) async {
    await updateLocalNote(noteId, isPinned: isPinned);
  }

  @override
  Future<List<domain.Note>> getPinnedNotes() async {
    final notes = await listNotes();
    return notes.where((n) => n.isPinned).toList();
  }

  @override
  Future<List<domain.Note>> list({int? limit}) async {
    final notes = await listNotes();
    if (limit != null) {
      return notes.take(limit).toList();
    }
    return notes;
  }

  @override
  Future<String> createOrUpdate(domain.Note note) async {
    final existing = await getNoteById(note.id);
    if (existing != null) {
      await updateNote(note);
    } else {
      await createNote(note);
    }
    return note.id;
  }

  @override
  Future<void> sync() async {
    await syncNotes();
  }

  @override
  Future<void> pushAllPending() async {
    // Implement push logic if needed
    await syncNotes();
  }

  @override
  Future<void> pullSince(DateTime? since) async {
    // Implement pull logic if needed
    await syncNotes();
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    // Return last sync time - for now return current time
    return DateTime.now();
  }

  /// Get all notes as UnifiedNotes
  Future<List<UnifiedNote>> getAllUnified() async {
    final notes = await listNotes();
    return notes.map((n) => UnifiedNote.from(n)).toList();
  }

  /// Get notes in folder as UnifiedNotes
  Future<List<UnifiedNote>> getNotesInFolder(String folderId) async {
    final notes = await listNotes(folderId: folderId);
    return notes.map((n) => UnifiedNote.from(n)).toList();
  }

  /// Search notes and return as UnifiedNotes
  Future<List<UnifiedNote>> searchUnified(String query) async {
    final notes = await searchNotes(query);
    return notes.map((n) => UnifiedNote.from(n)).toList();
  }

  /// Create note from UnifiedNote
  Future<UnifiedNote> createUnified(UnifiedNote note) async {
    final domainNote = note.toDomain();
    final created = await createNote(domainNote);
    return UnifiedNote.from(created);
  }

  /// Update note from UnifiedNote
  Future<UnifiedNote> updateUnified(UnifiedNote note) async {
    final domainNote = note.toDomain();
    final updated = await updateNote(domainNote);
    return UnifiedNote.from(updated);
  }

  /// Batch operations for performance
  Future<List<UnifiedNote>> batchCreate(List<UnifiedNote> notes) async {
    final results = <UnifiedNote>[];
    for (final note in notes) {
      final created = await createUnified(note);
      results.add(created);
    }
    return results;
  }

  Future<void> batchDelete(List<String> ids) async {
    for (final id in ids) {
      await deleteNote(id);
    }
  }

  /// Stream for watching notes
  @override
  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await listNotes(
        folderId: folderId,
        searchQuery: null,
      ),
    ).asyncMap((future) => future);
  }

  /// Stream for watching notes in folder - returns UnifiedNote for internal use
  Stream<List<UnifiedNote>> watchNotesInFolderUnified(String folderId) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getNotesInFolder(folderId),
    ).asyncMap((future) => future);
  }

  /// Stream for watching all notes as UnifiedNote - for internal use
  Stream<List<UnifiedNote>> watchNotesUnified() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getAllUnified(),
    ).asyncMap((future) => future);
  }
}