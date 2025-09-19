import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';

/// Coordinates task synchronization when notes are edited
/// This is the main entry point for bidirectional sync
class NoteTaskCoordinator {
  NoteTaskCoordinator({
    required AppDb database,
    required BidirectionalTaskSyncService bidirectionalSync,
  }) : _db = database,
       _bidirectionalSync = bidirectionalSync;

  final AppDb _db;
  final BidirectionalTaskSyncService _bidirectionalSync;
  final AppLogger _logger = LoggerFactory.instance;

  // Track active note subscriptions
  final Map<String, StreamSubscription<LocalNote?>> _noteSubscriptions = {};
  
  // Debounce timers to avoid excessive syncing
  final Map<String, Timer?> _debounceTimers = {};
  static const _debounceDelay = Duration(milliseconds: 500);

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

      _logger.info('Started watching note for task sync', data: {'noteId': noteId});
    } catch (e, stack) {
      _logger.error('Failed to start watching note', 
        error: e, 
        stackTrace: stack,
        data: {'noteId': noteId}
      );
    }
  }

  /// Stop watching a note
  Future<void> stopWatchingNote(String noteId) async {
    // Cancel subscription
    await _noteSubscriptions[noteId]?.cancel();
    _noteSubscriptions.remove(noteId);

    // Cancel any pending debounce timer
    _debounceTimers[noteId]?.cancel();
    _debounceTimers.remove(noteId);

    // Clear cache
    _bidirectionalSync.clearCacheForNote(noteId);

    _logger.debug('Stopped watching note', data: {'noteId': noteId});
  }

  /// Handle note content changes with debouncing
  void _handleNoteChange(String noteId, String content) {
    // Cancel existing timer
    _debounceTimers[noteId]?.cancel();

    // Set new debounce timer
    _debounceTimers[noteId] = Timer(_debounceDelay, () async {
      try {
        await _bidirectionalSync.syncFromNoteToTasks(noteId, content);
        _logger.debug('Synced tasks from note change', data: {'noteId': noteId});
      } catch (e, stack) {
        _logger.error('Failed to sync tasks from note', 
          error: e, 
          stackTrace: stack,
          data: {'noteId': noteId}
        );
      }
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
        error: e, 
        stackTrace: stack,
        data: {'noteId': noteId}
      );
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
