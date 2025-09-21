/// Adapter to allow task widgets to work with both UI and database task models
///
/// This adapter provides a migration path for widgets currently using the
/// deprecated UiNoteTask model to work with the actual database NoteTask model.

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_task.dart';
import 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart';
import 'package:flutter/material.dart';

/// Adapter widget that accepts either a UiNoteTask or a database NoteTask
/// and provides it to child widgets in the expected UiNoteTask format
class TaskWidgetAdapter extends StatelessWidget {
  final NoteTask? dbTask;
  final UiNoteTask? uiTask;
  final Widget Function(UiNoteTask task) builder;

  const TaskWidgetAdapter({
    super.key,
    this.dbTask,
    this.uiTask,
    required this.builder,
  }) : assert(dbTask != null || uiTask != null,
            'Either dbTask or uiTask must be provided');

  @override
  Widget build(BuildContext context) {
    final task = uiTask ?? TaskModelConverter.dbTaskToUiTask(dbTask!);
    return builder(task);
  }
}

/// Task callbacks that work with both models
abstract class UnifiedTaskCallbacks {
  /// Called when task status changes
  Future<void> onStatusChanged(String taskId, TaskStatus newStatus);

  /// Called when task priority changes
  Future<void> onPriorityChanged(String taskId, TaskPriority newPriority);

  /// Called when task content is edited
  Future<void> onContentChanged(String taskId, String newContent);

  /// Called when task is deleted
  Future<void> onDeleted(String taskId);

  /// Called to edit task details
  void onEdit(String taskId);

  /// Called when due date changes
  Future<void> onDueDateChanged(String taskId, DateTime? newDate);
}

/// Adapter for task callbacks that converts between UI and database models
class TaskCallbacksAdapter {
  final UnifiedTaskCallbacks callbacks;

  const TaskCallbacksAdapter(this.callbacks);

  /// Convert UI callbacks to work with database models
  void onUiStatusChanged(String taskId, UiTaskStatus status) {
    callbacks.onStatusChanged(
        taskId, TaskModelConverter.uiStatusToDbStatus(status));
  }

  void onUiPriorityChanged(String taskId, UiTaskPriority priority) {
    final dbPriority = TaskModelConverter.uiPriorityToDbPriority(priority);
    if (dbPriority != null) {
      callbacks.onPriorityChanged(taskId, dbPriority);
    }
  }

  void onContentChanged(String taskId, String content) {
    callbacks.onContentChanged(taskId, content);
  }

  void onDeleted(String taskId) {
    callbacks.onDeleted(taskId);
  }

  void onEdit(String taskId) {
    callbacks.onEdit(taskId);
  }

  void onDueDateChanged(String taskId, DateTime? date) {
    callbacks.onDueDateChanged(taskId, date);
  }
}
