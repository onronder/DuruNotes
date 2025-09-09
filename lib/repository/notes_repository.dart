import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
    required this.client,
    required this.userId,
  })  : api = SupabaseNoteApi(client),
        _indexer = NoteIndexer();

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseClient client;
  final String userId;
  final SupabaseNoteApi api;
  final NoteIndexer _indexer;

  final _uuid = const Uuid();

  // Gizli RTL/BiDi kontrol karakterlerini temizle
  String _stripBidi(String s) =>
      s.replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '');

  Future<String> createOrUpdate({
    required String title,
    required String body,
    String? id,
    Map<String, dynamic>? metadataJson,
  }) async {
    final noteId = id ?? _uuid.v4();
    final now = DateTime.now();

    // Metni temizle (ters yazmayı tetikleyen kontrolleri kaldır)
    final cleanTitle = _stripBidi(title.trim());
    final cleanBody = _stripBidi(body);

    // Convert metadata to JSON string if provided
    final metaString = metadataJson != null ? jsonEncode(metadataJson) : null;

    final n = LocalNote(
      id: noteId,
      title: cleanTitle,
      body: cleanBody,
      updatedAt: now,
      deleted: false,
      encryptedMetadata: metaString,
    );

    await db.upsertNote(n);
    await _indexer.indexNote(n);
    await db.enqueue(noteId, 'upsert_note');
    return noteId;
  }

  /// Get a single note by ID
  Future<LocalNote?> getNote(String id) async {
    return db.findNote(id);
  }

  Future<void> delete(String id) async {
    final n = await (db.select(
      db.localNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (n != null) {
      final deletedNote =
          n.copyWith(deleted: true, updatedAt: DateTime.now());
      await db.upsertNote(deletedNote);
      await _indexer.indexNote(deletedNote);
      await db.enqueue(id, 'upsert_note');
    }
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

          final titleEnc = await crypto.encryptStringForNote(
            userId: userId,
            noteId: n.id,
            text: n.title,
          );

          // Include persistent metadata if available
          Map<String, dynamic>? metadata;
          if (n.encryptedMetadata != null) {
            try {
              metadata = jsonDecode(n.encryptedMetadata!) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('Error decoding metadata: $e');
            }
          }
          
          final propsJson = {
            'body': n.body,
            'updatedAt': n.updatedAt.toIso8601String(),
            'deleted': n.deleted,
            // Include metadata if available
            if (metadata != null) ...{
              'metadata': metadata,
            },
          };
          
          final propsEnc = await crypto.encryptJsonForNote(
            userId: userId,
            noteId: n.id,
            json: propsJson,
          );

          await api.upsertEncryptedNote(
            id: n.id,
            titleEnc: titleEnc,
            propsEnc: propsEnc,
            deleted: n.deleted,
          );

          processedIds.add(op.id);
          debugPrint('✅ Pushed note: "${n.title.isEmpty ? "Untitled" : n.title}" (${n.deleted ? "deleted" : "active"})');

        } else if (op.kind == 'upsert_folder') {
          await _pushFolder(op.entityId);
          processedIds.add(op.id);

        } else if (op.kind == 'upsert_note_folder') {
          await _pushNoteFolderRelationship(op.entityId, isAdd: true);
          processedIds.add(op.id);

        } else if (op.kind == 'remove_note_folder') {
          await _pushNoteFolderRelationship(op.entityId, isAdd: false);
          processedIds.add(op.id);
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

        final titleEnc = SupabaseNoteApi.asBytes(r['title_enc']);
        final propsEnc = SupabaseNoteApi.asBytes(r['props_enc']);

        final titleRes = await crypto.decryptStringForNoteWithFallback(
          userId: userId,
          noteId: id,
          data: titleEnc,
        );
        var title = titleRes.value;
        final propsRes = await crypto.decryptJsonForNoteWithFallback(
          userId: userId,
          noteId: id,
          data: propsEnc,
        );
        final props = propsRes.value;

        // BiDi temizliği
        title = _stripBidi(title);
        final body = _stripBidi((props['body'] as String?) ?? '');

        final updatedAt =
            DateTime.tryParse((props['updatedAt'] as String?) ?? '') ??
                DateTime.now();

        // Extract metadata if present
        final metadata = props['metadata'];
        final metaString = metadata != null ? jsonEncode(metadata) : null;

        final local = await (db.select(
          db.localNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        debugPrint('🔍 Note ID: $id');
        debugPrint('   Title: "${title.isEmpty ? "Untitled" : title}"');
        debugPrint('   Remote updated: $updatedAt');
        debugPrint('   Local exists: ${local != null}');
        if (local != null) {
          debugPrint('   Local updated: ${local.updatedAt}');
          debugPrint('   Should update: ${local.updatedAt.isBefore(updatedAt)}');
        }

        // If legacy key was used, immediately re-encrypt with AMK on next push by flagging an upsert
        final needsRewrap = titleRes.usedLegacyKey || propsRes.usedLegacyKey;

        // Conflict resolution: prefer newest updatedAt. If equal, prefer local if there's a pending local op
        final hasPendingLocal = (await db.getPendingOps())
            .any((op) => op.kind == 'upsert_note' && op.entityId == id);
        final shouldApplyRemote = local == null || local.updatedAt.isBefore(updatedAt) ||
            (local.updatedAt.isAtSameMomentAs(updatedAt) && !hasPendingLocal) || needsRewrap;

        if (shouldApplyRemote) {
          final n = LocalNote(
            id: id,
            title: title,
            body: body,
            updatedAt: updatedAt,
            deleted: deleted,
            encryptedMetadata: metaString,
          );
          await db.upsertNote(n);
          await _indexer.indexNote(n);
          if (needsRewrap) {
            await db.enqueue(id, 'upsert_note');
          }
          
          if (deleted) {
            deletedCount++;
            debugPrint('🗑️ Synced deleted note: "${title.isEmpty ? "Untitled" : title}"');
          } else {
            updatedCount++;
            debugPrint('✅ Synced active note: "${title.isEmpty ? "Untitled" : title}"');
          }
        } else {
          skippedCount++;
        }
      } on Object catch (e) {
        final noteId = r['id'] as String? ?? 'unknown';
        debugPrint('❌ Failed to process remote note $noteId: $e');
      }
    }
    
    debugPrint('📊 Note pull complete: $updatedCount active, $deletedCount deleted, $skippedCount skipped');

    // Pull folders
    await pullFoldersSince(since);
    
    // Pull note-folder relationships
    await pullNoteFolderRelationsSince(since);
  }

  Future<Set<String>> fetchRemoteActiveIds() async {
    final ids = await api.fetchAllActiveIds();
    debugPrint('🔍 Remote active IDs: ${ids.length} notes');
    for (final id in ids.take(5)) {
      debugPrint('  - $id');
    }
    return ids;
  }

  Future<void> reconcileHardDeletes(Set<String> remoteActiveIds) async {
    debugPrint('🧹 Starting note reconcileHardDeletes...');
    final localIds = await db.getActiveNoteIds();
    debugPrint('📱 Local active note IDs: ${localIds.length} notes');
    
    final pending = await db.getPendingOps();
    final pendingIds = pending
        .where((p) => p.kind == 'upsert_note')
        .map((p) => p.entityId)
        .toSet();
    debugPrint('⏳ Pending note operations: ${pendingIds.length} notes');
    
    var deletedCount = 0;

    for (final id in localIds) {
      if (!remoteActiveIds.contains(id) && !pendingIds.contains(id)) {
        debugPrint('❌ Marking note as deleted locally: $id (not in remote active set)');
        final n = await (db.select(
          db.localNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        if (n != null) {
          debugPrint('  - Note title: "${n.title.isEmpty ? "Untitled" : n.title}"');
          final deletedNote =
              n.copyWith(deleted: true, updatedAt: DateTime.now());
          await db.upsertNote(deletedNote);
          await _indexer.indexNote(deletedNote);
          deletedCount++;
        }
      }
    }
    
    debugPrint('🧹 Note reconciliation complete: marked $deletedCount notes as deleted');

    // Also reconcile folders
    final remoteFolderIds = await fetchRemoteActiveFolderIds();
    await reconcileFolderHardDeletes(remoteFolderIds);
  }

  Future<List<LocalNote>> list() => db.allNotes();

  /// Paginated list using keyset pagination for better performance at scale
  /// Returns notes after the given cursor, ordered by updatedAt DESC
  Future<List<LocalNote>> listAfter(DateTime? cursor, {int limit = 20}) =>
      db.notesAfter(cursor: cursor, limit: limit);

  /// Fallback pagination method using offset (for debugging/small datasets)
  Future<List<LocalNote>> listWithOffset({int limit = 20, int offset = 0}) =>
      db.pagedNotes(limit: limit, offset: offset);

  // ==========================================
  // FOLDER OPERATIONS
  // ==========================================

  /// Create or update a folder with hierarchical path support
  Future<String> createOrUpdateFolder({
    required String name,
    required String? parentId,
    String? id,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    final folderId = id ?? _uuid.v4();
    final now = DateTime.now();

    // Clean folder name (strip BiDi characters)
    final cleanName = _stripBidi(name.trim());
    if (cleanName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }

    // Calculate folder path
    final path = await _calculateFolderPath(parentId, cleanName);

    // Create folder object
    final folder = LocalFolder(
      id: folderId,
      name: cleanName,
      parentId: parentId,
      path: path,
      sortOrder: sortOrder ?? 0,
      color: color,
      icon: icon,
      description: description ?? '',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    );

    // Save to database
    await db.upsertFolder(folder);
    
    // Add to pending sync operations
    await db.enqueue(folderId, 'upsert_folder');
    
    return folderId;
  }

  /// Calculate the full path for a folder based on its parent hierarchy
  Future<String> _calculateFolderPath(String? parentId, String name) async {
    if (parentId == null) {
      return '/$name';
    }

    final parent = await db.findFolder(parentId);
    if (parent == null) {
      // Parent doesn't exist, treat as root level
      return '/$name';
    }

    return '${parent.path}/$name';
  }

  /// Get a single folder by ID
  Future<LocalFolder?> getFolder(String id) async {
    return db.findFolder(id);
  }

  /// Get all folders in hierarchical order
  Future<List<LocalFolder>> listFolders() async {
    return db.allFolders();
  }

  /// Get root level folders (no parent)
  Future<List<LocalFolder>> getRootFolders() async {
    return db.getRootFolders();
  }

  /// Get child folders of a specific parent folder
  Future<List<LocalFolder>> getChildFolders(String parentId) async {
    return db.getChildFolders(parentId);
  }

  /// Get the full folder hierarchy as a tree structure
  Future<List<LocalFolder>> getFolderHierarchy() async {
    final allFolders = await db.allFolders();
    // Sort by path to maintain hierarchical order
    allFolders.sort((a, b) => a.path.compareTo(b.path));
    return allFolders;
  }

  /// Soft delete a folder and handle child folders
  Future<void> deleteFolder(String id) async {
    final folder = await db.findFolder(id);
    if (folder == null) return;

    final now = DateTime.now();

    // Check if folder has child folders
    final children = await db.getChildFolders(id);
    
    if (children.isNotEmpty) {
      // Move child folders to parent level
      for (final child in children) {
        final updatedChild = child.copyWith(
          parentId: Value(folder.parentId), // Move to grandparent
          updatedAt: now,
        );
        await db.upsertFolder(updatedChild);
        await db.enqueue(child.id, 'upsert_folder');
      }
    }

    // Check if folder has notes
    final notesInFolder = await db.getNoteIdsInFolder(id);
    
    // Move all notes out of the folder (to unfiled)
    for (final noteId in notesInFolder) {
      await removeNoteFromFolder(noteId);
    }

    // Soft delete the folder
    final deletedFolder = folder.copyWith(
      deleted: true,
      updatedAt: now,
    );
    
    await db.upsertFolder(deletedFolder);
    await db.enqueue(id, 'upsert_folder');
  }

  /// Move a folder to a new parent (or to root level)
  Future<void> moveFolder(String folderId, String? newParentId) async {
    final folder = await db.findFolder(folderId);
    if (folder == null) return;

    // Prevent circular references
    if (newParentId != null) {
      if (await _wouldCreateCircularReference(folderId, newParentId)) {
        throw ArgumentError('Cannot move folder: would create circular reference');
      }
    }

    // Calculate new path
    final newPath = await _calculateFolderPath(newParentId, folder.name);
    
    final updatedFolder = folder.copyWith(
      parentId: Value(newParentId),
      path: newPath,
      updatedAt: DateTime.now(),
    );

    await db.upsertFolder(updatedFolder);
    await db.enqueue(folderId, 'upsert_folder');

    // Update paths of all descendant folders
    await _updateDescendantPaths(folderId);
  }

  /// Check if moving a folder would create a circular reference
  Future<bool> _wouldCreateCircularReference(String folderId, String targetParentId) async {
    String? currentParentId = targetParentId;
    
    while (currentParentId != null) {
      if (currentParentId == folderId) {
        return true; // Found circular reference
      }
      
      final parent = await db.findFolder(currentParentId);
      currentParentId = parent?.parentId;
    }
    
    return false;
  }

  /// Update paths for all descendant folders when a folder is moved
  Future<void> _updateDescendantPaths(String parentFolderId) async {
    final children = await db.getChildFolders(parentFolderId);
    
    for (final child in children) {
      final newPath = await _calculateFolderPath(parentFolderId, child.name);
      final updatedChild = child.copyWith(
        path: newPath,
        updatedAt: DateTime.now(),
      );
      
      await db.upsertFolder(updatedChild);
      await db.enqueue(child.id, 'upsert_folder');
      
      // Recursively update child folders
      await _updateDescendantPaths(child.id);
    }
  }

  // ==========================================
  // FOLDER SYNC OPERATIONS
  // ==========================================

  /// Push all pending folder operations to remote
  Future<void> pushAllPendingFolders() async {
    final ops = await db.getPendingOps();
    final folderOps = ops.where((op) => 
        op.kind == 'upsert_folder' || 
        op.kind == 'upsert_note_folder' ||
        op.kind == 'remove_note_folder'
    ).toList();
    
    final processedIds = <int>[];

    debugPrint('📤 Pushing ${folderOps.length} pending folder operations...');

    for (final op in folderOps) {
      try {
        if (op.kind == 'upsert_folder') {
          await _pushFolder(op.entityId);
          processedIds.add(op.id);
        } else if (op.kind == 'upsert_note_folder') {
          await _pushNoteFolderRelationship(op.entityId, isAdd: true);
          processedIds.add(op.id);
        } else if (op.kind == 'remove_note_folder') {
          await _pushNoteFolderRelationship(op.entityId, isAdd: false);
          processedIds.add(op.id);
        }
      } on Object catch (e) {
        debugPrint('❌ Failed to push folder operation ${op.kind} for ${op.entityId}: $e');
        // Continue with other operations
      }
    }

    if (processedIds.isNotEmpty) {
      await db.deletePendingByIds(processedIds);
      debugPrint('✅ Successfully pushed ${processedIds.length} folder operations');
    }
  }

  /// Push a single folder to remote
  Future<void> _pushFolder(String folderId) async {
    final folder = await db.findFolder(folderId);
    if (folder == null) return;

    // Encrypt folder name
    final nameEnc = await crypto.encryptStringForNote(
      userId: userId,
      noteId: folderId, // Use folder ID as encryption key context
      text: folder.name,
    );

    // Encrypt folder properties
    final propsEnc = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: folderId,
      json: {
        'parentId': folder.parentId,
        'path': folder.path,
        'sortOrder': folder.sortOrder,
        'color': folder.color,
        'icon': folder.icon,
        'description': folder.description,
        'createdAt': folder.createdAt.toIso8601String(),
        'updatedAt': folder.updatedAt.toIso8601String(),
      },
    );

    await api.upsertEncryptedFolder(
      id: folderId,
      nameEnc: nameEnc,
      propsEnc: propsEnc,
      deleted: folder.deleted,
    );

    debugPrint('✅ Pushed folder: "${folder.name}" (${folder.deleted ? "deleted" : "active"})');
  }

  /// Push note-folder relationship to remote
  Future<void> _pushNoteFolderRelationship(String entityId, {required bool isAdd}) async {
    if (isAdd) {
      // Parse entityId as "noteId_folderId"
      final parts = entityId.split('_');
      if (parts.length >= 2) {
        final noteId = parts[0];
        final folderId = parts.sublist(1).join('_'); // Handle UUIDs with underscores
        
        await api.upsertNoteFolderRelation(
          noteId: noteId,
          folderId: folderId,
        );
        debugPrint('✅ Added note $noteId to folder $folderId');
      }
    } else {
      // Parse entityId as "noteId_remove"
      final noteId = entityId.replaceAll('_remove', '');
      await api.removeNoteFolderRelation(noteId: noteId);
      debugPrint('✅ Removed note $noteId from folder');
    }
  }

  /// Pull folders from remote since a given timestamp
  Future<void> pullFoldersSince(DateTime? since) async {
    debugPrint('📥 Pulling folders from remote since: ${since?.toIso8601String() ?? "beginning"}');
    final rows = await api.fetchEncryptedFolders(since: since);
    debugPrint('📦 Received ${rows.length} folders from remote');

    var updatedCount = 0;
    var deletedCount = 0;
    var skippedCount = 0;

    for (final r in rows) {
      try {
        final id = r['id'] as String;
        final deleted = (r['deleted'] as bool?) ?? false;

        final nameEnc = SupabaseNoteApi.asBytes(r['name_enc']);
        final propsEnc = SupabaseNoteApi.asBytes(r['props_enc']);

        // Decrypt folder data with legacy fallback
        final nameRes = await crypto.decryptStringForNoteWithFallback(
          userId: userId,
          noteId: id,
          data: nameEnc,
        );
        final name = _stripBidi(nameRes.value);

        final propsRes = await crypto.decryptJsonForNoteWithFallback(
          userId: userId,
          noteId: id,
          data: propsEnc,
        );
        final props = propsRes.value;

        final parentId = props['parentId'] as String?;
        final path = props['path'] as String? ?? '/$name';
        final sortOrder = (props['sortOrder'] as int?) ?? 0;
        final color = props['color'] as String?;
        final icon = props['icon'] as String?;
        final description = props['description'] as String? ?? '';

        final createdAt = DateTime.tryParse(props['createdAt'] as String? ?? '') ?? DateTime.now();
        final updatedAt = DateTime.tryParse(props['updatedAt'] as String? ?? '') ?? DateTime.now();

        final local = await db.findFolder(id);

        debugPrint('🔍 Folder ID: $id');
        debugPrint('   Name: "$name"');
        debugPrint('   Path: "$path"');
        debugPrint('   Remote updated: $updatedAt');
        debugPrint('   Local exists: ${local != null}');
        if (local != null) {
          debugPrint('   Local updated: ${local.updatedAt}');
          debugPrint('   Should update: ${local.updatedAt.isBefore(updatedAt)}');
        }

        // If legacy key was used, enqueue for rewrap on push
        final needsRewrap = nameRes.usedLegacyKey || propsRes.usedLegacyKey;

        // Update if remote is newer or if local doesn't exist
        final shouldApplyRemote = local == null || local.updatedAt.isBefore(updatedAt) || local.updatedAt.isAtSameMomentAs(updatedAt) || needsRewrap;
        if (shouldApplyRemote) {
          final folder = LocalFolder(
            id: id,
            name: name,
            parentId: parentId,
            path: path,
            sortOrder: sortOrder,
            color: color,
            icon: icon,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
          );

          await db.upsertFolder(folder);

          if (needsRewrap) {
            await db.enqueue(id, 'upsert_folder');
          }

          if (deleted) {
            deletedCount++;
            debugPrint('🗑️ Synced deleted folder: "$name"');
          } else {
            updatedCount++;
            debugPrint('✅ Synced active folder: "$name"');
          }
        } else {
          skippedCount++;
        }
      } on Object catch (e) {
        final folderId = r['id'] as String? ?? 'unknown';
        debugPrint('❌ Failed to process remote folder $folderId: $e');
      }
    }

    debugPrint('📊 Folder pull complete: $updatedCount active, $deletedCount deleted, $skippedCount skipped');
  }

  /// Pull note-folder relationships from remote
  Future<void> pullNoteFolderRelationsSince(DateTime? since) async {
    debugPrint('📥 Pulling note-folder relationships from remote since: ${since?.toIso8601String() ?? "beginning"}');
    final rows = await api.fetchNoteFolderRelations(since: since);
    debugPrint('📦 Received ${rows.length} note-folder relationships from remote');

    var updatedCount = 0;

    for (final r in rows) {
      try {
        final noteId = r['note_id'] as String;
        final folderId = r['folder_id'] as String;
        final addedAt = DateTime.tryParse(r['added_at'] as String? ?? '') ?? DateTime.now();

        // Check if both note and folder exist locally
        final note = await db.findNote(noteId);
        final folder = await db.findFolder(folderId);

        if (note != null && folder != null) {
          final relationship = NoteFolder(
            noteId: noteId,
            folderId: folderId,
            addedAt: addedAt,
          );

          await db.upsertNoteFolder(relationship);
          updatedCount++;
          debugPrint('✅ Synced note $noteId to folder ${folder.name}');
        } else {
          debugPrint('⚠️ Skipped relationship: note or folder not found locally');
        }
      } on Object catch (e) {
        debugPrint('❌ Failed to process note-folder relationship: $e');
      }
    }

    debugPrint('📊 Note-folder relationship pull complete: $updatedCount relationships synced');
  }

  /// Fetch remote active folder IDs for reconciliation
  Future<Set<String>> fetchRemoteActiveFolderIds() async {
    final ids = await api.fetchAllActiveFolderIds();
    debugPrint('🔍 Remote active folder IDs: ${ids.length} folders');
    return ids;
  }

  /// Reconcile hard deletes for folders
  Future<void> reconcileFolderHardDeletes(Set<String> remoteActiveIds) async {
    debugPrint('🧹 Starting folder reconcileHardDeletes...');
    final localIds = await db.getLocalActiveFolderIds();
    debugPrint('📱 Local active folder IDs: ${localIds.length} folders');

    final pending = await db.getPendingOps();
    final pendingFolderIds = pending
        .where((p) => p.kind == 'upsert_folder')
        .map((p) => p.entityId)
        .toSet();
    debugPrint('⏳ Pending folder operations: ${pendingFolderIds.length} folders');

    var deletedCount = 0;

    for (final id in localIds) {
      if (!remoteActiveIds.contains(id) && !pendingFolderIds.contains(id)) {
        debugPrint('❌ Marking folder as deleted locally: $id (not in remote active set)');
        final folder = await db.findFolder(id);

        if (folder != null) {
          debugPrint('  - Folder name: "${folder.name}"');
          
          // Move child folders to parent level before deleting
          final children = await db.getChildFolders(id);
          for (final child in children) {
            final updatedChild = child.copyWith(
              parentId: Value(folder.parentId),
              updatedAt: DateTime.now(),
            );
            await db.upsertFolder(updatedChild);
          }

          // Move notes out of folder
          final noteIds = await db.getNoteIdsInFolder(id);
          for (final noteId in noteIds) {
            await db.removeNoteFromFolder(noteId);
          }

          // Mark folder as deleted
          final deletedFolder = folder.copyWith(
            deleted: true,
            updatedAt: DateTime.now(),
          );
          await db.upsertFolder(deletedFolder);
          deletedCount++;
        }
      }
    }

    debugPrint('🧹 Folder reconciliation complete: marked $deletedCount folders as deleted');
  }

  // ==========================================
  // NOTE-FOLDER RELATIONSHIP OPERATIONS
  // ==========================================

  /// Add a note to a folder
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    // Verify both note and folder exist and are not deleted
    final note = await db.findNote(noteId);
    final folder = await db.findFolder(folderId);
    
    if (note == null || note.deleted) {
      throw ArgumentError('Note not found or is deleted');
    }
    if (folder == null || folder.deleted) {
      throw ArgumentError('Folder not found or is deleted');
    }

    // Remove from existing folder first (one folder per note)
    await removeNoteFromFolder(noteId);

    // Add to new folder
    final relationship = NoteFolder(
      noteId: noteId,
      folderId: folderId,
      addedAt: DateTime.now(),
    );

    await db.upsertNoteFolder(relationship);
    await db.enqueue('${noteId}_$folderId', 'upsert_note_folder');
  }

  /// Remove a note from its current folder
  Future<void> removeNoteFromFolder(String noteId) async {
    await db.removeNoteFromFolder(noteId);
    await db.enqueue('${noteId}_remove', 'remove_note_folder');
  }

  /// Move a note from one folder to another
  Future<void> moveNoteToFolder(String noteId, String folderId) async {
    await addNoteToFolder(noteId, folderId);
  }

  /// Get all notes in a specific folder
  Future<List<LocalNote>> getNotesInFolder(String folderId) async {
    final noteIds = await db.getNoteIdsInFolder(folderId);
    final notes = <LocalNote>[];
    
    for (final noteId in noteIds) {
      final note = await db.findNote(noteId);
      if (note != null && !note.deleted) {
        notes.add(note);
      }
    }
    
    // Sort by updated date (most recent first)
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Get unfiled notes (notes not in any folder)
  Future<List<LocalNote>> getUnfiledNotes() async {
    return db.getUnfiledNotes();
  }

  /// Get the folder containing a specific note
  Future<LocalFolder?> getFolderForNote(String noteId) async {
    return db.getFolderForNote(noteId);
  }

  // ==========================================
  // ERROR HANDLING AND CONFLICT RESOLUTION
  // ==========================================

  /// Comprehensive folder validation and repair
  Future<void> validateAndRepairFolderStructure() async {
    debugPrint('🔧 Starting folder structure validation and repair...');

    final allFolders = await db.allFolders();
    final foldersToUpdate = <LocalFolder>[];
    var repairedCount = 0;

    for (final folder in allFolders) {
      if (folder.deleted) continue; // Skip deleted folders

      var needsUpdate = false;
      var updatedFolder = folder;

      // Check for orphaned folders (parent doesn't exist)
      if (folder.parentId != null) {
        final parent = await db.findFolder(folder.parentId!);
        if (parent == null || parent.deleted) {
          debugPrint('🔧 Repairing orphaned folder: "${folder.name}" -> moved to root');
          updatedFolder = updatedFolder.copyWith(
            parentId: const Value(null),
            updatedAt: DateTime.now(),
          );
          needsUpdate = true;
        }
      }

      // Recalculate and fix path if incorrect
      final correctPath = await _calculateFolderPath(updatedFolder.parentId, updatedFolder.name);
      if (updatedFolder.path != correctPath) {
        debugPrint('🔧 Fixing folder path: "${updatedFolder.name}" -> "$correctPath"');
        updatedFolder = updatedFolder.copyWith(
          path: correctPath,
          updatedAt: DateTime.now(),
        );
        needsUpdate = true;
      }

      if (needsUpdate) {
        foldersToUpdate.add(updatedFolder);
        repairedCount++;
      }
    }

    // Apply repairs
    for (final folder in foldersToUpdate) {
      await db.upsertFolder(folder);
      await db.enqueue(folder.id, 'upsert_folder');
    }

    debugPrint('🔧 Folder validation complete: repaired $repairedCount folders');
  }

  /// Handle folder sync conflicts with intelligent resolution
  Future<void> resolveFolderConflicts() async {
    debugPrint('🔄 Checking for folder sync conflicts...');
    
    // Get folders that might have conflicts (recent updates)
    final recentFolders = await db.getRecentlyUpdatedFolders(
      since: DateTime.now().subtract(const Duration(hours: 24)),
    );

    var resolvedCount = 0;

    for (final folder in recentFolders) {
      try {
        // Check if folder still exists remotely
        final remoteFolders = await api.fetchEncryptedFolders();
        final remoteFolder = remoteFolders.firstWhere(
          (r) => r['id'] == folder.id,
          orElse: () => <String, dynamic>{},
        );

        if (remoteFolder.isNotEmpty) {
          final remoteUpdated = DateTime.tryParse(
            remoteFolder['updated_at'] as String? ?? '',
          );

          // If remote is significantly newer, pull it
          if (remoteUpdated != null &&
              remoteUpdated.isAfter(folder.updatedAt.add(const Duration(seconds: 30)))) {
            debugPrint('🔄 Resolving conflict: pulling newer version of "${folder.name}"');
            await pullFoldersSince(folder.updatedAt.subtract(const Duration(minutes: 1)));
            resolvedCount++;
          }
        }
      } on Object catch (e) {
        debugPrint('❌ Failed to resolve conflict for folder ${folder.id}: $e');
      }
    }

    debugPrint('🔄 Conflict resolution complete: resolved $resolvedCount conflicts');
  }

  /// Clean up orphaned note-folder relationships
  Future<void> cleanupOrphanedRelationships() async {
    debugPrint('🧹 Cleaning up orphaned note-folder relationships...');

    final allRelationships = await db.getAllNoteFolderRelationships();
    var cleanedCount = 0;

    for (final relationship in allRelationships) {
      // Check if note exists and is not deleted
      final note = await db.findNote(relationship.noteId);
      if (note == null || note.deleted) {
        await db.removeNoteFromFolder(relationship.noteId);
        cleanedCount++;
        continue;
      }

      // Check if folder exists and is not deleted
      final folder = await db.findFolder(relationship.folderId);
      if (folder == null || folder.deleted) {
        await db.removeNoteFromFolder(relationship.noteId);
        cleanedCount++;
        continue;
      }
    }

    debugPrint('🧹 Cleanup complete: removed $cleanedCount orphaned relationships');
  }

  /// Comprehensive folder system health check
  Future<Map<String, dynamic>> performFolderHealthCheck() async {
    debugPrint('🏥 Performing folder system health check...');

    final stats = <String, dynamic>{
      'total_folders': 0,
      'active_folders': 0,
      'deleted_folders': 0,
      'root_folders': 0,
      'orphaned_folders': 0,
      'total_relationships': 0,
      'orphaned_relationships': 0,
      'notes_with_folders': 0,
      'unfiled_notes': 0,
      'max_depth': 0,
      'issues_found': <String>[],
    };

    final allFolders = await db.allFolders();
    final allRelationships = await db.getAllNoteFolderRelationships();
    final allNotes = await db.allNotes();

    stats['total_folders'] = allFolders.length;
    stats['total_relationships'] = allRelationships.length;

    var activeCount = 0;
    var deletedCount = 0;
    var rootCount = 0;
    var orphanedCount = 0;

    // Analyze folders
    for (final folder in allFolders) {
      if (folder.deleted) {
        deletedCount++;
      } else {
        activeCount++;

        if (folder.parentId == null) {
          rootCount++;
        } else {
          // Check if parent exists
          final parent = allFolders.where((f) => f.id == folder.parentId).firstOrNull;
          if (parent == null || parent.deleted) {
            orphanedCount++;
            stats['issues_found'].add('Orphaned folder: "${folder.name}" (${folder.id})');
          }
        }

        // Calculate depth
        final depth = await _calculateFolderDepth(folder.id);
        final maxDepth = stats['max_depth'] as int;
        if (depth > maxDepth) {
          stats['max_depth'] = depth;
        }
      }
    }

    stats['active_folders'] = activeCount;
    stats['deleted_folders'] = deletedCount;
    stats['root_folders'] = rootCount;
    stats['orphaned_folders'] = orphanedCount;

    // Analyze relationships
    var orphanedRelationships = 0;
    final notesWithFolders = <String>{};

    for (final rel in allRelationships) {
      final noteExists = allNotes.any((n) => n.id == rel.noteId && !n.deleted);
      final folderExists = allFolders.any((f) => f.id == rel.folderId && !f.deleted);

      if (!noteExists || !folderExists) {
        orphanedRelationships++;
        stats['issues_found'].add('Orphaned relationship: note ${rel.noteId} -> folder ${rel.folderId}');
      } else {
        notesWithFolders.add(rel.noteId);
      }
    }

    stats['orphaned_relationships'] = orphanedRelationships;
    stats['notes_with_folders'] = notesWithFolders.length;
    stats['unfiled_notes'] = allNotes.where((n) => !n.deleted).length - notesWithFolders.length;

    debugPrint('🏥 Health check complete:');
    debugPrint('   Total folders: ${stats['total_folders']} (${stats['active_folders']} active, ${stats['deleted_folders']} deleted)');
    debugPrint('   Root folders: ${stats['root_folders']}');
    debugPrint('   Max folder depth: ${stats['max_depth']}');
    debugPrint('   Notes with folders: ${stats['notes_with_folders']}');
    debugPrint('   Unfiled notes: ${stats['unfiled_notes']}');
    final issuesList = stats['issues_found'] as List<String>;
    debugPrint('   Issues found: ${issuesList.length}');

    if (issuesList.isNotEmpty) {
      debugPrint('⚠️  Issues detected:');
      for (final issue in issuesList) {
        debugPrint('   - $issue');
      }
    }

    return stats;
  }

  /// Calculate folder depth in hierarchy
  Future<int> _calculateFolderDepth(String folderId) async {
    var depth = 0;
    String? currentId = folderId;

    while (currentId != null && depth < 100) { // Safety limit
      final folder = await db.findFolder(currentId);
      if (folder == null) break;
      
      if (folder.parentId == null) break; // Reached root
      
      currentId = folder.parentId;
      depth++;
    }

    return depth;
  }
}
