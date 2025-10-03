import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/features/sync/providers/sync_providers.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current folder filter provider
final currentFolderProvider =
    StateNotifierProvider<CurrentFolderNotifier, LocalFolder?>((ref) {
  return CurrentFolderNotifier();
});

/// Folder state provider for CRUD operations
///
/// TODO(infrastructure): Update FolderNotifier to use domain repositories
final folderProvider =
    StateNotifierProvider<FolderNotifier, FolderOperationState>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  final syncCoordinator = ref.watch(folderSyncCoordinatorProvider);
  return FolderNotifier(repo as IFolderRepository, syncCoordinator as FolderSyncCoordinator);
});

/// Folder hierarchy provider for tree structure management
///
/// TODO(infrastructure): Update FolderHierarchyNotifier to use domain repositories
final folderHierarchyProvider =
    StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return FolderHierarchyNotifier(repo as INotesRepository);
});

/// Note-folder relationship provider
///
/// TODO(infrastructure): Update NoteFolderNotifier to use domain repositories
final noteFolderProvider =
    StateNotifierProvider<NoteFolderNotifier, NoteFolderState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NoteFolderNotifier(repo as INotesRepository);
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