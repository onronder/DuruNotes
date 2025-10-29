import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/services/enhanced_task_service.dart' as enhanced;

class _MockNotesRepository extends Mock implements INotesRepository {}

class _StubEnhancedTaskService extends Mock implements enhanced.EnhancedTaskService {
  Future<String> Function()? onCreateTask;
  Future<void> Function(String taskId)? onToggle;
  Future<void> Function(String taskId)? onDelete;

  String? lastNoteId;
  String? lastContent;
  bool? lastCreateReminder;
  DateTime? lastDueDate;
  Map<String, dynamic>? lastCustomReminderArgs;
  String? lastRefreshedReminderTaskId;
  String? lastClearedReminderTaskId;

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
  }) async {
    lastNoteId = noteId;
    lastContent = content;
    lastCreateReminder = createReminder;
    lastDueDate = dueDate;
    if (onCreateTask != null) {
      return onCreateTask!();
    }
    return 'stub-task';
  }

  @override
  Future<void> toggleTaskStatus(String taskId) async {
    if (onToggle != null) {
      await onToggle!(taskId);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    if (onDelete != null) {
      await onDelete!(taskId);
    }
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
  Future<void> refreshDefaultTaskReminder(String taskId) async {
    lastRefreshedReminderTaskId = taskId;
  }

  @override
  Future<void> clearTaskReminder(String taskId) async {
    lastClearedReminderTaskId = taskId;
  }

  @override
  Future<void> updateTask({
    required String taskId,
    String? content,
    db.TaskStatus? status,
    db.TaskPriority? priority,
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
    // Stub implementation - no-op by default
  }
}

class _StubLogger implements AppLogger {
  const _StubLogger();
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}
  @override
  void debug(String message, {Map<String, dynamic>? data}) {}
  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {}
  @override
  Future<void> flush() async {}
  @override
  void info(String message, {Map<String, dynamic>? data}) {}
  @override
  void warn(String message, {Map<String, dynamic>? data}) {}
  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}

class _InMemoryTaskRepository implements ITaskRepository {
  final Map<String, domain.Task> _tasks = {};
  final StreamController<List<domain.Task>> _stream = StreamController<List<domain.Task>>.broadcast();

  void add(domain.Task task) {
    _tasks[task.id] = task;
    _emit();
  }

  void replaceAll(Iterable<domain.Task> tasks) {
    _tasks
      ..clear()
      ..addEntries(tasks.map((t) => MapEntry(t.id, t)));
    _emit();
  }

  void remove(String id) {
    _tasks.remove(id);
    _emit();
  }

  void _emit() {
    _stream.add(_tasks.values.toList(growable: false));
  }

  void dispose() {
    _stream.close();
  }

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async =>
      _tasks.values.where((t) => t.noteId == noteId).toList();

  @override
  Future<List<domain.Task>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<List<domain.Task>> getPendingTasks() async =>
      _tasks.values.where((t) => t.status != domain.TaskStatus.completed).toList();

  @override
  Future<domain.Task?> getTaskById(String id) async => _tasks[id];

  @override
  Future<domain.Task> createTask(domain.Task task) async {
    add(task);
    return task;
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    add(task);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async => remove(id);

  @override
  Future<void> completeTask(String id) async {
    final task = _tasks[id];
    if (task != null) {
      add(task.copyWith(status: domain.TaskStatus.completed));
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() => _stream.stream;

  @override
  Stream<List<domain.Task>> watchAllTasks() => _stream.stream;

  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) =>
      _stream.stream.map((tasks) => tasks.where((t) => t.noteId == noteId).toList());

  @override
  Future<List<domain.Task>> searchTasks(String query) async =>
      _tasks.values.where((t) => t.title.contains(query)).toList();

  @override
  Future<void> toggleTaskStatus(String id) async => completeTask(id);

  @override
  Future<void> updateTaskPriority(String id, domain.TaskPriority priority) async {
    final task = _tasks[id];
    if (task != null) {
      add(task.copyWith(priority: priority));
    }
  }

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    final task = _tasks[id];
    if (task != null) {
      add(task.copyWith(dueDate: dueDate));
    }
  }

  @override
  Future<List<domain.Task>> getCompletedTasks({int? limit, DateTime? since}) async {
    final completed = _tasks.values.where((t) => t.status == domain.TaskStatus.completed);
    if (limit != null) {
      return completed.take(limit).toList();
    }
    return completed.toList();
  }

  @override
  Future<List<domain.Task>> getOverdueTasks() async {
    final now = DateTime.now();
    return _tasks.values
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(now) && t.status != domain.TaskStatus.completed)
        .toList();
  }

  @override
  Future<List<domain.Task>> getTasksByDateRange({required DateTime start, required DateTime end}) async =>
      _tasks.values
          .where((t) => t.dueDate != null && !t.dueDate!.isBefore(start) && !t.dueDate!.isAfter(end))
          .toList();

  @override
  Future<void> deleteTasksForNote(String noteId) async {
    _tasks.removeWhere((key, value) => value.noteId == noteId);
    _emit();
  }

  @override
  Future<Map<String, int>> getTaskStatistics() async => {
        'total': _tasks.length,
        'completed': _tasks.values.where((t) => t.status == domain.TaskStatus.completed).length,
      };

  @override
  Future<List<domain.Task>> getTasksByPriority(domain.TaskPriority priority) async =>
      _tasks.values.where((t) => t.priority == priority).toList();

  @override
  Future<void> addTagToTask(String taskId, String tag) async {
    final task = _tasks[taskId];
    if (task != null && !task.tags.contains(tag)) {
      add(task.copyWith(tags: [...task.tags, tag]));
    }
  }

  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {
    final task = _tasks[taskId];
    if (task != null) {
      add(task.copyWith(tags: task.tags.where((t) => t != tag).toList()));
    }
  }

  @override
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) async {}

  @override
  Future<domain.Task> createSubtask({required String parentTaskId, required String title, String? description}) async {
    final subtaskId = 'sub-$parentTaskId-${_tasks.length + 1}';
    final now = DateTime.now();
    final subtask = domain.Task(
      id: subtaskId,
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
    add(subtask);
    return subtask;
  }

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async =>
      _tasks.values.where((t) => t.metadata['parentTaskId'] == true && t.noteId == parentTaskId).toList();
}

domain.Task _makeTask(String id, domain.TaskStatus status) {
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
    createdAt: now.subtract(const Duration(minutes: 5)),
    updatedAt: now,
    tags: const [],
    metadata: const {},
  );
}

Future<void> _saveTestResults(String testName, Map<String, dynamic> results) async {
  final timestamp = DateTime.now().toIso8601String();
  final reportData = {
    'test_name': testName,
    'timestamp': timestamp,
    'results': results,
  };

  final reportFile = File(
    '/Users/onronder/duru-notes/docs/test_reports/phase3_regression_${testName}_${DateTime.now().millisecondsSinceEpoch}.json',
  );

  await reportFile.parent.create(recursive: true);
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Regression Test Framework', () {
    late _InMemoryTaskRepository taskRepository;
    late _StubEnhancedTaskService enhancedService;
    late DomainTaskController controller;

    setUp(() {
      taskRepository = _InMemoryTaskRepository();
      enhancedService = _StubEnhancedTaskService();
      controller = DomainTaskController(
        taskRepository: taskRepository,
        notesRepository: _MockNotesRepository(),
        enhancedTaskService: enhancedService,
        logger: const _StubLogger(),
      );
      FeatureFlags.instance.clearOverrides();
    });

    tearDown(() {
      taskRepository.dispose();
      FeatureFlags.instance.clearOverrides();
    });

    test('Domain task CRUD operations behave consistently', () async {
      const taskId = 'task-001';
      final task = _makeTask(taskId, domain.TaskStatus.pending);

      enhancedService.onCreateTask = () async {
        taskRepository.add(task);
        return taskId;
      };

      enhancedService.onToggle = (id) async {
        final existing = await taskRepository.getTaskById(id);
        if (existing != null) {
          taskRepository.add(existing.copyWith(status: domain.TaskStatus.completed));
        }
      };

      enhancedService.onDelete = (id) async {
        taskRepository.remove(id);
      };

      final created = await controller.createTask(
        noteId: 'note-123',
        title: 'Regression Task',
        createReminder: false,
      );

      expect(created, task);
      expect(await taskRepository.getTaskById(taskId), isNotNull);
      expect(enhancedService.lastContent, 'Regression Task');

      await controller.toggleStatus(taskId);
      final completed = await taskRepository.getTaskById(taskId);
      expect(completed!.status, domain.TaskStatus.completed);

      await controller.deleteTask(taskId);
      expect(await taskRepository.getTaskById(taskId), isNull);

      await _saveTestResults('task_crud_regression', {
        'createdTask': created.title,
        'completedStatus': completed.status.toString(),
        'finalTaskCount': (await taskRepository.getAllTasks()).length,
      });
    });

    test('Task streams emit updates for domain controller consumers', () async {
      final pending = _makeTask('pending', domain.TaskStatus.pending);
      final completed = _makeTask('completed', domain.TaskStatus.completed);

      final pendingStream = controller.watchAllTasks(includeCompleted: false).first;
      taskRepository.replaceAll([pending, completed]);
      expect(await pendingStream, [pending]);

      final allStream = controller.watchAllTasks(includeCompleted: true).first;
      taskRepository.replaceAll([pending, completed]);
      expect(await allStream, containsAll([pending, completed]));

      await _saveTestResults('task_stream_regression', {
        'pendingOnlyLength': 1,
        'allTasksLength': 2,
      });
    });

    test('Feature flags regression coverage', () async {
      final flags = FeatureFlags.instance;
      flags.setOverride('phase3_regression_flag', true);
      expect(flags.isEnabled('phase3_regression_flag'), isTrue);

      flags.clearOverrides();
      expect(flags.isEnabled('phase3_regression_flag'), isFalse);

      await _saveTestResults('feature_flag_regression', {
        'overrideWorks': true,
        'clearRestoresDefault': true,
      });
    });

    test('TaskSyncMetrics tracks success and failures', () async {
      final metrics = TaskSyncMetrics.instance;

      final before = metrics.getHealthMetrics();
      final startSuccess = (before['successCount'] as int?) ?? 0;
      final startErrors = (before['errorCount'] as int?) ?? 0;

      final successSync = metrics.startSync(noteId: 'regression-note', syncType: 'success-case');
      metrics.endSync(syncId: successSync, success: true, taskCount: 4);

      final failureSync = metrics.startSync(noteId: 'regression-note', syncType: 'failure-case');
      metrics.endSync(syncId: failureSync, success: false, error: 'regression failure');

      final after = metrics.getHealthMetrics();
      final endSuccess = (after['successCount'] as int?) ?? 0;
      final endErrors = (after['errorCount'] as int?) ?? 0;

      expect(endSuccess, startSuccess + 1);
      expect(endErrors, startErrors + 1);

      final performance = metrics.getPerformanceStats();
      expect(performance['sampleCount'], greaterThan(0));

      await _saveTestResults('task_metrics_regression', {
        'successIncrementsBy': endSuccess - startSuccess,
        'errorIncrementsBy': endErrors - startErrors,
        'sampleCount': performance['sampleCount'],
      });
    });

    test('Reminder toggles drive enhanced service interactions', () async {
      final dueDate = DateTime.now().add(const Duration(days: 2));
      final existing = _makeTask('reminder-task', domain.TaskStatus.pending).copyWith(
        dueDate: dueDate,
        metadata: const {
          'reminderId': null,
        },
      );

      taskRepository.replaceAll([existing]);

      final updated = await controller.updateTask(
        existing,
        hasReminder: true,
        dueDate: dueDate,
      );

      expect(updated.metadata['reminderId'], isNull);
      expect(enhancedService.lastRefreshedReminderTaskId, existing.id);

      final withReminder = updated.copyWith(metadata: const {
        'reminderId': 99,
      });
      taskRepository.replaceAll([withReminder]);

      await controller.updateTask(
        withReminder,
        hasReminder: false,
        dueDate: dueDate,
      );

      expect(enhancedService.lastClearedReminderTaskId, withReminder.id);

      await _saveTestResults('reminder_toggle_regression', {
        'refreshedTaskId': enhancedService.lastRefreshedReminderTaskId,
        'clearedTaskId': enhancedService.lastClearedReminderTaskId,
      });
    });
  });
}
