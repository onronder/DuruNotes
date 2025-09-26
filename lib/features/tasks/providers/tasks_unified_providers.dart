// Unified Tasks Providers - No more dual architecture!
// These providers replace all conditional providers with a single, consistent interface

import 'package:duru_notes/core/models/unified_task.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/features/notes/providers/notes_unified_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main tasks list provider using UnifiedTask type
final tasksListProvider = StateNotifierProvider<TasksListNotifier, AsyncValue<UnifiedTaskList>>((ref) {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return TasksListNotifier(repository, ref);
});

class TasksListNotifier extends StateNotifier<AsyncValue<UnifiedTaskList>> {
  final dynamic _repository;
  final Ref _ref;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  domain.TaskStatus? _statusFilter;
  String? _noteIdFilter;

  TasksListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    _currentPage = 0;
    _isLoadingMore = false;

    try {
      final page = await _repository.getTasksPage(
        page: 0,
        pageSize: 20,
        status: _statusFilter,
        noteId: _noteIdFilter,
      );
      state = AsyncValue.data(page as UnifiedTaskList);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    final currentState = state;
    if (currentState is! AsyncData<UnifiedTaskList>) return;
    if (!currentState.value.hasMore) return;

    _isLoadingMore = true;
    
    try {
      final nextPage = await _repository.getTasksPage(
        page: _currentPage + 1,
        pageSize: 20,
        status: _statusFilter,
        noteId: _noteIdFilter,
      ) as UnifiedTaskList;
      _currentPage++;

      state = AsyncValue.data(UnifiedTaskList(
        tasks: [...currentState.value.tasks, ...nextPage.tasks],
        hasMore: nextPage.hasMore,
        currentPage: _currentPage,
        totalCount: nextPage.totalCount,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  void setStatusFilter(domain.TaskStatus? status) {
    _statusFilter = status;
    loadInitial();
  }

  void setNoteFilter(String? noteId) {
    _noteIdFilter = noteId;
    loadInitial();
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await refresh();
  }

  Future<void> createTask(UnifiedTask task) async {
    await _repository.createUnified(task);
    await refresh();
  }

  Future<void> updateTask(UnifiedTask task) async {
    await _repository.updateUnified(task);
    await refresh();
  }

  Future<void> completeTask(String id) async {
    await _repository.completeTask(id);
    await refresh();
  }
}

/// Current tasks provider
final currentTasksProvider = Provider<List<UnifiedTask>>((ref) {
  return ref.watch(tasksListProvider).when(
    data: (list) => list.tasks,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Pending tasks provider
final pendingTasksProvider = Provider<List<UnifiedTask>>((ref) {
  final tasks = ref.watch(currentTasksProvider);
  return tasks.where((task) => task.isPending).toList();
});

/// Completed tasks provider
final completedTasksProvider = Provider<List<UnifiedTask>>((ref) {
  final tasks = ref.watch(currentTasksProvider);
  return tasks.where((task) => task.isCompleted).toList();
});

/// Overdue tasks provider
final overdueTasksProvider = FutureProvider<List<UnifiedTask>>((ref) async {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return await repository.getOverdueUnified();
});

/// Tasks for note provider
final tasksForNoteProvider = FutureProvider.family<List<UnifiedTask>, String>((ref, noteId) async {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return await repository.getTasksForNoteUnified(noteId);
});

/// Today's tasks provider
final todaysTasksProvider = Provider<List<UnifiedTask>>((ref) {
  final tasks = ref.watch(currentTasksProvider);
  final today = DateTime.now();
  return tasks.where((task) {
    if (task.dueDate == null) return false;
    return task.dueDate!.year == today.year &&
           task.dueDate!.month == today.month &&
           task.dueDate!.day == today.day;
  }).toList();
});

/// Upcoming tasks provider (next 7 days)
final upcomingTasksProvider = Provider<List<UnifiedTask>>((ref) {
  final tasks = ref.watch(currentTasksProvider);
  final now = DateTime.now();
  final nextWeek = now.add(const Duration(days: 7));
  return tasks.where((task) {
    if (task.dueDate == null) return false;
    return task.dueDate!.isAfter(now) && task.dueDate!.isBefore(nextWeek);
  }).toList();
});

/// Task statistics provider
final taskStatisticsProvider = Provider<TaskStatistics>((ref) {
  final tasks = ref.watch(currentTasksProvider);
  final total = tasks.length;
  final completed = tasks.where((t) => t.isCompleted).length;
  final pending = tasks.where((t) => t.isPending).length;
  final overdue = tasks.where((t) => t.isOverdue).length;
  
  return TaskStatistics(
    total: total,
    completed: completed,
    pending: pending,
    overdue: overdue,
    completionRate: total > 0 ? (completed / total) * 100 : 0,
  );
});

class TaskStatistics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final double completionRate;

  TaskStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.completionRate,
  });
}

/// Watch tasks stream
final watchTasksProvider = StreamProvider<List<UnifiedTask>>((ref) {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return repository.watchTasksUnified();
});

/// Watch tasks for note stream
final watchTasksForNoteProvider = StreamProvider.family<List<UnifiedTask>, String>((ref, noteId) {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return repository.watchTasksForNoteUnified(noteId);
});

/// Watch overdue tasks stream
final watchOverdueTasksProvider = StreamProvider<List<UnifiedTask>>((ref) {
  final repository = ref.watch(unifiedTasksRepositoryProvider);
  return repository.watchOverdueTasks();
});