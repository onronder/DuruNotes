import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';

/// Service for syncing tasks between note content and task database
class NoteTaskSyncService {
  NoteTaskSyncService({
    required AppDb database,
    required TaskService taskService,
  }) : _db = database,
       _taskService = taskService;

  final AppDb _db;
  final TaskService _taskService;
  final AppLogger _logger = LoggerFactory.instance;
  final Map<String, StreamSubscription<LocalNote?>> _noteSubscriptions = {};

  /// Initialize task sync for a note
  Future<void> initializeNoteTaskSync(String noteId) async {
    // Cancel any existing subscription
    await _noteSubscriptions[noteId]?.cancel();

    // Watch for note changes
    _noteSubscriptions[noteId] = _db.watchNote(noteId).listen((note) async {
      if (note != null) {
        await syncTasksForNote(noteId, note.body);
      }
    });

    // Initial sync
    final note = await _db.getNote(noteId);
    if (note != null) {
      await syncTasksForNote(noteId, note.body);
    }
  }

  /// Stop syncing tasks for a note
  Future<void> stopNoteTaskSync(String noteId) async {
    await _noteSubscriptions[noteId]?.cancel();
    _noteSubscriptions.remove(noteId);
  }

  /// Sync tasks for a note based on its content
  Future<void> syncTasksForNote(String noteId, String noteContent) async {
    try {
      await _db.syncTasksWithNoteContent(noteId, noteContent);
    } catch (e) {
      _logger.debug('Error syncing tasks for note $noteId: $e');
    }
  }

  /// Update note content when a task is toggled
  Future<void> updateNoteContentForTask({
    required String noteId,
    required String taskId,
    required bool isCompleted,
  }) async {
    try {
      final note = await _db.getNote(noteId);
      if (note == null) return;

      final task = await _db.getTaskById(taskId);
      if (task == null) return;

      // Find and update the checkbox in note content
      final lines = note.body.split('\n');
      var position = 0;
      var updated = false;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('- [ ]') ||
            trimmedLine.startsWith('- [x]')) {
          if (position == task.position) {
            // Found the task line, update it
            final content = trimmedLine.substring(5).trim();
            final prefix = line.substring(0, line.indexOf('-'));
            lines[i] = '$prefix- [${isCompleted ? 'x' : ' '}] $content';
            updated = true;
            break;
          }
          position++;
        }
      }

      if (updated) {
        final updatedContent = lines.join('\n');
        await _db.updateNote(
          noteId,
          LocalNotesCompanion(
            body: Value(updatedContent),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.debug('Error updating note content for task: $e');
    }
  }

  /// Add a new task to note content
  Future<void> addTaskToNote({
    required String noteId,
    required String taskContent,
    required int position,
    bool isCompleted = false,
  }) async {
    try {
      final note = await _db.getNote(noteId);
      if (note == null) return;

      final lines = note.body.split('\n');
      final checkbox = isCompleted ? '[x]' : '[ ]';
      final taskLine = '- $checkbox $taskContent';

      // Find position to insert
      if (position >= 0 && position <= lines.length) {
        lines.insert(position, taskLine);
      } else {
        lines.add(taskLine);
      }

      final updatedContent = lines.join('\n');
      await _db.updateNote(
        noteId,
        LocalNotesCompanion(
          body: Value(updatedContent),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Sync tasks after adding
      await syncTasksForNote(noteId, updatedContent);
    } catch (e) {
      _logger.debug('Error adding task to note: $e');
    }
  }

  /// Remove a task from note content
  Future<void> removeTaskFromNote({
    required String noteId,
    required String taskId,
  }) async {
    try {
      final note = await _db.getNote(noteId);
      if (note == null) return;

      final task = await _db.getTaskById(taskId);
      if (task == null) return;

      final lines = note.body.split('\n');
      var position = 0;
      var lineToRemove = -1;

      for (var i = 0; i < lines.length; i++) {
        final trimmedLine = lines[i].trim();

        if (trimmedLine.startsWith('- [ ]') ||
            trimmedLine.startsWith('- [x]')) {
          if (position == task.position) {
            lineToRemove = i;
            break;
          }
          position++;
        }
      }

      if (lineToRemove >= 0) {
        lines.removeAt(lineToRemove);
        final updatedContent = lines.join('\n');

        await _db.updateNote(
          noteId,
          LocalNotesCompanion(
            body: Value(updatedContent),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // Mark task as deleted
        await _taskService.deleteTask(taskId);
      }
    } catch (e) {
      _logger.debug('Error removing task from note: $e');
    }
  }

  /// Update task content in note
  Future<void> updateTaskInNote({
    required String noteId,
    required String taskId,
    required String newContent,
  }) async {
    try {
      final note = await _db.getNote(noteId);
      if (note == null) return;

      final task = await _db.getTaskById(taskId);
      if (task == null) return;

      final lines = note.body.split('\n');
      var position = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('- [ ]') ||
            trimmedLine.startsWith('- [x]')) {
          if (position == task.position) {
            final isCompleted = trimmedLine.startsWith('- [x]');
            final prefix = line.substring(0, line.indexOf('-'));
            lines[i] = '$prefix- [${isCompleted ? 'x' : ' '}] $newContent';
            break;
          }
          position++;
        }
      }

      final updatedContent = lines.join('\n');
      await _db.updateNote(
        noteId,
        LocalNotesCompanion(
          body: Value(updatedContent),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Update task in database
      await _taskService.updateTask(taskId: taskId, content: newContent);
    } catch (e) {
      _logger.debug('Error updating task in note: $e');
    }
  }

  /// Reorder tasks in note
  Future<void> reorderTasksInNote({
    required String noteId,
    required Map<String, int> newPositions,
  }) async {
    try {
      final note = await _db.getNote(noteId);
      if (note == null) return;

      final tasks = await _db.getTasksForNote(noteId);

      final lines = note.body.split('\n');
      final taskLines = <int, String>{};
      var position = 0;

      // Extract task lines
      for (var i = 0; i < lines.length; i++) {
        final trimmedLine = lines[i].trim();
        if (trimmedLine.startsWith('- [ ]') ||
            trimmedLine.startsWith('- [x]')) {
          taskLines[position] = lines[i];
          lines[i] = '___TASK_PLACEHOLDER_${position}___';
          position++;
        }
      }

      // Reorder task lines based on new positions
      final reorderedTaskLines = <int, String>{};
      for (final entry in newPositions.entries) {
        final taskId = entry.key;
        final newPosition = entry.value;
        final task = tasks.firstWhere((t) => t.id == taskId);
        final oldPosition = task.position;

        if (taskLines.containsKey(oldPosition)) {
          reorderedTaskLines[newPosition] = taskLines[oldPosition]!;
        }
      }

      // Replace placeholders with reordered tasks
      position = 0;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('___TASK_PLACEHOLDER_')) {
          if (reorderedTaskLines.containsKey(position)) {
            lines[i] = reorderedTaskLines[position]!;
          }
          position++;
        }
      }

      final updatedContent = lines.join('\n');
      await _db.updateNote(
        noteId,
        LocalNotesCompanion(
          body: Value(updatedContent),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Update task positions in database
      await _taskService.updateTaskPositions(newPositions);
    } catch (e) {
      _logger.debug('Error reordering tasks in note: $e');
    }
  }

  /// Extract tasks from markdown content
  List<TaskInfo> extractTasksFromContent(String content) {
    final tasks = <TaskInfo>[];
    final lines = content.split('\n');
    var position = 0;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('- [ ]') || trimmedLine.startsWith('- [x]')) {
        final isCompleted = trimmedLine.startsWith('- [x]');
        final taskContent = trimmedLine.substring(5).trim();

        if (taskContent.isNotEmpty) {
          // Parse due date if present (format: - [ ] Task @due(2024-12-25))
          DateTime? dueDate;
          var cleanContent = taskContent;

          final dueDateMatch = RegExp(
            r'@due\((\d{4}-\d{2}-\d{2})\)',
          ).firstMatch(taskContent);
          if (dueDateMatch != null) {
            try {
              dueDate = DateTime.parse(dueDateMatch.group(1)!);
              cleanContent = taskContent
                  .replaceAll(dueDateMatch.group(0)!, '')
                  .trim();
            } catch (_) {}
          }

          // Parse priority if present (format: - [ ] Task !high)
          var priority = TaskPriority.medium;

          if (cleanContent.contains('!urgent')) {
            priority = TaskPriority.urgent;
            cleanContent = cleanContent.replaceAll('!urgent', '').trim();
          } else if (cleanContent.contains('!high')) {
            priority = TaskPriority.high;
            cleanContent = cleanContent.replaceAll('!high', '').trim();
          } else if (cleanContent.contains('!low')) {
            priority = TaskPriority.low;
            cleanContent = cleanContent.replaceAll('!low', '').trim();
          }

          tasks.add(
            TaskInfo(
              content: cleanContent,
              isCompleted: isCompleted,
              position: position,
              dueDate: dueDate,
              priority: priority,
            ),
          );

          position++;
        }
      }
    }

    return tasks;
  }

  /// Dispose all subscriptions
  void dispose() {
    for (final subscription in _noteSubscriptions.values) {
      subscription.cancel();
    }
    _noteSubscriptions.clear();
  }
}

/// Task information extracted from content
class TaskInfo {
  const TaskInfo({
    required this.content,
    required this.isCompleted,
    required this.position,
    this.dueDate,
    this.priority = TaskPriority.medium,
  });

  final String content;
  final bool isCompleted;
  final int position;
  final DateTime? dueDate;
  final TaskPriority priority;
}

// Provider is defined in lib/providers.dart
