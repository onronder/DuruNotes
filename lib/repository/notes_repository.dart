import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required this.db,
    required this.crypto,
    required this.api,
    required SupabaseClient client,
    required NoteIndexer indexer,
  }) : _supabase = client,
       _indexer = indexer;

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseNoteApi api;
  final SupabaseClient _supabase;
  final NoteIndexer _indexer;
  final _uuid = const Uuid();

  // Expose client for compatibility
  SupabaseClient get client => _supabase;

  // ----------------------
  // Saved Searches Management
  // ----------------------

  /// Create or update a saved search
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch) async {
    await db.upsertSavedSearch(savedSearch);
    // Enqueue for sync
    await db.enqueue(
      savedSearch.id,
      'upsert_saved_search',
      payload: jsonEncode(savedSearch.toJson()),
    );
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String id) async {
    await db.deleteSavedSearch(id);
    // Enqueue for sync
    await db.enqueue(id, 'delete_saved_search');
  }

  /// Get all saved searches
  Future<List<SavedSearch>> getSavedSearches() => db.getSavedSearches();

  /// Watch saved searches
  Stream<List<SavedSearch>> watchSavedSearches() => db.watchSavedSearches();

  /// Toggle saved search pin status
  Future<void> toggleSavedSearchPin(String id) => db.toggleSavedSearchPin(id);

  /// Track saved search usage
  Future<void> trackSavedSearchUsage(String id) =>
      db.updateSavedSearchUsage(id);

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> ids) =>
      db.reorderSavedSearches(ids);

  /// Execute a saved search
  Future<List<LocalNote>> executeSavedSearch(SavedSearch savedSearch) async {
    // Parse the saved search query
    final query = savedSearch.query;
    final searchType = savedSearch.searchType;

    // Parse parameters JSON if present
    Map<String, dynamic>? params;
    if (savedSearch.parameters != null) {
      try {
        params = jsonDecode(savedSearch.parameters!) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to parse saved search parameters: $e');
      }
    }

    // Execute based on search type
    switch (searchType) {
      case 'text':
        return db.searchNotes(query);
      case 'tags':
        final tags = (params?['tags'] as List?)?.cast<String>() ?? [];
        return db.notesByTags(
          anyTags: tags,
          noneTags: [],
          sort: const SortSpec(),
        );
      case 'folder':
        final folderId = params?['folderId'] as String?;
        if (folderId != null) {
          return getNotesInFolder(folderId);
        }
        return [];
      case 'compound':
        // Complex search with multiple filters
        return db.searchNotes(query);
      default:
        return [];
    }
  }

  // ----------------------
  // Pinned Notes Management
  // ----------------------

  /// Toggle note pin status
  Future<void> toggleNotePin(String noteId) => db.toggleNotePin(noteId);

  /// Set note pin status
  Future<void> setNotePin(String noteId, bool isPinned) =>
      db.setNotePin(noteId, isPinned);

  /// Get pinned notes
  Future<List<LocalNote>> getPinnedNotes() => db.getPinnedNotes();

  // ----------------------
  // Tag Management
  // ----------------------

  /// List tags with counts (for TagsScreen & autocomplete)
  Future<List<TagCount>> listTagsWithCounts() => db.getTagsWithCounts();

  /// Add tag to a note (enqueue offline ops)
  Future<void> addTag({required String noteId, required String tag}) async {
    final norm = tag.trim().toLowerCase();
    await db.addTagToNote(noteId, norm);
    await db.enqueue(
      '$noteId::$norm',
      'upsert_note_tag',
      payload: jsonEncode({'note_id': noteId, 'tag': norm}),
    );
  }

  /// Remove tag from a note
  Future<void> removeTag({required String noteId, required String tag}) async {
    final norm = tag.trim().toLowerCase();
    await db.removeTagFromNote(noteId, norm);
    await db.enqueue(
      '$noteId::$norm',
      'delete_note_tag',
      payload: jsonEncode({'note_id': noteId, 'tag': norm}),
    );
  }

  /// Bulk rename/merge tag across all notes (Optional admin tool)
  Future<int> renameTagEverywhere({
    required String from,
    required String to,
  }) async {
    final cnt = await db.renameTagEverywhere(from, to);
    // optional: enqueue global op if your server supports it
    await db.enqueue(
      'tag::${from.trim().toLowerCase()}',
      'rename_tag',
      payload: jsonEncode({
        'from': from.trim().toLowerCase(),
        'to': to.trim().toLowerCase(),
      }),
    );
    return cnt;
  }

  /// Query notes by tags (union + exclude)
  Future<List<LocalNote>> queryNotesByTags({
    required List<String> anyTags,
    required SortSpec sort,
    List<String> noneTags = const [],
  }) =>
      db.notesByTags(anyTags: anyTags, noneTags: noneTags, sort: sort);

  /// Search tags for autocomplete
  Future<List<String>> searchTags(String prefix) => db.searchTags(prefix);

  /// Get tags for a specific note
  Future<List<String>> getTagsForNote(String noteId) async {
    final tags = await (db.select(
      db.noteTags,
    )..where((t) => t.noteId.equals(noteId)))
        .get();
    return tags.map((t) => t.tag).toList();
  }

  // ----------------------
  // Note Management
  // ----------------------

  Future<LocalNote?> getLocalNoteById(String id) async {
    return (db.select(
      db.localNotes,
    )..where((note) => note.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a note by ID (compatibility method)
  Future<LocalNote?> getNote(String id) => getLocalNoteById(id);

  /// Get a note by ID (alias for getNote)
  Future<LocalNote?> getNoteById(String id) => getNote(id);

  /// Create a new note
  Future<LocalNote?> createNote({
    required String title,
    required String body,
    String? folderId,
  }) async {
    return createOrUpdate(title: title, body: body);
  }

  /// Update an existing note
  Future<LocalNote?> updateNote(
    String id, {
    required String title,
    required String body,
  }) async {
    return createOrUpdate(id: id, title: title, body: body);
  }

  Future<LocalNote?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    DateTime? updatedAt,
    Set<String> tags = const {},
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
  }) async {
    id ??= _uuid.v4();
    updatedAt ??= DateTime.now();

    // Merge attachmentMeta and metadataJson
    final metadata = <String, dynamic>{};
    if (attachmentMeta != null) {
      metadata.addAll(attachmentMeta);
    }
    if (metadataJson != null) {
      metadata.addAll(metadataJson);
    }

    // CRITICAL FIX: Preserve existing pin state if not explicitly provided
    var finalPinState = isPinned ?? false;
    if (isPinned == null) {
      // Check if this is an update to an existing note
      final existingNote = await db.findNote(id);
      if (existingNote != null) {
        // Preserve the existing pin state
        finalPinState = existingNote.isPinned;
      }
    }

    final note = LocalNote(
      id: id,
      title: title,
      body: body,
      updatedAt: updatedAt,
      deleted: false,
      encryptedMetadata: metadata.isNotEmpty ? jsonEncode(metadata) : null,
      isPinned: finalPinState,
      noteType: NoteKind.note, // Regular note, not a template
    );

    await db.upsertNote(note);
    await db.replaceTagsForNote(id, tags);
    await db.replaceLinksForNote(id, links);

    // Reindex for search
    await _indexer.indexNote(note);

    // Enqueue the pending operation for sync
    await db.enqueue(id, 'upsert_note');

    return note;
  }

  Future<List<LocalNote>> getRecentlyViewedNotes({int limit = 5}) async {
    return (db.select(db.localNotes)
          ..where((n) =>
              n.deleted.equals(false) &
              n.noteType.equals(0)) // Filter out templates
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<LocalNote>> localNotes() async {
    return (db.select(db.localNotes)
          ..where((note) =>
              note.deleted.equals(false) &
              note.noteType.equals(0)) // Filter out templates
          ..orderBy([
            // Order by pin status first (pinned notes at top)
            (note) => OrderingTerm.desc(note.isPinned),
            // Then by update time
            (note) => OrderingTerm.desc(note.updatedAt),
          ]))
        .get();
  }

  /// List notes with pagination (compatibility method)
  /// FIXED: Now respects pin ordering - pinned notes always appear first
  Future<List<LocalNote>> listAfter(DateTime? cursor, {int limit = 20}) async {
    final query = db.select(db.localNotes)
      ..where((n) =>
          n.deleted.equals(false) &
          n.noteType.equals(0)); // Filter out templates

    if (cursor != null) {
      query.where((n) => n.updatedAt.isSmallerThanValue(cursor));
    }

    query
      ..orderBy([
        // CRITICAL: Order by pin status first (pinned notes at top)
        (n) => OrderingTerm.desc(n.isPinned),
        // Then by update time
        (n) => OrderingTerm.desc(n.updatedAt),
      ])
      ..limit(limit);

    return query.get();
  }

  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    DateTime? updatedAt,
    Map<String, dynamic>? attachmentMeta,
    Set<String>? tags,
    List<Map<String, String?>>? links,
    bool? isPinned,
  }) async {
    // First, get the existing note
    final existing = await (db.select(
      db.localNotes,
    )..where((note) => note.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      return;
    }

    // Update the note with provided values
    final updated = existing.copyWith(
      title: title ?? existing.title,
      body: body ?? existing.body,
      deleted: deleted ?? existing.deleted,
      updatedAt: updatedAt ?? DateTime.now(),
      encryptedMetadata: Value(
        attachmentMeta != null
            ? jsonEncode(attachmentMeta)
            : existing.encryptedMetadata,
      ),
      isPinned: isPinned ?? existing.isPinned,
    );

    await db.upsertNote(updated);

    // Update tags if provided
    if (tags != null) {
      await db.replaceTagsForNote(id, tags);
    }

    // Update links if provided
    if (links != null) {
      await db.replaceLinksForNote(id, links);
    }

    // Reindex for search
    await _indexer.indexNote(updated);

    // Enqueue the pending operation for sync
    await db.enqueue(id, deleted ?? false ? 'delete_note' : 'upsert_note');
  }

  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

  /// Delete method (compatibility)
  Future<void> delete(String id) => deleteNote(id);

  // ----------------------
  // Template Management
  // ----------------------

  /// List all templates (notes with noteType = NoteKind.template)
  Future<List<LocalNote>> listTemplates() async {
    return (db.select(db.localNotes)
          ..where((t) => t.deleted.equals(false) & t.noteType.equals(1))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Create a new template with offline-first pattern
  Future<LocalNote?> createTemplate({
    required String title,
    required String body,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      debugPrint('🔄 Creating template: "$title"');

      final template = LocalNote(
        id: id,
        title: title,
        body: body,
        noteType: NoteKind.template, // Use enum value
        deleted: false,
        isPinned: false,
        updatedAt: now,
        encryptedMetadata: metadata != null ? jsonEncode(metadata) : null,
      );

      await db.upsertNote(template);
      if (tags.isNotEmpty) {
        await db.replaceTagsForNote(id, tags.toSet());
      }
      await db.enqueue(id, 'upsert_note');

      debugPrint('✅ Template created locally: $id');
      return template;
    } catch (e, stackTrace) {
      // Use AppLogger for proper error tracking
      final logger = LoggerFactory.instance;
      logger.error('Failed to create template',
          error: e,
          stackTrace: stackTrace,
          data: {
            'title': title,
            'bodyLength': body.length,
            'tagsCount': tags.length,
            'hasMetadata': metadata != null,
          });

      debugPrint('❌ Failed to create template: $e');
      return null;
    }
  }

  /// Create a new note from a template with metadata tracking
  Future<LocalNote?> createNoteFromTemplate(String templateId) async {
    try {
      debugPrint('🔄 Creating note from template: $templateId');

      final template = await getNote(templateId);
      if (template == null || template.noteType != NoteKind.template) {
        throw StateError('Template not found: $templateId');
      }

      final tags = await getTagsForNote(templateId);
      final newId = _uuid.v4();
      final now = DateTime.now();

      final metadata = {
        'source': 'template',
        'sourceTemplateId': templateId,
        'sourceTemplateTitle': template.title,
      };

      final note = LocalNote(
        id: newId,
        title: template.title,
        body: template.body,
        noteType: NoteKind.note, // Use enum value
        deleted: false,
        isPinned: false,
        updatedAt: now,
        encryptedMetadata: jsonEncode(metadata),
      );

      await db.upsertNote(note);
      if (tags.isNotEmpty) {
        await db.replaceTagsForNote(newId, tags.toSet());
      }
      await db.enqueue(newId, 'upsert_note');

      debugPrint('✅ Note created from template: $newId');
      return note;
    } catch (e, stackTrace) {
      // Use AppLogger for proper error tracking
      final logger = LoggerFactory.instance;
      logger.error('Failed to create note from template',
          error: e,
          stackTrace: stackTrace,
          data: {
            'templateId': templateId,
            'errorType': e.runtimeType.toString(),
          });

      debugPrint('❌ Failed to create note from template: $e');
      return null;
    }
  }

  /// Delete a template (soft delete with sync)
  Future<bool> deleteTemplate(String templateId) async {
    try {
      debugPrint('🗑️ Deleting template: $templateId');

      // Verify it's actually a template
      final template = await getNote(templateId);
      if (template == null || template.noteType != NoteKind.template) {
        throw StateError('Not a template: $templateId');
      }

      // Mark as deleted locally (soft delete)
      await updateLocalNote(templateId, deleted: true);

      // Queue for remote deletion
      await db.enqueue(templateId, 'delete_note');

      debugPrint('✅ Template deleted: $templateId');
      return true;
    } catch (e, stackTrace) {
      final logger = LoggerFactory.instance;
      logger.error('Failed to delete template',
          error: e,
          stackTrace: stackTrace,
          data: {
            'templateId': templateId,
          });

      debugPrint('❌ Failed to delete template: $e');
      return false;
    }
  }

  // ----------------------
  // Folder Management (Delegating to FolderRepository patterns)
  // ----------------------

  /// Get folder by ID
  Future<LocalFolder?> getFolder(String id) async {
    return (db.select(
      db.localFolders,
    )..where((f) => f.id.equals(id)))
        .getSingleOrNull();
  }

  /// List all folders
  Future<List<LocalFolder>> listFolders() async {
    return (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.path)]))
        .get();
  }

  /// Get root folders
  Future<List<LocalFolder>> getRootFolders() async {
    return (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.parentId.isNull())
          ..orderBy([
            (f) => OrderingTerm.asc(f.sortOrder),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .get();
  }

  /// Create or update folder
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    id ??= _uuid.v4();

    final folder = LocalFolder(
      id: id,
      name: name,
      parentId: parentId,
      path: '', // Will be computed by triggers
      sortOrder: sortOrder ?? 0,
      color: color,
      icon: icon,
      description: description ?? '',
      deleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await db.upsertFolder(folder);
    await db.enqueue(id, 'upsert_folder');

    return id;
  }

  /// Create folder (compatibility)
  Future<LocalFolder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final id = await createOrUpdateFolder(
      name: name,
      parentId: parentId,
      color: color,
      icon: icon,
      description: description,
    );

    return (await getFolder(id))!;
  }

  /// Rename folder
  Future<void> renameFolder(String folderId, String newName) async {
    final folder = await getFolder(folderId);
    if (folder == null) return;

    await db.upsertFolder(
      folder.copyWith(name: newName, updatedAt: DateTime.now()),
    );

    await db.enqueue(folderId, 'upsert_folder');
  }

  /// Move folder
  Future<void> moveFolder(String folderId, String? newParentId) async {
    final folder = await getFolder(folderId);
    if (folder == null) return;

    await db.upsertFolder(
      folder.copyWith(parentId: Value(newParentId), updatedAt: DateTime.now()),
    );

    await db.enqueue(folderId, 'upsert_folder');
  }

  /// Delete folder (soft delete)
  Future<void> deleteFolder(String folderId) async {
    final folder = await getFolder(folderId);
    if (folder == null) return;

    // Mark folder as deleted
    await db.upsertFolder(
      folder.copyWith(deleted: true, updatedAt: DateTime.now()),
    );

    // Move notes to inbox (null folder)
    final notesInFolder = await getNotesInFolder(folderId);
    for (final note in notesInFolder) {
      await moveNoteToFolder(note.id, null);
    }

    await db.enqueue(folderId, 'delete_folder');
  }

  /// Get notes in folder
  Future<List<LocalNote>> getNotesInFolder(String folderId) async {
    return db.getNotesInFolder(folderId);
  }

  /// Get unfiled notes
  Future<List<LocalNote>> getUnfiledNotes() async {
    final query = db.select(db.localNotes).join([
      leftOuterJoin(
        db.noteFolders,
        db.noteFolders.noteId.equalsExp(db.localNotes.id),
      ),
    ])
      ..where(db.localNotes.deleted.equals(false) &
          db.localNotes.noteType.equals(0)) // Filter out templates
      ..where(db.noteFolders.noteId.isNull());

    return query.map((row) => row.readTable(db.localNotes)).get();
  }

  /// Add note to folder
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    await db.moveNoteToFolder(noteId, folderId);

    // Don't update timestamp for folder changes - just sync the folder association
    await db.enqueue(noteId, 'note_folder_change');
  }

  /// Move note to folder
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    await db.moveNoteToFolder(noteId, folderId);

    // Don't update timestamp for folder changes - just sync the folder association
    await db.enqueue(noteId, 'note_folder_change');
  }

  /// Remove note from folder
  Future<void> removeNoteFromFolder(String noteId) async {
    await moveNoteToFolder(noteId, null);
  }

  /// Fetch aggregated note counts for folders
  Future<Map<String, int>> getFolderNoteCounts() async {
    return db.getFolderNoteCounts();
  }

  /// Repair orphaned folder relationships if any exist
  Future<void> ensureFolderIntegrity() async {
    await db.cleanupOrphanedRelationships();
  }

  /// Get folder for note
  Future<LocalFolder?> getFolderForNote(String noteId) async {
    final relation = await (db.select(
      db.noteFolders,
    )..where((nf) => nf.noteId.equals(noteId)))
        .getSingleOrNull();

    if (relation == null) return null;

    return getFolder(relation.folderId);
  }

  // ----------------------
  // Folder Health Check (Compatibility)
  // ----------------------

  Future<Map<String, dynamic>> performFolderHealthCheck() async {
    final issues = <String, List<String>>{};

    // Check for orphaned folders
    final folders = await listFolders();
    for (final folder in folders) {
      if (folder.parentId != null) {
        final parent = await getFolder(folder.parentId!);
        if (parent == null) {
          issues.putIfAbsent('orphaned_folders', () => []).add(folder.id);
        }
      }
    }

    // Check for orphaned note-folder relations
    final relations = await db.select(db.noteFolders).get();
    for (final rel in relations) {
      final note = await getNote(rel.noteId);
      final folder = await getFolder(rel.folderId);
      if (note == null) {
        issues.putIfAbsent('orphaned_note_relations', () => []).add(rel.noteId);
      }
      if (folder == null) {
        issues
            .putIfAbsent('orphaned_folder_relations', () => [])
            .add(rel.folderId);
      }
    }

    return {
      'healthy': issues.isEmpty,
      'issues': issues,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> validateAndRepairFolderStructure() async {
    // Implementation placeholder - could fix orphaned folders
    debugPrint('Validating folder structure...');
  }

  Future<void> cleanupOrphanedRelationships() async {
    // Remove orphaned note-folder relationships
    final relations = await db.select(db.noteFolders).get();
    for (final rel in relations) {
      final note = await getNote(rel.noteId);
      final folder = await getFolder(rel.folderId);

      if (note == null || folder == null) {
        await (db.delete(db.noteFolders)
              ..where((nf) => nf.noteId.equals(rel.noteId))
              ..where((nf) => nf.folderId.equals(rel.folderId)))
            .go();
        debugPrint(
          'Removed orphaned relation: ${rel.noteId} -> ${rel.folderId}',
        );
      }
    }
  }

  /// Resolve folder conflicts (compatibility)
  Future<void> resolveFolderConflicts() async {
    debugPrint('Resolving folder conflicts...');
    // Implementation placeholder
  }

  /// Get child folders
  Future<List<LocalFolder>> getChildFolders(String parentId) async {
    return (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.parentId.equals(parentId))
          ..orderBy([
            (f) => OrderingTerm.asc(f.sortOrder),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .get();
  }

  /// List all notes (compatibility)
  Future<List<LocalNote>> list({int? limit}) async {
    final query = db.select(db.localNotes)
      ..where((n) =>
          n.deleted.equals(false) &
          n.noteType.equals(0)) // Filter out templates
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  // ----------------------
  // Sync Methods
  // ----------------------

  /// Watch notes with filters and sorting
  Stream<List<LocalNote>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
    SortSpec? sort,
  }) {
    final query = db.select(db.localNotes)
      ..where((note) =>
          note.deleted.equals(false) &
          note.noteType.equals(0)); // Filter out templates

    // Handle folder filter
    if (folderId != null && folderId.isNotEmpty) {
      // Join with note_folders to filter by folder
      final subQuery = db.selectOnly(db.noteFolders)
        ..where(db.noteFolders.folderId.equals(folderId))
        ..addColumns([db.noteFolders.noteId]);
      query.where((note) => note.id.isInQuery(subQuery));
    } else if (folderId == '') {
      // Empty string means unfiled notes
      final subQuery = db.selectOnly(db.noteFolders)
        ..addColumns([db.noteFolders.noteId]);
      query.where((note) => note.id.isNotInQuery(subQuery));
    }

    // Handle tag filters
    if (anyTags != null && anyTags.isNotEmpty) {
      final normalizedTags =
          anyTags.map((t) => t.trim().toLowerCase()).toList();
      final tagSubQuery = db.selectOnly(db.noteTags)
        ..where(db.noteTags.tag.isIn(normalizedTags))
        ..addColumns([db.noteTags.noteId]);
      query.where((note) => note.id.isInQuery(tagSubQuery));
    }

    if (noneTags != null && noneTags.isNotEmpty) {
      final normalizedTags =
          noneTags.map((t) => t.trim().toLowerCase()).toList();
      final excludeSubQuery = db.selectOnly(db.noteTags)
        ..where(db.noteTags.tag.isIn(normalizedTags))
        ..addColumns([db.noteTags.noteId]);
      query.where((note) => note.id.isNotInQuery(excludeSubQuery));
    }

    // Apply sorting
    final sortSpec = sort ?? const SortSpec();

    // Apply sorting with pinned first if enabled
    query.orderBy([
      if (pinnedFirst)
        (note) =>
            OrderingTerm(expression: note.isPinned, mode: OrderingMode.desc),
      // Apply primary sort
      (note) {
        switch (sortSpec.sortBy) {
          case SortBy.title:
            return OrderingTerm(
              expression: note.title,
              mode: sortSpec.ascending ? OrderingMode.asc : OrderingMode.desc,
            );
          case SortBy.createdAt:
          case SortBy.updatedAt:
          default:
            return OrderingTerm(
              expression: note.updatedAt,
              mode: sortSpec.ascending ? OrderingMode.asc : OrderingMode.desc,
            );
        }
      },
    ]);

    return query.watch();
  }

  Future<void> pushAllPending() async {
    final ops = await db.getPendingOps();
    final processedIds = <int>[];

    debugPrint('📤 Processing ${ops.length} pending operations...');

    for (final op in ops) {
      try {
        if (op.kind == 'upsert_note') {
          final n = await (db.select(
            db.localNotes,
          )..where((t) => t.id.equals(op.entityId)))
              .getSingleOrNull();

          if (n == null) {
            processedIds.add(op.id);
            continue;
          }

          final tagsSet = await _getNoteTags(n.id);
          final linksList = await _getNoteLinks(n.id);

          // Encrypt using JSON methods
          final encryptedTitle = await crypto.encryptJsonForNote(
            userId: _supabase.auth.currentUser!.id,
            noteId: n.id,
            json: {'title': n.title},
          );

          final propsJson = <String, dynamic>{
            'body': n.body,
            'tags': tagsSet.toList(),
            'links': linksList
                .map((l) => {'title': l.targetTitle, 'id': l.targetId})
                .toList(),
            'isPinned': n.isPinned,
            'updatedAt': n.updatedAt.toIso8601String(),
            // Add noteType for template support
            'noteType': n.noteType == NoteKind.template ? 'template' : 'note',
          };

          if (n.encryptedMetadata != null) {
            try {
              final meta =
                  jsonDecode(n.encryptedMetadata!) as Map<String, dynamic>;
              propsJson.addAll(meta);
            } catch (e) {
              // Ignore parsing errors
            }
          }

          final encryptedProps = await crypto.encryptJsonForNote(
            userId: _supabase.auth.currentUser!.id,
            noteId: n.id,
            json: propsJson,
          );

          // Call the push API
          await api.upsertEncryptedNote(
            id: n.id,
            titleEnc: encryptedTitle,
            propsEnc: encryptedProps,
            deleted: n.deleted,
          );

          processedIds.add(op.id);
          final noteTypeStr =
              n.noteType == NoteKind.template ? 'template' : 'note';
          debugPrint(
              '✅ Pushed $noteTypeStr: ${n.id} [type=${n.noteType.index}]');
        } else if (op.kind == 'delete_note') {
          // Soft delete via upsert
          await api.upsertEncryptedNote(
            id: op.entityId,
            titleEnc: Uint8List(0),
            propsEnc: Uint8List(0),
            deleted: true,
          );
          processedIds.add(op.id);
          debugPrint('🗑️ Deleted note: ${op.entityId}');
        } else if (op.kind == 'upsert_saved_search') {
          // For now, saved searches are client-only
          // TODO: Implement server sync when ready
          processedIds.add(op.id);
          debugPrint('🔍 Saved search stored locally: ${op.entityId}');
        } else if (op.kind == 'delete_saved_search') {
          // For now, saved searches are client-only
          // TODO: Implement server sync when ready
          processedIds.add(op.id);
          debugPrint(
            '🗑️ Saved search deletion queued (client-only for now): ${op.entityId}',
          );
        } else if (op.kind == 'upsert_note_tag') {
          // Handle tag sync
          processedIds.add(op.id);
          debugPrint('🏷️ Tag sync queued: ${op.entityId}');
        } else if (op.kind == 'delete_note_tag') {
          // Handle tag removal sync
          processedIds.add(op.id);
          debugPrint('🏷️ Tag removal sync queued: ${op.entityId}');
        } else if (op.kind == 'rename_tag') {
          // Handle global tag rename
          processedIds.add(op.id);
          debugPrint('🏷️ Tag rename sync queued: ${op.entityId}');
        }
      } on Object catch (e) {
        debugPrint('❌ Failed to push ${op.kind} for ${op.entityId}: $e');
        // Continue with other operations
      }
    }

    if (processedIds.isNotEmpty) {
      await db.deletePendingByIds(processedIds);
      debugPrint('✅ Successfully pushed ${processedIds.length} operations');
    }
  }

  Future<void> pullSince(DateTime? since) async {
    // Pull notes first
    debugPrint(
      '📥 Pulling notes from remote since: ${since?.toIso8601String() ?? "beginning"}',
    );
    final rows = await api.fetchEncryptedNotes(since: since);
    debugPrint('📦 Received ${rows.length} notes from remote');

    var updatedCount = 0;
    var deletedCount = 0;
    var skippedCount = 0;

    for (final r in rows) {
      try {
        final id = r['id'] as String;
        final deleted = (r['deleted'] as bool?) ?? false;

        if (deleted) {
          // Mark as deleted locally (preserve noteType if existing)
          final existing = await (db.select(
            db.localNotes,
          )..where((n) => n.id.equals(id)))
              .getSingleOrNull();

          await db.upsertNote(
            LocalNote(
              id: id,
              title: '',
              body: '',
              updatedAt: DateTime.now(),
              deleted: true,
              isPinned: false,
              noteType: existing?.noteType ?? NoteKind.note,
            ),
          );
          deletedCount++;
          final typeStr =
              existing?.noteType == NoteKind.template ? 'template' : 'note';
          debugPrint('🗑️ Marked $typeStr as deleted: $id');
          continue;
        }

        // Decrypt the note
        final titleEnc = r['title_enc'] as Uint8List;
        final propsEnc = r['props_enc'] as Uint8List;

        // Try to decrypt title - handle both JSON and plain text
        String title;
        try {
          final titleJson = await crypto.decryptJsonForNote(
            userId: _supabase.auth.currentUser!.id,
            noteId: id,
            data: titleEnc,
          );
          title = titleJson['title'] as String? ?? '';
        } catch (e) {
          // Fallback: try as plain text
          try {
            title = await crypto.decryptStringForNote(
              userId: _supabase.auth.currentUser!.id,
              noteId: id,
              data: titleEnc,
            );
          } catch (_) {
            debugPrint('⚠️ Could not decrypt title for note $id, using empty');
            title = '';
          }
        }

        // Try to decrypt properties - handle both JSON and plain text
        String body;
        List<String> tags;
        List<Map<String, dynamic>> links;
        bool isPinned;
        NoteKind noteType;
        Map<String, dynamic> metadata;

        try {
          final propsJson = await crypto.decryptJsonForNote(
            userId: _supabase.auth.currentUser!.id,
            noteId: id,
            data: propsEnc,
          );
          body = propsJson['body'] as String? ?? '';
          tags = (propsJson['tags'] as List?)?.cast<String>() ?? [];
          links =
              (propsJson['links'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          isPinned = propsJson['isPinned'] as bool? ?? false;

          // Extract noteType from encrypted props (with backward compatibility)
          final kindStr = propsJson['noteType'] as String?;
          noteType = kindStr == 'template' ? NoteKind.template : NoteKind.note;
          if (kindStr != null) {
            debugPrint(
                '🔍 Decrypted note type: "$kindStr" => ${noteType.name} for $id');
          } else {
            debugPrint(
                '📝 No noteType in props for $id, defaulting to regular note');
          }

          // Extract metadata
          metadata = Map<String, dynamic>.from(propsJson);
          metadata.remove('body');
          metadata.remove('tags');
          metadata.remove('links');
          metadata.remove('isPinned');
          metadata.remove('updatedAt');
          metadata
              .remove('noteType'); // Remove from metadata to avoid duplication
        } catch (e) {
          // Fallback: try as plain text for body
          try {
            body = await crypto.decryptStringForNote(
              userId: _supabase.auth.currentUser!.id,
              noteId: id,
              data: propsEnc,
            );
            tags = [];
            links = [];
            isPinned = false;
            noteType = NoteKind.note; // Default to regular note
            metadata = {};
            debugPrint(
                '⚠️ Using plain text fallback for $id, defaulting to regular note');
          } catch (_) {
            debugPrint('⚠️ Could not decrypt body for note $id, using empty');
            body = '';
            tags = [];
            links = [];
            isPinned = false;
            noteType = NoteKind.note; // Default to regular note
            metadata = {};
          }
        }
        final updatedAt = DateTime.parse(r['updated_at'] as String);

        // Check if we need to update
        final existing = await (db.select(
          db.localNotes,
        )..where((n) => n.id.equals(id)))
            .getSingleOrNull();

        if (existing != null && existing.updatedAt.isAfter(updatedAt)) {
          skippedCount++;
          debugPrint('⏭️ Skipped note (local is newer): $id');
          continue;
        }

        // Upsert the note with correct type
        await db.upsertNote(
          LocalNote(
            id: id,
            title: title,
            body: body,
            updatedAt: updatedAt,
            deleted: false,
            encryptedMetadata:
                metadata.isNotEmpty ? jsonEncode(metadata) : null,
            isPinned: isPinned,
            noteType: noteType, // Preserve template/note type from sync
          ),
        );

        final typeStr = noteType == NoteKind.template ? 'template' : 'note';
        debugPrint(
            '📝 Synced $typeStr: $id [${title.substring(0, title.length.clamp(0, 30))}...]');

        // Update tags
        await db.replaceTagsForNote(id, tags.toSet());

        // Update links
        await db.replaceLinksForNote(
          id,
          links
              .map(
                (l) => {
                  'title': l['title'] as String?,
                  'id': l['id'] as String?,
                },
              )
              .toList(),
        );

        // Reindex for search (only for regular notes, not templates)
        if (noteType == NoteKind.note) {
          await _indexer.indexNote(
            LocalNote(
              id: id,
              title: title,
              body: body,
              updatedAt: updatedAt,
              deleted: false,
              encryptedMetadata:
                  metadata.isNotEmpty ? jsonEncode(metadata) : null,
              isPinned: isPinned,
              noteType: noteType,
            ),
          );
        } else {
          debugPrint('🔍 Skipped indexing template: $id');
        }

        updatedCount++;
      } on Object catch (e) {
        debugPrint('❌ Failed to process note during pull: $e');
      }
    }

    // Count templates vs notes for better visibility (with error handling)
    try {
      final templates = await (db.select(db.localNotes)
            ..where((t) => t.deleted.equals(false) & t.noteType.equals(1)))
          .get();
      final notes = await (db.select(db.localNotes)
            ..where((t) => t.deleted.equals(false) & t.noteType.equals(0)))
          .get();

      debugPrint(
        '📊 Pull complete: $updatedCount updated, $deletedCount deleted, $skippedCount skipped | '
        '📄 Notes: ${notes.length}, 📋 Templates: ${templates.length}',
      );
    } catch (e) {
      // Fallback if template counting fails (e.g., older DB schema)
      debugPrint(
        '📊 Pull complete: $updatedCount updated, $deletedCount deleted, $skippedCount skipped',
      );
      debugPrint('⚠️ Could not count templates: $e');
    }

    // Now pull folders
    await _pullFolders(since);
  }

  Future<void> _pullFolders(DateTime? since) async {
    debugPrint(
      '📥 Pulling folders from remote since: ${since?.toIso8601String() ?? "beginning"}',
    );

    try {
      final folders = await api.fetchEncryptedFolders(since: since);
      debugPrint('📦 Received ${folders.length} folders from remote');

      for (final folder in folders) {
        final id = folder['id'] as String;
        final deleted = folder['deleted'] as bool? ?? false;

        if (deleted) {
          // Delete folder locally
          final existing = await getFolder(id);
          if (existing != null) {
            await db.upsertFolder(existing.copyWith(deleted: true));
            debugPrint('🗑️ Deleted folder: ${existing.name}');
          }
        } else {
          // Decrypt folder
          final nameEnc = folder['name_enc'] as Uint8List;
          final propsEnc = folder['props_enc'] as Uint8List;

          // Try to decrypt name - handle both JSON and plain text
          String name;
          try {
            final nameJson = await crypto.decryptJsonForNote(
              userId: _supabase.auth.currentUser!.id,
              noteId: id,
              data: nameEnc,
            );
            name = nameJson['name'] as String? ?? '';
          } catch (e) {
            // Fallback: try as plain text
            try {
              name = await crypto.decryptStringForNote(
                userId: _supabase.auth.currentUser!.id,
                noteId: id,
                data: nameEnc,
              );
            } catch (_) {
              debugPrint(
                '⚠️ Could not decrypt name for folder $id, using empty',
              );
              name = '';
            }
          }

          // Try to decrypt properties - handle both JSON and plain text
          String? parentId;
          int sortOrder;
          String? color;
          String? icon;
          String description;

          try {
            final propsJson = await crypto.decryptJsonForNote(
              userId: _supabase.auth.currentUser!.id,
              noteId: id,
              data: propsEnc,
            );
            parentId = propsJson['parentId'] as String?;
            sortOrder = propsJson['sortOrder'] as int? ?? 0;
            color = propsJson['color'] as String?;
            icon = propsJson['icon'] as String?;
            description = (propsJson['description'] as String?) ?? '';
          } catch (e) {
            // Fallback: try as plain text for description
            try {
              description = await crypto.decryptStringForNote(
                userId: _supabase.auth.currentUser!.id,
                noteId: id,
                data: propsEnc,
              );
              parentId = null;
              sortOrder = 0;
              color = null;
              icon = null;
            } catch (_) {
              debugPrint(
                '⚠️ Could not decrypt properties for folder $id, using defaults',
              );
              parentId = null;
              sortOrder = 0;
              color = null;
              icon = null;
              description = '';
            }
          }
          final createdAt = DateTime.parse(folder['created_at'] as String);
          final updatedAt = DateTime.parse(folder['updated_at'] as String);

          // Upsert folder
          await db.upsertFolder(
            LocalFolder(
              id: id,
              name: name,
              parentId: parentId,
              path: '', // Will be computed by trigger
              sortOrder: sortOrder,
              color: color,
              icon: icon,
              description: description,
              deleted: false,
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
          debugPrint('📁 Updated folder: $name');
        }
      }

      // Pull note-folder associations
      final relations = await api.fetchNoteFolderRelations(since: since);
      debugPrint('📦 Received ${relations.length} note-folder associations');

      for (final rel in relations) {
        final noteId = rel['note_id'] as String;
        final folderId = rel['folder_id'] as String;

        // Check if note exists locally
        final noteExists = await (db.select(
              db.localNotes,
            )..where((n) => n.id.equals(noteId)))
                .getSingleOrNull() !=
            null;

        if (noteExists) {
          await db.moveNoteToFolder(noteId, folderId);
          debugPrint('📎 Associated note $noteId with folder $folderId');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to pull folders: $e');
    }
  }

  Future<Set<String>> _getNoteTags(String noteId) async {
    final tags = await (db.select(
      db.noteTags,
    )..where((t) => t.noteId.equals(noteId)))
        .get();
    return tags.map((t) => t.tag).toSet();
  }

  Future<List<NoteLink>> _getNoteLinks(String noteId) async {
    return (db.select(
      db.noteLinks,
    )..where((l) => l.sourceId.equals(noteId)))
        .get();
  }

  /// Fetch remote active IDs (compatibility)
  Future<Set<String>> fetchRemoteActiveIds() async {
    return api.fetchAllActiveIds();
  }

  /// Reconcile hard deletes (compatibility)
  Future<void> reconcileHardDeletes(Set<String> remoteIds) async {
    final localIds = await db.getLocalActiveNoteIds();
    final toDelete = localIds.difference(remoteIds);

    for (final id in toDelete) {
      await deleteNote(id);
      debugPrint('🗑️ Hard deleted local note not on server: $id');
    }
  }

  Future<void> reconcile() async {
    // Get local active note IDs
    final localIds = await db.getLocalActiveNoteIds();

    // Get remote active note IDs
    final remoteIds = await api.fetchAllActiveIds();

    // Find notes that exist locally but not remotely
    final localOnly = localIds.difference(remoteIds);

    // Find notes that exist remotely but not locally
    final remoteOnly = remoteIds.difference(localIds);

    debugPrint(
      '📊 Reconciliation: ${localOnly.length} local-only, ${remoteOnly.length} remote-only',
    );

    // For local-only notes, enqueue them for upload
    for (final id in localOnly) {
      await db.enqueue(id, 'upsert_note');
      debugPrint('📤 Enqueued local-only note for upload: $id');
    }

    // For remote-only notes, they will be pulled in the next sync
    if (remoteOnly.isNotEmpty) {
      debugPrint(
        '📥 Found ${remoteOnly.length} remote-only notes to be pulled',
      );
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    // For now, we'll use the most recent updated_at from local notes
    // In a production app, you might want to store this separately
    final mostRecent = await (db.select(db.localNotes)
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(1))
        .getSingleOrNull();

    return mostRecent?.updatedAt;
  }

  Future<void> sync() async {
    try {
      // First push any pending changes
      await pushAllPending();

      // Then pull latest changes
      final lastSync = await getLastSyncTime();
      await pullSince(lastSync?.subtract(const Duration(minutes: 1)));

      // Finally, reconcile any differences
      await reconcile();

      debugPrint('✅ Sync completed successfully');
    } on Object catch (e) {
      debugPrint('❌ Sync failed: $e');
      rethrow;
    }
  }
}
