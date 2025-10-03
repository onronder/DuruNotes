import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/services/sync/folder_remote_api.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';

// Legacy type alias for backward compatibility
typedef FolderRepository = FolderCoreRepository;

/// Coordinates folder sync operations with conflict resolution
class FolderSyncCoordinator {
  FolderSyncCoordinator({
    required this.repository,
    required FolderRemoteApi remoteApi,
    required this.audit,
    required this.logger,
  }) : _remoteApi = remoteApi;

  final FolderRepository repository;
  final FolderSyncAudit audit;
  final AppLogger logger;
  final FolderRemoteApi _remoteApi;

  // Sync state
  bool _isSyncing = false;
  final _pendingOperations = <String, FolderOperation>{};

  // Conflict resolution cache
  final _conflictCache = <String, ConflictResolution>{};
  static const _conflictCacheExpiry = Duration(minutes: 5);
  final _conflictTimestamps = <String, DateTime>{};

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Create a folder with sync
  Future<String?> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final operationId = 'create_${DateTime.now().millisecondsSinceEpoch}';
    final tempId = _generateTempId();

    try {
      logger.info(
          '🚀 FolderSyncCoordinator: Starting folder creation - name: $name, parentId: $parentId, operationId: $operationId');

      // Start audit
      audit.startOperation(
        operationId,
        FolderSyncEventType.createStarted,
        tempId,
        name,
      );

      // Create locally first
      logger.info('📝 FolderSyncCoordinator: Creating local folder');
      final localFolder = await repository.createLocalFolder(
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
      );

      if (localFolder == null) {
        logger
            .error('❌ FolderSyncCoordinator: createLocalFolder returned null');
        throw Exception('Failed to create local folder');
      }

      logger.info(
          '✅ FolderSyncCoordinator: Local folder created - folderId: ${localFolder.id}, name: ${localFolder.name}');

      // Queue for sync
      _pendingOperations[localFolder.id] = FolderOperation.create(
        folder: localFolder,
        timestamp: DateTime.now(),
      );

      // Try to sync to remote, but don't fail if it doesn't work
      try {
        await _syncFolderToRemote(localFolder, operationId);
        logger.info('📤 FolderSyncCoordinator: Successfully synced to remote');

        // Complete audit for successful sync
        audit.completeOperation(
          operationId,
          FolderSyncEventType.createCompleted,
          localFolder.id,
          name,
        );
      } catch (e) {
        logger.warning(
            '⚠️ FolderSyncCoordinator: Remote sync failed, but local creation succeeded: $e');
        // Don't fail the entire operation - folder was created locally
        // Remote sync will be retried later via pending operations
      }

      return localFolder.id;
    } on Exception catch (e, stack) {
      audit.recordFailure(
        operationId,
        FolderSyncEventType.createFailed,
        tempId,
        e,
        stack,
        name,
      );
      logger.error('Failed to create folder', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Update a folder with sync
  Future<bool> updateFolder({
    required String id,
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final operationId = 'update_${id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Start audit
      audit.startOperation(
        operationId,
        FolderSyncEventType.updateStarted,
        id,
        name,
      );

      // Get current folder for conflict detection
      final currentLocal = await repository.getFolderById(id);
      if (currentLocal == null) {
        throw Exception('Folder not found');
      }

      // Check for conflicts
      final hasConflict = await _checkForConflicts(currentLocal);
      if (hasConflict) {
        final resolved = await _resolveConflict(currentLocal, {
          'name': name,
          'parent_id': parentId,
          'color': color,
          'icon': icon,
          'description': description,
        });

        if (!resolved) {
          throw Exception('Conflict resolution failed');
        }
      }

      // Update locally - updateLocalFolder expects a LocalFolder object
      final existingFolder = await repository.getFolderById(id);
      if (existingFolder == null) {
        throw Exception('Folder not found for update: $id');
      }

      final updatedFolder = LocalFolder(
        id: id,
        name: name,
        parentId: parentId,
        path: existingFolder.path, // Keep existing path
        sortOrder: existingFolder.sortOrder,
        color: color ?? existingFolder.color,
        icon: icon ?? existingFolder.icon,
        description: description ?? existingFolder.description,
        createdAt: existingFolder.createdAt,
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await repository.updateLocalFolder(updatedFolder);

      // Get updated folder
      final refreshedFolder = await repository.getFolderById(id);
      if (refreshedFolder == null) {
        throw Exception('Updated folder not found');
      }

      // Queue for sync
      _pendingOperations[id] = FolderOperation.update(
        folder: updatedFolder,
        timestamp: DateTime.now(),
      );

      // Sync to remote
      await _syncFolderToRemote(updatedFolder, operationId);

      // Complete audit
      audit.completeOperation(
        operationId,
        FolderSyncEventType.updateCompleted,
        id,
        name,
      );

      return true;
    } on Exception catch (e, stack) {
      audit.recordFailure(
        operationId,
        FolderSyncEventType.updateFailed,
        id,
        e,
        stack,
        name,
      );
      logger.error('Failed to update folder', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Delete a folder with sync
  Future<bool> deleteFolder(String id) async {
    final operationId = 'delete_${id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Get folder info for audit
      final folder = await repository.getFolderById(id);
      final folderName = folder?.name;

      // Start audit
      audit.startOperation(
        operationId,
        FolderSyncEventType.deleteStarted,
        id,
        folderName,
      );

      // Delete locally (returns void)
      await repository.deleteLocalFolder(id);

      // Queue for sync
      _pendingOperations[id] = FolderOperation.delete(
        folderId: id,
        timestamp: DateTime.now(),
      );

      // Sync deletion to remote
      await _syncFolderDeletionToRemote(id, operationId);

      // Complete audit
      audit.completeOperation(
        operationId,
        FolderSyncEventType.deleteCompleted,
        id,
        folderName,
      );

      return true;
    } on Exception catch (e, stack) {
      audit.recordFailure(
        operationId,
        FolderSyncEventType.deleteFailed,
        id,
        e,
        stack,
      );
      logger.error('Failed to delete folder', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Sync all pending folder operations
  Future<void> syncAllFolders() async {
    if (_isSyncing) {
      logger.debug('Sync already in progress');
      return;
    }

    final syncId = 'sync_${DateTime.now().millisecondsSinceEpoch}';

    try {
      _isSyncing = true;
      audit.startOperation(syncId, FolderSyncEventType.syncStarted, 'all');

      // Get all local folders
      final localFolders = await repository.getAllFolders();

      // Get all remote folders
      final remoteFolders = await _fetchRemoteFolders();

      // Detect changes
      final changes = _detectChanges(localFolders, remoteFolders);

      // Apply changes with conflict resolution
      for (final change in changes) {
        await _applyChange(change);
      }

      // Process pending operations
      final pendingOps = List<FolderOperation>.from(_pendingOperations.values);
      for (final op in pendingOps) {
        await _processPendingOperation(op);
      }

      audit.completeOperation(syncId, FolderSyncEventType.syncCompleted, 'all');
      logger.info(
        'Folder sync completed',
        data: {
          'localCount': localFolders.length,
          'remoteCount': remoteFolders.length,
          'changesApplied': changes.length,
        },
      );
    } on Exception catch (e, stack) {
      audit.recordFailure(
        syncId,
        FolderSyncEventType.syncFailed,
        'all',
        e,
        stack,
      );
      logger.error('Folder sync failed', error: e, stackTrace: stack);
    } finally {
      _isSyncing = false;
    }
  }

  /// Handle realtime folder update
  Future<void> handleRealtimeUpdate(Map<String, dynamic> payload) async {
    final folderId = payload['id'] as String?;
    if (folderId == null) {
      return;
    }

    audit.recordEvent(
      FolderSyncEvent(
        type: FolderSyncEventType.realtimeReceived,
        timestamp: DateTime.now(),
        folderId: folderId,
        metadata: payload,
      ),
    );

    try {
      // Check if we have a pending operation for this folder
      if (_pendingOperations.containsKey(folderId)) {
        logger.debug(
          'Ignoring realtime update for folder with pending operation',
          data: {'folderId': folderId},
        );
        return;
      }

      // Get local folder
      final localFolder = await repository.getFolderById(folderId);

      if (localFolder == null) {
        // New folder from remote
        await _createFolderFromRemote(payload);
      } else {
        // Check for conflicts
        final hasConflict = await _checkForConflictsWithPayload(
          localFolder,
          payload,
        );
        if (hasConflict) {
          await _resolveConflict(localFolder, payload);
        } else {
          // Apply update
          await _updateFolderFromRemote(localFolder, payload);
        }
      }
    } on Exception catch (e, stack) {
      logger.error(
        'Failed to handle realtime update',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
    }
  }

  // Private methods

  String _generateTempId() {
    return 'temp_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  Future<void> _syncFolderToRemote(
    LocalFolder folder,
    String operationId,
  ) async {
    try {
      await _remoteApi.upsertFolder(folder);

      audit.recordEvent(
        FolderSyncEvent(
          type: FolderSyncEventType.realtimeSent,
          timestamp: DateTime.now(),
          folderId: folder.id,
          folderName: folder.name,
          metadata: {'action': 'upserted'},
        ),
      );

      _pendingOperations.remove(folder.id);
    } catch (e) {
      logger.error(
        'Failed to sync folder to remote',
        error: e,
        data: {'folderId': folder.id},
      );
      rethrow;
    }
  }

  Future<void> _syncFolderDeletionToRemote(
    String folderId,
    String operationId,
  ) async {
    try {
      await _remoteApi.markFolderDeleted(folderId);

      audit.recordEvent(
        FolderSyncEvent(
          type: FolderSyncEventType.realtimeSent,
          timestamp: DateTime.now(),
          folderId: folderId,
          metadata: {'deleted': true},
        ),
      );

      _pendingOperations.remove(folderId);
    } catch (e) {
      logger.error(
        'Failed to sync folder deletion to remote',
        error: e,
        data: {'folderId': folderId},
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteFolders() async {
    return _remoteApi.fetchFolders();
  }

  Future<bool> _checkForConflicts(LocalFolder folder) async {
    final remote = await _remoteApi.fetchFolder(folder.id);
    if (remote == null) {
      return false;
    }

    final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
    return remoteUpdatedAt.isAfter(folder.updatedAt);
  }

  Future<bool> _checkForConflictsWithPayload(
    LocalFolder local,
    Map<String, dynamic> remote,
  ) async {
    final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
    return local.updatedAt.isAfter(
      remoteUpdatedAt.subtract(const Duration(seconds: 1)),
    );
  }

  Future<bool> _resolveConflict(
    LocalFolder local,
    Map<String, dynamic> remote,
  ) async {
    // Check cache
    final cacheKey = '${local.id}_${local.updatedAt.millisecondsSinceEpoch}';
    if (_conflictCache.containsKey(cacheKey)) {
      final cached = _conflictCache[cacheKey]!;
      final timestamp = _conflictTimestamps[cacheKey]!;
      if (DateTime.now().difference(timestamp) < _conflictCacheExpiry) {
        return _applyResolution(local, remote, cached);
      }
    }

    // Determine resolution strategy
    final resolution = _determineResolution(local, remote);

    // Cache decision
    _conflictCache[cacheKey] = resolution;
    _conflictTimestamps[cacheKey] = DateTime.now();

    // Record conflict
    audit.recordConflict(local.id, local, remote, resolution);

    return _applyResolution(local, remote, resolution);
  }

  ConflictResolution _determineResolution(
    LocalFolder local,
    Map<String, dynamic> remote,
  ) {
    // Simple strategy - can be enhanced
    final localHash = _calculateFolderHash(local);
    final remoteHash = _calculateRemoteFolderHash(remote);

    if (localHash == remoteHash) {
      // No real conflict - same content
      return ConflictResolution.localWins;
    }

    // Check timestamps
    final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
    if (local.updatedAt.isAfter(remoteUpdatedAt)) {
      return ConflictResolution.localWins;
    } else {
      return ConflictResolution.remoteWins;
    }
  }

  String _calculateFolderHash(LocalFolder folder) {
    final content =
        '${folder.name}|${folder.parentId}|${folder.color}|${folder.icon}|${folder.description}';
    return md5.convert(utf8.encode(content)).toString();
  }

  String _calculateRemoteFolderHash(Map<String, dynamic> remote) {
    final content =
        '${remote['name']}|${remote['parent_id']}|${remote['color']}|${remote['icon']}|${remote['description']}';
    return md5.convert(utf8.encode(content)).toString();
  }

  Future<bool> _applyResolution(
    LocalFolder local,
    Map<String, dynamic> remote,
    ConflictResolution resolution,
  ) async {
    switch (resolution) {
      case ConflictResolution.localWins:
        // Push local to remote
        await _syncFolderToRemote(local, 'conflict_resolution');
        return true;

      case ConflictResolution.remoteWins:
        // Update local from remote
        await _updateFolderFromRemote(local, remote);
        return true;

      case ConflictResolution.merge:
        // Merge changes (implement merge logic)
        final merged = _mergeFolders(local, remote);
        await repository.updateLocalFolder(merged);
        await _syncFolderToRemote(merged, 'conflict_merge');
        return true;

      case ConflictResolution.manualReview:
        // Queue for manual review
        logger.warning(
          'Folder conflict requires manual review',
          data: {
            'folderId': local.id,
            'localName': local.name,
            'remoteName': remote['name'],
          },
        );
        return false;
    }
  }

  LocalFolder _mergeFolders(LocalFolder local, Map<String, dynamic> remote) {
    // Simple merge - prefer remote for most fields, keep local changes if newer
    // Note: copyWith in drift requires Value() wrapper for nullable fields
    return LocalFolder(
      id: local.id,
      name: remote['name'] as String? ?? local.name,
      parentId: remote['parent_id'] as String?,
      path:
          local.path, // Keep local path, will be recalculated if parent changed
      sortOrder: local.sortOrder,
      color: remote['color'] as String?,
      icon: remote['icon'] as String?,
      description: remote['description'] as String? ?? '',
      createdAt: local.createdAt,
      updatedAt: DateTime.now(),
      deleted: local.deleted,
    );
  }

  List<SyncChange> _detectChanges(
    List<LocalFolder> local,
    List<Map<String, dynamic>> remote,
  ) {
    final changes = <SyncChange>[];
    final localMap = {for (final f in local) f.id: f};
    final remoteMap = {for (final f in remote) f['id'] as String: f};

    // Find updates and deletes
    for (final localFolder in local) {
      if (remoteMap.containsKey(localFolder.id)) {
        final remoteFolder = remoteMap[localFolder.id]!;
        if (_hasChanges(localFolder, remoteFolder)) {
          changes.add(SyncChange.update(localFolder, remoteFolder));
        }
      } else if (!localFolder.deleted) {
        changes.add(SyncChange.delete(localFolder));
      }
    }

    // Find creates
    for (final remoteFolder in remote) {
      final id = remoteFolder['id'] as String;
      if (!localMap.containsKey(id)) {
        changes.add(SyncChange.create(remoteFolder));
      }
    }

    return changes;
  }

  bool _hasChanges(LocalFolder local, Map<String, dynamic> remote) {
    return local.name != remote['name'] ||
        local.parentId != remote['parent_id'] ||
        local.color != remote['color'] ||
        local.icon != remote['icon'] ||
        local.description != remote['description'];
  }

  Future<void> _applyChange(SyncChange change) async {
    switch (change.type) {
      case SyncChangeType.create:
        await _createFolderFromRemote(change.remoteData!);
        break;
      case SyncChangeType.update:
        await _updateFolderFromRemote(change.localFolder!, change.remoteData!);
        break;
      case SyncChangeType.delete:
        await repository.deleteLocalFolder(change.localFolder!.id);
        break;
    }
  }

  Future<void> _createFolderFromRemote(Map<String, dynamic> remote) async {
    // Use createOrUpdateFolder which accepts id parameter for sync
    await repository.createOrUpdateFolder(
      id: remote['id'] as String,
      name: remote['name'] as String,
      parentId: remote['parent_id'] as String?,
      color: remote['color'] as String?,
      icon: remote['icon'] as String?,
      description: remote['description'] as String?,
    );
  }

  Future<void> _updateFolderFromRemote(
    LocalFolder local,
    Map<String, dynamic> remote,
  ) async {
    final updatedFolder = LocalFolder(
      id: local.id,
      name: remote['name'] as String,
      parentId: remote['parent_id'] as String?,
      path: local.path, // Keep existing path
      sortOrder: local.sortOrder,
      color: remote['color'] as String? ?? local.color,
      icon: remote['icon'] as String? ?? local.icon,
      description: remote['description'] as String? ?? local.description,
      createdAt: local.createdAt,
      updatedAt: DateTime.now(),
      deleted: false,
    );

    await repository.updateLocalFolder(updatedFolder);
  }

  Future<void> _processPendingOperation(FolderOperation op) async {
    switch (op.type) {
      case OperationType.create:
      case OperationType.update:
        if (op.folder != null) {
          await _syncFolderToRemote(op.folder!, 'pending_${op.type.name}');
        }
        break;
      case OperationType.delete:
        if (op.folderId != null) {
          await _syncFolderDeletionToRemote(op.folderId!, 'pending_delete');
        }
        break;
    }
  }
}

/// Represents a folder operation
class FolderOperation {
  FolderOperation._({
    required this.type,
    required this.timestamp,
    this.folder,
    this.folderId,
  });

  factory FolderOperation.create({
    required LocalFolder folder,
    required DateTime timestamp,
  }) {
    return FolderOperation._(
      type: OperationType.create,
      folder: folder,
      timestamp: timestamp,
    );
  }

  factory FolderOperation.update({
    required LocalFolder folder,
    required DateTime timestamp,
  }) {
    return FolderOperation._(
      type: OperationType.update,
      folder: folder,
      timestamp: timestamp,
    );
  }

  factory FolderOperation.delete({
    required String folderId,
    required DateTime timestamp,
  }) {
    return FolderOperation._(
      type: OperationType.delete,
      folderId: folderId,
      timestamp: timestamp,
    );
  }

  final OperationType type;
  final DateTime timestamp;
  final LocalFolder? folder;
  final String? folderId;
}

enum OperationType { create, update, delete }

/// Represents a sync change
class SyncChange {
  SyncChange._({required this.type, this.localFolder, this.remoteData});

  factory SyncChange.create(Map<String, dynamic> remoteData) {
    return SyncChange._(type: SyncChangeType.create, remoteData: remoteData);
  }

  factory SyncChange.update(
    LocalFolder localFolder,
    Map<String, dynamic> remoteData,
  ) {
    return SyncChange._(
      type: SyncChangeType.update,
      localFolder: localFolder,
      remoteData: remoteData,
    );
  }

  factory SyncChange.delete(LocalFolder localFolder) {
    return SyncChange._(type: SyncChangeType.delete, localFolder: localFolder);
  }

  final SyncChangeType type;
  final LocalFolder? localFolder;
  final Map<String, dynamic>? remoteData;
}

enum SyncChangeType { create, update, delete }
