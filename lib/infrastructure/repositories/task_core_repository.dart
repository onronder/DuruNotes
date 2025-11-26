import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/events/mutation_event_bus.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/core/utils/hash_utils.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/services/trash_audit_logger.dart';
import 'package:uuid/uuid.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Core task repository implementation
class TaskCoreRepository implements ITaskRepository {
  TaskCoreRepository({
    required this.db,
    required this.client,
    required this.crypto,
    TrashAuditLogger? trashAuditLogger,
  }) : _logger = LoggerFactory.instance,
       _trashAuditLogger = trashAuditLogger ?? TrashAuditLogger(client: client);

  final AppDb db;
  final SupabaseClient client;
  final CryptoBox crypto;
  final AppLogger _logger;
  final _uuid = const Uuid();
  final SecurityAuditTrail _securityAuditTrail = SecurityAuditTrail();
  final TrashAuditLogger _trashAuditLogger;

  String? get _currentUserId => client.auth.currentUser?.id;

  void _auditAccess(String resource, {required bool granted, String? reason}) {
    unawaited(
      _securityAuditTrail.logAccess(
        resource: resource,
        granted: granted,
        reason: reason,
      ),
    );
  }

  String _requireUserId({required String method, Map<String, dynamic>? data}) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      final error = StateError('No authenticated user for task operation');
      _logger.warning('$method denied - unauthenticated user', data: data);
      _captureRepositoryException(
        method: method,
        error: error,
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      _auditAccess('tasks.$method', granted: false, reason: 'missing_user');
      throw error;
    }
    return userId;
  }

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'TaskCoreRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  Future<void> _enqueuePendingOp({
    required String entityId,
    required String kind,
    String? payload,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _logger.warning(
        'Skipping enqueue - no authenticated user',
        data: {'kind': kind, 'entityId': entityId},
      );
      return;
    }

    await db.enqueue(
      userId: userId,
      entityId: entityId,
      kind: kind,
      payload: payload,
    );
  }

  /// Decrypt a single task and map to domain
  Future<domain.Task> _decryptTask(NoteTask localTask) async {
    final userId = client.auth.currentUser?.id ?? '';
    String content = '';
    String? notes;
    String? labels;

    // Decrypt content
    try {
      if (localTask.contentEncrypted.isNotEmpty) {
        // FIX: Use base64.decode() not utf8.encode()
        // Data is stored as base64-encoded encrypted bytes
        final contentData = base64.decode(localTask.contentEncrypted);
        content = await crypto.decryptStringForNote(
          userId: userId,
          noteId: localTask.noteId,
          data: contentData,
        );
      }
    } catch (e) {
      _logger.warning('Failed to decrypt content for task ${localTask.id}: $e');
    }

    // Decrypt notes (description)
    try {
      if (localTask.notesEncrypted != null &&
          localTask.notesEncrypted!.isNotEmpty) {
        // FIX: Use base64.decode() not utf8.encode()
        // Data is stored as base64-encoded encrypted bytes
        final notesData = base64.decode(localTask.notesEncrypted!);
        notes = await crypto.decryptStringForNote(
          userId: userId,
          noteId: localTask.noteId,
          data: notesData,
        );
      }
    } catch (e) {
      _logger.warning('Failed to decrypt notes for task ${localTask.id}: $e');
    }

    // Decrypt labels (tags)
    try {
      if (localTask.labelsEncrypted != null &&
          localTask.labelsEncrypted!.isNotEmpty) {
        // FIX: Use base64.decode() not utf8.encode()
        // Data is stored as base64-encoded encrypted bytes
        final labelsData = base64.decode(localTask.labelsEncrypted!);
        labels = await crypto.decryptStringForNote(
          userId: userId,
          noteId: localTask.noteId,
          data: labelsData,
        );
      }
    } catch (e) {
      _logger.warning('Failed to decrypt labels for task ${localTask.id}: $e');
    }

    return TaskMapper.toDomain(
      localTask,
      content: content,
      notes: notes,
      labels: labels,
    );
  }

  /// Decrypt multiple tasks and map to domain
  Future<List<domain.Task>> _decryptTasks(List<NoteTask> localTasks) async {
    final List<domain.Task> tasks = [];
    for (final localTask in localTasks) {
      try {
        final task = await _decryptTask(localTask);
        tasks.add(task);
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to decrypt task ${localTask.id}',
          error: error,
          stackTrace: stackTrace,
        );
        // Continue with other tasks even if one fails
      }
    }
    return tasks;
  }

  @override
  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    try {
      final userId = _requireUserId(
        method: 'getTasksForNote',
        data: {'noteId': noteId},
      );
      final localTasks = await db.getTasksForNote(noteId, userId: userId);
      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getTasksForNote',
        granted: true,
        reason: 'noteId=$noteId count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks for note: $noteId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTasksForNote',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      _auditAccess(
        'tasks.getTasksForNote',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  @override
  Future<List<domain.Task>> getAllTasks() async {
    try {
      final userId = _requireUserId(method: 'getAllTasks');
      final localTasks = await db.getAllTasks(userId);
      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getAllTasks',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error('Failed to get all tasks', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getAllTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.getAllTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  @override
  Future<List<domain.Task>> getPendingTasks() async {
    try {
      final userId = _requireUserId(method: 'getPendingTasks');
      final localTasks = await db.getOpenTasks(userId: userId);
      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getPendingTasks',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error('Failed to get pending tasks', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getPendingTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.getPendingTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  @override
  Future<domain.Task?> getTaskById(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get task without authenticated user',
          data: {'taskId': id},
        );
        _auditAccess(
          'tasks.getTaskById',
          granted: false,
          reason: 'missing_user',
        );
        return null;
      }
      final localTask = await db.getTaskById(id, userId: userId);
      if (localTask == null) {
        _auditAccess('tasks.getTaskById', granted: false, reason: 'not_found');
        return null;
      }

      final task = await _decryptTask(localTask);
      _auditAccess('tasks.getTaskById', granted: true, reason: 'taskId=$id');
      return task;
    } catch (e, stack) {
      _logger.error(
        'Failed to get task by id: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTaskById',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.getTaskById',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return null;
    }
  }

  @override
  Future<domain.Task> createTask(domain.Task task) async {
    try {
      final userId = _requireUserId(
        method: 'createTask',
        data: {'noteId': task.noteId},
      );

      // Create task with new ID if not provided
      final taskToCreate = task.id.isEmpty
          ? task.copyWith(id: _uuid.v4())
          : task;
      final contentHash = stableTaskHash(
        taskToCreate.noteId,
        taskToCreate.title,
      );

      final existingWithHash = await db.findTaskByContentHash(
        noteId: taskToCreate.noteId,
        userId: userId,
        contentHash: contentHash,
      );

      // Encrypt content (title), notes (description), and labels (tags)
      final contentEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: taskToCreate.noteId,
        text: taskToCreate.title,
      );
      final contentEncrypted = base64.encode(contentEncryptedBytes);

      String? notesEncrypted;
      if (taskToCreate.description != null &&
          taskToCreate.description!.isNotEmpty) {
        final notesEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: taskToCreate.noteId,
          text: taskToCreate.description!,
        );
        notesEncrypted = base64.encode(notesEncryptedBytes);
      }

      String? labelsEncrypted;
      if (taskToCreate.tags.isNotEmpty) {
        final labelsJson = jsonEncode(taskToCreate.tags);
        final labelsEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: taskToCreate.noteId,
          text: labelsJson,
        );
        labelsEncrypted = base64.encode(labelsEncryptedBytes);
      }

      if (existingWithHash != null) {
        final duplicateUpdates = NoteTasksCompanion(
          contentEncrypted: Value(contentEncrypted),
          notesEncrypted: Value(notesEncrypted),
          labelsEncrypted: Value(labelsEncrypted),
          status: Value(_mapStatusToDb(taskToCreate.status)),
          priority: Value(_mapPriorityToDb(taskToCreate.priority)),
          dueDate: Value(taskToCreate.dueDate),
          completedAt: Value(taskToCreate.completedAt),
          estimatedMinutes: Value(
            taskToCreate.metadata['estimatedMinutes'] as int?,
          ),
          actualMinutes: Value(taskToCreate.metadata['actualMinutes'] as int?),
          parentTaskId: Value(taskToCreate.metadata['parentTaskId'] as String?),
          updatedAt: Value(taskToCreate.updatedAt),
          contentHash: Value(contentHash),
          deleted: const Value(false),
        );

        await db.updateTask(existingWithHash.id, userId, duplicateUpdates);

        await _enqueuePendingOp(
          entityId: existingWithHash.id,
          kind: 'upsert_task',
          payload: jsonEncode({'noteId': taskToCreate.noteId}),
        );

        TaskSyncMetrics.instance.recordDuplicate(
          noteId: taskToCreate.noteId,
          taskId: existingWithHash.id,
          duplicateId: taskToCreate.id,
          reason:
              'stable content hash collision prevented duplicate task insert',
        );

        MutationEventBus.instance.emitTask(
          kind: MutationKind.updated,
          taskId: existingWithHash.id,
          noteId: taskToCreate.noteId,
          metadata: {
            'priority': taskToCreate.priority.index,
            if (taskToCreate.dueDate != null)
              'dueDate': taskToCreate.dueDate!.toIso8601String(),
            if (taskToCreate.completedAt != null)
              'completedAt': taskToCreate.completedAt!.toIso8601String(),
            'deduped': true,
          },
        );

        _logger.info(
          'Deduped task creation by stable hash',
          data: {
            'noteId': taskToCreate.noteId,
            'existingTaskId': existingWithHash.id,
          },
        );

        final refreshed = await db.getTaskById(
          existingWithHash.id,
          userId: userId,
        );
        final dedupedTask = await _decryptTask(refreshed!);
        _auditAccess(
          'tasks.createTask',
          granted: true,
          reason: 'deduped existing=${existingWithHash.id}',
        );
        return dedupedTask;
      }

      // Create task companion for insertion
      final taskCompanion = NoteTasksCompanion(
        id: Value(taskToCreate.id),
        noteId: Value(taskToCreate.noteId),
        userId: Value(userId),
        contentEncrypted: Value(contentEncrypted),
        notesEncrypted: Value(notesEncrypted),
        labelsEncrypted: Value(labelsEncrypted),
        status: Value(_mapStatusToDb(taskToCreate.status)),
        priority: Value(_mapPriorityToDb(taskToCreate.priority)),
        dueDate: Value(taskToCreate.dueDate),
        completedAt: Value(taskToCreate.completedAt),
        completedBy: const Value(null),
        position: const Value(0),
        contentHash: Value(contentHash),
        reminderId: const Value(null),
        estimatedMinutes: Value(
          taskToCreate.metadata['estimatedMinutes'] as int?,
        ),
        actualMinutes: Value(taskToCreate.metadata['actualMinutes'] as int?),
        parentTaskId: Value(taskToCreate.metadata['parentTaskId'] as String?),
        createdAt: Value(taskToCreate.createdAt),
        updatedAt: Value(taskToCreate.updatedAt),
        encryptionVersion: const Value(1),
      );

      // Insert into database
      await db.createTask(taskCompanion);

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: taskToCreate.id,
        kind: 'upsert_task',
        payload: jsonEncode({'noteId': taskToCreate.noteId}),
      );

      MutationEventBus.instance.emitTask(
        kind: MutationKind.created,
        taskId: taskToCreate.id,
        noteId: taskToCreate.noteId,
        metadata: {
          'priority': taskToCreate.priority.index,
          if (taskToCreate.dueDate != null)
            'dueDate': taskToCreate.dueDate!.toIso8601String(),
        },
      );

      _auditAccess(
        'tasks.createTask',
        granted: true,
        reason: 'taskId=${taskToCreate.id}',
      );
      return taskToCreate;
    } catch (e, stack) {
      _logger.error(
        'Failed to create task: ${task.title}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id, 'noteId': task.noteId},
      );
      _auditAccess(
        'tasks.createTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<domain.Task> updateTask(domain.Task task) async {
    try {
      final userId = _requireUserId(
        method: 'updateTask',
        data: {'taskId': task.id, 'noteId': task.noteId},
      );
      // Verify task exists
      final existing = await db.getTaskById(task.id, userId: userId);
      if (existing == null) {
        final missingError = StateError('Task not found');
        _logger.warning(
          'Attempted to update non-existent task',
          data: {'taskId': task.id},
        );
        _captureRepositoryException(
          method: 'updateTask',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'taskId': task.id},
          level: SentryLevel.warning,
        );
        _auditAccess('tasks.updateTask', granted: false, reason: 'not_found');
        throw missingError;
      }

      // Encrypt content (title), notes (description), and labels (tags)
      final contentEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: task.noteId,
        text: task.title,
      );
      final contentEncrypted = base64.encode(contentEncryptedBytes);

      String? notesEncrypted;
      if (task.description != null && task.description!.isNotEmpty) {
        final notesEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: task.noteId,
          text: task.description!,
        );
        notesEncrypted = base64.encode(notesEncryptedBytes);
      }

      String? labelsEncrypted;
      if (task.tags.isNotEmpty) {
        final labelsJson = jsonEncode(task.tags);
        final labelsEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: task.noteId,
          text: labelsJson,
        );
        labelsEncrypted = base64.encode(labelsEncryptedBytes);
      }

      final contentHash = stableTaskHash(task.noteId, task.title);

      // Create update companion
      final updateCompanion = NoteTasksCompanion(
        contentEncrypted: Value(contentEncrypted),
        notesEncrypted: Value(notesEncrypted),
        labelsEncrypted: Value(labelsEncrypted),
        status: Value(_mapStatusToDb(task.status)),
        priority: Value(_mapPriorityToDb(task.priority)),
        dueDate: Value(task.dueDate),
        completedAt: Value(task.completedAt),
        estimatedMinutes: Value(task.metadata['estimatedMinutes'] as int?),
        actualMinutes: Value(task.metadata['actualMinutes'] as int?),
        parentTaskId: Value(task.metadata['parentTaskId'] as String?),
        updatedAt: Value(DateTime.now().toUtc()),
        contentHash: Value(contentHash),
      );

      // Update in database
      await db.updateTask(task.id, userId, updateCompanion);

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: task.id,
        kind: 'upsert_task',
        payload: jsonEncode({'noteId': task.noteId}),
      );

      MutationEventBus.instance.emitTask(
        kind: MutationKind.updated,
        taskId: task.id,
        noteId: task.noteId,
        metadata: {
          'priority': task.priority.index,
          if (task.dueDate != null) 'dueDate': task.dueDate!.toIso8601String(),
          if (task.completedAt != null)
            'completedAt': task.completedAt!.toIso8601String(),
        },
      );

      // Return updated task
      final updatedLocal = await db.getTaskById(task.id, userId: userId);
      final updatedTask = await _decryptTask(updatedLocal!);
      _auditAccess(
        'tasks.updateTask',
        granted: true,
        reason: 'taskId=${task.id}',
      );
      return updatedTask;
    } catch (e, stack) {
      _logger.error(
        'Failed to update task: ${task.id}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': task.id},
      );
      _auditAccess(
        'tasks.updateTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> updateTaskReminderLink({
    required String taskId,
    // MIGRATION v41: Changed from int to String (UUID)
    required String? reminderId,
  }) async {
    try {
      final userId = _requireUserId(
        method: 'updateTaskReminderLink',
        data: {'taskId': taskId, 'reminderId': reminderId},
      );

      await db.updateTask(
        taskId,
        userId,
        NoteTasksCompanion(
          reminderId: Value(reminderId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

      _auditAccess(
        'tasks.updateTaskReminderLink',
        granted: true,
        reason: 'taskId=$taskId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to update reminder link for task: $taskId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTaskReminderLink',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'reminderId': reminderId},
      );
      _auditAccess(
        'tasks.updateTaskReminderLink',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> updateTaskPositions(Map<String, int> positions) async {
    if (positions.isEmpty) {
      return;
    }

    try {
      final userId = _requireUserId(
        method: 'updateTaskPositions',
        data: {'count': positions.length},
      );
      final now = DateTime.now().toUtc();

      for (final entry in positions.entries) {
        await db.updateTask(
          entry.key,
          userId,
          NoteTasksCompanion(
            position: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }

      _auditAccess(
        'tasks.updateTaskPositions',
        granted: true,
        reason: 'count=${positions.length}',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to update task positions',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTaskPositions',
        error: e,
        stackTrace: stack,
        data: {'count': positions.length},
      );
      _auditAccess(
        'tasks.updateTaskPositions',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      final userId = _requireUserId(method: 'deleteTask', data: {'taskId': id});
      // Verify task exists
      final existing = await db.getTaskById(id, userId: userId);
      if (existing == null) {
        _logger.warning('Attempted to delete non-existent task: $id');
        _captureRepositoryException(
          method: 'deleteTask',
          error: StateError('Task not found for deletion'),
          stackTrace: StackTrace.current,
          data: {'taskId': id},
          level: SentryLevel.warning,
        );
        _auditAccess('tasks.deleteTask', granted: false, reason: 'not_found');
        return;
      }

      domain.Task? auditTask;
      try {
        auditTask = await _decryptTask(existing);
      } catch (_) {
        // Ignore audit failures
      }

      // Phase 1.1: Soft delete implementation with timestamps
      // Mark task as deleted instead of hard delete
      final now = DateTime.now().toUtc();
      final scheduledPurgeAt = now.add(const Duration(days: 30));

      await (db.update(
        db.noteTasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
        NoteTasksCompanion(
          deleted: Value(true),
          deletedAt: Value(now),
          scheduledPurgeAt: Value(scheduledPurgeAt),
          updatedAt: Value(now),
        ),
      );

      // Enqueue for sync (as upsert with deleted=true)
      await _enqueuePendingOp(
        entityId: id,
        kind: 'upsert_task',
        payload: jsonEncode({'noteId': existing.noteId}),
      );

      MutationEventBus.instance.emitTask(
        kind: MutationKind.deleted,
        taskId: id,
        noteId: existing.noteId,
      );

      _logger.info('Deleted task: $id');
      _auditAccess('tasks.deleteTask', granted: true, reason: 'taskId=$id');

      unawaited(
        _trashAuditLogger.logSoftDelete(
          itemType: TrashAuditItemType.task,
          itemId: id,
          itemTitle: auditTask?.title,
          scheduledPurgeAt: scheduledPurgeAt,
          metadata: {'source': 'tasks.deleteTask', 'noteId': existing.noteId},
        ),
      );
    } catch (e, stack) {
      _logger.error('Failed to delete task: $id', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'deleteTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.deleteTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Restore a soft-deleted task from trash (Phase 1.1)
  @override
  Future<void> restoreTask(String id) async {
    try {
      final userId = _requireUserId(
        method: 'restoreTask',
        data: {'taskId': id},
      );

      // Verify task exists and is deleted
      final task =
          await (db.select(db.noteTasks)
                ..where((t) => t.id.equals(id))
                ..where((t) => t.userId.equals(userId)))
              .getSingleOrNull();

      if (task == null) {
        throw StateError('Task not found or does not belong to user');
      }

      if (!task.deleted) {
        _logger.warning('Attempted to restore task that is not deleted: $id');
        return; // Already restored, no-op
      }

      domain.Task? auditTask;
      try {
        auditTask = await _decryptTask(task);
      } catch (_) {
        // Ignore audit failures
      }

      // Restore the task and clear timestamps
      final now = DateTime.now().toUtc();

      await (db.update(
        db.noteTasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
        NoteTasksCompanion(
          deleted: Value(false),
          deletedAt: Value(null),
          scheduledPurgeAt: Value(null),
          updatedAt: Value(now),
        ),
      );

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: id,
        kind: 'upsert_task',
        payload: jsonEncode({'noteId': task.noteId}),
      );

      _logger.info('Restored task from trash: $id');
      _auditAccess('tasks.restoreTask', granted: true, reason: 'taskId=$id');

      unawaited(
        _trashAuditLogger.logRestore(
          itemType: TrashAuditItemType.task,
          itemId: id,
          itemTitle: auditTask?.title,
          metadata: {'source': 'tasks.restoreTask', 'noteId': task.noteId},
        ),
      );
    } catch (e, stack) {
      _logger.error('Failed to restore task: $id', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'restoreTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.restoreTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Permanently delete a task (hard delete, cannot be undone)
  /// This removes the task from the database entirely
  @override
  Future<void> permanentlyDeleteTask(String id) async {
    try {
      final userId = _requireUserId(
        method: 'permanentlyDeleteTask',
        data: {'taskId': id},
      );

      final task =
          await (db.select(db.noteTasks)
                ..where((t) => t.id.equals(id))
                ..where((t) => t.userId.equals(userId)))
              .getSingleOrNull();

      if (task == null) {
        throw StateError('Task not found or does not belong to user');
      }

      domain.Task? auditTask;
      try {
        auditTask = await _decryptTask(task);
      } catch (_) {
        // Ignore audit failures
      }

      await db.transaction(() async {
        // Enqueue delete operation BEFORE removing from database
        await _enqueuePendingOp(
          entityId: id,
          kind: 'delete_task',
          payload: jsonEncode({'noteId': task.noteId}),
        );

        // Hard delete the task
        await (db.delete(db.noteTasks)..where((t) => t.id.equals(id))).go();
      });

      _logger.info('Permanently deleted task: $id');
      _auditAccess(
        'tasks.permanentlyDeleteTask',
        granted: true,
        reason: 'taskId=$id',
      );

      unawaited(
        _trashAuditLogger.logPermanentDelete(
          itemType: TrashAuditItemType.task,
          itemId: id,
          itemTitle: auditTask?.title,
          metadata: {
            'source': 'tasks.permanentlyDeleteTask',
            'noteId': task.noteId,
          },
        ),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to permanently delete task: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'permanentlyDeleteTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.permanentlyDeleteTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Get all deleted tasks for Trash view (Phase 1.1)
  @override
  Future<List<domain.Task>> getDeletedTasks() async {
    try {
      final userId = _requireUserId(method: 'getDeletedTasks');

      final localTasks =
          await (db.select(db.noteTasks)
                ..where((t) => t.deleted.equals(true) & t.userId.equals(userId))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getDeletedTasks',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error('Failed to get deleted tasks', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getDeletedTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.getDeletedTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  @override
  Future<void> completeTask(String id) async {
    try {
      final userId = _requireUserId(
        method: 'completeTask',
        data: {'taskId': id},
      );
      await db.completeTask(id, userId, completedBy: userId);

      final existing = await db.getTaskById(id, userId: userId);
      final noteId = existing?.noteId;

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: id,
        kind: 'upsert_task',
        payload: jsonEncode({'noteId': noteId}),
      );

      MutationEventBus.instance.emitTask(
        kind: MutationKind.updated,
        taskId: id,
        noteId: noteId,
        metadata: const {'completed': true},
      );

      _logger.info('Completed task: $id');
      _auditAccess('tasks.completeTask', granted: true, reason: 'taskId=$id');
    } catch (e, stack) {
      _logger.error(
        'Failed to complete task: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'completeTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.completeTask',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Stream<List<domain.Task>> watchTasks() {
    try {
      final userId = _requireUserId(method: 'watchTasks');
      _auditAccess('tasks.watchTasks', granted: true, reason: 'stream_start');
      return db.watchOpenTasks(userId).asyncMap((localTasks) async {
        try {
          return await _decryptTasks(localTasks);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to decrypt tasks in watchTasks stream',
            error: error,
            stackTrace: stackTrace,
          );
          _captureRepositoryException(
            method: 'watchTasks.stream',
            error: error,
            stackTrace: stackTrace,
          );
          _auditAccess(
            'tasks.watchTasks',
            granted: false,
            reason: 'stream_error=${error.runtimeType}',
          );
          return const <domain.Task>[];
        }
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to create task watch stream',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'watchTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.watchTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return Stream.error(e, stack);
    }
  }

  @override
  Stream<List<domain.Task>> watchAllTasks() {
    try {
      final userId = _requireUserId(method: 'watchAllTasks');
      _auditAccess(
        'tasks.watchAllTasks',
        granted: true,
        reason: 'stream_start',
      );
      // Watch all non-deleted tasks (both open and completed)
      return (db.select(db.noteTasks)
            ..where((t) => t.deleted.equals(false) & t.userId.equals(userId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch()
          .asyncMap((localTasks) async {
            try {
              return await _decryptTasks(localTasks);
            } catch (error, stackTrace) {
              _logger.error(
                'Failed to decrypt tasks in watchAllTasks stream',
                error: error,
                stackTrace: stackTrace,
              );
              _captureRepositoryException(
                method: 'watchAllTasks.stream',
                error: error,
                stackTrace: stackTrace,
              );
              _auditAccess(
                'tasks.watchAllTasks',
                granted: false,
                reason: 'stream_error=${error.runtimeType}',
              );
              return const <domain.Task>[];
            }
          });
    } catch (e, stack) {
      _logger.error(
        'Failed to create all tasks watch stream',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'watchAllTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.watchAllTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return Stream.error(e, stack);
    }
  }

  /// Watch tasks for a specific note
  @override
  Stream<List<domain.Task>> watchTasksForNote(String noteId) {
    try {
      final userId = _requireUserId(
        method: 'watchTasksForNote',
        data: {'noteId': noteId},
      );
      _auditAccess(
        'tasks.watchTasksForNote',
        granted: true,
        reason: 'noteId=$noteId stream_start',
      );
      return db.watchTasksForNote(noteId, userId).asyncMap((localTasks) async {
        try {
          return await _decryptTasks(localTasks);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to decrypt tasks in watchTasksForNote stream',
            error: error,
            stackTrace: stackTrace,
            data: {'noteId': noteId},
          );
          _captureRepositoryException(
            method: 'watchTasksForNote.stream',
            error: error,
            stackTrace: stackTrace,
            data: {'noteId': noteId},
          );
          _auditAccess(
            'tasks.watchTasksForNote',
            granted: false,
            reason: 'stream_error=${error.runtimeType}',
          );
          return const <domain.Task>[];
        }
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to create task watch stream for note: $noteId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'watchTasksForNote',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      _auditAccess(
        'tasks.watchTasksForNote',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return Stream.error(e, stack);
    }
  }

  /// Get completed tasks
  @override
  Future<List<domain.Task>> getCompletedTasks({
    DateTime? since,
    int? limit,
  }) async {
    try {
      final userId = _requireUserId(
        method: 'getCompletedTasks',
        data: {'since': since?.toIso8601String(), 'limit': limit},
      );
      final localTasks = await db.getCompletedTasks(
        userId: userId,
        since: since,
        limit: limit,
      );
      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getCompletedTasks',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error(
        'Failed to get completed tasks',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getCompletedTasks',
        error: e,
        stackTrace: stack,
        data: {'since': since?.toIso8601String(), 'limit': limit},
      );
      _auditAccess(
        'tasks.getCompletedTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  /// Get overdue tasks
  @override
  Future<List<domain.Task>> getOverdueTasks() async {
    try {
      final userId = _requireUserId(method: 'getOverdueTasks');
      final localTasks = await db.getOverdueTasks(userId);
      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getOverdueTasks',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error('Failed to get overdue tasks', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getOverdueTasks',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'tasks.getOverdueTasks',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  /// Get tasks by date range
  @override
  Future<List<domain.Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final userId = _requireUserId(
        method: 'getTasksByDateRange',
        data: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );
      // Database method uses 'start' and 'end' parameters
      final localTasks = await db.getTasksByDateRange(
        userId: userId,
        start: start,
        end: end,
      );

      final tasks = await _decryptTasks(localTasks);
      _auditAccess(
        'tasks.getTasksByDateRange',
        granted: true,
        reason: 'count=${tasks.length}',
      );
      return tasks;
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks by date range',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTasksByDateRange',
        error: e,
        stackTrace: stack,
        data: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );
      _auditAccess(
        'tasks.getTasksByDateRange',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Task>[];
    }
  }

  /// Toggle task status (open <-> completed)
  @override
  Future<void> toggleTaskStatus(String id) async {
    try {
      final userId = _requireUserId(
        method: 'toggleTaskStatus',
        data: {'taskId': id},
      );
      await db.toggleTaskStatus(id, userId);
      final task = await db.getTaskById(id, userId: userId);

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: id,
        kind: 'upsert_task',
        payload: task != null ? jsonEncode({'noteId': task.noteId}) : null,
      );

      _logger.info('Toggled task status: $id');
      _auditAccess(
        'tasks.toggleTaskStatus',
        granted: true,
        reason: 'taskId=$id',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to toggle task status: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'toggleTaskStatus',
        error: e,
        stackTrace: stack,
        data: {'taskId': id},
      );
      _auditAccess(
        'tasks.toggleTaskStatus',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Delete all tasks for a note
  @override
  Future<void> deleteTasksForNote(String noteId) async {
    try {
      final userId = _requireUserId(
        method: 'deleteTasksForNote',
        data: {'noteId': noteId},
      );

      // Phase 1.1: Get tasks BEFORE deleting so we can enqueue sync operations
      final tasks = await db.getTasksForNote(noteId, userId: userId);

      // Soft delete all tasks with timestamps (batch update instead of hard delete)
      final now = DateTime.now().toUtc();
      final scheduledPurgeAt = now.add(const Duration(days: 30));

      await (db.update(
        db.noteTasks,
      )..where((t) => t.noteId.equals(noteId) & t.userId.equals(userId))).write(
        NoteTasksCompanion(
          deleted: Value(true),
          deletedAt: Value(now),
          scheduledPurgeAt: Value(scheduledPurgeAt),
          updatedAt: Value(now),
        ),
      );

      // Enqueue sync operation for each deleted task
      for (final task in tasks) {
        await _enqueuePendingOp(
          entityId: task.id,
          kind: 'upsert_task',
          payload: jsonEncode({'noteId': noteId}),
        );
      }

      _logger.info(
        'Deleted all tasks for note: $noteId (count=${tasks.length})',
      );
      _auditAccess(
        'tasks.deleteTasksForNote',
        granted: true,
        reason: 'noteId=$noteId count=${tasks.length}',
      );

      MutationEventBus.instance.emitNote(
        kind: MutationKind.updated,
        noteId: noteId,
        metadata: const {'tasksCleared': true},
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to delete tasks for note: $noteId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'deleteTasksForNote',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      _auditAccess(
        'tasks.deleteTasksForNote',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Get task statistics
  @override
  Future<Map<String, int>> getTaskStatistics() async {
    try {
      final allTasks = await getAllTasks();
      final completedTasks = allTasks.where(
        (t) => t.status == domain.TaskStatus.completed,
      );
      final pendingTasks = allTasks.where(
        (t) => t.status == domain.TaskStatus.pending,
      );
      final inProgressTasks = allTasks.where(
        (t) => t.status == domain.TaskStatus.inProgress,
      );
      final overdueTasks = allTasks.where(
        (t) =>
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime.now()) &&
            t.status != domain.TaskStatus.completed,
      );

      return {
        'total': allTasks.length,
        'completed': completedTasks.length,
        'pending': pendingTasks.length,
        'in_progress': inProgressTasks.length,
        'overdue': overdueTasks.length,
      };
    } catch (e, stack) {
      _logger.error(
        'Failed to get task statistics',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTaskStatistics',
        error: e,
        stackTrace: stack,
      );
      return const <String, int>{};
    }
  }

  /// Get tasks by priority
  @override
  Future<List<domain.Task>> getTasksByPriority(
    domain.TaskPriority priority,
  ) async {
    try {
      final allTasks = await getAllTasks();
      return allTasks.where((task) => task.priority == priority).toList();
    } catch (e, stack) {
      _logger.error(
        'Failed to get tasks by priority: $priority',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTasksByPriority',
        error: e,
        stackTrace: stack,
        data: {'priority': priority.name},
      );
      return const <domain.Task>[];
    }
  }

  /// Search tasks by content
  @override
  Future<List<domain.Task>> searchTasks(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllTasks();
      }

      final allTasks = await getAllTasks();
      final normalizedQuery = query.toLowerCase();

      return allTasks.where((task) {
        final matchesTitle = task.title.toLowerCase().contains(normalizedQuery);
        final matchesDescription =
            task.description?.toLowerCase().contains(normalizedQuery) ?? false;
        return matchesTitle || matchesDescription;
      }).toList();
    } catch (e, stack) {
      _logger.error(
        'Failed to search tasks with query: $query',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'searchTasks',
        error: e,
        stackTrace: stack,
        data: {'queryLength': query.length},
      );
      return const <domain.Task>[];
    }
  }

  /// Update task priority
  @override
  Future<void> updateTaskPriority(
    String id,
    domain.TaskPriority priority,
  ) async {
    try {
      final task = await getTaskById(id);
      if (task == null) {
        final missingError = StateError('Task not found');
        _logger.warning(
          'Attempted to update priority for non-existent task',
          data: {'taskId': id},
        );
        _captureRepositoryException(
          method: 'updateTaskPriority',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'taskId': id},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final updatedTask = task.copyWith(priority: priority);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error(
        'Failed to update task priority: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTaskPriority',
        error: e,
        stackTrace: stack,
        data: {'taskId': id, 'priority': priority.name},
      );
      rethrow;
    }
  }

  /// Update task due date
  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) async {
    try {
      final task = await getTaskById(id);
      if (task == null) {
        final missingError = StateError('Task not found');
        _logger.warning(
          'Attempted to update due date for non-existent task',
          data: {'taskId': id},
        );
        _captureRepositoryException(
          method: 'updateTaskDueDate',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'taskId': id},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final updatedTask = task.copyWith(dueDate: dueDate);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error(
        'Failed to update task due date: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTaskDueDate',
        error: e,
        stackTrace: stack,
        data: {'taskId': id, 'dueDate': dueDate?.toIso8601String()},
      );
      rethrow;
    }
  }

  /// Add tag to task
  @override
  Future<void> addTagToTask(String taskId, String tag) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) {
        final missingError = StateError('Task not found');
        _logger.warning(
          'Attempted to add tag to non-existent task',
          data: {'taskId': taskId, 'tag': tag},
        );
        _captureRepositoryException(
          method: 'addTagToTask',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'taskId': taskId, 'tag': tag},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final updatedTags = [...task.tags];
      if (!updatedTags.contains(tag)) {
        updatedTags.add(tag);
        final updatedTask = task.copyWith(tags: updatedTags);
        await updateTask(updatedTask);
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to add tag to task: $taskId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'addTagToTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'tag': tag},
      );
      rethrow;
    }
  }

  /// Remove tag from task
  @override
  Future<void> removeTagFromTask(String taskId, String tag) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) {
        final missingError = StateError('Task not found');
        _logger.warning(
          'Attempted to remove tag from non-existent task',
          data: {'taskId': taskId, 'tag': tag},
        );
        _captureRepositoryException(
          method: 'removeTagFromTask',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'taskId': taskId, 'tag': tag},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final updatedTags = task.tags.where((t) => t != tag).toList();
      final updatedTask = task.copyWith(tags: updatedTags);
      await updateTask(updatedTask);
    } catch (e, stack) {
      _logger.error(
        'Failed to remove tag from task: $taskId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'removeTagFromTask',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'tag': tag},
      );
      rethrow;
    }
  }

  /// Sync tasks with note content
  @override
  Future<void> syncTasksWithNoteContent(
    String noteId,
    String noteContent,
  ) async {
    try {
      await db.syncTasksWithNoteContent(noteId, noteContent);
      _logger.info('Synced tasks with note content: $noteId');
    } catch (e, stack) {
      _logger.error(
        'Failed to sync tasks with note content: $noteId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'syncTasksWithNoteContent',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId, 'contentLength': noteContent.length},
      );
      rethrow;
    }
  }

  /// Create subtask
  @override
  Future<domain.Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
    domain.TaskPriority priority = domain.TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    try {
      final parentTask = await getTaskById(parentTaskId);
      if (parentTask == null) {
        final missingError = StateError('Parent task not found');
        _logger.warning(
          'Attempted to create subtask for non-existent parent task',
          data: {'parentTaskId': parentTaskId},
        );
        _captureRepositoryException(
          method: 'createSubtask',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'parentTaskId': parentTaskId},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final now = DateTime.now().toUtc();
      final subtask = domain.Task(
        id: _uuid.v4(),
        noteId: parentTask.noteId,
        title: title,
        description: description,
        status: domain.TaskStatus.pending,
        priority: priority,
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        tags: [],
        metadata: {'parentTaskId': parentTaskId},
      );

      return await createTask(subtask);
    } catch (e, stack) {
      _logger.error(
        'Failed to create subtask for: $parentTaskId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createSubtask',
        error: e,
        stackTrace: stack,
        data: {'parentTaskId': parentTaskId},
      );
      rethrow;
    }
  }

  @override
  /// Get subtasks for a parent task
  /// OPTIMIZED: Uses efficient DB query instead of loading all tasks into memory
  /// Related: ARCHITECTURE_VIOLATIONS.md v1.1.0 - Production-grade service layer fix
  Future<List<domain.Task>> getSubtasks(String parentTaskId) async {
    final userId = _requireUserId(
      method: 'getSubtasks',
      data: {'parentTaskId': parentTaskId},
    );

    try {
      // Use efficient DB query with WHERE clause (not in-memory filtering)
      final dbTasks = await db.getOpenTasks(
        userId: userId,
        parentTaskId: parentTaskId,
      );

      // Decrypt and map to domain entities using existing helper
      final domainTasks = await _decryptTasks(dbTasks);

      _logger.info(
        '[TaskRepository] Retrieved ${domainTasks.length} subtasks for parent: $parentTaskId',
      );
      return domainTasks;
    } catch (e, stack) {
      _logger.error(
        'Failed to get subtasks for: $parentTaskId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getSubtasks',
        error: e,
        stackTrace: stack,
        data: {'parentTaskId': parentTaskId},
      );
      return const <domain.Task>[];
    }
  }

  // Private helper methods

  /// Map domain TaskStatus to database TaskStatus
  TaskStatus _mapStatusToDb(domain.TaskStatus status) {
    switch (status) {
      case domain.TaskStatus.pending:
        return TaskStatus.open;
      case domain.TaskStatus.inProgress:
        return TaskStatus.open; // Map in-progress to open in db
      case domain.TaskStatus.completed:
        return TaskStatus.completed;
      case domain.TaskStatus.cancelled:
        return TaskStatus.cancelled;
    }
  }

  /// Map domain TaskPriority to database TaskPriority
  TaskPriority _mapPriorityToDb(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return TaskPriority.low;
      case domain.TaskPriority.medium:
        return TaskPriority.medium;
      case domain.TaskPriority.high:
        return TaskPriority.high;
      case domain.TaskPriority.urgent:
        return TaskPriority.urgent;
    }
  }

  @override
  Future<int> anonymizeAllTasksForUser(String userId) async {
    try {
      _logger.info(
        'GDPR: Starting task anonymization for user',
        data: {'userId': userId},
      );

      // Call Supabase RPC function for atomic anonymization
      // This executes a DoD 5220.22-M compliant overwrite of all encrypted data
      final response = await client.rpc<List<Map<String, dynamic>>>(
        'anonymize_user_tasks',
        params: {'target_user_id': userId},
      );

      // Extract count from response
      final count = response.isNotEmpty
          ? (response.first['count'] as int? ?? 0)
          : 0;

      _logger.info(
        'GDPR: Task anonymization complete',
        data: {'userId': userId, 'tasksAnonymized': count},
      );

      // Invalidate local cache - tasks are now tombstoned
      await (db.delete(
        db.noteTasks,
      )..where((tbl) => tbl.userId.equals(userId))).go();

      return count;
    } catch (error, stackTrace) {
      _logger.error(
        'GDPR: Task anonymization failed',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      _captureRepositoryException(
        method: 'anonymizeAllTasksForUser',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      rethrow;
    }
  }
}
