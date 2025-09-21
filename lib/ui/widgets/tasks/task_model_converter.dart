/// Converter utility to map between UI task models and database task models
///
/// This provides conversion functions to map between the temporary UI models
/// and the actual Drift-backed database models.

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_task.dart';

class TaskModelConverter {
  /// Convert UI task status to database task status
  static TaskStatus uiStatusToDbStatus(UiTaskStatus uiStatus) {
    switch (uiStatus) {
      case UiTaskStatus.pending:
      case UiTaskStatus.inProgress:
        return TaskStatus.open;
      case UiTaskStatus.completed:
        return TaskStatus.completed;
      case UiTaskStatus.cancelled:
        return TaskStatus.cancelled;
    }
  }

  /// Convert database task status to UI task status
  static UiTaskStatus dbStatusToUiStatus(TaskStatus dbStatus) {
    switch (dbStatus) {
      case TaskStatus.open:
        return UiTaskStatus.pending;
      case TaskStatus.completed:
        return UiTaskStatus.completed;
      case TaskStatus.cancelled:
        return UiTaskStatus.cancelled;
    }
  }

  /// Convert UI task priority to database task priority
  static TaskPriority? uiPriorityToDbPriority(UiTaskPriority uiPriority) {
    switch (uiPriority) {
      case UiTaskPriority.none:
        return TaskPriority.low; // Map 'none' to 'low' as closest equivalent
      case UiTaskPriority.low:
        return TaskPriority.low;
      case UiTaskPriority.medium:
        return TaskPriority.medium;
      case UiTaskPriority.high:
        return TaskPriority.high;
      case UiTaskPriority.urgent:
        return TaskPriority.urgent;
    }
  }

  /// Convert database task priority to UI task priority
  static UiTaskPriority dbPriorityToUiPriority(TaskPriority dbPriority) {
    switch (dbPriority) {
      case TaskPriority.low:
        return UiTaskPriority.low;
      case TaskPriority.medium:
        return UiTaskPriority.medium;
      case TaskPriority.high:
        return UiTaskPriority.high;
      case TaskPriority.urgent:
        return UiTaskPriority.urgent;
    }
  }

  /// Convert database NoteTask to UI NoteTask
  static UiNoteTask dbTaskToUiTask(NoteTask dbTask) {
    return UiNoteTask(
      id: dbTask.id,
      content: dbTask.content,
      status: dbStatusToUiStatus(dbTask.status),
      priority: dbPriorityToUiPriority(dbTask.priority),
      dueDate: dbTask.dueDate,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
      tags: dbTask.labels != null
          ? (dbTask.labels!.split(',').where((s) => s.isNotEmpty).toList())
          : [],
      subtasks: [], // Subtasks would need to be loaded separately
      noteId: dbTask.noteId,
      parentTaskId: dbTask.parentTaskId,
    );
  }

  /// Convert UI NoteTask to database NoteTasksCompanion for insertion/update
  static NoteTasksCompanion uiTaskToDbCompanion(UiNoteTask uiTask) {
    return NoteTasksCompanion.insert(
      id: uiTask.id,
      noteId: uiTask.noteId ?? '',
      content: uiTask.content,
      status: Value(uiStatusToDbStatus(uiTask.status)),
      priority:
          Value(uiPriorityToDbPriority(uiTask.priority) ?? TaskPriority.medium),
      dueDate: Value(uiTask.dueDate),
      createdAt: Value(uiTask.createdAt),
      updatedAt: Value(uiTask.updatedAt),
      parentTaskId: Value(uiTask.parentTaskId),
      labels: Value(uiTask.tags.isNotEmpty ? uiTask.tags.join(',') : null),
      contentHash: '', // Will be computed by the database or service layer
    );
  }
}
