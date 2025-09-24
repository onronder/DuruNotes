import 'dart:convert';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;

/// Maps between domain Note entity and infrastructure LocalNote
class NoteMapper {
  /// Convert infrastructure LocalNote to domain Note
  static domain.Note toDomain(LocalNote localNote, {List<String>? tags, List<domain.NoteLink>? links}) {
    return domain.Note(
      id: localNote.id,
      title: localNote.title,
      body: localNote.body,
      updatedAt: localNote.updatedAt,
      deleted: localNote.deleted,
      encryptedMetadata: localNote.encryptedMetadata,
      isPinned: localNote.isPinned,
      noteType: localNote.noteType,
      folderId: localNote.folderId,
      version: localNote.version,
      userId: localNote.userId,
      attachmentMeta: localNote.attachmentMeta,
      metadata: localNote.metadata,
      tags: tags ?? [],
      links: links ?? [],
    );
  }

  /// Convert domain Note to infrastructure LocalNote
  static LocalNote toInfrastructure(domain.Note note) {
    return LocalNote(
      id: note.id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      deleted: note.deleted,
      encryptedMetadata: note.encryptedMetadata,
      isPinned: note.isPinned,
      noteType: note.noteType,
      folderId: note.folderId,
      version: note.version,
      userId: note.userId,
      attachmentMeta: note.attachmentMeta,
      metadata: note.metadata,
      conflictState: NoteConflictState.none,
    );
  }

  /// Convert LocalNote list to domain Note list
  static List<domain.Note> toDomainList(List<LocalNote> localNotes) {
    return localNotes.map((note) => toDomain(note)).toList();
  }

  /// Convert domain Note list to LocalNote list
  static List<LocalNote> toInfrastructureList(List<domain.Note> notes) {
    return notes.map((note) => toInfrastructure(note)).toList();
  }

  /// Convert NoteLink to domain
  static domain.NoteLink linkToDomain(NoteLink link) {
    return domain.NoteLink(
      sourceId: link.sourceId,
      targetTitle: link.targetTitle,
      targetId: link.targetId,
    );
  }

  /// Convert domain NoteLink to infrastructure
  static NoteLink linkToInfrastructure(domain.NoteLink link) {
    return NoteLink(
      sourceId: link.sourceId,
      targetTitle: link.targetTitle,
      targetId: link.targetId,
    );
  }
}