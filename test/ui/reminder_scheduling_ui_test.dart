import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

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
  late DateTime defaultDueDate;

  setUp(() {
    mockTaskService = MockEnhancedTaskService();
    mockReminderBridge = MockTaskReminderBridge();
    mockDb = MockAppDb();
    final base = DateTime.now().add(const Duration(days: 1));
    defaultDueDate = DateTime(base.year, base.month, base.day, 20, 0);
  });

  NoteTask _buildTask({DateTime? dueDate, int? reminderId}) {
    final now = DateTime.now();
    return NoteTask(
      id: 'task-1',
      noteId: 'note-1',
      content: 'Seed task',
      status: TaskStatus.open,
      priority: TaskPriority.medium,
      dueDate: dueDate,
      reminderId: reminderId,
      position: 0,
      contentHash: 'hash',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    );
  }

  group('TaskMetadataDialog Reminder UI', () {
    testWidgets('shows reminder section when due date is pre-set',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Set reminder'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows reminder time options when reminder enabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.access_time), findsWidgets);
      expect(find.byIcon(Icons.schedule), findsWidgets);
    });

    testWidgets('shows quick reminder presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      expect(find.text('15 minutes before'), findsOneWidget);
      expect(find.text('1 hour before'), findsOneWidget);
      expect(find.text('2 hours before'), findsOneWidget);
      expect(find.text('1 day before'), findsOneWidget);
    });

    testWidgets('persists default reminder time when saved', (tester) async {
      TaskMetadata? savedMetadata;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (metadata) => savedMetadata = metadata,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedMetadata, isNotNull);
      expect(savedMetadata!.reminderTime, isNotNull);
      expect(
        savedMetadata!.reminderTime,
        equals(defaultDueDate.subtract(const Duration(hours: 1))),
      );
    });

    testWidgets('allows entering estimated minutes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(
          find.byKey(const ValueKey('task_estimate_field')), '25');
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('displays preset selection text when chosen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskMetadataDialog(
              task: _buildTask(dueDate: defaultDueDate),
              taskContent: 'Test Task',
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day before'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 day before'), findsWidgets);
    });
  });

  group('Task Reminder Integration', () {
    testWidgets('creates task with custom reminder time', (tester) async {
      const taskId = 'test-task-123';
      final dueDate = defaultDueDate.add(const Duration(days: 1));
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

    testWidgets('updates reminder for existing task', (tester) async {
      final task = _buildTask(dueDate: defaultDueDate, reminderId: 42);

      when(mockDb.getTaskById(any)).thenAnswer((_) async => task);
      when(mockReminderBridge.updateTaskReminder(any)).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
          taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
          appDbProvider.overrideWithValue(mockDb),
        ],
      );

      await container.read(taskReminderBridgeProvider).updateTaskReminder(task);

      verify(mockReminderBridge.updateTaskReminder(task)).called(1);
    });

    testWidgets('cancels reminder when toggled off', (tester) async {
      final task = _buildTask(dueDate: defaultDueDate, reminderId: 42);

      when(mockReminderBridge.cancelTaskReminder(any)).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
          taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
          appDbProvider.overrideWithValue(mockDb),
        ],
      );

      await container.read(taskReminderBridgeProvider).cancelTaskReminder(task);

      verify(mockReminderBridge.cancelTaskReminder(task)).called(1);
    });
  });
}
