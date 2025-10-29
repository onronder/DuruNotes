import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;

/// DEPRECATED: Utility for migrating UI components - post-migration this should not be used.
///
/// Post-encryption migration, all UI should work exclusively with domain entities.
/// LocalNote and NoteTask no longer have plaintext fields (title, body, content).
/// Use repositories to get decrypted domain entities instead.
@Deprecated('UI should work with domain entities only. Use repositories to get decrypted data.')
class UiMigrationUtility {
  UiMigrationUtility._();

  /// Convert any note type to domain Note
  static domain.Note toDomainNote(dynamic note) {
    if (note is domain.Note) {
      return note;
    } else if (note is LocalNote) {
      throw UnsupportedError(
        'Cannot convert LocalNote to domain.Note without decryption. '
        'Use NotesRepository.getNoteById() to get decrypted domain.Note instead.',
      );
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Convert any note type to LocalNote
  @Deprecated('Use repositories instead of direct LocalNote access')
  static LocalNote toLocalNote(dynamic note) {
    if (note is LocalNote) {
      return note;
    } else if (note is domain.Note) {
      throw UnsupportedError(
        'Cannot convert domain.Note to LocalNote post-migration. '
        'Use repositories for all database operations.',
      );
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Convert any task type to domain Task
  static domain.Task toDomainTask(dynamic task) {
    if (task is domain.Task) {
      return task;
    } else if (task is NoteTask) {
      throw UnsupportedError(
        'Cannot convert NoteTask to domain.Task without decryption. '
        'Use TaskRepository.getTaskById() to get decrypted domain.Task instead.',
      );
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Convert any task type to NoteTask
  @Deprecated('Use repositories instead of direct NoteTask access')
  static NoteTask toLocalTask(dynamic task) {
    if (task is NoteTask) {
      return task;
    } else if (task is domain.Task) {
      throw UnsupportedError(
        'Cannot convert domain.Task to NoteTask post-migration. '
        'Use repositories for all database operations.',
      );
    } else {
      throw ArgumentError('Unknown task type: ${task.runtimeType}');
    }
  }

  /// Convert any folder type to domain Folder
  static domain.Folder toDomainFolder(dynamic folder) {
    if (folder is domain.Folder) {
      return folder;
    } else if (folder is LocalFolder) {
      // Folders aren't encrypted, can convert using mapper if needed
      // But post-migration, UI should only receive domain.Folder from repositories
      throw UnsupportedError(
        'Use FolderRepository.getFolder() to get domain.Folder instead.',
      );
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
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
      throw UnsupportedError(
        'LocalNote.title does not exist post-encryption. '
        'Use NotesRepository.getNoteById() to get decrypted title.',
      );
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note content from any note type
  static String getNoteContent(dynamic note) {
    if (note is domain.Note) {
      return note.body;
    } else if (note is LocalNote) {
      throw UnsupportedError(
        'LocalNote.body does not exist post-encryption. '
        'Use NotesRepository.getNoteById() to get decrypted content.',
      );
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get note updated timestamp from any note type
  static DateTime getNoteUpdatedAt(dynamic note) {
    if (note is domain.Note) {
      return note.updatedAt;
    } else if (note is LocalNote) {
      return note.updatedAt;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Check if note is deleted
  static bool isNoteDeleted(dynamic note) {
    if (note is domain.Note) {
      return note.deleted;
    } else if (note is LocalNote) {
      return note.deleted;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Check if note is pinned
  static bool isNotePinned(dynamic note) {
    if (note is domain.Note) {
      return note.isPinned;
    } else if (note is LocalNote) {
      return note.isPinned;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Alias for isNotePinned (for backward compatibility)
  static bool getNoteIsPinned(dynamic note) => isNotePinned(note);

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
      throw UnsupportedError(
        'NoteTask.content does not exist post-encryption. '
        'Use TaskRepository.getTaskById() to get decrypted title.',
      );
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

  /// Get task due date from any task type
  static DateTime? getTaskDueDate(dynamic task) {
    if (task is domain.Task) {
      return task.dueDate;
    } else if (task is NoteTask) {
      return task.dueDate;
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
}
