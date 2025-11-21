import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/services/enhanced_task_service.dart' as enhanced;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/data/local/app_db.dart'
    as db
    show TaskStatus, TaskPriority;

class _MockNotesRepository extends Mock implements INotesRepository {}

class _StubEnhancedTaskService extends Mock
    implements enhanced.EnhancedTaskService {
  String? lastNoteId;
  String? lastContent;
  bool? lastCreateReminder;
  DateTime? lastDueDate;
  Future<String> Function()? onCreateTask;

  @override
  Future<String> createTask({
    required String noteId,
    required String content,
    db.TaskStatus status = db.TaskStatus.open,
    db.TaskPriority priority = db.TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
    int? position,
    bool createReminder = true,
  }) {
    lastNoteId = noteId;
    lastContent = content;
    lastCreateReminder = createReminder;
    lastDueDate = dueDate;
    if (onCreateTask != null) {
      return onCreateTask!();
    }
    return Future.value('stub-task');
  }
}

class _InMemoryTaskRepository implements ITaskRepository {
  final Map<String, domain.Task> _tasks = {};
  final StreamController<List<domain.Task>> _allTasksController =
      StreamController<List<domain.Task>>.broadcast();

  void replaceAll(List<domain.Task> tasks) {
    _tasks
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
    _emit();
  }

  void addTask(domain.Task task) {
    _tasks[task.id] = task;
    _emit();
  }

  void _emit() {
    _allTasksController.add(_tasks.values.toList());
  }

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async =>
      _tasks.values.where((t) => t.noteId == noteId).toList();

  @override
  Future<List<domain.Task>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<List<domain.Task>> getPendingTasks() async => _tasks.values
      .where((t) => t.status != domain.TaskStatus.completed)
      .toList();

  @override
  Future<domain.Task?> getTaskById(String id) async => _tasks[id];

  @override
  Future<domain.Task> createTask(domain.Task task) async {
    addTask(task);
    return task;
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    _tasks[task.id] = task;
    _emit();
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
    _emit();
  }

  @override
  Future<void> completeTask(String id) async {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(status: domain.TaskStatus.completed);
      _emit();
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() => _allTasksController.stream;

  @override
  Stream<List<domain.Task>> watchAllTasks() => _allTasksController.stream;

  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) =>
      _allTasksController.stream.map(
        (tasks) => tasks.where((t) => t.noteId == noteId).toList(),
      );

  @override
  Future<List<domain.Task>> searchTasks(String query) async =>
      _tasks.values.where((t) => t.title.contains(query)).toList();

  @override
  Future<void> toggleTaskStatus(String id) async {
    final task = _tasks[id];
    if (task == null) return;
    final newStatus = task.status == domain.TaskStatus.completed
        ? domain.TaskStatus.pending
        : domain.TaskStatus.completed;
    _tasks[id] = task.copyWith(status: newStatus);
    _emit();
  }

  @override
  Future<void> updateTaskPriority(
    String id,
    domain.TaskPriority priority,
  ) async {
    final task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(priority: priority);
    _emit();
  }

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    final task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(dueDate: dueDate);
    _emit();
  }

  @override
  Future<List<domain.Task>> getCompletedTasks({
    int? limit,
    DateTime? since,
  }) async {
    final tasks = _tasks.values.where(
      (t) => t.status == domain.TaskStatus.completed,
    );
    if (limit != null) {
      return tasks.take(limit).toList();
    }
    return tasks.toList();
  }

  @override
  Future<List<domain.Task>> getOverdueTasks() async {
    final now = DateTime.now();
    return _tasks.values
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(now))
        .toList();
  }

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
    _emit();
  }

  @override
  Future<Map<String, int>> getTaskStatistics() async => {
    'total': _tasks.length,
    'completed': _tasks.values
        .where((t) => t.status == domain.TaskStatus.completed)
        .length,
  };

  @override
  Future<List<domain.Task>> getTasksByPriority(
    domain.TaskPriority priority,
  ) async => _tasks.values.where((t) => t.priority == priority).toList();

  @override
  Future<void> addTagToTask(String taskId, String tag) async {
    final task = _tasks[taskId];
    if (task == null) return;
    final updatedTags = {...task.tags, tag}.toList();
    _tasks[taskId] = task.copyWith(tags: updatedTags);
    _emit();
  }

  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {
    final task = _tasks[taskId];
    if (task == null) return;
    final updatedTags = task.tags.where((t) => t != tag).toList();
    _tasks[taskId] = task.copyWith(tags: updatedTags);
    _emit();
  }

  @override
  Future<void> syncTasksWithNoteContent(
    String noteId,
    String noteContent,
  ) async {}

  @override
  Future<void> updateTaskReminderLink({
    required String taskId,
    required String? reminderId,
  }) async {}

  @override
  Future<void> updateTaskPositions(Map<String, int> positions) async {}

  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) async {
    final id = 'subtask-${_tasks.length + 1}';
    final now = DateTime.now();
    final subtask = domain.Task(
      id: id,
      noteId: parentTaskId,
      title: title,
      description: description,
      status: domain.TaskStatus.pending,
      priority: domain.TaskPriority.medium,
      dueDate: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      tags: const [],
      metadata: const {'parentTaskId': true},
    );
    addTask(subtask);
    return subtask;
  }

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async => _tasks
      .values
      .where(
        (t) => t.metadata['parentTaskId'] == true && t.noteId == parentTaskId,
      )
      .toList();

  @override
  Future<List<domain.Task>> getDeletedTasks() async => const [];

  @override
  Future<void> restoreTask(String id) async {}

  @override
  Future<void> permanentlyDeleteTask(String id) async {}

  @override
  Future<int> anonymizeAllTasksForUser(String userId) async => 0;
}

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

domain.Task _makeTask({required String id, required domain.TaskStatus status}) {
  final now = DateTime.now();
  return domain.Task(
    id: id,
    noteId: 'note-123',
    title: 'Task $id',
    description: null,
    status: status,
    priority: domain.TaskPriority.medium,
    dueDate: null,
    completedAt: status == domain.TaskStatus.completed ? now : null,
    createdAt: now.subtract(const Duration(hours: 1)),
    updatedAt: now,
    tags: const [],
    metadata: const {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Sync System Integrity', () {
    test(
      'DomainTaskController delegates creation to EnhancedTaskService',
      () async {
        final taskRepository = _InMemoryTaskRepository();
        final notesRepository = _MockNotesRepository();
        final enhancedService = _StubEnhancedTaskService();

        final controller = DomainTaskController(
          taskRepository: taskRepository,
          notesRepository: notesRepository,
          enhancedTaskService: enhancedService,
          logger: const _StubLogger(),
        );

        const createdTaskId = 'task-001';
        final task = _makeTask(
          id: createdTaskId,
          status: domain.TaskStatus.pending,
        );

        final dueDate = DateTime(2025, 1, 1);

        enhancedService.onCreateTask = () async {
          taskRepository.addTask(task);
          return createdTaskId;
        };

        final result = await controller.createTask(
          noteId: 'note-123',
          title: 'Write tests',
          dueDate: dueDate,
          createReminder: true,
        );

        expect(result, task);
        expect(await taskRepository.getTaskById(createdTaskId), task);
        expect(enhancedService.lastNoteId, 'note-123');
        expect(enhancedService.lastContent, 'Write tests');
        expect(enhancedService.lastCreateReminder, isTrue);
        expect(enhancedService.lastDueDate, dueDate);
      },
    );

    test(
      'DomainTaskController stream filtering excludes completed tasks',
      () async {
        final taskRepository = _InMemoryTaskRepository();
        final notesRepository = _MockNotesRepository();
        final enhancedService = _StubEnhancedTaskService();

        final controller = DomainTaskController(
          taskRepository: taskRepository,
          notesRepository: notesRepository,
          enhancedTaskService: enhancedService,
          logger: const _StubLogger(),
        );

        final pendingTask = _makeTask(
          id: 'pending',
          status: domain.TaskStatus.pending,
        );
        final completedTask = _makeTask(
          id: 'done',
          status: domain.TaskStatus.completed,
        );

        final tasksFuture = controller
            .watchAllTasks(includeCompleted: false)
            .first;
        taskRepository.replaceAll([pendingTask, completedTask]);
        final tasks = await tasksFuture;
        expect(tasks, [pendingTask]);

        final allTasksFuture = controller
            .watchAllTasks(includeCompleted: true)
            .first;
        taskRepository.replaceAll([pendingTask, completedTask]);
        final allTasks = await allTasksFuture;
        expect(allTasks, containsAll([pendingTask, completedTask]));
      },
    );

    test('TaskSyncMetrics records successful sync completion', () {
      final metrics = TaskSyncMetrics.instance;

      final before = metrics.getHealthMetrics();
      final initialSuccesses = (before['successCount'] as int?) ?? 0;

      final syncId = metrics.startSync(
        noteId: 'note-321',
        syncType: 'domain-task-sync',
      );

      metrics.endSync(syncId: syncId, success: true, taskCount: 3);

      final after = metrics.getHealthMetrics();
      final finalSuccesses = (after['successCount'] as int?) ?? 0;
      expect(finalSuccesses, initialSuccesses + 1);

      final performance = metrics.getPerformanceStats();
      expect(performance['sampleCount'], greaterThan(0));
    });
  });
}
