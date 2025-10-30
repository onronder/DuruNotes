import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';

import '../repository/notes_repository_test.mocks.dart';

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

  Future<void> seedNote({required String noteId, DateTime? timestamp}) async {
    final now = (timestamp ?? DateTime.now()).toUtc();
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
            noteType: Value(NoteKind.note),
            isPinned: const Value(false),
            version: const Value(1),
          ),
        );
  }

  test('syncReminders uploads local reminders missing remotely', () async {
    final createdAt = DateTime.utc(2025, 1, 1, 12);
    await seedNote(noteId: 'note-1', timestamp: createdAt);

    final reminderId = await db.createReminder(
      NoteRemindersCompanion.insert(
        noteId: 'note-1',
        userId: 'user-123',
        type: ReminderType.time,
        title: const Value('Local Reminder'),
        body: const Value('Do the thing'),
        createdAt: Value(createdAt),
        isActive: const Value(true),
        recurrencePattern: const Value(RecurrencePattern.none),
        recurrenceInterval: const Value(1),
        snoozeCount: const Value(0),
        triggerCount: const Value(0),
      ),
    );

    final result = await service.syncRemindersForTest();

    expect(result.success, isTrue);
    expect(result.syncedReminders, 1);
    verify(
      mockNoteApi.upsertReminder(argThat(isA<Map<String, dynamic>>())),
    ).called(1);
    verify(mockNoteApi.getReminders()).called(1);

    final stored = await db.getReminderById(reminderId, 'user-123');
    expect(stored, isNotNull);
    expect(stored!.title, 'Local Reminder');
  });

  test(
    'syncReminders downloads remote reminders into local database',
    () async {
      final createdAt = DateTime.utc(2025, 1, 2, 8);
      await seedNote(noteId: 'note-remote', timestamp: createdAt);

      final remoteReminder = {
        'id': 99,
        'note_id': 'note-remote',
        'user_id': 'user-123',
        'title': 'Remote Reminder',
        'body': 'Imported from cloud',
        'type': 'time',
        'remind_at': createdAt.add(const Duration(hours: 3)).toIso8601String(),
        'is_active': true,
        'recurrence_pattern': 'none',
        'recurrence_interval': 1,
        'recurrence_end_date': null,
        'latitude': null,
        'longitude': null,
        'radius': null,
        'location_name': null,
        'snoozed_until': null,
        'snooze_count': 0,
        'trigger_count': 0,
        'last_triggered': null,
        'notification_title': null,
        'notification_body': null,
        'notification_image': null,
        'time_zone': 'UTC',
        'created_at': createdAt.toIso8601String(),
        'updated_at': createdAt.toIso8601String(),
      };

      when(
        mockNoteApi.getReminders(),
      ).thenAnswer((_) async => [remoteReminder]);

      final result = await service.syncRemindersForTest();

      expect(result.success, isTrue);
      expect(result.syncedReminders, 1);
      verify(mockNoteApi.getReminders()).called(1);
      verifyNever(mockNoteApi.upsertReminder(any));

      final stored = await db.getReminderById(99, 'user-123');
      expect(stored, isNotNull);
      expect(stored!.title, 'Remote Reminder');
      expect(stored.body, 'Imported from cloud');
      expect(stored.noteId, 'note-remote');
    },
  );
}
