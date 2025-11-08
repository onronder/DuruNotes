import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/trash_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for scheduling and executing automatic purge of overdue trash items
/// Phase 1.1: Soft Delete & Trash System - Auto-Purge
///
/// This service runs on app startup to check for items that have exceeded
/// the 30-day retention period and permanently deletes them.
class PurgeSchedulerService {
  PurgeSchedulerService(this._ref, {required TrashService trashService})
      : _trash = trashService;

  final Ref _ref;
  final TrashService _trash;

  AppLogger get _logger => _ref.read(loggerProvider);

  /// Feature flag key for enabling automatic purge
  static const String _featureFlagKey = 'enable_automatic_trash_purge';

  /// Check if automatic purge is enabled via feature flag
  bool get isAutoPurgeEnabled {
    return FeatureFlags.instance.isEnabled(_featureFlagKey);
  }

  /// Last purge check timestamp (stored in memory, resets on app restart)
  DateTime? _lastPurgeCheck;

  /// Minimum time between purge checks (24 hours)
  static const Duration _purgeCheckInterval = Duration(hours: 24);

  /// Check if we should run purge check
  bool get shouldRunPurgeCheck {
    if (_lastPurgeCheck == null) return true;

    final timeSinceLastCheck = DateTime.now().difference(_lastPurgeCheck!);
    return timeSinceLastCheck >= _purgeCheckInterval;
  }

  /// Execute automatic purge check on app startup
  ///
  /// This is designed to be called during app initialization.
  /// It will:
  /// 1. Check feature flag
  /// 2. Check if enough time has passed since last check
  /// 3. Get trash statistics
  /// 4. Purge overdue items if any exist
  /// 5. Log analytics
  ///
  /// Returns a [PurgeCheckResult] with details about what was purged.
  Future<PurgeCheckResult> checkAndPurgeOnStartup() async {
    _logger.info('[PurgeScheduler] Starting automatic purge check');

    // Check feature flag
    if (!isAutoPurgeEnabled) {
      _logger.info('[PurgeScheduler] Auto-purge disabled via feature flag');
      return PurgeCheckResult(
        executed: false,
        reason: 'Feature flag disabled',
        itemsPurged: 0,
        checkedAt: DateTime.now(),
      );
    }

    // Check if we should run based on time interval
    if (!shouldRunPurgeCheck) {
      final timeSinceLastCheck =
          DateTime.now().difference(_lastPurgeCheck!).inHours;
      _logger.info(
        '[PurgeScheduler] Skipping purge check - last check was $timeSinceLastCheck hours ago',
      );
      return PurgeCheckResult(
        executed: false,
        reason: 'Too soon since last check ($timeSinceLastCheck hours ago)',
        itemsPurged: 0,
        checkedAt: DateTime.now(),
      );
    }

    try {
      // Get trash statistics to see if there are overdue items
      final stats = await _trash.getTrashStatistics();

      _logger.info(
        '[PurgeScheduler] Trash stats: ${stats.overdueForPurgeCount} overdue items',
        data: {
          'total_items': stats.totalItems,
          'overdue_count': stats.overdueForPurgeCount,
          'notes': stats.notesCount,
          'folders': stats.foldersCount,
          'tasks': stats.tasksCount,
        },
      );

      // Update last check timestamp
      _lastPurgeCheck = DateTime.now();

      // If no overdue items, return early
      if (stats.overdueForPurgeCount == 0) {
        _logger.info('[PurgeScheduler] No overdue items to purge');
        return PurgeCheckResult(
          executed: false,
          reason: 'No overdue items found',
          itemsPurged: 0,
          checkedAt: _lastPurgeCheck!,
          statistics: stats,
        );
      }

      // Purge overdue items
      _logger.info(
        '[PurgeScheduler] Purging ${stats.overdueForPurgeCount} overdue items',
      );

      final purgeResult = await _purgeOverdueItems();

      _logger.info(
        '[PurgeScheduler] Purge completed: ${purgeResult.successCount} succeeded, ${purgeResult.failureCount} failed',
        data: {
          'success_count': purgeResult.successCount,
          'failure_count': purgeResult.failureCount,
          'errors': purgeResult.errors.length,
        },
      );

      // Track analytics
      _trackPurgeAnalytics(purgeResult, stats);

      return PurgeCheckResult(
        executed: true,
        reason: 'Purged overdue items',
        itemsPurged: purgeResult.successCount,
        checkedAt: _lastPurgeCheck!,
        statistics: stats,
        failures: purgeResult.failureCount,
        errors: purgeResult.errors,
      );
    } catch (e, stack) {
      _logger.error(
        '[PurgeScheduler] Failed to execute purge check',
        error: e,
        stackTrace: stack,
      );

      return PurgeCheckResult(
        executed: false,
        reason: 'Error during purge: ${e.toString()}',
        itemsPurged: 0,
        checkedAt: DateTime.now(),
        error: e,
      );
    }
  }

  /// Purge all overdue items
  Future<BulkDeleteResult> _purgeOverdueItems() async {
    int successCount = 0;
    int failureCount = 0;
    final errors = <String, dynamic>{};

    try {
      // Get all deleted items
      final contents = await _trash.getAllDeletedItems();

      final now = DateTime.now();

      // Filter for overdue items only
      final overdueNotes = contents.notes.where((note) {
        return note.scheduledPurgeAt != null &&
            note.scheduledPurgeAt!.isBefore(now);
      }).toList();

      final overdueFolders = contents.folders.where((folder) {
        return folder.scheduledPurgeAt != null &&
            folder.scheduledPurgeAt!.isBefore(now);
      }).toList();

      final overdueTasks = contents.tasks.where((task) {
        return task.scheduledPurgeAt != null &&
            task.scheduledPurgeAt!.isBefore(now);
      }).toList();

      _logger.info(
        '[PurgeScheduler] Found overdue items: ${overdueNotes.length} notes, ${overdueFolders.length} folders, ${overdueTasks.length} tasks',
      );

      // Purge overdue notes
      for (final note in overdueNotes) {
        try {
          await _trash.permanentlyDeleteNote(note.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['note_${note.id}'] = e.toString();
          _logger.error(
            '[PurgeScheduler] Failed to purge note ${note.id}',
            error: e,
          );
        }
      }

      // Purge overdue folders
      for (final folder in overdueFolders) {
        try {
          await _trash.permanentlyDeleteFolder(folder.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['folder_${folder.id}'] = e.toString();
          _logger.error(
            '[PurgeScheduler] Failed to purge folder ${folder.id}',
            error: e,
          );
        }
      }

      // Purge overdue tasks
      for (final task in overdueTasks) {
        try {
          await _trash.permanentlyDeleteTask(task.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['task_${task.id}'] = e.toString();
          _logger.error(
            '[PurgeScheduler] Failed to purge task ${task.id}',
            error: e,
          );
        }
      }

      return BulkDeleteResult(
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
        completedAt: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error(
        '[PurgeScheduler] Failed to purge overdue items',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Track purge analytics
  void _trackPurgeAnalytics(
    BulkDeleteResult purgeResult,
    TrashStatistics stats,
  ) {
    _logger.breadcrumb(
      'Automatic purge completed',
      data: {
        'success_count': purgeResult.successCount,
        'failure_count': purgeResult.failureCount,
        'total_trash_items': stats.totalItems,
        'overdue_count': stats.overdueForPurgeCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Manually trigger a purge check (for testing or admin purposes)
  ///
  /// This bypasses the time interval check but still respects the feature flag.
  Future<PurgeCheckResult> forcePurgeCheck() async {
    _logger.info('[PurgeScheduler] Force purge check requested');
    _lastPurgeCheck = null; // Reset to allow immediate check
    return checkAndPurgeOnStartup();
  }

  /// Get current purge status without executing a purge
  Future<PurgeStatus> getPurgeStatus() async {
    try {
      final stats = await _trash.getTrashStatistics();

      return PurgeStatus(
        isEnabled: isAutoPurgeEnabled,
        lastCheckAt: _lastPurgeCheck,
        nextCheckAt: _lastPurgeCheck?.add(_purgeCheckInterval),
        overdueItemsCount: stats.overdueForPurgeCount,
        totalTrashItems: stats.totalItems,
        purgeWithin7Days: stats.purgeWithin7Days,
        statistics: stats,
      );
    } catch (e, stack) {
      _logger.error(
        '[PurgeScheduler] Failed to get purge status',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}

/// Result of a purge check operation
class PurgeCheckResult {
  const PurgeCheckResult({
    required this.executed,
    required this.reason,
    required this.itemsPurged,
    required this.checkedAt,
    this.statistics,
    this.failures = 0,
    this.errors = const {},
    this.error,
  });

  /// Whether the purge was actually executed
  final bool executed;

  /// Reason for the result (e.g., "Feature flag disabled", "No overdue items")
  final String reason;

  /// Number of items successfully purged
  final int itemsPurged;

  /// When the check was performed
  final DateTime checkedAt;

  /// Trash statistics at time of check (if available)
  final TrashStatistics? statistics;

  /// Number of items that failed to purge
  final int failures;

  /// Map of item IDs to error messages
  final Map<String, dynamic> errors;

  /// Error that prevented purge check from completing (if any)
  final Object? error;

  bool get hasFailures => failures > 0;
  bool get wasSuccessful => executed && failures == 0;
}

/// Current status of the purge scheduler
class PurgeStatus {
  const PurgeStatus({
    required this.isEnabled,
    required this.lastCheckAt,
    required this.nextCheckAt,
    required this.overdueItemsCount,
    required this.totalTrashItems,
    required this.purgeWithin7Days,
    required this.statistics,
  });

  /// Whether automatic purge is enabled via feature flag
  final bool isEnabled;

  /// When the last purge check was performed
  final DateTime? lastCheckAt;

  /// When the next purge check will occur
  final DateTime? nextCheckAt;

  /// Number of items currently overdue for purge
  final int overdueItemsCount;

  /// Total number of items in trash
  final int totalTrashItems;

  /// Number of items scheduled for purge in next 7 days
  final int purgeWithin7Days;

  /// Full trash statistics
  final TrashStatistics statistics;
}
