import 'dart:async';

import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';

/// Sync service that provides backwards compatibility
/// This wraps the UnifiedSyncService for legacy code compatibility
class SyncService {
  final INotesRepository repository;
  final UnifiedSyncService _unifiedSyncService;

  /// Stream of sync changes for UI updates
  final StreamController<void> _changesController = StreamController<void>.broadcast();
  Stream<void> get changes => _changesController.future;

  SyncService(this.repository)
    : _unifiedSyncService = UnifiedSyncService() {

    // TODO: Initialize UnifiedSyncService properly
    // Forward sync events to our changes stream
    // _unifiedSyncService.syncStatusStream.listen((_) {
    //   _changesController.add(null);
    // });
  }

  /// Start realtime sync with optional unified service
  void startRealtime({UnifiedRealtimeService? unifiedService}) {
    // TODO: Start realtime connections
    // _unifiedSyncService.startRealtime();
  }

  /// Sync if online
  Future<void> syncIfOnline() async {
    try {
      await repository.sync();
      _changesController.add(null);
    } catch (e) {
      // Log but don't rethrow to maintain compatibility
      // print('Sync failed: $e');
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

  /// Check if currently syncing
  bool get isSyncing => false; // TODO: Implement sync status tracking

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return repository.getLastSyncTime();
  }

  /// Sync notes specifically
  Future<void> syncNotes() async {
    await repository.sync();
    _changesController.add(null);
  }

  /// Sync folders specifically
  Future<void> syncFolders() async {
    // TODO: Implement folder sync using repository
    _changesController.add(null);
  }

  /// Sync now (alias for sync method)
  Future<void> syncNow() async {
    await sync();
  }

  /// Stop all sync operations
  void stopRealtime() {
    // TODO: Stop realtime connections
  }

  /// Dispose resources
  void dispose() {
    _changesController.close();
    // TODO: Dispose unified sync service properly
  }
}