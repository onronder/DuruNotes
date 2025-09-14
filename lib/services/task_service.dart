import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/utils/hash_utils.dart';
import 'package:uuid/uuid.dart';

/// Service for managing tasks
class TaskService {
  TaskService({
    required AppDb database,
  }) : _db = database;

  final AppDb _db;
  final _uuid = const Uuid();

  /// Create a new task
  Future<String> createTask({
    required String noteId,
    required String content,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    Map<String, dynamic>? labels,
    String? notes,
    int? estimatedMinutes,
  }) async {
    final taskId = _uuid.v4();
    final contentHash = stableTaskHash(noteId, content);

    await _db.createTask(
      NoteTasksCompanion.insert(
        id: taskId,
        noteId: noteId,
        content: content,
        contentHash: contentHash,
        priority: Value(priority),
        dueDate: Value(dueDate),
        parentTaskId: Value(parentTaskId),
        labels: labels != null ? Value(labels.toString()) : const Value.absent(),
        notes: Value(notes),
        estimatedMinutes: Value(estimatedMinutes),
      ),
    );

    // Due date reminders should be handled by the reminder service separately

    return taskId;
  }

  /// Update an existing task
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
  }) async {
    final updates = NoteTasksCompanion(
      content: content != null ? Value(content) : const Value.absent(),
      contentHash: content != null
          ? Value(stableTaskHash((await _db.getTaskById(taskId))?.noteId ?? '', content))
          : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      labels: labels != null ? Value(labels.toString()) : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      estimatedMinutes: estimatedMinutes != null ? Value(estimatedMinutes) : const Value.absent(),
      actualMinutes: actualMinutes != null ? Value(actualMinutes) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await _db.updateTask(taskId, updates);

    // Reminder updates should be handled separately via the reminder service
  }

  /// Mark a task as completed
  Future<void> completeTask(String taskId, {String? completedBy}) async {
    await _db.completeTask(taskId, completedBy: completedBy);
    // Reminder cancellation should be handled by the UI or integration layer
  }

  /// Toggle task completion status
  Future<void> toggleTaskStatus(String taskId) async {
    await _db.toggleTaskStatus(taskId);
    // Reminder status updates should be handled by the UI or integration layer
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    await _db.deleteTaskById(taskId);
    // Reminder deletion should be handled by the UI or integration layer
  }

  /// Get all tasks for a note
  Future<List<NoteTask>> getTasksForNote(String noteId) async {
    return _db.getTasksForNote(noteId);
  }

  /// Get all open tasks
  Future<List<NoteTask>> getOpenTasks({
    DateTime? dueBefore,
    TaskPriority? priority,
    String? parentTaskId,
  }) async {
    return _db.getOpenTasks(
      dueBefore: dueBefore,
      priority: priority,
      parentTaskId: parentTaskId,
    );
  }

  /// Get tasks for a specific date range
  Future<List<NoteTask>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    return _db.getTasksByDateRange(start: start, end: end);
  }

  /// Get overdue tasks
  Future<List<NoteTask>> getOverdueTasks() async {
    return _db.getOverdueTasks();
  }

  /// Get completed tasks
  Future<List<NoteTask>> getCompletedTasks({
    DateTime? since,
    int? limit,
  }) async {
    return _db.getCompletedTasks(since: since, limit: limit);
  }

  /// Get tasks for today
  Future<List<NoteTask>> getTodaysTasks() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db.getTasksByDateRange(start: startOfDay, end: endOfDay);
  }

  /// Get tasks for this week
  Future<List<NoteTask>> getThisWeeksTasks() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return _db.getTasksByDateRange(
      start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      end: DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day),
    );
  }

  /// Watch all open tasks
  Stream<List<NoteTask>> watchOpenTasks() {
    return _db.watchOpenTasks();
  }

  /// Watch tasks for a specific note
  Stream<List<NoteTask>> watchTasksForNote(String noteId) {
    return _db.watchTasksForNote(noteId);
  }

  /// Sync tasks with note content
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) async {
    await _db.syncTasksWithNoteContent(noteId, noteContent);
  }

  /// Get task statistics
  Future<TaskStatistics> getTaskStatistics() async {
    final openTasks = await getOpenTasks();
    final overdueTasks = await getOverdueTasks();
    final todaysTasks = await getTodaysTasks();
    final completedToday = await getCompletedTasks(
      since: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );

    return TaskStatistics(
      totalOpen: openTasks.length,
      totalOverdue: overdueTasks.length,
      dueToday: todaysTasks.length,
      completedToday: completedToday.length,
    );
  }

  /// Batch update task positions (for reordering)
  Future<void> updateTaskPositions(Map<String, int> taskPositions) async {
    for (final entry in taskPositions.entries) {
      await _db.updateTask(
        entry.key,
        NoteTasksCompanion(
          position: Value(entry.value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Get subtasks for a parent task
  Future<List<NoteTask>> getSubtasks(String parentTaskId) async {
    return _db.getOpenTasks(parentTaskId: parentTaskId);
  }

  /// Convert task priority to display string
  String priorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  /// Convert task status to display string
  String statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Task statistics model
class TaskStatistics {
  const TaskStatistics({
    required this.totalOpen,
    required this.totalOverdue,
    required this.dueToday,
    required this.completedToday,
  });

  final int totalOpen;
  final int totalOverdue;
  final int dueToday;
  final int completedToday;
}