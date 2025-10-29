import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository(this.tasks);

  final List<domain.Task> tasks;

  @override
  Future<List<domain.Task>> getAllTasks() async => tasks;

  @override
  Future<domain.Task?> getTaskById(String id) async {
    try {
      return tasks.firstWhere((task) => task.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    return tasks.where((task) => task.noteId == noteId).toList();
  }

  @override
  Future<List<domain.Task>> getPendingTasks() async => tasks
      .where((task) => task.status != domain.TaskStatus.completed)
      .toList();

  @override
  Future<domain.Task> createTask(domain.Task task) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> completeTask(String id) {
    throw UnimplementedError();
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) {
    throw UnimplementedError();
  }

  @override
  Stream<List<domain.Task>> watchAllTasks() {
    throw UnimplementedError();
  }

  @override
  Stream<List<domain.Task>> watchTasks() {
    throw UnimplementedError();
  }

  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> searchTasks(String query) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleTaskStatus(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTaskPriority(String id, domain.TaskPriority priority) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> getCompletedTasks({int? limit, DateTime? since}) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> getOverdueTasks() {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTasksForNote(String noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, int>> getTaskStatistics() {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> getTasksByPriority(domain.TaskPriority priority) {
    throw UnimplementedError();
  }

  @override
  Future<void> addTagToTask(String taskId, String tag) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeTagFromTask(String taskId, String tag) {
    throw UnimplementedError();
  }

  @override
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) {
    throw UnimplementedError();
  }

  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) {
    throw UnimplementedError();
  }
}

void main() {
  group('TaskAnalyticsService - category performance', () {
    late ProviderContainer container;

    setUp(() {
      final start = DateTime(2025, 1, 1, 9);
      final tasks = <domain.Task>[
        domain.Task(
          id: 't1',
          noteId: 'note-1',
          title: 'Finish report',
          description: null,
          status: domain.TaskStatus.completed,
          priority: domain.TaskPriority.high,
          dueDate: start.add(const Duration(hours: 8)),
          completedAt: start.add(const Duration(hours: 5)),
          createdAt: start,
          updatedAt: start.add(const Duration(hours: 5)),
          tags: const ['work'],
          metadata: const {'estimatedMinutes': 360, 'actualMinutes': 300},
        ),
        domain.Task(
          id: 't2',
          noteId: 'note-2',
          title: 'Plan vacation',
          description: null,
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          dueDate: null,
          completedAt: null,
          createdAt: start.add(const Duration(days: 1)),
          updatedAt: start.add(const Duration(days: 1)),
          tags: const ['personal', 'work'],
          metadata: const {'estimatedMinutes': 120, 'actualMinutes': 0},
        ),
      ];

      final repository = _FakeTaskRepository(tasks);

      container = ProviderContainer(
        overrides: [
          taskCoreRepositoryProvider.overrideWithValue(repository),
          loggerProvider.overrideWithValue(const ConsoleLogger()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('uses domain tasks to compute category stats', () async {
      final service = container.read(taskAnalyticsServiceProvider);
      final start = DateTime(2024, 12, 31);
      final end = DateTime(2025, 1, 31);

      final performance = await service.getCategoryPerformance(start, end);

      expect(performance.categoryStats.containsKey('work'), isTrue);
      expect(performance.categoryStats.containsKey('personal'), isTrue);

      final workStats = performance.categoryStats['work']!;
      expect(workStats.totalTasks, 2);
      expect(workStats.completedTasks, 1);
      expect(workStats.totalEstimatedMinutes, 480);
      expect(workStats.totalActualMinutes, 300);
      expect(workStats.averageCompletionTime, const Duration(hours: 5));

      final personalStats = performance.categoryStats['personal']!;
      expect(personalStats.totalTasks, 1);
      expect(personalStats.completedTasks, 0);

      expect(performance.mostProductiveCategory, 'work');
      expect(performance.slowestCategory, 'work');
    });
  });
}
