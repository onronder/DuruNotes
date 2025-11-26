import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
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

import 'base_reminder_service_test.mocks.dart';

final _pluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override in tests');
});

final _dbProvider = Provider<AppDb>((ref) {
  throw UnimplementedError('Override in tests');
});

final _reminderServiceProvider = Provider<TestReminderService>((ref) {
  final plugin = ref.watch(_pluginProvider);
  final db = ref.watch(_dbProvider);
  return TestReminderService(ref, plugin, db);
});

class TestReminderService extends BaseReminderService {
  TestReminderService(super.ref, super.plugin, super.db);

  @override
  Future<String?> createReminder(ReminderConfig config) async =>
      'test-reminder-id';
}

@GenerateNiceMocks([
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<AppDb>(),
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
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAppDb mockDb;
  late MockAnalyticsService mockAnalytics;
  late MockAppLogger mockLogger;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockDb = MockAppDb();
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
        _dbProvider.overrideWithValue(mockDb),
      ],
    );

    service = container.read(_reminderServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('BaseReminderService database operations', () {
    test('createReminderInDb returns inserted identifier', () async {
      when(mockDb.createReminder(any)).thenAnswer((_) async => 'reminder-99');

      final config = ReminderConfig(
        noteId: 'note-123',
        title: 'Project checkpoint',
        scheduledTime: DateTime.utc(2025, 10, 20, 12),
      );
      final companion = config.toCompanion(ReminderType.time, 'user-123');

      final result = await service.createReminderInDb(companion);

      expect(result, 'reminder-99');
      verify(mockDb.createReminder(companion)).called(1);
    });

    test(
      'updateReminderStatus updates record when user authenticated',
      () async {
        NoteRemindersCompanion? updatedCompanion;
        when(mockDb.updateReminder(any, any, any)).thenAnswer((
          invocation,
        ) async {
          updatedCompanion =
              invocation.positionalArguments[2] as NoteRemindersCompanion;
        });

        await service.updateReminderStatus('reminder-42', true);

        verify(mockDb.updateReminder('reminder-42', 'user-123', any)).called(1);
        expect(updatedCompanion, isNotNull);
        expect(updatedCompanion!.isActive.value, isTrue);
      },
    );

    test('updateReminderStatus skips update when user missing', () async {
      when(mockAuth.currentUser).thenReturn(null);

      await service.updateReminderStatus('reminder-13', false);

      verifyNever(mockDb.updateReminder(any, any, any));
    });

    test('getRemindersForNote delegates to database with user scope', () async {
      final reminder = NoteReminder(
        id: 'reminder-1',
        noteId: 'note-abc',
        userId: 'user-123',
        title: 'Sync meeting',
        body: 'Discuss roadmap',
        type: ReminderType.time,
        remindAt: DateTime.utc(2025, 10, 20, 9),
        isActive: true,
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
        createdAt: DateTime.utc(2025, 10, 19),
        lastTriggered: null,
        triggerCount: 0,
      );

      when(
        mockDb.getRemindersForNote('note-abc', 'user-123'),
      ).thenAnswer((_) async => [reminder]);

      final results = await service.getRemindersForNote('note-abc');

      expect(results, hasLength(1));
      expect(results.first.title, 'Sync meeting');
    });

    test('getRemindersForNote returns empty when unauthenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final results = await service.getRemindersForNote('note-xyz');

      expect(results, isEmpty);
      verifyNever(mockDb.getRemindersForNote(any, any));
    });
  });

  group('BaseReminderService notifications', () {
    test('scheduleNotification delegates to plugin', () async {
      when(
        mockPlugin.zonedSchedule(
          any,
          any,
          any,
          any,
          any,
          androidScheduleMode: anyNamed('androidScheduleMode'),
          payload: anyNamed('payload'),
        ),
      ).thenAnswer((_) async {});

      final data = ReminderNotificationData(
        id: 'reminder-77',
        title: 'Daily review',
        body: 'Capture notes before wrap-up',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        payload: 'note-123',
      );

      await service.scheduleNotification(data);

      verify(
        mockPlugin.zonedSchedule(
          any,
          'Daily review',
          'Capture notes before wrap-up',
          any,
          any,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'note-123',
        ),
      ).called(1);
    });

    test('cancelNotification cancels scheduled entry', () async {
      when(mockPlugin.cancel(any)).thenAnswer((_) async {});

      await service.cancelNotification('reminder-88');

      verify(mockPlugin.cancel(any)).called(1);
    });

    test('getPendingNotifications returns plugin list', () async {
      when(mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(1, 'Title', 'Body', 'payload'),
        ],
      );

      final pending = await service.getPendingNotifications();

      expect(pending, hasLength(1));
      expect(pending.first.id, 1);
      verify(mockPlugin.pendingNotificationRequests()).called(1);
    });
  });
}
