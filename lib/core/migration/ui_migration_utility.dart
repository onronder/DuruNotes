import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';

/// Utility for migrating UI components to support both local and domain models
class UiMigrationUtility {
  UiMigrationUtility._();

  /// Convert any note type to domain Note
  static domain.Note toDomainNote(dynamic note) {
    if (note is domain.Note) {
      return note;
    } else if (note is LocalNote) {
      return NoteMapper.toDomain(note);
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Convert any note type to LocalNote
  static LocalNote toLocalNote(dynamic note) {
    if (note is LocalNote) {
      return note;
    } else if (note is domain.Note) {
      return NoteMapper.toInfrastructure(note);
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Convert any task type to domain Task
  static domain.Task toDomainTask(dynamic task) {
    if (task is domain.Task) {
      return task;
    } else if (task is NoteTask) {
      return TaskMapper.toDomain(task);
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Convert any task type to NoteTask
  static NoteTask toLocalTask(dynamic task) {
    if (task is NoteTask) {
      return task;
    } else if (task is domain.Task) {
      return TaskMapper.toInfrastructure(task);
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Convert any folder type to domain Folder
  static domain.Folder toDomainFolder(dynamic folder) {
    if (folder is domain.Folder) {
      return folder;
    } else if (folder is LocalFolder) {
      return FolderMapper.toDomain(folder);
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Convert any folder type to LocalFolder
  static LocalFolder toLocalFolder(dynamic folder) {
    if (folder is LocalFolder) {
      return folder;
    } else if (folder is domain.Folder) {
      return FolderMapper.toInfrastructure(folder);
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Check if object is a domain entity
  static bool isDomainEntity(dynamic object) {
    return object is domain.Note ||
           object is domain.Task ||
           object is domain.Folder;
  }

  /// Check if object is a local database model
  static bool isLocalModel(dynamic object) {
    return object is LocalNote ||
           object is NoteTask ||
           object is LocalFolder;
  }

  /// Get note ID from any note type
  static String getNoteId(dynamic note) {
    if (note is domain.Note) {
      return note.id;
    } else if (note is LocalNote) {
      return note.id;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note title from any note type
  static String getNoteTitle(dynamic note) {
    if (note is domain.Note) {
      return note.title;
    } else if (note is LocalNote) {
      return note.title;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note content from any note type
  static String getNoteContent(dynamic note) {
    if (note is domain.Note) {
      return note.body;
    } else if (note is LocalNote) {
      return note.body;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note created date from any note type
  static DateTime getNoteCreatedAt(dynamic note) {
    if (note is domain.Note) {
      // domain.Note uses updatedAt, doesn't have createdAt
      return note.updatedAt;
    } else if (note is LocalNote) {
      // LocalNote doesn't have createdAt, use updatedAt
      return note.updatedAt;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note updated date from any note type
  static DateTime getNoteUpdatedAt(dynamic note) {
    if (note is domain.Note) {
      return note.updatedAt;
    } else if (note is LocalNote) {
      return note.updatedAt;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note folder ID from any note type
  static String? getNoteFolderId(dynamic note) {
    if (note is domain.Note) {
      return note.folderId;
    } else if (note is LocalNote) {
      // LocalNote doesn't have folderId - parse from metadata
      return null; // TODO: Parse from metadata if needed
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note synced status from any note type
  static bool getNoteIsSynced(dynamic note) {
    if (note is domain.Note) {
      // Parse metadata JSON if available
      if (note.metadata != null) {
        try {
          final meta = note.metadata! as String;
          // Simplified check - in real implementation would parse JSON
          return meta.contains('synced');
        } catch (e) {
          return false;
        }
      }
      return false;
    } else if (note is LocalNote) {
      // LocalNote doesn't have isSynced - assume synced if has encryptedMetadata
      return note.encryptedMetadata != null;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note starred status from any note type
  static bool getNoteIsStarred(dynamic note) {
    if (note is domain.Note) {
      // domain.Note doesn't have starred - use metadata or default to false
      return false; // TODO: Parse from metadata if needed
    } else if (note is LocalNote) {
      // LocalNote doesn't have starred - parse from metadata or default to false
      return false; // TODO: Parse from metadata if needed
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note pinned status from any note type
  static bool getNoteIsPinned(dynamic note) {
    if (note is domain.Note) {
      return note.isPinned;
    } else if (note is LocalNote) {
      return note.isPinned;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note archived status from any note type
  static bool getNoteIsArchived(dynamic note) {
    if (note is domain.Note) {
      // domain.Note doesn't have archived - use deleted flag or metadata
      return note.deleted; // Or parse from metadata if needed
    } else if (note is LocalNote) {
      // LocalNote doesn't have archived - parse from metadata or use deleted
      return note.deleted; // Or parse from metadata if needed
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note color from any note type
  static String? getNoteColor(dynamic note) {
    if (note is domain.Note) {
      // domain.Note doesn't have color - use metadata or default to null
      return null; // TODO: Parse from metadata if needed
    } else if (note is LocalNote) {
      // LocalNote doesn't have color - parse from metadata
      return null; // TODO: Parse from metadata if needed
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get task ID from any task type
  static String getTaskId(dynamic task) {
    if (task is domain.Task) {
      return task.id;
    } else if (task is NoteTask) {
      return task.id;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Get task title from any task type
  static String getTaskTitle(dynamic task) {
    if (task is domain.Task) {
      return task.title;
    } else if (task is NoteTask) {
      return task.content;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Get task completed status from any task type
  static bool getTaskIsCompleted(dynamic task) {
    if (task is domain.Task) {
      return task.status == domain.TaskStatus.completed;
    } else if (task is NoteTask) {
      return task.status == TaskStatus.completed;
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Get folder ID from any folder type
  static String getFolderId(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.id;
    } else if (folder is LocalFolder) {
      return folder.id;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Get folder name from any folder type
  static String getFolderName(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.name;
    } else if (folder is LocalFolder) {
      return folder.name;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Get folder color from any folder type
  static String? getFolderColor(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.color;
    } else if (folder is LocalFolder) {
      return folder.color;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Get folder icon from any folder type
  static String? getFolderIcon(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.icon;
    } else if (folder is LocalFolder) {
      return folder.icon;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }
}