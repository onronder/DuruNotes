import 'dart:async';

import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Sort specification for notes
enum FolderSortBy {
  updatedAt,
  title,
  createdAt,
  pinned, // Pinned notes first
}

enum FolderSortOrder { asc, desc }

class FolderSortSpec {
  const FolderSortSpec({
    this.sortBy = FolderSortBy.updatedAt,
    this.order = FolderSortOrder.desc,
  });
  final FolderSortBy sortBy;
  final FolderSortOrder order;
}

/// Repository for managing folders with offline-first sync
class FolderRepository {
  FolderRepository({required this.db, required this.userId});

  final AppDb db;
  final String userId;
  final _uuid = const Uuid();

  // Broadcast stream for folder updates
  final _folderUpdates = StreamController<void>.broadcast();
  Stream<void> get folderUpdates => _folderUpdates.stream;

  // ----------------------
  // Folder Management
  // ----------------------

  /// Watch all folders as a stream
  Stream<List<LocalFolder>> watchFolders({String? parentId}) {
    if (parentId == null) {
      // Watch root folders
      return (db.select(db.localFolders)
            ..where((f) => f.deleted.equals(false) & f.parentId.isNull())
            ..orderBy([
              (f) => OrderingTerm.asc(f.sortOrder),
              (f) => OrderingTerm.asc(f.name),
            ]))
          .watch();
    } else {
      // Watch child folders of a parent
      return (db.select(db.localFolders)
            ..where(
              (f) => f.deleted.equals(false) & f.parentId.equals(parentId),
            )
            ..orderBy([
              (f) => OrderingTerm.asc(f.sortOrder),
              (f) => OrderingTerm.asc(f.name),
            ]))
          .watch();
    }
  }

  /// Watch all folders (flat list)
  Stream<List<LocalFolder>> watchAllFolders() {
    return (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.path)]))
        .watch();
  }

  /// Create a local folder (for sync coordinator)
  Future<LocalFolder?> createLocalFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final folderId = id ?? _uuid.v4();
      final now = DateTime.now();

      debugPrint('🔧 Creating local folder: name="$name", parentId=$parentId');

      // Generate path
      String path;
      if (parentId != null) {
        debugPrint('🔍 Looking up parent folder: $parentId');
        final parent = await db.getFolderById(parentId);
        if (parent == null) {
          debugPrint('❌ Parent folder not found: $parentId');
          throw Exception('Parent folder not found: $parentId');
        }
        path = '${parent.path}/$name';
        debugPrint('📁 Generated path with parent: $path');
      } else {
        path = '/$name';
        debugPrint('📁 Generated root path: $path');
      }

      // Get max sort order for siblings
      final siblings = parentId != null
          ? await db.getChildFolders(parentId)
          : await db.getRootFolders();
      final maxOrder = siblings.isEmpty
          ? 0
          : siblings.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

      debugPrint('📊 Found ${siblings.length} siblings, max order: $maxOrder');

      final folder = LocalFolder(
        id: folderId,
        name: name,
        parentId: parentId,
        path: path,
        sortOrder: maxOrder + 1,
        color: color,
        icon: icon,
        description: description ?? '',
        createdAt: now,
        updatedAt: now,
        deleted: false,
      );

      debugPrint('💾 Upserting folder to database...');
      await db.upsertFolder(folder);
      _folderUpdates.add(null);

      debugPrint('✅ Local folder created successfully: ${folder.id}');
      return folder;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to create local folder: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update a local folder (for sync coordinator)
  Future<bool> updateLocalFolder({
    required String id,
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final existing = await db.getFolderById(id);
      if (existing == null) return false;

      // Generate new path if parent changed
      var path = existing.path;
      if (parentId != existing.parentId) {
        if (parentId != null) {
          final parent = await db.getFolderById(parentId);
          if (parent == null) {
            throw Exception('Parent folder not found');
          }
          path = '${parent.path}/$name';
        } else {
          path = '/$name';
        }
      } else if (name != existing.name) {
        // Update path if name changed
        final pathParts = existing.path.split('/');
        pathParts[pathParts.length - 1] = name;
        path = pathParts.join('/');
      }

      final updated = existing.copyWith(
        name: name,
        parentId: Value(parentId),
        path: path,
        color: Value(color),
        icon: Value(icon),
        description: description,
        updatedAt: DateTime.now(),
      );

      await db.upsertFolder(updated);
      _folderUpdates.add(null);

      return true;
    } catch (e) {
      debugPrint('Failed to update local folder: $e');
      return false;
    }
  }

  /// Delete a local folder (for sync coordinator)
  Future<bool> deleteLocalFolder(String id) async {
    try {
      final folder = await db.getFolderById(id);
      if (folder == null) return false;

      final deleted = folder.copyWith(deleted: true, updatedAt: DateTime.now());

      await db.upsertFolder(deleted);
      _folderUpdates.add(null);

      return true;
    } catch (e) {
      debugPrint('Failed to delete local folder: $e');
      return false;
    }
  }

  /// Get folder by ID
  Future<LocalFolder?> getFolderById(String id) async {
    return db.getFolderById(id);
  }

  /// Get all folders
  Future<List<LocalFolder>> getAllFolders() async {
    return await db.allFolders();
  }

  /// Create a new folder
  Future<LocalFolder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final folderId = _uuid.v4();
    final now = DateTime.now();

    // Generate path
    String path;
    if (parentId != null) {
      final parent = await db.getFolderById(parentId);
      if (parent == null) {
        throw Exception('Parent folder not found');
      }
      path = '${parent.path}/$name';
    } else {
      path = '/$name';
    }

    // Get max sort order for siblings
    final siblings = parentId != null
        ? await db.getChildFolders(parentId)
        : await db.getRootFolders();
    final maxOrder = siblings.isEmpty
        ? 0
        : siblings.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    final folder = LocalFolder(
      id: folderId,
      name: name,
      parentId: parentId,
      path: path,
      sortOrder: maxOrder + 1,
      color: color,
      icon: icon,
      description: description ?? '',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    );

    await db.upsertFolder(folder);
    await db.enqueue(folderId, 'upsert_folder');

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('📁 Created folder: $name at $path');
    return folder;
  }

  /// Rename a folder
  Future<void> renameFolder({
    required String folderId,
    required String newName,
  }) async {
    final folder = await db.getFolderById(folderId);
    if (folder == null) {
      throw Exception('Folder not found');
    }

    // Generate new path
    String newPath;
    if (folder.parentId != null) {
      final parent = await db.getFolderById(folder.parentId!);
      if (parent == null) {
        throw Exception('Parent folder not found');
      }
      newPath = '${parent.path}/$newName';
    } else {
      newPath = '/$newName';
    }

    // Update folder
    final updatedFolder = folder.copyWith(
      name: newName,
      path: newPath,
      updatedAt: DateTime.now(),
    );

    await db.upsertFolder(updatedFolder);

    // Update paths of all descendant folders
    await _updateDescendantPaths(folderId, newPath);

    await db.enqueue(folderId, 'upsert_folder');

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('📝 Renamed folder: ${folder.name} -> $newName');
  }

  /// Move a folder to a new parent
  Future<void> moveFolder({
    required String folderId,
    String? newParentId,
  }) async {
    final folder = await db.getFolderById(folderId);
    if (folder == null) {
      throw Exception('Folder not found');
    }

    // Prevent moving folder to its own descendant
    if (newParentId != null) {
      if (await _isDescendantOf(newParentId, folderId)) {
        throw Exception('Cannot move folder to its own descendant');
      }
    }

    // Generate new path
    String newPath;
    if (newParentId != null) {
      final parent = await db.getFolderById(newParentId);
      if (parent == null) {
        throw Exception('Parent folder not found');
      }
      newPath = '${parent.path}/${folder.name}';
    } else {
      newPath = '/${folder.name}';
    }

    // Update folder
    final updatedFolder = folder.copyWith(
      parentId: Value(newParentId),
      path: newPath,
      updatedAt: DateTime.now(),
    );

    await db.upsertFolder(updatedFolder);

    // Update paths of all descendant folders
    await _updateDescendantPaths(folderId, newPath);

    await db.enqueue(folderId, 'upsert_folder');

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('📦 Moved folder: ${folder.name} to ${newParentId ?? 'root'}');
  }

  /// Delete a folder (soft delete)
  Future<void> deleteFolder({
    required String folderId,
    bool moveNotesToInbox = true,
  }) async {
    final folder = await db.getFolderById(folderId);
    if (folder == null) {
      throw Exception('Folder not found');
    }

    // Soft delete the folder
    final deletedFolder = folder.copyWith(
      deleted: true,
      updatedAt: DateTime.now(),
    );
    await db.upsertFolder(deletedFolder);

    // Handle notes in this folder
    if (moveNotesToInbox) {
      final noteIds = await db.getNoteIdsInFolder(folderId);
      for (final noteId in noteIds) {
        await db.moveNoteToFolder(noteId, null); // Move to inbox
      }
      debugPrint(
        '🗑️ Moved ${noteIds.length} notes from deleted folder to inbox',
      );
    }

    // Recursively delete child folders
    final children = await db.getChildFolders(folderId);
    for (final child in children) {
      await deleteFolder(
        folderId: child.id,
        moveNotesToInbox: moveNotesToInbox,
      );
    }

    // Clean up sort preferences for this folder
    try {
      await SortPreferencesService().removeSortForFolder(folderId);
    } catch (e) {
      // Silently fail - preferences cleanup is not critical
      debugPrint('Failed to clean up sort preferences for folder: $e');
    }

    await db.enqueue(folderId, 'delete_folder');

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('🗑️ Deleted folder: ${folder.name}');
  }

  /// Reorder folders within their parent
  Future<void> reorderSiblings({
    required String? parentId,
    required List<String> orderedFolderIds,
  }) async {
    for (var i = 0; i < orderedFolderIds.length; i++) {
      final folder = await db.getFolderById(orderedFolderIds[i]);
      if (folder != null) {
        final updatedFolder = folder.copyWith(
          sortOrder: i,
          updatedAt: DateTime.now(),
        );
        await db.upsertFolder(updatedFolder);
        await db.enqueue(folder.id, 'upsert_folder');
      }
    }

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('🔄 Reordered ${orderedFolderIds.length} folders');
  }

  // ----------------------
  // Note-Folder Management
  // ----------------------

  /// Move a note to a folder
  Future<void> moveNoteToFolder({
    required String noteId,
    String? folderId,
  }) async {
    await db.moveNoteToFolder(noteId, folderId);

    // Update the note's updatedAt to trigger sync
    final note = await db.findNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await db.upsertNote(updatedNote);
      await db.enqueue(noteId, 'upsert_note');
    }

    // Emit folder update event
    _folderUpdates.add(null);

    debugPrint('📁 Moved note $noteId to folder ${folderId ?? 'inbox'}');
  }

  /// Watch notes in a specific folder
  Stream<List<LocalNote>> watchNotesInFolder({
    required FolderSortSpec sort,
    String? folderId,
  }) {
    Stream<List<LocalNote>> baseStream;

    if (folderId == null) {
      // Watch unfiled notes
      baseStream = _watchUnfiledNotes(sort);
    } else {
      // Watch notes in specific folder
      baseStream = _watchNotesInSpecificFolder(folderId, sort);
    }

    return baseStream;
  }

  Stream<List<LocalNote>> _watchUnfiledNotes(FolderSortSpec sort) {
    final query =
        db.select(db.localNotes).join([
          leftOuterJoin(
            db.noteFolders,
            db.noteFolders.noteId.equalsExp(db.localNotes.id),
          ),
        ])..where(
          db.localNotes.deleted.equals(false) & db.noteFolders.noteId.isNull(),
        );

    _applySorting(query, sort);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.localNotes)).toList(),
    );
  }

  Stream<List<LocalNote>> _watchNotesInSpecificFolder(
    String folderId,
    FolderSortSpec sort,
  ) {
    final query =
        db.select(db.localNotes).join([
          innerJoin(
            db.noteFolders,
            db.noteFolders.noteId.equalsExp(db.localNotes.id),
          ),
        ])..where(
          db.localNotes.deleted.equals(false) &
              db.noteFolders.folderId.equals(folderId),
        );

    _applySorting(query, sort);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.localNotes)).toList(),
    );
  }

  void _applySorting(JoinedSelectStatement query, FolderSortSpec sort) {
    final isAsc = sort.order == FolderSortOrder.asc;

    switch (sort.sortBy) {
      case FolderSortBy.pinned:
        query.orderBy([
          OrderingTerm(
            expression: db.localNotes.isPinned,
            mode: OrderingMode.desc,
          ),
          OrderingTerm(
            expression: db.localNotes.updatedAt,
            mode: OrderingMode.desc,
          ),
        ]);
        break;
      case FolderSortBy.title:
        query.orderBy([
          OrderingTerm(
            expression: db.localNotes.title,
            mode: isAsc ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case FolderSortBy.createdAt:
        // Using updatedAt as proxy since we don't have createdAt
        query.orderBy([
          OrderingTerm(
            expression: db.localNotes.updatedAt,
            mode: isAsc ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case FolderSortBy.updatedAt:
      default:
        query.orderBy([
          OrderingTerm(
            expression: db.localNotes.updatedAt,
            mode: isAsc ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
    }
  }

  /// Get breadcrumb path for a folder
  Future<List<LocalFolder>> getFolderBreadcrumbs(String folderId) async {
    final breadcrumbs = <LocalFolder>[];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = await db.getFolderById(currentId);
      if (folder == null) break;

      breadcrumbs.insert(0, folder);
      currentId = folder.parentId;
    }

    return breadcrumbs;
  }

  // ----------------------
  // Helper Methods
  // ----------------------

  /// Check if a folder is a descendant of another
  Future<bool> _isDescendantOf(
    String potentialDescendantId,
    String ancestorId,
  ) async {
    String? currentId = potentialDescendantId;

    while (currentId != null) {
      if (currentId == ancestorId) return true;

      final folder = await db.getFolderById(currentId);
      if (folder == null) break;

      currentId = folder.parentId;
    }

    return false;
  }

  /// Update paths of all descendant folders
  Future<void> _updateDescendantPaths(
    String parentId,
    String newParentPath,
  ) async {
    final children = await db.getChildFolders(parentId);

    for (final child in children) {
      final newChildPath = '$newParentPath/${child.name}';
      final updatedChild = child.copyWith(
        path: newChildPath,
        updatedAt: DateTime.now(),
      );

      await db.upsertFolder(updatedChild);
      await db.enqueue(child.id, 'upsert_folder');

      // Recursively update descendants
      await _updateDescendantPaths(child.id, newChildPath);
    }
  }

  /// Get folder statistics
  Future<Map<String, dynamic>> getFolderStats(String folderId) async {
    final folder = await db.getFolderById(folderId);
    if (folder == null) {
      throw Exception('Folder not found');
    }

    final noteCount = await db.getNotesCountInFolder(folderId);
    final childFolders = await db.getChildFolders(folderId);

    // Get total descendant count
    var totalNotes = noteCount;
    for (final child in childFolders) {
      final childStats = await getFolderStats(child.id);
      totalNotes += childStats['totalNotes'] as int;
    }

    return {
      'folder': folder,
      'directNotes': noteCount,
      'totalNotes': totalNotes,
      'childFolderCount': childFolders.length,
    };
  }

  /// Search folders by name
  Future<List<LocalFolder>> searchFolders(String query) async {
    return db.searchFolders(query);
  }

  /// Push all pending folder operations to server
  Future<void> pushAllPending() async {
    final ops = await db.getPendingOps();
    final folderOps = ops
        .where((op) => op.kind == 'upsert_folder' || op.kind == 'delete_folder')
        .toList();

    debugPrint(
      '📤 Processing ${folderOps.length} pending folder operations...',
    );

    // Process folder operations
    // This would typically sync with a remote API
    // For now, we'll just mark them as processed
    for (final op in folderOps) {
      await db.delete(db.pendingOps).delete(op);
    }
  }

  /// Dispose the repository and close stream controllers
  void dispose() {
    _folderUpdates.close();
  }
}
