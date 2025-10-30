import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// DEPRECATED: Legacy sync service - use UnifiedSyncService instead
///
/// This service has incomplete implementations and TODO stubs.
/// Migrate to UnifiedSyncService for:
/// - Complete sync functionality with encryption support
/// - Conflict resolution and bidirectional sync
/// - Memory-optimized batch processing
/// - Support for notes, tasks, and folders
///
/// Migration example:
/// ```dart
/// // Old:
/// final syncService = SyncService(repository);
/// await syncService.sync();
///
/// // New:
/// final unifiedSync = ref.watch(unifiedSyncServiceProvider);
/// final result = await unifiedSync.syncAll();
/// if (result.success) {
///   // Sync completed
/// }
/// ```
@Deprecated(
  'Use UnifiedSyncService instead. This service will be removed in a future version.',
)
class SyncService {
  final INotesRepository repository;
  final AppLogger _logger = LoggerFactory.instance;

  /// Stream of sync changes for UI updates
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  Stream<void> get changes => _changesController.stream;

  SyncService(this.repository);

  /// DEPRECATED: Start realtime sync - use UnifiedRealtimeService directly
  @Deprecated('Use UnifiedRealtimeService instead')
  void startRealtime({UnifiedRealtimeService? unifiedService}) {
    throw UnimplementedError(
      'SyncService.startRealtime() is deprecated. '
      'Use UnifiedRealtimeService directly:\n'
      '  final realtimeService = ref.watch(unifiedRealtimeServiceProvider);\n'
      '  realtimeService.startRealtime();',
    );
  }

  /// Sync if online
  Future<void> syncIfOnline() async {
    try {
      await repository.sync();
      _changesController.add(null);

      _logger.info('[SyncService] Sync completed successfully');
    } catch (e, stack) {
      // Log with full context for debugging production issues
      _logger.error(
        '[SyncService] Sync failed',
        error: e,
        stackTrace: stack,
        data: {'operation': 'syncIfOnline', 'deprecated': true},
      );

      // Report to Sentry for critical sync failures
      await Sentry.captureException(
        e,
        stackTrace: stack,
        hint: Hint.withMap({
          'context': 'SyncService.syncIfOnline (deprecated)',
        }),
      );

      // Don't rethrow to maintain backward compatibility
      // Callers can check last sync time to detect failures
    }
  }

  /// Basic sync method for compatibility
  Future<void> sync() async {
    await syncIfOnline();
  }

  /// Force sync regardless of connection status
  Future<void> forceSync() async {
    await repository.sync();
    _changesController.add(null);
  }

  /// DEPRECATED: Check if currently syncing - use UnifiedSyncService instead
  @Deprecated('Use UnifiedSyncService.isSyncing instead')
  bool get isSyncing {
    // Always return false since this service doesn't track sync state
    // Use UnifiedSyncService for proper sync status tracking
    return false;
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return repository.getLastSyncTime();
  }

  /// Sync notes specifically
  Future<void> syncNotes() async {
    await repository.sync();
    _changesController.add(null);
  }

  /// DEPRECATED: Sync folders - use UnifiedSyncService instead
  @Deprecated('Use UnifiedSyncService.syncAll() instead')
  Future<void> syncFolders() async {
    throw UnimplementedError(
      'SyncService.syncFolders() is not implemented. '
      'Use UnifiedSyncService for folder sync:\n'
      '  final unifiedSync = ref.watch(unifiedSyncServiceProvider);\n'
      '  final result = await unifiedSync.syncAll(); // Syncs folders, notes, and tasks',
    );
  }

  /// Sync now (alias for sync method)
  Future<void> syncNow() async {
    await sync();
  }

  /// DEPRECATED: Stop realtime sync - use UnifiedRealtimeService directly
  @Deprecated('Use UnifiedRealtimeService instead')
  void stopRealtime() {
    throw UnimplementedError(
      'SyncService.stopRealtime() is deprecated. '
      'Use UnifiedRealtimeService directly:\n'
      '  final realtimeService = ref.watch(unifiedRealtimeServiceProvider);\n'
      '  realtimeService.stopRealtime();',
    );
  }

  /// Dispose resources
  void dispose() {
    _changesController.close();
    // Note: UnifiedSyncService doesn't require disposal
  }
}
