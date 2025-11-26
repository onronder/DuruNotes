import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider, loggerProvider;
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show authStateChangesProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskRepositoryProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show keyManagerProvider, cryptoBoxProvider;
import 'package:duru_notes/services/providers/services_providers.dart'
    show quickCaptureServiceProvider;
import 'package:duru_notes/services/connection_manager.dart';
import 'package:duru_notes/services/sync/folder_remote_api.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified sync service provider - replaces old SyncService
/// Properly initializes the singleton with all required dependencies
///
/// CRITICAL FIX: Prevent multiple initialization of singleton by using StateProvider
/// The singleton pattern with late final fields cannot be re-initialized
final unifiedSyncServiceProvider = Provider<UnifiedSyncService>((ref) {
  // PRODUCTION FIX #5: Keep provider alive to prevent disposal/recreation cycles
  ref.keepAlive();

  // Get the singleton instance
  final service = UnifiedSyncService();

  // Only initialize once - check if already initialized
  if (service.isInitialized) {
    debugPrint('[Sync] UnifiedSyncService already initialized');
    return service;
  }

  debugPrint('[Sync] Initializing UnifiedSyncService for the first time');

  // Watch auth state to rebuild when auth changes (but don't re-initialize)
  ref.watch(authStateChangesProvider);

  // Get all required dependencies for initialization
  final appDb = ref.watch(appDbProvider);
  final supabase = Supabase.instance.client;
  final migrationConfig = ref.watch(migrationConfigProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final cryptoBox = ref.watch(cryptoBoxProvider);
  // Use domain repository - always available
  // Repository handles auth internally
  final notesRepo = ref.watch(notesCoreRepositoryProvider);
  final tasksRepo = ref.watch(taskRepositoryProvider);
  // Widget integration
  final quickCaptureService = ref.watch(quickCaptureServiceProvider);

  // Initialize the service with all dependencies
  service
      .initialize(
        database: appDb,
        client: supabase,
        migrationConfig: migrationConfig,
        domainNotesRepo: notesRepo,
        domainTasksRepo: tasksRepo,
        keyManager: keyManager,
        cryptoBox: cryptoBox,
        quickCaptureService: quickCaptureService,
      )
      .catchError((Object error) {
        debugPrint('[Sync] Failed to initialize UnifiedSyncService: $error');
      });

  // Get unified realtime service if available
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);

  // PRODUCTION FIX #4: Trigger automatic sync when realtime events arrive
  // PERFORMANCE FIX: Add debouncing to prevent sync spam from rapid realtime events
  if (unifiedRealtime != null) {
    Timer? realtimeSyncDebounceTimer;

    void onRealtimeEvent() {
      if (service.isInitialized) {
        // Cancel any pending debounced sync
        realtimeSyncDebounceTimer?.cancel();

        // Debounce: wait 2 seconds before syncing
        // This prevents rapid-fire syncs when multiple realtime events arrive
        realtimeSyncDebounceTimer = Timer(const Duration(seconds: 2), () {
          debugPrint(
            '[Sync] 📡 Realtime event (debounced) - triggering automatic sync',
          );
          service.syncAll().catchError((Object error) {
            debugPrint('[Sync] Auto-sync from realtime event failed: $error');
            // Return a failed sync result for error handler
            return SyncResult(
              success: false,
              message: error.toString(),
              errors: [error.toString()],
            );
          });
        });
      }
    }

    // Listen to realtime service notifications
    unifiedRealtime.addListener(onRealtimeEvent);

    // Clean up listener and timer on dispose
    ref.onDispose(() {
      realtimeSyncDebounceTimer?.cancel();
      unifiedRealtime.removeListener(onRealtimeEvent);
      debugPrint(
        '[Sync] Removed realtime listener and cancelled debounce timer',
      );
    });
  }

  // Invalidate providers when service state changes
  ref.onDispose(() {
    // Note: Don't dispose singleton service
    debugPrint('[Sync] Provider disposed');
  });

  return service;
});

/// Sync mode provider - simplified without old NotesRepository
///
/// CRITICAL FIX: Uses autoDispose to prevent disposal errors during logout
/// When user logs out, SecurityInitialization is cleared and this provider
/// needs to be disposed immediately before trying to rebuild with invalid dependencies
final syncModeProvider = StateNotifierProvider.autoDispose<SyncModeNotifier, SyncMode>((
  ref,
) {
  // Use domain repository - always available when security is initialized
  // Repository handles auth internally and returns empty data when not authenticated
  final notesRepo = ref.watch(notesCoreRepositoryProvider);

  // CRITICAL FIX: Get unified sync service to pass to SyncModeNotifier
  final syncService = ref.watch(unifiedSyncServiceProvider);

  // SyncModeNotifier requires concrete NotesCoreRepository
  // CRITICAL FIX: Pass sync service without callback - cache invalidation is handled in SyncModeNotifier
  // No callback needed - the repository will invalidate its own cache after sync
  return SyncModeNotifier(notesRepo, syncService);
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
  final crypto = ref.watch(cryptoBoxProvider);
  return SupabaseFolderRemoteApi(
    client: client,
    logger: logger,
    crypto: crypto,
  );
});

/// PRODUCTION FIX: Returns null when user not authenticated
final folderSyncCoordinatorProvider = Provider<FolderSyncCoordinator?>((ref) {
  final repository = ref.watch(folderRepositoryProvider);

  // PRODUCTION FIX: Return null when repository is null (user not authenticated)
  if (repository == null) {
    return null;
  }

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
final unifiedRealtimeServiceProvider = ChangeNotifierProvider<UnifiedRealtimeService?>((
  ref,
) {
  // PRODUCTION FIX #5: Keep provider alive to prevent disposal/recreation cycles
  ref.keepAlive();

  // Track current service instance for proper cleanup
  UnifiedRealtimeService? currentService;

  // CRITICAL FIX: Register disposal callback at provider level, not inside .when()
  // This prevents "Cannot call onDispose after provider was dispose" error
  ref.onDispose(() {
    debugPrint('[Providers] Disposing unified realtime service');
    currentService?.dispose();
  });

  // Watch auth state to properly manage lifecycle
  final authStateAsync = ref.watch(authStateChangesProvider);

  return authStateAsync.when(
    data: (authState) {
      // Dispose previous service if it exists (auth state changed)
      if (currentService != null) {
        debugPrint(
          '[Providers] Auth state changed - disposing old realtime service',
        );
        currentService!.dispose();
        currentService = null;
      }

      // Return null if not authenticated
      if (authState.session == null) {
        debugPrint(
          '[Providers] No session - unified realtime service not created',
        );
        return null;
      }

      final userId = authState.session!.user.id;
      final logger = ref.watch(loggerProvider);
      final folderSyncCoordinator = ref.watch(folderSyncCoordinatorProvider);

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

      // Track this service instance for cleanup
      currentService = service;

      return service;
    },
    loading: () {
      // Dispose service when loading (shouldn't happen often)
      if (currentService != null) {
        debugPrint('[Providers] Auth loading - disposing realtime service');
        currentService!.dispose();
        currentService = null;
      }
      return null;
    },
    error: (error, stack) {
      debugPrint('[Providers] Auth state error: $error');
      // Dispose service on error
      if (currentService != null) {
        debugPrint('[Providers] Auth error - disposing realtime service');
        currentService!.dispose();
        currentService = null;
      }
      return null;
    },
  );
});
