import 'dart:convert';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;

/// Converter utility for converting between NoteTask and domain.Task
class TaskConverter {
  /// Convert NoteTask (infrastructure) to domain.Task
  static domain.Task fromLocal(NoteTask local, {List<String>? tags}) {
    return domain.Task(
      id: local.id,
      noteId: local.noteId,
      title: local.content, // NoteTask uses 'content' for the task text
      content: local.notes, // Optional extended content from notes field
      status: _convertStatusToDomain(local.status),
      priority: _convertPriorityToDomain(local.priority),
      dueDate: local.dueDate,
      completedAt: local.completedAt,
      tags: tags ?? _parseLabelsToTags(local.labels),
      metadata: _buildMetadataFromLocal(local),
    );
  }

  /// Convert domain.Task to NoteTask
  static NoteTask toLocal(domain.Task task) {
    return NoteTask(
      id: task.id,
      noteId: task.noteId,
      content: task.title, // NoteTask uses 'content' for the task text
      contentHash: task.title.hashCode.toString(),
      status: _convertStatusToLocal(task.status),
      priority: _convertPriorityToLocal(task.priority),
      dueDate: task.dueDate,
      completedAt: task.completedAt,
      position: 0, // Default position
      notes: task.content, // Store extended content in notes field
      labels: _tagsToLabelsJson(task.tags), // Convert tags to JSON labels
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deleted: false,
    );
  }

  /// Convert List<NoteTask> to List<domain.Task>
  static List<domain.Task> fromLocalList(List<NoteTask> localTasks, {Map<String, List<String>>? tagsMap}) {
    return localTasks.map((local) => fromLocal(
      local,
      tags: tagsMap?[local.id],
    )).toList();
  }

  /// Convert List<domain.Task> to List<NoteTask>
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

  /// Convert local TaskStatus to domain TaskStatus
  static domain.TaskStatus _convertStatusToDomain(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return domain.TaskStatus.pending;
      case TaskStatus.completed:
        return domain.TaskStatus.completed;
      case TaskStatus.cancelled:
        return domain.TaskStatus.cancelled;
      default:
        return domain.TaskStatus.pending;
    }
  }

  /// Convert domain TaskStatus to local TaskStatus
  static TaskStatus _convertStatusToLocal(domain.TaskStatus status) {
    switch (status) {
      case domain.TaskStatus.pending:
        return TaskStatus.open;
      case domain.TaskStatus.inProgress:
        return TaskStatus.open; // Local doesn't have inProgress, map to open
      case domain.TaskStatus.completed:
        return TaskStatus.completed;
      case domain.TaskStatus.cancelled:
        return TaskStatus.cancelled;
    }
  }

  /// Convert local TaskPriority to domain TaskPriority
  static domain.TaskPriority _convertPriorityToDomain(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return domain.TaskPriority.low;
      case TaskPriority.medium:
        return domain.TaskPriority.medium;
      case TaskPriority.high:
        return domain.TaskPriority.high;
      case TaskPriority.urgent:
        return domain.TaskPriority.urgent;
    }
  }

  /// Convert domain TaskPriority to local TaskPriority
  static TaskPriority _convertPriorityToLocal(domain.TaskPriority priority) {
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
    if (task is domain.Task) {
      return task.title;
    } else if (task is NoteTask) {
      return task.content;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
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

  /// Parse labels JSON string to tags list
  static List<String> _parseLabelsToTags(String? labels) {
    if (labels == null || labels.isEmpty) return [];
    try {
      final decoded = jsonDecode(labels);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (e) {
      // If parsing fails, return empty list
    }
    return [];
  }

  /// Convert tags list to labels JSON string
  static String? _tagsToLabelsJson(List<String> tags) {
    if (tags.isEmpty) return null;
    try {
      return jsonEncode(tags);
    } catch (e) {
      return null;
    }
  }

  /// Build metadata map from NoteTask fields
  static Map<String, dynamic> _buildMetadataFromLocal(NoteTask local) {
    final metadata = <String, dynamic>{};

    if (local.position > 0) metadata['position'] = local.position;
    if (local.contentHash.isNotEmpty) metadata['contentHash'] = local.contentHash;
    if (local.reminderId != null) metadata['reminderId'] = local.reminderId;
    if (local.completedBy != null) metadata['completedBy'] = local.completedBy;
    if (local.estimatedMinutes != null) metadata['estimatedMinutes'] = local.estimatedMinutes;
    if (local.actualMinutes != null) metadata['actualMinutes'] = local.actualMinutes;
    if (local.parentTaskId != null) metadata['parentTaskId'] = local.parentTaskId;

    return metadata;
  }
}