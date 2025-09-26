import 'package:duru_notes/domain/entities/note_link.dart' as domain;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:uuid/uuid.dart';

/// Mapper for converting between domain and infrastructure note links
class NoteLinkMapper {
  static const _uuid = Uuid();

  /// Convert database NoteLink to domain entity
  static domain.NoteLink toDomain(NoteLink dbLink) {
    // Map the simple database link to a richer domain model
    return domain.NoteLink(
      id: '${dbLink.sourceId}_${dbLink.targetTitle}', // Composite ID
      fromNoteId: dbLink.sourceId,
      toNoteId: dbLink.targetId ?? '', // Empty if not resolved
      linkType: 'reference', // Default type
      linkText: dbLink.targetTitle,
      createdAt: DateTime.now(), // Not stored in DB, use current time
      metadata: null,
    );
  }

  /// Convert domain entity to database NoteLink
  static NoteLink toInfrastructure(domain.NoteLink domainLink) {
    return NoteLink(
      sourceId: domainLink.fromNoteId,
      targetTitle: domainLink.linkText ?? domainLink.toNoteId,
      targetId: domainLink.toNoteId.isNotEmpty ? domainLink.toNoteId : null,
    );
  }

  /// Create domain entity from extended format (with metadata)
  static domain.NoteLink fromExtended({
    required String fromNoteId,
    required String toNoteId,
    String? linkType,
    String? linkText,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return domain.NoteLink(
      id: _uuid.v4(),
      fromNoteId: fromNoteId,
      toNoteId: toNoteId,
      linkType: linkType ?? 'reference',
      linkText: linkText,
      createdAt: createdAt ?? DateTime.now(),
      metadata: metadata,
    );
  }

  /// Convert list of database links to domain entities
  static List<domain.NoteLink> toDomainList(List<NoteLink> dbLinks) {
    return dbLinks.map(toDomain).toList();
  }

  /// Convert list of domain entities to database links
  static List<NoteLink> toInfrastructureList(List<domain.NoteLink> domainLinks) {
    return domainLinks.map(toInfrastructure).toList();
  }

  /// Create domain entity from JSON (for API/storage)
  static domain.NoteLink fromJson(Map<String, dynamic> json) {
    return domain.NoteLink(
      id: json['id'] as String,
      fromNoteId: json['from_note_id'] as String,
      toNoteId: json['to_note_id'] as String,
      linkType: json['link_type'] as String? ?? 'reference',
      linkText: json['link_text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert domain entity to JSON for API/storage
  static Map<String, dynamic> toJson(domain.NoteLink link) {
    return {
      'id': link.id,
      'from_note_id': link.fromNoteId,
      'to_note_id': link.toNoteId,
      'link_type': link.linkType,
      if (link.linkText != null) 'link_text': link.linkText,
      'created_at': link.createdAt.toIso8601String(),
      if (link.metadata != null) 'metadata': link.metadata,
    };
  }

  /// Convert from note metadata format (backward compatibility)
  static List<domain.NoteLink> fromNoteMetadata(
    String noteId,
    List<Map<String, String?>> links,
  ) {
    return links.map((linkData) {
      return domain.NoteLink(
        id: _uuid.v4(),
        fromNoteId: noteId,
        toNoteId: linkData['targetId'] ?? '',
        linkType: linkData['type'] ?? 'reference',
        linkText: linkData['title'],
        createdAt: DateTime.now(),
        metadata: null,
      );
    }).toList();
  }

  /// Convert to note metadata format (backward compatibility)
  static List<Map<String, String?>> toNoteMetadata(
    List<domain.NoteLink> links,
  ) {
    return links.map((link) {
      return {
        'targetId': link.toNoteId,
        'title': link.linkText ?? link.toNoteId,
        'type': link.linkType,
      };
    }).toList();
  }
}