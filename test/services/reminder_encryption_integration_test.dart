import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_42_reminder_encryption.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../repository/notes_repository_test.mocks.dart';
import '../utils/uuid_test_helper.dart';

/// Integration tests for Migration v42: Reminder Encryption
///
/// Tests the complete encryption/decryption flow for reminders including:
/// - Upload encryption (local -> remote)
/// - Download decryption (remote -> local)
/// - Backward compatibility (plaintext + encrypted dual-write)
/// - Lazy encryption (gradual migration of existing data)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDb db;
  late UnifiedSyncService service;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCrypto;
  late MockSupabaseNoteApi mockNoteApi;

  setUpAll(() async {
    db = AppDb.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockCrypto = MockCryptoBox();
    mockNoteApi = MockSupabaseNoteApi();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('user-123');

    // Stub encrypt to return predictable encrypted data
    when(
      mockCrypto.encryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        text: anyNamed('text'),
      ),
    ).thenAnswer((invocation) async {
      final text = invocation.namedArguments[Symbol('text')] as String;
      // Simple encryption: reverse the string and convert to bytes
      final encrypted = text.split('').reversed.join();
      return Uint8List.fromList(encrypted.codeUnits);
    });

    // Stub decrypt to reverse the encryption
    when(
      mockCrypto.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[Symbol('data')] as Uint8List;
      // Simple decryption: convert bytes to string and reverse
      final encrypted = String.fromCharCodes(data);
      return encrypted.split('').reversed.join();
    });

    final secureApi = SecureApiWrapper.testing(
      api: mockNoteApi,
      userIdResolver: () => 'user-123',
    );

    service = UnifiedSyncService();
    await service.initialize(
      database: db,
      client: mockSupabase,
      migrationConfig: MigrationConfig.developmentConfig(),
      cryptoBox: mockCrypto,
      secureApi: secureApi,
    );
  });

  setUp(() async {
    await db.customStatement('DELETE FROM note_reminders;');
    await db.customStatement('DELETE FROM local_notes;');
    reset(mockNoteApi);
    when(
      mockNoteApi.getReminders(),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(mockNoteApi.upsertReminder(any)).thenAnswer((_) async {});
    when(mockNoteApi.deleteReminder(any)).thenAnswer((_) async {});
  });

  tearDownAll(() async {
    await db.close();
  });

  Future<void> seedNote({required String noteId}) async {
    final now = DateTime.utc(2025, 11, 18);
    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: noteId,
            titleEncrypted: const Value('encrypted-title'),
            bodyEncrypted: const Value('encrypted-body'),
            createdAt: now,
            updatedAt: now,
            deleted: const Value(false),
            userId: const Value('user-123'),
            isPinned: const Value(false),
            version: const Value(1),
          ),
        );
  }

  group('Migration v42: Encrypted reminder sync', () {
    test('Upload: encrypts reminder before sending to remote', () async {
      // Arrange
      await seedNote(noteId: 'note-1');

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Doctor appointment'),
          body: const Value('Annual checkup'),
          locationName: const Value('Downtown clinic'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      // Act
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);
      expect(result.syncedReminders, 1);

      // Verify upsertReminder was called with encrypted data
      final captured = verify(mockNoteApi.upsertReminder(captureAny)).captured;
      expect(captured, hasLength(1));

      final uploadedReminder = captured.first as Map<String, dynamic>;
      expect(uploadedReminder['id'], reminderId);
      expect(uploadedReminder['user_id'], 'user-123');
      expect(uploadedReminder['note_id'], 'note-1');

      // MIGRATION v42: Verify BOTH plaintext AND encrypted fields present
      expect(uploadedReminder['title'], 'Doctor appointment');
      expect(uploadedReminder['body'], 'Annual checkup');
      expect(uploadedReminder['location_name'], 'Downtown clinic');

      expect(uploadedReminder['title_enc'], isNotNull);
      expect(uploadedReminder['body_enc'], isNotNull);
      expect(uploadedReminder['location_name_enc'], isNotNull);
      expect(uploadedReminder['encryption_version'], 1);

      // Verify encrypted data is different from plaintext
      final titleEnc = uploadedReminder['title_enc'] as Uint8List;
      expect(String.fromCharCodes(titleEnc), isNot('Doctor appointment'));
    });

    test('Download: decrypts encrypted reminder from remote', () async {
      // Arrange
      await seedNote(noteId: 'note-2');

      // Simulate encrypted reminder from remote
      final encryptedTitle = Uint8List.fromList('eltiT detpyrcnE'.codeUnits);
      final encryptedBody = Uint8List.fromList('ydoB detpyrcnE'.codeUnits);
      final encryptedLocation = Uint8List.fromList(
        'noitacoL detpyrcnE'.codeUnits,
      );

      final remoteReminder = {
        'id': UuidTestHelper.testReminder1,
        'note_id': 'note-2',
        'user_id': 'user-123',
        'title': 'PLAINTEXT_FALLBACK', // Old plaintext (ignored)
        'body': 'PLAINTEXT_BODY_FALLBACK',
        'location_name': 'PLAINTEXT_LOCATION_FALLBACK',
        'title_enc': encryptedTitle,
        'body_enc': encryptedBody,
        'location_name_enc': encryptedLocation,
        'encryption_version': 1,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 20, 15).toIso8601String(),
        'is_active': true,
        'recurrence_pattern': 'none',
        'recurrence_interval': 1,
        'latitude': null,
        'longitude': null,
        'radius': null,
        'snoozed_until': null,
        'snooze_count': 0,
        'trigger_count': 0,
        'last_triggered': null,
        'notification_title': null,
        'notification_body': null,
        'notification_image': null,
        'time_zone': 'UTC',
        'created_at': DateTime.utc(2025, 11, 18).toIso8601String(),
        'updated_at': DateTime.utc(2025, 11, 18).toIso8601String(),
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);
      expect(result.syncedReminders, 1);

      // Verify reminder was decrypted and stored locally
      final stored = await db.getReminderById(
        UuidTestHelper.testReminder1,
        'user-123',
      );
      expect(stored, isNotNull);

      // MIGRATION v42: Verify decrypted plaintext values
      expect(stored!.title, 'Encrypted Title'); // Reversed back
      expect(stored.body, 'Encrypted Body');
      expect(stored.locationName, 'Encrypted Location');

      // Verify encrypted data is also stored (dual storage)
      expect(stored.titleEncrypted, isNotNull);
      expect(stored.bodyEncrypted, isNotNull);
      expect(stored.locationNameEncrypted, isNotNull);
      expect(stored.encryptionVersion, 1);
    });

    test('Backward compatibility: handles plaintext-only reminders', () async {
      // Arrange
      await seedNote(noteId: 'note-3');

      // Simulate old plaintext-only reminder (pre-v42)
      final remoteReminder = {
        'id': UuidTestHelper.testReminder2,
        'note_id': 'note-3',
        'user_id': 'user-123',
        'title': 'Legacy plaintext reminder',
        'body': 'Created before v42',
        'location_name': null,
        'title_enc': null, // No encrypted data
        'body_enc': null,
        'location_name_enc': null,
        'encryption_version': null,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 21, 10).toIso8601String(),
        'is_active': true,
        'recurrence_pattern': 'none',
        'recurrence_interval': 1,
        'latitude': null,
        'longitude': null,
        'radius': null,
        'snoozed_until': null,
        'snooze_count': 0,
        'trigger_count': 0,
        'last_triggered': null,
        'notification_title': null,
        'notification_body': null,
        'notification_image': null,
        'time_zone': 'UTC',
        'created_at': DateTime.utc(2025, 11, 18).toIso8601String(),
        'updated_at': DateTime.utc(2025, 11, 18).toIso8601String(),
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);
      expect(result.syncedReminders, 1);

      // Verify plaintext reminder was stored correctly
      final stored = await db.getReminderById(
        UuidTestHelper.testReminder2,
        'user-123',
      );
      expect(stored, isNotNull);
      expect(stored!.title, 'Legacy plaintext reminder');
      expect(stored.body, 'Created before v42');
      expect(stored.encryptionVersion, isNull); // No encryption
    });

    test('Sync round-trip: upload encrypted, download decrypted', () async {
      // Arrange
      await seedNote(noteId: 'note-4');

      // Create local reminder with valid UUID
      final testId = UuidTestHelper.deterministicUuid('round-trip-test');
      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: Value(testId),
          noteId: 'note-4',
          userId: 'user-123',
          type: ReminderType.location,
          title: const Value('Grocery shopping'),
          body: const Value('Buy milk and bread'),
          locationName: const Value('Supermarket'),
          latitude: const Value(37.7749),
          longitude: const Value(-122.4194),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      // Capture what gets uploaded
      Map<String, dynamic>? uploadedData;
      when(mockNoteApi.upsertReminder(any)).thenAnswer((invocation) async {
        uploadedData =
            invocation.positionalArguments[0] as Map<String, dynamic>;
      });

      // Act - Upload
      final uploadResult = await service.syncRemindersForTest();
      expect(uploadResult.success, isTrue);
      expect(uploadedData, isNotNull);

      // Simulate remote returning the same data on download
      when(mockNoteApi.getReminders()).thenAnswer((_) async => [uploadedData!]);

      // Delete local reminder to force download
      await db.deleteReminderById(reminderId, 'user-123');
      final deleted = await db.getReminderById(reminderId, 'user-123');
      expect(deleted, isNull);

      // Act - Download
      final downloadResult = await service.syncRemindersForTest();
      if (!downloadResult.success) {
        print('Download failed with errors: ${downloadResult.errors}');
      }
      expect(downloadResult.success, isTrue);

      // Assert - Verify round-trip consistency
      final restored = await db.getReminderById(reminderId, 'user-123');
      expect(restored, isNotNull);
      expect(restored!.title, 'Grocery shopping');
      expect(restored.body, 'Buy milk and bread');
      expect(restored.locationName, 'Supermarket');
      expect(restored.latitude, 37.7749);
      expect(restored.longitude, -122.4194);
      expect(restored.encryptionVersion, 1);
    });

    test('Migration progress: tracks encryption adoption', () async {
      // Arrange
      await seedNote(noteId: 'note-5');

      // Create 3 reminders: 1 encrypted, 2 plaintext
      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('encrypted-1'),
          noteId: 'note-5',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Encrypted reminder'),
          titleEncrypted: Value(Uint8List.fromList([1, 2, 3])),
          bodyEncrypted: Value(Uint8List.fromList([4, 5, 6])),
          encryptionVersion: const Value(1),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('plaintext-1'),
          noteId: 'note-5',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Plaintext reminder 1'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('plaintext-2'),
          noteId: 'note-5',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Plaintext reminder 2'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      // Act - Get migration progress
      final progress = await Migration42ReminderEncryption.getProgress(db);

      // Assert
      expect(progress['total'], 3);
      expect(progress['encrypted'], 1);
      expect(progress['plaintext'], 2);

      // Calculate adoption percentage
      final adoptionRate = (progress['encrypted']! / progress['total']! * 100)
          .round();
      expect(adoptionRate, 33); // 33% encrypted
    });
  });
}
