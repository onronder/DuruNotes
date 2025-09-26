import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/attachment.dart' as domain;
import 'package:duru_notes/domain/repositories/i_attachment_repository.dart';
import 'package:duru_notes/infrastructure/mappers/attachment_mapper.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:drift/drift.dart';

/// Implementation of IAttachmentRepository using the local database
class AttachmentRepository implements IAttachmentRepository {
  AttachmentRepository({
    required AppDb db,
  })  : _db = db,
        _logger = LoggerFactory.instance;

  final AppDb _db;
  final AppLogger _logger;

  @override
  Future<domain.Attachment?> getById(String id) async {
    try {
      final query = _db.select(_db.attachmentsTable)
        ..where((a) => a.id.equals(id));
      final result = await query.getSingleOrNull();
      return result != null ? AttachmentMapper.fromDatabase(result) : null;
    } catch (e, stack) {
      _logger.error('Failed to get attachment by id: $id', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<domain.Attachment>> getByNoteId(String noteId) async {
    try {
      final query = _db.select(_db.attachmentsTable)
        ..where((a) => a.noteId.equals(noteId))
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
      final results = await query.get();
      return results.map(AttachmentMapper.fromDatabase).toList();
    } catch (e, stack) {
      _logger.error('Failed to get attachments for note: $noteId', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Attachment>> getByType(String mimeType) async {
    try {
      final query = _db.select(_db.attachmentsTable)
        ..where((a) => a.mimeType.equals(mimeType))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]);
      final results = await query.get();
      return results.map(AttachmentMapper.fromDatabase).toList();
    } catch (e, stack) {
      _logger.error('Failed to get attachments by type: $mimeType', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<domain.Attachment> create(domain.Attachment attachment) async {
    try {
      final companion = AttachmentMapper.toCompanion(attachment);
      await _db.into(_db.attachmentsTable).insert(companion);
      _logger.info('Created attachment: ${attachment.id}');
      return attachment;
    } catch (e, stack) {
      _logger.error('Failed to create attachment', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<domain.Attachment> update(domain.Attachment attachment) async {
    try {
      final companion = AttachmentsTableCompanion(
        id: Value(attachment.id),
        noteId: Value(attachment.noteId),
        filename: Value(attachment.fileName),
        mimeType: Value(attachment.mimeType),
        size: Value(attachment.size),
        url: Value(attachment.url),
        localPath: Value(attachment.localPath),
        createdAt: Value(attachment.uploadedAt),
        metadata: const Value('{}'),
      );

      final rows = await (_db.update(_db.attachmentsTable)
        ..where((a) => a.id.equals(attachment.id)))
        .write(companion);

      if (rows > 0) {
        _logger.info('Updated attachment: ${attachment.id}');
        return attachment;
      } else {
        throw Exception('Attachment not found: ${attachment.id}');
      }
    } catch (e, stack) {
      _logger.error('Failed to update attachment: ${attachment.id}', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final rows = await (_db.delete(_db.attachmentsTable)
        ..where((a) => a.id.equals(id)))
        .go();

      if (rows > 0) {
        _logger.info('Deleted attachment: $id');
      } else {
        _logger.warning('Attachment not found for deletion: $id');
      }
    } catch (e, stack) {
      _logger.error('Failed to delete attachment: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteByNoteId(String noteId) async {
    try {
      final rows = await (_db.delete(_db.attachmentsTable)
        ..where((a) => a.noteId.equals(noteId)))
        .go();

      _logger.info('Deleted $rows attachments for note: $noteId');
    } catch (e, stack) {
      _logger.error('Failed to delete attachments for note: $noteId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<int> getTotalSize() async {
    try {
      // Use raw query for SUM aggregate
      final result = await _db.customSelect(
        'SELECT SUM(size) as total FROM attachments_table',
        readsFrom: {_db.attachmentsTable},
      ).getSingleOrNull();

      return result?.read<int?>('total') ?? 0;
    } catch (e, stack) {
      _logger.error('Failed to get total attachment size', error: e, stackTrace: stack);
      return 0;
    }
  }

  @override
  Future<int> getSizeByNoteId(String noteId) async {
    try {
      // Use raw query for SUM aggregate with WHERE
      final result = await _db.customSelect(
        'SELECT SUM(size) as total FROM attachments_table WHERE note_id = ?',
        variables: [Variable.withString(noteId)],
        readsFrom: {_db.attachmentsTable},
      ).getSingleOrNull();

      return result?.read<int?>('total') ?? 0;
    } catch (e, stack) {
      _logger.error('Failed to get attachment size for note: $noteId', error: e, stackTrace: stack);
      return 0;
    }
  }

  @override
  Future<List<domain.Attachment>> search(String query) async {
    try {
      // Search in filename and metadata
      final results = await (_db.select(_db.attachmentsTable)
        ..where((a) => a.filename.contains(query) |
                      a.metadata.contains(query))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .get();

      return results.map(AttachmentMapper.fromDatabase).toList();
    } catch (e, stack) {
      _logger.error('Failed to search attachments: $query', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Stream<List<domain.Attachment>> watchByNoteId(String noteId) {
    try {
      final query = _db.select(_db.attachmentsTable)
        ..where((a) => a.noteId.equals(noteId))
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);

      return query.watch().map((attachments) =>
          attachments.map(AttachmentMapper.fromDatabase).toList());
    } catch (e, stack) {
      _logger.error('Failed to watch attachments for note: $noteId', error: e, stackTrace: stack);
      return Stream.value([]);
    }
  }

  @override
  Future<void> cleanupOrphaned() async {
    try {
      // Delete attachments where note_id doesn't exist in local_notes
      final result = await _db.customStatement(
        '''DELETE FROM attachments_table
           WHERE note_id NOT IN (SELECT id FROM local_notes)''',
      );

      _logger.info('Cleaned up orphaned attachments');
    } catch (e, stack) {
      _logger.error('Failed to cleanup orphaned attachments', error: e, stackTrace: stack);
    }
  }

  @override
  Future<Map<String, int>> getStatsByType() async {
    try {
      final results = await _db.customSelect(
        '''SELECT mime_type, COUNT(*) as count
           FROM attachments_table
           GROUP BY mime_type''',
        readsFrom: {_db.attachmentsTable},
      ).get();

      final stats = <String, int>{};
      for (final row in results) {
        stats[row.read<String>('mime_type')] = row.read<int>('count');
      }

      return stats;
    } catch (e, stack) {
      _logger.error('Failed to get attachment stats by type', error: e, stackTrace: stack);
      return {};
    }
  }
}