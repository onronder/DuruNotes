import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;

/// Converter utility for converting between LocalNote and domain.Note
class NoteConverter {
  /// Convert LocalNote (infrastructure) to domain.Note (domain)
  static domain.Note fromLocal(LocalNote local, {List<String>? tags, List<domain.NoteLink>? links}) {
    return domain.Note(
      id: local.id,
      title: local.title,
      body: local.body,
      updatedAt: local.updatedAt,
      deleted: local.deleted,
      isPinned: local.isPinned,
      noteType: local.noteType,
      version: local.version,
      userId: local.userId ?? '',
      folderId: null, // Folder relationship handled separately
      encryptedMetadata: local.encryptedMetadata,
      attachmentMeta: local.attachmentMeta,
      metadata: local.metadata,
      tags: tags ?? const [],
      links: links ?? const [],
    );
  }

  /// Convert domain.Note to LocalNote (infrastructure)
  static LocalNote toLocal(domain.Note note) {
    return LocalNote(
      id: note.id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      deleted: note.deleted,
      isPinned: note.isPinned,
      noteType: note.noteType,
      version: note.version,
      userId: note.userId.isNotEmpty ? note.userId : null,
      encryptedMetadata: note.encryptedMetadata,
      attachmentMeta: note.attachmentMeta,
      metadata: note.metadata,
    );
  }

  /// Convert List<LocalNote> to List<domain.Note>
  static List<domain.Note> fromLocalList(List<LocalNote> localNotes) {
    return localNotes.map((local) => fromLocal(local)).toList();
  }

  /// Convert List<domain.Note> to List<LocalNote>
  static List<LocalNote> toLocalList(List<domain.Note> domainNotes) {
    return domainNotes.map((note) => toLocal(note)).toList();
  }

  /// Smart conversion that handles both types
  static domain.Note ensureDomainNote(dynamic note) {
    if (note is domain.Note) {
      return note;
    } else if (note is LocalNote) {
      return fromLocal(note);
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Smart conversion that handles both types to LocalNote
  static LocalNote ensureLocalNote(dynamic note) {
    if (note is LocalNote) {
      return note;
    } else if (note is domain.Note) {
      return toLocal(note);
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get ID from any note type
  static String getNoteId(dynamic note) {
    if (note is domain.Note) {
      return note.id;
    } else if (note is LocalNote) {
      return note.id;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get title from any note type
  static String getNoteTitle(dynamic note) {
    if (note is domain.Note) {
      return note.title;
    } else if (note is LocalNote) {
      return note.title;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }

  /// Get body from any note type
  static String getNoteBody(dynamic note) {
    if (note is domain.Note) {
      return note.body;
    } else if (note is LocalNote) {
      return note.body;
    } else {
      throw ArgumentError('Unknown note type: ${note.runtimeType}');
    }
  }
}