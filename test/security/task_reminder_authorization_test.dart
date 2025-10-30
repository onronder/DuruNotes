import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/data/local/app_db.dart' as app_db;
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider, loggerProvider;
import 'package:duru_notes/providers/infrastructure_providers.dart'
    show navigatorKeyProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show taskReminderBridgeProvider;
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'task_reminder_authorization_test.mocks.dart';

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
  MockSpec<AdvancedReminderService>(),
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<AppLogger>(),
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
  late TaskReminderBridge bridge;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCrypto;
  late MockAdvancedReminderService mockAdvancedService;
  late MockFlutterLocalNotificationsPlugin mockNotifications;
  late MockAppLogger mockLogger;
  late FakeSnoozeReminderService fakeSnoozeService;
  late FakeReminderCoordinator fakeCoordinator;

  Future<void> setupBridge({String? supabaseUserId}) async {
    db = app_db.AppDb.forTesting(NativeDatabase.memory());

    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    when(mockSupabaseClient.auth).thenReturn(mockAuth);
    if (supabaseUserId != null) {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn(supabaseUserId);
    } else {
      when(mockAuth.currentUser).thenReturn(null);
    }

    mockCrypto = MockCryptoBox();

    mockAdvancedService = MockAdvancedReminderService();
    when(mockAdvancedService.deleteReminder(any)).thenAnswer((_) async => {});

    mockNotifications = MockFlutterLocalNotificationsPlugin();
    when(mockNotifications.initialize(any)).thenAnswer((_) async => true);
    when(
      mockNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    when(
      mockNotifications.zonedSchedule(
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
    when(mockNotifications.show(any, any, any, any)).thenAnswer((_) async {});

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

    fakeSnoozeService = FakeSnoozeReminderService();
    fakeCoordinator = FakeReminderCoordinator(fakeSnoozeService);

    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(db),
        supabaseClientProvider.overrideWithValue(mockSupabaseClient),
        navigatorKeyProvider.overrideWithValue(GlobalKey<NavigatorState>()),
        loggerProvider.overrideWithValue(mockLogger),
        taskCoreRepositoryProvider.overrideWithValue(null),
        advancedReminderServiceProvider.overrideWithValue(mockAdvancedService),
        taskReminderBridgeProvider.overrideWith(
          (ref) => TaskReminderBridge(
            ref,
            reminderCoordinator: fakeCoordinator,
            advancedReminderService: mockAdvancedService,
            database: db,
            notificationPlugin: mockNotifications,
            cryptoBox: mockCrypto,
            taskRepository: null,
          ),
        ),
      ],
    );

    bridge = container.read(taskReminderBridgeProvider);
  }

  Future<void> insertNote({
    required String noteId,
    required String userId,
  }) async {
    final now = DateTime.utc(2025, 10, 29);
    await db
        .into(db.localNotes)
        .insert(
          app_db.LocalNotesCompanion.insert(
            id: noteId,
            createdAt: now,
            updatedAt: now,
            titleEncrypted: const Value('{}'),
            bodyEncrypted: const Value('{}'),
            encryptionVersion: const Value(1),
            deleted: const Value(false),
            isPinned: const Value(false),
            noteType: Value(NoteKind.note),
            version: const Value(1),
            userId: Value(userId),
          ),
        );
  }

  Future<app_db.NoteTask> insertTask({
    required String taskId,
    required String noteId,
    required String userId,
    DateTime? dueDate,
    int? reminderId,
  }) async {
    final now = DateTime.utc(2025, 10, 29, 12);
    await db
        .into(db.noteTasks)
        .insert(
          app_db.NoteTasksCompanion.insert(
            id: taskId,
            noteId: noteId,
            userId: userId,
            contentEncrypted: '{"content":"Encrypted"}',
            contentHash: 'hash-$taskId',
            encryptionVersion: const Value(1),
            status: const Value(app_db.TaskStatus.open),
            priority: const Value(app_db.TaskPriority.medium),
            dueDate: Value(dueDate),
            position: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
            deleted: const Value(false),
            reminderId: reminderId != null
                ? Value(reminderId)
                : const Value.absent(),
          ),
        );
    final task = await db.getTaskById(taskId, userId: userId);
    return task!;
  }

  Future<int> insertReminder({
    required String noteId,
    required String userId,
    required DateTime remindAt,
    int snoozeCount = 0,
    bool isActive = true,
    DateTime? snoozedUntil,
  }) async {
    return db.createReminder(
      app_db.NoteRemindersCompanion.insert(
        noteId: noteId,
        userId: userId,
        type: app_db.ReminderType.time,
        remindAt: Value(remindAt),
        isActive: Value(isActive),
        snoozeCount: Value(snoozeCount),
        snoozedUntil: Value(snoozedUntil),
        title: const Value('Reminder'),
        body: const Value('Body'),
        notificationTitle: const Value('Title'),
        notificationBody: const Value('Body'),
      ),
    );
  }

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('TaskReminderBridge authorization', () {
    test('createTaskReminder links task for current user', () async {
      await setupBridge(supabaseUserId: _userA);
      await insertNote(noteId: 'note-1', userId: _userA);
      final dueDate = DateTime.now().add(const Duration(hours: 3));
      final originalTask = await insertTask(
        taskId: 'task-1',
        noteId: 'note-1',
        userId: _userA,
        dueDate: dueDate,
      );

      fakeCoordinator.nextReminderId = 321;

      final taskWithoutUser = originalTask.copyWith(userId: '');
      late int? reminderId;
      final events = await _captureAuditEvents(() async {
        reminderId = await bridge.createTaskReminder(
          task: taskWithoutUser,
          beforeDueDate: const Duration(minutes: 30),
        );
      });

      expect(reminderId, equals(321));

      final updatedTask = await db.getTaskById('task-1', userId: _userA);
      expect(updatedTask!.reminderId, equals(321));
      expect(fakeCoordinator.createCalls, hasLength(1));
      expect(fakeCoordinator.createCalls.single['noteId'], 'note-1');

      final auditEvents = _eventsFor(
        events,
        'taskReminderBridge.createTaskReminder',
      );
      expect(auditEvents, isNotEmpty);
      final latest = auditEvents.last;
      expect(latest.metadata?['granted'], isTrue);
      expect('${latest.metadata?['reason']}', contains('reminderId=321'));
    });

    test('createTaskReminder logs denial when unauthenticated', () async {
      await setupBridge(supabaseUserId: null);
      await insertNote(noteId: 'note-unauth', userId: _userA);
      final task = await insertTask(
        taskId: 'task-unauth',
        noteId: 'note-unauth',
        userId: _userA,
        dueDate: DateTime.now().add(const Duration(hours: 2)),
      );

      fakeCoordinator.nextReminderId = 555;

      late int? reminderId;
      final events = await _captureAuditEvents(() async {
        reminderId = await bridge.createTaskReminder(
          task: task.copyWith(userId: ''),
          beforeDueDate: const Duration(minutes: 45),
        );
      });

      expect(reminderId, equals(555));

      final storedTask = await db.getTaskById('task-unauth', userId: _userA);
      expect(storedTask!.reminderId, isNull);

      final auditEvents = _eventsFor(
        events,
        'taskReminderBridge.createTaskReminder',
      );
      expect(auditEvents, isNotEmpty);
      final latest = auditEvents.last;
      expect(latest.metadata?['granted'], isFalse);
      expect(latest.metadata?['reason'], 'missing_user');
    });

    test(
      'cancelTaskReminder skips link removal when user cannot be resolved',
      () async {
        await setupBridge(supabaseUserId: null);
        await insertNote(noteId: 'note-2', userId: _userA);
        await insertTask(
          taskId: 'task-2',
          noteId: 'note-2',
          userId: _userA,
          dueDate: DateTime.now().add(const Duration(hours: 2)),
          reminderId: 777,
        );

        final storedTask = await db.getTaskById('task-2', userId: _userA);
        final taskWithoutUser = storedTask!.copyWith(
          userId: '',
          reminderId: const Value(777),
        );

        final events = await _captureAuditEvents(() async {
          await bridge.cancelTaskReminder(taskWithoutUser);
        });

        verify(mockAdvancedService.deleteReminder(777)).called(1);

        final postTask = await db.getTaskById('task-2', userId: _userA);
        expect(postTask!.reminderId, equals(777));

        final auditEvents = _eventsFor(
          events,
          'taskReminderBridge.cancelTaskReminder',
        );
        expect(auditEvents, isNotEmpty);
        expect(auditEvents.last.metadata?['granted'], isFalse);
        expect(auditEvents.last.metadata?['reason'], 'missing_user');
      },
    );

    test('snoozeTaskReminder prevents cross-user reminder access', () async {
      await setupBridge(supabaseUserId: _userB);
      await insertNote(noteId: 'note-3', userId: _userA);
      await insertTask(
        taskId: 'task-3',
        noteId: 'note-3',
        userId: _userA,
        dueDate: DateTime.now().add(const Duration(hours: 4)),
        reminderId: null,
      );

      final reminderId = await insertReminder(
        noteId: 'note-3',
        userId: _userA,
        remindAt: DateTime.now().add(const Duration(hours: 2)),
        snoozeCount: 1,
      );

      await db.updateTask(
        'task-3',
        _userA,
        app_db.NoteTasksCompanion(reminderId: Value(reminderId)),
      );

      final taskForSnooze = (await db.getTaskById('task-3', userId: _userA))!;

      final events = await _captureAuditEvents(() async {
        await bridge.snoozeTaskReminder(
          task: taskForSnooze,
          snoozeDuration: const Duration(minutes: 15),
        );
      });

      expect(fakeSnoozeService.calls, isEmpty);

      final storedReminder = await db.getReminderById(reminderId, _userA);
      expect(storedReminder!.snoozeCount, equals(1));

      final auditEvents = _eventsFor(
        events,
        'taskReminderBridge.snoozeTaskReminder',
      );
      expect(auditEvents, isNotEmpty);
      expect(auditEvents.last.metadata?['granted'], isFalse);
      expect(auditEvents.last.metadata?['reason'], 'not_found');
    });
  });
}

class FakeReminderCoordinator {
  FakeReminderCoordinator(this.snoozeService);

  final FakeSnoozeReminderService snoozeService;
  int nextReminderId = 100;
  final List<Map<String, dynamic>> createCalls = [];

  Future<int?> createTimeReminder({
    required String noteId,
    required String title,
    required String body,
    required DateTime remindAtUtc,
    app_db.RecurrencePattern recurrence = app_db.RecurrencePattern.none,
    int recurrenceInterval = 1,
    DateTime? recurrenceEndDate,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    createCalls.add({
      'noteId': noteId,
      'title': title,
      'body': body,
      'remindAtUtc': remindAtUtc,
      'recurrence': recurrence,
      'interval': recurrenceInterval,
      'customTitle': customNotificationTitle,
      'customBody': customNotificationBody,
    });
    return nextReminderId;
  }
}

class FakeSnoozeReminderService {
  final List<Map<String, dynamic>> calls = [];
  bool shouldSucceed = true;

  Future<bool> snoozeReminder(
    int reminderId,
    app_db.SnoozeDuration duration,
  ) async {
    calls.add({'reminderId': reminderId, 'duration': duration});
    return shouldSucceed;
  }
}

class MockCryptoBox extends Mock implements CryptoBox {}
