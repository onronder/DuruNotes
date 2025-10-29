import 'dart:convert';

import 'package:duru_notes/core/utils/hash_utils.dart';

import '../../data/local/app_db.dart';
import '../../domain/entities/task.dart' as domain;

/// Maps between domain Task entity and infrastructure NoteTask
/// NOTE: This mapper works with already encrypted/decrypted data.
/// Encryption/decryption happens at the repository level.
class TaskMapper {
  /// Convert infrastructure NoteTask to domain Task
  /// Note: content, notes, and labels are expected to be already decrypted by the repository
  static domain.Task toDomain(
    NoteTask local, {
    required String content,
    String? notes,
    String? labels,
  }) {
    return domain.Task(
      id: local.id,
      noteId: local.noteId,
      title: content, // Use decrypted content as title
      description: notes, // Use decrypted notes as description
      status: _mapStatus(local.status),
      priority: _mapPriority(local.priority),
      dueDate: local.dueDate,
      completedAt: local.completedAt,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
      tags: _parseLabels(labels),
      metadata: _buildMetadata(local),
    );
  }

  /// Convert domain Task to infrastructure NoteTask
  /// Note: content, notes, and labels should be encrypted before passing to this method
  static NoteTask toInfrastructure(
    domain.Task domain, {
    required String userId,
    required String contentEncrypted,
    String? notesEncrypted,
    String? labelsEncrypted,
  }) {
    return NoteTask(
      id: domain.id,
      noteId: domain.noteId,
      userId: userId,
      contentEncrypted: contentEncrypted, // Encrypted content
      status: mapStatusToDb(domain.status),
      priority: mapPriorityToDb(domain.priority),
      dueDate: domain.dueDate,
      completedAt: domain.completedAt,
      completedBy: null, // Set to null by default
      position: 0, // Default position
      contentHash: stableTaskHash(domain.noteId, domain.title),
      reminderId: null, // No reminder by default
      labelsEncrypted: labelsEncrypted, // Encrypted labels
      notesEncrypted: notesEncrypted, // Encrypted notes
      estimatedMinutes: _extractEstimatedMinutes(domain.metadata),
      actualMinutes: _extractActualMinutes(domain.metadata),
      parentTaskId: _extractParentTaskId(domain.metadata),
      createdAt: domain.createdAt,
      updatedAt: domain.updatedAt,
      deleted: false, // Tasks are not deleted by default
      encryptionVersion: 1, // Mark as encrypted
    );
  }

  // Note: List conversion methods removed - repositories handle iteration
  // and decryption/encryption for each task individually

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
  static TaskStatus mapStatusToDb(domain.TaskStatus status) {
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
  static TaskPriority mapPriorityToDb(domain.TaskPriority priority) {
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
    metadata['createdAt'] = local.createdAt.toIso8601String();
    metadata['updatedAt'] = local.updatedAt.toIso8601String();

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
