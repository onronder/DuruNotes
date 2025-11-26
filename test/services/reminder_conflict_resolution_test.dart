import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../repository/notes_repository_test.mocks.dart';
import '../utils/uuid_test_helper.dart';

/// Tests for CRITICAL #5: Conflict resolution preserves encrypted fields
///
/// Verifies that when reminder conflicts occur (timestamps differ),
/// the encrypted fields are preserved from the newer version and not lost.
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

    // Stub encrypt/decrypt
    when(
      mockCrypto.encryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        text: anyNamed('text'),
      ),
    ).thenAnswer((invocation) async {
      final text = invocation.namedArguments[Symbol('text')] as String;
      return Uint8List.fromList(text.split('').reversed.join().codeUnits);
    });

    when(
      mockCrypto.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[Symbol('data')] as Uint8List;
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
    when(mockNoteApi.getReminders()).thenAnswer((_) async => []);
    when(mockNoteApi.upsertReminder(any)).thenAnswer((_) async {});
  });

  tearDownAll(() async {
    await db.close();
  });

  Future<void> seedNote({required String noteId}) async {
    final now = DateTime.utc(2025, 11, 19);
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

  group('CRITICAL #5: Conflict Resolution - Encrypted Field Preservation', () {
    test('preserves local encryption when local is newer', () async {
      // Arrange
      await seedNote(noteId: 'note-1');

      final localTitleEnc = Uint8List.fromList(
        'local-encrypted-title'.codeUnits,
      );
      final localBodyEnc = Uint8List.fromList('local-encrypted-body'.codeUnits);
      final localLocationEnc = Uint8List.fromList(
        'local-encrypted-location'.codeUnits,
      );

      // Create local reminder with encryption (newer)
      final reminderId = UuidTestHelper.deterministicUuid('conflict-test-1');
      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: Value(reminderId),
          noteId: 'note-1',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Local Title'),
          body: const Value('Local Body'),
          locationName: const Value('Local Location'),
          titleEncrypted: Value(localTitleEnc),
          bodyEncrypted: Value(localBodyEnc),
          locationNameEncrypted: Value(localLocationEnc),
          encryptionVersion: const Value(1),
          createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
          updatedAt: Value(DateTime.utc(2025, 11, 19, 12, 0)), // Newer
        ),
      );

      // Remote reminder with different encryption (older)
      final remoteTitleEnc = Uint8List.fromList(
        'remote-encrypted-title'.codeUnits,
      );
      final remoteBodyEnc = Uint8List.fromList(
        'remote-encrypted-body'.codeUnits,
      );

      final remoteReminder = {
        'id': reminderId,
        'note_id': 'note-1',
        'user_id': 'user-123',
        'title': 'Remote Title',
        'body': 'Remote Body',
        'location_name': 'Remote Location',
        'title_enc': remoteTitleEnc,
        'body_enc': remoteBodyEnc,
        'location_name_enc': null,
        'encryption_version': 1,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 20, 10).toIso8601String(),
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
        'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
        'updated_at': DateTime.utc(
          2025,
          11,
          19,
          11,
          0,
        ).toIso8601String(), // Older
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act - Trigger sync (conflict should be detected)
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);

      final stored = await db.getReminderById(reminderId, 'user-123');
      expect(stored, isNotNull);

      // CRITICAL #5: Verify LOCAL encryption preserved (local is newer)
      expect(stored!.titleEncrypted, equals(localTitleEnc));
      expect(stored.bodyEncrypted, equals(localBodyEnc));
      expect(stored.locationNameEncrypted, equals(localLocationEnc));
      expect(stored.encryptionVersion, 1);

      // Verify encryption is NOT from remote
      expect(stored.titleEncrypted, isNot(equals(remoteTitleEnc)));
      expect(stored.bodyEncrypted, isNot(equals(remoteBodyEnc)));
    });

    test('preserves remote encryption when remote is newer', () async {
      // Arrange
      await seedNote(noteId: 'note-2');

      final localTitleEnc = Uint8List.fromList(
        'local-encrypted-title'.codeUnits,
      );
      final localBodyEnc = Uint8List.fromList('local-encrypted-body'.codeUnits);

      // Create local reminder with encryption (older)
      final reminderId = UuidTestHelper.deterministicUuid('conflict-test-2');
      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: Value(reminderId),
          noteId: 'note-2',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Local Title'),
          body: const Value('Local Body'),
          titleEncrypted: Value(localTitleEnc),
          bodyEncrypted: Value(localBodyEnc),
          encryptionVersion: const Value(1),
          createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
          updatedAt: Value(DateTime.utc(2025, 11, 19, 11, 0)), // Older
        ),
      );

      // Remote reminder with different encryption (newer)
      final remoteTitleEnc = Uint8List.fromList(
        'remote-encrypted-title'.codeUnits,
      );
      final remoteBodyEnc = Uint8List.fromList(
        'remote-encrypted-body'.codeUnits,
      );
      final remoteLocationEnc = Uint8List.fromList(
        'remote-encrypted-location'.codeUnits,
      );

      final remoteReminder = {
        'id': reminderId,
        'note_id': 'note-2',
        'user_id': 'user-123',
        'title': 'Remote Title',
        'body': 'Remote Body',
        'location_name': 'Remote Location',
        'title_enc': remoteTitleEnc,
        'body_enc': remoteBodyEnc,
        'location_name_enc': remoteLocationEnc,
        'encryption_version': 1,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 20, 10).toIso8601String(),
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
        'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
        'updated_at': DateTime.utc(
          2025,
          11,
          19,
          12,
          0,
        ).toIso8601String(), // Newer
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act - Trigger sync (conflict should be detected)
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);

      final stored = await db.getReminderById(reminderId, 'user-123');
      expect(stored, isNotNull);

      // CRITICAL #5: Verify REMOTE encryption preserved (remote is newer)
      expect(stored!.titleEncrypted, equals(remoteTitleEnc));
      expect(stored.bodyEncrypted, equals(remoteBodyEnc));
      expect(stored.locationNameEncrypted, equals(remoteLocationEnc));
      expect(stored.encryptionVersion, 1);

      // Verify encryption is NOT from local
      expect(stored.titleEncrypted, isNot(equals(localTitleEnc)));
      expect(stored.bodyEncrypted, isNot(equals(localBodyEnc)));
    });

    test(
      'preserves local encryption when remote is missing encryption',
      () async {
        // Arrange
        await seedNote(noteId: 'note-3');

        final localTitleEnc = Uint8List.fromList(
          'local-encrypted-title'.codeUnits,
        );
        final localBodyEnc = Uint8List.fromList(
          'local-encrypted-body'.codeUnits,
        );

        // Create local reminder with encryption
        final reminderId = UuidTestHelper.deterministicUuid('conflict-test-3');
        await db.createReminder(
          NoteRemindersCompanion.insert(
            id: Value(reminderId),
            noteId: 'note-3',
            userId: 'user-123',
            type: ReminderType.time,
            title: const Value('Encrypted Title'),
            body: const Value('Encrypted Body'),
            titleEncrypted: Value(localTitleEnc),
            bodyEncrypted: Value(localBodyEnc),
            encryptionVersion: const Value(1),
            createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
            updatedAt: Value(DateTime.utc(2025, 11, 19, 11, 0)),
          ),
        );

        // Remote reminder WITHOUT encryption (pre-v42 or encryption failed)
        final remoteReminder = {
          'id': reminderId,
          'note_id': 'note-3',
          'user_id': 'user-123',
          'title': 'Plaintext Title',
          'body': 'Plaintext Body',
          'location_name': null,
          'title_enc': null, // No encryption
          'body_enc': null,
          'location_name_enc': null,
          'encryption_version': null,
          'type': 'time',
          'remind_at': DateTime.utc(2025, 11, 20, 10).toIso8601String(),
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
          'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
          'updated_at': DateTime.utc(
            2025,
            11,
            19,
            12,
            0,
          ).toIso8601String(), // Newer but unencrypted
        };

        when(
          mockNoteApi.getReminders(),
        ).thenAnswer((_) async => [remoteReminder]);

        // Act
        final result = await service.syncRemindersForTest();

        // Assert
        expect(result.success, isTrue);

        final stored = await db.getReminderById(reminderId, 'user-123');
        expect(stored, isNotNull);

        // CRITICAL #5: Verify local encryption PRESERVED despite remote being newer
        // This prevents encryption loss when syncing with unencrypted devices
        expect(stored!.titleEncrypted, equals(localTitleEnc));
        expect(stored.bodyEncrypted, equals(localBodyEnc));
        expect(stored.encryptionVersion, 1);
      },
    );

    test('uses remote encryption when local is missing encryption', () async {
      // Arrange
      await seedNote(noteId: 'note-4');

      // Create local reminder WITHOUT encryption
      final reminderId = UuidTestHelper.deterministicUuid('conflict-test-4');
      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: Value(reminderId),
          noteId: 'note-4',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Plaintext Title'),
          body: const Value('Plaintext Body'),
          createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
          updatedAt: Value(
            DateTime.utc(2025, 11, 19, 12, 0),
          ), // Newer but unencrypted
        ),
      );

      // Remote reminder WITH encryption (older but encrypted)
      final remoteTitleEnc = Uint8List.fromList(
        'remote-encrypted-title'.codeUnits,
      );
      final remoteBodyEnc = Uint8List.fromList(
        'remote-encrypted-body'.codeUnits,
      );

      final remoteReminder = {
        'id': reminderId,
        'note_id': 'note-4',
        'user_id': 'user-123',
        'title': 'Encrypted Title',
        'body': 'Encrypted Body',
        'location_name': null,
        'title_enc': remoteTitleEnc,
        'body_enc': remoteBodyEnc,
        'location_name_enc': null,
        'encryption_version': 1,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 20, 10).toIso8601String(),
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
        'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
        'updated_at': DateTime.utc(
          2025,
          11,
          19,
          11,
          0,
        ).toIso8601String(), // Older but encrypted
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);

      final stored = await db.getReminderById(reminderId, 'user-123');
      expect(stored, isNotNull);

      // CRITICAL #5: Verify remote encryption adopted (upgrade local to encrypted)
      expect(stored!.titleEncrypted, equals(remoteTitleEnc));
      expect(stored.bodyEncrypted, equals(remoteBodyEnc));
      expect(stored.encryptionVersion, 1);
    });

    test('handles neither version encrypted (pre-v42 reminder)', () async {
      // Arrange
      await seedNote(noteId: 'note-5');

      // Create local reminder without encryption
      final reminderId = UuidTestHelper.deterministicUuid('conflict-test-5');
      await db.createReminder(
        NoteRemindersCompanion.insert(
          id: Value(reminderId),
          noteId: 'note-5',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Old Plaintext Title'),
          body: const Value('Old Plaintext Body'),
          createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
          updatedAt: Value(DateTime.utc(2025, 11, 19, 11, 0)),
        ),
      );

      // Remote reminder also without encryption
      final remoteReminder = {
        'id': reminderId,
        'note_id': 'note-5',
        'user_id': 'user-123',
        'title': 'New Plaintext Title',
        'body': 'New Plaintext Body',
        'location_name': null,
        'title_enc': null,
        'body_enc': null,
        'location_name_enc': null,
        'encryption_version': null,
        'type': 'time',
        'remind_at': DateTime.utc(2025, 11, 20, 10).toIso8601String(),
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
        'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
        'updated_at': DateTime.utc(
          2025,
          11,
          19,
          12,
          0,
        ).toIso8601String(), // Newer
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      // Act
      final result = await service.syncRemindersForTest();

      // Assert
      expect(result.success, isTrue);

      final stored = await db.getReminderById(reminderId, 'user-123');
      expect(stored, isNotNull);

      // CRITICAL #5: Verify no encryption (acceptable for pre-v42 reminders)
      expect(stored!.titleEncrypted, isNull);
      expect(stored.bodyEncrypted, isNull);
      expect(stored.encryptionVersion, isNull);

      // Verify newer plaintext values used
      expect(stored.title, 'New Plaintext Title');
      expect(stored.body, 'New Plaintext Body');
    });

    test(
      'conflict resolution still applies other strategies with encryption',
      () async {
        // Verify that encryption preservation doesn't interfere with other conflict strategies
        await seedNote(noteId: 'note-6');

        final localTitleEnc = Uint8List.fromList('local-title-enc'.codeUnits);
        final localBodyEnc = Uint8List.fromList('local-body-enc'.codeUnits);

        // Create local reminder: encrypted, snoozed, triggered
        final reminderId = UuidTestHelper.deterministicUuid('conflict-test-6');
        await db.createReminder(
          NoteRemindersCompanion.insert(
            id: Value(reminderId),
            noteId: 'note-6',
            userId: 'user-123',
            type: ReminderType.time,
            title: const Value('Local'),
            body: const Value('Local'),
            titleEncrypted: Value(localTitleEnc),
            bodyEncrypted: Value(localBodyEnc),
            encryptionVersion: const Value(1),
            isActive: const Value(true),
            snoozedUntil: Value(DateTime.utc(2025, 11, 20, 10)),
            snoozeCount: const Value(2),
            triggerCount: const Value(3),
            createdAt: Value(DateTime.utc(2025, 11, 19, 10, 0)),
            updatedAt: Value(DateTime.utc(2025, 11, 19, 11, 0)), // Older
          ),
        );

        final remoteTitleEnc = Uint8List.fromList('remote-title-enc'.codeUnits);
        final remoteBodyEnc = Uint8List.fromList('remote-body-enc'.codeUnits);

        // Remote: newer, inactive, no snooze, different trigger count
        final remoteReminder = {
          'id': reminderId,
          'note_id': 'note-6',
          'user_id': 'user-123',
          'title': 'Remote',
          'body': 'Remote',
          'location_name': null,
          'title_enc': remoteTitleEnc,
          'body_enc': remoteBodyEnc,
          'location_name_enc': null,
          'encryption_version': 1,
          'type': 'time',
          'remind_at': DateTime.utc(2025, 11, 20, 15).toIso8601String(),
          'is_active': false, // Deactivated
          'recurrence_pattern': 'none',
          'recurrence_interval': 1,
          'latitude': null,
          'longitude': null,
          'radius': null,
          'snoozed_until': null, // No snooze
          'snooze_count': 0,
          'trigger_count': 5, // Different trigger count
          'last_triggered': null,
          'notification_title': null,
          'notification_body': null,
          'notification_image': null,
          'time_zone': 'UTC',
          'created_at': DateTime.utc(2025, 11, 19, 10, 0).toIso8601String(),
          'updated_at': DateTime.utc(
            2025,
            11,
            19,
            12,
            0,
          ).toIso8601String(), // Newer
        };

        when(
          mockNoteApi.getReminders(),
        ).thenAnswer((_) async => [remoteReminder]);

        // Act
        final result = await service.syncRemindersForTest();

        // Assert
        expect(result.success, isTrue);

        final stored = await db.getReminderById(reminderId, 'user-123');
        expect(stored, isNotNull);

        // CRITICAL #5: Verify remote encryption (newer)
        expect(stored!.titleEncrypted, equals(remoteTitleEnc));
        expect(stored.bodyEncrypted, equals(remoteBodyEnc));

        // STRATEGY 1: Prefer snoozed_until (local has it, remote doesn't)
        expect(stored.snoozedUntil, isNotNull);
        // Compare timestamps accounting for potential timezone conversion
        final expectedSnooze = DateTime.utc(2025, 11, 20, 10);
        expect(
          stored.snoozedUntil!.toUtc(),
          equals(expectedSnooze),
          reason: 'Snoozed time should match (accounting for timezone)',
        );

        // STRATEGY 2: Merge trigger_count (sum)
        expect(stored.triggerCount, 8); // 3 + 5

        // STRATEGY 3: Prefer is_active=false
        expect(stored.isActive, false);
      },
    );
  });
}
