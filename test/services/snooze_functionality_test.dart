import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'snooze_functionality_test.mocks.dart';

final _pluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override in tests');
});

final _dbProvider = Provider<AppDb>((ref) {
  throw UnimplementedError('Override in tests');
});

final _serviceProvider = Provider<TestSnoozeReminderService>((ref) {
  final plugin = ref.watch(_pluginProvider);
  final db = ref.watch(_dbProvider);
  return TestSnoozeReminderService(ref, plugin, db);
});

class TestSnoozeReminderService extends SnoozeReminderService {
  TestSnoozeReminderService(
    super.ref,
    super.plugin,
    super.db,
  );

  bool permissionGranted = true;

  @override
  Future<bool> hasNotificationPermissions() async => permissionGranted;
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
  late TestSnoozeReminderService service;
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

    when(mockAnalytics.event(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.featureUsed(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.startTiming(any)).thenReturn(null);
    when(mockAnalytics.endTiming(any, properties: anyNamed('properties')))
        .thenReturn(null);

    when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.warning(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.error(
      any,
      error: anyNamed('error'),
      stackTrace: anyNamed('stackTrace'),
      data: anyNamed('data'),
    )).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        _pluginProvider.overrideWithValue(mockPlugin),
        _dbProvider.overrideWithValue(mockDb),
      ],
    );

    service = container.read(_serviceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  NoteReminder reminder0({int snoozeCount = 0}) => NoteReminder(
        id: 42,
        noteId: 'note-123',
        userId: 'user-123',
        title: 'Standup reminder',
        body: 'Join the daily standup',
        type: ReminderType.time,
        remindAt: DateTime.now().add(const Duration(minutes: 5)),
        isActive: true,
        latitude: null,
        longitude: null,
        radius: null,
        locationName: null,
        recurrencePattern: RecurrencePattern.none,
        recurrenceEndDate: null,
        recurrenceInterval: 1,
        snoozedUntil: null,
        snoozeCount: snoozeCount,
        notificationTitle: null,
        notificationBody: null,
        notificationImage: null,
        timeZone: 'UTC',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastTriggered: null,
        triggerCount: 0,
      );

  group('snoozeReminder', () {
    test('returns true and reschedules reminder', () async {
      final reminder = reminder0(snoozeCount: 2);
      DateTime? snoozedUntilArg;
      NoteRemindersCompanion? updateCompanion;

      when(mockDb.getReminderById(42, 'user-123'))
          .thenAnswer((_) async => reminder);
      when(mockDb.snoozeReminder(any, any, any)).thenAnswer((invocation) async {
        snoozedUntilArg = invocation.positionalArguments[2] as DateTime;
      });
      when(mockDb.updateReminder(any, any, any)).thenAnswer((invocation) async {
        updateCompanion = invocation.positionalArguments[2]
            as NoteRemindersCompanion;
      });
      when(mockPlugin.cancel(any)).thenAnswer((_) async {});
      when(mockPlugin.zonedSchedule(
        any,
        any,
        any,
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});

      final start = DateTime.now();
      final result = await service.snoozeReminder(42, SnoozeDuration.fifteenMinutes);

      expect(result, isTrue);
      expect(snoozedUntilArg, isNotNull);
      expect(snoozedUntilArg!.isAfter(start), isTrue);
      expect(snoozedUntilArg!.difference(start).inMinutes, equals(15));
      expect(updateCompanion, isNotNull);
      expect(updateCompanion!.snoozeCount.value, equals(3));

      verify(mockDb.snoozeReminder(42, 'user-123', any)).called(1);
      verify(mockDb.updateReminder(42, 'user-123', any)).called(1);
      verify(mockPlugin.cancel(42)).called(1);
      verify(mockPlugin.zonedSchedule(
        42,
        'Standup reminder',
        'Join the daily standup',
        any,
        any,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: anyNamed('payload'),
      )).called(1);

      verify(mockAnalytics.event('reminder_snoozed', properties: anyNamed('properties')))
          .called(1);
      verify(mockAnalytics.featureUsed('snooze_used', properties: anyNamed('properties')))
          .called(1);
    });

    test('returns false when snooze limit reached', () async {
      final reminder = reminder0(snoozeCount: SnoozeReminderService.maxSnoozeCount);

      when(mockDb.getReminderById(42, 'user-123'))
          .thenAnswer((_) async => reminder);

      final result = await service.snoozeReminder(42, SnoozeDuration.fiveMinutes);

      expect(result, isFalse);
      verifyNever(mockDb.snoozeReminder(any, any, any));
      verify(mockAnalytics.event('snooze_limit_reached', properties: anyNamed('properties')))
          .called(1);
    });

    test('returns false when notification permission denied', () async {
      final reminder = reminder0();
      service.permissionGranted = false;

      when(mockDb.getReminderById(42, 'user-123'))
          .thenAnswer((_) async => reminder);

      final result = await service.snoozeReminder(42, SnoozeDuration.tenMinutes);

      expect(result, isFalse);
      verify(mockAnalytics.event('snooze_failed', properties: anyNamed('properties')))
          .called(1);
      verifyNever(mockDb.snoozeReminder(any, any, any));
    });
  });
}
