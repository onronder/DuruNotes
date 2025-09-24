import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';

/// Provides backward compatibility during migration from database models to domain entities
abstract class CompatibilityLayer {
  /// Convert domain Note entity to infrastructure LocalNote
  static LocalNote domainToLocal(domain.Note note) {
    return NoteMapper.toInfrastructure(note);
  }

  /// Convert infrastructure LocalNote to domain Note entity
  static domain.Note localToDomain(LocalNote note) {
    return NoteMapper.toDomain(note);
  }

  /// Convert list of domain Notes to LocalNotes
  static List<LocalNote> domainListToLocal(List<domain.Note> notes) {
    return notes.map((note) => domainToLocal(note)).toList();
  }

  /// Convert list of LocalNotes to domain Notes
  static List<domain.Note> localListToDomain(List<LocalNote> notes) {
    return notes.map((note) => localToDomain(note)).toList();
  }
}