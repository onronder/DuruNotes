import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:rxdart/rxdart.dart';

/// Represents a task update event
class TaskUpdate {
  const TaskUpdate({
    required this.taskId,
    required this.task,
    required this.action,
  });

  final String taskId;
  final domain.Task? task;
  final TaskUpdateAction action;
}

enum TaskUpdateAction { created, updated, deleted, synced }

enum SyncStatus { idle, syncing, success, error }

/// DEPRECATED: Legacy task sync service - use UnifiedSyncService instead
///
/// This service has incomplete remote sync implementation (marked with TODO).
/// Currently only syncs locally without actual remote synchronization.
///
/// Migrate to UnifiedSyncService for:
/// - Complete bidirectional task sync with remote
/// - Automatic conflict resolution
/// - Encryption support for task data
/// - Integration with note-embedded tasks
/// - Proper error handling and retry logic
///
/// Migration example:
/// ```dart
/// // Old:
/// final taskSyncService = TaskSyncService(repository: taskRepo, db: db);
/// await taskSyncService.syncAllTasks();
///
/// // New:
/// final unifiedSync = ref.watch(unifiedSyncServiceProvider);
/// final result = await unifiedSync.syncAll();
/// if (result.success) {
///   // All tasks synced: ${result.syncedTasks} tasks
/// }
/// ```
@Deprecated(
  'Use UnifiedSyncService instead. This service will be removed in a future version.',
)
class TaskSyncService {
  TaskSyncService({
    required ITaskRepository repository,
    required AppDb db, // Kept for backward compatibility
    AppLogger? logger,
  }) : _repository = repository,
       _logger = logger ?? LoggerFactory.instance,
       _taskUpdatesController = BehaviorSubject<TaskUpdate>(),
       _syncStatusController = BehaviorSubject<SyncStatus>.seeded(
         SyncStatus.idle,
       );

  final ITaskRepository _repository;
  final AppLogger _logger;

  // Stream controllers for updates
  final BehaviorSubject<TaskUpdate> _taskUpdatesController;
  final BehaviorSubject<SyncStatus> _syncStatusController;

  // Sync state
  final Map<String, DateTime> _lastSyncTimes = {};
  final Map<String, List<domain.Task>> _pendingChanges = {};
  final Set<String> _syncInProgress = {};
  Timer? _syncTimer;

  // Debounce configuration
  static const Duration _syncDebounceTime = Duration(seconds: 2);
  static const int _maxRetries = 3;

  /// Helper to get updatedAt from task metadata
  DateTime _getUpdatedAt(domain.Task task) {
    final updatedAtStr = task.metadata['updatedAt'] as String?;
    if (updatedAtStr != null) {
      return DateTime.parse(updatedAtStr);
    }
    // Fallback to a default timestamp if not found
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Stream of task updates
  Stream<TaskUpdate> get taskUpdates => _taskUpdatesController.stream;

  /// Stream of sync status
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// DEPRECATED: Sync all tasks - incomplete implementation without actual remote sync
  ///
  /// WARNING: This method only updates local sync times without syncing to remote.
  /// Use UnifiedSyncService.syncAll() for actual remote synchronization.
  @Deprecated('Use UnifiedSyncService.syncAll() for complete remote sync')
  Future<void> syncAllTasks() async {
    if (_syncStatusController.value == SyncStatus.syncing) {
      _logger.debug('[TaskSyncService] Sync already in progress');
      return;
    }

    try {
      _syncStatusController.add(SyncStatus.syncing);
      _logger.warning(
        '[TaskSyncService] DEPRECATION WARNING: syncAllTasks() does not sync to remote. '
        'Use UnifiedSyncService.syncAll() instead.',
      );

      // Get all local tasks
      final localTasks = await _repository.getAllTasks();

      // INCOMPLETE: This only marks tasks as synced locally without remote sync
      // Use UnifiedSyncService for actual remote synchronization
      for (final task in localTasks) {
        _lastSyncTimes[task.id] = DateTime.now();
      }

      _syncStatusController.add(SyncStatus.success);
      _logger.info(
        '[TaskSyncService] Local task sync completed (remote sync NOT performed)',
        data: {'taskCount': localTasks.length},
      );
    } catch (e, stack) {
      _syncStatusController.add(SyncStatus.error);
      _logger.error(
        '[TaskSyncService] Task sync failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Sync tasks for a specific note
  Future<void> syncTasksForNote(String noteId) async {
    if (_syncInProgress.contains(noteId)) {
      _logger.debug(
        '[TaskSyncService] Sync already in progress for note',
        data: {'noteId': noteId},
      );
      return;
    }

    _syncInProgress.add(noteId);

    try {
      _logger.debug(
        '[TaskSyncService] Syncing tasks for note',
        data: {'noteId': noteId},
      );

      // Get tasks for this note
      final tasks = await _repository.getTasksForNote(noteId);

      // Check for pending changes
      final pending = _pendingChanges[noteId] ?? [];
      if (pending.isNotEmpty) {
        _logger.info(
          '[TaskSyncService] Processing pending changes',
          data: {'noteId': noteId, 'pendingCount': pending.length},
        );

        // Apply pending changes
        for (final task in pending) {
          await _repository.updateTask(task);

          _taskUpdatesController.add(
            TaskUpdate(
              taskId: task.id,
              task: task,
              action: TaskUpdateAction.synced,
            ),
          );
        }

        _pendingChanges[noteId]?.clear();
      }

      // Update sync time
      _lastSyncTimes[noteId] = DateTime.now();

      _logger.info(
        '[TaskSyncService] Tasks synced for note',
        data: {'noteId': noteId, 'taskCount': tasks.length},
      );
    } catch (e, stack) {
      _logger.error(
        '[TaskSyncService] Failed to sync tasks for note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
    } finally {
      _syncInProgress.remove(noteId);
    }
  }

  /// Handle task update and queue for sync
  void queueTaskUpdate(domain.Task task) {
    final noteId = task.noteId;

    // Add to pending changes
    _pendingChanges[noteId] ??= <domain.Task>[];
    _pendingChanges[noteId]!.add(task);

    // Notify listeners
    _taskUpdatesController.add(
      TaskUpdate(taskId: task.id, task: task, action: TaskUpdateAction.updated),
    );

    // Schedule sync
    _scheduleDebouncedSync(noteId);
  }

  /// Schedule a debounced sync for a note
  void _scheduleDebouncedSync(String noteId) {
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounceTime, () {
      syncTasksForNote(noteId);
    });
  }

  /// Resolve conflicts between local and remote tasks
  Future<domain.Task> resolveConflict(
    domain.Task local,
    domain.Task remote,
  ) async {
    _logger.info(
      '[TaskSyncService] Resolving task conflict',
      data: {
        'taskId': local.id,
        'localUpdated': _getUpdatedAt(local).toIso8601String(),
        'remoteUpdated': _getUpdatedAt(remote).toIso8601String(),
      },
    );

    // Simple last-write-wins strategy
    if (_getUpdatedAt(local).isAfter(_getUpdatedAt(remote))) {
      return local;
    } else {
      return remote;
    }
  }

  /// Retry failed sync operations
  Future<bool> retrySyncWithBackoff(
    String noteId,
    Future<void> Function() operation,
  ) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await operation();
        return true;
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          // Exponential backoff
          final delay = Duration(seconds: (attempt + 1) * 2);
          _logger.debug(
            '[TaskSyncService] Retrying sync after delay',
            data: {
              'noteId': noteId,
              'attempt': attempt + 1,
              'delay': delay.inSeconds,
            },
          );
          await Future<void>.delayed(delay);
        }
      }
    }

    return false;
  }

  /// Get last sync time for a note
  DateTime? getLastSyncTime(String noteId) {
    return _lastSyncTimes[noteId];
  }

  /// Check if tasks need sync
  bool needsSync(String noteId) {
    final lastSync = _lastSyncTimes[noteId];
    if (lastSync == null) return true;

    // Consider sync needed if more than 5 minutes old
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    return lastSync.isBefore(fiveMinutesAgo);
  }

  /// Clear sync cache for a note
  void clearSyncCache(String noteId) {
    _lastSyncTimes.remove(noteId);
    _pendingChanges.remove(noteId);
    _syncInProgress.remove(noteId);
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _taskUpdatesController.close();
    _syncStatusController.close();
    _lastSyncTimes.clear();
    _pendingChanges.clear();
    _syncInProgress.clear();
  }
}
