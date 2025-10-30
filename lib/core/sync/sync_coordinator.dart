import 'dart:async';
import 'package:flutter/foundation.dart';

/// Unified sync coordinator to prevent race conditions across all sync services
/// Ensures only one sync operation can run at a time system-wide
class SyncCoordinator {
  static final SyncCoordinator _instance = SyncCoordinator._internal();
  factory SyncCoordinator() => _instance;
  SyncCoordinator._internal();

  final Map<String, Completer<void>?> _activeSyncs = {};
  final Map<String, DateTime> _lastSyncTimes = {};
  // Increased from 2s to 10s to prevent excessive sync calls (especially from realtime events)
  static const Duration _minSyncInterval = Duration(seconds: 10);

  /// Check if any sync operation is currently running
  bool get isSyncing =>
      _activeSyncs.values.any((completer) => completer != null);

  /// Check if a specific sync type is running
  bool isSyncingType(String syncType) => _activeSyncs[syncType] != null;

  /// Execute a sync operation with proper locking
  Future<T> executeSync<T>(
    String syncType,
    Future<T> Function() syncOperation, {
    bool allowConcurrentTypes = false,
  }) async {
    // Check rate limiting
    final lastSync = _lastSyncTimes[syncType];
    if (lastSync != null) {
      final timeSinceLastSync = DateTime.now().difference(lastSync);
      if (timeSinceLastSync < _minSyncInterval) {
        debugPrint(
          '🚫 Sync rate limited: $syncType (${timeSinceLastSync.inMilliseconds}ms since last)',
        );
        throw SyncRateLimitedException(syncType, timeSinceLastSync);
      }
    }

    // Check for concurrent operations
    if (!allowConcurrentTypes && isSyncing) {
      final activeSyncTypes = _activeSyncs.entries
          .where((entry) => entry.value != null)
          .map((entry) => entry.key)
          .toList();
      debugPrint('🚫 Sync blocked: $syncType (active: $activeSyncTypes)');
      throw SyncConcurrencyException(syncType, activeSyncTypes);
    }

    if (isSyncingType(syncType)) {
      debugPrint('🚫 Sync already running: $syncType');
      throw SyncAlreadyRunningException(syncType);
    }

    // Start the sync operation
    final completer = Completer<void>();
    _activeSyncs[syncType] = completer;
    _lastSyncTimes[syncType] = DateTime.now();

    debugPrint('🔄 Starting sync: $syncType');

    try {
      final result = await syncOperation();
      debugPrint('✅ Sync completed: $syncType');
      return result;
    } catch (error, stackTrace) {
      debugPrint('❌ Sync failed: $syncType - $error\n$stackTrace');
      rethrow;
    } finally {
      // Always cleanup, even on error
      _activeSyncs[syncType] = null;
      completer.complete();
    }
  }

  /// Wait for all sync operations to complete
  Future<void> waitForAllSyncs() async {
    final activeCompleters = _activeSyncs.values
        .where((completer) => completer != null)
        .cast<Completer<void>>()
        .toList();

    if (activeCompleters.isNotEmpty) {
      debugPrint(
        '⏳ Waiting for ${activeCompleters.length} active syncs to complete',
      );
      await Future.wait(activeCompleters.map((c) => c.future));
    }
  }

  /// Wait for a specific sync type to complete
  Future<void> waitForSync(String syncType) async {
    final completer = _activeSyncs[syncType];
    if (completer != null) {
      debugPrint('⏳ Waiting for sync to complete: $syncType');
      await completer.future;
    }
  }

  /// Force cancel all sync operations (emergency use only)
  void cancelAllSyncs() {
    debugPrint('🛑 Emergency: Cancelling all sync operations');
    for (final entry in _activeSyncs.entries) {
      if (entry.value != null) {
        debugPrint('🛑 Cancelled sync: ${entry.key}');
        entry.value!.complete();
      }
    }
    _activeSyncs.clear();
  }

  /// Get sync status for monitoring
  Map<String, dynamic> getSyncStatus() {
    final activeSyncs = _activeSyncs.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key)
        .toList();

    return {
      'is_syncing': isSyncing,
      'active_syncs': activeSyncs,
      'last_sync_times': Map.fromEntries(
        _lastSyncTimes.entries.map(
          (entry) => MapEntry(entry.key, entry.value.toIso8601String()),
        ),
      ),
    };
  }
}

/// Exception thrown when sync operation is rate limited
class SyncRateLimitedException implements Exception {
  const SyncRateLimitedException(this.syncType, this.timeSinceLastSync);
  final String syncType;
  final Duration timeSinceLastSync;

  @override
  String toString() =>
      'SyncRateLimitedException: $syncType rate limited '
      '(${timeSinceLastSync.inMilliseconds}ms since last sync)';
}

/// Exception thrown when sync operation conflicts with another running sync
class SyncConcurrencyException implements Exception {
  const SyncConcurrencyException(this.syncType, this.activeSyncs);
  final String syncType;
  final List<String> activeSyncs;

  @override
  String toString() =>
      'SyncConcurrencyException: $syncType blocked by active syncs: $activeSyncs';
}

/// Exception thrown when the same sync type is already running
class SyncAlreadyRunningException implements Exception {
  const SyncAlreadyRunningException(this.syncType);
  final String syncType;

  @override
  String toString() =>
      'SyncAlreadyRunningException: $syncType is already running';
}
