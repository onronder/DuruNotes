import 'dart:async';

import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Manages locks for reminder encryption operations to prevent race conditions.
///
/// CRITICAL #6: Fix lazy encryption race condition
///
/// Problem:
/// Multiple concurrent calls to ensureReminderEncrypted() for the same reminder
/// can result in duplicate encryption work and potential data corruption.
///
/// Example Race Condition:
/// ```
/// Thread A: Read reminder (not encrypted) -> Start encrypting
/// Thread B: Read reminder (not encrypted) -> Start encrypting
/// Thread A: Write to database
/// Thread B: Write to database (overwrites A's write)
/// ```
///
/// Solution:
/// Use in-memory locks keyed by reminder ID to ensure only one encryption
/// operation runs per reminder at a time.
///
/// Usage:
/// ```dart
/// final lockManager = EncryptionLockManager(config.reminderConfig);
///
/// Future<bool> encryptReminder(String reminderId) async {
///   return await lockManager.withLock(reminderId, () async {
///     // Critical section - only one thread executes this at a time
///     final encrypted = await performEncryption();
///     await saveToDatabase(encrypted);
///     return true;
///   });
/// }
/// ```
///
/// Features:
/// - Per-reminder locking (concurrent encryption of different reminders allowed)
/// - Timeout protection (configurable via ReminderConfig)
/// - Auto-cleanup (locks released even if operation throws)
/// - Memory management (completed locks removed from map)
/// - Metrics tracking (lock wait time, contention rate)
class EncryptionLockManager {
  final ReminderServiceConfig _config;

  EncryptionLockManager([ReminderServiceConfig? config])
    : _config = config ?? ReminderServiceConfig.defaultConfig() {
    _logger.debug(
      'EncryptionLockManager initialized with lockTimeout=${_config.lockTimeout}',
    );
  }

  static const _logger = ConsoleLogger();

  /// Active locks keyed by reminder ID
  /// Each Completer represents an ongoing encryption operation
  final Map<String, Completer<void>> _locks = {};

  /// Metrics: Total number of lock acquisitions
  int _totalLockAcquisitions = 0;

  /// Metrics: Total time spent waiting for locks (milliseconds)
  int _totalWaitTimeMs = 0;

  /// Metrics: Number of times a thread had to wait for existing lock
  int _lockContentions = 0;

  /// Metrics: Number of lock timeouts
  int _lockTimeouts = 0;

  /// Execute operation with exclusive lock on reminder ID.
  ///
  /// Returns the result of [operation] if successful.
  ///
  /// Throws [TimeoutException] if lock cannot be acquired within [_lockTimeout].
  ///
  /// The lock is automatically released when [operation] completes or throws,
  /// ensuring no deadlocks even in error cases.
  Future<T> withLock<T>(
    String reminderId,
    Future<T> Function() operation,
  ) async {
    final lockStartTime = DateTime.now();

    try {
      // Wait for any existing lock to complete
      await _acquireLock(reminderId, lockStartTime);

      // Execute critical section with exclusive access
      return await operation();
    } finally {
      // Always release lock, even if operation threw
      _releaseLock(reminderId);
    }
  }

  /// Acquire exclusive lock for reminder ID.
  ///
  /// If lock is already held by another operation, waits for it to complete.
  /// Tracks metrics for lock contention and wait time.
  Future<void> _acquireLock(String reminderId, DateTime startTime) async {
    _totalLockAcquisitions++;

    // Check if lock already exists
    while (_locks.containsKey(reminderId)) {
      _lockContentions++;
      _logger.debug(
        'Lock contention for reminder $reminderId - waiting for existing lock',
      );

      final existingLock = _locks[reminderId]!;

      try {
        // Wait for existing lock with timeout
        await existingLock.future.timeout(
          _config.lockTimeout,
          onTimeout: () {
            _lockTimeouts++;
            _logger.error(
              'Lock timeout waiting for reminder $reminderId encryption',
            );
            throw TimeoutException(
              'Failed to acquire encryption lock for reminder $reminderId',
              _config.lockTimeout,
            );
          },
        );
      } catch (e) {
        // If existing lock threw an error, it's still released
        // Check again in case lock was removed during error handling
        if (!_locks.containsKey(reminderId)) {
          break;
        }
        rethrow;
      }

      // Lock was released, check again in case another thread acquired it
      // This handles the case where multiple threads are waiting
    }

    // Create new lock for this operation
    _locks[reminderId] = Completer<void>();

    // Track wait time
    final waitTime = DateTime.now().difference(startTime);
    _totalWaitTimeMs += waitTime.inMilliseconds;

    if (waitTime.inMilliseconds > 100) {
      _logger.warning(
        'Long wait for encryption lock: ${waitTime.inMilliseconds}ms '
        'for reminder $reminderId',
      );
    }
  }

  /// Release lock for reminder ID.
  ///
  /// Completes the lock's future to unblock waiting threads.
  /// Removes lock from map to free memory.
  void _releaseLock(String reminderId) {
    final lock = _locks.remove(reminderId);

    if (lock != null && !lock.isCompleted) {
      lock.complete();
      _logger.debug('Released encryption lock for reminder $reminderId');
    }
  }

  /// Get statistics about lock usage for monitoring.
  ///
  /// Returns metrics including:
  /// - Total lock acquisitions
  /// - Average wait time per acquisition
  /// - Lock contention rate (% of acquisitions that had to wait)
  /// - Number of timeouts
  /// - Currently active locks
  Map<String, dynamic> getStats() {
    final avgWaitTimeMs = _totalLockAcquisitions > 0
        ? _totalWaitTimeMs / _totalLockAcquisitions
        : 0.0;

    final contentionRate = _totalLockAcquisitions > 0
        ? (_lockContentions / _totalLockAcquisitions) * 100
        : 0.0;

    return {
      'totalLockAcquisitions': _totalLockAcquisitions,
      'totalWaitTimeMs': _totalWaitTimeMs,
      'averageWaitTimeMs': avgWaitTimeMs,
      'lockContentions': _lockContentions,
      'contentionRatePercent': contentionRate,
      'lockTimeouts': _lockTimeouts,
      'activeLocksCount': _locks.length,
      'activeLockIds': _locks.keys.toList(),
    };
  }

  /// Reset all statistics (useful for testing).
  void resetStats() {
    _totalLockAcquisitions = 0;
    _totalWaitTimeMs = 0;
    _lockContentions = 0;
    _lockTimeouts = 0;
  }

  /// Clear all locks (use with caution, only for testing/cleanup).
  ///
  /// Completes all pending locks to unblock waiting threads.
  /// Should only be used during app shutdown or test cleanup.
  void clearAll() {
    for (final lock in _locks.values) {
      if (!lock.isCompleted) {
        lock.complete();
      }
    }
    _locks.clear();
    _logger.debug('Cleared all encryption locks');
  }

  /// Check if a specific reminder is currently locked.
  ///
  /// Useful for debugging and monitoring.
  bool isLocked(String reminderId) {
    return _locks.containsKey(reminderId);
  }

  /// Get list of all currently locked reminder IDs.
  ///
  /// Useful for debugging and monitoring.
  List<String> getActiveLocks() {
    return _locks.keys.toList();
  }
}
