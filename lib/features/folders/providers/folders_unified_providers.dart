// Unified Folders Providers - No more dual architecture!
// These providers replace all conditional providers with a single, consistent interface

import 'package:duru_notes/infrastructure/repositories/unified_folders_repository.dart';
import 'package:duru_notes/providers.dart'; // Import main providers for appDbProvider and supabaseClientProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main folders list provider using UnifiedFolder type
final foldersListProvider = StateNotifierProvider<FoldersListNotifier, AsyncValue<UnifiedFolderList>>((ref) {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return FoldersListNotifier(repository, ref);
});

class FoldersListNotifier extends StateNotifier<AsyncValue<UnifiedFolderList>> {
  final UnifiedFoldersRepository _repository;
  final Ref _ref;
  String? _parentIdFilter;

  FoldersListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();

    try {
      final folders = await _repository.getAllUnified();
      state = AsyncValue.data(UnifiedFolderList(
        folders: folders,
        totalCount: folders.length,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  void setParentFilter(String? parentId) {
    _parentIdFilter = parentId;
    loadInitial();
  }

  Future<void> deleteFolder(String id) async {
    await _repository.deleteFolder(id);
    await refresh();
  }

  Future<void> createFolder(UnifiedFolder folder) async {
    await _repository.createUnified(folder);
    await refresh();
  }

  Future<void> updateFolder(UnifiedFolder folder) async {
    await _repository.updateUnified(folder);
    await refresh();
  }

  Future<void> moveFolder(String folderId, String? newParentId) async {
    await _repository.moveFolder(folderId, newParentId);
    await refresh();
  }

  Future<void> addNoteToFolder(String noteId, String folderId) async {
    await _repository.addNoteToFolder(noteId, folderId);
    await refresh();
  }

  Future<void> removeNoteFromFolder(String noteId, String folderId) async {
    await _repository.removeNoteFromFolder(noteId, folderId);
    await refresh();
  }
}

/// Current folders provider
final currentFoldersProvider = Provider<List<UnifiedFolder>>((ref) {
  return ref.watch(foldersListProvider).when(
    data: (list) => list.folders,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Root folders provider
final rootFoldersProvider = Provider<List<UnifiedFolder>>((ref) {
  final folders = ref.watch(currentFoldersProvider);
  return folders.where((folder) => folder.isRoot).toList();
});

/// Child folders provider
final childFoldersProvider = Provider.family<List<UnifiedFolder>, String>((ref, parentId) {
  final folders = ref.watch(currentFoldersProvider);
  return folders.where((folder) => folder.parentId == parentId).toList();
});

/// Folder by ID provider
final folderByIdProvider = FutureProvider.family<UnifiedFolder?, String>((ref, folderId) async {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  final folder = await repository.getFolderById(folderId);
  return folder != null ? UnifiedFolder.from(folder) : null;
});

/// Folder tree provider
final folderTreeProvider = FutureProvider<Map<String, List<UnifiedFolder>>>((ref) async {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return await repository.getFolderTree();
});

/// Folder path provider (breadcrumb)
final folderPathProvider = FutureProvider.family<List<UnifiedFolder>, String>((ref, folderId) async {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return await repository.getFolderPath(folderId);
});

/// Notes in folder provider
final notesInFolderIdsProvider = FutureProvider.family<List<String>, String>((ref, folderId) async {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return await repository.getNotesInFolder(folderId);
});

/// Folder statistics provider
final folderStatisticsProvider = Provider<FolderStatistics>((ref) {
  final folders = ref.watch(currentFoldersProvider);
  final total = folders.length;
  final root = folders.where((f) => f.isRoot).length;
  final withNotes = folders.where((f) => f.noteCount > 0).length;
  final empty = folders.where((f) => f.isEmpty).length;
  
  return FolderStatistics(
    total: total,
    rootFolders: root,
    foldersWithNotes: withNotes,
    emptyFolders: empty,
  );
});

class FolderStatistics {
  final int total;
  final int rootFolders;
  final int foldersWithNotes;
  final int emptyFolders;

  FolderStatistics({
    required this.total,
    required this.rootFolders,
    required this.foldersWithNotes,
    required this.emptyFolders,
  });
}

/// Watch folders stream
final watchFoldersProvider = StreamProvider<List<UnifiedFolder>>((ref) {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return repository.watchFolders();
});

/// Watch root folders stream
final watchRootFoldersProvider = StreamProvider<List<UnifiedFolder>>((ref) {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return repository.watchRootFolders();
});

/// Watch child folders stream
final watchChildFoldersProvider = StreamProvider.family<List<UnifiedFolder>, String>((ref, parentId) {
  final repository = ref.watch(unifiedFoldersRepositoryProvider);
  return repository.watchChildFolders(parentId);
});

/// Selected folder state
final selectedFolderProvider = StateProvider<UnifiedFolder?>((ref) => null);

/// Folder expansion state (for tree view)
final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});

/// Folder sort order
enum FolderSortOrder { name, dateCreated, dateModified, noteCount }

final folderSortOrderProvider = StateProvider<FolderSortOrder>((ref) => FolderSortOrder.name);

/// Sorted folders provider
final sortedFoldersProvider = Provider<List<UnifiedFolder>>((ref) {
  final folders = ref.watch(currentFoldersProvider);
  final sortOrder = ref.watch(folderSortOrderProvider);
  
  final sorted = [...folders];
  
  switch (sortOrder) {
    case FolderSortOrder.name:
      sorted.sort((a, b) => a.name.compareTo(b.name));
      break;
    case FolderSortOrder.dateCreated:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case FolderSortOrder.dateModified:
      sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      break;
    case FolderSortOrder.noteCount:
      sorted.sort((a, b) => b.noteCount.compareTo(a.noteCount));
      break;
  }
  
  return sorted;
});