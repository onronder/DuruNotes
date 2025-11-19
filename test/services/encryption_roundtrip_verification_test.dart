import 'dart:typed_data';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/reminders/sync_encryption_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<CryptoBox>()])
import 'encryption_roundtrip_verification_test.mocks.dart';

/// CRITICAL #7: Test encryption roundtrip verification
///
/// Ensures that after encryption, the encrypted data can be decrypted back
/// to the original plaintext, preventing silent data corruption.
void main() {
  group('Encryption Roundtrip Verification', () {
    late MockCryptoBox mockCryptoBox;
    late SyncEncryptionHelper helper;

    const testUserId = 'test-user-123';
    const testNoteId = 'test-note-456';
    const testReminderId = 'test-reminder-789';

    setUp(() {
      mockCryptoBox = MockCryptoBox();
      helper = SyncEncryptionHelper(mockCryptoBox);
    });

    /// Helper to create a mock reminder
    NoteReminder createMockReminder({
      String title = 'Test Reminder',
      String body = 'Test Body',
      String? locationName,
      Uint8List? titleEncrypted,
      Uint8List? bodyEncrypted,
      Uint8List? locationNameEncrypted,
      int? encryptionVersion,
    }) {
      return NoteReminder(
        id: testReminderId,
        userId: testUserId,
        noteId: testNoteId,
        title: title,
        body: body,
        locationName: locationName,
        type: ReminderType.time,
        remindAt: DateTime.now().add(const Duration(hours: 1)),
        isActive: true,
        latitude: null,
        longitude: null,
        radius: null,
        recurrencePattern: RecurrencePattern.none,
        recurrenceInterval: 1,
        recurrenceEndDate: null,
        snoozedUntil: null,
        snoozeCount: 0,
        notificationTitle: null,
        notificationBody: null,
        notificationImage: null,
        timeZone: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: null,
        scheduledPurgeAt: null,
        lastTriggered: null,
        triggerCount: 0,
        titleEncrypted: titleEncrypted,
        bodyEncrypted: bodyEncrypted,
        locationNameEncrypted: locationNameEncrypted,
        encryptionVersion: encryptionVersion,
      );
    }

    group('Success Cases', () {
      test('verification passes when encryption roundtrips correctly', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Buy milk',
          body: 'From the store',
        );

        final titleEncrypted = Uint8List.fromList('Buy milk'.codeUnits);
        final bodyEncrypted = Uint8List.fromList('From the store'.codeUnits);

        // Mock encryption
        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Buy milk',
          ),
        ).thenAnswer((_) async => titleEncrypted);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'From the store',
          ),
        ).thenAnswer((_) async => bodyEncrypted);

        // Mock verification (decrypt back to original)
        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: titleEncrypted,
          ),
        ).thenAnswer((_) async => 'Buy milk');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: bodyEncrypted,
          ),
        ).thenAnswer((_) async => 'From the store');

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isTrue);
        expect(result.titleEncrypted, equals(titleEncrypted));
        expect(result.bodyEncrypted, equals(bodyEncrypted));

        // Verify that decryption was called (roundtrip verification happened)
        verify(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: titleEncrypted,
          ),
        ).called(1);

        verify(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: bodyEncrypted,
          ),
        ).called(1);
      });

      test('verification passes for all fields including locationName', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Meeting',
          body: 'Team sync',
          locationName: 'Conference Room A',
        );

        final titleEnc = Uint8List.fromList('Meeting'.codeUnits);
        final bodyEnc = Uint8List.fromList('Team sync'.codeUnits);
        final locationEnc = Uint8List.fromList('Conference Room A'.codeUnits);

        // Mock encryption
        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'Meeting',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'Team sync',
          ),
        ).thenAnswer((_) async => bodyEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'Conference Room A',
          ),
        ).thenAnswer((_) async => locationEnc);

        // Mock verification (all roundtrip correctly)
        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: titleEnc,
          ),
        ).thenAnswer((_) async => 'Meeting');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => 'Team sync');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: locationEnc,
          ),
        ).thenAnswer((_) async => 'Conference Room A');

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isTrue);
        expect(result.titleEncrypted, equals(titleEnc));
        expect(result.bodyEncrypted, equals(bodyEnc));
        expect(result.locationNameEncrypted, equals(locationEnc));
      });

      test('verification passes for existing encryption when consistent', () async {
        // ARRANGE
        final titleEnc = Uint8List.fromList('Encrypted title'.codeUnits);
        final bodyEnc = Uint8List.fromList('Encrypted body'.codeUnits);

        final reminder = createMockReminder(
          title: 'My Title',
          body: 'My Body',
          titleEncrypted: titleEnc,
          bodyEncrypted: bodyEnc,
          encryptionVersion: 1,
        );

        // Mock verification (decrypt to original)
        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: titleEnc,
          ),
        ).thenAnswer((_) async => 'My Title');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => 'My Body');

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isTrue);
        expect(result.titleEncrypted, equals(titleEnc));
        expect(result.bodyEncrypted, equals(bodyEnc));

        // Should NOT call encrypt (reuses existing)
        verifyNever(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: anyNamed('text'),
          ),
        );
      });
    });

    group('Failure Cases', () {
      test('verification fails when title decrypts to different value', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Original Title',
          body: 'Original Body',
        );

        final titleEnc = Uint8List.fromList('encrypted'.codeUnits);
        final bodyEnc = Uint8List.fromList('encrypted'.codeUnits);

        // Mock encryption succeeds
        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'Original Title',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'Original Body',
          ),
        ).thenAnswer((_) async => bodyEnc);

        // Mock verification fails (decrypts to WRONG value)
        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: titleEnc,
          ),
        ).thenAnswer((_) async => 'CORRUPTED TITLE');  // ❌ Mismatch!

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isFalse);
        expect(result.failureReason, contains('Encryption verification failed'));
        expect(result.failureReason, contains('title'));
        expect(result.isRetryable, isTrue);
      });

      test('verification fails when body decrypts to different value', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Title',
          body: 'Original Body',
        );

        final titleEnc = Uint8List.fromList('titleenc'.codeUnits);
        final bodyEnc = Uint8List.fromList('bodyenc'.codeUnits);

        // Mock encryption - return different bytes for title and body
        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Title',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Original Body',
          ),
        ).thenAnswer((_) async => bodyEnc);

        // Mock verification: title OK, body FAILS
        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: titleEnc,
          ),
        ).thenAnswer((_) async => 'Title');  // ✅ Correct

        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => 'CORRUPTED BODY');  // ❌ Mismatch!

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isFalse);
        expect(result.failureReason, contains('Encryption verification failed'));
        expect(result.failureReason, contains('body'));
        expect(result.isRetryable, isTrue);
      });

      test('verification fails when locationName decrypts incorrectly', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Meeting',
          body: 'Important',
          locationName: 'Room 123',
        );

        final titleEnc = Uint8List.fromList('tenc'.codeUnits);
        final bodyEnc = Uint8List.fromList('benc'.codeUnits);
        final locationEnc = Uint8List.fromList('lenc'.codeUnits);

        // Mock encryption - each field gets unique bytes
        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Meeting',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Important',
          ),
        ).thenAnswer((_) async => bodyEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            text: 'Room 123',
          ),
        ).thenAnswer((_) async => locationEnc);

        // Mock verification: title and body OK, location FAILS
        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: titleEnc,
          ),
        ).thenAnswer((_) async => 'Meeting');  // ✅ Correct

        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => 'Important');  // ✅ Correct

        when(
          mockCryptoBox.decryptStringForNote(
            userId: testUserId,
            noteId: testNoteId,
            data: locationEnc,
          ),
        ).thenAnswer((_) async => 'Wrong Room');  // ❌ Mismatch!

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isFalse);
        expect(result.failureReason, contains('Encryption verification failed'));
        expect(result.failureReason, contains('location'));
        expect(result.isRetryable, isTrue);
      });

      test('failed verification is queued for retry', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Test',
          body: 'Test',
        );

        final enc = Uint8List.fromList('e'.codeUnits);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: anyNamed('text'),
          ),
        ).thenAnswer((_) async => enc);

        // Mock verification fails
        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: enc,
          ),
        ).thenAnswer((_) async => 'WRONG');

        // ACT
        final result1 = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result1.success, isFalse);
        expect(result1.isRetryable, isTrue);

        // Verify reminder is in retry queue
        final stats = helper.getRetryStats();
        expect(stats['queueSize'], greaterThan(0));
      });
    });

    group('Edge Cases', () {
      test('handles decryption exception during verification', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: 'Test',
          body: 'Test',
        );

        final enc = Uint8List.fromList('e'.codeUnits);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: anyNamed('text'),
          ),
        ).thenAnswer((_) async => enc);

        // Mock decryption throws (verification failure)
        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: enc,
          ),
        ).thenThrow(Exception('Decryption failed'));

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isFalse);
        // Should still be retryable (could be temporary key issue)
        expect(result.isRetryable, isTrue);
      });

      test('verification handles empty strings correctly', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: '',
          body: '',
        );

        final titleEnc = Uint8List(0);
        final bodyEnc = Uint8List(0);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: '',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: titleEnc,
          ),
        ).thenAnswer((_) async => '');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => '');

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isTrue);
      });

      test('verification handles unicode characters correctly', () async {
        // ARRANGE
        final reminder = createMockReminder(
          title: '你好世界',  // Chinese
          body: 'مرحبا بالعالم',  // Arabic
        );

        final titleEnc = Uint8List.fromList('你好世界'.codeUnits);
        final bodyEnc = Uint8List.fromList('مرحبا بالعالم'.codeUnits);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: '你好世界',
          ),
        ).thenAnswer((_) async => titleEnc);

        when(
          mockCryptoBox.encryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            text: 'مرحبا بالعالم',
          ),
        ).thenAnswer((_) async => bodyEnc);

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: titleEnc,
          ),
        ).thenAnswer((_) async => '你好世界');

        when(
          mockCryptoBox.decryptStringForNote(
            userId: anyNamed('userId'),
            noteId: anyNamed('noteId'),
            data: bodyEnc,
          ),
        ).thenAnswer((_) async => 'مرحبا بالعالم');

        // ACT
        final result = await helper.encryptForSync(
          reminder: reminder,
          userId: testUserId,
        );

        // ASSERT
        expect(result.success, isTrue);
      });
    });
  });
}
