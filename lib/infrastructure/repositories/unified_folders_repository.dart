// Unified Folders Repository that eliminates dual architecture
// Works with UnifiedFolder type to provide consistent interface

import 'package:duru_notes/core/models/unified_folder.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified repository that provides a single interface for folders
/// No more conditional logic or feature flags
class UnifiedFoldersRepository {
  final AppDb db;
  final SupabaseClient? client;
  final FolderCoreRepository _coreRepository;

  UnifiedFoldersRepository({
    required this.db,
    this.client,
  }) : _coreRepository = FolderCoreRepository(db: db, client: client!);

  /// Get folders with pagination - returns UnifiedFolderList
  Future<UnifiedFolderList> getFoldersPage({
    required int page,
    required int pageSize,
    String? parentId,
  }) async {
    final allFolders = await _coreRepository.listFolders();

    // Filter by parent if provided
    var filteredFolders = allFolders;
    if (parentId != null) {
      filteredFolders = allFolders.where((f) => f.parentId == parentId).toList();
    }

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = (page + 1) * pageSize;
    final paginatedFolders = filteredFolders.skip(startIndex).take(pageSize).toList();

    // Convert to UnifiedFolders
    final unifiedFolders = paginatedFolders.map((f) => UnifiedFolder.from(f)).toList();

    return UnifiedFolderList(
      folders: unifiedFolders,
      hasMore: endIndex < filteredFolders.length,
      currentPage: page,
      totalCount: filteredFolders.length,
    );
  }

  /// Get all folders
  Future<List<domain.Folder>> listFolders() async {
    return await _coreRepository.listFolders();
  }

  /// Get folder by ID
  Future<domain.Folder?> getFolderById(String id) async {
    return await _coreRepository.getFolderById(id);
  }

  /// Create folder
  Future<domain.Folder> createFolder(domain.Folder folder) async {
    return await _coreRepository.createFolder(
      name: folder.name,
      parentId: folder.parentId,
      color: folder.color,
      icon: folder.icon,
      description: folder.description,
    );
  }

  /// Update folder
  Future<domain.Folder> updateFolder(domain.Folder folder) async {
    return await _coreRepository.updateFolder(folder);
  }

  /// Delete folder
  Future<void> deleteFolder(String id) async {
    await _coreRepository.deleteFolder(id);
  }

  /// Add note to folder
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    await _coreRepository.addNoteToFolder(noteId, folderId);
  }

  /// Remove note from folder
  Future<void> removeNoteFromFolder(String noteId, String folderId) async {
    await _coreRepository.removeNoteFromFolder(noteId);
  }

  /// Get notes in folder
  Future<List<String>> getNotesInFolder(String folderId) async {
    final notes = await _coreRepository.getNotesInFolder(folderId);
    return notes.map((n) => n.id).toList();
  }

  /// Sync folders
  Future<void> syncFolders() async {
    await _coreRepository.syncFolders();
  }

  /// Get all folders as UnifiedFolders
  Future<List<UnifiedFolder>> getAllUnified() async {
    final folders = await listFolders();
    return folders.map((f) => UnifiedFolder.from(f)).toList();
  }

  /// Get root folders as UnifiedFolders
  Future<List<UnifiedFolder>> getRootFolders() async {
    final folders = await listFolders();
    final rootFolders = folders.where((f) => f.parentId == null).toList();
    return rootFolders.map((f) => UnifiedFolder.from(f)).toList();
  }

  /// Get child folders as UnifiedFolders
  Future<List<UnifiedFolder>> getChildFolders(String parentId) async {
    final folders = await listFolders();
    final childFolders = folders.where((f) => f.parentId == parentId).toList();
    return childFolders.map((f) => UnifiedFolder.from(f)).toList();
  }

  /// Create folder from UnifiedFolder
  Future<UnifiedFolder> createUnified(UnifiedFolder folder) async {
    final domainFolder = folder.toDomain();
    final created = await createFolder(domainFolder);
    return UnifiedFolder.from(created);
  }

  /// Update folder from UnifiedFolder
  Future<UnifiedFolder> updateUnified(UnifiedFolder folder) async {
    final domainFolder = folder.toDomain();
    final updated = await updateFolder(domainFolder);
    return UnifiedFolder.from(updated);
  }

  /// Move folder to new parent
  Future<UnifiedFolder> moveFolder(String folderId, String? newParentId) async {
    final folder = await getFolderById(folderId);
    if (folder != null) {
      final moved = folder.copyWith(parentId: newParentId);
      final updated = await updateFolder(moved);
      return UnifiedFolder.from(updated);
    }
    throw Exception('Folder not found: $folderId');
  }

  /// Get folder tree structure
  Future<Map<String, List<UnifiedFolder>>> getFolderTree() async {
    final folders = await getAllUnified();
    final tree = <String, List<UnifiedFolder>>{};

    // Group by parent ID
    for (final folder in folders) {
      final parentId = folder.parentId ?? 'root';
      tree.putIfAbsent(parentId, () => []).add(folder);
    }

    return tree;
  }

  /// Get folder path (breadcrumb)
  Future<List<UnifiedFolder>> getFolderPath(String folderId) async {
    final path = <UnifiedFolder>[];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = await getFolderById(currentId);
      if (folder != null) {
        path.insert(0, UnifiedFolder.from(folder));
        currentId = folder.parentId;
      } else {
        break;
      }
    }

    return path;
  }

  /// Batch operations for performance
  Future<List<UnifiedFolder>> batchCreate(List<UnifiedFolder> folders) async {
    final results = <UnifiedFolder>[];
    for (final folder in folders) {
      final created = await createUnified(folder);
      results.add(created);
    }
    return results;
  }

  Future<void> batchDelete(List<String> ids) async {
    for (final id in ids) {
      await deleteFolder(id);
    }
  }

  Future<void> batchAddNotes(String folderId, List<String> noteIds) async {
    for (final noteId in noteIds) {
      await addNoteToFolder(noteId, folderId);
    }
  }

  Future<void> batchRemoveNotes(String folderId, List<String> noteIds) async {
    for (final noteId in noteIds) {
      await removeNoteFromFolder(noteId, folderId);
    }
  }

  /// Stream for watching folders
  Stream<List<UnifiedFolder>> watchFolders() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getAllUnified(),
    ).asyncMap((future) => future);
  }

  /// Stream for watching root folders
  Stream<List<UnifiedFolder>> watchRootFolders() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getRootFolders(),
    ).asyncMap((future) => future);
  }

  /// Stream for watching child folders
  Stream<List<UnifiedFolder>> watchChildFolders(String parentId) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getChildFolders(parentId),
    ).asyncMap((future) => future);
  }
}