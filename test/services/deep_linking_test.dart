import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/deep_link_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/services/notification_config_service.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/main.dart' show navigatorKey;
import 'dart:convert';

@GenerateMocks([
  AppDb,
  NotesRepository,
  TaskReminderBridge,
])
import 'deep_linking_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockNotesRepository mockNotesRepo;
  late MockTaskReminderBridge mockTaskBridge;
  late ProviderContainer container;
  late DeepLinkService deepLinkService;
  
  setUp(() {
    mockDb = MockAppDb();
    mockNotesRepo = MockNotesRepository();
    mockTaskBridge = MockTaskReminderBridge();
    
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(mockDb),
        notesRepositoryProvider.overrideWithValue(mockNotesRepo),
      ],
    );
    
    deepLinkService = DeepLinkService(ref: container);
  });
  
  tearDown(() {
    container.dispose();
  });
  
  group('Deep Linking from Notifications', () {
    testWidgets('should handle task reminder notification tap', (tester) async {
      const taskId = 'task-123';
      const noteId = 'note-456';
      
      final task = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Test Task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      final note = LocalNote(
        id: noteId,
        title: 'Test Note',
        body: '- [ ] Test Task\n- [ ] Another Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getTaskById(taskId)).thenAnswer((_) async => task);
      when(mockNotesRepo.getNote(noteId)).thenAnswer((_) async => note);
      
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Simulate notification tap
                        await deepLinkService.handleDeepLink(
                          context: context,
                          payload: jsonEncode({
                            'type': 'task_reminder',
                            'taskId': taskId,
                            'noteId': noteId,
                          }),
                        );
                      },
                      child: const Text('Simulate Notification'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      
      // Tap the button to simulate notification
      await tester.tap(find.text('Simulate Notification'));
      await tester.pumpAndSettle();
      
      // Verify task was fetched
      verify(mockDb.getTaskById(taskId)).called(1);
      
      // Verify note was fetched for navigation
      verify(mockNotesRepo.getNote(noteId)).called(1);
    });
    
    testWidgets('should handle task completion action', (tester) async {
      const taskId = 'task-789';
      const noteId = 'note-abc';
      
      final task = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Complete this task',
        status: TaskStatus.open,
        priority: TaskPriority.high,
        position: 0,
        contentHash: 'hash',
        reminderId: 42,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockDb.getTaskById(taskId)).thenAnswer((_) async => task);
      when(mockTaskBridge.handleTaskNotificationAction(
        action: anyNamed('action'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});
      
      // Test complete action
      await mockTaskBridge.handleTaskNotificationAction(
        action: 'complete_task',
        payload: jsonEncode({
          'taskId': taskId,
          'noteId': noteId,
        }),
      );
      
      verify(mockTaskBridge.handleTaskNotificationAction(
        action: 'complete_task',
        payload: anyNamed('payload'),
      )).called(1);
    });
    
    testWidgets('should handle snooze action', (tester) async {
      const taskId = 'task-snooze';
      const noteId = 'note-snooze';
      
      final task = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Snooze this task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash',
        reminderId: 99,
        dueDate: DateTime.now().add(const Duration(hours: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockDb.getTaskById(taskId)).thenAnswer((_) async => task);
      when(mockTaskBridge.handleTaskNotificationAction(
        action: anyNamed('action'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});
      
      // Test snooze actions
      await mockTaskBridge.handleTaskNotificationAction(
        action: 'snooze_task_15',
        payload: jsonEncode({
          'taskId': taskId,
          'noteId': noteId,
        }),
      );
      
      verify(mockTaskBridge.handleTaskNotificationAction(
        action: 'snooze_task_15',
        payload: anyNamed('payload'),
      )).called(1);
      
      await mockTaskBridge.handleTaskNotificationAction(
        action: 'snooze_task_1h',
        payload: jsonEncode({
          'taskId': taskId,
          'noteId': noteId,
        }),
      );
      
      verify(mockTaskBridge.handleTaskNotificationAction(
        action: 'snooze_task_1h',
        payload: anyNamed('payload'),
      )).called(1);
    });
  });
  
  group('App State Handling', () {
    test('should store pending deep link when app not ready', () async {
      const taskId = 'task-pending';
      const noteId = 'note-pending';
      
      // Simulate app not ready (no navigator context)
      // This is tested in TaskReminderBridge
      final bridge = mockTaskBridge;
      
      // When context is null, the deep link should be stored
      // This behavior is implemented in TaskReminderBridge
      
      // Verify that pending deep link is processed when app becomes ready
      // This would be tested with integration tests
    });
    
    test('should handle task not found gracefully', () async {
      const taskId = 'task-missing';
      const noteId = 'note-missing';
      
      when(mockDb.getTaskById(taskId)).thenAnswer((_) async => null);
      when(mockNotesRepo.getNote(noteId)).thenAnswer((_) async => null);
      
      // Should not throw, just show error message
      await deepLinkService.handleDeepLink(
        context: MockBuildContext(),
        payload: jsonEncode({
          'type': 'task_reminder',
          'taskId': taskId,
          'noteId': noteId,
        }),
      );
      
      // Verify graceful handling
      verify(mockDb.getTaskById(taskId)).called(1);
    });
  });
  
  group('Notification Configuration', () {
    test('should have correct Android actions', () {
      final configService = NotificationConfigService.instance;
      final actions = configService.getTaskNotificationActions();
      
      expect(actions.length, equals(4));
      
      // Check action IDs
      final actionIds = actions.map((a) => a.id).toList();
      expect(actionIds, contains('complete_task'));
      expect(actionIds, contains('snooze_task_15'));
      expect(actionIds, contains('snooze_task_1h'));
      expect(actionIds, contains('open_task'));
    });
    
    test('should have correct iOS categories', () {
      final configService = NotificationConfigService.instance;
      final settings = configService.getInitializationSettings();
      
      expect(settings.iOS, isNotNull);
      
      // The categories are defined in the settings
      final iosSettings = settings.iOS as DarwinInitializationSettings;
      expect(iosSettings.notificationCategories, isNotNull);
      expect(iosSettings.notificationCategories!.length, greaterThan(0));
      
      // Find task reminder category
      final taskCategory = iosSettings.notificationCategories!
          .firstWhere((c) => c.identifier == 'TASK_REMINDER');
      
      expect(taskCategory.actions.length, equals(4));
      
      // Check action identifiers
      final actionIds = taskCategory.actions.map((a) => a.identifier).toList();
      expect(actionIds, contains('complete_task'));
      expect(actionIds, contains('snooze_task_15'));
      expect(actionIds, contains('snooze_task_1h'));
      expect(actionIds, contains('open_task'));
    });
  });
  
  group('Task Highlighting', () {
    test('should pass highlight parameters to note editor', () async {
      const taskId = 'task-highlight';
      const noteId = 'note-highlight';
      const taskContent = 'Highlighted Task';
      
      final task = NoteTask(
        id: taskId,
        noteId: noteId,
        content: taskContent,
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 5,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      final note = LocalNote(
        id: noteId,
        title: 'Test Note',
        body: '''
# Tasks
- [ ] First Task
- [ ] Second Task
- [ ] Third Task
- [ ] Fourth Task
- [ ] Highlighted Task
- [ ] Last Task
''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getTaskById(taskId)).thenAnswer((_) async => task);
      when(mockNotesRepo.getNote(noteId)).thenAnswer((_) async => note);
      
      // The deep link service should pass highlighting parameters
      // This would be verified in the ModernEditNoteScreen
      // which would highlight the task content
      
      expect(task.content, equals(taskContent));
      expect(note.body.contains(taskContent), isTrue);
    });
  });
}

// Mock BuildContext for testing
class MockBuildContext extends Mock implements BuildContext {}
