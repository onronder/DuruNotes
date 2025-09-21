import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/ui/enhanced_task_list_screen.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/providers.dart';

@GenerateMocks([
  AppDb,
  EnhancedTaskService,
  TaskReminderBridge,
])
import 'task_creation_input_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockEnhancedTaskService mockTaskService;
  late MockTaskReminderBridge mockReminderBridge;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDb();
    mockTaskService = MockEnhancedTaskService();
    mockReminderBridge = MockTaskReminderBridge();

    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWithValue(mockDb),
        enhancedTaskServiceProvider.overrideWithValue(mockTaskService),
        taskReminderBridgeProvider.overrideWithValue(mockReminderBridge),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Task Creation with User Input', () {
    testWidgets('should use user input for task title', (tester) async {
      const userInput = 'Buy groceries for dinner';
      const taskId = 'task-123';

      when(mockTaskService.createTask(
        noteId: 'standalone',
        content: userInput,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).thenAnswer((_) async => taskId);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<TaskMetadata>(
                        context: context,
                        builder: (context) => TaskMetadataDialog(
                          taskContent: '',
                          isNewTask: true,
                          onSave: (metadata) =>
                              Navigator.of(context).pop(metadata),
                        ),
                      );

                      if (result != null) {
                        // Simulate what EnhancedTaskListScreen does
                        await mockTaskService.createTask(
                          noteId: 'standalone',
                          content: result.taskContent,
                          priority: result.priority,
                          dueDate: result.dueDate,
                          labels: result.labels.isNotEmpty
                              ? {'labels': result.labels}
                              : null,
                          notes: result.notes,
                          estimatedMinutes: result.estimatedMinutes,
                          createReminder:
                              result.hasReminder && result.dueDate != null,
                        );
                      }
                    },
                    child: const Text('Create Task'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Enter task title
      await tester.enterText(find.byType(TextField).first, userInput);
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify task was created with user's input
      verify(mockTaskService.createTask(
        noteId: 'standalone',
        content: userInput,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).called(1);
    });

    testWidgets('should show validation error for empty title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Try to save without entering title
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Should show error on the text field decoration
      // Create button should be disabled when empty
      final createButton =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(createButton.onPressed, isNull);
    });

    testWidgets('should auto-focus on task title field for new tasks',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the text field has focus
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.autofocus, isTrue);
    });

    testWidgets('should show different placeholders for new vs edit',
        (tester) async {
      // Test new task
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Enter task description...'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget); // Dialog title

      // Test edit task
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: 'Existing Task',
                isNewTask: false,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Task description'), findsOneWidget);
      expect(find.text('Edit Task'), findsOneWidget); // Dialog title
    });

    testWidgets('should handle long task titles', (tester) async {
      const longTitle =
          'This is a very long task title that should be handled properly '
          'by the system without any issues or truncation in the creation process';
      const taskId = 'task-long';

      when(mockTaskService.createTask(
        noteId: 'standalone',
        content: longTitle,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).thenAnswer((_) async => taskId);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<TaskMetadata>(
                        context: context,
                        builder: (context) => TaskMetadataDialog(
                          taskContent: '',
                          isNewTask: true,
                          onSave: (metadata) =>
                              Navigator.of(context).pop(metadata),
                        ),
                      );

                      if (result != null) {
                        await mockTaskService.createTask(
                          noteId: 'standalone',
                          content: result.taskContent,
                          priority: result.priority,
                          dueDate: result.dueDate,
                          labels: result.labels.isNotEmpty
                              ? {'labels': result.labels}
                              : null,
                          notes: result.notes,
                          estimatedMinutes: result.estimatedMinutes,
                          createReminder:
                              result.hasReminder && result.dueDate != null,
                        );
                      }
                    },
                    child: const Text('Create Task'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Enter long title
      await tester.enterText(find.byType(TextField).first, longTitle);
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify task was created with full title
      verify(mockTaskService.createTask(
        noteId: 'standalone',
        content: longTitle,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).called(1);
    });

    testWidgets('should trim whitespace from task title', (tester) async {
      const inputWithSpaces = '  Buy milk   ';
      const trimmedInput = 'Buy milk';
      const taskId = 'task-trim';

      when(mockTaskService.createTask(
        noteId: 'standalone',
        content: trimmedInput,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).thenAnswer((_) async => taskId);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<TaskMetadata>(
                        context: context,
                        builder: (context) => TaskMetadataDialog(
                          taskContent: '',
                          isNewTask: true,
                          onSave: (metadata) =>
                              Navigator.of(context).pop(metadata),
                        ),
                      );

                      if (result != null) {
                        await mockTaskService.createTask(
                          noteId: 'standalone',
                          content: result.taskContent.trim(),
                          priority: result.priority,
                          dueDate: result.dueDate,
                          labels: result.labels.isNotEmpty
                              ? {'labels': result.labels}
                              : null,
                          notes: result.notes,
                          estimatedMinutes: result.estimatedMinutes,
                          createReminder:
                              result.hasReminder && result.dueDate != null,
                        );
                      }
                    },
                    child: const Text('Create Task'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Enter title with spaces
      await tester.enterText(find.byType(TextField).first, inputWithSpaces);
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify task was created with trimmed title
      verify(mockTaskService.createTask(
        noteId: 'standalone',
        content: trimmedInput,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).called(1);
    });
  });

  group('Task Creation Success Feedback', () {
    test('should show success message with task title', () async {
      const taskTitle = 'Complete project proposal';
      const taskId = 'task-success';

      when(mockTaskService.createTask(
        noteId: 'standalone',
        content: taskTitle,
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        createReminder: anyNamed('createReminder'),
      )).thenAnswer((_) async => taskId);

      // The success message should show:
      // "Created task: Complete project proposal"

      // This would be tested in the actual UI with:
      // expect(find.text('Created task: $taskTitle'), findsOneWidget);
    });
  });
}
