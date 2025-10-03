import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adapter to enable services to work with both local and domain models
class ServiceAdapter {
  ServiceAdapter({
    required this.db,
    required this.client,
    required this.useDomainModels,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final bool useDomainModels;
  final AppLogger _logger;

  /// Process note data for services
  dynamic processNote(dynamic note) {
    if (useDomainModels) {
      // Convert to domain if needed
      if (note is LocalNote) {
        return NoteMapper.toDomain(note);
      }
      return note as domain.Note;
    } else {
      // Convert to local if needed
      if (note is domain.Note) {
        return NoteMapper.toInfrastructure(note);
      }
      return note as LocalNote;
    }
  }

  /// Process task data for services
  dynamic processTask(dynamic task) {
    if (useDomainModels) {
      // Convert to domain if needed
      if (task is NoteTask) {
        return TaskMapper.toDomain(task);
      }
      return task as domain.Task;
    } else {
      // Convert to local if needed
      if (task is domain.Task) {
        return TaskMapper.toInfrastructure(task);
      }
      return task as NoteTask;
    }
  }

  /// Process folder data for services
  dynamic processFolder(dynamic folder) {
    if (useDomainModels) {
      // Convert to domain if needed
      if (folder is LocalFolder) {
        return FolderMapper.toDomain(folder);
      }
      return folder as domain.Folder;
    } else {
      // Convert to local if needed
      if (folder is domain.Folder) {
        return FolderMapper.toInfrastructure(folder);
      }
      return folder as LocalFolder;
    }
  }

  /// Process a list of notes
  List<dynamic> processNotes(List<dynamic> notes) {
    return notes.map((note) => processNote(note)).toList();
  }

  /// Process a list of tasks
  List<dynamic> processTasks(List<dynamic> tasks) {
    return tasks.map((task) => processTask(task)).toList();
  }

  /// Process a list of folders
  List<dynamic> processFolders(List<dynamic> folders) {
    return folders.map((folder) => processFolder(folder)).toList();
  }

  /// Get note data for sync
  Map<String, dynamic> getNoteDataForSync(dynamic note) {
    if (note is domain.Note) {
      return {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'folder_id': note.folderId,
        'is_pinned': note.isPinned,
        'version': note.version,
        'tags': note.tags,
        'updated_at': note.updatedAt.toIso8601String(),
        'user_id': note.userId,
        'deleted': note.deleted,
        'note_type': note.noteType.index,
      };
    } else if (note is LocalNote) {
      // LocalNote only has: id, title, body, updatedAt, deleted, encryptedMetadata,
      // isPinned, noteType, version, userId, attachmentMeta, metadata
      // It does NOT have: folderId, starred, archived, color, createdAt, tags (tags are in separate table)
      return {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'is_pinned': note.isPinned,
        'version': note.version,
        'updated_at': note.updatedAt.toIso8601String(),
        'user_id': note.userId,
        'deleted': note.deleted,
        'note_type': note.noteType.index,
      };
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get task data for sync
  Map<String, dynamic> getTaskDataForSync(dynamic task) {
    if (task is domain.Task) {
      return {
        'id': task.id,
        'note_id': task.noteId,
        'content': task.title,
        'status': _mapDomainTaskStatus(task.status),
        'priority': _mapDomainTaskPriority(task.priority),
        'due_date': task.dueDate?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'notes': task.description,
        'tags': task.tags,
      };
    } else if (task is NoteTask) {
      return {
        'id': task.id,
        'note_id': task.noteId,
        'content': task.content,
        'status': task.status.name,
        'priority': task.priority.name,
        'due_date': task.dueDate?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'notes': task.notes,
        'labels': task.labels,
      };
    }
    throw ArgumentError('Unknown task type: ${task.runtimeType}');
  }

  /// Get folder data for sync
  Map<String, dynamic> getFolderDataForSync(dynamic folder) {
    if (folder is domain.Folder) {
      return {
        'id': folder.id,
        'name': folder.name,
        'parent_id': folder.parentId,
        'color': folder.color,
        'icon': folder.icon,
        'sort_order': folder.sortOrder,
        'created_at': folder.createdAt.toIso8601String(),
        'updated_at': folder.updatedAt.toIso8601String(),
      };
    } else if (folder is LocalFolder) {
      return {
        'id': folder.id,
        'name': folder.name,
        'parent_id': folder.parentId,
        'color': folder.color,
        'icon': folder.icon,
        'sort_order': folder.sortOrder,
        'created_at': folder.createdAt.toIso8601String(),
        'updated_at': folder.updatedAt.toIso8601String(),
      };
    }
    throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
  }

  /// Create note from sync data
  dynamic createNoteFromSync(Map<String, dynamic> data) {
    if (useDomainModels) {
      return domain.Note(
        id: data['id'] as String,
        title: (data['title'] ?? '') as String,
        body: (data['body'] ?? data['content'] ?? '') as String,
        folderId: data['folder_id'] as String?,
        isPinned: (data['is_pinned'] ?? false) as bool,
        version: (data['version'] ?? 1) as int,
        tags: data['tags'] != null
            ? List<String>.from(data['tags'] as List<dynamic>)
            : const <String>[],
        links: [], // Links need to be populated separately
        updatedAt: DateTime.parse(data['updated_at'] as String),
        userId: (data['user_id'] ?? '') as String,
        deleted: (data['deleted'] ?? false) as bool,
        noteType: data['note_type'] != null
            ? NoteKind.values[data['note_type'] as int]
            : NoteKind.note,
        encryptedMetadata: data['encrypted_metadata'] as String?,
        attachmentMeta: data['attachment_meta'] as String?,
        metadata: data['metadata'] as String?,
      );
    } else {
      // For local model, we'd need to create using companion
      // This is handled by the repository layer
      _logger.warning('Creating LocalNote from sync should be handled by repository');
      return data;
    }
  }

  /// Create task from sync data
  dynamic createTaskFromSync(Map<String, dynamic> data) {
    if (useDomainModels) {
      return domain.Task(
        id: data['id'] as String,
        noteId: data['note_id'] as String,
        title: (data['content'] ?? '') as String,
        description: data['notes'] as String?,
        status: _parseDomainTaskStatus(data['status'] as String?),
        priority: _parseDomainTaskPriority(data['priority'] as String?),
        dueDate: data['due_date'] != null ? DateTime.parse(data['due_date'] as String) : null,
        completedAt: data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
        tags: List<String>.from(
          (data['tags'] as List<dynamic>?) ??
          (data['labels'] as String?)?.split(',') ??
          <String>[]
        ),
        metadata: const <String, dynamic>{},
      );
    } else {
      // For local model, handled by repository
      _logger.warning('Creating NoteTask from sync should be handled by repository');
      return data;
    }
  }

  /// Create folder from sync data
  dynamic createFolderFromSync(Map<String, dynamic> data) {
    if (useDomainModels) {
      return domain.Folder(
        id: data['id'] as String,
        name: data['name'] as String,
        parentId: data['parent_id'] as String?,
        color: data['color'] as String?,
        icon: data['icon'] as String?,
        description: data['description'] as String?,
        sortOrder: (data['sort_order'] ?? 0) as int,
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: DateTime.parse(data['updated_at'] as String),
        userId: (data['user_id'] ?? '') as String,
      );
    } else {
      // For local model, handled by repository
      _logger.warning('Creating LocalFolder from sync should be handled by repository');
      return data;
    }
  }

  // Private helper methods

  String _mapDomainTaskStatus(domain.TaskStatus status) {
    switch (status) {
      case domain.TaskStatus.pending:
        return 'open';
      case domain.TaskStatus.inProgress:
        return 'open';
      case domain.TaskStatus.completed:
        return 'completed';
      case domain.TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  String _mapDomainTaskPriority(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return 'low';
      case domain.TaskPriority.medium:
        return 'medium';
      case domain.TaskPriority.high:
        return 'high';
      case domain.TaskPriority.urgent:
        return 'urgent';
    }
  }

  domain.TaskStatus _parseDomainTaskStatus(String? status) {
    switch (status) {
      case 'open':
        return domain.TaskStatus.pending;
      case 'completed':
        return domain.TaskStatus.completed;
      case 'cancelled':
        return domain.TaskStatus.cancelled;
      default:
        return domain.TaskStatus.pending;
    }
  }

  domain.TaskPriority _parseDomainTaskPriority(String? priority) {
    switch (priority) {
      case 'low':
        return domain.TaskPriority.low;
      case 'high':
        return domain.TaskPriority.high;
      case 'urgent':
        return domain.TaskPriority.urgent;
      default:
        return domain.TaskPriority.medium;
    }
  }
}