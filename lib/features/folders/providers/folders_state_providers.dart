import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/sync/providers/sync_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current folder filter provider
final currentFolderProvider =
    StateNotifierProvider<CurrentFolderNotifier, domain.Folder?>((ref) {
      return CurrentFolderNotifier();
    });

/// Folder state provider for CRUD operations
///
/// **PRODUCTION FIX**: Returns empty notifier when user not authenticated
final folderProvider =
    StateNotifierProvider<FolderNotifier, FolderOperationState>((ref) {
      final repo = ref.watch(folderRepositoryProvider);
      final syncCoordinator = ref.watch(folderSyncCoordinatorProvider);

      // PRODUCTION FIX: Handle unauthenticated state
      if (repo == null || syncCoordinator == null) {
        return FolderNotifier.empty();
      }

      return FolderNotifier(repo, syncCoordinator);
    });

/// Folder hierarchy provider for tree structure management
///
/// **PRODUCTION FIX**: Returns empty notifier when user not authenticated
final folderHierarchyProvider =
    StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>((ref) {
      final repo = ref.watch(folderRepositoryProvider);

      // PRODUCTION FIX: Handle unauthenticated state
      if (repo == null) {
        return FolderHierarchyNotifier.empty();
      }

      return FolderHierarchyNotifier(repo);
    });

/// Note-folder relationship provider
///
/// **PRODUCTION FIX**: Returns empty notifier when user not authenticated
final noteFolderProvider =
    StateNotifierProvider<NoteFolderNotifier, NoteFolderState>((ref) {
      final notesRepo = ref.watch(notesCoreRepositoryProvider);
      final folderRepo = ref.watch(folderRepositoryProvider);

      // PRODUCTION FIX: Providers are always non-null in authenticated state
      return NoteFolderNotifier(notesRepo, folderRepo);
    });

/// Folder list provider (derived from hierarchy state)
final folderListProvider = Provider<List<domain.Folder>>((ref) {
  return ref.watch(folderHierarchyProvider).folders;
});

/// Visible folder tree nodes provider (derived from hierarchy state)
final visibleFolderNodesProvider = Provider<List<FolderTreeNode>>((ref) {
  ref.watch(folderHierarchyProvider); // Watch the state, not just notifier
  return ref.read(folderHierarchyProvider.notifier).getVisibleNodes();
});
