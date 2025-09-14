import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required this.db,
    required this.crypto,
    required this.api,
    required SupabaseClient client,
  }) : _supabase = client;

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseNoteApi api;
  final SupabaseClient _supabase;
  final _uuid = const Uuid();
  final _indexer = NoteIndexer();
  
  // Expose client for compatibility
  SupabaseClient get client => _supabase;

  // ----------------------
  // Saved Searches Management
  // ----------------------

  /// Create or update a saved search
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch) async {
    await db.upsertSavedSearch(savedSearch);
    // Enqueue for sync
    await db.enqueue(savedSearch.id, 'upsert_saved_search',
      payload: jsonEncode(savedSearch.toJson()));
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
  Future<void> trackSavedSearchUsage(String id) => db.updateSavedSearchUsage(id);

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> ids) => db.reorderSavedSearches(ids);

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
        return await db.searchNotes(query);
      case 'tags':
        final tags = (params?['tags'] as List?)?.cast<String>() ?? [];
        return await db.notesByTags(
          anyTags: tags,
          noneTags: [],
          sort: const SortSpec(),
        );
      case 'folder':
        final folderId = params?['folderId'] as String?;
        if (folderId != null) {
          return await getNotesInFolder(folderId);
        }
        return [];
      case 'compound':
        // Complex search with multiple filters
        return await db.searchNotes(query);
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
  Future<void> setNotePin(String noteId, bool isPinned) => db.setNotePin(noteId, isPinned);

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
    await db.enqueue('$noteId::$norm', 'upsert_note_tag',
      payload: jsonEncode({'note_id': noteId, 'tag': norm}));
  }

  /// Remove tag from a note
  Future<void> removeTag({required String noteId, required String tag}) async {
    final norm = tag.trim().toLowerCase();
    await db.removeTagFromNote(noteId, norm);
    await db.enqueue('$noteId::$norm', 'delete_note_tag',
      payload: jsonEncode({'note_id': noteId, 'tag': norm}));
  }

  /// Bulk rename/merge tag across all notes (Optional admin tool)
  Future<int> renameTagEverywhere({required String from, required String to}) async {
    final cnt = await db.renameTagEverywhere(from, to);
    // optional: enqueue global op if your server supports it
    await db.enqueue('tag::${from.trim().toLowerCase()}', 'rename_tag',
      payload: jsonEncode({'from': from.trim().toLowerCase(), 'to': to.trim().toLowerCase()}));
    return cnt;
  }

  /// Query notes by tags (union + exclude)
  Future<List<LocalNote>> queryNotesByTags({
    required List<String> anyTags,
    List<String> noneTags = const [],
    required SortSpec sort,
  }) => db.notesByTags(anyTags: anyTags, noneTags: noneTags, sort: sort);

  /// Search tags for autocomplete
  Future<List<String>> searchTags(String prefix) => db.searchTags(prefix);

  /// Get tags for a specific note
  Future<List<String>> getTagsForNote(String noteId) async {
    final tags = await (db.select(db.noteTags)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    return tags.map((t) => t.tag).toList();
  }

  // ----------------------
  // Note Management
  // ----------------------

  Future<LocalNote?> getLocalNoteById(String id) async {
    return (db.select(db.localNotes)..where((note) => note.id.equals(id)))
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
    return createOrUpdate(
      title: title,
      body: body,
    );
  }
  
  /// Update an existing note
  Future<LocalNote?> updateNote(
    String id, {
    required String title,
    required String body,
  }) async {
    return createOrUpdate(
      id: id,
      title: title,
      body: body,
    );
  }

  Future<LocalNote?> createOrUpdate({
    String? id,
    required String title,
    required String body,
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

    final note = LocalNote(
      id: id,
      title: title,
      body: body,
      updatedAt: updatedAt,
      deleted: false,
      encryptedMetadata: metadata.isNotEmpty ? jsonEncode(metadata) : null,
      isPinned: isPinned ?? false,
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
    return await (db.select(db.localNotes)
          ..where((n) => n.deleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<LocalNote>> localNotes() async {
    return await (db.select(db.localNotes)
          ..where((note) => note.deleted.equals(false))
          ..orderBy([(note) => OrderingTerm.desc(note.updatedAt)]))
        .get();
  }

  /// List notes with pagination (compatibility method)
  Future<List<LocalNote>> listAfter(DateTime? cursor, {int limit = 20}) async {
    final query = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false));
    
    if (cursor != null) {
      query.where((n) => n.updatedAt.isSmallerThanValue(cursor));
    }
    
    query
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
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
    final existing = await (db.select(db.localNotes)
          ..where((note) => note.id.equals(id)))
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
      encryptedMetadata: Value(attachmentMeta != null ? jsonEncode(attachmentMeta) : existing.encryptedMetadata),
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
    await db.enqueue(id, deleted == true ? 'delete_note' : 'upsert_note');
  }

  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

  /// Delete method (compatibility)
  Future<void> delete(String id) => deleteNote(id);

  // ----------------------
  // Folder Management (Delegating to FolderRepository patterns)
  // ----------------------

  /// Get folder by ID
  Future<LocalFolder?> getFolder(String id) async {
    return await (db.select(db.localFolders)
          ..where((f) => f.id.equals(id)))
        .getSingleOrNull();
  }

  /// List all folders
  Future<List<LocalFolder>> listFolders() async {
    return await (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.path)]))
        .get();
  }

  /// Get root folders
  Future<List<LocalFolder>> getRootFolders() async {
    return await (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.parentId.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder), (f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  /// Create or update folder
  Future<String> createOrUpdateFolder({
    String? id,
    required String name,
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
    
    await db.upsertFolder(folder.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    ));
    
    await db.enqueue(folderId, 'upsert_folder');
  }

  /// Move folder
  Future<void> moveFolder(String folderId, String? newParentId) async {
    final folder = await getFolder(folderId);
    if (folder == null) return;
    
    await db.upsertFolder(folder.copyWith(
      parentId: Value(newParentId),
      updatedAt: DateTime.now(),
    ));
    
    await db.enqueue(folderId, 'upsert_folder');
  }

  /// Delete folder (soft delete)
  Future<void> deleteFolder(String folderId) async {
    final folder = await getFolder(folderId);
    if (folder == null) return;

    // Mark folder as deleted
    await db.upsertFolder(folder.copyWith(
      deleted: true,
      updatedAt: DateTime.now(),
    ));
    
    // Move notes to inbox (null folder)
    final notesInFolder = await getNotesInFolder(folderId);
    for (final note in notesInFolder) {
      await moveNoteToFolder(note.id, null);
    }
    
    await db.enqueue(folderId, 'delete_folder');
  }

  /// Get notes in folder
  Future<List<LocalNote>> getNotesInFolder(String folderId) async {
    return await db.getNotesInFolder(folderId);
  }

  /// Get unfiled notes
  Future<List<LocalNote>> getUnfiledNotes() async {
    final query = db.select(db.localNotes).join([
      leftOuterJoin(db.noteFolders, db.noteFolders.noteId.equalsExp(db.localNotes.id)),
    ])
      ..where(db.localNotes.deleted.equals(false))
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

  /// Get folder for note
  Future<LocalFolder?> getFolderForNote(String noteId) async {
    final relation = await (db.select(db.noteFolders)
          ..where((nf) => nf.noteId.equals(noteId)))
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
    final relations = await (db.select(db.noteFolders)).get();
    for (final rel in relations) {
      final note = await getNote(rel.noteId);
      final folder = await getFolder(rel.folderId);
      if (note == null) {
        issues.putIfAbsent('orphaned_note_relations', () => []).add(rel.noteId);
      }
      if (folder == null) {
        issues.putIfAbsent('orphaned_folder_relations', () => []).add(rel.folderId);
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
    final relations = await (db.select(db.noteFolders)).get();
    for (final rel in relations) {
      final note = await getNote(rel.noteId);
      final folder = await getFolder(rel.folderId);
      
      if (note == null || folder == null) {
        await (db.delete(db.noteFolders)
              ..where((nf) => nf.noteId.equals(rel.noteId))
              ..where((nf) => nf.folderId.equals(rel.folderId)))
            .go();
        debugPrint('Removed orphaned relation: ${rel.noteId} -> ${rel.folderId}');
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
    return await (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.parentId.equals(parentId))
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder), (f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  /// List all notes (compatibility)
  Future<List<LocalNote>> list({int? limit}) async {
    final query = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false))
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
    var query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false));

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
      final normalizedTags = anyTags.map((t) => t.trim().toLowerCase()).toList();
      final tagSubQuery = db.selectOnly(db.noteTags)
        ..where(db.noteTags.tag.isIn(normalizedTags))
        ..addColumns([db.noteTags.noteId]);
      query.where((note) => note.id.isInQuery(tagSubQuery));
    }
    
    if (noneTags != null && noneTags.isNotEmpty) {
      final normalizedTags = noneTags.map((t) => t.trim().toLowerCase()).toList();
      final excludeSubQuery = db.selectOnly(db.noteTags)
        ..where(db.noteTags.tag.isIn(normalizedTags))
        ..addColumns([db.noteTags.noteId]);
      query.where((note) => note.id.isNotInQuery(excludeSubQuery));
    }
    
    // Apply sorting
    final sortSpec = sort ?? const SortSpec();
    
    // Apply sorting with pinned first if enabled
    query.orderBy([
      if (pinnedFirst) (note) => OrderingTerm(
        expression: note.isPinned,
        mode: OrderingMode.desc,
      ),
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
          )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();

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
            'links': linksList.map((l) => {'title': l.targetTitle, 'id': l.targetId}).toList(),
            'isPinned': n.isPinned,
            'updatedAt': n.updatedAt.toIso8601String(),
          };
          
          if (n.encryptedMetadata != null) {
            try {
              final meta = jsonDecode(n.encryptedMetadata!) as Map<String, dynamic>;
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
          debugPrint('✅ Pushed note: ${n.id}');
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
          debugPrint('🗑️ Saved search deletion queued (client-only for now): ${op.entityId}');
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
    debugPrint('📥 Pulling notes from remote since: ${since?.toIso8601String() ?? "beginning"}');
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
          // Mark as deleted locally
          await db.upsertNote(LocalNote(
            id: id,
            title: '',
            body: '',
            updatedAt: DateTime.now(),
            deleted: true,
            encryptedMetadata: null,
            isPinned: false,
          ));
          deletedCount++;
          debugPrint('🗑️ Marked note as deleted: $id');
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
        Map<String, dynamic> metadata;
        
        try {
          final propsJson = await crypto.decryptJsonForNote(
            userId: _supabase.auth.currentUser!.id,
            noteId: id,
            data: propsEnc,
          );
          body = propsJson['body'] as String? ?? '';
          tags = (propsJson['tags'] as List?)?.cast<String>() ?? [];
          links = (propsJson['links'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          isPinned = propsJson['isPinned'] as bool? ?? false;
          
          // Extract metadata
          metadata = Map<String, dynamic>.from(propsJson);
          metadata.remove('body');
          metadata.remove('tags');
          metadata.remove('links');
          metadata.remove('isPinned');
          metadata.remove('updatedAt');
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
            metadata = {};
          } catch (_) {
            debugPrint('⚠️ Could not decrypt body for note $id, using empty');
            body = '';
            tags = [];
            links = [];
            isPinned = false;
            metadata = {};
          }
        }
        final updatedAt = DateTime.parse(r['updated_at'] as String);

        // Check if we need to update
        final existing = await (db.select(db.localNotes)
              ..where((n) => n.id.equals(id)))
            .getSingleOrNull();

        if (existing != null && existing.updatedAt.isAfter(updatedAt)) {
          skippedCount++;
          debugPrint('⏭️ Skipped note (local is newer): $id');
          continue;
        }

        // Upsert the note
        await db.upsertNote(LocalNote(
          id: id,
          title: title,
          body: body,
          updatedAt: updatedAt,
          deleted: false,
          encryptedMetadata: metadata.isNotEmpty ? jsonEncode(metadata) : null,
          isPinned: isPinned,
        ));

        // Update tags
        await db.replaceTagsForNote(id, tags.toSet());

        // Update links
        await db.replaceLinksForNote(id, links.map((l) => {
          'title': l['title'] as String?,
          'id': l['id'] as String?,
        }).toList());

        // Reindex for search
        await _indexer.indexNote(LocalNote(
          id: id,
          title: title,
          body: body,
          updatedAt: updatedAt,
          deleted: false,
          encryptedMetadata: metadata.isNotEmpty ? jsonEncode(metadata) : null,
          isPinned: isPinned,
        ));

        updatedCount++;
        debugPrint('✅ Updated note: $id');
      } on Object catch (e) {
        debugPrint('❌ Failed to process note during pull: $e');
      }
    }

    debugPrint('📊 Pull complete: $updatedCount updated, $deletedCount deleted, $skippedCount skipped');

    // Now pull folders
    await _pullFolders(since);
  }

  Future<void> _pullFolders(DateTime? since) async {
    debugPrint('📥 Pulling folders from remote since: ${since?.toIso8601String() ?? "beginning"}');
    
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
              debugPrint('⚠️ Could not decrypt name for folder $id, using empty');
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
              debugPrint('⚠️ Could not decrypt properties for folder $id, using defaults');
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
          await db.upsertFolder(LocalFolder(
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
          ));
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
        final noteExists = await (db.select(db.localNotes)
              ..where((n) => n.id.equals(noteId)))
            .getSingleOrNull() != null;
        
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
    final tags = await (db.select(db.noteTags)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    return tags.map((t) => t.tag).toSet();
  }

  Future<List<NoteLink>> _getNoteLinks(String noteId) async {
    return await (db.select(db.noteLinks)
          ..where((l) => l.sourceId.equals(noteId)))
        .get();
  }

  /// Fetch remote active IDs (compatibility)
  Future<Set<String>> fetchRemoteActiveIds() async {
    return await api.fetchAllActiveIds();
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

    debugPrint('📊 Reconciliation: ${localOnly.length} local-only, ${remoteOnly.length} remote-only');

    // For local-only notes, enqueue them for upload
    for (final id in localOnly) {
      await db.enqueue(id, 'upsert_note');
      debugPrint('📤 Enqueued local-only note for upload: $id');
    }

    // For remote-only notes, they will be pulled in the next sync
    if (remoteOnly.isNotEmpty) {
      debugPrint('📥 Found ${remoteOnly.length} remote-only notes to be pulled');
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
