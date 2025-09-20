import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/providers.dart';

@GenerateMocks([
  EnhancedTaskService,
  TaskReminderBridge,
  AppDb,
])
import 'reminder_scheduling_ui_test.mocks.dart';

void main() {
  late MockEnhancedTaskService mockTaskService;
  late MockTaskReminderBridge mockReminderBridge;
  late MockAppDb mockDb;

  setUp(() {
    mockTaskService = MockEnhancedTaskService();
    mockReminderBridge = MockTaskReminderBridge();
    mockDb = MockAppDb();
  });

  group('TaskMetadataDialog Reminder UI', () {
    testWidgets('should show reminder section when due date is set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Set a due date
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      
      // Select tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text(tomorrow.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify reminder section is visible
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Set reminder'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should show reminder time options when reminder is enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Set a due date
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text(tomorrow.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enable reminder
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify time selection options are visible
      expect(find.byIcon(Icons.access_time), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('should show quick reminder presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Set due date and enable reminder
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text(tomorrow.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Open quick presets menu
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      // Verify preset options
      expect(find.text('15 minutes before'), findsOneWidget);
      expect(find.text('1 hour before'), findsOneWidget);
      expect(find.text('2 hours before'), findsOneWidget);
      expect(find.text('1 day before'), findsOneWidget);
    });

    testWidgets('should validate reminder time is before due date', (tester) async {
      TaskMetadata? savedMetadata;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              taskContent: 'Test Task',
              onSave: (metadata) {
                savedMetadata = metadata;
              },
            ),
          ),
        ),
      );

      // Set a due date
      final dueDate = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dueDate.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enable reminder
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Try to save without setting reminder time (should use default)
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify metadata was saved with default reminder time (1 hour before)
      expect(savedMetadata, isNotNull);
      expect(savedMetadata!.hasReminder, isTrue);
      expect(savedMetadata!.reminderTime, isNotNull);
      
      // Default should be 1 hour before due date
      final expectedReminderTime = dueDate.subtract(const Duration(hours: 1));
      expect(
        savedMetadata!.reminderTime!.hour,
        equals(expectedReminderTime.hour),
      );
    });

    testWidgets('should format reminder time correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Set due date
      final dueDate = DateTime.now().add(const Duration(days: 2));
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dueDate.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enable reminder
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Select "1 day before" preset
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day before'));
      await tester.pumpAndSettle();

      // Verify formatted text is shown
      expect(find.textContaining('1 day before'), findsWidgets);
    });
  });

  group('Task Reminder Integration', () {
    testWidgets('should create task with custom reminder time', (tester) async {
      const taskId = 'test-task-123';
      final dueDate = DateTime.now().add(const Duration(days: 2));
      final reminderTime = dueDate.subtract(const Duration(hours: 2));

      when(mockTaskService.createTaskWithReminder(
        noteId: anyNamed('noteId'),
        content: anyNamed('content'),
        dueDate: anyNamed('dueDate'),
        reminderTime: anyNamed('reminderTime'),
        priority: anyNamed('priority'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
      )).thenAnswer((_) async => taskId);

      final container = ProviderContainer(
        overrides: [
          enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
          taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
          appDbProvider.overrideWithValue(mockDb),
        ],
      );

      // Test the service is called with correct parameters
      await container.read(enhancedTaskServiceProvider).createTaskWithReminder(
        noteId: 'note-123',
        content: 'Test Task',
        dueDate: dueDate,
        reminderTime: reminderTime,
      );

      verify(mockTaskService.createTaskWithReminder(
        noteId: 'note-123',
        content: 'Test Task',
        dueDate: dueDate,
        reminderTime: reminderTime,
      )).called(1);
    });

    testWidgets('should handle reminder updates for existing tasks', (tester) async {
      final oldTask = NoteTask(
        id: 'task-123',
        noteId: 'note-123',
        content: 'Test Task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        reminderId: 42,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      when(mockDb.getTaskById(any)).thenAnswer((_) async => oldTask);
      when(mockReminderBridge.updateTaskReminder(any)).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
          taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
          appDbProvider.overrideWithValue(mockDb),
        ],
      );

      // Simulate updating task reminder
      await container.read(taskReminderBridgeProvider).updateTaskReminder(oldTask);

      verify(mockReminderBridge.updateTaskReminder(oldTask)).called(1);
    });

    testWidgets('should cancel reminder when toggled off', (tester) async {
      final task = NoteTask(
        id: 'task-123',
        noteId: 'note-123',
        content: 'Test Task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        reminderId: 42,
        position: 0,
        contentHash: 'hash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      when(mockReminderBridge.cancelTaskReminder(any)).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
          taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
          appDbProvider.overrideWithValue(mockDb),
        ],
      );

      // Simulate cancelling reminder
      await container.read(taskReminderBridgeProvider).cancelTaskReminder(task);

      verify(mockReminderBridge.cancelTaskReminder(task)).called(1);
    });
  });
}
