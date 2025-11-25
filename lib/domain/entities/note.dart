import 'package:duru_notes/models/note_kind.dart';

/// Pure domain entity for Note
/// This is infrastructure-agnostic and contains only business logic
class Note {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  final String? encryptedMetadata;
  final bool isPinned;
  final NoteKind noteType;
  final String? folderId;
  final int version;
  final String userId;

  /// JSON metadata for note attachments (voice recordings, images, files, etc.)
  /// Structure: `{"voiceRecordings": [{id, url, filename, durationSeconds, createdAt}], ...}`
  /// See docs/NOTE_ATTACHMENT_SCHEMA.md for full schema documentation
  final String? attachmentMeta;

  final String? metadata;
  final List<String> tags;
  final List<NoteLinkReference> links;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    this.scheduledPurgeAt,
    this.encryptedMetadata,
    required this.isPinned,
    required this.noteType,
    this.folderId,
    required this.version,
    required this.userId,
    this.attachmentMeta,
    this.metadata,
    this.tags = const [],
    this.links = const [],
  });

  Note copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    DateTime? deletedAt,
    DateTime? scheduledPurgeAt,
    String? encryptedMetadata,
    bool? isPinned,
    NoteKind? noteType,
    String? folderId,
    int? version,
    String? userId,
    String? attachmentMeta,
    String? metadata,
    List<String>? tags,
    List<NoteLinkReference>? links,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      isPinned: isPinned ?? this.isPinned,
      noteType: noteType ?? this.noteType,
      folderId: folderId ?? this.folderId,
      version: version ?? this.version,
      userId: userId ?? this.userId,
      attachmentMeta: attachmentMeta ?? this.attachmentMeta,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      links: links ?? this.links,
    );
  }
}

/// Simple link reference used in Note entity
/// For full bidirectional links, see note_link.dart
class NoteLinkReference {
  final String sourceId;
  final String targetTitle;
  final String? targetId;

  const NoteLinkReference({
    required this.sourceId,
    required this.targetTitle,
    this.targetId,
  });
}
