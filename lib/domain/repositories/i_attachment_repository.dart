import 'package:duru_notes/domain/entities/attachment.dart';

/// Domain interface for attachment operations
abstract class IAttachmentRepository {
  /// Get attachment by ID
  Future<Attachment?> getById(String id);

  /// Get all attachments for a specific note
  Future<List<Attachment>> getByNoteId(String noteId);

  /// Get attachments by file type
  Future<List<Attachment>> getByType(String mimeType);

  /// Create an attachment
  Future<Attachment> create(Attachment attachment);

  /// Update an attachment
  Future<Attachment> update(Attachment attachment);

  /// Delete an attachment
  Future<void> delete(String attachmentId);

  /// Delete all attachments for a note
  Future<void> deleteByNoteId(String noteId);

  /// Get total storage used by all attachments
  Future<int> getTotalSize();

  /// Get storage used by attachments for a specific note
  Future<int> getSizeByNoteId(String noteId);

  /// Search attachments by filename or metadata
  Future<List<Attachment>> search(String query);

  /// Watch attachments for a note (stream)
  Stream<List<Attachment>> watchByNoteId(String noteId);

  /// Clean up orphaned attachments
  Future<void> cleanupOrphaned();

  /// Get statistics by attachment type
  Future<Map<String, int>> getStatsByType();
}
