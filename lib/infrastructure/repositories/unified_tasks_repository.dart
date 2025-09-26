// Unified Tasks Repository that eliminates dual architecture
// Works with UnifiedTask type to provide consistent interface

import 'package:duru_notes/core/models/unified_task.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified repository that provides a single interface for tasks
/// No more conditional logic or feature flags
class UnifiedTasksRepository implements ITaskRepository {
  final AppDb db;
  final SupabaseClient? client;
  final TaskCoreRepository _coreRepository;

  UnifiedTasksRepository({
    required this.db,
    this.client,
  }) : _coreRepository = TaskCoreRepository(db: db, client: client!);

  /// Get tasks with pagination - returns UnifiedTaskList
  Future<UnifiedTaskList> getTasksPage({
    required int page,
    required int pageSize,
    String? noteId,
    domain.TaskStatus? status,
    DateTime? dueDate,
  }) async {
    final allTasks = await _coreRepository.getAllTasks();

    // Apply filters
    var filteredTasks = allTasks;

    // Filter by noteId if provided
    if (noteId != null) {
      filteredTasks = filteredTasks.where((t) => t.noteId == noteId).toList();
    }

    // Filter by status if provided
    if (status != null) {
      filteredTasks = filteredTasks.where((t) => t.status == status).toList();
    }

    // Filter by due date if provided
    if (dueDate != null) {
      filteredTasks = filteredTasks.where((t) {
        if (t.dueDate == null) return false;
        return t.dueDate!.year == dueDate.year &&
            t.dueDate!.month == dueDate.month &&
            t.dueDate!.day == dueDate.day;
      }).toList();
    }

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = (page + 1) * pageSize;
    final paginatedTasks = filteredTasks.skip(startIndex).take(pageSize).toList();

    // Convert to UnifiedTasks
    final unifiedTasks = paginatedTasks.map((t) => UnifiedTask.from(t)).toList();

    return UnifiedTaskList(
      tasks: unifiedTasks,
      hasMore: endIndex < filteredTasks.length,
      currentPage: page,
      totalCount: filteredTasks.length,
    );
  }

  @override
  Future<String> createTask(domain.Task task) async {
    final createdId = await _coreRepository.createTask(task);
    return createdId;
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    return await _coreRepository.updateTask(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _coreRepository.deleteTask(id);
  }

  @override
  Future<domain.Task?> getTaskById(String id) async {
    return await _coreRepository.getTaskById(id);
  }

  Future<List<domain.Task>> getTasksByNoteId(String noteId) async {
    return await _coreRepository.getTasksByNoteId(noteId);
  }

  @override
  Future<List<domain.Task>> getAllTasks() async {
    return await _coreRepository.getAllTasks();
  }

  @override
  Future<List<domain.Task>> getPendingTasks() async {
    final tasks = await _coreRepository.getAllTasks();
    return tasks.where((t) => t.status == domain.TaskStatus.pending).toList();
  }

  Future<List<domain.Task>> getAllTasksWithFilters({
    String? noteId,
    domain.TaskStatus? status,
  }) async {
    final allTasks = await _coreRepository.getAllTasks();

    var filteredTasks = allTasks;
    if (noteId != null) {
      filteredTasks = filteredTasks.where((t) => t.noteId == noteId).toList();
    }
    if (status != null) {
      filteredTasks = filteredTasks.where((t) => t.status == status).toList();
    }

    return filteredTasks;
  }

  Future<List<domain.Task>> getOverdueTasks() async {
    return await _coreRepository.getOverdueTasks();
  }

  Future<void> syncTasks() async {
    await _coreRepository.syncTasks();
  }

  /// Get all tasks as UnifiedTasks
  Future<List<UnifiedTask>> getAllUnified({
    domain.TaskStatus? status,
  }) async {
    final tasks = await getAllTasks();
    final filteredTasks = status != null
        ? tasks.where((t) => t.status == status).toList()
        : tasks;
    return filteredTasks.map((t) => UnifiedTask.from(t)).toList();
  }

  /// Get tasks for note
  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    return await getTasksByNoteId(noteId);
  }

  /// Get tasks for note as UnifiedTasks - for internal use
  Future<List<UnifiedTask>> getTasksForNoteUnified(String noteId) async {
    final tasks = await getTasksByNoteId(noteId);
    return tasks.map((t) => UnifiedTask.from(t)).toList();
  }

  /// Get overdue tasks as UnifiedTasks
  Future<List<UnifiedTask>> getOverdueUnified() async {
    final tasks = await getOverdueTasks();
    return tasks.map((t) => UnifiedTask.from(t)).toList();
  }

  /// Create task from UnifiedTask
  Future<UnifiedTask> createUnified(UnifiedTask task) async {
    final domainTask = task.toDomain();
    final created = await createTask(domainTask);
    return UnifiedTask.from(created);
  }

  /// Update task from UnifiedTask
  Future<UnifiedTask> updateUnified(UnifiedTask task) async {
    final domainTask = task.toDomain();
    final updated = await updateTask(domainTask);
    return UnifiedTask.from(updated);
  }

  /// Complete task
  @override
  Future<void> completeTask(String id) async {
    final task = await getTaskById(id);
    if (task != null) {
      final completed = task.copyWith(
        status: domain.TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      await updateTask(completed);
    }
  }

  /// Complete task and return UnifiedTask - for internal use
  Future<UnifiedTask> completeTaskUnified(String id) async {
    final task = await getTaskById(id);
    if (task != null) {
      final completed = task.copyWith(
        status: domain.TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      final updated = await updateTask(completed);
      return UnifiedTask.from(updated);
    }
    throw Exception('Task not found: $id');
  }

  /// Batch operations for performance
  Future<List<UnifiedTask>> batchCreate(List<UnifiedTask> tasks) async {
    final results = <UnifiedTask>[];
    for (final task in tasks) {
      final created = await createUnified(task);
      results.add(created);
    }
    return results;
  }

  Future<void> batchComplete(List<String> ids) async {
    for (final id in ids) {
      await completeTask(id);
    }
  }

  Future<void> batchDelete(List<String> ids) async {
    for (final id in ids) {
      await deleteTask(id);
    }
  }

  /// Stream for watching tasks
  @override
  Stream<List<domain.Task>> watchTasks() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getAllTasks(),
    ).asyncMap((future) => future);
  }

  @override
  Stream<List<domain.Task>> watchAllTasks() {
    return watchTasks();
  }

  /// Stream for watching tasks for note
  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getTasksForNote(noteId),
    ).asyncMap((future) => future);
  }

  /// Stream for watching tasks as UnifiedTask - for internal use
  Stream<List<UnifiedTask>> watchTasksUnified() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getAllUnified(),
    ).asyncMap((future) => future);
  }

  /// Stream for watching tasks for note as UnifiedTask - for internal use
  Stream<List<UnifiedTask>> watchTasksForNoteUnified(String noteId) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getTasksForNoteUnified(noteId),
    ).asyncMap((future) => future);
  }

  /// Stream for watching overdue tasks
  Stream<List<UnifiedTask>> watchOverdueTasks() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) async => await getOverdueUnified(),
    ).asyncMap((future) => future);
  }

  // Implementation of remaining ITaskRepository methods

  @override
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) =>
      task.metadata['parentId'] == parentTaskId
    ).toList();
  }

  @override
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    domain.TaskStatus? status,
  }) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      final dueDate = task.dueDate!;
      final isInRange = dueDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                       dueDate.isBefore(endDate.add(const Duration(days: 1)));
      if (status != null) {
        return isInRange && task.status == status;
      }
      return isInRange;
    }).toList();
  }

  @override
  Future<List<domain.Task>> searchTasks(String query) async {
    final allTasks = await getAllTasks();
    final lowercaseQuery = query.toLowerCase();
    return allTasks.where((task) {
      final title = task.title.toLowerCase();
      final content = (task.content ?? '').toLowerCase();
      return title.contains(lowercaseQuery) || content.contains(lowercaseQuery);
    }).toList();
  }

  @override
  Future<List<domain.Task>> getCompletedTasks({
    DateTime? since,
    int? limit,
  }) async {
    final allTasks = await getAllTasks();
    var completedTasks = allTasks.where((task) =>
      task.status == domain.TaskStatus.completed
    ).toList();

    if (since != null) {
      completedTasks = completedTasks.where((task) =>
        task.completedAt != null && task.completedAt!.isAfter(since)
      ).toList();
    }

    // Sort by completion date (most recent first)
    completedTasks.sort((a, b) {
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (limit != null && completedTasks.length > limit) {
      completedTasks = completedTasks.take(limit).toList();
    }

    return completedTasks;
  }

  @override
  Future<void> toggleTaskStatus(String id) async {
    final task = await getTaskById(id);
    if (task != null) {
      final newStatus = task.status == domain.TaskStatus.completed
        ? domain.TaskStatus.pending
        : domain.TaskStatus.completed;

      final updatedTask = task.copyWith(
        status: newStatus,
        completedAt: newStatus == domain.TaskStatus.completed
          ? DateTime.now()
          : null,
      );

      await updateTask(updatedTask);
    }
  }

  @override
  Future<Map<String, int>> getTaskStatistics() async {
    final allTasks = await getAllTasks();

    final stats = <String, int>{
      'total': allTasks.length,
      'pending': 0,
      'inProgress': 0,
      'completed': 0,
      'cancelled': 0,
      'overdue': 0,
      'dueToday': 0,
      'dueTomorrow': 0,
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final task in allTasks) {
      // Count by status
      switch (task.status) {
        case domain.TaskStatus.pending:
          stats['pending'] = stats['pending']! + 1;
        case domain.TaskStatus.inProgress:
          stats['inProgress'] = stats['inProgress']! + 1;
        case domain.TaskStatus.completed:
          stats['completed'] = stats['completed']! + 1;
        case domain.TaskStatus.cancelled:
          stats['cancelled'] = stats['cancelled']! + 1;
      }

      // Count by due date
      if (task.dueDate != null) {
        final dueDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day
        );

        if (dueDate.isBefore(today) && task.status != domain.TaskStatus.completed) {
          stats['overdue'] = stats['overdue']! + 1;
        } else if (dueDate.isAtSameMomentAs(today)) {
          stats['dueToday'] = stats['dueToday']! + 1;
        } else if (dueDate.isAtSameMomentAs(tomorrow)) {
          stats['dueTomorrow'] = stats['dueTomorrow']! + 1;
        }
      }
    }

    return stats;
  }

  @override
  Future<List<domain.Task>> getTasksByPriority(domain.TaskPriority priority) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.priority == priority).toList();
  }

  @override
  Future<void> updateTaskPriority(String id, domain.TaskPriority priority) async {
    final task = await getTaskById(id);
    if (task != null) {
      final updatedTask = task.copyWith(priority: priority);
      await updateTask(updatedTask);
    }
  }

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    final task = await getTaskById(id);
    if (task != null) {
      final updatedTask = task.copyWith(dueDate: dueDate);
      await updateTask(updatedTask);
    }
  }

  @override
  Future<void> addTagToTask(String taskId, String tag) async {
    final task = await getTaskById(taskId);
    if (task != null) {
      final currentTags = List<String>.from(task.tags);
      if (!currentTags.contains(tag)) {
        currentTags.add(tag);
        final updatedTask = task.copyWith(tags: currentTags);
        await updateTask(updatedTask);
      }
    }
  }

  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {
    final task = await getTaskById(taskId);
    if (task != null) {
      final currentTags = List<String>.from(task.tags);
      if (currentTags.contains(tag)) {
        currentTags.remove(tag);
        final updatedTask = task.copyWith(tags: currentTags);
        await updateTask(updatedTask);
      }
    }
  }

  @override
  Future<void> deleteTasksForNote(String noteId) async {
    final tasks = await getTasksForNote(noteId);
    for (final task in tasks) {
      await deleteTask(task.id);
    }
  }
}