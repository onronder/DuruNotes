import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Audit event types for folder synchronization
enum FolderSyncEventType {
  createStarted,
  createCompleted,
  createFailed,
  updateStarted,
  updateCompleted,
  updateFailed,
  deleteStarted,
  deleteCompleted,
  deleteFailed,
  conflictDetected,
  conflictResolved,
  realtimeReceived,
  realtimeSent,
  syncStarted,
  syncCompleted,
  syncFailed,
}

/// Folder sync audit event
class FolderSyncEvent {
  FolderSyncEvent({
    required this.type,
    required this.timestamp,
    required this.folderId,
    this.folderName,
    this.userId,
    this.metadata,
    this.error,
    this.stackTrace,
    this.conflictInfo,
  });

  final FolderSyncEventType type;
  final DateTime timestamp;
  final String folderId;
  final String? folderName;
  final String? userId;
  final Map<String, dynamic>? metadata;
  final dynamic error;
  final StackTrace? stackTrace;
  final ConflictInfo? conflictInfo;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'folderId': folderId,
        'folderName': folderName,
        'userId': userId,
        'metadata': metadata,
        'error': error?.toString(),
        'conflictInfo': conflictInfo?.toJson(),
      };
}

/// Information about sync conflicts
class ConflictInfo {
  ConflictInfo({
    required this.localVersion,
    required this.remoteVersion,
    required this.resolution,
    this.mergedVersion,
  });

  final LocalFolder localVersion;
  final Map<String, dynamic> remoteVersion;
  final ConflictResolution resolution;
  final LocalFolder? mergedVersion;

  Map<String, dynamic> toJson() => {
        'localVersion': {
          'id': localVersion.id,
          'name': localVersion.name,
          'updatedAt': localVersion.updatedAt.toIso8601String(),
        },
        'remoteVersion': remoteVersion,
        'resolution': resolution.name,
        'mergedVersion': mergedVersion != null
            ? {
                'id': mergedVersion!.id,
                'name': mergedVersion!.name,
                'updatedAt': mergedVersion!.updatedAt.toIso8601String(),
              }
            : null,
      };
}

/// Conflict resolution strategies
enum ConflictResolution { localWins, remoteWins, merge, manualReview }

/// Service for auditing folder sync operations
class FolderSyncAudit {
  FolderSyncAudit({required this.logger});

  final AppLogger logger;

  // Event stream for monitoring
  final _eventController = StreamController<FolderSyncEvent>.broadcast();
  Stream<FolderSyncEvent> get events => _eventController.stream;

  // Metrics tracking
  final Map<FolderSyncEventType, int> _eventCounts = {};
  final List<FolderSyncEvent> _recentEvents = [];
  static const int _maxRecentEvents = 100;

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, Duration> _operationDurations = {};

  /// Record a sync event
  void recordEvent(FolderSyncEvent event) {
    // Update counts
    _eventCounts[event.type] = (_eventCounts[event.type] ?? 0) + 1;

    // Store recent events
    _recentEvents.add(event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeAt(0);
    }

    // Emit to stream
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }

    // Log the event
    _logEvent(event);

    // Send to Sentry
    _sendToSentry(event);
  }

  /// Start tracking an operation
  void startOperation(
    String operationId,
    FolderSyncEventType type,
    String folderId, [
    String? folderName,
  ]) {
    final startTime = DateTime.now();
    _operationStartTimes[operationId] = startTime;

    recordEvent(
      FolderSyncEvent(
        type: type,
        timestamp: startTime,
        folderId: folderId,
        folderName: folderName,
      ),
    );
  }

  /// Complete tracking an operation
  void completeOperation(
    String operationId,
    FolderSyncEventType type,
    String folderId, [
    String? folderName,
  ]) {
    final endTime = DateTime.now();
    final startTime = _operationStartTimes.remove(operationId);

    if (startTime != null) {
      final duration = endTime.difference(startTime);
      _operationDurations[operationId] = duration;

      recordEvent(
        FolderSyncEvent(
          type: type,
          timestamp: endTime,
          folderId: folderId,
          folderName: folderName,
          metadata: {'duration_ms': duration.inMilliseconds},
        ),
      );
    } else {
      recordEvent(
        FolderSyncEvent(
          type: type,
          timestamp: endTime,
          folderId: folderId,
          folderName: folderName,
        ),
      );
    }
  }

  /// Record an operation failure
  void recordFailure(
    String operationId,
    FolderSyncEventType type,
    String folderId,
    dynamic error,
    StackTrace? stackTrace, [
    String? folderName,
  ]) {
    _operationStartTimes.remove(operationId);

    recordEvent(
      FolderSyncEvent(
        type: type,
        timestamp: DateTime.now(),
        folderId: folderId,
        folderName: folderName,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Record a conflict
  void recordConflict(
    String folderId,
    LocalFolder localVersion,
    Map<String, dynamic> remoteVersion,
    ConflictResolution resolution, [
    LocalFolder? mergedVersion,
  ]) {
    recordEvent(
      FolderSyncEvent(
        type: FolderSyncEventType.conflictDetected,
        timestamp: DateTime.now(),
        folderId: folderId,
        folderName: localVersion.name,
        conflictInfo: ConflictInfo(
          localVersion: localVersion,
          remoteVersion: remoteVersion,
          resolution: resolution,
          mergedVersion: mergedVersion,
        ),
      ),
    );

    if (resolution != ConflictResolution.manualReview) {
      recordEvent(
        FolderSyncEvent(
          type: FolderSyncEventType.conflictResolved,
          timestamp: DateTime.now(),
          folderId: folderId,
          folderName: mergedVersion?.name ?? localVersion.name,
          metadata: {'resolution': resolution.name},
        ),
      );
    }
  }

  /// Get audit metrics
  Map<String, dynamic> getMetrics() {
    return {
      'eventCounts': Map<String, int>.from(
        _eventCounts.map((key, value) => MapEntry(key.name, value)),
      ),
      'recentEventsCount': _recentEvents.length,
      'averageDurations': _calculateAverageDurations(),
      'errorRate': _calculateErrorRate(),
      'conflictRate': _calculateConflictRate(),
    };
  }

  /// Get recent events for debugging
  List<FolderSyncEvent> getRecentEvents([int? limit]) {
    if (limit == null) {
      return List.from(_recentEvents);
    }
    final startIndex =
        _recentEvents.length > limit ? _recentEvents.length - limit : 0;
    return _recentEvents.sublist(startIndex);
  }

  /// Clear audit data
  void clear() {
    _eventCounts.clear();
    _recentEvents.clear();
    _operationStartTimes.clear();
    _operationDurations.clear();
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }

  // Private methods

  void _logEvent(FolderSyncEvent event) {
    final level = _getLogLevel(event.type);
    final message = 'FolderSync: ${event.type.name}';
    final data = event.toJson();

    switch (level) {
      case LogLevel.debug:
        logger.debug(message, data: data);
        break;
      case LogLevel.info:
        logger.info(message, data: data);
        break;
      case LogLevel.warning:
        logger.warning(message, data: data);
        break;
      case LogLevel.error:
        logger.error(
          message,
          error: event.error,
          stackTrace: event.stackTrace,
          data: data,
        );
        break;
    }
  }

  LogLevel _getLogLevel(FolderSyncEventType type) {
    switch (type) {
      case FolderSyncEventType.createFailed:
      case FolderSyncEventType.updateFailed:
      case FolderSyncEventType.deleteFailed:
      case FolderSyncEventType.syncFailed:
        return LogLevel.error;
      case FolderSyncEventType.conflictDetected:
        return LogLevel.warning;
      case FolderSyncEventType.createCompleted:
      case FolderSyncEventType.updateCompleted:
      case FolderSyncEventType.deleteCompleted:
      case FolderSyncEventType.syncCompleted:
      case FolderSyncEventType.conflictResolved:
        return LogLevel.info;
      case FolderSyncEventType.createStarted:
      case FolderSyncEventType.updateStarted:
      case FolderSyncEventType.deleteStarted:
      case FolderSyncEventType.realtimeReceived:
      case FolderSyncEventType.realtimeSent:
      case FolderSyncEventType.syncStarted:
        return LogLevel.debug;
    }
  }

  void _sendToSentry(FolderSyncEvent event) {
    // Add breadcrumb for all events
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'FolderSync: ${event.type.name}',
        category: 'folder.sync',
        level: _getSentryLevel(event.type),
        data: event.toJson(),
        timestamp: event.timestamp,
      ),
    );

    // Capture errors
    if (event.error != null) {
      Sentry.captureException(
        event.error,
        stackTrace: event.stackTrace,
        withScope: (scope) {
          scope
            ..setTag('folder.sync.type', event.type.name)
            ..setContexts('folder', {
              'id': event.folderId,
              'name': event.folderName,
            });
          if (event.metadata != null) {
            scope.setContexts('metadata', event.metadata);
          }
        },
      );
    }

    // Track performance for completed operations
    if (event.metadata?['duration_ms'] != null) {
      final transaction = Sentry.startTransaction(
        'folder.sync.${event.type.name}',
        'folder',
      );
      transaction
        ..setData('folder_id', event.folderId)
        ..setData('duration_ms', event.metadata!['duration_ms'])
        ..finish();
    }
  }

  SentryLevel _getSentryLevel(FolderSyncEventType type) {
    switch (type) {
      case FolderSyncEventType.createFailed:
      case FolderSyncEventType.updateFailed:
      case FolderSyncEventType.deleteFailed:
      case FolderSyncEventType.syncFailed:
        return SentryLevel.error;
      case FolderSyncEventType.conflictDetected:
        return SentryLevel.warning;
      case FolderSyncEventType.createCompleted:
      case FolderSyncEventType.updateCompleted:
      case FolderSyncEventType.deleteCompleted:
      case FolderSyncEventType.syncCompleted:
      case FolderSyncEventType.conflictResolved:
        return SentryLevel.info;
      case FolderSyncEventType.createStarted:
      case FolderSyncEventType.updateStarted:
      case FolderSyncEventType.deleteStarted:
      case FolderSyncEventType.realtimeReceived:
      case FolderSyncEventType.realtimeSent:
      case FolderSyncEventType.syncStarted:
        return SentryLevel.debug;
    }
  }

  Map<String, double> _calculateAverageDurations() {
    final averages = <String, double>{};
    final durationsByType = <FolderSyncEventType, List<int>>{};

    for (final entry in _operationDurations.entries) {
      // Extract type from operation ID
      for (final type in FolderSyncEventType.values) {
        if (entry.key.contains(type.name)) {
          durationsByType
              .putIfAbsent(type, () => [])
              .add(entry.value.inMilliseconds);
          break;
        }
      }
    }

    for (final entry in durationsByType.entries) {
      if (entry.value.isNotEmpty) {
        final sum = entry.value.reduce((a, b) => a + b);
        averages[entry.key.name] = sum / entry.value.length;
      }
    }

    return averages;
  }

  double _calculateErrorRate() {
    final totalOps = (_eventCounts[FolderSyncEventType.createCompleted] ?? 0) +
        (_eventCounts[FolderSyncEventType.updateCompleted] ?? 0) +
        (_eventCounts[FolderSyncEventType.deleteCompleted] ?? 0) +
        (_eventCounts[FolderSyncEventType.createFailed] ?? 0) +
        (_eventCounts[FolderSyncEventType.updateFailed] ?? 0) +
        (_eventCounts[FolderSyncEventType.deleteFailed] ?? 0);

    if (totalOps == 0) {
      return 0;
    }

    final errors = (_eventCounts[FolderSyncEventType.createFailed] ?? 0) +
        (_eventCounts[FolderSyncEventType.updateFailed] ?? 0) +
        (_eventCounts[FolderSyncEventType.deleteFailed] ?? 0);

    return errors / totalOps;
  }

  double _calculateConflictRate() {
    final totalOps = (_eventCounts[FolderSyncEventType.updateCompleted] ?? 0) +
        (_eventCounts[FolderSyncEventType.updateFailed] ?? 0);

    if (totalOps == 0) {
      return 0;
    }

    final conflicts = _eventCounts[FolderSyncEventType.conflictDetected] ?? 0;
    return conflicts / totalOps;
  }
}

/// Log levels for audit events
enum LogLevel { debug, info, warning, error }
