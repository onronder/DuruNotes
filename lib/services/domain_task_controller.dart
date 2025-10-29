import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Domain task controller orchestrates task mutations through the domain
/// repository while delegating reminder management to [EnhancedTaskService].
class DomainTaskController {
  DomainTaskController({
    required ITaskRepository taskRepository,
    required INotesRepository notesRepository,
    required EnhancedTaskService enhancedTaskService,
    required AppLogger logger,
  }) : _taskRepository = taskRepository,
       _notesRepository = notesRepository,
       _enhancedTaskService = enhancedTaskService,
       _logger = logger;

  final ITaskRepository _taskRepository;
  final INotesRepository _notesRepository;
  final EnhancedTaskService _enhancedTaskService;
  final AppLogger _logger;

  static const legacyStandaloneNoteId = 'standalone';
  static const _generatedStandaloneNoteId =
      '00000000-0000-0000-0000-000000000001';
  static const _standaloneNoteTitle = 'Standalone Tasks';

  static String? _cachedStandaloneUserId;
  static String? _cachedStandaloneNoteId;
  static const Uuid _uuid = Uuid();

  static String _resolveStandaloneNoteId() {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      userId = null;
    }

    if (userId == null || userId.isEmpty) {
      _cachedStandaloneUserId = null;
      _cachedStandaloneNoteId = legacyStandaloneNoteId;
      return legacyStandaloneNoteId;
    }

    if (_cachedStandaloneUserId == userId && _cachedStandaloneNoteId != null) {
      return _cachedStandaloneNoteId!;
    }

    final computed = _uuid.v5(
      Namespace.url.value,
      'duru-notes-standalone-task-container:$userId',
    );

    _cachedStandaloneUserId = userId;
    _cachedStandaloneNoteId = computed;
    return computed;
  }

  static String get standaloneNoteId => _resolveStandaloneNoteId();

  static bool isStandaloneNoteId(String noteId) {
    if (noteId == legacyStandaloneNoteId ||
        noteId == _generatedStandaloneNoteId) {
      return true;
    }
    final resolved = _cachedStandaloneNoteId ?? _resolveStandaloneNoteId();
    return noteId == resolved;
  }

  /// Stream all tasks. When [includeCompleted] is false, completed tasks
  /// are filtered out from the stream.
  Stream<List<domain.Task>> watchAllTasks({bool includeCompleted = true}) {
    return _taskRepository.watchAllTasks().map((tasks) {
      if (includeCompleted) return tasks;
      return tasks
          .where((task) => task.status != domain.TaskStatus.completed)
          .toList(growable: false);
    });
  }

  /// Stream tasks for a specific note.
  Stream<List<domain.Task>> watchTasksForNote(
    String noteId, {
    bool includeCompleted = true,
  }) {
    return _taskRepository.watchTasksForNote(noteId).map((tasks) {
      if (includeCompleted) return tasks;
      return tasks
          .where((task) => task.status != domain.TaskStatus.completed)
          .toList(growable: false);
    });
  }

  Future<domain.Task?> getTaskById(String taskId) {
    return _taskRepository.getTaskById(taskId);
  }

  Future<List<domain.Task>> getTasksForNote(String noteId) {
    return _taskRepository.getTasksForNote(noteId);
  }

  /// Create a new task. When [noteId] is omitted, a standalone container note
  /// is created (if needed) to keep encryption/sync consistent.
  Future<domain.Task> createTask({
    String? noteId,
    required String title,
    String? description,
    domain.TaskPriority priority = domain.TaskPriority.medium,
    domain.TaskStatus status = domain.TaskStatus.pending,
    DateTime? dueDate,
    DateTime? completedAt,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
    bool createReminder = true,
    DateTime? reminderTime,
    String? parentTaskId,
    int? estimatedMinutes,
  }) async {
    final effectiveNoteId = noteId ?? await _ensureStandaloneNote();
    debugPrint(
      '[DomainTaskController] createTask request -> '
      'note=$effectiveNoteId title="$title" due=${dueDate?.toIso8601String()} '
      'priority=${priority.name} createReminder=$createReminder',
    );

    final bool shouldCreateCustomReminder =
        createReminder && dueDate != null && reminderTime != null;
    final bool shouldScheduleReminder =
        createReminder && dueDate != null && !shouldCreateCustomReminder;

    if (createReminder && dueDate == null) {
      _logger.warning(
        'Reminder requested without due date; skipping reminder creation',
        data: {'title': title, 'noteId': effectiveNoteId},
      );
    }

    final taskId = await _enhancedTaskService.createTask(
      noteId: effectiveNoteId,
      content: title,
      priority: TaskMapper.mapPriorityToDb(priority),
      status: TaskMapper.mapStatusToDb(status),
      dueDate: dueDate,
      parentTaskId: parentTaskId,
      labels: tags.isEmpty ? null : {'labels': tags},
      notes: description,
      estimatedMinutes: estimatedMinutes,
      createReminder: shouldScheduleReminder,
    );

    if (shouldCreateCustomReminder) {
      // ignore: unnecessary_non_null_assertion
      final DateTime dueDateForReminder = dueDate!;
      // ignore: unnecessary_non_null_assertion
      final DateTime reminderTimeForReminder = reminderTime!;
      await _enhancedTaskService.setCustomTaskReminder(
        taskId: taskId,
        dueDate: dueDateForReminder,
        reminderTime: reminderTimeForReminder,
      );
      debugPrint(
        '[DomainTaskController] custom reminder scheduled for task $taskId',
      );
    }

    final created = await _taskRepository.getTaskById(taskId);
    if (created == null) {
      throw StateError('Task $taskId not found after creation');
    }

    _logger.info(
      'Created domain task',
      data: {'taskId': taskId, 'noteId': created.noteId},
    );
    debugPrint(
      '[DomainTaskController] task created id=$taskId note=${created.noteId}',
    );
    return created;
  }

  Future<domain.Task> updateTask(
    domain.Task task, {
    String? title,
    String? description,
    domain.TaskPriority? priority,
    DateTime? dueDate,
    DateTime? reminderTime,
    bool? hasReminder,
    domain.TaskStatus? status,
    List<String>? tags,
    int? estimatedMinutes,
    int? actualMinutes,
    Map<String, dynamic>? metadata,
  }) async {
    final bool previouslyHadReminder = task.metadata['reminderId'] != null;
    final bool shouldCancelReminder = hasReminder == false;
    final bool shouldAutoRefreshReminder =
        reminderTime == null && !shouldCancelReminder;

    debugPrint(
      '[DomainTaskController] updateTask request -> id=${task.id} '
      'title=${title ?? task.title} due=${(dueDate ?? task.dueDate)?.toIso8601String()} '
      'hasReminder=$hasReminder',
    );

    await _enhancedTaskService.updateTask(
      taskId: task.id,
      content: title ?? task.title,
      notes: description ?? task.description,
      priority: priority != null ? TaskMapper.mapPriorityToDb(priority) : null,
      dueDate: dueDate ?? task.dueDate,
      labels: tags != null ? {'labels': tags} : null,
      status: status != null ? TaskMapper.mapStatusToDb(status) : null,
      estimatedMinutes:
          estimatedMinutes ?? task.metadata['estimatedMinutes'] as int?,
      actualMinutes: actualMinutes ?? task.metadata['actualMinutes'] as int?,
      reminderId: metadata?['reminderId'] as int?,
      updateReminder: shouldAutoRefreshReminder,
      clearReminderId: shouldCancelReminder,
    );

    domain.Task? updated = await _taskRepository.getTaskById(task.id);
    if (updated == null) {
      throw StateError('Task ${task.id} not found after update');
    }

    final effectiveDueDate = dueDate ?? updated.dueDate;

    if (shouldCancelReminder && previouslyHadReminder) {
      await _enhancedTaskService.clearTaskReminder(task.id);
      updated = await _taskRepository.getTaskById(task.id) ?? updated;
      debugPrint('[DomainTaskController] cleared reminder for task ${task.id}');
    } else if (!shouldCancelReminder && reminderTime != null) {
      final customDueDate = effectiveDueDate;
      if (customDueDate == null) {
        _logger.warning(
          'Cannot set custom reminder without due date',
          data: {'taskId': task.id},
        );
      } else {
        await _enhancedTaskService.setCustomTaskReminder(
          taskId: task.id,
          dueDate: customDueDate,
          reminderTime: reminderTime,
        );
        updated = await _taskRepository.getTaskById(task.id) ?? updated;
        debugPrint(
          '[DomainTaskController] set custom reminder for task ${task.id}',
        );
      }
    } else if (hasReminder == true &&
        !previouslyHadReminder &&
        effectiveDueDate != null) {
      await _enhancedTaskService.refreshDefaultTaskReminder(task.id);
      updated = await _taskRepository.getTaskById(task.id) ?? updated;
      debugPrint(
        '[DomainTaskController] refreshed default reminder for task ${task.id}',
      );
    } else if (hasReminder == true &&
        !previouslyHadReminder &&
        effectiveDueDate == null) {
      _logger.warning(
        'Reminder was enabled but task has no due date; skipping reminder creation',
        data: {'taskId': task.id},
      );
    }

    return updated;
  }

  Future<void> toggleStatus(String taskId) =>
      _enhancedTaskService.toggleTaskStatus(taskId);

  Future<void> deleteTask(String taskId) =>
      _enhancedTaskService.deleteTask(taskId);

  Future<void> updateTaskContents({
    required String taskId,
    required String title,
    String? description,
  }) async {
    final task = await _requireTask(taskId);
    await updateTask(task, title: title, description: description);
  }

  Future<void> setPriority(String taskId, domain.TaskPriority priority) async {
    final task = await _requireTask(taskId);
    await updateTask(task, priority: priority);
  }

  Future<void> setDueDate(String taskId, DateTime? dueDate) async {
    final task = await _requireTask(taskId);
    await updateTask(task, dueDate: dueDate);
  }

  Future<void> setStatus(String taskId, domain.TaskStatus status) async {
    final task = await _requireTask(taskId);
    await updateTask(task, status: status);
  }

  Future<void> setTags(String taskId, List<String> tags) async {
    final task = await _requireTask(taskId);
    await updateTask(task, tags: tags);
  }

  Future<void> setEstimatedMinutes(String taskId, int? estimatedMinutes) async {
    final task = await _requireTask(taskId);
    await updateTask(task, estimatedMinutes: estimatedMinutes);
  }

  Future<void> setActualMinutes(String taskId, int actualMinutes) async {
    final task = await _requireTask(taskId);
    await updateTask(task, actualMinutes: actualMinutes);
  }

  Future<void> completeAllSubtasks(String parentTaskId) async {
    final subtasks = await _taskRepository.getSubtasks(parentTaskId);
    for (final subtask in subtasks) {
      await setStatus(subtask.id, domain.TaskStatus.completed);
      await setActualMinutes(
        subtask.id,
        subtask.metadata['actualMinutes'] as int? ?? 0,
      );
      await completeAllSubtasks(subtask.id);
    }
  }

  Future<void> deleteHierarchy(String taskId) async {
    final subtasks = await _taskRepository.getSubtasks(taskId);
    for (final subtask in subtasks) {
      await deleteHierarchy(subtask.id);
    }
    await deleteTask(taskId);
  }

  Future<domain.Task> _requireTask(String taskId) async {
    final task = await _taskRepository.getTaskById(taskId);
    if (task == null) throw StateError('Task $taskId not found');
    return task;
  }

  Future<String> _ensureStandaloneNote() async {
    final desiredNoteId = standaloneNoteId;
    final existing = await _notesRepository.getNoteById(desiredNoteId);
    if (existing != null) return desiredNoteId;

    for (final legacyId in <String>[
      legacyStandaloneNoteId,
      _generatedStandaloneNoteId,
    ]) {
      final legacyNote = await _notesRepository.getNoteById(legacyId);
      if (legacyNote != null) {
        await _enhancedTaskService.migrateStandaloneNoteId(
          fromNoteId: legacyId,
          toNoteId: desiredNoteId,
        );

        final migratedTasks = await _taskRepository.getTasksForNote(
          desiredNoteId,
        );
        for (final task in migratedTasks) {
          try {
            await _taskRepository.updateTask(task);
          } catch (error, stackTrace) {
            _logger.error(
              'Failed to refresh migrated standalone task',
              error: error,
              stackTrace: stackTrace,
              data: {'taskId': task.id},
            );
          }
        }
      }
    }

    await _notesRepository.createOrUpdate(
      id: desiredNoteId,
      title: _standaloneNoteTitle,
      body: 'Automated container for standalone tasks.',
      metadataJson: {'system': true, 'standaloneTasks': true},
      tags: const [],
      links: const [],
    );

    _logger.info(
      'Created standalone note for tasks',
      data: {'noteId': desiredNoteId},
    );
    debugPrint('[DomainTaskController] created standalone note $desiredNoteId');

    return desiredNoteId;
  }
}
