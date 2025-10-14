import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/infrastructure/adapters/service_adapter.dart';
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/sync/sync_coordinator.dart';

/// Sync result with detailed information
class SyncResult {
  const SyncResult({
    required this.success,
    this.message,
    this.syncedNotes = 0,
    this.syncedTasks = 0,
    this.conflicts = const [],
    this.errors = const [],
  });

  final bool success;
  final String? message;
  final int syncedNotes;
  final int syncedTasks;
  final List<SyncConflict> conflicts;
  final List<String> errors;
}

/// Represents a sync conflict
class SyncConflict {
  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
    required this.resolution,
  });

  final String entityType;
  final String entityId;
  final DateTime localVersion;
  final DateTime remoteVersion;
  final ConflictResolution resolution;
}

enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  skip,
}

/// Task mapping for bidirectional sync
class TaskMapping {
  const TaskMapping({
    required this.taskId,
    required this.lineNumber,
    required this.checksum,
    required this.embeddedId,
  });

  final String taskId;
  final int lineNumber;
  final String checksum;
  final String? embeddedId;
}

/// Unified sync service supporting both domain and legacy models
class UnifiedSyncService {
  static final UnifiedSyncService _instance = UnifiedSyncService._internal();
  factory UnifiedSyncService() => _instance;
  UnifiedSyncService._internal();

  final _logger = LoggerFactory.instance;
  final _uuid = const Uuid();

  AppDb? _db;
  SupabaseClient? _client;
  MigrationConfig? _migrationConfig;
  ServiceAdapter? _adapter;
  CryptoBox? _cryptoBox;

  // Domain repositories
  INotesRepository? _domainNotesRepo;
  ITaskRepository? _domainTasksRepo;

  // Sync state - now managed by coordinator
  final SyncCoordinator _syncCoordinator = SyncCoordinator();
  DateTime? _lastSyncTime;
  final Set<String> _activeSyncOperations = {};

  // Initialization tracking
  bool _isInitialized = false;

  // Sync configuration
  bool _enableBidirectionalTaskSync = true;

  // MEMORY OPTIMIZATION: Batch size for iOS (lower than Android due to stricter memory limits)
  static const int _syncBatchSize = 5; // Process 5 notes at a time to prevent memory spikes

  void _captureSyncException({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('service', 'UnifiedSyncService');
          scope.setTag('operation', operation);
          data?.forEach((key, value) {
            scope.setExtra(key, value);
          });
        },
      ),
    );
  }

  Future<void> initialize({
    required AppDb database,
    required SupabaseClient client,
    required MigrationConfig migrationConfig,
    INotesRepository? domainNotesRepo,
    ITaskRepository? domainTasksRepo,
    KeyManager? keyManager,
    CryptoBox? cryptoBox,
  }) async {
    // Prevent re-initialization
    if (_isInitialized) {
      _logger.debug('UnifiedSyncService already initialized, skipping');
      return;
    }

    _db = database;
    _client = client;
    _migrationConfig = migrationConfig;
    _domainNotesRepo = domainNotesRepo;
    _domainTasksRepo = domainTasksRepo;

    _adapter = ServiceAdapter(
      db: database,
      client: client,
      useDomainModels: migrationConfig.isFeatureEnabled('notes'),
    );

    // Use provided CryptoBox or throw error if not provided
    // This should be initialized by the providers that already exist in the app
    if (cryptoBox == null) {
      throw ArgumentError('CryptoBox must be provided for encryption');
    }
    _cryptoBox = cryptoBox;

    _isInitialized = true;
    _logger.info('UnifiedSyncService initialized with CryptoBox encryption');
  }

  /// Check if currently syncing
  bool get isSyncing => _syncCoordinator.isSyncing;

  /// Check if service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Configure sync settings
  void configure({
    int? maxRetries,
    Duration? retryDelay,
    bool? enableBidirectionalTaskSync,
  }) {
    // maxRetries and retryDelay parameters kept for API compatibility but not stored
    if (enableBidirectionalTaskSync != null) {
      _enableBidirectionalTaskSync = enableBidirectionalTaskSync;
    }
  }

  /// Main sync method
  Future<SyncResult> syncAll() async {
    try {
      return await _syncCoordinator.executeSync<SyncResult>(
        'unified_sync_all',
        () => _performSyncAll(),
        allowConcurrentTypes: false, // Full sync requires exclusive access
      );
    } on SyncAlreadyRunningException catch (error, stack) {
      _logger.warning('Unified sync already in progress');
      _captureSyncException(
        operation: 'syncAll.alreadyRunning',
        error: error,
        stackTrace: stack,
        level: SentryLevel.warning,
      );
      return SyncResult(
        success: false,
        message: 'Unified sync already in progress',
      );
    } on SyncConcurrencyException catch (error, stack) {
      _logger.warning(
        'Unified sync blocked by other active syncs: ${error.activeSyncs}',
      );
      _captureSyncException(
        operation: 'syncAll.concurrency',
        error: error,
        stackTrace: stack,
        level: SentryLevel.warning,
        data: {'activeSyncs': error.activeSyncs},
      );
      return SyncResult(
        success: false,
        message: 'Sync blocked by other active operations: ${error.activeSyncs}',
      );
    } on SyncRateLimitedException catch (error, stack) {
      _logger.warning(
        'Unified sync rate limited: ${error.timeSinceLastSync.inMilliseconds}ms since last',
      );
      _captureSyncException(
        operation: 'syncAll.rateLimited',
        error: error,
        stackTrace: stack,
        level: SentryLevel.warning,
        data: {
          'timeSinceLastSyncMs': error.timeSinceLastSync.inMilliseconds,
        },
      );
      return SyncResult(
        success: false,
        message: 'Sync rate limited, try again in a moment',
      );
    }
  }

  Future<SyncResult> _performSyncAll() async {
    final startTime = DateTime.now();

    try {
      // CRITICAL: Check initialization before syncing
      if (!_isInitialized || _db == null || _client == null || _migrationConfig == null) {
        _logger.error('UnifiedSyncService not properly initialized');
        return SyncResult(
          success: false,
          message: 'Sync service not initialized',
          errors: ['Service not initialized - please restart the app'],
        );
      }

      _logger.info('Starting full sync');

      // Sync in order: folders -> notes -> tasks
      final folderResult = await _syncFolders();
      final noteResult = await _syncNotes();
      final taskResult = await _syncTasks();

      // Combine results
      final allConflicts = [
        ...folderResult.conflicts,
        ...noteResult.conflicts,
        ...taskResult.conflicts,
      ];

      final allErrors = [
        ...folderResult.errors,
        ...noteResult.errors,
        ...taskResult.errors,
      ];

      _lastSyncTime = DateTime.now();
      final duration = _lastSyncTime!.difference(startTime);

      _logger.info('Sync completed in ${duration.inSeconds}s');
      _logger.info('Synced: ${noteResult.syncedNotes} notes, ${taskResult.syncedTasks} tasks');

      return SyncResult(
        success: allErrors.isEmpty,
        message: allErrors.isEmpty
            ? 'Sync completed successfully'
            : 'Sync completed with ${allErrors.length} errors',
        syncedNotes: noteResult.syncedNotes,
        syncedTasks: taskResult.syncedTasks,
        conflicts: allConflicts,
        errors: allErrors,
      );

    } catch (error, stack) {
      _logger.error('Unified sync failed', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'performSyncAll',
        error: error,
        stackTrace: stack,
      );
      return SyncResult(
        success: false,
        message: 'Sync failed: ${error.toString()}',
        errors: [error.toString()],
      );
    }
  }

  /// Sync folders
  Future<SyncResult> _syncFolders() async {
    final toUpload = <dynamic>[];
    final toDownload = <Map<String, dynamic>>[];
    final conflicts = <SyncConflict>[];

    try {
      _logger.debug('Syncing folders');

      // Get local and remote folders
      final localFolders = await _getLocalFolders();
      final remoteFolders = await _getRemoteFolders();

      // Compare and categorize
      for (final local in localFolders) {
        final localId = _getFolderId(local);
        final remote = remoteFolders.firstWhere(
          (r) => r['id'] == localId,
          orElse: () => <String, dynamic>{},
        );

        if (remote.isEmpty) {
          toUpload.add(local);
        } else {
          final conflict = _detectConflict(local, remote, 'folder');
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }

      for (final remote in remoteFolders) {
        final remoteId = remote['id'] as String;
        final hasLocal = localFolders.any((l) => _getFolderId(l) == remoteId);
        if (!hasLocal) {
          toDownload.add(remote);
        }
      }

      // Sync changes
      await _uploadFolders(toUpload);
      await _downloadFolders(toDownload);

      return SyncResult(
        success: true,
        conflicts: conflicts,
      );

    } catch (error, stack) {
      _logger.error('Folder sync failed', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'syncFolders',
        error: error,
        stackTrace: stack,
        data: {
          'pendingUploads': toUpload.length,
          'pendingDownloads': toDownload.length,
        },
      );
      return SyncResult(
        success: false,
        errors: ['Folder sync failed: ${error.toString()}'],
      );
    }
  }

  /// Sync notes with conflict resolution
  Future<SyncResult> _syncNotes() async {
    final toUpload = <dynamic>[];
    final toDownload = <Map<String, dynamic>>[];
    final conflicts = <SyncConflict>[];

    try {
      _logger.debug('Syncing notes');

      // Get local and remote notes
      final localNotes = await _getLocalNotes();
      final remoteNotes = await _getRemoteNotes();

      _logger.info('🔍 SYNC DEBUG: Found ${localNotes.length} local notes, ${remoteNotes.length} remote notes');
      _logger.debug('🔍 SYNC DEBUG: Found ${localNotes.length} local notes, ${remoteNotes.length} remote notes');

      // Compare and categorize
      for (final local in localNotes) {
        final localId = _getNoteId(local);
        final remote = remoteNotes.firstWhere(
          (r) => r['id'] == localId,
          orElse: () => <String, dynamic>{},
        );

        if (remote.isEmpty) {
          _logger.info('📤 UPLOAD: Note $localId exists locally but not remotely');
          _logger.debug('📤 UPLOAD: Note $localId exists locally but not remotely');
          toUpload.add(local);
        } else {
          final conflict = _detectConflict(local, remote, 'note');
          if (conflict != null) {
            conflicts.add(conflict);
            // Auto-resolve based on strategy
            final resolved = await _resolveConflict(conflict, local, remote);
            if (resolved != null) {
              toUpload.add(resolved);
            }
          }
        }
      }

      for (final remote in remoteNotes) {
        final remoteId = remote['id'] as String;
        final hasLocal = localNotes.any((l) => _getNoteId(l) == remoteId);
        if (!hasLocal) {
          _logger.info('📥 DOWNLOAD: Note $remoteId exists remotely but not locally');
          toDownload.add(remote);
        }
      }

      _logger.info('🔄 SYNC SUMMARY: Uploading ${toUpload.length} notes, Downloading ${toDownload.length} notes');
      _logger.debug('🔄 SYNC SUMMARY: Uploading ${toUpload.length} notes, Downloading ${toDownload.length} notes');

      // Sync changes
      await _uploadNotes(toUpload);
      await _downloadNotes(toDownload);

      // Sync embedded tasks if enabled
      if (_enableBidirectionalTaskSync) {
        for (final note in localNotes) {
          await _syncEmbeddedTasks(_getNoteId(note));
        }
      }

      return SyncResult(
        success: true,
        syncedNotes: toUpload.length + toDownload.length,
        conflicts: conflicts,
      );

    } catch (error, stack) {
      _logger.error('Note sync failed', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'syncNotes',
        error: error,
        stackTrace: stack,
        data: {
          'pendingUploads': toUpload.length,
          'pendingDownloads': toDownload.length,
        },
      );
      return SyncResult(
        success: false,
        errors: ['Note sync failed: ${error.toString()}'],
      );
    }
  }

  /// Sync tasks
  Future<SyncResult> _syncTasks() async {
    final toUpload = <dynamic>[];
    final toDownload = <Map<String, dynamic>>[];
    final conflicts = <SyncConflict>[];

    try {
      _logger.debug('Syncing tasks');

      // Get local and remote tasks
      final localTasks = await _getLocalTasks();
      final remoteTasks = await _getRemoteTasks();

      // Compare and sync
      for (final local in localTasks) {
        final localId = _getTaskId(local);
        final remote = remoteTasks.firstWhere(
          (r) => r['id'] == localId,
          orElse: () => <String, dynamic>{},
        );

        if (remote.isEmpty) {
          toUpload.add(local);
        } else {
          final conflict = _detectConflict(local, remote, 'task');
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }

      for (final remote in remoteTasks) {
        final remoteId = remote['id'] as String;
        final hasLocal = localTasks.any((l) => _getTaskId(l) == remoteId);
        if (!hasLocal) {
          toDownload.add(remote);
        }
      }

      // Sync changes
      await _uploadTasks(toUpload);
      await _downloadTasks(toDownload);

      return SyncResult(
        success: true,
        syncedTasks: toUpload.length + toDownload.length,
        conflicts: conflicts,
      );

    } catch (error, stack) {
      _logger.error('Task sync failed', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'syncTasks',
        error: error,
        stackTrace: stack,
        data: {
          'pendingUploads': toUpload.length,
          'pendingDownloads': toDownload.length,
        },
      );
      return SyncResult(
        success: false,
        errors: ['Task sync failed: ${error.toString()}'],
      );
    }
  }

  /// Bidirectional task sync within note content
  Future<void> _syncEmbeddedTasks(String noteId) async {
    if (!_enableBidirectionalTaskSync) return;

    // Prevent recursive sync loops
    if (_activeSyncOperations.contains(noteId)) {
      _logger.debug('Sync already active for note: $noteId');
      return;
    }

    _activeSyncOperations.add(noteId);

    try {
      final note = await _getNoteById(noteId);
      if (note == null) return;

      final content = _getNoteContent(note);
      final tasks = await _getNoteTasks(noteId);

      // Extract task lines from content
      final taskPattern = RegExp(r'^(\s*)-\s*\[([x ])\]\s*(.+?)(?:\s*<!--\s*task:([a-f0-9-]+)\s*-->)?$', multiLine: true);
      final matches = taskPattern.allMatches(content);

      final updatedContent = StringBuffer();
      int lastIndex = 0;

      for (final match in matches) {
        // Add content before the match
        updatedContent.write(content.substring(lastIndex, match.start));

        final indent = match.group(1) ?? '';
        final isCompleted = match.group(2) == 'x';
        final taskText = match.group(3) ?? '';
        final embeddedId = match.group(4);

        // Find or create corresponding task
        dynamic task;
        if (embeddedId != null) {
          task = tasks.firstWhere(
            (t) => _getTaskId(t) == embeddedId,
            orElse: () => null,
          );
        }

        if (task == null) {
          // Create new task
          final newTaskId = _uuid.v4();
          task = await _createTask(
            id: newTaskId,
            noteId: noteId,
            title: taskText,
            completed: isCompleted,
          );

          // PRODUCTION FIX: Don't add task IDs to user-visible content
          // Task IDs should only exist in the database, not in note content
          updatedContent.write('$indent- [${isCompleted ? 'x' : ' '}] $taskText');
        } else {
          // Update existing task
          final taskCompleted = _isTaskCompleted(task);
          if (taskCompleted != isCompleted) {
            await _updateTaskCompletion(_getTaskId(task), isCompleted);
          }

          // Write the original line without task ID metadata
          final matchText = match.group(0) ?? '';
          // Remove any existing task ID comments from the line
          final cleanedLine = matchText.replaceAll(RegExp(r'\s*<!--\s*task:[a-f0-9-]+\s*-->'), '');
          updatedContent.write(cleanedLine);
        }

        lastIndex = match.end;
      }

      // Add remaining content
      updatedContent.write(content.substring(lastIndex));

      // Update note if content changed
      final newContent = updatedContent.toString();
      if (newContent != content) {
        await _updateNoteContent(noteId, newContent);
      }

      // PRODUCTION FIX: Don't inject task IDs into note content
      // Tasks should be managed separately in the database
      // User content should remain clean without metadata comments

    } catch (error, stack) {
      _logger.error('Failed to sync embedded tasks for note: $noteId', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'syncEmbeddedTasks',
        error: error,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
    } finally {
      _activeSyncOperations.remove(noteId);
    }
  }

  // Conflict detection and resolution
  SyncConflict? _detectConflict(dynamic local, Map<String, dynamic> remote, String entityType) {
    try {
      DateTime localUpdated;
      DateTime remoteUpdated;

      switch (entityType) {
        case 'note':
          localUpdated = _getNoteUpdatedAt(local);
          remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          break;
        case 'task':
          localUpdated = _getTaskUpdatedAt(local);
          remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          break;
        case 'folder':
          localUpdated = _getFolderUpdatedAt(local);
          remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          break;
        default:
          return null;
      }

      // If times differ significantly, there's a conflict
      if (localUpdated.difference(remoteUpdated).abs() > const Duration(seconds: 5)) {
        return SyncConflict(
          entityType: entityType,
          entityId: remote['id'] as String,
          localVersion: localUpdated,
          remoteVersion: remoteUpdated,
          resolution: localUpdated.isAfter(remoteUpdated)
              ? ConflictResolution.useLocal
              : ConflictResolution.useRemote,
        );
      }

      return null;
    } catch (error, stack) {
      _logger.error('Failed to detect conflict', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'detectConflict',
        error: error,
        stackTrace: stack,
        data: {'entityType': entityType},
        level: SentryLevel.warning,
      );
      return null;
    }
  }

  Future<dynamic> _resolveConflict(
    SyncConflict conflict,
    dynamic local,
    Map<String, dynamic> remote,
  ) async {
    switch (conflict.resolution) {
      case ConflictResolution.useLocal:
        return local;
      case ConflictResolution.useRemote:
        // Convert remote to local format
        return null; // Would need conversion logic
      case ConflictResolution.merge:
        // Implement merge logic
        return local; // For now, default to local
      case ConflictResolution.skip:
        return null;
    }
  }

  // Data fetching methods
  Future<List<dynamic>> _getLocalNotes() async {
    final notesEnabled = _migrationConfig!.isFeatureEnabled('notes');
    final repoAvailable = _domainNotesRepo != null;
    _logger.debug('🔍 _getLocalNotes: notes enabled=$notesEnabled, repo available=$repoAvailable');

    if (notesEnabled && repoAvailable) {
      final notes = await _domainNotesRepo!.localNotes();
      _logger.debug('🔍 Domain repo returned ${notes.length} notes');
      return notes;
    } else {
      final notes = await _db!.select(_db!.localNotes).get();
      _logger.debug('🔍 Drift DB returned ${notes.length} notes');
      return notes;
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteNotes() async {
    try {
      // Use proper encrypted note API with decryption
      final api = SupabaseNoteApi(_client!);
      final encryptedNotes = await api.fetchEncryptedNotes();
      final userId = _client!.auth.currentUser?.id;

      if (userId == null) {
        _logger.error('No authenticated user for decryption');
        return [];
      }

      _logger.info('📥 Fetching and decrypting ${encryptedNotes.length} remote notes (batch size: $_syncBatchSize)...');

      // MEMORY OPTIMIZATION: Decrypt notes in batches to prevent memory spikes
      final List<Map<String, dynamic>> notes = [];
      int decryptionErrors = 0;

      for (int i = 0; i < encryptedNotes.length; i += _syncBatchSize) {
        final end = (i + _syncBatchSize).clamp(0, encryptedNotes.length);
        final batch = encryptedNotes.sublist(i, end);

        _logger.debug('📦 Decrypting batch ${(i ~/ _syncBatchSize) + 1}/${(encryptedNotes.length / _syncBatchSize).ceil()}: notes $i-${end - 1}');

        for (final note in batch) {
          try {
            final noteId = note['id'] as String;
            final titleEnc = note['title_enc'] as Uint8List;
            final propsEnc = note['props_enc'] as Uint8List;

            // Decrypt title using CryptoBox (same as existing working code)
            String title;
            try {
              final titleJson = await _cryptoBox!.decryptJsonForNote(
                userId: userId,
                noteId: noteId,
                data: titleEnc,
              );
              title = titleJson['title'] as String? ?? '';
            } catch (e) {
              // Fallback: try as plain string
              try {
                title = await _cryptoBox!.decryptStringForNote(
                  userId: userId,
                  noteId: noteId,
                  data: titleEnc,
                );
              } catch (_) {
                title = 'Untitled (Decryption Failed)';
                decryptionErrors++;
              }
            }

            // Decrypt props using CryptoBox
            String body;
            List<String> tags;
            bool isPinned;

            try {
              final propsJson = await _cryptoBox!.decryptJsonForNote(
                userId: userId,
                noteId: noteId,
                data: propsEnc,
              );
              body = propsJson['body'] as String? ?? '';
              tags = (propsJson['tags'] as List?)?.cast<String>() ?? [];
              isPinned = propsJson['isPinned'] as bool? ?? false;
            } catch (e) {
              // Fallback: try with legacy key
              try {
                final result = await _cryptoBox!.decryptJsonForNoteWithFallback(
                  userId: userId,
                  noteId: noteId,
                  data: propsEnc,
                );
                body = result.value['body'] as String? ?? '';
                tags = (result.value['tags'] as List?)?.cast<String>() ?? [];
                isPinned = result.value['isPinned'] as bool? ?? false;
                // Legacy key detection removed - no sensitive logging
              } catch (_) {
                body = 'Content could not be decrypted';
                tags = [];
                isPinned = false;
                decryptionErrors++;
              }
            }

            notes.add({
              'id': noteId,
              'title': title,
              'body': body,
              'folder_id': null, // Will be handled separately
              'is_pinned': isPinned,
              'tags': tags,
              'created_at': note['created_at'],
              'updated_at': note['updated_at'],
              'deleted': note['deleted'] ?? false,
              'user_id': note['user_id'],
            });
          } catch (error, stack) {
            _logger.error('Failed to decrypt note ${note['id']}: $error', stackTrace: stack);
            _captureSyncException(
              operation: 'decryptRemoteNote',
              error: error,
              stackTrace: stack,
              data: {'noteId': note['id']},
              level: SentryLevel.warning,
            );
            decryptionErrors++;
          }
        }

        // MEMORY OPTIMIZATION: Allow garbage collection between batches
        if (i + _syncBatchSize < encryptedNotes.length) {
          _logger.debug('⏸️  Batch decrypted, allowing GC before next batch...');
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      if (decryptionErrors > 0) {
        _logger.warning('Encountered $decryptionErrors decryption errors during sync');
      }

      _logger.info('✅ Fetched and decrypted ${notes.length} remote notes');
      return notes;
    } catch (error, stack) {
      _logger.error('Failed to fetch remote notes', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'getRemoteNotes',
        error: error,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<dynamic>> _getLocalTasks() async {
    if (_migrationConfig!.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      return await _domainTasksRepo!.getAllTasks();
    } else {
      return await _db!.select(_db!.noteTasks).get();
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteTasks() async {
    try {
      final userId = _client!.auth.currentUser?.id;
      if (userId == null) {
        _logger.error('Cannot fetch tasks without authenticated user');
        return [];
      }

      final response = await _client!
          .from('note_tasks')
          .select()
          .eq('user_id', userId)  // CRITICAL: Filter by user_id for data isolation
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (error, stack) {
      _logger.error('Failed to fetch remote tasks', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'getRemoteTasks',
        error: error,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<dynamic>> _getLocalFolders() async {
    if (_migrationConfig!.isFeatureEnabled('folders')) {
      // Would need folder repository
      return [];
    } else {
      return await _db!.select(_db!.localFolders).get();
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteFolders() async {
    try {
      final userId = _client!.auth.currentUser?.id;
      if (userId == null) {
        _logger.error('Cannot fetch folders without authenticated user');
        return [];
      }

      final response = await _client!
          .from('folders')
          .select()
          .eq('user_id', userId)  // CRITICAL: Filter by user_id for data isolation
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (error, stack) {
      _logger.error('Failed to fetch remote folders', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'getRemoteFolders',
        error: error,
        stackTrace: stack,
      );
      return [];
    }
  }

  // Upload methods
  Future<void> _uploadNotes(List<dynamic> notes) async {
    if (notes.isEmpty) {
      _logger.info('⏭️ UPLOAD SKIP: No notes to upload');
      _logger.debug('⏭️ UPLOAD SKIP: No notes to upload');
      return;
    }

    _logger.info('📤 UPLOADING ${notes.length} notes to remote (batch size: $_syncBatchSize)...');
    _logger.debug('📤 UPLOADING ${notes.length} notes to remote (batch size: $_syncBatchSize)...');

    try {
      // Use SupabaseNoteApi with CryptoBox to encrypt notes before uploading
      final api = SupabaseNoteApi(_client!);
      final userId = _client!.auth.currentUser?.id;

      if (userId == null) {
        _logger.error('❌ UPLOAD FAILED: No authenticated user for encryption');
        return;
      }

      // MEMORY OPTIMIZATION: Process notes in batches to prevent memory spikes
      int uploadedCount = 0;
      for (int i = 0; i < notes.length; i += _syncBatchSize) {
        final end = (i + _syncBatchSize).clamp(0, notes.length);
        final batch = notes.sublist(i, end);

        _logger.debug('📦 Processing batch ${(i ~/ _syncBatchSize) + 1}/${(notes.length / _syncBatchSize).ceil()}: notes $i-${end - 1}');

        for (final note in batch) {
          final noteData = _adapter!.getNoteDataForSync(note);
          final noteId = noteData['id'] as String;
          _logger.info('📤 Uploading note: $noteId (title: ${noteData['title']})');
          _logger.debug('📤 Uploading note: $noteId (title: ${noteData['title']})');

          // Encrypt title using CryptoBox (same as existing working code)
          final encryptedTitle = await _cryptoBox!.encryptJsonForNote(
            userId: userId,
            noteId: noteId,
            json: {'title': noteData['title'] ?? ''},
          );

          // Encrypt props using CryptoBox
          // COMPATIBILITY: Read 'body' first, fall back to 'content'
          final propsJson = <String, dynamic>{
            'body': (noteData['body'] ?? noteData['content'] ?? ''),
            'tags': (noteData['tags'] ?? <Map<String, dynamic>>[]),
            'isPinned': (noteData['is_pinned'] ?? false),
            'updatedAt': DateTime.now().toIso8601String(),
          };

          final encryptedProps = await _cryptoBox!.encryptJsonForNote(
            userId: userId,
            noteId: noteId,
            json: propsJson,
          );

          // Upload using the encrypted API
          await api.upsertEncryptedNote(
            id: noteId,
            titleEnc: encryptedTitle,
            propsEnc: encryptedProps,
            deleted: (noteData['deleted'] ?? false) as bool,
          );
          _logger.info('✅ Successfully uploaded note: $noteId');
          uploadedCount++;
        }

        // MEMORY OPTIMIZATION: Allow garbage collection between batches
        if (i + _syncBatchSize < notes.length) {
          _logger.debug('⏸️  Batch complete, allowing GC before next batch...');
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      _logger.info('✅ UPLOAD COMPLETE: Uploaded $uploadedCount encrypted notes');
    } catch (error, stack) {
      _logger.error('❌ UPLOAD FAILED: Failed to upload notes', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'uploadNotes',
        error: error,
        stackTrace: stack,
        data: {'attemptedUploads': notes.length},
      );
      rethrow;
    }
  }

  Future<void> _uploadTasks(List<dynamic> tasks) async {
    if (tasks.isEmpty) return;

    try {
      final data = tasks.map((task) => _adapter!.getTaskDataForSync(task)).toList();
      await _client!.from('note_tasks').upsert(data);
      _logger.debug('Uploaded ${tasks.length} tasks');
    } catch (error, stack) {
      _logger.error('Failed to upload tasks', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'uploadTasks',
        error: error,
        stackTrace: stack,
        data: {'attemptedUploads': tasks.length},
      );
      rethrow;
    }
  }

  Future<void> _uploadFolders(List<dynamic> folders) async {
    if (folders.isEmpty) return;

    try {
      final data = folders.map((folder) => _adapter!.getFolderDataForSync(folder)).toList();
      await _client!.from('folders').upsert(data);
      _logger.debug('Uploaded ${folders.length} folders');
    } catch (error, stack) {
      _logger.error('Failed to upload folders', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'uploadFolders',
        error: error,
        stackTrace: stack,
        data: {'attemptedUploads': folders.length},
      );
      rethrow;
    }
  }

  // Download methods
  Future<void> _downloadNotes(List<Map<String, dynamic>> notes) async {
    if (notes.isEmpty) return;

    try {
      for (final noteData in notes) {
        // Save through appropriate repository
        if (_migrationConfig!.isFeatureEnabled('notes') && _domainNotesRepo != null) {
          // Use createOrUpdate with proper parameters
          await _domainNotesRepo!.createOrUpdate(
            title: noteData['title'] as String? ?? '',
            body: noteData['body'] as String? ?? '',
            id: noteData['id'] as String?,
            folderId: noteData['folder_id'] as String?,
            tags: (noteData['tags'] as List?)?.cast<String>() ?? [],
            isPinned: noteData['is_pinned'] as bool?,
          );
        } else {
          // For local notes, save directly to database using adapter
          final note = _adapter!.createNoteFromSync(noteData);
          final localNote = note as LocalNote;
          await _db!.into(_db!.localNotes).insertOnConflictUpdate(localNote);
        }
      }
      _logger.debug('Downloaded ${notes.length} notes');
    } catch (error, stack) {
      _logger.error('Failed to download notes', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'downloadNotes',
        error: error,
        stackTrace: stack,
        data: {'attemptedDownloads': notes.length},
      );
      rethrow;
    }
  }

  Future<void> _downloadTasks(List<Map<String, dynamic>> tasks) async {
    if (tasks.isEmpty) return;

    try {
      for (final taskData in tasks) {
        final task = _adapter!.createTaskFromSync(taskData);
        // Save through appropriate repository
        if (_migrationConfig!.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
          await _domainTasksRepo!.createTask(task as domain.Task);
        } else {
          // For local tasks, save directly to database
          final noteTask = task as NoteTask;
          await _db!.into(_db!.noteTasks).insertOnConflictUpdate(noteTask);
        }
      }
      _logger.debug('Downloaded ${tasks.length} tasks');
    } catch (error, stack) {
      _logger.error('Failed to download tasks', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'downloadTasks',
        error: error,
        stackTrace: stack,
        data: {'attemptedDownloads': tasks.length},
      );
      rethrow;
    }
  }

  Future<void> _downloadFolders(List<Map<String, dynamic>> folders) async {
    if (folders.isEmpty) return;

    try {
      for (final folderData in folders) {
        final folder = _adapter!.createFolderFromSync(folderData);

        // Handle both domain.Folder and LocalFolder types correctly
        LocalFolder localFolder;
        if (folder is domain.Folder) {
          // Convert domain folder to LocalFolder using mapper
          localFolder = FolderMapper.toInfrastructure(folder);
        } else if (folder is LocalFolder) {
          localFolder = folder;
        } else {
          _logger.error('Unknown folder type: ${folder.runtimeType}');
          continue;
        }

        await _db!.into(_db!.localFolders).insertOnConflictUpdate(localFolder);
      }
      _logger.debug('Downloaded ${folders.length} folders');
    } catch (error, stack) {
      _logger.error('Failed to download folders', error: error, stackTrace: stack);
      _captureSyncException(
        operation: 'downloadFolders',
        error: error,
        stackTrace: stack,
        data: {'attemptedDownloads': folders.length},
      );
      rethrow;
    }
  }

  // Helper methods for working with different model types
  Future<dynamic> _getNoteById(String id) async {
    if (_migrationConfig!.isFeatureEnabled('notes') && _domainNotesRepo != null) {
      return await _domainNotesRepo!.getNoteById(id);
    } else {
      return await _db!.getNote(id);
    }
  }

  Future<List<dynamic>> _getNoteTasks(String noteId) async {
    if (_migrationConfig!.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      return await _domainTasksRepo!.getTasksForNote(noteId);
    } else {
      return await _db!.getTasksForNote(noteId);
    }
  }

  Future<dynamic> _createTask({
    required String id,
    required String noteId,
    required String title,
    required bool completed,
  }) async {
    if (_migrationConfig!.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      final now = DateTime.now();
      final task = domain.Task(
        id: id,
        noteId: noteId,
        title: title,
        description: null,
        status: completed ? domain.TaskStatus.completed : domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: completed ? now : null,
        createdAt: now,
        updatedAt: now,
        tags: [],
        metadata: {},
      );
      await _domainTasksRepo!.createTask(task);
      return task;
    } else {
      await _db!.into(_db!.noteTasks).insert(
        NoteTasksCompanion(
          id: Value(id),
          noteId: Value(noteId),
          contentEncrypted: Value(title), // Tasks use encrypted content now
          status: Value(completed ? TaskStatus.completed : TaskStatus.open),
          deleted: const Value(false),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return await _db!.getTaskById(id);
    }
  }

  Future<void> _updateTaskCompletion(String taskId, bool completed) async {
    if (_migrationConfig!.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      final task = await _domainTasksRepo!.getTaskById(taskId);
      if (task != null) {
        await _domainTasksRepo!.updateTask(
          task.copyWith(
            status: completed ? domain.TaskStatus.completed : domain.TaskStatus.pending,
            completedAt: completed ? DateTime.now() : null,
          ),
        );
      }
    } else {
      await (_db!.update(_db!.noteTasks)
            ..where((t) => t.id.equals(taskId)))
          .write(NoteTasksCompanion(
            status: Value(completed ? TaskStatus.completed : TaskStatus.open),
            completedAt: Value(completed ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ));
    }
  }

  Future<void> _updateNoteContent(String noteId, String content) async {
    if (_migrationConfig!.isFeatureEnabled('notes') && _domainNotesRepo != null) {
      final note = await _domainNotesRepo!.getNoteById(noteId);
      if (note != null) {
        // Use createOrUpdate with all required fields
        await _domainNotesRepo!.createOrUpdate(
          title: note.title,
          body: content,
          id: note.id,
          folderId: note.folderId,
          tags: note.tags,
          links: note.links.map((l) => {
            'sourceId': l.sourceId,
            'targetTitle': l.targetTitle,
            'targetId': l.targetId,
          }).toList(),
          isPinned: note.isPinned,
        );
      }
    } else {
      await _db!.updateNote(
        noteId,
        LocalNotesCompanion(
          bodyEncrypted: Value(content), // Notes use encrypted body now
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // Type-agnostic property accessors
  String _getNoteId(dynamic note) {
    if (note is domain.Note) return note.id;
    if (note is LocalNote) return note.id;
    throw ArgumentError('Unknown note type');
  }

  String _getNoteContent(dynamic note) {
    if (note is domain.Note) return note.body;
    if (note is LocalNote) return note.bodyEncrypted ?? '';
    throw ArgumentError('Unknown note type');
  }

  DateTime _getNoteUpdatedAt(dynamic note) {
    if (note is domain.Note) return note.updatedAt;
    if (note is LocalNote) return note.updatedAt;
    throw ArgumentError('Unknown note type');
  }

  String _getTaskId(dynamic task) {
    if (task is domain.Task) return task.id;
    if (task is NoteTask) return task.id;
    throw ArgumentError('Unknown task type');
  }

  String _getTaskTitle(dynamic task) {
    if (task is domain.Task) return task.title;
    if (task is NoteTask) return task.contentEncrypted ?? '';
    throw ArgumentError('Unknown task type');
  }

  bool _isTaskCompleted(dynamic task) {
    if (task is domain.Task) return task.status == domain.TaskStatus.completed;
    if (task is NoteTask) return task.status == TaskStatus.completed;
    throw ArgumentError('Unknown task type');
  }

  DateTime _getTaskUpdatedAt(dynamic task) {
    // Tasks don't have updatedAt, use completedAt or dueDate as fallback
    if (task is domain.Task) return task.completedAt ?? task.dueDate ?? DateTime.now();
    if (task is NoteTask) return task.completedAt ?? task.dueDate ?? DateTime.now();
    throw ArgumentError('Unknown task type');
  }

  String _getFolderId(dynamic folder) {
    if (folder is domain.Folder) return folder.id;
    if (folder is LocalFolder) return folder.id;
    throw ArgumentError('Unknown folder type');
  }

  DateTime _getFolderUpdatedAt(dynamic folder) {
    if (folder is domain.Folder) return folder.updatedAt;
    if (folder is LocalFolder) return folder.updatedAt;
    throw ArgumentError('Unknown folder type');
  }

}
