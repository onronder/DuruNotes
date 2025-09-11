import 'dart:convert';

import 'package:drift/drift.dart' show Value, OrderingTerm, OrderingMode;
import 'package:flutter/foundation.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required this.db,
    required this.crypto,
    required this.api,
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseNoteApi api;
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

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
    final parameters = savedSearch.parameters;
    
    // Execute based on search type
    switch (searchType) {
      case 'text':
        return await db.searchNotes(query);
      case 'tags':
        final tags = (parameters?['tags'] as List?)?.cast<String>() ?? [];
        return await db.notesByTags(
          anyTags: tags,
          noneTags: [],
          sort: const SortSpec(),
        );
      case 'folder':
        final folderId = parameters?['folderId'] as String?;
        if (folderId != null) {
          return await db.notesForSavedSearch(
            savedSearchKey: null,
            folderId: folderId,
          );
        }
        return [];
      case 'compound':
        // Complex search with multiple filters
        return await db.notesForSavedSearch(
          savedSearchKey: query,
          folderId: parameters?['folderId'] as String?,
        );
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

  Future<LocalNote?> getLocalNoteById(String id) async {
    return (db.select(db.localNotes)..where((note) => note.id.equals(id)))
        .getSingleOrNull();
  }

  Future<LocalNote?> createOrUpdate({
    String? id,
    required String title,
    required String body,
    DateTime? updatedAt,
    Set<String> tags = const {},
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    bool? isPinned,
  }) async {
    id ??= _uuid.v4();
    updatedAt ??= DateTime.now();

    final note = LocalNote(
      id: id,
      title: title,
      body: body,
      updatedAt: updatedAt,
      deleted: false,
      encryptedMetadata: attachmentMeta != null ? jsonEncode(attachmentMeta) : null,
      isPinned: isPinned ?? false,
    );

    await db.upsertLocalNote(note);
    await db.replaceTagsForNote(id, tags);
    await db.replaceLinksForNote(id, links);

    // Reindex for search
    await NoteIndexer.updateIndex(db, note, tags);

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

    await db.upsertLocalNote(updated);

    // Update tags if provided
    if (tags != null) {
      await db.replaceTagsForNote(id, tags);
    }

    // Update links if provided
    if (links != null) {
      await db.replaceLinksForNote(id, links);
    }

    // Reindex for search
    await NoteIndexer.updateIndex(db, updated, tags ?? {});

    // Enqueue the pending operation for sync
    await db.enqueue(id, deleted == true ? 'delete_note' : 'upsert_note');
  }

  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

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

          // Get the encrypted note data
          final encNote = await crypto.encryptNote(
            id: n.id,
            title: n.title,
            body: n.body,
            tags: tagsSet.toList(),
            links: linksList.map((l) => {'title': l.targetTitle, 'id': l.targetId}).toList(),
          );

          // Include attachment metadata and pinned status
          final propsJson = <String, dynamic>{
            'isPinned': n.isPinned,
          };
          
          if (n.encryptedMetadata != null) {
            try {
              final meta = jsonDecode(n.encryptedMetadata!);
              propsJson['attachments'] = meta['attachments'];
              propsJson['source'] = meta['source'];
              propsJson['originalUrl'] = meta['originalUrl'];
              propsJson['originalId'] = meta['originalId'];
            } catch (e) {
              // Ignore parsing errors
            }
          }

          // Call the push API
          await api.pushEncryptedNote(
            id: n.id,
            eTitleNonce: encNote.encryptedTitleNonce,
            eTitle: encNote.encryptedTitle,
            eBodyNonce: encNote.encryptedBodyNonce,
            eBody: encNote.encryptedBody,
            updatedAt: n.updatedAt,
            eTags: encNote.encryptedTags,
            eLinks: encNote.encryptedLinks,
            propsJson: propsJson.isNotEmpty ? propsJson : null,
          );

          processedIds.add(op.id);
          debugPrint('✅ Pushed note: ${n.id}');
        } else if (op.kind == 'delete_note') {
          await api.deleteNote(op.entityId);
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
          try {
            final payload = op.payload != null ? jsonDecode(op.payload!) : null;
            if (payload != null) {
              // TODO: Implement server-side tag sync if needed
              processedIds.add(op.id);
              debugPrint('🏷️ Tag sync queued: ${op.entityId}');
            }
          } catch (e) {
            debugPrint('❌ Failed to process tag operation: $e');
          }
        } else if (op.kind == 'delete_note_tag') {
          // Handle tag removal sync
          try {
            final payload = op.payload != null ? jsonDecode(op.payload!) : null;
            if (payload != null) {
              // TODO: Implement server-side tag sync if needed
              processedIds.add(op.id);
              debugPrint('🏷️ Tag removal sync queued: ${op.entityId}');
            }
          } catch (e) {
            debugPrint('❌ Failed to process tag removal: $e');
          }
        } else if (op.kind == 'rename_tag') {
          // Handle global tag rename
          try {
            final payload = op.payload != null ? jsonDecode(op.payload!) : null;
            if (payload != null) {
              // TODO: Implement server-side tag rename if needed
              processedIds.add(op.id);
              debugPrint('🏷️ Tag rename sync queued: ${op.entityId}');
            }
          } catch (e) {
            debugPrint('❌ Failed to process tag rename: $e');
          }
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
          await db.upsertLocalNote(LocalNote(
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
        final decrypted = await crypto.decryptNote(
          eTitleNonce: r['e_title_nonce'] as String,
          eTitle: r['e_title'] as String,
          eBodyNonce: r['e_body_nonce'] as String,
          eBody: r['e_body'] as String,
          eTags: r['e_tags'],
          eLinks: r['e_links'],
        );

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

        // Extract metadata from props_json
        final propsJson = r['props_json'] as Map<String, dynamic>?;
        Map<String, dynamic>? attachmentMeta;
        bool isPinned = false;
        
        if (propsJson != null) {
          isPinned = propsJson['isPinned'] as bool? ?? false;
          
          if (propsJson['attachments'] != null || 
              propsJson['source'] != null || 
              propsJson['originalUrl'] != null || 
              propsJson['originalId'] != null) {
            attachmentMeta = {};
            if (propsJson['attachments'] != null) {
              attachmentMeta['attachments'] = propsJson['attachments'];
            }
            if (propsJson['source'] != null) {
              attachmentMeta['source'] = propsJson['source'];
            }
            if (propsJson['originalUrl'] != null) {
              attachmentMeta['originalUrl'] = propsJson['originalUrl'];
            }
            if (propsJson['originalId'] != null) {
              attachmentMeta['originalId'] = propsJson['originalId'];
            }
          }
        }

        // Upsert the note
        await db.upsertLocalNote(LocalNote(
          id: id,
          title: decrypted.title,
          body: decrypted.body,
          updatedAt: updatedAt,
          deleted: false,
          encryptedMetadata: attachmentMeta != null ? jsonEncode(attachmentMeta) : null,
          isPinned: isPinned,
        ));

        // Update tags
        await db.replaceTagsForNote(id, decrypted.tags.toSet());

        // Update links
        await db.replaceLinksForNote(id, decrypted.links);

        // Reindex for search
        await NoteIndexer.updateIndex(
          db,
          LocalNote(
            id: id,
            title: decrypted.title,
            body: decrypted.body,
            updatedAt: updatedAt,
            deleted: false,
            encryptedMetadata: attachmentMeta != null ? jsonEncode(attachmentMeta) : null,
            isPinned: isPinned,
          ),
          decrypted.tags.toSet(),
        );

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
      final response = await _supabase
          .from('folders')
          .select()
          .order('created_at', ascending: true);
      
      final folders = (response as List).cast<Map<String, dynamic>>();
      debugPrint('📦 Received ${folders.length} folders from remote');
      
      for (final folder in folders) {
        final id = folder['id'] as String;
        final name = folder['name'] as String;
        final parentId = folder['parent_id'] as String?;
        final position = folder['position'] as int? ?? 0;
        final color = folder['color'] as String?;
        final icon = folder['icon'] as String?;
        final isDeleted = folder['deleted'] as bool? ?? false;
        final createdAt = DateTime.parse(folder['created_at'] as String);
        final updatedAt = DateTime.parse(folder['updated_at'] as String);
        
        if (isDeleted) {
          // Delete folder locally
          await db.deleteFolder(id);
          debugPrint('🗑️ Deleted folder: $name');
        } else {
          // Upsert folder
          await db.upsertFolder(LocalFolder(
            id: id,
            name: name,
            parentId: parentId,
            path: '', // Will be computed by trigger
            position: position,
            color: color,
            icon: icon,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ));
          debugPrint('📁 Updated folder: $name');
        }
      }
      
      // Pull note-folder associations
      final noteFoldersResponse = await _supabase
          .from('note_folders')
          .select()
          .order('created_at', ascending: true);
      
      final noteFolders = (noteFoldersResponse as List).cast<Map<String, dynamic>>();
      debugPrint('📦 Received ${noteFolders.length} note-folder associations');
      
      for (final nf in noteFolders) {
        final noteId = nf['note_id'] as String;
        final folderId = nf['folder_id'] as String;
        
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

  Future<void> reconcile() async {
    // Get local active note IDs
    final localIds = await db.getLocalActiveNoteIds();

    // Get remote active note IDs
    final remoteIds = await api.getRemoteActiveNoteIds();

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
