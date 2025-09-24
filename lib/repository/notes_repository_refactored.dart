import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/template_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;
import 'package:uuid/uuid.dart';

/// Refactored NotesRepository that delegates to specialized repositories
/// This maintains backward compatibility while implementing clean architecture
class NotesRepositoryRefactored extends NotesRepository {
  NotesRepositoryRefactored({
    required AppDb db,
    required CryptoBox crypto,
    required SupabaseNoteApi api,
    required SupabaseClient client,
    required NoteIndexer indexer,
  }) : super(
          db: db,
          crypto: crypto,
          api: api,
          client: client,
          indexer: indexer,
        ) {
    // Initialize the specialized repositories
    _notesCore = NotesCoreRepository(
      db: db,
      crypto: crypto,
      api: api,
      client: client,
      indexer: indexer,
    );
    _tags = TagRepository(db: db);
    _search = SearchRepository(db: db);
    _folders = FolderRepository(db: db, userId: client.auth.currentUser?.id ?? '');
    _templates = TemplateRepository(db: db) as ITemplateRepository;
  }

  final AppLogger _logger = LoggerFactory.instance;
  final _uuid = const Uuid();

  // Specialized repositories
  late final INotesRepository _notesCore;
  late final ITagRepository _tags;
  late final ISearchRepository _search;
  late final IFolderRepository _folders;
  late final ITemplateRepository _templates;


  // ----------------------
  // Delegate to SearchRepository
  // ----------------------
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch) =>
      _search.createOrUpdateSavedSearch(savedSearch);

  Future<void> deleteSavedSearch(String id) =>
      _search.deleteSavedSearch(id);

  Future<List<SavedSearch>> getSavedSearches() =>
      _search.getSavedSearches();

  Stream<List<SavedSearch>> watchSavedSearches() =>
      _search.watchSavedSearches();

  Future<void> toggleSavedSearchPin(String id) =>
      _search.toggleSavedSearchPin(id);

  Future<void> trackSavedSearchUsage(String id) =>
      _search.trackSavedSearchUsage(id);

  Future<void> reorderSavedSearches(List<String> ids) =>
      _search.reorderSavedSearches(ids);

  Future<List<LocalNote>> executeSavedSearch(SavedSearch savedSearch) =>
      _search.executeSavedSearch(savedSearch);

  // ----------------------
  // Delegate to TagRepository
  // ----------------------
  Future<List<TagCount>> listTagsWithCounts() =>
      _tags.listTagsWithCounts();

  Future<void> addTag({required String noteId, required String tag}) =>
      _tags.addTag(noteId: noteId, tag: tag);

  Future<void> removeTag({required String noteId, required String tag}) =>
      _tags.removeTag(noteId: noteId, tag: tag);

  @override
  Future<int> renameTagEverywhere({
    required String from,
    required String to,
  }) =>
      _tags.renameTagEverywhere(oldTag: from, newTag: to);

  Future<List<LocalNote>> queryNotesByTags({
    List<String> anyTags = const [],
    List<String> allTags = const [],
    List<String> noneTags = const [],
  }) =>
      _tags.queryNotesByTags(
        anyTags: anyTags,
        allTags: allTags,
        noneTags: noneTags,
      );

  Future<List<String>> searchTags(String prefix) =>
      _tags.searchTags(prefix);

  Future<List<String>> getTagsForNote(String noteId) =>
      _tags.getTagsForNote(noteId);

  // ----------------------
  // Delegate to NotesCoreRepository
  // ----------------------
  Future<LocalNote?> getLocalNoteById(String id) =>
      _notesCore.getNoteById(id);

  Future<LocalNote?> getNote(String id) => getLocalNoteById(id);

  Future<LocalNote?> getNoteById(String id) => getNote(id);

  Future<LocalNote?> createNote({
    required String title,
    required String body,
    String? folderId,
  }) =>
      _notesCore.createOrUpdate(
        title: title,
        body: body,
        folderId: folderId,
      );

  Future<LocalNote?> updateNote(
    String id, {
    required String title,
    required String body,
    String? folderId,
    bool? isPinned,
  }) =>
      _notesCore.createOrUpdate(
        id: id,
        title: title,
        body: body,
        folderId: folderId,
        isPinned: isPinned,
      );

  @override
  Future<LocalNote?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    Set<String> tags = const {},
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
  }) =>
      _notesCore.createOrUpdate(
        id: id,
        title: title,
        body: body,
        folderId: folderId,
        tags: tags.toList(),
        links: links,
        attachmentMeta: attachmentMeta,
        metadataJson: metadataJson,
        isPinned: isPinned,
      );

  Future<List<LocalNote>> getRecentlyViewedNotes({int limit = 5}) =>
      _notesCore.getRecentlyViewedNotes(limit: limit);

  Future<List<LocalNote>> localNotes() =>
      _notesCore.localNotes();

  Future<List<LocalNote>> listAfter(DateTime? cursor, {int limit = 20}) =>
      _notesCore.listAfter(cursor, limit: limit);

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
    Set<String>? tags,
  }) =>
      _notesCore.updateLocalNote(
        id,
        title: title,
        body: body,
        deleted: deleted,
        folderId: folderId,
        attachmentMeta: attachmentMeta,
        metadata: metadata,
        links: links,
        isPinned: isPinned,
      );

  Future<void> deleteNote(String id) => _notesCore.deleteNote(id);

  Future<void> delete(String id) => deleteNote(id);

  Future<void> toggleNotePin(String noteId) => _notesCore.toggleNotePin(noteId);

  Future<void> setNotePin(String noteId, bool isPinned) =>
      _notesCore.setNotePin(noteId, isPinned);

  Future<List<LocalNote>> getPinnedNotes() => _notesCore.getPinnedNotes();

  Future<List<LocalNote>> list({int? limit}) => _notesCore.list(limit: limit);

  @override
  Stream<List<LocalNote>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? allTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) =>
      _notesCore.watchNotes(
        folderId: folderId,
        anyTags: anyTags,
        noneTags: noneTags,
        pinnedFirst: pinnedFirst,
      );

  // ----------------------
  // Delegate to TemplateRepository
  // ----------------------
  Future<List<LocalNote>> listTemplates() => _templates.listTemplates();

  Future<LocalNote?> createTemplate({
    required String title,
    required String body,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  }) =>
      _templates.createTemplate(
        title: title,
        body: body,
        tags: tags,
        metadata: metadata,
      );

  Future<LocalNote?> createNoteFromTemplate(String templateId) =>
      _templates.createNoteFromTemplate(templateId);

  Future<bool> deleteTemplate(String templateId) =>
      _templates.deleteTemplate(templateId);

  // ----------------------
  // Delegate to FolderRepository
  // ----------------------
  Future<LocalFolder?> getFolder(String id) => _folders.getFolder(id);

  Future<List<LocalFolder>> listFolders() => _folders.listFolders();

  Future<List<LocalFolder>> getRootFolders() => _folders.getRootFolders();

  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) =>
      _folders.createOrUpdateFolder(
        name: name,
        id: id,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
        sortOrder: sortOrder,
      );

  Future<LocalFolder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) =>
      _folders.createFolder(
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
      );

  Future<void> renameFolder(String folderId, String newName) =>
      _folders.renameFolder(folderId, newName);

  Future<void> moveFolder(String folderId, String? newParentId) =>
      _folders.moveFolder(folderId, newParentId);

  Future<void> deleteFolder(String folderId) =>
      _folders.deleteFolder(folderId);

  Future<List<LocalNote>> getNotesInFolder(String folderId) =>
      _folders.getNotesInFolder(folderId);

  Future<List<LocalNote>> getUnfiledNotes() => _folders.getUnfiledNotes();

  Future<void> addNoteToFolder(String noteId, String folderId) =>
      _folders.addNoteToFolder(noteId, folderId);

  Future<void> moveNoteToFolder(String noteId, String? folderId) =>
      _folders.moveNoteToFolder(noteId, folderId);

  Future<void> removeNoteFromFolder(String noteId) =>
      _folders.removeNoteFromFolder(noteId);

  Future<Map<String, int>> getFolderNoteCounts() =>
      _folders.getFolderNoteCounts();

  Future<void> ensureFolderIntegrity() => _folders.ensureFolderIntegrity();

  Future<LocalFolder?> getFolderForNote(String noteId) =>
      _folders.getFolderForNote(noteId);

  Future<Map<String, dynamic>> performFolderHealthCheck() =>
      _folders.performFolderHealthCheck();

  Future<void> validateAndRepairFolderStructure() =>
      _folders.validateAndRepairFolderStructure();

  Future<void> cleanupOrphanedRelationships() =>
      _folders.cleanupOrphanedRelationships();

  Future<void> resolveFolderConflicts() =>
      _folders.resolveFolderConflicts();

  Future<List<LocalFolder>> getChildFolders(String parentId) =>
      _folders.getChildFolders(parentId);

  Future<List<LocalFolder>> getChildFoldersRecursive(String parentId) =>
      _folders.getChildFoldersRecursive(parentId);

  // ----------------------
  // Sync operations - delegate to NotesCoreRepository
  // ----------------------
  Future<void> pushAllPending() => _notesCore.pushAllPending();

  Future<void> pullSince(DateTime? since) => _notesCore.pullSince(since);

  Future<void> sync() => _notesCore.sync();

  Future<DateTime?> getLastSyncTime() => _notesCore.getLastSyncTime();

  Future<Set<String>> fetchRemoteActiveIds() async {
    // Implementation needed - this would query the remote server
    _logger.info('Fetching remote active IDs');
    return <String>{};
  }

  Future<void> reconcileHardDeletes(Set<String> remoteIds) async {
    // Implementation needed - this would reconcile local and remote deletes
    _logger.info('Reconciling hard deletes');
  }

  Future<void> reconcile() async {
    final remoteIds = await fetchRemoteActiveIds();
    await reconcileHardDeletes(remoteIds);
  }

  // Private helper methods for sync
  Future<void> _pullFolders(DateTime? since) async {
    // Implementation needed - this would pull folder changes from remote
    _logger.info('Pulling folders since $since');
  }

  Future<Set<String>> _getNoteTags(String noteId) async {
    final tags = await getTagsForNote(noteId);
    return tags.toSet();
  }

  Future<List<NoteLink>> _getNoteLinks(String noteId) async {
    // Implementation needed
    return [];
  }
}