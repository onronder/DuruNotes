import 'dart:async';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/services/reminders/encryption_lock_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncryptionLockManager', () {
    late EncryptionLockManager lockManager;

    setUp(() {
      lockManager = EncryptionLockManager();
    });

    tearDown(() {
      lockManager.clearAll();
    });

    group('Basic Locking', () {
      test('allows execution when no lock exists', () async {
        var executed = false;

        await lockManager.withLock('reminder-1', () async {
          executed = true;
        });

        expect(executed, isTrue);
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('releases lock after operation completes', () async {
        expect(lockManager.isLocked('reminder-1'), isFalse);

        await lockManager.withLock('reminder-1', () async {
          // Inside lock
          expect(lockManager.isLocked('reminder-1'), isTrue);
        });

        // After lock
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('releases lock even if operation throws', () async {
        expect(lockManager.isLocked('reminder-1'), isFalse);

        try {
          await lockManager.withLock('reminder-1', () async {
            expect(lockManager.isLocked('reminder-1'), isTrue);
            throw Exception('Test error');
          });
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Test error'));
        }

        // Lock should be released despite error
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('returns operation result', () async {
        final result = await lockManager.withLock('reminder-1', () async {
          return 42;
        });

        expect(result, equals(42));
      });

      test('returns operation result even with complex types', () async {
        final result = await lockManager.withLock('reminder-1', () async {
          return {'encrypted': true, 'count': 5};
        });

        expect(result, equals({'encrypted': true, 'count': 5}));
      });
    });

    group('Concurrent Access Prevention', () {
      test('prevents concurrent execution of same reminder ID', () async {
        final executionOrder = <String>[];
        final completer1 = Completer<void>();
        final completer2 = Completer<void>();

        // Thread 1: Acquire lock and wait
        final future1 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('thread1-start');
          await completer1.future; // Wait for signal
          executionOrder.add('thread1-end');
        });

        // Wait to ensure thread1 acquires lock first
        await Future.delayed(const Duration(milliseconds: 10));

        // Thread 2: Try to acquire same lock (should wait)
        final future2 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('thread2-start');
          completer2.complete();
          executionOrder.add('thread2-end');
        });

        // Verify thread2 is waiting
        expect(lockManager.isLocked('reminder-1'), isTrue);
        expect(executionOrder, equals(['thread1-start']));

        // Release thread1
        completer1.complete();
        await future1;

        // Thread2 should now execute
        await future2;

        // Verify execution order (thread1 completes before thread2 starts)
        expect(
          executionOrder,
          equals([
            'thread1-start',
            'thread1-end',
            'thread2-start',
            'thread2-end',
          ]),
        );
      });

      test('allows concurrent execution of different reminder IDs', () async {
        final executionOrder = <String>[];
        final completer1 = Completer<void>();
        final completer2 = Completer<void>();

        // Thread 1: reminder-1
        final future1 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('reminder1-start');
          await completer1.future;
          executionOrder.add('reminder1-end');
        });

        // Thread 2: reminder-2 (different ID, should run concurrently)
        final future2 = lockManager.withLock('reminder-2', () async {
          executionOrder.add('reminder2-start');
          await completer2.future;
          executionOrder.add('reminder2-end');
        });

        // Wait for both to start
        await Future.delayed(const Duration(milliseconds: 10));

        // Both should have started (different locks)
        expect(executionOrder, equals(['reminder1-start', 'reminder2-start']));

        // Release both
        completer1.complete();
        completer2.complete();
        await Future.wait([future1, future2]);

        // Both should have completed
        expect(executionOrder.length, equals(4));
      });

      test('handles multiple waiting threads in order', () async {
        final executionOrder = <String>[];
        final completers = [
          Completer<void>(),
          Completer<void>(),
          Completer<void>(),
        ];

        // Thread 1: Acquire lock
        final future1 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('thread1');
          await completers[0].future;
        });

        // Wait for thread1 to acquire lock
        await Future.delayed(const Duration(milliseconds: 10));

        // Threads 2 and 3: Queue up waiting for lock
        final future2 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('thread2');
          await completers[1].future;
        });

        final future3 = lockManager.withLock('reminder-1', () async {
          executionOrder.add('thread3');
          await completers[2].future;
        });

        // Wait for all threads to be queued
        await Future.delayed(const Duration(milliseconds: 10));

        // Only thread1 should have executed
        expect(executionOrder, equals(['thread1']));

        // Release thread1
        completers[0].complete();
        await future1;

        // Wait for thread2 to acquire lock
        await Future.delayed(const Duration(milliseconds: 10));
        expect(executionOrder, equals(['thread1', 'thread2']));

        // Release thread2
        completers[1].complete();
        await future2;

        // Wait for thread3 to acquire lock
        await Future.delayed(const Duration(milliseconds: 10));
        expect(executionOrder, equals(['thread1', 'thread2', 'thread3']));

        // Release thread3
        completers[2].complete();
        await future3;

        expect(executionOrder, equals(['thread1', 'thread2', 'thread3']));
      });
    });

    group('Statistics Tracking', () {
      test('tracks total lock acquisitions', () async {
        await lockManager.withLock('reminder-1', () async {});
        await lockManager.withLock('reminder-2', () async {});
        await lockManager.withLock('reminder-3', () async {});

        final stats = lockManager.getStats();
        expect(stats['totalLockAcquisitions'], equals(3));
      });

      test('tracks lock contention when threads wait', () async {
        final completer = Completer<void>();

        // Thread 1: Hold lock
        final future1 = lockManager.withLock('reminder-1', () async {
          await completer.future;
        });

        // Wait for thread1 to acquire lock
        await Future.delayed(const Duration(milliseconds: 10));

        // Thread 2: Wait for lock (creates contention)
        final future2 = lockManager.withLock('reminder-1', () async {});

        // Release thread1
        completer.complete();
        await Future.wait([future1, future2]);

        final stats = lockManager.getStats();
        expect(stats['totalLockAcquisitions'], equals(2));
        expect(stats['lockContentions'], equals(1));
        expect(stats['contentionRatePercent'], equals(50.0));
      });

      test('calculates average wait time', () async {
        final completer = Completer<void>();

        // Thread 1: Hold lock for a bit
        final future1 = lockManager.withLock('reminder-1', () async {
          await completer.future;
        });

        // Wait for thread1 to acquire lock
        await Future.delayed(const Duration(milliseconds: 10));

        // Thread 2: Will have to wait
        final future2 = lockManager.withLock('reminder-1', () async {});

        // Hold for 50ms before releasing
        await Future.delayed(const Duration(milliseconds: 50));
        completer.complete();
        await Future.wait([future1, future2]);

        final stats = lockManager.getStats();
        expect(stats['averageWaitTimeMs'], greaterThan(0));
        expect(stats['totalWaitTimeMs'], greaterThan(0));
      });

      test('reports active locks', () async {
        final completer1 = Completer<void>();
        final completer2 = Completer<void>();

        // Acquire two locks
        final future1 = lockManager.withLock('reminder-1', () async {
          await completer1.future;
        });

        final future2 = lockManager.withLock('reminder-2', () async {
          await completer2.future;
        });

        // Wait for locks to be acquired
        await Future.delayed(const Duration(milliseconds: 10));

        final stats = lockManager.getStats();
        expect(stats['activeLocksCount'], equals(2));
        expect(
          stats['activeLockIds'],
          containsAll(['reminder-1', 'reminder-2']),
        );

        // Release locks
        completer1.complete();
        completer2.complete();
        await Future.wait([future1, future2]);

        final statsAfter = lockManager.getStats();
        expect(statsAfter['activeLocksCount'], equals(0));
        expect(statsAfter['activeLockIds'], isEmpty);
      });

      test('resetStats clears all metrics', () async {
        await lockManager.withLock('reminder-1', () async {});
        await lockManager.withLock('reminder-2', () async {});

        var stats = lockManager.getStats();
        expect(stats['totalLockAcquisitions'], equals(2));

        lockManager.resetStats();

        stats = lockManager.getStats();
        expect(stats['totalLockAcquisitions'], equals(0));
        expect(stats['lockContentions'], equals(0));
        expect(stats['totalWaitTimeMs'], equals(0));
      });
    });

    group('Timeout Protection', () {
      test('times out if lock held too long with custom config', () async {
        // Create lock manager with short timeout for testing
        final shortTimeoutConfig = ReminderServiceConfig(
          lockTimeout: const Duration(milliseconds: 100),
        );
        final testLockManager = EncryptionLockManager(shortTimeoutConfig);

        try {
          final completer = Completer<void>();

          // Thread 1: Hold lock indefinitely
          final future1 = testLockManager.withLock('reminder-1', () async {
            await completer.future;
          });

          // Wait for thread1 to acquire lock
          await Future.delayed(const Duration(milliseconds: 10));

          // Thread 2: Should timeout waiting for lock
          var timeoutOccurred = false;
          try {
            await testLockManager.withLock('reminder-1', () async {
              fail('Should have timed out');
            });
          } on TimeoutException catch (e) {
            timeoutOccurred = true;
            expect(e.message, contains('reminder-1'));
          }

          expect(timeoutOccurred, isTrue);

          // Verify timeout was tracked in stats
          final stats = testLockManager.getStats();
          expect(stats['lockTimeouts'], equals(1));

          // Clean up
          completer.complete();
          await future1;
        } finally {
          testLockManager.clearAll();
        }
      });

      test('tracks timeout statistics correctly', () async {
        final shortTimeoutConfig = ReminderServiceConfig(
          lockTimeout: const Duration(milliseconds: 50),
        );
        final testLockManager = EncryptionLockManager(shortTimeoutConfig);

        try {
          final completer = Completer<void>();

          // Hold lock
          final future1 = testLockManager.withLock('reminder-1', () async {
            await completer.future;
          });

          await Future.delayed(const Duration(milliseconds: 10));

          // Attempt operation that will timeout
          var timeoutOccurred = false;
          try {
            await testLockManager.withLock('reminder-1', () async {});
          } on TimeoutException {
            timeoutOccurred = true;
          }

          expect(timeoutOccurred, isTrue);

          final stats = testLockManager.getStats();
          expect(stats['lockTimeouts'], greaterThanOrEqualTo(1));
          expect(stats['lockContentions'], greaterThanOrEqualTo(1));

          completer.complete();
          await future1;
        } finally {
          testLockManager.clearAll();
        }
      });
    });

    group('Edge Cases', () {
      test('handles rapid lock/unlock cycles', () async {
        for (var i = 0; i < 100; i++) {
          await lockManager.withLock('reminder-1', () async {
            // Quick operation
          });
        }

        final stats = lockManager.getStats();
        expect(stats['totalLockAcquisitions'], equals(100));
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('clearAll completes all pending locks', () async {
        final completer = Completer<void>();
        var operationCompleted = false;

        final future = lockManager.withLock('reminder-1', () async {
          await completer.future;
          operationCompleted = true;
        });

        // Wait for lock to be acquired
        await Future.delayed(const Duration(milliseconds: 10));
        expect(lockManager.isLocked('reminder-1'), isTrue);

        // Clear all locks (should complete the completer)
        lockManager.clearAll();

        // Complete the operation
        completer.complete();
        await future;

        expect(operationCompleted, isTrue);
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('getActiveLocks returns current lock IDs', () async {
        final completer1 = Completer<void>();
        final completer2 = Completer<void>();

        final future1 = lockManager.withLock('reminder-1', () async {
          await completer1.future;
        });

        final future2 = lockManager.withLock('reminder-2', () async {
          await completer2.future;
        });

        await Future.delayed(const Duration(milliseconds: 10));

        final activeLocks = lockManager.getActiveLocks();
        expect(activeLocks.length, equals(2));
        expect(activeLocks, containsAll(['reminder-1', 'reminder-2']));

        completer1.complete();
        completer2.complete();
        await Future.wait([future1, future2]);

        final activeLocksAfter = lockManager.getActiveLocks();
        expect(activeLocksAfter, isEmpty);
      });

      test('handles exception in waiting thread gracefully', () async {
        final completer1 = Completer<void>();

        // Thread 1: Hold lock
        final future1 = lockManager.withLock('reminder-1', () async {
          await completer1.future;
        });

        await Future.delayed(const Duration(milliseconds: 10));

        // Thread 2: Will throw during execution
        var thread2Executed = false;
        final future2 = lockManager.withLock('reminder-1', () async {
          thread2Executed = true;
          throw Exception('Thread 2 error');
        });

        // Release thread 1
        completer1.complete();
        await future1;

        // Thread 2 should execute and throw
        try {
          await future2;
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Thread 2 error'));
        }

        expect(thread2Executed, isTrue);
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('handles lock with null or empty reminder ID', () async {
        // Empty string should work as a valid lock ID
        await lockManager.withLock('', () async {
          expect(lockManager.isLocked(''), isTrue);
        });

        expect(lockManager.isLocked(''), isFalse);
      });

      test('concurrent operations with mixed success and failure', () async {
        final results = <String>[];
        final completer = Completer<void>();

        // Thread 1: Success
        final future1 = lockManager.withLock('reminder-1', () async {
          await completer.future;
          results.add('success-1');
        });

        await Future.delayed(const Duration(milliseconds: 10));

        // Thread 2: Will fail
        final future2 = lockManager.withLock('reminder-1', () async {
          results.add('fail-2');
          throw Exception('Fail 2');
        });

        // Thread 3: Success
        final future3 = lockManager.withLock('reminder-1', () async {
          results.add('success-3');
        });

        // Release thread 1
        completer.complete();
        await future1;

        // Thread 2 will execute and fail
        try {
          await future2;
        } catch (e) {
          // Expected
        }

        // Thread 3 should still execute despite thread 2 failure
        await future3;

        expect(results, equals(['success-1', 'fail-2', 'success-3']));
        expect(lockManager.isLocked('reminder-1'), isFalse);
      });

      test('verifies config is applied correctly', () async {
        final customConfig = ReminderServiceConfig(
          lockTimeout: const Duration(seconds: 45),
        );
        final customLockManager = EncryptionLockManager(customConfig);

        try {
          // Just verify it initializes without error
          await customLockManager.withLock('test', () async {});
          expect(customLockManager.isLocked('test'), isFalse);
        } finally {
          customLockManager.clearAll();
        }
      });
    });
  });
}
