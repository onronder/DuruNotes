import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;

/// DEPRECATED: This converter is no longer compatible with encrypted fields.
///
/// Post-encryption migration, all conversions between NoteTask and domain.Task
/// must go through infrastructure/mappers/task_mapper.dart, which properly handles
/// encryption/decryption at the repository layer.
///
/// This file should not be used in new code and will be removed after migration.
@Deprecated(
  'Use infrastructure/mappers/task_mapper.dart instead. This converter no longer supports encrypted fields after encryption migration.',
)
class TaskConverter {
  /// Convert NoteTask (infrastructure) to domain.Task
  static domain.Task fromLocal(NoteTask local, {List<String>? tags}) {
    throw UnsupportedError(
      'TaskConverter.fromLocal is deprecated and no longer supported after encryption migration. '
      'Use infrastructure/mappers/task_mapper.dart instead, which properly handles encryption/decryption.',
    );
  }

  /// Convert domain.Task to NoteTask
  static NoteTask toLocal(domain.Task task) {
    throw UnsupportedError(
      'TaskConverter.toLocal is deprecated and no longer supported after encryption migration. '
      'Use infrastructure/mappers/task_mapper.dart instead, which properly handles encryption/decryption.',
    );
  }

  /// Convert `List<NoteTask>` to `List<domain.Task>`
  static List<domain.Task> fromLocalList(
    List<NoteTask> localTasks, {
    Map<String, List<String>>? tagsMap,
  }) {
    return localTasks
        .map((local) => fromLocal(local, tags: tagsMap?[local.id]))
        .toList();
  }

  /// Convert `List<domain.Task>` to `List<NoteTask>`
  static List<NoteTask> toLocalList(List<domain.Task> domainTasks) {
    return domainTasks.map((task) => toLocal(task)).toList();
  }

  /// Smart conversion that handles both types
  static domain.Task ensureDomainTask(dynamic task, {List<String>? tags}) {
    if (task is domain.Task) {
      return task;
    } else if (task is NoteTask) {
      return fromLocal(task, tags: tags);
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Smart conversion that handles both types to NoteTask
  static NoteTask ensureLocalTask(dynamic task) {
    if (task is NoteTask) {
      return task;
    } else if (task is domain.Task) {
      return toLocal(task);
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Get ID from any task type
  static String getTaskId(dynamic task) {
    if (task is domain.Task) {
      return task.id;
    } else if (task is NoteTask) {
      return task.id;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Get title from any task type
  static String getTaskTitle(dynamic task) {
    throw UnsupportedError(
      'TaskConverter.getTaskTitle is deprecated. NoteTask now uses encrypted fields. '
      'Use infrastructure/mappers/task_mapper.dart with encryption service instead.',
    );
  }

  /// Check if task is completed
  static bool isTaskCompleted(dynamic task) {
    if (task is domain.Task) {
      return task.status == domain.TaskStatus.completed;
    } else if (task is NoteTask) {
      return task.status == TaskStatus.completed;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }
}
