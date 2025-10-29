import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/attachment.dart' as domain;
import 'package:duru_notes/domain/repositories/i_attachment_repository.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// DEPRECATED: Attachments feature not yet implemented in database schema.
///
/// The attachments table does not exist in the current database schema.
/// This stub implementation satisfies the interface contract but returns
/// empty/default values until the feature is properly implemented.
///
/// TODO(attachments): Implement attachments functionality:
/// 1. Create attachments table in app_db.dart
/// 2. Add migrations for attachments schema
/// 3. Implement file storage (local + cloud)
/// 4. Implement actual repository methods
/// 5. Add encryption for attachment metadata
/// 6. Add file compression/optimization
@Deprecated(
  'Attachments table does not exist in schema - feature not yet implemented',
)
class AttachmentRepository implements IAttachmentRepository {
  AttachmentRepository({required AppDb db}) : _logger = LoggerFactory.instance;

  final AppLogger _logger;

  void _logDeprecationWarning(String method) {
    _logger.warning(
      'AttachmentRepository.$method called but attachments feature not implemented',
      data: {'component': 'AttachmentRepository', 'method': method},
    );
  }

  @override
  Future<domain.Attachment?> getById(String id) async {
    _logDeprecationWarning('getById');
    return null;
  }

  @override
  Future<List<domain.Attachment>> getByNoteId(String noteId) async {
    _logDeprecationWarning('getByNoteId');
    return [];
  }

  @override
  Future<List<domain.Attachment>> getByType(String mimeType) async {
    _logDeprecationWarning('getByType');
    return [];
  }

  @override
  Future<domain.Attachment> create(domain.Attachment attachment) async {
    _logDeprecationWarning('create');
    throw UnsupportedError(
      'Attachments feature not implemented. Cannot create attachments until attachments table is added to schema.',
    );
  }

  @override
  Future<domain.Attachment> update(domain.Attachment attachment) async {
    _logDeprecationWarning('update');
    throw UnsupportedError(
      'Attachments feature not implemented. Cannot update attachments until attachments table is added to schema.',
    );
  }

  @override
  Future<void> delete(String attachmentId) async {
    _logDeprecationWarning('delete');
    // No-op: Nothing to delete
  }

  @override
  Future<void> deleteByNoteId(String noteId) async {
    _logDeprecationWarning('deleteByNoteId');
    // No-op: Nothing to delete
  }

  @override
  Future<int> getTotalSize() async {
    _logDeprecationWarning('getTotalSize');
    return 0;
  }

  @override
  Future<int> getSizeByNoteId(String noteId) async {
    _logDeprecationWarning('getSizeByNoteId');
    return 0;
  }

  @override
  Future<List<domain.Attachment>> search(String query) async {
    _logDeprecationWarning('search');
    return [];
  }

  @override
  Stream<List<domain.Attachment>> watchByNoteId(String noteId) {
    _logDeprecationWarning('watchByNoteId');
    return Stream.value([]);
  }

  @override
  Future<void> cleanupOrphaned() async {
    _logDeprecationWarning('cleanupOrphaned');
    // No-op: Nothing to cleanup
  }

  @override
  Future<Map<String, int>> getStatsByType() async {
    _logDeprecationWarning('getStatsByType');
    return {};
  }
}
