import 'package:duru_notes/data/local/app_db.dart' hide NoteLink;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';

/// DEPRECATED: This converter is no longer compatible with encrypted fields.
///
/// Post-encryption migration, all conversions between LocalNote and domain.Note
/// must go through infrastructure/mappers/note_mapper.dart, which properly handles
/// encryption/decryption at the repository layer.
///
/// This file should not be used in new code and will be removed after migration.
@Deprecated('Use infrastructure/mappers/note_mapper.dart instead. This converter no longer supports encrypted fields after encryption migration.')
class NoteConverter {
  /// Convert LocalNote (infrastructure) to domain.Note (domain)
  static domain.Note fromLocal(LocalNote local, {List<String>? tags, List<NoteLink>? links}) {
    throw UnsupportedError(
      'NoteConverter.fromLocal is deprecated and no longer supported after encryption migration. '
      'Use infrastructure/mappers/note_mapper.dart instead, which properly handles encryption/decryption.'
    );
  }

  /// Convert domain.Note to LocalNote (infrastructure)
  static LocalNote toLocal(domain.Note note) {
    throw UnsupportedError(
      'NoteConverter.toLocal is deprecated and no longer supported after encryption migration. '
      'Use infrastructure/mappers/note_mapper.dart instead, which properly handles encryption/decryption.'
    );
  }

  /// Convert `List<LocalNote>` to `List<domain.Note>`
  static List<domain.Note> fromLocalList(List<LocalNote> localNotes) {
    return localNotes.map((local) => fromLocal(local)).toList();
  }

  /// Convert `List<domain.Note>` to `List<LocalNote>`
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
    throw UnsupportedError(
      'NoteConverter.getNoteTitle is deprecated. LocalNote now uses encrypted fields. '
      'Use infrastructure/mappers/note_mapper.dart with encryption service instead.'
    );
  }

  /// Get body from any note type
  static String getNoteBody(dynamic note) {
    throw UnsupportedError(
      'NoteConverter.getNoteBody is deprecated. LocalNote now uses encrypted fields. '
      'Use infrastructure/mappers/note_mapper.dart with encryption service instead.'
    );
  }
}