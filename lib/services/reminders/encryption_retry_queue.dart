import 'dart:async';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/reminders/encryption_result.dart';

/// In-memory queue for managing failed encryption retry attempts
///
/// **Purpose:**
/// When reminder encryption fails (e.g., offline, CryptoBox unavailable),
/// reminders are queued for retry rather than uploading inconsistent data.
///
/// **Architecture:**
/// - In-memory queue (persisted state not needed - will retry on next sync)
/// - Exponential backoff (1s, 2s, 4s, 8s, ... up to 5 min)
/// - Max retry limit (configurable via ReminderConfig)
/// - Automatic cleanup of old entries
///
/// **Thread Safety:**
/// - Single-threaded (Dart isolate model)
/// - No concurrent access issues in Flutter apps
///
/// **Production Considerations:**
/// - Queue is lost on app restart (acceptable - sync will retry)
/// - Memory bounded (configurable max queue size)
/// - Automatic expiry (configurable max age)
class EncryptionRetryQueue {
  final _logger = LoggerFactory.instance;

  /// Active retry metadata keyed by reminder ID
  final Map<String, EncryptionRetryMetadata> _queue = {};

  /// Configuration for retry queue limits
  final ReminderServiceConfig _config;

  /// Creates a retry queue with the given configuration
  EncryptionRetryQueue([ReminderServiceConfig? config])
    : _config = config ?? ReminderServiceConfig.defaultConfig();

  /// Add a reminder to the retry queue after encryption failure
  ///
  /// Returns true if added, false if queue is full or entry too old
  bool enqueue({
    required String reminderId,
    required String noteId,
    required String userId,
  }) {
    // Check queue size limit
    if (_queue.length >= _config.maxQueueSize) {
      _logger.warning(
        '[EncryptionRetryQueue] Queue full, cannot enqueue reminder',
        data: {'reminderId': reminderId, 'queueSize': _queue.length},
      );
      return false;
    }

    // Check if already in queue
    if (_queue.containsKey(reminderId)) {
      // Increment retry count
      final existing = _queue[reminderId]!;

      // Check max retries
      if (existing.retryCount >= _config.maxRetries) {
        _logger.error(
          '[EncryptionRetryQueue] Max retries exceeded, removing from queue',
          data: {'reminderId': reminderId, 'retryCount': existing.retryCount},
        );
        _queue.remove(reminderId);
        return false;
      }

      // Increment retry
      _queue[reminderId] = existing.incrementRetry();
      _logger.info(
        '[EncryptionRetryQueue] Incremented retry count',
        data: {
          'reminderId': reminderId,
          'retryCount': _queue[reminderId]!.retryCount,
          'nextRetryMs': _queue[reminderId]!.nextRetryDelayMs,
        },
      );
    } else {
      // Add new entry
      _queue[reminderId] = EncryptionRetryMetadata.firstFailure(
        reminderId: reminderId,
        noteId: noteId,
        userId: userId,
      );
      _logger.info(
        '[EncryptionRetryQueue] Added to queue',
        data: {'reminderId': reminderId, 'queueSize': _queue.length},
      );
    }

    // Cleanup old entries
    _cleanupExpired();

    return true;
  }

  /// Remove a reminder from the queue after successful encryption
  void dequeue(String reminderId) {
    if (_queue.remove(reminderId) != null) {
      _logger.info(
        '[EncryptionRetryQueue] Removed from queue after success',
        data: {'reminderId': reminderId, 'queueSize': _queue.length},
      );
    }
  }

  /// Get all reminders ready for retry
  ///
  /// Returns reminders where:
  /// - Exponential backoff delay has elapsed
  /// - Not exceeded max retry count
  /// - Not expired (older than max age)
  List<EncryptionRetryMetadata> getReadyForRetry() {
    final ready = <EncryptionRetryMetadata>[];

    for (final metadata in _queue.values) {
      // Check if should retry now (backoff elapsed)
      if (!metadata.shouldRetryNow) {
        continue;
      }

      // Check age
      final age = DateTime.now().difference(metadata.firstFailureTime);
      if (age > _config.queueMaxAge) {
        continue;
      }

      ready.add(metadata);
    }

    _logger.debug(
      '[EncryptionRetryQueue] Found ready for retry',
      data: {'count': ready.length, 'totalQueue': _queue.length},
    );

    return ready;
  }

  /// Check if a reminder is in the retry queue
  bool isQueued(String reminderId) => _queue.containsKey(reminderId);

  /// Get retry metadata for a reminder
  EncryptionRetryMetadata? getMetadata(String reminderId) => _queue[reminderId];

  /// Get current queue size
  int get size => _queue.length;

  /// Get queue statistics for monitoring
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    int totalRetries = 0;
    int readyForRetry = 0;
    int expiredCount = 0;

    for (final metadata in _queue.values) {
      totalRetries += metadata.retryCount;

      if (metadata.shouldRetryNow) {
        readyForRetry++;
      }

      final age = now.difference(metadata.firstFailureTime);
      if (age > _config.queueMaxAge) {
        expiredCount++;
      }
    }

    return {
      'queueSize': _queue.length,
      'readyForRetry': readyForRetry,
      'totalRetries': totalRetries,
      'expiredCount': expiredCount,
      'maxRetries': _config.maxRetries,
      'maxQueueSize': _config.maxQueueSize,
      'maxAgeMinutes': _config.queueMaxAge.inMinutes,
    };
  }

  /// Clear all entries (for testing or reset)
  void clear() {
    final count = _queue.length;
    _queue.clear();
    _logger.info(
      '[EncryptionRetryQueue] Cleared queue',
      data: {'removedCount': count},
    );
  }

  /// Remove expired entries (older than max age)
  void _cleanupExpired() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _queue.entries) {
      final age = now.difference(entry.value.firstFailureTime);
      if (age > _config.queueMaxAge) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _queue.remove(id);
    }

    if (toRemove.isNotEmpty) {
      _logger.info(
        '[EncryptionRetryQueue] Cleaned up expired entries',
        data: {'removedCount': toRemove.length, 'queueSize': _queue.length},
      );
    }
  }

  /// Process retry queue (call this periodically or on CryptoBox availability)
  ///
  /// Returns the number of reminders that still need retry
  Future<int> processRetries(
    Future<ReminderEncryptionResult> Function(EncryptionRetryMetadata)
    retryCallback,
  ) async {
    final ready = getReadyForRetry();

    if (ready.isEmpty) {
      return _queue.length; // Return pending count
    }

    _logger.info(
      '[EncryptionRetryQueue] Processing retries',
      data: {'count': ready.length},
    );

    int successCount = 0;
    int failureCount = 0;

    for (final metadata in ready) {
      try {
        final result = await retryCallback(metadata);

        if (result.success) {
          // Success - remove from queue
          dequeue(metadata.reminderId);
          successCount++;
        } else {
          // Failed - increment retry count or remove if non-retryable
          if (result.isRetryable) {
            enqueue(
              reminderId: metadata.reminderId,
              noteId: metadata.noteId,
              userId: metadata.userId,
            );
            failureCount++;
          } else {
            // Non-retryable error - remove from queue
            _queue.remove(metadata.reminderId);
            _logger.error(
              '[EncryptionRetryQueue] Non-retryable error, removed from queue',
              error: result.error,
              data: {
                'reminderId': metadata.reminderId,
                'reason': result.failureReason,
              },
            );
          }
        }
      } catch (error, stack) {
        _logger.error(
          '[EncryptionRetryQueue] Error during retry',
          error: error,
          stackTrace: stack,
          data: {'reminderId': metadata.reminderId},
        );
        failureCount++;
      }
    }

    _logger.info(
      '[EncryptionRetryQueue] Retry batch complete',
      data: {
        'success': successCount,
        'failures': failureCount,
        'remaining': _queue.length,
      },
    );

    return _queue.length;
  }
}
