import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/sync_performance_metrics.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';

/// Type of change being tracked
enum ChangeType { content, toggle, create, delete }

/// Represents a pending change to be synced
class PendingChange {
  final ChangeType type;
  final String content;
  final DateTime timestamp;
  final bool isCritical;
  final String? taskId;
  final bool? isCompleted;

  PendingChange({
    required this.type,
    required this.content,
    required this.timestamp,
    this.isCritical = false,
    this.taskId,
    this.isCompleted,
  });
}

/// Coordinates task synchronization when notes are edited
/// This is the main entry point for bidirectional sync
class NoteTaskCoordinator {
  NoteTaskCoordinator({
    required AppDb database,
    required BidirectionalTaskSyncService bidirectionalSync,
  })  : _db = database,
        _bidirectionalSync = bidirectionalSync;

  final AppDb _db;
  final BidirectionalTaskSyncService _bidirectionalSync;
  final AppLogger _logger = LoggerFactory.instance;

  // Track active note subscriptions
  final Map<String, StreamSubscription<LocalNote?>> _noteSubscriptions = {};

  // Debounce timers to avoid excessive syncing
  final Map<String, Timer?> _debounceTimers = {};
  static const _defaultDebounceDelay = Duration(milliseconds: 500);
  static const _criticalDebounceDelay = Duration(milliseconds: 100);

  // Track pending changes for each note
  final Map<String, List<PendingChange>> _pendingChanges = {};

  // Track if a sync is in progress
  final Set<String> _syncInProgress = {};

  /// Start watching a note for changes and sync tasks
  Future<void> startWatchingNote(String noteId) async {
    try {
      // Cancel any existing subscription
      await stopWatchingNote(noteId);

      // Initialize bidirectional sync
      await _bidirectionalSync.initializeBidirectionalSync(noteId);

      // Watch for note changes
      _noteSubscriptions[noteId] = _db.watchNote(noteId).listen((note) {
        if (note != null) {
          _handleNoteChange(noteId, note.body);
        }
      });

      _logger.info('Started watching note for task sync',
          data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to start watching note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Stop watching a note with final sync
  Future<void> stopWatchingNote(String noteId) async {
    try {
      // Force immediate sync of any pending changes
      await _forceSyncPendingChanges(noteId);

      // Cancel subscription
      await _noteSubscriptions[noteId]?.cancel();
      _noteSubscriptions.remove(noteId);

      // Cancel any pending debounce timer
      _debounceTimers[noteId]?.cancel();
      _debounceTimers.remove(noteId);

      // Clear pending changes
      _pendingChanges.remove(noteId);
      _syncInProgress.remove(noteId);

      // Clear cache
      _bidirectionalSync.clearCacheForNote(noteId);

      _logger.info('Stopped watching note and synced final changes',
          data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Error during final sync',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Handle note content changes with debouncing
  void _handleNoteChange(String noteId, String content,
      {bool isCritical = false}) {
    // Add to pending changes
    _pendingChanges[noteId] ??= [];
    _pendingChanges[noteId]!.add(
      PendingChange(
        type: ChangeType.content,
        content: content,
        timestamp: DateTime.now(),
        isCritical: isCritical,
      ),
    );

    // Cancel existing timer
    _debounceTimers[noteId]?.cancel();

    // Use shorter delay for critical changes (like checkbox toggles)
    final delay = isCritical ? _criticalDebounceDelay : _defaultDebounceDelay;

    // Set new debounce timer
    _debounceTimers[noteId] = Timer(delay, () async {
      await _processPendingChanges(noteId);
    });
  }

  /// Process all pending changes for a note
  Future<void> _processPendingChanges(String noteId) async {
    final changes = _pendingChanges[noteId];
    if (changes == null || changes.isEmpty) return;

    // Get the latest change (most recent content)
    final latestChange = changes.last;

    // Clear pending changes
    _pendingChanges[noteId] = [];

    // If another sync is active, queue this one
    if (_syncInProgress.contains(noteId)) {
      _pendingChanges[noteId] = [latestChange];
      _scheduleSync(noteId, isCritical: latestChange.isCritical);
      return;
    }

    // Start performance tracking
    final syncId = SyncPerformanceMetrics.instance.startSync(
      noteId: noteId,
      syncType: latestChange.type.name,
      metadata: {
        'changeCount': changes.length,
        'isCritical': latestChange.isCritical,
      },
    );
    final timer = SyncTimer(syncId, SyncPerformanceMetrics.instance);

    _syncInProgress.add(noteId);
    bool success = false;
    String? error;

    try {
      await _bidirectionalSync.syncFromNoteToTasks(
          noteId, latestChange.content);
      success = true;
      _logger.debug('Synced tasks from note change', data: {
        'noteId': noteId,
        'changeCount': changes.length,
        'wasCritical': latestChange.isCritical,
      });
    } catch (e, stack) {
      error = e.toString();
      _logger.error('Failed to sync tasks from note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    } finally {
      _syncInProgress.remove(noteId);
      timer.stop(success: success, error: error);

      // Check if more changes accumulated
      if (_pendingChanges[noteId]?.isNotEmpty ?? false) {
        _scheduleSync(noteId);
      }
    }
  }

  /// Schedule a sync with appropriate delay
  void _scheduleSync(String noteId, {bool isCritical = false}) {
    _debounceTimers[noteId]?.cancel();
    final delay = isCritical ? _criticalDebounceDelay : _defaultDebounceDelay;
    _debounceTimers[noteId] = Timer(delay, () async {
      await _processPendingChanges(noteId);
    });
  }

  /// Force sync of any pending changes
  Future<void> _forceSyncPendingChanges(String noteId) async {
    // Cancel any pending debounced syncs
    _debounceTimers[noteId]?.cancel();
    _debounceTimers.remove(noteId);

    // Process any pending changes immediately
    await _processPendingChanges(noteId);
  }

  /// Handle task checkbox toggle specifically
  Future<void> handleTaskToggle({
    required String noteId,
    required String taskId,
    required bool isCompleted,
    required String updatedContent,
  }) async {
    // Track toggle for rapid toggle detection
    SyncPerformanceMetrics.instance.recordToggle(taskId);

    // Add to pending changes with critical priority
    _pendingChanges[noteId] ??= [];
    _pendingChanges[noteId]!.add(
      PendingChange(
        type: ChangeType.toggle,
        content: updatedContent,
        timestamp: DateTime.now(),
        isCritical: true,
        taskId: taskId,
        isCompleted: isCompleted,
      ),
    );

    // Schedule with critical priority
    _scheduleSync(noteId, isCritical: true);

    _logger.debug('Scheduled critical sync for task toggle', data: {
      'noteId': noteId,
      'taskId': taskId,
      'isCompleted': isCompleted,
    });
  }

  /// Manually trigger sync for a note
  Future<void> syncNote(String noteId) async {
    try {
      final note = await _db.getNote(noteId);
      if (note != null) {
        await _bidirectionalSync.syncFromNoteToTasks(noteId, note.body);
        _logger.debug('Manually synced note tasks', data: {'noteId': noteId});
      }
    } catch (e, stack) {
      _logger.error('Failed to manually sync note',
          error: e, stackTrace: stack, data: {'noteId': noteId});
    }
  }

  /// Stop watching all notes
  Future<void> dispose() async {
    // Cancel all subscriptions
    for (final subscription in _noteSubscriptions.values) {
      await subscription.cancel();
    }
    _noteSubscriptions.clear();

    // Cancel all timers
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
  }
}
