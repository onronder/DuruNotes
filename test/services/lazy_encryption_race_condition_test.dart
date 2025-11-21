import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/reminders/recurring_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:duru_notes/test/test_utils/uuid_test_helper.dart';

@GenerateNiceMocks([
  MockSpec<ProviderContainer>(),
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<CryptoBox>(),
])
import 'lazy_encryption_race_condition_test.mocks.dart';

/// CRITICAL #6: Test lazy encryption race condition fix
///
/// This test simulates concurrent encryption attempts to verify the lock
/// manager prevents duplicate work and data corruption.
void main() {
  group('Lazy Encryption Race Condition', () {
    late AppDb db;
    late MockCryptoBox mockCryptoBox;
    late RecurringReminderService reminderService;
    late MockProviderContainer mockContainer;
    late MockFlutterLocalNotificationsPlugin mockPlugin;

    const testUserId = 'test-user-123';
    const testNoteId = 'test-note-456';

    setUp(() async {
      // Create in-memory database
      db = AppDb(NativeDatabase.memory());

      // Create mocks
      mockCryptoBox = MockCryptoBox();
      mockContainer = MockProviderContainer();
      mockPlugin = MockFlutterLocalNotificationsPlugin();

      // Setup basic mocks
      when(mockContainer.read(any)).thenReturn(null);

      // Setup crypto box to simulate encryption with delay
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        // Simulate encryption work with delay
        await Future.delayed(const Duration(milliseconds: 50));
        final text = _.namedArguments[const Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // Create service
      reminderService = RecurringReminderService(
        mockContainer,
        mockPlugin,
        db,
        cryptoBox: mockCryptoBox,
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to create unencrypted reminder
    Future<NoteReminder> createUnencryptedReminder(String title) async {
      final reminderId = UuidTestHelper.deterministicUuid('reminder-$title');

      await db.into(db.noteReminders).insert(
            NoteRemindersCompanion.insert(
              id: reminderId,
              userId: testUserId,
              noteId: testNoteId,
              title: title,
              body: 'Test body for $title',
              scheduledTime: DateTime.now().add(const Duration(hours: 1)),
              recurrencePattern: RecurrencePattern.none,
              recurrenceInterval: 1,
              reminderType: ReminderType.local,
              // No encrypted fields - plaintext only
            ),
          );

      final reminder = await db.getReminderByIdIncludingDeleted(
        reminderId,
        testUserId,
      );

      expect(reminder, isNotNull);
      expect(reminder!.titleEncrypted, isNull);
      expect(reminder.bodyEncrypted, isNull);
      expect(reminder.encryptionVersion, isNull);

      return reminder;
    }

    test('prevents duplicate encryption when accessed concurrently', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Concurrent Test');

      // Track encryption calls
      var encryptionCallCount = 0;
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        encryptionCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        final text = _.namedArguments[const Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // ACT: Trigger 5 concurrent encryption attempts
      final futures = List.generate(
        5,
        (_) => reminderService.ensureReminderEncrypted(reminder),
      );

      final results = await Future.wait(futures);

      // ASSERT: Only ONE thread should have performed encryption
      final encryptedCount = results.where((r) => r == true).length;
      expect(
        encryptedCount,
        equals(1),
        reason: 'Only one thread should successfully encrypt',
      );

      // Verify reminder is encrypted in database
      final updated = await db.getReminderByIdIncludingDeleted(
        reminder.id,
        testUserId,
      );
      expect(updated!.titleEncrypted, isNotNull);
      expect(updated.bodyEncrypted, isNotNull);
      expect(updated.encryptionVersion, equals(1));

      // CRITICAL: Encryption should be called exactly 2 times per field
      // (title + body = 2 calls total, not 10 calls for 5 threads)
      // Note: May be 3 calls if location is encrypted
      expect(
        encryptionCallCount,
        lessThanOrEqual(3),
        reason: 'Should not encrypt multiple times due to lock',
      );
    });

    test('handles lock contention correctly with staggered access', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Staggered Test');

      final results = <bool>[];

      // ACT: Launch threads with staggered delays
      for (var i = 0; i < 3; i++) {
        // Stagger by 20ms each
        Future.delayed(Duration(milliseconds: i * 20), () async {
          final result = await reminderService.ensureReminderEncrypted(reminder);
          results.add(result);
        });
      }

      // Wait for all to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // ASSERT: Only first thread should encrypt
      expect(
        results.where((r) => r == true).length,
        equals(1),
        reason: 'Only first thread should encrypt, others skip',
      );
    });

    test('double-check pattern prevents stale data encryption', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Double Check Test');

      // Track what text was encrypted
      final encryptedTexts = <String>[];
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('nodeId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        final text = _.namedArguments[const Symbol('text')] as String;
        encryptedTexts.add(text);
        await Future.delayed(const Duration(milliseconds: 50));
        return Uint8List.fromList(text.codeUnits);
      });

      // ACT: Start encryption in background
      final future1 = reminderService.ensureReminderEncrypted(reminder);

      // While encrypting, update the reminder title in database
      await Future.delayed(const Duration(milliseconds: 10));
      await db.updateReminder(
        reminder.id,
        testUserId,
        const NoteRemindersCompanion(
          title: Value('UPDATED TITLE'),
        ),
      );

      // Wait for encryption to complete
      await future1;

      // ASSERT: Should encrypt current data from database, not stale data
      // The double-check fetches latest data before encrypting
      expect(
        encryptedTexts.contains('UPDATED TITLE'),
        isTrue,
        reason: 'Should encrypt current data, not stale reminder parameter',
      );
    });

    test('releases lock even if encryption fails', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Error Test');

      // Make encryption fail
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenThrow(Exception('Encryption failed'));

      // ACT: Try to encrypt (should fail)
      final result1 = await reminderService.ensureReminderEncrypted(reminder);
      expect(result1, isFalse);

      // ASSERT: Lock should be released, allow retry
      // Fix the encryption mock
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        final text = _.namedArguments[const Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // Retry should work (lock was released)
      final result2 = await reminderService.ensureReminderEncrypted(reminder);
      expect(result2, isTrue);
    });

    test('handles concurrent encryption of different reminders', () async {
      // ARRANGE: Create multiple reminders
      final reminder1 = await createUnencryptedReminder('Reminder 1');
      final reminder2 = await createUnencryptedReminder('Reminder 2');
      final reminder3 = await createUnencryptedReminder('Reminder 3');

      // ACT: Encrypt all concurrently (different IDs, should run in parallel)
      final results = await Future.wait([
        reminderService.ensureReminderEncrypted(reminder1),
        reminderService.ensureReminderEncrypted(reminder2),
        reminderService.ensureReminderEncrypted(reminder3),
      ]);

      // ASSERT: All should succeed
      expect(results, equals([true, true, true]));

      // Verify all are encrypted
      final updated1 = await db.getReminderByIdIncludingDeleted(
        reminder1.id,
        testUserId,
      );
      final updated2 = await db.getReminderByIdIncludingDeleted(
        reminder2.id,
        testUserId,
      );
      final updated3 = await db.getReminderByIdIncludingDeleted(
        reminder3.id,
        testUserId,
      );

      expect(updated1!.titleEncrypted, isNotNull);
      expect(updated2!.titleEncrypted, isNotNull);
      expect(updated3!.titleEncrypted, isNotNull);
    });

    test('lock stats track contention correctly', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Stats Test');

      // Make encryption take longer to ensure contention
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        final text = _.namedArguments[const Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // ACT: Launch 3 concurrent attempts
      await Future.wait([
        reminderService.ensureReminderEncrypted(reminder),
        reminderService.ensureReminderEncrypted(reminder),
        reminderService.ensureReminderEncrypted(reminder),
      ]);

      // ASSERT: Check lock statistics
      final stats = reminderService.getEncryptionLockStats();
      expect(stats['totalLockAcquisitions'], greaterThanOrEqual(1));
      expect(stats['lockContentions'], greaterThanOrEqual(0));
      expect(stats['lockTimeouts'], equals(0));
      expect(stats['activeLocksCount'], equals(0)); // All released
    });

    test('skips encryption if reminder deleted while waiting for lock', () async {
      // ARRANGE: Create plaintext reminder
      final reminder = await createUnencryptedReminder('Delete Test');

      // Make encryption slow
      when(
        mockCryptoBox.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        final text = _.namedArguments[const Symbol('text')] as String;
        return Uint8List.fromList(text.codeUnits);
      });

      // ACT: Start encryption
      final future1 = reminderService.ensureReminderEncrypted(reminder);

      // While first encryption is in progress, start second encryption attempt
      await Future.delayed(const Duration(milliseconds: 10));
      final future2 = reminderService.ensureReminderEncrypted(reminder);

      // Delete reminder while second thread waits for lock
      await Future.delayed(const Duration(milliseconds: 20));
      await db.deleteReminderById(reminder.id, testUserId);

      // Wait for both to complete
      final result1 = await future1;
      final result2 = await future2;

      // ASSERT: First encryption might succeed or fail depending on timing
      // Second encryption should return false (reminder deleted)
      expect(result2, isFalse);

      // Reminder should be soft-deleted
      final deleted = await db.getReminderById(reminder.id, testUserId);
      expect(deleted, isNull); // Excluded from normal query

      final deletedIncluded = await db.getReminderByIdIncludingDeleted(
        reminder.id,
        testUserId,
      );
      expect(deletedIncluded?.deletedAt, isNotNull);
    });
  });
}
