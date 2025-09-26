import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';

/// Helper functions to fix migration type issues in notes_list_screen
class NotesListMigrationHelper {
  /// Convert dynamic note to LocalNote for backward compatibility
  static LocalNote ensureLocalNote(dynamic note) {
    if (note is LocalNote) {
      return note;
    } else if (note is domain.Note) {
      return NoteMapper.toInfrastructure(note);
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get note ID safely from any note type
  static String getNoteId(dynamic note) {
    if (note is LocalNote) {
      return note.id;
    } else if (note is domain.Note) {
      return note.id;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get note title safely from any note type
  static String getNoteTitle(dynamic note) {
    if (note is LocalNote) {
      return note.title;
    } else if (note is domain.Note) {
      return note.title;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get note body safely from any note type
  static String getNoteBody(dynamic note) {
    if (note is LocalNote) {
      return note.body;
    } else if (note is domain.Note) {
      return note.body;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get note updated time safely from any note type
  static DateTime getNoteUpdatedAt(dynamic note) {
    if (note is LocalNote) {
      return note.updatedAt;
    } else if (note is domain.Note) {
      return note.updatedAt;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Check if note is pinned safely from any note type
  static bool getNoteIsPinned(dynamic note) {
    if (note is LocalNote) {
      return note.isPinned;
    } else if (note is domain.Note) {
      return note.isPinned;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Check if note is deleted safely from any note type
  static bool getNoteIsDeleted(dynamic note) {
    if (note is LocalNote) {
      return note.deleted;
    } else if (note is domain.Note) {
      return note.deleted;
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }
}