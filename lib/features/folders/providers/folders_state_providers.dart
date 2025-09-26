import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/features/sync/providers/sync_providers.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Need to import these from the original file since they're not exported yet
// We'll update these imports once we create the proper barrel files

/// Current folder filter provider
final currentFolderProvider =
    StateNotifierProvider<CurrentFolderNotifier, LocalFolder?>((ref) {
  return CurrentFolderNotifier();
});

/// Folder state provider for CRUD operations
final folderProvider =
    StateNotifierProvider<FolderNotifier, FolderOperationState>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  final syncCoordinator = ref.watch(folderSyncCoordinatorProvider);
  return FolderNotifier(repo, syncCoordinator as FolderSyncCoordinator);
});

/// Folder hierarchy provider for tree structure management
final folderHierarchyProvider =
    StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return FolderHierarchyNotifier(repo as NotesRepository);
});

/// Note-folder relationship provider
final noteFolderProvider =
    StateNotifierProvider<NoteFolderNotifier, NoteFolderState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NoteFolderNotifier(repo as NotesRepository);
});

/// Folder list provider (derived from hierarchy state)
final folderListProvider = Provider<List<LocalFolder>>((ref) {
  return ref.watch(folderHierarchyProvider).folders;
});

/// Visible folder tree nodes provider (derived from hierarchy state)
final visibleFolderNodesProvider = Provider<List<FolderTreeNode>>((ref) {
  ref.watch(folderHierarchyProvider); // Watch the state, not just notifier
  return ref.read(folderHierarchyProvider.notifier).getVisibleNodes();
});