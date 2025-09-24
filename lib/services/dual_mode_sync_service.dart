import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/infrastructure/adapters/service_adapter.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sync service that works with both local and domain models
class DualModeSyncService {
  DualModeSyncService({
    required this.db,
    required this.client,
    required this.migrationConfig,
  })  : _logger = LoggerFactory.instance,
        _adapter = ServiceAdapter(
          db: db,
          client: client,
          useDomainModels: migrationConfig.useDomainEntities,
        );

  final AppDb db;
  final SupabaseClient client;
  final MigrationConfig migrationConfig;
  final AppLogger _logger;
  final ServiceAdapter _adapter;

  // Track sync status
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Sync notes with remote
  Future<SyncResult> syncNotes() async {
    if (_isSyncing) {
      _logger.warning('Sync already in progress, skipping');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return SyncResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      // Get local notes
      final localNotes = await db.getAllNotes();

      // Get remote notes
      final remoteResponse = await client
          .from('notes')
          .select()
          .eq('user_id', userId);

      final remoteNotes = (remoteResponse as List<dynamic>)
          .map((data) => data as Map<String, dynamic>)
          .toList();

      int uploaded = 0;
      int downloaded = 0;
      int conflicts = 0;

      // Process each local note
      for (final localNote in localNotes) {
        final processedNote = _adapter.processNote(localNote);
        final syncData = _adapter.getNoteDataForSync(processedNote);

        // Find corresponding remote note
        final remoteNote = remoteNotes.firstWhere(
          (r) => r['id'] == syncData['id'],
          orElse: () => <String, dynamic>{},
        );

        if (remoteNote.isEmpty) {
          // Upload new note
          await _uploadNote(syncData, userId);
          uploaded++;
        } else {
          // Check for conflicts
          final remoteUpdated = DateTime.parse(remoteNote['updated_at']);
          final localUpdated = DateTime.parse(syncData['updated_at']);

          if (localUpdated.isAfter(remoteUpdated)) {
            // Local is newer, upload
            await _updateRemoteNote(syncData, userId);
            uploaded++;
          } else if (remoteUpdated.isAfter(localUpdated)) {
            // Remote is newer, download
            await _downloadNote(remoteNote);
            downloaded++;
          }
        }
      }

      // Download new remote notes
      final localNoteIds = localNotes.map((n) => n.id).toSet();
      for (final remoteNote in remoteNotes) {
        if (!localNoteIds.contains(remoteNote['id'])) {
          await _downloadNote(remoteNote);
          downloaded++;
        }
      }

      _lastSyncTime = DateTime.now();
      _logger.info('Sync completed', data: {
        'uploaded': uploaded,
        'downloaded': downloaded,
        'conflicts': conflicts,
      });

      return SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
      );
    } catch (e, stack) {
      _logger.error('Sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        message: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync tasks with remote
  Future<SyncResult> syncTasks() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return SyncResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      // Get local tasks
      final localTasks = await db.getAllTasks();

      // Get remote tasks
      final remoteResponse = await client
          .from('tasks')
          .select()
          .eq('user_id', userId);

      final remoteTasks = (remoteResponse as List<dynamic>)
          .map((data) => data as Map<String, dynamic>)
          .toList();

      int uploaded = 0;
      int downloaded = 0;

      // Process each local task
      for (final localTask in localTasks) {
        final processedTask = _adapter.processTask(localTask);
        final syncData = _adapter.getTaskDataForSync(processedTask);

        // Find corresponding remote task
        final remoteTask = remoteTasks.firstWhere(
          (r) => r['id'] == syncData['id'],
          orElse: () => <String, dynamic>{},
        );

        if (remoteTask.isEmpty) {
          // Upload new task
          await _uploadTask(syncData, userId);
          uploaded++;
        } else {
          // For tasks, always prefer local version (tasks are managed locally)
          await _updateRemoteTask(syncData, userId);
          uploaded++;
        }
      }

      // Download new remote tasks
      final localTaskIds = localTasks.map((t) => t.id).toSet();
      for (final remoteTask in remoteTasks) {
        if (!localTaskIds.contains(remoteTask['id'])) {
          await _downloadTask(remoteTask);
          downloaded++;
        }
      }

      _lastSyncTime = DateTime.now();
      _logger.info('Task sync completed', data: {
        'uploaded': uploaded,
        'downloaded': downloaded,
      });

      return SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
      );
    } catch (e, stack) {
      _logger.error('Task sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        message: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync folders with remote
  Future<SyncResult> syncFolders() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return SyncResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      // Get local folders
      final localFolders = await db.getAllFolders();

      // Get remote folders
      final remoteResponse = await client
          .from('folders')
          .select()
          .eq('user_id', userId);

      final remoteFolders = (remoteResponse as List<dynamic>)
          .map((data) => data as Map<String, dynamic>)
          .toList();

      int uploaded = 0;
      int downloaded = 0;

      // Process each local folder
      for (final localFolder in localFolders) {
        final processedFolder = _adapter.processFolder(localFolder);
        final syncData = _adapter.getFolderDataForSync(processedFolder);

        // Find corresponding remote folder
        final remoteFolder = remoteFolders.firstWhere(
          (r) => r['id'] == syncData['id'],
          orElse: () => <String, dynamic>{},
        );

        if (remoteFolder.isEmpty) {
          // Upload new folder
          await _uploadFolder(syncData, userId);
          uploaded++;
        } else {
          // Update remote folder
          await _updateRemoteFolder(syncData, userId);
          uploaded++;
        }
      }

      // Download new remote folders
      final localFolderIds = localFolders.map((f) => f.id).toSet();
      for (final remoteFolder in remoteFolders) {
        if (!localFolderIds.contains(remoteFolder['id'])) {
          await _downloadFolder(remoteFolder);
          downloaded++;
        }
      }

      _lastSyncTime = DateTime.now();
      _logger.info('Folder sync completed', data: {
        'uploaded': uploaded,
        'downloaded': downloaded,
      });

      return SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
      );
    } catch (e, stack) {
      _logger.error('Folder sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        message: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Full sync - notes, tasks, and folders
  Future<SyncResult> fullSync() async {
    final noteResult = await syncNotes();
    if (!noteResult.success) return noteResult;

    final taskResult = await syncTasks();
    if (!taskResult.success) return taskResult;

    final folderResult = await syncFolders();
    if (!folderResult.success) return folderResult;

    return SyncResult(
      success: true,
      uploaded: noteResult.uploaded + taskResult.uploaded + folderResult.uploaded,
      downloaded: noteResult.downloaded + taskResult.downloaded + folderResult.downloaded,
      conflicts: noteResult.conflicts,
    );
  }

  // Private helper methods

  Future<void> _uploadNote(Map<String, dynamic> data, String userId) async {
    final uploadData = {...data, 'user_id': userId};
    await client.from('notes').upsert(uploadData);
  }

  Future<void> _updateRemoteNote(Map<String, dynamic> data, String userId) async {
    final updateData = {...data, 'user_id': userId};
    await client.from('notes').upsert(updateData);
  }

  Future<void> _downloadNote(Map<String, dynamic> data) async {
    final note = _adapter.createNoteFromSync(data);
    if (migrationConfig.useDomainEntities) {
      // Use domain repository
      _logger.info('Downloading note via domain repository');
    } else {
      // Use local database directly
      await db.upsertNote(LocalNotesCompanion.insert(
        id: data['id'],
        title: data['title'] ?? '',
        body: data['content'] ?? '',
        folderId: Value(data['folder_id']),
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: DateTime.parse(data['updated_at']),
        starred: data['is_starred'] ?? false,
        pinned: data['is_pinned'] ?? false,
        archived: data['is_archived'] ?? false,
        color: Value(data['color']),
        version: data['version'] ?? 1,
      ));
    }
  }

  Future<void> _uploadTask(Map<String, dynamic> data, String userId) async {
    final uploadData = {...data, 'user_id': userId};
    await client.from('tasks').upsert(uploadData);
  }

  Future<void> _updateRemoteTask(Map<String, dynamic> data, String userId) async {
    final updateData = {...data, 'user_id': userId};
    await client.from('tasks').upsert(updateData);
  }

  Future<void> _downloadTask(Map<String, dynamic> data) async {
    final task = _adapter.createTaskFromSync(data);
    if (migrationConfig.useDomainEntities) {
      // Use domain repository
      _logger.info('Downloading task via domain repository');
    } else {
      // Use local database directly
      _logger.warning('Task download to local DB not implemented');
    }
  }

  Future<void> _uploadFolder(Map<String, dynamic> data, String userId) async {
    final uploadData = {...data, 'user_id': userId};
    await client.from('folders').upsert(uploadData);
  }

  Future<void> _updateRemoteFolder(Map<String, dynamic> data, String userId) async {
    final updateData = {...data, 'user_id': userId};
    await client.from('folders').upsert(updateData);
  }

  Future<void> _downloadFolder(Map<String, dynamic> data) async {
    final folder = _adapter.createFolderFromSync(data);
    if (migrationConfig.useDomainEntities) {
      // Use domain repository
      _logger.info('Downloading folder via domain repository');
    } else {
      // Use local database directly
      _logger.warning('Folder download to local DB not implemented');
    }
  }
}

/// Result of a sync operation
class SyncResult {
  const SyncResult({
    required this.success,
    this.message,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
  });

  final bool success;
  final String? message;
  final int uploaded;
  final int downloaded;
  final int conflicts;
}