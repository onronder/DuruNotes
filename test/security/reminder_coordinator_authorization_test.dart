import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider, loggerProvider, supabaseClientProvider;
import 'package:duru_notes/data/local/app_db.dart' as app_db;
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'reminder_coordinator_authorization_test.mocks.dart';

const _userA = 'user-a';
const _userB = 'user-b';

Future<List<SecurityEvent>> _captureAuditEvents(
  Future<void> Function() action,
) async {
  final trail = SecurityAuditTrail();
  final events = <SecurityEvent>[];
  final sub = trail.eventStream.listen(events.add);
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

class _TestReminderCoordinator extends ReminderCoordinator {
  _TestReminderCoordinator(super.ref, super.plugin, super.db);

  @override
  Future<bool> hasNotificationPermissions() async => true;

  @override
  Future<bool> requestNotificationPermissions() async => true;
}

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
  late _TestReminderCoordinator coordinator;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockAppLogger mockLogger;
  late MockAnalyticsService mockAnalytics;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;

  Future<void> setupCoordinator({String? userId}) async {
    FeatureFlags.instance.setOverride('use_unified_permission_manager', false);

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
    when(mockAnalytics.startTiming(any)).thenReturn(null);
    when(
      mockAnalytics.endTiming(any, properties: anyNamed('properties')),
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
    ).thenAnswer((_) async {});
    when(mockPlugin.cancel(any, tag: anyNamed('tag'))).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
      ],
    );

    final coordinatorProvider = Provider<_TestReminderCoordinator>((ref) {
      return _TestReminderCoordinator(ref, mockPlugin, db);
    });

    coordinator = container.read(coordinatorProvider);
    await coordinator.initialize();
  }

  Future<int> insertReminder({
    required String noteId,
    required String userId,
    required DateTime remindAt,
    bool isActive = true,
  }) async {
    return db.createReminder(
      app_db.NoteRemindersCompanion.insert(
        noteId: noteId,
        userId: userId,
        type: app_db.ReminderType.time,
        remindAt: Value(remindAt),
        isActive: Value(isActive),
        title: const Value('Reminder'),
        body: const Value('Body'),
      ),
    );
  }

  tearDown(() async {
    FeatureFlags.instance.clearOverrides();
    await db.close();
    container.dispose();
  });

  group('ReminderCoordinator audit logging', () {
    test('createTimeReminder logs success for authenticated user', () async {
      await setupCoordinator(userId: _userA);

      late int? reminderId;
      final events = await _captureAuditEvents(() async {
        reminderId = await coordinator.createTimeReminder(
          noteId: 'note-1',
          title: 'Test',
          body: 'Body',
          remindAtUtc: DateTime.now().toUtc().add(const Duration(hours: 2)),
        );
      });

      expect(reminderId, isNotNull);
      final stored = await db.getReminderById(reminderId!, _userA);
      expect(stored, isNotNull);

      final auditEvents = _eventsFor(
        events,
        'reminderCoordinator.createTimeReminder',
      );
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isTrue);
      expect(
        '${auditEvents.last.metadata?['reason']}',
        contains('reminderId='),
      );
    });

    test('createTimeReminder logs denial when unauthenticated', () async {
      await setupCoordinator(userId: null);

      final events = await _captureAuditEvents(() async {
        await coordinator.createTimeReminder(
          noteId: 'note-unauth',
          title: 'Title',
          body: 'Body',
          remindAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
      });

      final auditEvents = _eventsFor(
        events,
        'reminderCoordinator.createTimeReminder',
      );
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'missing_user');
    });

    test(
      'cancelReminder logs not_found when reminder belongs to another user',
      () async {
        await setupCoordinator(userId: _userB);
        final reminderId = await insertReminder(
          noteId: 'note-2',
          userId: _userA,
          remindAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );

        final events = await _captureAuditEvents(() async {
          await coordinator.cancelReminder(reminderId);
        });

        final auditEvents = _eventsFor(
          events,
          'reminderCoordinator.cancelReminder',
        );
        expect(auditEvents, isNotEmpty);
        expect(auditEvents.last.metadata?['granted'], isFalse);
        expect(auditEvents.last.metadata?['reason'], 'not_found');
      },
    );

    test('processDueReminders logs denial when unauthenticated', () async {
      await setupCoordinator(userId: null);

      final events = await _captureAuditEvents(() async {
        await coordinator.processDueReminders();
      });

      final auditEvents = _eventsFor(
        events,
        'reminderCoordinator.processDueReminders',
      );
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'missing_user');
    });
  });
}
