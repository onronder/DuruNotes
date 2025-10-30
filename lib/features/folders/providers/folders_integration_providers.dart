import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/features/folders/note_folder_integration_service.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note-folder integration service provider for enhanced operations
///
/// Uses domain folder repository for folder operations.
final noteFolderIntegrationServiceProvider =
    Provider<NoteFolderIntegrationService>((ref) {
      // Use folder repository for folder operations
      final folderRepository = ref.watch(folderCoreRepositoryProvider);
      final analyticsService = ref.watch(analyticsProvider);

      return NoteFolderIntegrationService(
        folderRepository: folderRepository,
        analyticsService: analyticsService,
      );
    });

/// Root folders provider for quick access
/// This provider is invalidated whenever folders change to ensure consistency
final rootFoldersProvider =
    FutureProvider.autoDispose<List<domain_folder.Folder>>((ref) async {
      // Watch the folder hierarchy state to ensure both providers stay in sync
      ref.watch(folderHierarchyProvider);

      final folderRepo = ref.watch(folderRepositoryProvider);

      // Guard against null repository (unauthenticated)
      if (folderRepo == null) {
        return <domain_folder.Folder>[];
      }

      final folders = await folderRepo.listFolders();

      // Filter for root folders (no parent)
      final rootFolders = folders
          .where((f) => f.parentId == null || f.parentId!.isEmpty)
          .toList();

      return rootFolders;
    });

/// All folders count provider for accurate statistics
final allFoldersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Watch the folder hierarchy to rebuild when folders change
  ref.watch(folderHierarchyProvider);

  final repo = ref.watch(folderRepositoryProvider);

  // Guard against null repository (unauthenticated)
  if (repo == null) {
    return 0;
  }

  final allFolders = await repo.listFolders();
  return allFolders.length;
});

/// Unfiled notes count provider
///
/// Uses domain repository which handles auth internally.
/// Returns 0 when not authenticated (repository returns empty list).
final unfiledNotesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Use domain repository - it handles auth internally
  // Repository methods return empty list when not authenticated
  final repo = ref.watch(notesCoreRepositoryProvider);

  final allNotes = await repo.localNotes(); // Returns [] if not auth'd
  final unfiledNotes = allNotes
      .where((note) => note.folderId == null || note.folderId!.isEmpty)
      .toList();

  return unfiledNotes.length;
});

// ===== PHASE 6: Domain providers moved to folders_domain_providers.dart =====
// domainFoldersProvider and domainFoldersStreamProvider are now in:
// lib/features/folders/providers/folders_domain_providers.dart
// Import from there or use barrel re-export

/// Folder update listener provider - listens to folder updates and invalidates dependent providers
final folderUpdateListenerProvider = Provider<void>((ref) {
  // Listen to folder updates and invalidate dependent providers
  ref.listen(folderUpdatesProvider, (_, _) {
    // Invalidate all folder-related providers to refresh UI
    ref.invalidate(folderHierarchyProvider);
    ref.invalidate(rootFoldersProvider);
    ref.invalidate(folderListProvider);
    ref.invalidate(visibleFolderNodesProvider);
    ref.invalidate(unfiledNotesCountProvider);
    // We'll need to invalidate filteredNotesProvider from notes module
    // ref.invalidate(filteredNotesProvider);

    // Also refresh notes if they're folder-filtered
    final currentFolder = ref.read(currentFolderProvider);
    if (currentFolder != null) {
      final config = ref.read(migrationConfigProvider);
      if (config.isFeatureEnabled('notes')) {
        // We'll need to import dualNotesPageProvider from notes module
        // ref.read(dualNotesPageProvider.notifier).refresh();
      } else {
        // We'll need to import notesPageProvider from notes module
        // ref.read(notesPageProvider.notifier).refresh();
      }
    }

    debugPrint('[FolderUpdates] Invalidated folder-dependent providers');
  });
});
