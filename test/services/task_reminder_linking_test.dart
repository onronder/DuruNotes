import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'task_reminder_linking_test.mocks.dart';

final _pluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override in tests');
});

final _dbProvider = Provider<AppDb>((ref) {
  throw UnimplementedError('Override in tests');
});

final _reminderCoordinatorTestProvider = Provider<_FakeReminderCoordinator>((
  ref,
) {
  throw UnimplementedError('Override in tests');
});

final _advancedReminderServiceProvider = Provider<AdvancedReminderService>((
  ref,
) {
  throw UnimplementedError('Override in tests');
});

final _cryptoBoxProvider = Provider<CryptoBox>((ref) {
  throw UnimplementedError('Override in tests');
});

final _taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  throw UnimplementedError('Override in tests');
});

final _taskReminderBridgeProvider = Provider<TaskReminderBridge>((ref) {
  return TaskReminderBridge(
    ref,
    reminderCoordinator: ref.watch(_reminderCoordinatorTestProvider),
    advancedReminderService: ref.watch(_advancedReminderServiceProvider),
    database: ref.watch(_dbProvider),
    notificationPlugin: ref.watch(_pluginProvider),
    cryptoBox: ref.watch(_cryptoBoxProvider),
    taskRepository: ref.watch(_taskRepositoryProvider),
  );
});

class _FakeReminderCoordinator {
  _FakeReminderCoordinator(this.snoozeService);

  int? lastCreateCount;
  Duration? lastBeforeDue;
  String? lastNoteId;
  String? lastTitle;
  String? lastBody;
  DateTime? lastRemindAt;
  int reminderIdToReturn = 321;
  SnoozeReminderService snoozeService;

  Future<int?> createTimeReminder({
    required String noteId,
    required String title,
    required String body,
    required DateTime remindAtUtc,
    RecurrencePattern recurrence = RecurrencePattern.none,
    int recurrenceInterval = 1,
    DateTime? recurrenceEndDate,
    String? customNotificationTitle,
    String? customNotificationBody,
  }) async {
    lastCreateCount = recurrenceInterval;
    lastBeforeDue = remindAtUtc.difference(DateTime.now().toUtc());
    lastNoteId = noteId;
    lastTitle = title;
    lastBody = body;
    lastRemindAt = remindAtUtc;
    return reminderIdToReturn;
  }
}

class _FakeTaskRepository extends Fake implements ITaskRepository {
  _FakeTaskRepository(this.task);

  final domain.Task task;

  @override
  Future<domain.Task?> getTaskById(String id) async => task;

  // Unused interface members
  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) => throw UnimplementedError();
}

@GenerateNiceMocks([
  MockSpec<FlutterLocalNotificationsPlugin>(),
  MockSpec<AndroidFlutterLocalNotificationsPlugin>(),
  MockSpec<AppDb>(),
  MockSpec<AnalyticsService>(),
  MockSpec<AppLogger>(),
  MockSpec<AdvancedReminderService>(),
  MockSpec<SnoozeReminderService>(),
  MockSpec<CryptoBox>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  const MethodChannel timezoneChannel = MethodChannel('flutter_timezone');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(timezoneChannel, (call) async {
        if (call.method == 'getLocalTimezone') {
          return 'UTC';
        }
        return null;
      });

  late ProviderContainer container;
  late TaskReminderBridge bridge;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;
  late MockAppDb mockDb;
  late MockAnalyticsService mockAnalytics;
  late MockAppLogger mockLogger;
  late MockAdvancedReminderService mockAdvancedService;
  late MockSnoozeReminderService mockSnoozeService;
  late _FakeReminderCoordinator fakeCoordinator;
  late _FakeTaskRepository fakeRepository;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCryptoBox;

  final testNavigatorKey = GlobalKey<NavigatorState>();

  Future<void> initializeSupabase() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
  }

  domain.Task domainTask() {
    final now = DateTime.now();
    return domain.Task(
      id: 'task-1',
      noteId: 'note-1',
      title: 'Review architecture',
      description: null,
      status: domain.TaskStatus.pending,
      priority: domain.TaskPriority.high,
      dueDate: now.add(const Duration(hours: 4)),
      completedAt: null,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
      tags: const ['focus'],
      metadata: const {},
    );
  }

  NoteTask noteTask({int? reminderId}) {
    final now = DateTime.now();
    return NoteTask(
      id: 'task-1',
      noteId: 'note-1',
      userId: 'user-123',
      contentEncrypted: 'encrypted-content',
      labelsEncrypted: null,
      notesEncrypted: null,
      encryptionVersion: 1,
      status: TaskStatus.open,
      priority: TaskPriority.high,
      dueDate: now.add(const Duration(hours: 4)),
      completedAt: null,
      completedBy: null,
      position: 0,
      contentHash: 'hash',
      reminderId: reminderId,
      estimatedMinutes: 30,
      actualMinutes: null,
      parentTaskId: null,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now,
      deleted: false,
    );
  }

  NoteReminder noteReminder({required DateTime snoozedUntil, int count = 2}) {
    final now = DateTime.now();
    return NoteReminder(
      id: 321,
      noteId: 'note-1',
      userId: 'user-123',
      title: 'Reminder title',
      body: 'Reminder body',
      type: ReminderType.time,
      remindAt: now,
      isActive: true,
      latitude: null,
      longitude: null,
      radius: null,
      locationName: null,
      recurrencePattern: RecurrencePattern.none,
      recurrenceEndDate: null,
      recurrenceInterval: 1,
      snoozedUntil: snoozedUntil,
      snoozeCount: count,
      notificationTitle: null,
      notificationBody: null,
      notificationImage: null,
      timeZone: 'UTC',
      createdAt: now.subtract(const Duration(days: 1)),
      lastTriggered: null,
      triggerCount: 0,
    );
  }

  setUpAll(() async {
    await initializeSupabase();
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();
    mockDb = MockAppDb();
    mockAnalytics = MockAnalyticsService();
    mockLogger = MockAppLogger();
    mockAdvancedService = MockAdvancedReminderService();
    mockSnoozeService = MockSnoozeReminderService();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockCryptoBox = MockCryptoBox();

    fakeCoordinator = _FakeReminderCoordinator(mockSnoozeService);
    fakeRepository = _FakeTaskRepository(domainTask());

    when(mockPlugin.initialize(any)).thenAnswer((_) async => true);
    when(
      mockPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(mockAndroidPlugin);
    when(
      mockAndroidPlugin.createNotificationChannel(any),
    ).thenAnswer((_) async {});
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
    when(mockPlugin.cancel(any)).thenAnswer((_) async {});
    when(mockPlugin.show(any, any, any, any)).thenAnswer((_) async {});

    when(mockSupabaseClient.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('user-123');
    when(
      mockAnalytics.event(any, properties: anyNamed('properties')),
    ).thenReturn(null);
    when(
      mockAnalytics.featureUsed(any, properties: anyNamed('properties')),
    ).thenReturn(null);

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

    when(
      mockCryptoBox.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((_) async => 'Review architecture');

    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
        supabaseClientProvider.overrideWithValue(mockSupabaseClient),
        navigatorKeyProvider.overrideWithValue(testNavigatorKey),
        _pluginProvider.overrideWithValue(mockPlugin),
        _dbProvider.overrideWithValue(mockDb),
        _reminderCoordinatorTestProvider.overrideWithValue(fakeCoordinator),
        _advancedReminderServiceProvider.overrideWithValue(mockAdvancedService),
        _cryptoBoxProvider.overrideWithValue(mockCryptoBox),
        _taskRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );

    bridge = container.read(_taskReminderBridgeProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('createTaskReminder', () {
    test('links reminder id to task and returns id', () async {
      NoteTasksCompanion? capturedUpdate;
      when(mockDb.updateTask(any, any, any)).thenAnswer((invocation) async {
        capturedUpdate =
            invocation.positionalArguments[2] as NoteTasksCompanion;
      });

      final result = await bridge.createTaskReminder(
        task: noteTask(),
        beforeDueDate: const Duration(hours: 2),
      );

      expect(result, equals(fakeCoordinator.reminderIdToReturn));
      expect(capturedUpdate, isNotNull);
      expect(capturedUpdate!.reminderId.value, equals(321));
      expect(capturedUpdate!.updatedAt.present, isTrue);
      verify(mockDb.updateTask('task-1', 'user-123', any)).called(1);
    });
  });

  group('cancelTaskReminder', () {
    test('clears reminder id and deletes remote reminder', () async {
      when(mockAdvancedService.deleteReminder(321)).thenAnswer((_) async {});
      when(mockDb.updateTask(any, any, any)).thenAnswer((_) async {});

      await bridge.cancelTaskReminder(noteTask(reminderId: 321));

      verify(mockAdvancedService.deleteReminder(321)).called(1);
      verify(mockDb.updateTask('task-1', 'user-123', any)).called(1);
    });
  });

  group('snoozeTaskReminder', () {
    test('delegates to snooze service and syncs updated reminder', () async {
      when(
        mockSnoozeService.snoozeReminder(321, any),
      ).thenAnswer((_) async => true);

      int getReminderCall = 0;
      when(mockDb.getReminderById(321, 'user-123')).thenAnswer((_) async {
        getReminderCall++;
        if (getReminderCall == 1) {
          return noteReminder(
            snoozedUntil: DateTime.now().add(const Duration(minutes: 5)),
            count: 2,
          );
        }
        return noteReminder(
          snoozedUntil: DateTime.now().add(const Duration(minutes: 15)),
          count: 3,
        );
      });

      await bridge.snoozeTaskReminder(
        task: noteTask(reminderId: 321),
        snoozeDuration: const Duration(minutes: 15),
      );

      verify(
        mockSnoozeService.snoozeReminder(321, SnoozeDuration.fifteenMinutes),
      ).called(1);
      verify(
        mockDb.getReminderById(321, 'user-123'),
      ).called(greaterThanOrEqualTo(2));
    });
  });
}
