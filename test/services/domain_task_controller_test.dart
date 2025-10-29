import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart'
    show AppDb, TaskPriority, TaskStatus;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _MockNotesRepository extends Mock implements INotesRepository {}

class _MockLogger extends Mock implements AppLogger {}

class _MockAppDb extends Mock implements AppDb {}

class _MockTaskReminderBridge extends Mock implements TaskReminderBridge {}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, domain.Task> _tasks = <String, domain.Task>{};

  void seedTask(domain.Task task) {
    _tasks[task.id] = task;
  }

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async =>
      _tasks.values.where((task) => task.noteId == noteId).toList();

  @override
  Future<List<domain.Task>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<List<domain.Task>> getPendingTasks() async =>
      _tasks.values
          .where((task) => task.status == domain.TaskStatus.pending)
          .toList();

  @override
  Future<domain.Task?> getTaskById(String id) async => _tasks[id];

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
  Future<void> deleteTask(String id) async => _tasks.remove(id);

  @override
  Future<void> completeTask(String id) async {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(status: domain.TaskStatus.completed);
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() => Stream.value(_tasks.values.toList());

  @override
  Stream<List<domain.Task>> watchAllTasks() => watchTasks();

  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) =>
      Stream.value(_tasks.values
          .where((task) => task.noteId == noteId)
          .toList());

  @override
  Future<List<domain.Task>> searchTasks(String query) async =>
      _tasks.values
          .where((task) =>
              task.title.toLowerCase().contains(query.toLowerCase()))
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
  Future<void> updateTaskPriority(String id, domain.TaskPriority priority) async {
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
  Future<List<domain.Task>> getCompletedTasks({int? limit, DateTime? since}) async =>
      _tasks.values
          .where((task) => task.status == domain.TaskStatus.completed)
          .toList();

  @override
  Future<List<domain.Task>> getOverdueTasks() async => const <domain.Task>[];

  @override
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) async =>
      _tasks.values
          .where((task) =>
              task.dueDate != null &&
              task.dueDate!.isAfter(start) &&
              task.dueDate!.isBefore(end))
          .toList();

  @override
  Future<void> deleteTasksForNote(String noteId) async {
    _tasks.removeWhere((key, value) => value.noteId == noteId);
  }

  @override
  Future<Map<String, int>> getTaskStatistics() async => const <String, int>{};

  @override
  Future<List<domain.Task>> getTasksByPriority(domain.TaskPriority priority) async =>
      _tasks.values.where((task) => task.priority == priority).toList();

  @override
  Future<void> addTagToTask(String taskId, String tag) async {}

  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {}

  @override
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) async {}

  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async =>
      const <domain.Task>[];
}

class _RecordingEnhancedTaskService extends EnhancedTaskService {
  _RecordingEnhancedTaskService(
    AppDb database,
    ITaskRepository taskRepository,
    TaskReminderBridge reminderBridge,
  ) : super(
          database: database,
          taskRepository: taskRepository,
          reminderBridge: reminderBridge,
        );

  String nextCreateTaskId = 'task-id';
  Map<String, dynamic>? lastCreateArgs;
  Map<String, dynamic>? lastUpdateArgs;
  Map<String, dynamic>? lastCustomReminderArgs;
  String? lastClearedTaskId;
  final List<String> refreshReminderCalls = <String>[];

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
    lastCreateArgs = {
      'noteId': noteId,
      'content': content,
      'status': status,
      'priority': priority,
      'dueDate': dueDate,
      'parentTaskId': parentTaskId,
      'labels': labels,
      'notes': notes,
      'estimatedMinutes': estimatedMinutes,
      'position': position,
      'createReminder': createReminder,
    };
    return nextCreateTaskId;
  }

  @override
  Future<void> updateTask({
    required String taskId,
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
    int? actualMinutes,
    int? reminderId,
    String? parentTaskId,
    bool updateReminder = true,
    bool clearReminderId = false,
  }) async {
    lastUpdateArgs = {
      'taskId': taskId,
      'content': content,
      'status': status,
      'priority': priority,
      'dueDate': dueDate,
      'labels': labels,
      'notes': notes,
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'reminderId': reminderId,
      'parentTaskId': parentTaskId,
      'updateReminder': updateReminder,
      'clearReminderId': clearReminderId,
    };
  }

  @override
  Future<void> setCustomTaskReminder({
    required String taskId,
    required DateTime dueDate,
    required DateTime reminderTime,
  }) async {
    lastCustomReminderArgs = {
      'taskId': taskId,
      'dueDate': dueDate,
      'reminderTime': reminderTime,
    };
  }

  @override
  Future<void> clearTaskReminder(String taskId) async {
    lastClearedTaskId = taskId;
  }

  @override
  Future<void> refreshDefaultTaskReminder(String taskId) async {
    refreshReminderCalls.add(taskId);
  }
}

domain.Task _task({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  DateTime? dueDate,
  Map<String, dynamic> metadata = const {},
}) {
  return domain.Task(
    id: id,
    noteId: 'note-1',
    title: 'Initial Task',
    description: 'details',
    status: domain.TaskStatus.pending,
    priority: domain.TaskPriority.medium,
    dueDate: dueDate,
    completedAt: null,
    createdAt: createdAt,
    updatedAt: updatedAt,
    tags: const <String>[],
    metadata: metadata,
  );
}

void main() {
  group('DomainTaskController reminders', () {
    late _FakeTaskRepository taskRepository;
    late _MockNotesRepository mockNotesRepository;
    late _MockLogger mockLogger;
    late _RecordingEnhancedTaskService enhancedService;
    late DomainTaskController controller;

    final now = DateTime.utc(2025, 10, 18, 12);

    setUp(() {
      taskRepository = _FakeTaskRepository();
      mockNotesRepository = _MockNotesRepository();
      mockLogger = _MockLogger();
      enhancedService = _RecordingEnhancedTaskService(
        _MockAppDb(),
        taskRepository,
        _MockTaskReminderBridge(),
      );

      controller = DomainTaskController(
        taskRepository: taskRepository,
        notesRepository: mockNotesRepository,
        enhancedTaskService: enhancedService,
        logger: mockLogger,
      );
    });

    test('createTask schedules custom reminder when reminderTime supplied', () async {
      final dueDate = now.add(const Duration(days: 1));
      final reminderTime = dueDate.subtract(const Duration(hours: 2));
      const taskId = 'task-123';
      enhancedService.nextCreateTaskId = taskId;

      final createdTask = _task(
        id: taskId,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
      );
      taskRepository.seedTask(createdTask);

      final task = await controller.createTask(
        noteId: 'note-1',
        title: 'Plan sprint',
        dueDate: dueDate,
        reminderTime: reminderTime,
        createReminder: true,
        tags: const ['focus'],
      );

      expect(task.id, taskId);

      final createArgs = enhancedService.lastCreateArgs;
      expect(createArgs, isNotNull);
      expect(createArgs!['noteId'], 'note-1');
      expect(createArgs['content'], 'Plan sprint');
      expect(createArgs['status'], TaskStatus.open);
      expect(createArgs['createReminder'], isFalse);
      final labels = createArgs['labels'] as Map<String, dynamic>?;
      expect(labels, isNotNull);
      expect(labels!['labels'], equals(['focus']));

      final reminderArgs = enhancedService.lastCustomReminderArgs;
      expect(reminderArgs, isNotNull);
      expect(reminderArgs!['taskId'], taskId);
      expect(reminderArgs['dueDate'], dueDate);
      expect(reminderArgs['reminderTime'], reminderTime);
      expect(enhancedService.lastClearedTaskId, isNull);
    });

    test('updateTask clears reminder when hasReminder is false', () async {
      const taskId = 'task-456';
      final dueDate = now.add(const Duration(days: 2));
      final existingTask = _task(
        id: taskId,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        metadata: const {
          'reminderId': 42,
          'estimatedMinutes': 15,
          'actualMinutes': 5,
        },
      );
      taskRepository.seedTask(existingTask);

      await controller.updateTask(
        existingTask,
        hasReminder: false,
      );

      final updateArgs = enhancedService.lastUpdateArgs;
      expect(updateArgs, isNotNull);
      expect(updateArgs!['taskId'], taskId);
      expect(updateArgs['clearReminderId'], isTrue);
      expect(updateArgs['updateReminder'], isFalse);
      expect(enhancedService.lastClearedTaskId, taskId);
      expect(enhancedService.lastCustomReminderArgs, isNull);
      expect(enhancedService.refreshReminderCalls, isEmpty);
    });

    test('updateTask sets custom reminder when reminderTime provided', () async {
      const taskId = 'task-789';
      final dueDate = now.add(const Duration(days: 4));
      final reminderTime = dueDate.subtract(const Duration(hours: 3));
      final existingTask = _task(
        id: taskId,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        metadata: const {
          'estimatedMinutes': 10,
          'actualMinutes': 2,
        },
      );
      taskRepository.seedTask(existingTask);

      await controller.updateTask(
        existingTask,
        hasReminder: true,
        reminderTime: reminderTime,
      );

      final updateArgs = enhancedService.lastUpdateArgs;
      expect(updateArgs, isNotNull);
      expect(updateArgs!['taskId'], taskId);
      expect(updateArgs['clearReminderId'], isFalse);
      expect(updateArgs['updateReminder'], isFalse);

      final customReminderArgs = enhancedService.lastCustomReminderArgs;
      expect(customReminderArgs, isNotNull);
      expect(customReminderArgs!['taskId'], taskId);
      expect(customReminderArgs['dueDate'], dueDate);
      expect(customReminderArgs['reminderTime'], reminderTime);
      expect(enhancedService.lastClearedTaskId, isNull);
      expect(enhancedService.refreshReminderCalls, isEmpty);
    });
  });
}
