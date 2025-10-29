import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/attachment.dart' as domain;
import 'package:duru_notes/models/note_block.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

/// Mapper for converting between domain and infrastructure attachment representations
class AttachmentMapper {
  static const _uuid = Uuid();

  /// Convert infrastructure AttachmentBlockData to domain entity
  static domain.Attachment toDomain(
    AttachmentBlockData blockData, {
    required String noteId,
    String? id,
    DateTime? uploadedAt,
  }) {
    return domain.Attachment(
      id: id ?? _uuid.v4(),
      noteId: noteId,
      fileName: blockData.fileName,
      mimeType: blockData.mimeType,
      size: blockData.fileSize,
      url: blockData.url,
      localPath: blockData.localPath,
      uploadedAt: uploadedAt ?? DateTime.now(),
    );
  }

  /// Convert domain entity to infrastructure AttachmentBlockData
  static AttachmentBlockData toInfrastructure(domain.Attachment attachment) {
    return AttachmentBlockData(
      fileName: attachment.fileName,
      fileSize: attachment.size,
      mimeType: attachment.mimeType,
      url: attachment.url,
      localPath: attachment.localPath,
      thumbnailUrl: null, // Can be generated based on mime type
      description: null, // Can be added as metadata
    );
  }

  /// Convert list of infrastructure attachments to domain entities
  static List<domain.Attachment> toDomainList(
    List<AttachmentBlockData> blockDataList, {
    required String noteId,
  }) {
    return blockDataList
        .map((blockData) => toDomain(blockData, noteId: noteId))
        .toList();
  }

  /// Convert list of domain entities to infrastructure attachments
  static List<AttachmentBlockData> toInfrastructureList(
    List<domain.Attachment> attachments,
  ) {
    return attachments.map(toInfrastructure).toList();
  }

  /// Create domain entity from JSON (API/storage format)
  static domain.Attachment fromJson(Map<String, dynamic> json) {
    return domain.Attachment(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
      url: json['url'] as String?,
      localPath: json['local_path'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  /// Convert domain entity to JSON for API/storage
  static Map<String, dynamic> toJson(domain.Attachment attachment) {
    return {
      'id': attachment.id,
      'note_id': attachment.noteId,
      'file_name': attachment.fileName,
      'mime_type': attachment.mimeType,
      'size': attachment.size,
      if (attachment.url != null) 'url': attachment.url,
      if (attachment.localPath != null) 'local_path': attachment.localPath,
      'uploaded_at': attachment.uploadedAt.toIso8601String(),
    };
  }

  /// Create AttachmentBlockData from attachment metadata JSON
  static AttachmentBlockData fromMetadataJson(Map<String, dynamic> json) {
    return AttachmentBlockData(
      fileName: json['fileName'] as String? ?? 'Unknown',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      url: json['url'] as String?,
      localPath: json['localPath'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Convert AttachmentBlockData to metadata JSON
  static Map<String, dynamic> toMetadataJson(AttachmentBlockData blockData) {
    return {
      'fileName': blockData.fileName,
      'fileSize': blockData.fileSize,
      'mimeType': blockData.mimeType,
      if (blockData.url != null) 'url': blockData.url,
      if (blockData.localPath != null) 'localPath': blockData.localPath,
      if (blockData.thumbnailUrl != null) 'thumbnailUrl': blockData.thumbnailUrl,
      if (blockData.description != null) 'description': blockData.description,
    };
  }

  /// Extract attachments from note metadata
  static List<domain.Attachment> fromNoteMetadata(
    String noteId,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || !metadata.containsKey('attachments')) {
      return [];
    }

    final attachmentsList = metadata['attachments'] as List<dynamic>?;
    if (attachmentsList == null) return [];

    return attachmentsList.map((attachmentData) {
      final data = attachmentData as Map<String, dynamic>;
      return domain.Attachment(
        id: data['id'] as String? ?? _uuid.v4(),
        noteId: noteId,
        fileName: data['fileName'] as String? ?? 'Unknown',
        mimeType: data['mimeType'] as String? ?? 'application/octet-stream',
        size: data['fileSize'] as int? ?? 0,
        url: data['url'] as String?,
        localPath: data['localPath'] as String?,
        uploadedAt: data['uploadedAt'] != null
            ? DateTime.parse(data['uploadedAt'] as String)
            : DateTime.now(),
      );
    }).toList();
  }

  /// Convert attachments to note metadata format
  static Map<String, dynamic> toNoteMetadata(
    List<domain.Attachment> attachments,
  ) {
    return {
      'attachments': attachments.map((attachment) {
        return {
          'id': attachment.id,
          'fileName': attachment.fileName,
          'mimeType': attachment.mimeType,
          'fileSize': attachment.size,
          if (attachment.url != null) 'url': attachment.url,
          if (attachment.localPath != null) 'localPath': attachment.localPath,
          'uploadedAt': attachment.uploadedAt.toIso8601String(),
        };
      }).toList(),
    };
  }

  /// Convert database LocalAttachment to domain entity
  static domain.Attachment fromDatabase(LocalAttachment attachment) {
    return domain.Attachment(
      id: attachment.id,
      noteId: attachment.noteId,
      fileName: attachment.filename,
      mimeType: attachment.mimeType,
      size: attachment.size,
      url: attachment.url,
      localPath: attachment.localPath,
      uploadedAt: attachment.createdAt,
    );
  }

  /// Convert domain entity to database companion for inserts
  /// P0.5 SECURITY: Requires userId to enforce user isolation
  static AttachmentsCompanion toCompanion(
    domain.Attachment attachment, {
    required String userId,
  }) {
    return AttachmentsCompanion.insert(
      id: attachment.id,
      noteId: attachment.noteId,
      userId: userId, // P0.5 SECURITY: Required for user isolation
      filename: attachment.fileName,
      mimeType: attachment.mimeType,
      size: attachment.size,
      createdAt: attachment.uploadedAt,
      url: Value(attachment.url),
      localPath: Value(attachment.localPath),
      metadata: const Value('{}'),
    );
  }

  /// Convert list of database attachments to domain entities
  static List<domain.Attachment> fromDatabaseList(List<LocalAttachment> attachments) {
    return attachments.map(fromDatabase).toList();
  }
}