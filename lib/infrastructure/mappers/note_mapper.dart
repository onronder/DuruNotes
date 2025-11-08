import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps between domain Note entity and infrastructure LocalNote
/// NOTE: This mapper works with already encrypted/decrypted data.
/// Encryption/decryption happens at the repository level.
class NoteMapper {
  /// Convert infrastructure LocalNote to domain Note
  /// Note: folderId must be fetched separately from NoteFolders junction table
  /// Note: title and body are expected to be already decrypted by the repository
  static domain.Note toDomain(
    db.LocalNote localNote, {
    required String title,
    required String body,
    String? folderId,
    List<String>? tags,
    List<NoteLink>? links,
  }) {
    return domain.Note(
      id: localNote.id,
      title: title,
      body: body,
      createdAt: localNote.createdAt,
      updatedAt: localNote.updatedAt,
      deleted: localNote.deleted,
      deletedAt: localNote.deletedAt,
      scheduledPurgeAt: localNote.scheduledPurgeAt,
      encryptedMetadata: localNote.encryptedMetadata,
      isPinned: localNote.isPinned,
      noteType: localNote.noteType,
      folderId:
          folderId, // folderId is passed in, not stored directly on LocalNote
      version: localNote.version,
      userId:
          localNote.userId ??
          Supabase.instance.client.auth.currentUser?.id ??
          '', // Handle null userId
      attachmentMeta: localNote.attachmentMeta,
      metadata: localNote.metadata,
      tags: tags ?? [],
      links: _convertLinksToNoteLinkReferences(links ?? []),
    );
  }

  /// Convert domain Note to infrastructure LocalNote
  /// Note: folderId relationship must be stored separately in NoteFolders junction table
  /// Note: title and body should be encrypted before passing to this method
  static db.LocalNote toInfrastructure(
    domain.Note note, {
    required String titleEncrypted,
    required String bodyEncrypted,
  }) {
    return db.LocalNote(
      id: note.id,
      titleEncrypted: titleEncrypted,
      bodyEncrypted: bodyEncrypted,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deleted: note.deleted,
      deletedAt: note.deletedAt,
      scheduledPurgeAt: note.scheduledPurgeAt,
      encryptedMetadata: note.encryptedMetadata,
      isPinned: note.isPinned,
      noteType: note.noteType,
      // folderId is NOT stored on LocalNote - it's in NoteFolders junction table
      version: note.version,
      userId: note.userId,
      attachmentMeta: note.attachmentMeta,
      metadata: note.metadata,
      encryptionVersion: 1, // Mark as encrypted
    );
  }

  /// Convert database NoteLink to domain NoteLink entity
  static NoteLink linkToDomain(db.NoteLink dbLink) {
    return NoteLink(
      id: '${dbLink.sourceId}_${dbLink.targetTitle}', // Generate ID from source and target
      fromNoteId: dbLink.sourceId,
      toNoteId: dbLink.targetId ?? '',
      linkType: 'reference', // Default type for database links
      linkText: dbLink.targetTitle,
      createdAt: DateTime.now(), // Database doesn't store creation time
    );
  }

  /// Convert domain NoteLink entity to database NoteLink
  static db.NoteLink linkToInfrastructure(
    NoteLink link, {
    required String userId,
  }) {
    return db.NoteLink(
      sourceId: link.fromNoteId,
      targetTitle: link.linkText ?? link.toNoteId,
      targetId: link.toNoteId.isEmpty ? null : link.toNoteId,
      userId: userId,
    );
  }

  /// Helper to convert full NoteLink entities to simple NoteLinkReferences
  static List<domain.NoteLinkReference> _convertLinksToNoteLinkReferences(
    List<NoteLink> links,
  ) {
    return links
        .map(
          (link) => domain.NoteLinkReference(
            sourceId: link.fromNoteId,
            targetTitle: link.linkText ?? link.toNoteId,
            targetId: link.toNoteId.isEmpty ? null : link.toNoteId,
          ),
        )
        .toList();
  }
}
