import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/reminders/encryption_result.dart';
import 'package:duru_notes/services/reminders/encryption_retry_queue.dart';
import 'package:duru_notes/services/reminders/sync_encryption_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../repository/notes_repository_test.mocks.dart';

/// Unit tests for SyncEncryptionHelper (CRITICAL #4)
///
/// Tests encryption with explicit error handling, retry queue integration,
/// and validation to prevent data corruption during offline sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDb db;
  late MockCryptoBox mockCrypto;
  late SyncEncryptionHelper helper;

  setUp(() async {
    db = AppDb.forTesting(NativeDatabase.memory());
    mockCrypto = MockCryptoBox();
    helper = SyncEncryptionHelper(mockCrypto);

    // Clear retry queue (singleton) between tests
    EncryptionRetryQueue().clear();

    // Create a test note for reminders
    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: 'note-1',
            titleEncrypted: const Value('encrypted-title'),
            bodyEncrypted: const Value('encrypted-body'),
            createdAt: DateTime.utc(2025, 11, 19),
            updatedAt: DateTime.utc(2025, 11, 19),
            deleted: const Value(false),
            userId: const Value('user-123'),
            isPinned: const Value(false),
            version: const Value(1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncEncryptionHelper - Success Cases', () {
    test('encrypts unencrypted reminder successfully', () async {
      // Arrange
      final reminder = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Doctor appointment'),
          body: const Value('Annual checkup'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final fullReminder = await db.getReminderById(reminder, 'user-123');

      // Stub successful encryption
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits.reversed.toList());
      });

      // CRITICAL #7: Stub decryption for verification (roundtrip)
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;
        // Reverse the reversed codeUnits back to original
        return String.fromCharCodes(data.reversed);
      });

      // Act
      final result = await helper.encryptForSync(
        reminder: fullReminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.titleEncrypted, isNotNull);
      expect(result.bodyEncrypted, isNotNull);
      expect(result.encryptionVersion, 1);
      expect(result.error, isNull);
      expect(result.failureReason, isNull);
    });

    test('uses existing encryption if valid', () async {
      // Arrange - create reminder with existing encryption
      final titleEnc = Uint8List.fromList('encrypted-title'.codeUnits);
      final bodyEnc = Uint8List.fromList('encrypted-body'.codeUnits);

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Original Title'),
          body: const Value('Original Body'),
          titleEncrypted: Value(titleEnc),
          bodyEncrypted: Value(bodyEnc),
          encryptionVersion: const Value(1),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub decryption to return matching plaintext
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;
        if (String.fromCharCodes(data) == 'encrypted-title') {
          return 'Original Title';
        } else if (String.fromCharCodes(data) == 'encrypted-body') {
          return 'Original Body';
        }
        throw Exception('Unexpected data');
      });

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.titleEncrypted, titleEnc);
      expect(result.bodyEncrypted, bodyEnc);

      // Verify encryption was not called (used existing)
      verifyNever(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      );
    });

    test('re-encrypts if existing encryption is inconsistent', () async {
      // Arrange - create reminder with invalid encryption
      final titleEnc = Uint8List.fromList('wrong-encryption'.codeUnits);
      final bodyEnc = Uint8List.fromList('wrong-body'.codeUnits);

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Correct Title'),
          body: const Value('Correct Body'),
          titleEncrypted: Value(titleEnc),
          bodyEncrypted: Value(bodyEnc),
          encryptionVersion: const Value(1),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub decryption to return DIFFERENT plaintext for OLD encryption (inconsistent)
      // But return CORRECT plaintext for NEW encryption (verification passes)
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;

        // Check if this is the old encrypted data (wrong-encryption)
        if (String.fromCharCodes(data) == 'wrong-encryption' ||
            String.fromCharCodes(data) == 'wrong-body') {
          return 'WRONG_DECRYPTED_VALUE'; // Old encryption is inconsistent
        }

        // For new encryption (reversed codeUnits), reverse it back
        // This makes verification pass
        return String.fromCharCodes(data.reversed);
      });

      // Stub encryption for re-encryption
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits.reversed.toList());
      });

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isTrue);

      // Verify encryption WAS called (re-encrypted due to inconsistency)
      verify(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-1',
          text: 'Correct Title',
        ),
      ).called(1);

      verify(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-1',
          text: 'Correct Body',
        ),
      ).called(1);
    });
  });

  group('SyncEncryptionHelper - Failure Cases', () {
    test('fails when CryptoBox is null', () async {
      // Arrange
      final helperWithoutCrypto = SyncEncryptionHelper(null);

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Test'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Act
      final result = await helperWithoutCrypto.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isTrue); // CryptoBox unavailable is retryable
      expect(result.failureReason, contains('CryptoBox not available'));
    });

    test('fails with retryable error for timeout', () async {
      // Arrange
      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Test'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub encryption to throw timeout error
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenThrow(Exception('Encryption timeout'));

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isTrue); // Timeout is retryable
      expect(result.failureReason, contains('timeout'));
    });

    test('fails with non-retryable error for invalid key', () async {
      // Arrange
      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Test'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub encryption to throw corrupted key error
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenThrow(Exception('Invalid key - corrupted'));

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isFalse); // Corrupted key is NOT retryable
    });
  });

  group('SyncEncryptionHelper - Retry Queue Integration', () {
    test('removes from retry queue on successful encryption', () async {
      // This test verifies that retry queue integration works correctly
      // by checking that queue operations are called properly
      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Test'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub successful encryption
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // CRITICAL #7: Stub decryption for verification (roundtrip)
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;
        return String.fromCharCodes(data);
      });

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isTrue);

      // Verify queue is empty (reminder not in queue)
      final stats = helper.getRetryStats();
      expect(stats['queueSize'], 0);
    });

    test('adds to retry queue on retryable failure', () async {
      // Arrange
      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Test'),
          createdAt: Value(DateTime.utc(2025, 11, 19)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');

      // Stub encryption to throw retryable error
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenThrow(Exception('CryptoBox not initialized'));

      // Act
      final result = await helper.encryptForSync(
        reminder: reminder!,
        userId: 'user-123',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isTrue);

      // Verify item was added to retry queue
      final stats = helper.getRetryStats();
      expect(stats['queueSize'], 1);
    });
  });

  group('EncryptionRetryQueue - Queue Operations', () {
    late EncryptionRetryQueue queue;

    setUp(() {
      queue = EncryptionRetryQueue();
      queue.clear(); // Ensure clean state (singleton)
    });

    test('enqueues new entry', () {
      // Act
      final added = queue.enqueue(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Assert
      expect(added, isTrue);
      expect(queue.size, 1);
      expect(queue.isQueued('reminder-1'), isTrue);
    });

    test('increments retry count on re-enqueue', () {
      // Arrange
      queue.enqueue(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Act - Enqueue same reminder again
      queue.enqueue(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Assert
      final metadata = queue.getMetadata('reminder-1');
      expect(metadata, isNotNull);
      expect(metadata!.retryCount, 1); // First retry
      expect(queue.size, 1); // Still only 1 entry
    });

    test('dequeues entry on success', () {
      // Arrange
      queue.enqueue(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Act
      queue.dequeue('reminder-1');

      // Assert
      expect(queue.size, 0);
      expect(queue.isQueued('reminder-1'), isFalse);
    });

    test('respects max retries limit', () {
      // Arrange - First enqueue (retryCount=0)
      queue.enqueue(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Retry until we hit the limit
      // _maxRetries = 10, so retryCount can be 0, 1, 2, ..., 9 before removal
      // On the 11th call (when retryCount=10), it should be removed
      for (int i = 0; i < 11; i++) {
        final added = queue.enqueue(
          reminderId: 'reminder-1',
          noteId: 'note-1',
          userId: 'user-123',
        );

        if (i < 10) {
          // First 10 calls succeed (retryCount goes from 0 to 10)
          expect(added, isTrue, reason: 'Call ${i + 1} should succeed');
          expect(queue.isQueued('reminder-1'), isTrue);
        } else {
          // 11th call hits the limit (retryCount=10 >= maxRetries=10)
          expect(added, isFalse, reason: 'Call 11 should hit max limit');
          expect(queue.isQueued('reminder-1'), isFalse);
        }
      }

      // Assert - Queue removes entry after max retries
      expect(queue.isQueued('reminder-1'), isFalse);
    });

    test('exponential backoff calculation', () {
      // Arrange
      final metadata = EncryptionRetryMetadata.firstFailure(
        reminderId: 'reminder-1',
        noteId: 'note-1',
        userId: 'user-123',
      );

      // Assert - Check exponential backoff
      expect(metadata.nextRetryDelayMs, 1000); // 1 second (2^0 * 1000)

      final retry1 = metadata.incrementRetry();
      expect(retry1.nextRetryDelayMs, 2000); // 2 seconds (2^1 * 1000)

      final retry2 = retry1.incrementRetry();
      expect(retry2.nextRetryDelayMs, 4000); // 4 seconds (2^2 * 1000)

      final retry3 = retry2.incrementRetry();
      expect(retry3.nextRetryDelayMs, 8000); // 8 seconds (2^3 * 1000)
    });
  });

  group('ReminderEncryptionResult - Factory Methods', () {
    test('success factory creates valid result', () {
      // Arrange
      final titleEnc = Uint8List.fromList([1, 2, 3]);
      final bodyEnc = Uint8List.fromList([4, 5, 6]);

      // Act
      final result = ReminderEncryptionResult.success(
        titleEncrypted: titleEnc,
        bodyEncrypted: bodyEnc,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.titleEncrypted, titleEnc);
      expect(result.bodyEncrypted, bodyEnc);
      expect(result.encryptionVersion, 1);
      expect(result.isRetryable, isFalse);
      expect(result.error, isNull);
    });

    test('failure factory creates valid result', () {
      // Arrange
      final error = Exception('Test error');

      // Act
      final result = ReminderEncryptionResult.failure(
        error: error,
        reason: 'Test failure reason',
        isRetryable: true,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.error, error);
      expect(result.failureReason, 'Test failure reason');
      expect(result.isRetryable, isTrue);
      expect(result.titleEncrypted, isNull);
    });

    test('cryptoBoxUnavailable factory creates retryable result', () {
      // Act
      final result = ReminderEncryptionResult.cryptoBoxUnavailable();

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isTrue);
      expect(result.failureReason, contains('CryptoBox not available'));
    });

    test('keyNotUnlocked factory creates retryable result', () {
      // Act
      final result = ReminderEncryptionResult.keyNotUnlocked();

      // Assert
      expect(result.success, isFalse);
      expect(result.isRetryable, isTrue);
      expect(result.failureReason, contains('Master key not unlocked'));
    });
  });
}
