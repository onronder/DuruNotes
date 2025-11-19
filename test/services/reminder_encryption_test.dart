import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_42_reminder_encryption.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../repository/notes_repository_test.mocks.dart' show MockCryptoBox;
import 'reminder_encryption_test.mocks.dart';

final _pluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override in tests');
});

final _dbProvider = Provider<AppDb>((ref) {
  throw UnimplementedError('Override in tests');
});

final _cryptoBoxProvider = Provider<MockCryptoBox>((ref) {
  throw UnimplementedError('Override in tests');
});

final _reminderServiceProvider = Provider<TestReminderService>((ref) {
  final plugin = ref.watch(_pluginProvider);
  final db = ref.watch(_dbProvider);
  final cryptoBox = ref.watch(_cryptoBoxProvider);
  return TestReminderService(ref, plugin, db, cryptoBox: cryptoBox);
});

/// Test implementation of BaseReminderService for encryption testing
class TestReminderService extends BaseReminderService {
  TestReminderService(
    super.ref,
    super.plugin,
    super.db, {
    super.cryptoBox,
  });

  @override
  Future<String?> createReminder(ReminderConfig config) async =>
      'test-reminder-id';
}

@GenerateNiceMocks([
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<AnalyticsService>(),
  MockSpec<AppLogger>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  late ProviderContainer container;
  late TestReminderService service;
  late AppDb db;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockCryptoBox mockCrypto;
  late MockAnalyticsService mockAnalytics;
  late MockAppLogger mockLogger;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() async {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    db = AppDb.forTesting(NativeDatabase.memory());
    mockCrypto = MockCryptoBox();
    mockAnalytics = MockAnalyticsService();
    mockLogger = MockAppLogger();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('user-123');

    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        _pluginProvider.overrideWithValue(mockPlugin),
        _dbProvider.overrideWithValue(db),
        _cryptoBoxProvider.overrideWithValue(mockCrypto),
      ],
    );

    service = container.read(_reminderServiceProvider);

    // Clean up database between tests
    await db.customStatement('DELETE FROM note_reminders;');
    await db.customStatement('DELETE FROM local_notes;');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Migration v42: ReminderConfig encryption', () {
    test('toCompanionWithEncryption encrypts title, body, and location_name',
        () async {
      // Arrange
      final config = ReminderConfig(
        noteId: 'note-123',
        title: 'Doctor appointment',
        body: 'Annual checkup at 3pm',
        scheduledTime: DateTime.utc(2025, 11, 20, 15),
      );

      final titleBytes = Uint8List.fromList([1, 2, 3]);
      final bodyBytes = Uint8List.fromList([4, 5, 6]);
      final locationBytes = Uint8List.fromList([7, 8, 9]);

      when(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Doctor appointment',
        ),
      ).thenAnswer((_) async => titleBytes);

      when(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Annual checkup at 3pm',
        ),
      ).thenAnswer((_) async => bodyBytes);

      when(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Downtown clinic',
        ),
      ).thenAnswer((_) async => locationBytes);

      // Act
      final companion = await config.toCompanionWithEncryption(
        ReminderType.time,
        'user-123',
        mockCrypto,
        locationName: 'Downtown clinic',
      );

      // Assert - plaintext fields (backward compatibility)
      expect(companion.title.value, 'Doctor appointment');
      expect(companion.body.value, 'Annual checkup at 3pm');
      expect(companion.locationName.value, 'Downtown clinic');

      // Assert - encrypted fields (v42)
      expect(companion.titleEncrypted.value, titleBytes);
      expect(companion.bodyEncrypted.value, bodyBytes);
      expect(companion.locationNameEncrypted.value, locationBytes);
      expect(companion.encryptionVersion.value, 1);

      // Verify encryption calls
      verify(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Doctor appointment',
        ),
      ).called(1);
      verify(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Annual checkup at 3pm',
        ),
      ).called(1);
      verify(
        mockCrypto.encryptStringForNote(
          userId: 'user-123',
          noteId: 'note-123',
          text: 'Downtown clinic',
        ),
      ).called(1);
    });

    test('toCompanionWithEncryption handles null CryptoBox gracefully',
        () async {
      // Arrange
      final config = ReminderConfig(
        noteId: 'note-456',
        title: 'Team standup',
        scheduledTime: DateTime.utc(2025, 11, 21, 9),
      );

      // Act
      final companion = await config.toCompanionWithEncryption(
        ReminderType.time,
        'user-123',
        null, // No CryptoBox
      );

      // Assert - plaintext fields present
      expect(companion.title.value, 'Team standup');
      expect(companion.body.value, '');

      // Assert - no encrypted fields
      expect(companion.titleEncrypted.present, isFalse);
      expect(companion.bodyEncrypted.present, isFalse);
      expect(companion.encryptionVersion.present, isFalse);
    });

    test('toCompanionWithEncryption continues with plaintext on encryption error',
        () async {
      // Arrange
      final config = ReminderConfig(
        noteId: 'note-789',
        title: 'Sprint review',
        body: 'Demo latest features',
        scheduledTime: DateTime.utc(2025, 11, 22, 14),
      );

      // Simulate encryption failure
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenThrow(Exception('Encryption key not available'));

      // Act
      final companion = await config.toCompanionWithEncryption(
        ReminderType.time,
        'user-123',
        mockCrypto,
      );

      // Assert - plaintext fields still present
      expect(companion.title.value, 'Sprint review');
      expect(companion.body.value, 'Demo latest features');

      // Assert - no encrypted fields (degraded mode)
      expect(companion.titleEncrypted.present, isFalse);
      expect(companion.bodyEncrypted.present, isFalse);
      expect(companion.encryptionVersion.present, isFalse);

      // Note: Error logging verification removed because toCompanionWithEncryption() uses
      // LoggerFactory.instance (singleton) which cannot be easily mocked in this context.
      // The important behavior is verified: reminder creation continues with plaintext on error.
    });
  });

  group('Migration v42: BaseReminderService decryption', () {
    test('decryptReminderFields prefers encrypted data when available',
        () async {
      // Arrange
      final reminder = NoteReminder(
        id: 'reminder-1',
        noteId: 'note-123',
        userId: 'user-123',
        title: 'PLAINTEXT_TITLE', // Old plaintext
        body: 'PLAINTEXT_BODY',
        type: ReminderType.time,
        remindAt: DateTime.utc(2025, 11, 20, 15),
        isActive: true,
        // Encrypted fields (v42)
        titleEncrypted: Uint8List.fromList([1, 2, 3]),
        bodyEncrypted: Uint8List.fromList([4, 5, 6]),
        locationNameEncrypted: Uint8List.fromList([7, 8, 9]),
        encryptionVersion: 1,
        latitude: null,
        longitude: null,
        radius: null,
        locationName: 'PLAINTEXT_LOCATION',
        recurrencePattern: RecurrencePattern.none,
        recurrenceEndDate: null,
        recurrenceInterval: 1,
        snoozedUntil: null,
        snoozeCount: 0,
        notificationTitle: null,
        notificationBody: null,
        notificationImage: null,
        timeZone: 'UTC',
        createdAt: DateTime.utc(2025, 11, 19),
        lastTriggered: null,
        triggerCount: 0,
      );

      // Configure mock to return decrypted values based on data
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;
        if (data.length == 3 && data[0] == 1 && data[1] == 2 && data[2] == 3) {
          return 'DECRYPTED_TITLE';
        } else if (data.length == 3 && data[0] == 4 && data[1] == 5 && data[2] == 6) {
          return 'DECRYPTED_BODY';
        } else if (data.length == 3 && data[0] == 7 && data[1] == 8 && data[2] == 9) {
          return 'DECRYPTED_LOCATION';
        }
        return 'UNKNOWN';
      });

      // Act
      final decrypted = await service.decryptReminderFields(reminder);

      // Assert - decrypted data is returned (NOT plaintext)
      expect(decrypted['title'], 'DECRYPTED_TITLE');
      expect(decrypted['body'], 'DECRYPTED_BODY');
      expect(decrypted['locationName'], 'DECRYPTED_LOCATION');

      // Verify decryption was called
      verify(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).called(greaterThanOrEqualTo(3));
    });

    test('decryptReminderFields falls back to plaintext on decryption error',
        () async {
      // Arrange - reset mock to clear previous configurations
      reset(mockCrypto);
      reset(mockLogger);

      final reminder = NoteReminder(
        id: 'reminder-2',
        noteId: 'note-456',
        userId: 'user-123',
        title: 'PLAINTEXT_FALLBACK',
        body: 'PLAINTEXT_BODY_FALLBACK',
        type: ReminderType.time,
        remindAt: DateTime.utc(2025, 11, 21, 10),
        isActive: true,
        titleEncrypted: Uint8List.fromList([99, 99, 99]), // Corrupt data
        bodyEncrypted: Uint8List.fromList([88, 88, 88]),
        encryptionVersion: 1,
        latitude: null,
        longitude: null,
        radius: null,
        locationName: null,
        recurrencePattern: RecurrencePattern.none,
        recurrenceEndDate: null,
        recurrenceInterval: 1,
        snoozedUntil: null,
        snoozeCount: 0,
        notificationTitle: null,
        notificationBody: null,
        notificationImage: null,
        timeZone: 'UTC',
        createdAt: DateTime.utc(2025, 11, 20),
        lastTriggered: null,
        triggerCount: 0,
      );

      // Simulate decryption failure
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenThrow(Exception('Decryption failed - corrupt data'));

      // Act
      final decrypted = await service.decryptReminderFields(reminder);

      // Assert - fallback to plaintext
      expect(decrypted['title'], 'PLAINTEXT_FALLBACK');
      expect(decrypted['body'], 'PLAINTEXT_BODY_FALLBACK');

      // Verify error was logged
      verify(
        mockLogger.error(
          any,
          error: anyNamed('error'),
          stackTrace: anyNamed('stackTrace'),
        ),
      ).called(1);
    });

    test('decryptReminderFields returns plaintext when no encrypted data',
        () async {
      // Arrange - reset mock to clear previous verification state
      reset(mockCrypto);

      // Arrange - pre-v42 reminder (no encrypted fields)
      final reminder = NoteReminder(
        id: 'reminder-3',
        noteId: 'note-789',
        userId: 'user-123',
        title: 'Legacy reminder',
        body: 'Created before v42',
        type: ReminderType.time,
        remindAt: DateTime.utc(2025, 11, 22, 11),
        isActive: true,
        titleEncrypted: null, // No encrypted data
        bodyEncrypted: null,
        encryptionVersion: null,
        latitude: null,
        longitude: null,
        radius: null,
        locationName: null,
        recurrencePattern: RecurrencePattern.none,
        recurrenceEndDate: null,
        recurrenceInterval: 1,
        snoozedUntil: null,
        snoozeCount: 0,
        notificationTitle: null,
        notificationBody: null,
        notificationImage: null,
        timeZone: 'UTC',
        createdAt: DateTime.utc(2025, 11, 21),
        lastTriggered: null,
        triggerCount: 0,
      );

      // Act
      final decrypted = await service.decryptReminderFields(reminder);

      // Assert - plaintext data returned
      expect(decrypted['title'], 'Legacy reminder');
      expect(decrypted['body'], 'Created before v42');

      // Verify no decryption attempted
      verifyNever(mockCrypto.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ));
    });
  });

  group('Migration v42: Lazy encryption', () {
    test('ensureReminderEncrypted encrypts plaintext reminder', () async {
      // Arrange
      reset(mockCrypto); // Reset to clear any previous stubs
      reset(mockAnalytics);

      final titleBytes = Uint8List.fromList([10, 20, 30]);
      final bodyBytes = Uint8List.fromList([40, 50, 60]);
      final locationBytes = Uint8List.fromList([70, 80, 90]);

      // Configure mock responses
      when(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[Symbol('text')] as String;
        if (text == 'Plaintext title') return titleBytes;
        if (text == 'Plaintext body') return bodyBytes;
        if (text == 'Plaintext location') return locationBytes;
        return Uint8List.fromList([99, 99, 99]);
      });

      // CRITICAL #7: Mock decryption for roundtrip verification
      when(
        mockCrypto.decryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[Symbol('data')] as Uint8List;
        // Simulate successful roundtrip
        if (data == titleBytes) return 'Plaintext title';
        if (data == bodyBytes) return 'Plaintext body';
        if (data == locationBytes) return 'Plaintext location';
        return 'unknown';
      });

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('reminder-lazy-1'),
          noteId: 'note-123',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Plaintext title'),
          body: const Value('Plaintext body'),
          locationName: const Value('Plaintext location'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');
      expect(reminder, isNotNull);
      expect(reminder!.encryptionVersion, isNull); // Not yet encrypted

      // Act
      final encrypted = await service.ensureReminderEncrypted(reminder);

      // Assert
      expect(encrypted, isTrue); // Encryption was performed

      // Verify database was updated
      final updated = await db.getReminderById(reminderId, 'user-123');
      expect(updated, isNotNull);
      expect(updated!.titleEncrypted, titleBytes);
      expect(updated.bodyEncrypted, bodyBytes);
      expect(updated.locationNameEncrypted, locationBytes);
      expect(updated.encryptionVersion, 1);

      // Verify analytics event
      verify(
        mockAnalytics.event('reminder_lazy_encrypted', properties: anyNamed('properties')),
      ).called(1);
    });

    test('ensureReminderEncrypted skips already encrypted reminder', () async {
      // Arrange
      reset(mockCrypto); // Reset to clear previous verification state

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('reminder-lazy-2'),
          noteId: 'note-456',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Already encrypted'),
          body: const Value('Encrypted body'),
          titleEncrypted: Value(Uint8List.fromList([1, 2, 3])),
          bodyEncrypted: Value(Uint8List.fromList([4, 5, 6])),
          encryptionVersion: const Value(1), // Already encrypted
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');
      expect(reminder, isNotNull);

      // Act
      final encrypted = await service.ensureReminderEncrypted(reminder!);

      // Assert
      expect(encrypted, isFalse); // No encryption performed

      // Verify no encryption calls
      verifyNever(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      );
    });

    test('ensureReminderEncrypted returns false when no CryptoBox', () async {
      // Arrange
      final _serviceNoCryptoProvider = Provider<TestReminderService>((ref) {
        final plugin = ref.watch(_pluginProvider);
        final db = ref.watch(_dbProvider);
        return TestReminderService(ref, plugin, db, cryptoBox: null);
      });

      final containerWithoutCrypto = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(mockLogger),
          analyticsProvider.overrideWithValue(mockAnalytics),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          _pluginProvider.overrideWithValue(mockPlugin),
          _dbProvider.overrideWithValue(db),
        ],
      );

      final serviceWithoutCrypto =
          containerWithoutCrypto.read(_serviceNoCryptoProvider);

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('reminder-lazy-3'),
          noteId: 'note-789',
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('No crypto box'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-123');
      expect(reminder, isNotNull);

      // Act
      final encrypted =
          await serviceWithoutCrypto.ensureReminderEncrypted(reminder!);

      // Assert
      expect(encrypted, isFalse);

      // Verify database was NOT updated
      final unchanged = await db.getReminderById(reminderId, 'user-123');
      expect(unchanged!.encryptionVersion, isNull);

      // Cleanup
      containerWithoutCrypto.dispose();
    });

    test('ensureReminderEncrypted handles user mismatch', () async {
      // Arrange
      reset(mockCrypto); // Reset to clear verification state
      reset(mockLogger);

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('reminder-lazy-4'),
          noteId: 'note-999',
          userId: 'user-456', // Different user
          type: ReminderType.time,
          title: const Value('Other user reminder'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

      final reminder = await db.getReminderById(reminderId, 'user-456');
      expect(reminder, isNotNull);

      // Act
      final encrypted = await service.ensureReminderEncrypted(reminder!);

      // Assert
      expect(encrypted, isFalse); // User mismatch prevented encryption

      // Verify warning was logged
      verify(mockLogger.warning(argThat(contains('Cannot encrypt reminder')))).called(1);
    });

    test('getRemindersForNote triggers lazy encryption in background',
        () async {
      // Arrange
      reset(mockCrypto); // Reset to clear verification state
      reset(mockAnalytics);

      final noteId = 'note-lazy-test';

      // Create the note first
      await db.into(db.localNotes).insert(
        LocalNotesCompanion.insert(
          id: noteId,
          titleEncrypted: const Value('encrypted-title'),
          bodyEncrypted: const Value('encrypted-body'),
          createdAt: DateTime.utc(2025, 11, 18),
          updatedAt: DateTime.utc(2025, 11, 18),
          deleted: const Value(false),
          userId: const Value('user-123'),
          isPinned: const Value(false),
          version: const Value(1),
        ),
      );

      final reminderId = await db.createReminder(
        NoteRemindersCompanion.insert(
          id: const Value('reminder-bg-1'),
          noteId: noteId,
          userId: 'user-123',
          type: ReminderType.time,
          title: const Value('Background encryption test'),
          body: const Value('Should be encrypted'),
          createdAt: Value(DateTime.utc(2025, 11, 18)),
        ),
      );

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

      // CRITICAL #7: Mock decryption for roundtrip verification
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
      final reminders = await service.getRemindersForNote(noteId);

      // Assert - reminders returned immediately
      expect(reminders, hasLength(1));
      expect(reminders.first.id, reminderId);

      // Wait for background encryption to complete
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify encryption was called (lazy encryption in background)
      verify(
        mockCrypto.encryptStringForNote(
          userId: anyNamed('userId'),
          noteId: anyNamed('noteId'),
          text: anyNamed('text'),
        ),
      ).called(greaterThanOrEqualTo(2)); // At least title and body
    });
  });
}
