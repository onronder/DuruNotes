import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/services/reminders/snooze_reminder_service.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@GenerateMocks([
  AppDb,
  TaskReminderBridge,
  ReminderCoordinator,
  AdvancedReminderService,
  FlutterLocalNotificationsPlugin,
])
import 'task_reminder_linking_test.mocks.dart';

class MockSnoozeReminderService extends Mock implements SnoozeReminderService {}

class FakeSnoozeReminderService extends Fake implements SnoozeReminderService {
  int? capturedReminderId;
  SnoozeDuration? capturedDuration;

  @override
  Future<bool> snoozeReminder(int reminderId, SnoozeDuration duration) async {
    capturedReminderId = reminderId;
    capturedDuration = duration;
    return true;
  }
}

void main() {
  late MockAppDb mockDb;
  late MockTaskReminderBridge mockReminderBridge;
  late EnhancedTaskService enhancedTaskService;

  setUp(() {
    mockDb = MockAppDb();
    mockReminderBridge = MockTaskReminderBridge();

    when(mockDb.transaction<String>(
      any,
      requireNew: anyNamed('requireNew'),
    )).thenAnswer((invocation) async {
      final action =
          invocation.positionalArguments.first as Future<String> Function();
      return await action();
    });

    enhancedTaskService = EnhancedTaskService(
      database: mockDb,
      reminderBridge: mockReminderBridge,
    );
  });

  group('Task Reminder Linking', () {
    test('should link reminder ID to task when creating task with reminder',
        () async {
      // Arrange
      const reminderId = 42;
      final dueDate = DateTime.now().add(const Duration(days: 1));

      final taskTemplate = NoteTask(
        id: 'template',
        noteId: 'note-123',
        content: 'Test task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        dueDate: dueDate,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      var capturedTaskId = '';

      // Mock the database operations
      when(mockDb.createTask(any)).thenAnswer((invocation) async {
        final companion =
            invocation.positionalArguments.first as NoteTasksCompanion;
        capturedTaskId = companion.id.value;
      });
      when(mockDb.getTaskById(any)).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        return taskTemplate.copyWith(id: id);
      });
      when(mockDb.updateTask(any, any)).thenAnswer((_) async {});

      // Mock reminder creation
      when(mockReminderBridge.createTaskReminder(
        task: anyNamed('task'),
        beforeDueDate: anyNamed('beforeDueDate'),
      )).thenAnswer((_) async => reminderId);

      // Act
      final resultTaskId = await enhancedTaskService.createTask(
        noteId: 'note-123',
        content: 'Test task',
        dueDate: dueDate,
        createReminder: true,
      );

      // Assert
      expect(resultTaskId, isNotEmpty);
      expect(resultTaskId, equals(capturedTaskId));

      // Verify reminder was created
      verify(mockReminderBridge.createTaskReminder(
        task: argThat(isA<NoteTask>(), named: 'task'),
        beforeDueDate:
            argThat(equals(const Duration(hours: 1)), named: 'beforeDueDate'),
      )).called(1);

      // Verify task was updated with reminder ID
      verify(mockDb.updateTask(
        capturedTaskId,
        argThat(
          isA<NoteTasksCompanion>().having(
            (c) => c.reminderId.value,
            'reminderId',
            equals(reminderId),
          ),
        ),
      )).called(1);
    });

    test('should clear reminder ID when cancelling task reminder', () async {
      // Arrange
      const taskId = 'test-task-123';
      const reminderId = 42;

      final task = NoteTask(
        id: taskId,
        noteId: 'note-123',
        content: 'Test task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        reminderId: reminderId,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final taskService = TaskService(database: mockDb);
      final mockAdvancedReminderService = MockAdvancedReminderService();
      final mockReminderCoordinator = MockReminderCoordinator();
      final mockNotificationPlugin = MockFlutterLocalNotificationsPlugin();

      final reminderBridge = TaskReminderBridge(
        reminderCoordinator: mockReminderCoordinator,
        advancedReminderService: mockAdvancedReminderService,
        taskService: taskService,
        database: mockDb,
        notificationPlugin: mockNotificationPlugin,
      );

      // Mock the delete operation
      when(mockAdvancedReminderService.deleteReminder(reminderId))
          .thenAnswer((_) async {});
      when(mockDb.updateTask(any, any)).thenAnswer((_) async {});

      // Act
      await reminderBridge.cancelTaskReminder(task);

      // Assert
      verify(mockAdvancedReminderService.deleteReminder(reminderId)).called(1);

      // Verify task was updated with cleared reminder ID
      verify(mockDb.updateTask(
        taskId,
        argThat(
          isA<NoteTasksCompanion>(),
        ),
      )).called(1);
    });

    test('should update reminder ID when snoozing task reminder', () async {
      // Arrange
      const taskId = 'test-task-123';
      const oldReminderId = 42;
      const newReminderId = 43;
      final dueDate = DateTime.now().add(const Duration(days: 1));

      final task = NoteTask(
        id: taskId,
        noteId: 'note-123',
        content: 'Test task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        dueDate: dueDate,
        reminderId: oldReminderId,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final taskService = TaskService(database: mockDb);
      final mockAdvancedReminderService = MockAdvancedReminderService();
      final mockReminderCoordinator = MockReminderCoordinator();
      final mockNotificationPlugin = MockFlutterLocalNotificationsPlugin();

      final reminderBridge = TaskReminderBridge(
        reminderCoordinator: mockReminderCoordinator,
        advancedReminderService: mockAdvancedReminderService,
        taskService: taskService,
        database: mockDb,
        notificationPlugin: mockNotificationPlugin,
      );

      // Mock operations
      final fakeSnoozeService = FakeSnoozeReminderService();
      when(mockReminderCoordinator.snoozeService).thenReturn(fakeSnoozeService);
      when(mockDb.getReminderById(oldReminderId))
          .thenAnswer((_) async => NoteReminder(
                id: oldReminderId,
                noteId: task.noteId,
                title: task.content,
                body: task.content,
                type: ReminderType.time,
                remindAt: dueDate,
                isActive: true,
                recurrencePattern: RecurrencePattern.none,
                recurrenceInterval: 1,
                snoozeCount: 0,
                createdAt: DateTime.now(),
                triggerCount: 0,
              ));

      // Act
      await reminderBridge.snoozeTaskReminder(
        task: task,
        snoozeDuration: const Duration(minutes: 15),
      );

      // Assert
      expect(fakeSnoozeService.capturedReminderId, equals(oldReminderId));
      expect(fakeSnoozeService.capturedDuration, SnoozeDuration.fifteenMinutes);
      verifyNever(mockAdvancedReminderService.deleteReminder(any));
      verifyNever(mockReminderCoordinator.createTimeReminder(
        noteId: anyNamed('noteId'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        remindAtUtc: anyNamed('remindAtUtc'),
        customNotificationTitle: anyNamed('customNotificationTitle'),
        customNotificationBody: anyNamed('customNotificationBody'),
      ));
      verifyNever(mockDb.updateTask(any, any));
    });
  });
}
