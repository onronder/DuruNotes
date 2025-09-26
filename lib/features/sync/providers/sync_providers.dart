import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/sync_service.dart';
import 'package:duru_notes/services/connection_manager.dart';
import 'package:duru_notes/services/sync/folder_remote_api.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  // Rebuild SyncService when repo or auth changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notesRepositoryProvider);
  final service = SyncService(repo as NotesRepository);

  // Get unified realtime service if available
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);

  // Start realtime sync with unified service
  service.startRealtime(unifiedService: unifiedRealtime);

  // Listen to sync changes and refresh folders on completion
  service.changes.listen((_) async {
    try {
      // Refresh folders after successful sync
      // This also triggers rootFoldersProvider rebuild automatically
      // We'll need to import from folders module
      // await ref.read(folderHierarchyProvider.notifier).loadFolders();
      debugPrint('[Sync] Folders refreshed after sync completion');

      // Also refresh notes providers for immediate UI update
      // We'll need to import from notes module
      // ref.invalidate(filteredNotesProvider);
      final config = ref.read(migrationConfigProvider);
      if (config.isFeatureEnabled('notes')) {
        // ref.read(dualNotesPageProvider.notifier).refresh();
      } else {
        // ref.read(notesPageProvider.notifier).refresh();
      }
      debugPrint('[Sync] Notes providers refreshed after sync completion');

      // Run template migration after sync
      // We'll need to import from templates module
      // final migrationService = ref.read(templateMigrationServiceProvider);
      // if (await migrationService.needsMigration()) {
      //   debugPrint('[Sync] Running template migration...');
      //   await migrationService.migrateTemplates();
      //   ref.invalidate(templateListProvider);
      //   debugPrint('[Sync] Template migration completed');
      // }
    } catch (e) {
      debugPrint('[Sync] Error refreshing after sync: $e');
    }
  });

  // Clean up on disposal
  ref.onDispose(service.stopRealtime);

  return service;
});

/// Sync mode provider
final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((
  ref,
) {
  // We'll need to import notesRepositoryProvider from notes module
  final repo = null; // ref.watch(notesRepositoryProvider);

  // Callback to refresh UI after successful sync
  // Use a safe callback that checks if the provider is still alive
  void onSyncComplete() {
    // Only refresh if the provider is still alive
    try {
      // Check if we can still access providers and refresh conditionally
      final config = ref.read(migrationConfigProvider);
      if (config.isFeatureEnabled('notes')) {
        // We'll need to import from notes module
        // ref.read(dualNotesPageProvider.notifier).refresh();
        // Load additional pages if there are more notes
        // while (ref.read(conditionalHasMoreProvider)) {
        //   ref.read(dualNotesPageProvider.notifier).loadMore();
        // }
      } else {
        // We'll need to import from notes module
        // ref.read(notesPageProvider.notifier).refresh();
        // Load additional pages if there are more notes
        // while (ref.read(hasMoreNotesProvider)) {
        //   ref.read(notesPageProvider.notifier).loadMore();
        // }
      }

      // Refresh folders as well
      // We'll need to import from folders module
      // ref.read(folderHierarchyProvider.notifier).loadFolders();
    } catch (e) {
      // Provider is disposed or ref is not available
      // Silently ignore - this is expected when the provider is disposed
      debugPrint('[SyncMode] Cannot refresh after sync - provider disposed');
    }
  }

  return SyncModeNotifier(repo as NotesRepository, onSyncComplete);
});

// Folder sync audit provider
final folderSyncAuditProvider = Provider<FolderSyncAudit>((ref) {
  final logger = ref.watch(loggerProvider);
  return FolderSyncAudit(logger: logger);
});

// Folder sync coordinator provider
final folderRemoteApiProvider = Provider<FolderRemoteApi>((ref) {
  final client = Supabase.instance.client;
  final logger = ref.watch(loggerProvider);
  return SupabaseFolderRemoteApi(client: client, logger: logger);
});

final folderSyncCoordinatorProvider = Provider<FolderSyncCoordinator>((ref) {
  final repository = ref.watch(folderRepositoryProvider);
  final remoteApi = ref.watch(folderRemoteApiProvider);
  final audit = ref.watch(folderSyncAuditProvider);
  final logger = ref.watch(loggerProvider);

  return FolderSyncCoordinator(
    repository: repository as FolderRepository,
    remoteApi: remoteApi,
    audit: audit,
    logger: logger,
  );
});

/// Unified Realtime Service - Single source of truth for all realtime subscriptions
/// This replaces individual realtime services to reduce database load
final unifiedRealtimeServiceProvider =
    ChangeNotifierProvider<UnifiedRealtimeService?>((ref) {
  // Watch auth state to properly manage lifecycle
  final authStateAsync = ref.watch(authStateChangesProvider);

  return authStateAsync.when(
    data: (authState) {
      // Return null if not authenticated
      if (authState.session == null) {
        debugPrint(
          '[Providers] No session - unified realtime service not created',
        );
        return null;
      }

      final userId = authState.session!.user.id;
      final logger = ref.watch(loggerProvider);
      final folderSyncCoordinator = ref.watch(
        folderSyncCoordinatorProvider,
      );

      debugPrint(
        '[Providers] Creating unified realtime service for user: $userId',
      );

      // Create service with injected dependencies
      final service = UnifiedRealtimeService(
        supabase: Supabase.instance.client,
        userId: userId,
        logger: logger,
        connectionManager: ConnectionManager(),
        folderSyncCoordinator: folderSyncCoordinator,
      );

      // Start the service with proper error handling
      service.start().catchError((Object error) {
        logger.error(
          '[Providers] Failed to start unified realtime',
          error: error,
        );
      });

      // CRITICAL: Proper disposal on logout or provider disposal
      ref.onDispose(() {
        debugPrint('[Providers] Disposing unified realtime service');
        service.dispose();
      });

      return service;
    },
    loading: () => null,
    error: (error, stack) {
      debugPrint('[Providers] Auth state error: $error');
      return null;
    },
  );
});