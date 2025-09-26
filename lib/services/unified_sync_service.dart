import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/core/sync/sync_coordinator.dart';
import 'package:duru_notes/core/sync/transaction_manager.dart';

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

  late final AppDb _db;
  late final SupabaseClient _client;
  late final MigrationConfig _migrationConfig;
  late final ServiceAdapter _adapter;
  late final CryptoBox _cryptoBox;
  late final KeyManager _keyManager;

  // Domain repositories
  INotesRepository? _domainNotesRepo;
  ITaskRepository? _domainTasksRepo;

  // Sync state - now managed by coordinator
  final SyncCoordinator _syncCoordinator = SyncCoordinator();
  late final TransactionManager _transactionManager;
  DateTime? _lastSyncTime;
  final Set<String> _activeSyncOperations = {};

  // Task sync caches
  final Map<String, List<TaskMapping>> _taskMappingCache = {};
  final Map<String, Map<int, String>> _embeddedIdCache = {};

  // Sync configuration
  int _maxRetries = 3;
  Duration _retryDelay = const Duration(seconds: 2);
  bool _enableBidirectionalTaskSync = true;

  Future<void> initialize({
    required AppDb database,
    required SupabaseClient client,
    required MigrationConfig migrationConfig,
    INotesRepository? domainNotesRepo,
    ITaskRepository? domainTasksRepo,
    KeyManager? keyManager,
    CryptoBox? cryptoBox,
  }) async {
    _db = database;
    _client = client;
    _migrationConfig = migrationConfig;
    _domainNotesRepo = domainNotesRepo;
    _domainTasksRepo = domainTasksRepo;
    _transactionManager = TransactionManager(database);

    _adapter = ServiceAdapter(
      db: database,
      client: client,
      useDomainModels: migrationConfig.isFeatureEnabled('notes'),
    );

    // Use provided KeyManager/CryptoBox or throw error if not provided
    // These should be initialized by the providers that already exist in the app
    if (keyManager == null || cryptoBox == null) {
      throw ArgumentError('KeyManager and CryptoBox must be provided for encryption');
    }
    _keyManager = keyManager;
    _cryptoBox = cryptoBox;

    _logger.info('UnifiedSyncService initialized with CryptoBox encryption');
  }

  /// Check if currently syncing
  bool get isSyncing => _syncCoordinator.isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Configure sync settings
  void configure({
    int? maxRetries,
    Duration? retryDelay,
    bool? enableBidirectionalTaskSync,
  }) {
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelay != null) _retryDelay = retryDelay;
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
    } on SyncAlreadyRunningException {
      _logger.warning('Unified sync already in progress');
      return SyncResult(
        success: false,
        message: 'Unified sync already in progress',
      );
    } on SyncConcurrencyException catch (e) {
      _logger.warning('Unified sync blocked by other active syncs: ${e.activeSyncs}');
      return SyncResult(
        success: false,
        message: 'Sync blocked by other active operations: ${e.activeSyncs}',
      );
    } on SyncRateLimitedException catch (e) {
      _logger.warning('Unified sync rate limited: ${e.timeSinceLastSync.inMilliseconds}ms since last');
      return SyncResult(
        success: false,
        message: 'Sync rate limited, try again in a moment',
      );
    }
  }

  Future<SyncResult> _performSyncAll() async {
    final startTime = DateTime.now();

    try {
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

    } catch (e, stack) {
      _logger.error('Unified sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
        errors: [e.toString()],
      );
    }
  }

  /// Sync folders
  Future<SyncResult> _syncFolders() async {
    try {
      _logger.debug('Syncing folders');

      // Get local and remote folders
      final localFolders = await _getLocalFolders();
      final remoteFolders = await _getRemoteFolders();

      // Detect changes
      final toUpload = <dynamic>[];
      final toDownload = <Map<String, dynamic>>[];
      final conflicts = <SyncConflict>[];

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

    } catch (e, stack) {
      _logger.error('Folder sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        errors: ['Folder sync failed: ${e.toString()}'],
      );
    }
  }

  /// Sync notes with conflict resolution
  Future<SyncResult> _syncNotes() async {
    try {
      _logger.debug('Syncing notes');

      // Get local and remote notes
      final localNotes = await _getLocalNotes();
      final remoteNotes = await _getRemoteNotes();

      final toUpload = <dynamic>[];
      final toDownload = <Map<String, dynamic>>[];
      final conflicts = <SyncConflict>[];

      // Compare and categorize
      for (final local in localNotes) {
        final localId = _getNoteId(local);
        final remote = remoteNotes.firstWhere(
          (r) => r['id'] == localId,
          orElse: () => <String, dynamic>{},
        );

        if (remote.isEmpty) {
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
          toDownload.add(remote);
        }
      }

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

    } catch (e, stack) {
      _logger.error('Note sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        errors: ['Note sync failed: ${e.toString()}'],
      );
    }
  }

  /// Sync tasks
  Future<SyncResult> _syncTasks() async {
    try {
      _logger.debug('Syncing tasks');

      // Get local and remote tasks
      final localTasks = await _getLocalTasks();
      final remoteTasks = await _getRemoteTasks();

      final toUpload = <dynamic>[];
      final toDownload = <Map<String, dynamic>>[];
      final conflicts = <SyncConflict>[];

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

    } catch (e, stack) {
      _logger.error('Task sync failed', error: e, stackTrace: stack);
      return SyncResult(
        success: false,
        errors: ['Task sync failed: ${e.toString()}'],
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

          // Add embedded ID
          updatedContent.write('$indent- [${isCompleted ? 'x' : ' '}] $taskText <!-- task:$newTaskId -->');
        } else {
          // Update existing task
          final taskCompleted = _isTaskCompleted(task);
          if (taskCompleted != isCompleted) {
            await _updateTaskCompletion(_getTaskId(task), isCompleted);
          }

          updatedContent.write(match.group(0));
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

      // Sync tasks back to content
      for (final task in tasks) {
        final taskId = _getTaskId(task);
        if (!content.contains('task:$taskId')) {
          // Task exists in DB but not in content - add it
          final taskTitle = _getTaskTitle(task);
          final taskCompleted = _isTaskCompleted(task);
          final taskLine = '- [${taskCompleted ? 'x' : ' '}] $taskTitle <!-- task:$taskId -->';

          await _updateNoteContent(
            noteId,
            '$newContent\n$taskLine',
          );
        }
      }

    } catch (e, stack) {
      _logger.error('Failed to sync embedded tasks for note: $noteId', error: e, stackTrace: stack);
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
    } catch (e) {
      _logger.error('Failed to detect conflict', error: e);
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
    if (_migrationConfig.isFeatureEnabled('notes') && _domainNotesRepo != null) {
      return await _domainNotesRepo!.localNotes();
    } else {
      return await _db.select(_db.localNotes).get();
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteNotes() async {
    try {
      // Use proper encrypted note API with decryption
      final api = SupabaseNoteApi(_client);
      final encryptedNotes = await api.fetchEncryptedNotes();
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        _logger.error('No authenticated user for decryption');
        return [];
      }

      // Decrypt and convert encrypted notes using CryptoBox (the working system)
      final List<Map<String, dynamic>> notes = [];
      int decryptionErrors = 0;

      for (final note in encryptedNotes) {
        try {
          final noteId = note['id'] as String;
          final titleEnc = note['title_enc'] as Uint8List;
          final propsEnc = note['props_enc'] as Uint8List;

          // Decrypt title using CryptoBox (same as existing working code)
          String title;
          try {
            final titleJson = await _cryptoBox.decryptJsonForNote(
              userId: userId,
              noteId: noteId,
              data: titleEnc,
            );
            title = titleJson['title'] as String? ?? '';
          } catch (e) {
            // Fallback: try as plain string
            try {
              title = await _cryptoBox.decryptStringForNote(
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
            final propsJson = await _cryptoBox.decryptJsonForNote(
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
              final result = await _cryptoBox.decryptJsonForNoteWithFallback(
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
        } catch (e) {
          _logger.error('Failed to decrypt note ${note['id']}: $e');
          decryptionErrors++;
        }
      }

      if (decryptionErrors > 0) {
        _logger.warning('Encountered $decryptionErrors decryption errors during sync');
      }

      _logger.info('Fetched and decrypted ${notes.length} remote notes');
      return notes;
    } catch (e, stack) {
      _logger.error('Failed to fetch remote notes', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<dynamic>> _getLocalTasks() async {
    if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      return await _domainTasksRepo!.getAllTasks();
    } else {
      return await _db.select(_db.noteTasks).get();
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteTasks() async {
    try {
      final response = await _client
          .from('tasks')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      _logger.error('Failed to fetch remote tasks', error: e);
      return [];
    }
  }

  Future<List<dynamic>> _getLocalFolders() async {
    if (_migrationConfig.isFeatureEnabled('folders')) {
      // Would need folder repository
      return [];
    } else {
      return await _db.select(_db.localFolders).get();
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteFolders() async {
    try {
      final response = await _client
          .from('folders')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      _logger.error('Failed to fetch remote folders', error: e);
      return [];
    }
  }

  // Upload methods
  Future<void> _uploadNotes(List<dynamic> notes) async {
    if (notes.isEmpty) return;

    try {
      // Use SupabaseNoteApi with CryptoBox to encrypt notes before uploading
      final api = SupabaseNoteApi(_client);
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        _logger.error('No authenticated user for encryption');
        return;
      }

      for (final note in notes) {
        final noteData = _adapter.getNoteDataForSync(note);
        final noteId = noteData['id'] as String;

        // Encrypt title using CryptoBox (same as existing working code)
        final encryptedTitle = await _cryptoBox.encryptJsonForNote(
          userId: userId,
          noteId: noteId,
          json: {'title': noteData['title'] ?? ''},
        );

        // Encrypt props using CryptoBox
        // COMPATIBILITY: Read 'body' first, fall back to 'content'
        final propsJson = <String, dynamic>{
          'body': (noteData['body'] ?? noteData['content'] ?? ''),
          'tags': (noteData['tags'] ?? []),
          'isPinned': (noteData['is_pinned'] ?? false),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final encryptedProps = await _cryptoBox.encryptJsonForNote(
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
      }

      _logger.debug('Uploaded ${notes.length} encrypted notes');
    } catch (e) {
      _logger.error('Failed to upload notes', error: e);
      rethrow;
    }
  }

  Future<void> _uploadTasks(List<dynamic> tasks) async {
    if (tasks.isEmpty) return;

    try {
      final data = tasks.map((task) => _adapter.getTaskDataForSync(task)).toList();
      await _client.from('tasks').upsert(data);
      _logger.debug('Uploaded ${tasks.length} tasks');
    } catch (e) {
      _logger.error('Failed to upload tasks', error: e);
      rethrow;
    }
  }

  Future<void> _uploadFolders(List<dynamic> folders) async {
    if (folders.isEmpty) return;

    try {
      final data = folders.map((folder) => _adapter.getFolderDataForSync(folder)).toList();
      await _client.from('folders').upsert(data);
      _logger.debug('Uploaded ${folders.length} folders');
    } catch (e) {
      _logger.error('Failed to upload folders', error: e);
      rethrow;
    }
  }

  // Download methods
  Future<void> _downloadNotes(List<Map<String, dynamic>> notes) async {
    if (notes.isEmpty) return;

    try {
      for (final noteData in notes) {
        final note = _adapter.createNoteFromSync(noteData);
        // Save through appropriate repository
        if (_migrationConfig.isFeatureEnabled('notes') && _domainNotesRepo != null) {
          await _domainNotesRepo!.createOrUpdate(note as domain.Note);
        } else {
          // For local notes, save directly to database
          final localNote = note as LocalNote;
          await _db.into(_db.localNotes).insertOnConflictUpdate(localNote);
        }
      }
      _logger.debug('Downloaded ${notes.length} notes');
    } catch (e) {
      _logger.error('Failed to download notes', error: e);
      rethrow;
    }
  }

  Future<void> _downloadTasks(List<Map<String, dynamic>> tasks) async {
    if (tasks.isEmpty) return;

    try {
      for (final taskData in tasks) {
        final task = _adapter.createTaskFromSync(taskData);
        // Save through appropriate repository
        if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
          await _domainTasksRepo!.createTask(task as domain.Task);
        } else {
          // For local tasks, save directly to database
          final noteTask = task as NoteTask;
          await _db.into(_db.noteTasks).insertOnConflictUpdate(noteTask);
        }
      }
      _logger.debug('Downloaded ${tasks.length} tasks');
    } catch (e) {
      _logger.error('Failed to download tasks', error: e);
      rethrow;
    }
  }

  Future<void> _downloadFolders(List<Map<String, dynamic>> folders) async {
    if (folders.isEmpty) return;

    try {
      for (final folderData in folders) {
        final folder = _adapter.createFolderFromSync(folderData);
        // Save through appropriate repository
        if (_migrationConfig.isFeatureEnabled('folders')) {
          // Domain folders are handled via database directly for now
          // TODO: Add IFolderRepository when available
          final localFolder = folder as LocalFolder;
          await _db.into(_db.localFolders).insertOnConflictUpdate(localFolder);
        } else {
          // For local folders, save directly to database
          final localFolder = folder as LocalFolder;
          await _db.into(_db.localFolders).insertOnConflictUpdate(localFolder);
        }
      }
      _logger.debug('Downloaded ${folders.length} folders');
    } catch (e) {
      _logger.error('Failed to download folders', error: e);
      rethrow;
    }
  }

  // Helper methods for working with different model types
  Future<dynamic> _getNoteById(String id) async {
    if (_migrationConfig.isFeatureEnabled('notes') && _domainNotesRepo != null) {
      return await _domainNotesRepo!.getById(id);
    } else {
      return await _db.getNote(id);
    }
  }

  Future<List<dynamic>> _getNoteTasks(String noteId) async {
    if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      return await _domainTasksRepo!.getTasksForNote(noteId);
    } else {
      return await _db.getTasksForNote(noteId);
    }
  }

  Future<dynamic> _createTask({
    required String id,
    required String noteId,
    required String title,
    required bool completed,
  }) async {
    if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      final task = domain.Task(
        id: id,
        noteId: noteId,
        title: title,
        content: '',
        status: completed ? domain.TaskStatus.completed : domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: completed ? DateTime.now() : null,
        tags: [],
        metadata: {},
      );
      await _domainTasksRepo!.createTask(task);
      return task;
    } else {
      await _db.into(_db.noteTasks).insert(
        NoteTasksCompanion(
          id: Value(id),
          noteId: Value(noteId),
          content: Value(title),
          status: Value(completed ? TaskStatus.completed : TaskStatus.open),
          deleted: const Value(false),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return await _db.getTaskById(id);
    }
  }

  Future<void> _updateTaskCompletion(String taskId, bool completed) async {
    if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
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
      await (_db.update(_db.noteTasks)
            ..where((t) => t.id.equals(taskId)))
          .write(NoteTasksCompanion(
            status: Value(completed ? TaskStatus.completed : TaskStatus.open),
            completedAt: Value(completed ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ));
    }
  }

  Future<void> _updateNoteContent(String noteId, String content) async {
    if (_migrationConfig.isFeatureEnabled('notes') && _domainNotesRepo != null) {
      final note = await _domainNotesRepo!.getById(noteId);
      if (note != null) {
        await _domainNotesRepo!.createOrUpdate(note.copyWith(body: content));
      }
    } else {
      await _db.updateNote(
        noteId,
        LocalNotesCompanion(
          body: Value(content),
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
    if (note is LocalNote) return note.body;
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
    if (task is NoteTask) return task.content;
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