import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart';
import 'package:duru_notes/services/connection_manager.dart';
import 'package:duru_notes/services/sync/folder_remote_api.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified sync service provider - replaces old SyncService
final unifiedSyncServiceProvider = Provider<UnifiedSyncService>((ref) {
  // Rebuild when repo or auth changes
  ref.watch(authStateChangesProvider);
  final notesRepo = ref.watch(notesCoreRepositoryProvider);
  final foldersRepo = ref.watch(folderCoreRepositoryProvider);

  final service = UnifiedSyncService(
    notesRepository: notesRepo,
    foldersRepository: foldersRepo,
  );

  // Get unified realtime service if available
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);

  // Listen to sync changes and refresh providers on completion
  service.changes.listen((_) async {
    try {
      debugPrint('[Sync] Sync completed, refreshing providers');

      // Invalidate providers to trigger refresh
      ref.invalidate(notesCoreRepositoryProvider);
      ref.invalidate(folderCoreRepositoryProvider);

      debugPrint('[Sync] Providers refreshed after sync completion');
    } catch (e) {
      debugPrint('[Sync] Error refreshing after sync: $e');
    }
  });

  // Clean up on disposal
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Sync mode provider - simplified without old NotesRepository
final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((
  ref,
) {
  final notesRepo = ref.watch(notesCoreRepositoryProvider);

  // Callback to refresh UI after successful sync
  void onSyncComplete() {
    try {
      // Invalidate providers to trigger refresh
      ref.invalidate(notesCoreRepositoryProvider);
      ref.invalidate(folderCoreRepositoryProvider);

      debugPrint('[SyncMode] Providers refreshed after sync');
    } catch (e) {
      debugPrint('[SyncMode] Cannot refresh after sync - provider disposed');
    }
  }

  return SyncModeNotifier(notesRepo, onSyncComplete);
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