import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for task synchronization
class TaskRepository {
  TaskRepository({
    required AppDb database,
    required SupabaseClient supabase,
  })  : _db = database,
        _supabase = supabase;

  final AppDb _db;
  final SupabaseClient _supabase;

  /// Sync tasks with backend
  Future<void> syncTasks({bool forceSync = false}) async {
    try {
      // Get all local tasks that need syncing
      final localTasks = await _db.select(_db.noteTasks).get();
      
      // Get user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Upload local tasks to backend
      for (final task in localTasks) {
        await _uploadTask(task);
      }

      // Download tasks from backend
      await _downloadTasks();

      // Handle pending operations for tasks
      await _processPendingTaskOperations();
    } catch (e) {
      debugPrint('Error syncing tasks: $e');
      rethrow;
    }
  }

  /// Upload a single task to backend
  Future<void> _uploadTask(NoteTask task) async {
    try {
      final taskData = {
        'id': task.id,
        'note_id': task.noteId,
        'content': task.content,
        'status': task.status.index,
        'priority': task.priority.index,
        'due_date': task.dueDate?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'completed_by': task.completedBy,
        'position': task.position,
        'content_hash': task.contentHash,
        'reminder_id': task.reminderId,
        'labels': task.labels,
        'notes': task.notes,
        'estimated_minutes': task.estimatedMinutes,
        'actual_minutes': task.actualMinutes,
        'parent_task_id': task.parentTaskId,
        'created_at': task.createdAt.toIso8601String(),
        'updated_at': task.updatedAt.toIso8601String(),
        'deleted': task.deleted,
        'user_id': _supabase.auth.currentUser!.id,
      };

      await _supabase
          .from('note_tasks')
          .upsert(taskData, onConflict: 'id');
    } catch (e) {
      debugPrint('Error uploading task ${task.id}: $e');
      // Add to pending operations for retry
      await _addPendingTaskOperation(task, 'upsert');
    }
  }

  /// Download tasks from backend
  Future<void> _downloadTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('note_tasks')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final tasks = response as List<dynamic>;

      for (final taskData in tasks) {
        await _saveTaskLocally(taskData as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error downloading tasks: $e');
      rethrow;
    }
  }

  /// Save a task from backend to local database
  Future<void> _saveTaskLocally(Map<String, dynamic> taskData) async {
    try {
      final task = NoteTasksCompanion.insert(
        id: taskData['id'] as String,
        noteId: taskData['note_id'] as String,
        content: taskData['content'] as String,
        contentHash: taskData['content_hash'] as String,
        status: Value(TaskStatus.values[(taskData['status'] as int?) ?? 0]),
        priority: Value(TaskPriority.values[(taskData['priority'] as int?) ?? 1]),
        dueDate: taskData['due_date'] != null
            ? Value(DateTime.parse(taskData['due_date'] as String))
            : const Value.absent(),
        completedAt: taskData['completed_at'] != null
            ? Value(DateTime.parse(taskData['completed_at'] as String))
            : const Value.absent(),
        completedBy: Value(taskData['completed_by'] as String?),
        position: Value((taskData['position'] as int?) ?? 0),
        reminderId: Value(taskData['reminder_id'] as int?),
        labels: Value(taskData['labels'] as String?),
        notes: Value(taskData['notes'] as String?),
        estimatedMinutes: Value(taskData['estimated_minutes'] as int?),
        actualMinutes: Value(taskData['actual_minutes'] as int?),
        parentTaskId: Value(taskData['parent_task_id'] as String?),
        createdAt: Value(DateTime.parse(taskData['created_at'] as String)),
        updatedAt: Value(DateTime.parse(taskData['updated_at'] as String)),
        deleted: Value((taskData['deleted'] as bool?) ?? false),
      );

      await _db.into(_db.noteTasks).insertOnConflictUpdate(task);
    } catch (e) {
      debugPrint('Error saving task locally: $e');
    }
  }

  /// Add a pending operation for a task
  Future<void> _addPendingTaskOperation(
    NoteTask task,
    String operation,
  ) async {
    final payload = {
      'task': task.toJson(),
      'operation': operation,
    };

    await _db.into(_db.pendingOps).insert(
          PendingOpsCompanion.insert(
            entityId: task.id,
            kind: 'task_$operation',
            payload: Value(jsonEncode(payload)),
          ),
        );
  }

  /// Process pending task operations
  Future<void> _processPendingTaskOperations() async {
    final pendingOps = await _db.select(_db.pendingOps).get();
    final taskOps = pendingOps.where((op) => op.kind.startsWith('task_')).toList();

    for (final op in taskOps) {
      try {
        if (op.payload != null) {
          final payload = jsonDecode(op.payload!) as Map<String, dynamic>;
          final taskData = payload['task'] as Map<String, dynamic>;
          
          switch (op.kind) {
            case 'task_upsert':
              await _uploadTaskData(taskData);
              break;
            case 'task_delete':
              await _deleteTaskOnBackend(op.entityId);
              break;
          }
        }

        // Remove pending operation after successful processing
        await (_db.delete(_db.pendingOps)..where((o) => o.id.equals(op.id)))
            .go();
      } catch (e) {
        debugPrint('Error processing pending operation ${op.id}: $e');
      }
    }
  }

  /// Upload task data to backend
  Future<void> _uploadTaskData(Map<String, dynamic> taskData) async {
    taskData['user_id'] = _supabase.auth.currentUser!.id;
    await _supabase.from('note_tasks').upsert(taskData, onConflict: 'id');
  }

  /// Delete a task on backend
  Future<void> _deleteTaskOnBackend(String taskId) async {
    await _supabase
        .from('note_tasks')
        .update({'deleted': true})
        .eq('id', taskId);
  }

  /// Create a task
  Future<void> createTask(NoteTask task) async {
    // Save locally
    await _db.createTask(
      NoteTasksCompanion.insert(
        id: task.id,
        noteId: task.noteId,
        content: task.content,
        contentHash: task.contentHash,
        status: Value(task.status),
        priority: Value(task.priority),
        dueDate: Value(task.dueDate),
        position: Value(task.position),
      ),
    );

    // Sync with backend
    await _uploadTask(task);
  }

  /// Update a task
  Future<void> updateTask(String taskId, NoteTasksCompanion updates) async {
    // Update locally
    await _db.updateTask(taskId, updates);

    // Get updated task and sync
    final task = await _db.getTaskById(taskId);
    if (task != null) {
      await _uploadTask(task);
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    // Mark as deleted locally
    await _db.updateTask(
      taskId,
      NoteTasksCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Delete on backend
    await _deleteTaskOnBackend(taskId);
  }

  /// Listen to realtime task updates
  StreamSubscription? listenToTaskUpdates({
    required String noteId,
    required Function(Map<String, dynamic>) onTaskUpdate,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    return _supabase
        .from('note_tasks')
        .stream(primaryKey: ['id'])
        .listen((data) {
          for (final task in data) {
            if (task['note_id'] == noteId && task['user_id'] == userId) {
              onTaskUpdate(task);
              _saveTaskLocally(task);
            }
          }
        });
  }
}

/// Extension to convert NoteTask to JSON
extension NoteTaskExtension on NoteTask {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'content': content,
      'status': status.index,
      'priority': priority.index,
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'position': position,
      'content_hash': contentHash,
      'reminder_id': reminderId,
      'labels': labels,
      'notes': notes,
      'estimated_minutes': estimatedMinutes,
      'actual_minutes': actualMinutes,
      'parent_task_id': parentTaskId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }
}

// Providers are defined in lib/providers.dart
