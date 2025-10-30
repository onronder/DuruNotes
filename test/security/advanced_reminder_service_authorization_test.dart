import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider, loggerProvider;
import 'package:duru_notes/data/local/app_db.dart' as app_db;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'advanced_reminder_service_authorization_test.mocks.dart';

const _userA = 'user-a';
const _userB = 'user-b';

Future<List<SecurityEvent>> _captureAuditEvents(
  Future<void> Function() action,
) async {
  final auditTrail = SecurityAuditTrail();
  final events = <SecurityEvent>[];
  final sub = auditTrail.eventStream.listen(events.add);
  try {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  } finally {
    await sub.cancel();
  }
  return events;
}

List<SecurityEvent> _eventsFor(List<SecurityEvent> events, String resource) =>
    events.where((event) => event.metadata?['resource'] == resource).toList();

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<AppLogger>(),
  MockSpec<AnalyticsService>(),
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<AndroidFlutterLocalNotificationsPlugin>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  late app_db.AppDb db;
  late ProviderContainer container;
  late AdvancedReminderService service;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockAppLogger mockLogger;
  late MockAnalyticsService mockAnalytics;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;
  late List<int> scheduledIds;
  late List<int> cancelledIds;

  Future<void> setupService({String? userId}) async {
    db = app_db.AppDb.forTesting(NativeDatabase.memory());

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    when(mockSupabase.auth).thenReturn(mockAuth);
    if (userId != null) {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn(userId);
    } else {
      when(mockAuth.currentUser).thenReturn(null);
    }

    mockLogger = MockAppLogger();
    when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.warning(any, data: anyNamed('data'))).thenReturn(null);
    when(
      mockLogger.error(
        any,
        error: anyNamed('error'),
        stackTrace: anyNamed('stackTrace'),
        data: anyNamed('data'),
      ),
    ).thenReturn(null);

    mockAnalytics = MockAnalyticsService();
    when(mockAnalytics.isEnabled).thenReturn(true);
    when(
      mockAnalytics.event(any, properties: anyNamed('properties')),
    ).thenReturn(null);

    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();

    when(mockPlugin.initialize(any)).thenAnswer((_) async => true);
    when(
      mockPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(mockAndroidPlugin);
    when(
      mockAndroidPlugin.createNotificationChannel(any),
    ).thenAnswer((_) async => {});

    scheduledIds = <int>[];
    cancelledIds = <int>[];

    when(
      mockPlugin.zonedSchedule(
        any,
        any,
        any,
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
      ),
    ).thenAnswer((invocation) async {
      scheduledIds.add(invocation.positionalArguments[0] as int);
    });

    when(mockPlugin.cancel(any, tag: anyNamed('tag'))).thenAnswer((
      invocation,
    ) async {
      cancelledIds.add(invocation.positionalArguments[0] as int);
    });

    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
      ],
    );

    final serviceProvider = Provider<AdvancedReminderService>((ref) {
      return AdvancedReminderService(ref, mockPlugin, db);
    });

    service = container.read(serviceProvider);
    await service.init();
  }

  Future<int> insertReminder({
    required String noteId,
    required String userId,
    required DateTime remindAt,
    bool isActive = true,
    int snoozeCount = 0,
  }) {
    return db.createReminder(
      app_db.NoteRemindersCompanion.insert(
        noteId: noteId,
        userId: userId,
        type: app_db.ReminderType.time,
        remindAt: Value(remindAt),
        isActive: Value(isActive),
        snoozeCount: Value(snoozeCount),
        title: const Value('Reminder'),
        body: const Value('Body'),
      ),
    );
  }

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('AdvancedReminderService authorization', () {
    test('createTimeReminder stores user and schedules notification', () async {
      await setupService(userId: _userA);

      final remindAt = DateTime.now().toUtc().add(const Duration(hours: 2));
      late int? reminderId;
      final events = await _captureAuditEvents(() async {
        reminderId = await service.createTimeReminder(
          noteId: 'note-1',
          title: 'Test',
          body: 'Body',
          remindAtUtc: remindAt,
        );
      });

      expect(reminderId, isNotNull);
      final stored = await db.getReminderById(reminderId!, _userA);
      expect(stored, isNotNull);
      expect(stored!.userId, equals(_userA));
      expect(scheduledIds, contains(reminderId.hashCode.abs()));

      final auditEvents = _eventsFor(
        events,
        'advancedReminder.createTimeReminder',
      );
      expect(auditEvents, isNotEmpty);
      final latest = auditEvents.last;
      expect(latest.metadata?['granted'], isTrue);
      expect('${latest.metadata?['reason']}', contains('reminderId='));
    });

    test('createTimeReminder returns null when unauthenticated', () async {
      await setupService(userId: null);

      final remindAt = DateTime.now().toUtc().add(const Duration(hours: 1));
      late int? reminderId;
      final events = await _captureAuditEvents(() async {
        reminderId = await service.createTimeReminder(
          noteId: 'note-unauth',
          title: 'Title',
          body: 'Body',
          remindAtUtc: remindAt,
        );
      });

      expect(reminderId, isNull);
      final reminders = await db.getReminderById(1, _userA);
      expect(reminders, isNull);
      expect(scheduledIds, isEmpty);

      final auditEvents = _eventsFor(
        events,
        'advancedReminder.createTimeReminder',
      );
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'missing_user');
    });

    test('deleteReminder ignores reminders owned by other users', () async {
      await setupService(userId: _userB);
      final reminderId = await insertReminder(
        noteId: 'note-2',
        userId: _userA,
        remindAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final events = await _captureAuditEvents(() async {
        await service.deleteReminder(reminderId);
      });

      final stored = await db.getReminderById(reminderId, _userA);
      expect(stored, isNotNull);

      final auditEvents = _eventsFor(events, 'advancedReminder.deleteReminder');
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'not_found');
    });

    test('snoozeReminder prevents cross-user snooze mutations', () async {
      await setupService(userId: _userB);
      final reminderId = await insertReminder(
        noteId: 'note-3',
        userId: _userA,
        remindAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final events = await _captureAuditEvents(() async {
        await service.snoozeReminder(
          reminderId,
          app_db.SnoozeDuration.fifteenMinutes,
        );
      });

      final stored = await db.getReminderById(reminderId, _userA);
      expect(stored, isNotNull);
      expect(stored!.snoozeCount, equals(0));
      expect(stored.snoozedUntil, isNull);
      expect(cancelledIds, isEmpty);
      expect(scheduledIds, isEmpty);

      final auditEvents = _eventsFor(events, 'advancedReminder.snoozeReminder');
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'not_found');
    });
  });
}
