import 'package:duru_notes/core/migration/state_migration_helper.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/folders/note_folder_integration_service.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note-folder integration service provider for enhanced operations
///
/// TODO(infrastructure): Update NoteFolderIntegrationService to use domain repositories
/// For now, using the domain notes repository
final noteFolderIntegrationServiceProvider = Provider<NoteFolderIntegrationService>((ref) {
  final notesRepository = ref.watch(notesRepositoryProvider);
  final analyticsService = ref.watch(analyticsProvider);
  // Cast to domain repository type
  return NoteFolderIntegrationService(
    notesRepository: notesRepository as INotesRepository,
    analyticsService: analyticsService as AnalyticsService,
  );
});

/// Root folders provider for quick access
/// This provider is invalidated whenever folders change to ensure consistency
final rootFoldersProvider = FutureProvider<List<LocalFolder>>((ref) async {
  // Watch the folder hierarchy state to ensure both providers stay in sync
  ref.watch(folderHierarchyProvider);

  final folderRepo = ref.watch(folderRepositoryProvider);
  final folders = await folderRepo.listFolders();

  // Filter for root folders (no parent)
  final rootFolders = folders.where((f) => f.parentId == null || f.parentId!.isEmpty).toList();

  // TODO(infrastructure): Convert domain folders to LocalFolder
  // For now, return empty list until proper conversion is implemented
  return [];
});

/// All folders count provider for accurate statistics
final allFoldersCountProvider = FutureProvider<int>((ref) async {
  // Watch the folder hierarchy to rebuild when folders change
  ref.watch(folderHierarchyProvider);

  final repo = ref.watch(folderRepositoryProvider);
  final allFolders = await repo.listFolders();
  return allFolders.length;
});

/// Unfiled notes count provider
final unfiledNotesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  // Get all notes without a folder
  final allNotes = await repo.localNotes();
  final unfiledNotes = allNotes.where((note) => note.folderId == null || note.folderId!.isEmpty).toList();
  return unfiledNotes.length;
});

/// Domain folders provider - switches between legacy and domain
final domainFoldersProvider = FutureProvider<List<domain_folder.Folder>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Use domain repository
    final repository = ref.watch(folderCoreRepositoryProvider);
    return repository.listFolders();
  } else {
    // Convert from legacy
    final localFolders = ref.watch(folderListProvider);
    return StateMigrationHelper.convertFoldersToDomain(localFolders);
  }
});

/// Domain folders stream provider
final domainFoldersStreamProvider = StreamProvider<List<domain_folder.Folder>>((ref) {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Since domain folder repository doesn't have watchFolders,
    // we'll watch the folder updates provider and convert each time
    return ref.watch(folderUpdatesProvider.stream).asyncMap((_) async {
      final repository = ref.read(folderCoreRepositoryProvider);
      return repository.listFolders();
    });
  } else {
    // Convert legacy stream - watch folder hierarchy changes
    return ref.watch(folderUpdatesProvider.stream).map((_) {
      final localFolders = ref.read(folderListProvider);
      return StateMigrationHelper.convertFoldersToDomain(localFolders);
    });
  }
});

/// Folder update listener provider - listens to folder updates and invalidates dependent providers
final folderUpdateListenerProvider = Provider<void>((ref) {
  // Listen to folder updates and invalidate dependent providers
  ref.listen(folderUpdatesProvider, (_, __) {
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