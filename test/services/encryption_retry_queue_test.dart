import 'dart:async';
import 'dart:typed_data';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/services/reminders/encryption_result.dart';
import 'package:duru_notes/services/reminders/encryption_retry_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncryptionRetryQueue', () {
    late EncryptionRetryQueue queue;

    setUp(() {
      queue = EncryptionRetryQueue();
    });

    tearDown(() {
      queue.clear();
    });

    group('Basic Enqueue/Dequeue', () {
      test('enqueues reminder successfully', () {
        final result = queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        expect(result, isTrue);
        expect(queue.isQueued('reminder-1'), isTrue);
        expect(queue.size, equals(1));
      });

      test('dequeues reminder successfully', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        expect(queue.isQueued('reminder-1'), isTrue);

        queue.dequeue('reminder-1');

        expect(queue.isQueued('reminder-1'), isFalse);
        expect(queue.size, equals(0));
      });

      test('dequeue non-existent reminder does not throw', () {
        expect(() => queue.dequeue('non-existent'), returnsNormally);
        expect(queue.size, equals(0));
      });

      test('can enqueue multiple different reminders', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-2',
          noteId: 'note-2',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-3',
          noteId: 'note-3',
          userId: 'user-1',
        );

        expect(queue.size, equals(3));
        expect(queue.isQueued('reminder-1'), isTrue);
        expect(queue.isQueued('reminder-2'), isTrue);
        expect(queue.isQueued('reminder-3'), isTrue);
      });
    });

    group('Retry Logic', () {
      test('increments retry count when enqueuing existing reminder', () {
        // First failure
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        var metadata = queue.getMetadata('reminder-1');
        expect(metadata?.retryCount, equals(0));

        // Second failure
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        metadata = queue.getMetadata('reminder-1');
        expect(metadata?.retryCount, equals(1));

        // Third failure
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        metadata = queue.getMetadata('reminder-1');
        expect(metadata?.retryCount, equals(2));
      });

      test('respects max retries limit', () {
        final config = ReminderServiceConfig(maxRetries: 3);
        final limitedQueue = EncryptionRetryQueue(config);

        try {
          // Enqueue 5 times:
          // 1st: retryCount=0
          // 2nd: retryCount=1
          // 3rd: retryCount=2
          // 4th: retryCount=3
          // 5th: retryCount=3 >= maxRetries(3), should remove and return false
          for (var i = 0; i < 5; i++) {
            final result = limitedQueue.enqueue(
              reminderId: 'reminder-1',
              noteId: 'note-1',
              userId: 'user-1',
            );
            if (i == 4) {
              // 5th enqueue should fail due to max retries
              expect(result, isFalse);
            }
          }

          // Should have been removed after exceeding max retries
          expect(limitedQueue.isQueued('reminder-1'), isFalse);
        } finally {
          limitedQueue.clear();
        }
      });

      test('exponential backoff increases delay between retries', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        var metadata = queue.getMetadata('reminder-1')!;
        final delay1 = metadata.nextRetryDelayMs;

        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        metadata = queue.getMetadata('reminder-1')!;
        final delay2 = metadata.nextRetryDelayMs;

        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        metadata = queue.getMetadata('reminder-1')!;
        final delay3 = metadata.nextRetryDelayMs;

        // Each delay should be roughly double the previous (exponential backoff)
        expect(delay2, greaterThan(delay1));
        expect(delay3, greaterThan(delay2));
      });

      test('shouldRetryNow returns true immediately after enqueueing', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        final metadata = queue.getMetadata('reminder-1')!;
        // First attempt should be ready immediately (lastRetryTime is null)
        expect(metadata.shouldRetryNow, isTrue);
      });

      test('shouldRetryNow returns false after re-enqueue before backoff', () async {
        final config = ReminderServiceConfig(maxRetries: 5);
        final testQueue = EncryptionRetryQueue(config);

        try {
          // First enqueue
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          // Re-enqueue (simulates failed retry)
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          var metadata = testQueue.getMetadata('reminder-1')!;
          final delayMs = metadata.nextRetryDelayMs;

          // Should not be ready immediately after re-enqueue (backoff in effect)
          expect(metadata.shouldRetryNow, isFalse);

          // Wait for delay to pass
          await Future.delayed(Duration(milliseconds: delayMs + 100));

          metadata = testQueue.getMetadata('reminder-1')!;
          expect(metadata.shouldRetryNow, isTrue);
        } finally {
          testQueue.clear();
        }
      });
    });

    group('Queue Size Limits', () {
      test('respects max queue size', () {
        final config = ReminderServiceConfig(maxQueueSize: 3);
        final limitedQueue = EncryptionRetryQueue(config);

        try {
          // Add 3 reminders (should succeed)
          for (var i = 1; i <= 3; i++) {
            final result = limitedQueue.enqueue(
              reminderId: 'reminder-$i',
              noteId: 'note-$i',
              userId: 'user-1',
            );
            expect(result, isTrue);
          }

          expect(limitedQueue.size, equals(3));

          // Try to add 4th reminder (should fail)
          final result = limitedQueue.enqueue(
            reminderId: 'reminder-4',
            noteId: 'note-4',
            userId: 'user-1',
          );

          expect(result, isFalse);
          expect(limitedQueue.size, equals(3));
          expect(limitedQueue.isQueued('reminder-4'), isFalse);
        } finally {
          limitedQueue.clear();
        }
      });

      test('re-enqueuing at capacity still fails size check', () {
        final config = ReminderServiceConfig(maxQueueSize: 2);
        final limitedQueue = EncryptionRetryQueue(config);

        try {
          limitedQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          expect(limitedQueue.size, equals(1));

          // Re-enqueue reminder-1 (should succeed, size still 1)
          final result = limitedQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          expect(result, isTrue);
          expect(limitedQueue.size, equals(1)); // Size unchanged
        } finally {
          limitedQueue.clear();
        }
      });
    });

    group('Age-based Expiry', () {
      test('cleans up expired entries', () async {
        final config = ReminderServiceConfig(
          queueMaxAge: const Duration(milliseconds: 100),
        );
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          expect(testQueue.size, equals(1));

          // Wait for entry to expire
          await Future.delayed(const Duration(milliseconds: 150));

          // Try to enqueue another reminder, which triggers cleanup
          testQueue.enqueue(
            reminderId: 'reminder-2',
            noteId: 'note-2',
            userId: 'user-1',
          );

          // reminder-1 should have been cleaned up
          expect(testQueue.isQueued('reminder-1'), isFalse);
          expect(testQueue.size, equals(1));
        } finally {
          testQueue.clear();
        }
      });

      test('getReadyForRetry excludes expired entries', () async {
        final config = ReminderServiceConfig(
          queueMaxAge: const Duration(milliseconds: 100),
        );
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          // Wait for expiry
          await Future.delayed(const Duration(milliseconds: 150));

          final ready = testQueue.getReadyForRetry();

          // Should not include expired entry
          expect(ready.isEmpty, isTrue);
        } finally {
          testQueue.clear();
        }
      });
    });

    group('getReadyForRetry', () {
      test('returns empty list when queue is empty', () {
        final ready = queue.getReadyForRetry();
        expect(ready, isEmpty);
      });

      test('includes items ready for first attempt immediately', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );

        final ready = queue.getReadyForRetry();

        // First attempt should be ready immediately (lastRetryTime is null)
        expect(ready, hasLength(1));
        expect(ready[0].reminderId, equals('reminder-1'));
      });

      test('includes items ready for retry after backoff', () async {
        final config = ReminderServiceConfig();
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          final metadata = testQueue.getMetadata('reminder-1')!;
          await Future.delayed(
            Duration(milliseconds: metadata.nextRetryDelayMs + 50),
          );

          final ready = testQueue.getReadyForRetry();

          expect(ready.length, equals(1));
          expect(ready.first.reminderId, equals('reminder-1'));
        } finally {
          testQueue.clear();
        }
      });
    });

    group('Statistics', () {
      test('getStats returns correct queue size', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-2',
          noteId: 'note-2',
          userId: 'user-1',
        );

        final stats = queue.getStats();
        expect(stats['queueSize'], equals(2));
      });

      test('getStats tracks total retries', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-2',
          noteId: 'note-2',
          userId: 'user-1',
        );

        final stats = queue.getStats();
        expect(stats['totalRetries'], equals(1)); // reminder-1 has 1 retry
      });

      test('getStats includes config values', () {
        final config = ReminderServiceConfig(
          maxRetries: 15,
          maxQueueSize: 500,
          queueMaxAge: const Duration(hours: 2),
        );
        final testQueue = EncryptionRetryQueue(config);

        try {
          final stats = testQueue.getStats();
          expect(stats['maxRetries'], equals(15));
          expect(stats['maxQueueSize'], equals(500));
          expect(stats['maxAgeMinutes'], equals(120));
        } finally {
          testQueue.clear();
        }
      });
    });

    group('processRetries', () {
      test('processes ready reminders', () async {
        final config = ReminderServiceConfig();
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          final metadata = testQueue.getMetadata('reminder-1')!;
          await Future.delayed(
            Duration(milliseconds: metadata.nextRetryDelayMs + 50),
          );

          var processedIds = <String>[];
          final remaining = await testQueue.processRetries(
            (metadata) async {
              processedIds.add(metadata.reminderId);
              return ReminderEncryptionResult.success(
                titleEncrypted: Uint8List(0),
                bodyEncrypted: Uint8List(0),
              );
            },
          );

          expect(processedIds, contains('reminder-1'));
          expect(remaining, equals(0));
          expect(testQueue.isQueued('reminder-1'), isFalse);
        } finally {
          testQueue.clear();
        }
      });

      test('removes non-retryable failures from queue', () async {
        final config = ReminderServiceConfig();
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          final metadata = testQueue.getMetadata('reminder-1')!;
          await Future.delayed(
            Duration(milliseconds: metadata.nextRetryDelayMs + 50),
          );

          await testQueue.processRetries((metadata) async {
            return ReminderEncryptionResult.failure(
              error: Exception('Non-retryable'),
              reason: 'Test',
              isRetryable: false,
            );
          });

          expect(testQueue.isQueued('reminder-1'), isFalse);
        } finally {
          testQueue.clear();
        }
      });

      test('keeps retryable failures in queue', () async {
        final config = ReminderServiceConfig();
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          final metadata = testQueue.getMetadata('reminder-1')!;
          await Future.delayed(
            Duration(milliseconds: metadata.nextRetryDelayMs + 50),
          );

          await testQueue.processRetries((metadata) async {
            return ReminderEncryptionResult.failure(
              error: Exception('Retryable'),
              reason: 'Test',
              isRetryable: true,
            );
          });

          expect(testQueue.isQueued('reminder-1'), isTrue);
        } finally {
          testQueue.clear();
        }
      });

      test('handles exceptions during retry callback', () async {
        final config = ReminderServiceConfig();
        final testQueue = EncryptionRetryQueue(config);

        try {
          testQueue.enqueue(
            reminderId: 'reminder-1',
            noteId: 'note-1',
            userId: 'user-1',
          );

          final metadata = testQueue.getMetadata('reminder-1')!;
          await Future.delayed(
            Duration(milliseconds: metadata.nextRetryDelayMs + 50),
          );

          final remaining = await testQueue.processRetries((metadata) async {
            throw Exception('Callback error');
          });

          // Should still be in queue (failures are retryable by default)
          expect(testQueue.isQueued('reminder-1'), isTrue);
          expect(remaining, greaterThan(0));
        } finally {
          testQueue.clear();
        }
      });
    });

    group('clear', () {
      test('removes all entries from queue', () {
        queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-1',
        );
        queue.enqueue(
          reminderId: 'reminder-2',
          noteId: 'note-2',
          userId: 'user-1',
        );

        expect(queue.size, equals(2));

        queue.clear();

        expect(queue.size, equals(0));
        expect(queue.isQueued('reminder-1'), isFalse);
        expect(queue.isQueued('reminder-2'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles empty reminder ID', () {
        final result = queue.enqueue(
          reminderId: '',
          noteId: 'note-1',
          userId: 'user-1',
        );

        expect(result, isTrue);
        expect(queue.isQueued(''), isTrue);
      });

      test('handles very long reminder ID', () {
        final longId = 'r' * 1000;
        final result = queue.enqueue(
          reminderId: longId,
          noteId: 'note-1',
          userId: 'user-1',
        );

        expect(result, isTrue);
        expect(queue.isQueued(longId), isTrue);
      });

      test('handles rapid enqueue/dequeue cycles', () {
        for (var i = 0; i < 100; i++) {
          queue.enqueue(
            reminderId: 'reminder-$i',
            noteId: 'note-$i',
            userId: 'user-1',
          );
          queue.dequeue('reminder-$i');
        }

        expect(queue.size, equals(0));
      });
    });
  });
}
