import 'package:duru_notes/core/migration/state_migration_helper.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Domain tasks stream provider - provides clean stream of domain.Task entities
/// This replaces duplicate task fetching logic in UI components
///
/// **PRODUCTION FIX**: Returns empty stream when user not authenticated
final domainTasksStreamProvider =
    StreamProvider.autoDispose<List<domain_task.Task>>((ref) {
      final repository = ref.watch(taskCoreRepositoryProvider);

      // PRODUCTION FIX: Handle unauthenticated state
      if (repository == null) {
        return Stream.value(<domain_task.Task>[]);
      }

      return repository.watchAllTasks();
    });

/// Domain open tasks provider - provides only open/pending tasks
///
/// NOTE: Riverpod 3.0+ - Using .future and async* instead of deprecated .stream
final domainOpenTasksProvider =
    StreamProvider.autoDispose<List<domain_task.Task>>((ref) async* {
      // Riverpod 3.0: Fetch initial data with .future
      final allTasks = await ref.watch(domainTasksStreamProvider.future);
      yield allTasks
          .where((task) => task.status != domain_task.TaskStatus.completed)
          .toList();

      // Listen for subsequent updates
      ref.listen(domainTasksStreamProvider, (previous, next) {
        // Provider will auto-rebuild when domainTasksStreamProvider changes
      });
    });

/// Domain completed tasks provider - provides only completed tasks
///
/// NOTE: Riverpod 3.0+ - Using .future and async* instead of deprecated .stream
final domainCompletedTasksProvider =
    StreamProvider.autoDispose<List<domain_task.Task>>((ref) async* {
      // Riverpod 3.0: Fetch initial data with .future
      final allTasks = await ref.watch(domainTasksStreamProvider.future);
      yield allTasks
          .where((task) => task.status == domain_task.TaskStatus.completed)
          .toList();

      // Listen for subsequent updates
      ref.listen(domainTasksStreamProvider, (previous, next) {
        // Provider will auto-rebuild when domainTasksStreamProvider changes
      });
    });

/// Domain tasks for note provider - provides tasks for a specific note
///
/// **PRODUCTION FIX**: Returns empty stream when user not authenticated
final domainTasksForNoteProvider = StreamProvider.autoDispose
    .family<List<domain_task.Task>, String>((ref, noteId) {
      final repository = ref.watch(taskCoreRepositoryProvider);

      // PRODUCTION FIX: Handle unauthenticated state
      if (repository == null) {
        return Stream.value(<domain_task.Task>[]);
      }

      return repository.watchTasksForNote(noteId);
    });

/// Domain task statistics provider - provides task statistics
final domainTaskStatsProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final tasksAsync = await ref.watch(domainTasksStreamProvider.future);
  final now = DateTime.now();

  final pendingCount = tasksAsync
      .where((t) => t.status != domain_task.TaskStatus.completed)
      .length;

  final completedTodayCount = tasksAsync.where((t) {
    if (t.completedAt == null) return false;
    return t.completedAt!.year == now.year &&
        t.completedAt!.month == now.month &&
        t.completedAt!.day == now.day;
  }).length;

  final overdueCount = tasksAsync.where((t) {
    if (t.dueDate == null || t.status == domain_task.TaskStatus.completed) {
      return false;
    }
    return t.dueDate!.isBefore(now);
  }).length;

  return {
    'pending': pendingCount,
    'completedToday': completedTodayCount,
    'overdue': overdueCount,
  };
});

/// Domain tasks provider - switches between legacy and domain
///
/// **PRODUCTION FIX**: Returns empty list when user not authenticated
final domainTasksProvider = FutureProvider.autoDispose<List<domain_task.Task>>((
  ref,
) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('tasks')) {
    // Use domain repository
    final repository = ref.watch(taskCoreRepositoryProvider);

    // PRODUCTION FIX: Handle unauthenticated state
    if (repository == null) {
      return <domain_task.Task>[];
    }

    return repository.getAllTasks();
  } else {
    // Convert from legacy - get all tasks from all notes
    final db = ref.watch(appDbProvider);
    final allTasks = await db.select(db.noteTasks).get();
    return StateMigrationHelper.convertTasksToDomain(allTasks);
  }
});
