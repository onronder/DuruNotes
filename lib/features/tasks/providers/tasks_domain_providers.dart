import 'package:duru_notes/core/migration/state_migration_helper.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Domain tasks stream provider - provides clean stream of domain.Task entities
/// This replaces duplicate task fetching logic in UI components
final domainTasksStreamProvider = StreamProvider<List<domain_task.Task>>((ref) {
  final repository = ref.watch(taskCoreRepositoryProvider);
  return repository.watchAllTasks();
});

/// Domain open tasks provider - provides only open/pending tasks
final domainOpenTasksProvider = StreamProvider<List<domain_task.Task>>((ref) {
  final allTasksStream = ref.watch(domainTasksStreamProvider.stream);
  return allTasksStream.map((tasks) =>
      tasks.where((task) => task.status != domain_task.TaskStatus.completed).toList());
});

/// Domain completed tasks provider - provides only completed tasks
final domainCompletedTasksProvider = StreamProvider<List<domain_task.Task>>((ref) {
  final allTasksStream = ref.watch(domainTasksStreamProvider.stream);
  return allTasksStream.map((tasks) =>
      tasks.where((task) => task.status == domain_task.TaskStatus.completed).toList());
});

/// Domain tasks for note provider - provides tasks for a specific note
final domainTasksForNoteProvider =
    StreamProvider.family<List<domain_task.Task>, String>((ref, noteId) {
  final repository = ref.watch(taskCoreRepositoryProvider);
  return repository.watchTasksForNote(noteId);
});

/// Domain task statistics provider - provides task statistics
final domainTaskStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final tasksAsync = await ref.watch(domainTasksStreamProvider.future);
  final now = DateTime.now();

  final pendingCount = tasksAsync.where((t) =>
      t.status != domain_task.TaskStatus.completed).length;

  final completedTodayCount = tasksAsync.where((t) {
    if (t.completedAt == null) return false;
    return t.completedAt!.year == now.year &&
           t.completedAt!.month == now.month &&
           t.completedAt!.day == now.day;
  }).length;

  final overdueCount = tasksAsync.where((t) {
    if (t.dueDate == null || t.status == domain_task.TaskStatus.completed) return false;
    return t.dueDate!.isBefore(now);
  }).length;

  return {
    'pending': pendingCount,
    'completedToday': completedTodayCount,
    'overdue': overdueCount,
  };
});

/// Domain tasks provider - switches between legacy and domain
final domainTasksProvider = FutureProvider<List<domain_task.Task>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('tasks')) {
    // Use domain repository
    final repository = ref.watch(taskCoreRepositoryProvider);
    return repository.getAllTasks();
  } else {
    // Convert from legacy - get all tasks from all notes
    final db = ref.watch(appDbProvider);
    final allTasks = await db.select(db.noteTasks).get();
    return StateMigrationHelper.convertTasksToDomain(allTasks);
  }
});