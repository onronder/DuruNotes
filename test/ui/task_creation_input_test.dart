import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/ui/dialogs/task_metadata_dialog.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/data/local/app_db.dart'
    show TaskStatus, TaskPriority;

/// Fake task repository for testing (no mocking library needed)
class _FakeTaskRepository implements ITaskRepository {
  final Map<String, domain.Task> _tasks = {};

  void seedTask(domain.Task task) {
    _tasks[task.id] = task;
  }

  @override
  Future<domain.Task> createTask(domain.Task task) async {
    _tasks[task.id] = task;
    return task;
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    _tasks[task.id] = task;
    return task;
  }

  @override
  Future<List<domain.Task>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<domain.Task?> getTaskById(String id) async => _tasks[id];

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async =>
      _tasks.values.where((t) => t.noteId == noteId).toList();

  @override
  Future<List<domain.Task>> getPendingTasks() async => _tasks.values
      .where((t) => t.status != domain.TaskStatus.completed)
      .toList();

  @override
  Future<void> deleteTask(String id) async => _tasks.remove(id);

  @override
  Future<void> completeTask(String id) async {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(status: domain.TaskStatus.completed);
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() =>
      Stream.value(_tasks.values.toList());

  @override
  Stream<List<domain.Task>> watchAllTasks() => watchTasks();

  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) =>
      Stream.value(_tasks.values.where((t) => t.noteId == noteId).toList());

  @override
  Future<List<domain.Task>> searchTasks(String query) async => _tasks.values
      .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
      .toList();

  @override
  Future<void> toggleTaskStatus(String id) async {
    final task = _tasks[id];
    if (task != null) {
      final newStatus = task.status == domain.TaskStatus.completed
          ? domain.TaskStatus.pending
          : domain.TaskStatus.completed;
      _tasks[id] = task.copyWith(status: newStatus);
    }
  }

  @override
  Future<void> updateTaskPriority(
    String id,
    domain.TaskPriority priority,
  ) async {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(priority: priority);
    }
  }

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(dueDate: dueDate);
    }
  }

  @override
  Future<List<domain.Task>> getCompletedTasks({
    int? limit,
    DateTime? since,
  }) async {
    final completed = _tasks.values.where(
      (t) => t.status == domain.TaskStatus.completed,
    );
    if (limit != null) {
      return completed.take(limit).toList();
    }
    return completed.toList();
  }

  @override
  Future<List<domain.Task>> getOverdueTasks() async => const [];

  @override
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) async => _tasks.values
      .where(
        (t) =>
            t.dueDate != null &&
            !t.dueDate!.isBefore(start) &&
            !t.dueDate!.isAfter(end),
      )
      .toList();

  @override
  Future<void> deleteTasksForNote(String noteId) async {
    _tasks.removeWhere((key, value) => value.noteId == noteId);
  }

  @override
  Future<Map<String, int>> getTaskStatistics() async => const {};

  @override
  Future<List<domain.Task>> getTasksByPriority(
    domain.TaskPriority priority,
  ) async => _tasks.values.where((t) => t.priority == priority).toList();

  @override
  Future<void> addTagToTask(String taskId, String tag) async {}

  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {}

  @override
  Future<void> syncTasksWithNoteContent(
    String noteId,
    String noteContent,
  ) async {}

  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) async => throw UnimplementedError();

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async => const [];

  @override
  Future<void> updateTaskReminderLink({
    required String taskId,
    required String? reminderId,
  }) async {}

  @override
  Future<void> updateTaskPositions(Map<String, int> positions) async {}

  @override
  Future<List<domain.Task>> getDeletedTasks() async => const [];

  @override
  Future<void> restoreTask(String id) async {}

  @override
  Future<void> permanentlyDeleteTask(String id) async {}
}

/// Mock notes repository (minimal implementation)
class _MockNotesRepository implements INotesRepository {
  @override
  Future<Note?> getNoteById(String id) async => null;

  @override
  Future<Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    // Return a minimal note for testing
    return Note(
      id: id ?? 'test-note',
      title: title,
      body: body,
      folderId: folderId,
      isPinned: isPinned ?? false,
      version: 1,
      tags: tags,
      links: [],
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      userId: 'test-user',
      deleted: false,
      noteType: NoteKind.note,
    );
  }

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> permanentlyDeleteNote(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub enhanced task service for testing
class _StubEnhancedTaskService implements EnhancedTaskService {
  String nextTaskId = 'task-123';
  String? lastCreatedContent;
  TaskPriority? lastCreatedPriority;
  DateTime? lastCreatedDueDate;

  @override
  Future<String> createTask({
    required String noteId,
    required String content,
    TaskStatus status = TaskStatus.open,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
    int? position,
    bool createReminder = true,
  }) async {
    lastCreatedContent = content;
    lastCreatedPriority = priority;
    lastCreatedDueDate = dueDate;
    return nextTaskId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub logger for testing
class _StubLogger implements AppLogger {
  const _StubLogger();

  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}

  @override
  void debug(String message, {Map<String, dynamic>? data}) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> flush() async {}

  @override
  void info(String message, {Map<String, dynamic>? data}) {}

  @override
  void warn(String message, {Map<String, dynamic>? data}) {}

  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Creation with User Input', () {
    late _FakeTaskRepository taskRepository;
    late _StubEnhancedTaskService enhancedService;
    late DomainTaskController controller;
    late ProviderContainer container;

    setUp(() {
      taskRepository = _FakeTaskRepository();
      enhancedService = _StubEnhancedTaskService();
      controller = DomainTaskController(
        taskRepository: taskRepository,
        notesRepository: _MockNotesRepository(),
        enhancedTaskService: enhancedService,
        logger: const _StubLogger(),
      );

      container = ProviderContainer(
        overrides: [domainTaskControllerProvider.overrideWithValue(controller)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should use user input for task title', (tester) async {
      const userInput = 'Buy groceries for dinner';
      const taskId = 'task-123';
      enhancedService.nextTaskId = taskId;

      // Create the task that will be returned by repository
      final now = DateTime.now();
      final createdTask = domain.Task(
        id: taskId,
        noteId: DomainTaskController.standaloneNoteId,
        title: userInput,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
      taskRepository.seedTask(createdTask);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<TaskMetadata>(
                      context: context,
                      builder: (context) => TaskMetadataDialog(
                        taskContent: '',
                        isNewTask: true,
                        onSave: (metadata) async {
                          Navigator.of(context).pop(metadata);
                        },
                      ),
                    );

                    if (result != null) {
                      await controller.createTask(
                        title: result.taskContent,
                        priority: result.priority,
                        dueDate: result.dueDate,
                        tags: result.labels,
                        createReminder: result.hasReminder,
                        reminderTime: result.reminderTime,
                      );
                    }
                  },
                  child: const Text('Create Task'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Enter task title (first TextField is the task content field with autofocus)
      await tester.enterText(find.byType(TextField).first, userInput);
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Verify task was created with user's input
      expect(enhancedService.lastCreatedContent, userInput);
      final tasks = await taskRepository.getAllTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, userInput);
    });

    testWidgets('should show validation error for empty title', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to save without entering title
      // Button should be disabled when content is empty
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(
        createButton.onPressed,
        isNull,
        reason: 'Create button should be disabled when title is empty',
      );
    });

    testWidgets('should auto-focus on task title field for new tasks', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the first text field has autofocus enabled
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.autofocus, isTrue);
    });

    testWidgets('should show different labels for new vs edit', (tester) async {
      // Test new task
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: '',
                isNewTask: true,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Enter task description...'), findsOneWidget);

      // Test edit task
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TaskMetadataDialog(
                taskContent: 'Existing Task',
                isNewTask: false,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.text('Task description'), findsOneWidget);
    });

    testWidgets('should handle long task titles', (tester) async {
      const longTitle =
          'This is a very long task title that should be handled properly '
          'by the system without any issues or truncation in the creation process';
      const taskId = 'task-long';
      enhancedService.nextTaskId = taskId;

      final now = DateTime.now();
      final createdTask = domain.Task(
        id: taskId,
        noteId: DomainTaskController.standaloneNoteId,
        title: longTitle,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
      taskRepository.seedTask(createdTask);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<TaskMetadata>(
                      context: context,
                      builder: (context) => TaskMetadataDialog(
                        taskContent: '',
                        isNewTask: true,
                        onSave: (metadata) async {
                          Navigator.of(context).pop(metadata);
                        },
                      ),
                    );

                    if (result != null) {
                      await controller.createTask(
                        title: result.taskContent,
                        priority: result.priority,
                        dueDate: result.dueDate,
                        tags: result.labels,
                        createReminder: result.hasReminder,
                      );
                    }
                  },
                  child: const Text('Create Task'),
                ),
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
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Verify task was created with full title
      expect(enhancedService.lastCreatedContent, longTitle);
      final tasks = await taskRepository.getAllTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, longTitle);
    });

    testWidgets('should trim whitespace from task title', (tester) async {
      const inputWithSpaces = '  Buy milk   ';
      const trimmedInput = 'Buy milk';
      const taskId = 'task-trim';
      enhancedService.nextTaskId = taskId;

      final now = DateTime.now();
      final createdTask = domain.Task(
        id: taskId,
        noteId: DomainTaskController.standaloneNoteId,
        title: trimmedInput,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
      taskRepository.seedTask(createdTask);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<TaskMetadata>(
                      context: context,
                      builder: (context) => TaskMetadataDialog(
                        taskContent: '',
                        isNewTask: true,
                        onSave: (metadata) async {
                          Navigator.of(context).pop(metadata);
                        },
                      ),
                    );

                    if (result != null) {
                      await controller.createTask(
                        title: result.taskContent.trim(),
                        priority: result.priority,
                        dueDate: result.dueDate,
                        tags: result.labels,
                        createReminder: result.hasReminder,
                      );
                    }
                  },
                  child: const Text('Create Task'),
                ),
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
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Verify task was created with trimmed title
      expect(enhancedService.lastCreatedContent, trimmedInput);
    });
  });

  group('Task Creation Success Feedback', () {
    test('should capture task creation parameters', () async {
      final taskRepository = _FakeTaskRepository();
      final enhancedService = _StubEnhancedTaskService();
      final controller = DomainTaskController(
        taskRepository: taskRepository,
        notesRepository: _MockNotesRepository(),
        enhancedTaskService: enhancedService,
        logger: const _StubLogger(),
      );

      const taskTitle = 'Complete project proposal';
      const taskId = 'task-success';
      enhancedService.nextTaskId = taskId;

      final now = DateTime.now();
      final createdTask = domain.Task(
        id: taskId,
        noteId: DomainTaskController.standaloneNoteId,
        title: taskTitle,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
      taskRepository.seedTask(createdTask);

      await controller.createTask(title: taskTitle, createReminder: false);

      // Verify creation parameters were captured
      expect(enhancedService.lastCreatedContent, taskTitle);
      expect(enhancedService.lastCreatedPriority, TaskPriority.medium);
    });
  });
}
