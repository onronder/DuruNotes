import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/services/enhanced_task_service.dart' as enhanced;

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

class _MockNotesRepository extends Mock implements INotesRepository {}

class _StubEnhancedTaskService extends Mock
    implements enhanced.EnhancedTaskService {
  Future<String> Function()? onCreateTask;
  Future<void> Function(String taskId)? onToggle;
  Future<void> Function(String taskId)? onDelete;

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
    if (onCreateTask != null) {
      return onCreateTask!();
    }
    return 'task-${DateTime.now().microsecondsSinceEpoch}';
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
}

class _InMemoryTaskRepository implements ITaskRepository {
  final Map<String, domain.Task> _tasks = {};
  final StreamController<List<domain.Task>> _stream =
      StreamController<List<domain.Task>>.broadcast();

  void add(domain.Task task) {
    _tasks[task.id] = task;
    _emit();
  }

  void addAll(Iterable<domain.Task> tasks) {
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
    _emit();
  }

  void remove(String id) {
    _tasks.remove(id);
    _emit();
  }

  void clear() {
    _tasks.clear();
    _emit();
  }

  void dispose() {
    _stream.close();
  }

  void _emit() => _stream.add(_tasks.values.toList(growable: false));

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
  Stream<List<domain.Task>> watchTasksForNote(String noteId) => _stream.stream
      .map((tasks) => tasks.where((t) => t.noteId == noteId).toList());

  @override
  Future<List<domain.Task>> searchTasks(String query) async =>
      _tasks.values.where((t) => t.title.contains(query)).toList();

  @override
  Future<void> toggleTaskStatus(String id) async => completeTask(id);

  @override
  Future<void> updateTaskPriority(
    String id,
    domain.TaskPriority priority,
  ) async {
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
  Future<List<domain.Task>> getOverdueTasks() async {
    final now = DateTime.now();
    return _tasks.values
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.isBefore(now) &&
              t.status != domain.TaskStatus.completed,
        )
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
}

domain.Task _makeTask(
  String id, {
  domain.TaskStatus status = domain.TaskStatus.pending,
}) {
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
    createdAt: now.subtract(const Duration(minutes: 2)),
    updatedAt: now,
    tags: const [],
    metadata: const {},
  );
}

Future<void> _saveTestResults(String name, Map<String, dynamic> results) async {
  final file = File(
    'docs/test_reports/phase3_performance_${name}_${DateTime.now().millisecondsSinceEpoch}.json',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(
    JsonEncoder.withIndent('  ').convert({
      'test_name': name,
      'timestamp': DateTime.now().toIso8601String(),
      'results': results,
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Performance Monitoring', () {
    late _InMemoryTaskRepository repository;
    late _StubEnhancedTaskService enhancedService;
    late DomainTaskController controller;

    setUp(() {
      repository = _InMemoryTaskRepository();
      enhancedService = _StubEnhancedTaskService();
      controller = DomainTaskController(
        taskRepository: repository,
        notesRepository: _MockNotesRepository(),
        enhancedTaskService: enhancedService,
        logger: const _StubLogger(),
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'Task creation and retrieval stay within expected durations',
      () async {
        enhancedService.onCreateTask = () async {
          final id = 'perf-${DateTime.now().microsecondsSinceEpoch}';
          repository.add(_makeTask(id));
          return id;
        };

        final createStart = DateTime.now();
        final created = await controller.createTask(
          noteId: 'note-123',
          title: 'Performance Task',
        );
        final createDuration = DateTime.now()
            .difference(createStart)
            .inMilliseconds;

        expect(createDuration, lessThan(500));
        expect(created.title, startsWith('Task perf'));

        final retrieveStart = DateTime.now();
        final retrieved = await controller.getTaskById(created.id);
        final retrieveDuration = DateTime.now()
            .difference(retrieveStart)
            .inMilliseconds;

        expect(retrieveDuration, lessThan(200));
        expect(retrieved, isNotNull);

        await _saveTestResults('task_creation_retrieval', {
          'createDurationMs': createDuration,
          'retrieveDurationMs': retrieveDuration,
        });
      },
    );

    test('Concurrent toggles complete within acceptable bounds', () async {
      repository.addAll(List.generate(10, (index) => _makeTask('task-$index')));

      enhancedService.onToggle = (id) async {
        final task = await repository.getTaskById(id);
        if (task != null) {
          repository.add(task.copyWith(status: domain.TaskStatus.completed));
        }
      };

      final start = DateTime.now();
      final tasks = await repository.getAllTasks();
      await Future.wait(tasks.map((task) => controller.toggleStatus(task.id)));
      final duration = DateTime.now().difference(start).inMilliseconds;

      expect(duration, lessThan(1000));
      expect(
        (await repository.getAllTasks()).every(
          (task) => task.status == domain.TaskStatus.completed,
        ),
        isTrue,
      );

      await _saveTestResults('concurrent_toggle', {
        'durationMs': duration,
        'taskCount': (await repository.getAllTasks()).length,
      });
    });

    test('Task list streaming handles rapid updates', () async {
      final events = <int>[];
      final subscription = controller.watchAllTasks().listen((tasks) {
        events.add(tasks.length);
      });

      repository.clear();
      for (var i = 0; i < 20; i++) {
        repository.add(_makeTask('stream-$i'));
      }

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events, isNotEmpty);
      expect(events.last, 20);

      await subscription.cancel();

      await _saveTestResults('task_stream_events', {
        'eventCount': events.length,
        'finalSize': events.last,
      });
    });

    test('TaskSyncMetrics captures performance statistics', () async {
      final metrics = TaskSyncMetrics.instance;
      final before = metrics.getPerformanceStats();

      final syncId = metrics.startSync(
        noteId: 'perf-note',
        syncType: 'performance-test',
      );
      metrics.endSync(syncId: syncId, success: true, taskCount: 5);

      final after = metrics.getPerformanceStats();
      expect(
        after['sampleCount'],
        equals((before['sampleCount'] as int? ?? 0) + 1),
      );

      await _saveTestResults('task_sync_metrics_performance', {
        'before': before,
        'after': after,
      });
    });
  });
}
