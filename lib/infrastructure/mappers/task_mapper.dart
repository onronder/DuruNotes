import 'dart:convert';

import '../../data/local/app_db.dart';
import '../../domain/entities/task.dart' as domain;

class TaskMapper {
  static domain.Task toDomain(NoteTask local) {
    return domain.Task(
      id: local.id,
      noteId: local.noteId,
      title: local.content, // Use content as title
      description: local.notes, // Use notes as description
      status: _mapStatus(local.status),
      priority: _mapPriority(local.priority),
      dueDate: local.dueDate,
      completedAt: local.completedAt,
      tags: _parseLabels(local.labels),
      metadata: _buildMetadata(local),
    );
  }

  static NoteTask toInfrastructure(domain.Task domain) {
    return NoteTask(
      id: domain.id,
      noteId: domain.noteId,
      content: domain.title, // Map title to content
      status: _mapStatusToDb(domain.status),
      priority: _mapPriorityToDb(domain.priority),
      dueDate: domain.dueDate,
      completedAt: domain.completedAt,
      completedBy: null, // Set to null by default
      position: 0, // Default position
      contentHash: domain.title.hashCode.toString(), // Simple hash
      reminderId: null, // No reminder by default
      labels: _encodeLabels(domain.tags),
      notes: domain.description,
      estimatedMinutes: _extractEstimatedMinutes(domain.metadata),
      actualMinutes: _extractActualMinutes(domain.metadata),
      parentTaskId: _extractParentTaskId(domain.metadata),
      createdAt: DateTime.now(), // Will be overridden by database if exists
      updatedAt: DateTime.now(), // Will be overridden by database
      deleted: false, // Tasks are not deleted by default
    );
  }

  static List<domain.Task> toDomainList(List<NoteTask> locals) {
    return locals.map((local) => toDomain(local)).toList();
  }

  static List<NoteTask> toInfrastructureList(List<domain.Task> domains) {
    return domains.map((domain) => toInfrastructure(domain)).toList();
  }

  /// Map database TaskStatus to domain TaskStatus
  static domain.TaskStatus _mapStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return domain.TaskStatus.pending;
      case TaskStatus.completed:
        return domain.TaskStatus.completed;
      case TaskStatus.cancelled:
        return domain.TaskStatus.cancelled;
    }
  }

  /// Map domain TaskStatus to database TaskStatus
  static TaskStatus _mapStatusToDb(domain.TaskStatus status) {
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

  /// Map database TaskPriority to domain TaskPriority
  static domain.TaskPriority _mapPriority(TaskPriority priority) {
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

  /// Map domain TaskPriority to database TaskPriority
  static TaskPriority _mapPriorityToDb(domain.TaskPriority priority) {
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

  /// Parse labels JSON string to tags list
  static List<String> _parseLabels(String? labels) {
    if (labels == null || labels.isEmpty) {
      return <String>[];
    }

    try {
      final decoded = json.decode(labels);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return <String>[];
    } catch (e) {
      return <String>[];
    }
  }

  /// Encode tags list to labels JSON string
  static String? _encodeLabels(List<String> tags) {
    if (tags.isEmpty) return null;

    try {
      return json.encode(tags);
    } catch (e) {
      return null;
    }
  }

  /// Build metadata map from NoteTask fields
  static Map<String, dynamic> _buildMetadata(NoteTask local) {
    final metadata = <String, dynamic>{};

    if (local.estimatedMinutes != null) {
      metadata['estimatedMinutes'] = local.estimatedMinutes;
    }
    if (local.actualMinutes != null) {
      metadata['actualMinutes'] = local.actualMinutes;
    }
    if (local.parentTaskId != null) {
      metadata['parentTaskId'] = local.parentTaskId;
    }
    if (local.reminderId != null) {
      metadata['reminderId'] = local.reminderId;
    }

    metadata['position'] = local.position;
    metadata['contentHash'] = local.contentHash;

    if (local.completedBy != null) {
      metadata['completedBy'] = local.completedBy;
    }

    return metadata;
  }

  /// Extract estimated minutes from metadata
  static int? _extractEstimatedMinutes(Map<String, dynamic> metadata) {
    return metadata['estimatedMinutes'] as int?;
  }

  /// Extract actual minutes from metadata
  static int? _extractActualMinutes(Map<String, dynamic> metadata) {
    return metadata['actualMinutes'] as int?;
  }

  /// Extract parent task ID from metadata
  static String? _extractParentTaskId(Map<String, dynamic> metadata) {
    return metadata['parentTaskId'] as String?;
  }
}