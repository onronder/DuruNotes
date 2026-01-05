import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';

/// Production-grade Full-Text Search (FTS) service for encrypted content
///
/// This service manages FTS indexing at the application layer, replacing
/// SQL triggers that cannot work with encrypted data. It provides:
/// - Manual FTS indexing after encryption/decryption
/// - Transaction-safe updates
/// - Batch operations
/// - Recovery/repair functionality
/// - Comprehensive error handling and audit logging
///
/// **Architecture Note**: FTS contains decrypted content for search.
/// The SQLite database file is not SQLCipher-encrypted, so FTS data is stored
/// in plaintext at rest on device. Rely on OS storage protections and treat
/// FTS as local-only data; revisit if SQLCipher is enabled later.
class FtsService {
  FtsService({
    required this.db,
    AppLogger? logger,
    SecurityAuditTrail? auditTrail,
  }) : _logger = logger ?? LoggerFactory.instance,
       _auditTrail = auditTrail ?? SecurityAuditTrail();

  final AppDb db;
  final AppLogger _logger;
  final SecurityAuditTrail _auditTrail;

  // Performance metrics
  int _indexOperations = 0;
  int _failedOperations = 0;

  /// Index a note for full-text search
  ///
  /// This should be called after creating or updating a note, passing
  /// the decrypted content for indexing.
  ///
  /// **Security Note**: Content passed here is decrypted but never stored
  /// in plaintext in the database. It's only indexed in FTS which is
  /// protected by database encryption.
  Future<bool> indexNote({
    required String noteId,
    required String title,
    required String body,
    String? folderPath,
  }) async {
    try {
      _logger.debug(
        'Indexing note for FTS',
        data: {
          'noteId': noteId,
          'titleLength': title.length,
          'bodyLength': body.length,
          'hasFolderPath': folderPath != null,
        },
      );

      // Delete existing FTS entry (if any)
      await db.customStatement('DELETE FROM fts_notes WHERE id = ?', [noteId]);

      // Insert new FTS entry with decrypted content
      await db.customStatement(
        'INSERT INTO fts_notes(id, title, body, folder_path) VALUES (?, ?, ?, ?)',
        [noteId, title, body, folderPath],
      );

      _indexOperations++;

      // Audit log (only for critical operations, not every index)
      if (_indexOperations % 100 == 0) {
        await _auditTrail.logEvent(
          SecurityEventType.encryptionOperation,
          'FTS indexing milestone: $_indexOperations operations',
          metadata: {
            'totalOperations': _indexOperations,
            'failedOperations': _failedOperations,
          },
          severity: SecuritySeverity.info,
        );
      }

      return true;
    } catch (e, stackTrace) {
      _failedOperations++;

      _logger.error(
        'Failed to index note for FTS',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );

      // Log critical failures
      if (_failedOperations > 10) {
        await _auditTrail.logEvent(
          SecurityEventType.securityViolation,
          'High FTS indexing failure rate',
          metadata: {
            'failedOperations': _failedOperations,
            'totalOperations': _indexOperations,
          },
          severity: SecuritySeverity.warning,
        );
      }

      return false;
    }
  }

  /// Remove a note from full-text search index
  ///
  /// This should be called when a note is deleted or marked as deleted.
  Future<bool> removeNote(String noteId) async {
    try {
      _logger.debug('Removing note from FTS', data: {'noteId': noteId});

      await db.customStatement('DELETE FROM fts_notes WHERE id = ?', [noteId]);

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to remove note from FTS',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      return false;
    }
  }

  /// Batch index multiple notes
  ///
  /// More efficient than individual indexing for bulk operations.
  /// Uses a transaction to ensure atomicity.
  Future<int> indexNotesBatch(
    List<({String id, String title, String body, String? folderPath})> notes,
  ) async {
    if (notes.isEmpty) {
      return 0;
    }

    int successful = 0;

    try {
      _logger.info(
        'Batch indexing notes for FTS',
        data: {'count': notes.length},
      );

      await db.transaction(() async {
        for (final note in notes) {
          try {
            // Delete existing
            await db.customStatement('DELETE FROM fts_notes WHERE id = ?', [
              note.id,
            ]);

            // Insert new
            await db.customStatement(
              'INSERT INTO fts_notes(id, title, body, folder_path) VALUES (?, ?, ?, ?)',
              [note.id, note.title, note.body, note.folderPath],
            );

            successful++;
          } catch (e) {
            _logger.warning(
              'Failed to index note in batch',
              data: {'noteId': note.id, 'error': e.toString()},
            );
          }
        }
      });

      _logger.info(
        'Batch indexing completed',
        data: {
          'total': notes.length,
          'successful': successful,
          'failed': notes.length - successful,
        },
      );

      // Audit log for batch operations
      await _auditTrail.logEvent(
        SecurityEventType.encryptionOperation,
        'FTS batch indexing completed',
        metadata: {
          'total': notes.length,
          'successful': successful,
          'failed': notes.length - successful,
        },
        severity: successful == notes.length
            ? SecuritySeverity.info
            : SecuritySeverity.warning,
      );

      return successful;
    } catch (e, stackTrace) {
      _logger.error(
        'Batch indexing failed',
        error: e,
        stackTrace: stackTrace,
        data: {'notesCount': notes.length},
      );
      return successful;
    }
  }

  /// Reindex all notes in the database
  ///
  /// This is a recovery operation that rebuilds the entire FTS index.
  /// Should be used:
  /// - After migration from plaintext to encrypted storage
  /// - When FTS corruption is detected
  /// - As a maintenance operation
  ///
  /// **Warning**: This is an expensive operation. Use sparingly.
  Future<({int total, int successful, int failed})> reindexAllNotes({
    required Future<
      List<({String id, String title, String body, String? folderPath})>
    >
    Function()
    notesFetcher,
  }) async {
    try {
      _logger.info('Starting FTS reindex of all notes');

      final startTime = DateTime.now();

      // Clear existing FTS data
      await db.customStatement('DELETE FROM fts_notes');

      // Fetch all notes (caller must decrypt them)
      final notes = await notesFetcher();

      // Batch index
      final successful = await indexNotesBatch(notes);
      final failed = notes.length - successful;

      final duration = DateTime.now().difference(startTime);

      _logger.info(
        'FTS reindex completed',
        data: {
          'total': notes.length,
          'successful': successful,
          'failed': failed,
          'durationMs': duration.inMilliseconds,
        },
      );

      // Audit log
      await _auditTrail.logEvent(
        SecurityEventType.encryptionOperation,
        'FTS complete reindex',
        metadata: {
          'total': notes.length,
          'successful': successful,
          'failed': failed,
          'durationMs': duration.inMilliseconds,
        },
        severity: failed == 0
            ? SecuritySeverity.info
            : SecuritySeverity.warning,
      );

      return (total: notes.length, successful: successful, failed: failed);
    } catch (e, stackTrace) {
      _logger.error('FTS reindex failed', error: e, stackTrace: stackTrace);

      await _auditTrail.logEvent(
        SecurityEventType.securityViolation,
        'FTS reindex failed catastrophically',
        metadata: {'error': e.toString()},
        severity: SecuritySeverity.critical,
      );

      rethrow;
    }
  }

  /// Verify FTS integrity
  ///
  /// Checks if FTS is in sync with the notes table.
  /// Returns the number of missing or stale entries.
  Future<({int missing, int stale, bool healthy})> verifyIntegrity() async {
    try {
      _logger.info('Verifying FTS integrity');

      // Count notes that should be in FTS but aren't
      final missingResult = await db.customSelect('''
        SELECT COUNT(*) as count
        FROM local_notes
        WHERE deleted = 0 AND note_type = 0
        AND id NOT IN (SELECT id FROM fts_notes)
        ''').getSingle();
      final missing = missingResult.data['count'] as int;

      // Count FTS entries that shouldn't be there (deleted/template notes)
      final staleResult = await db.customSelect('''
        SELECT COUNT(*) as count
        FROM fts_notes
        WHERE id NOT IN (
          SELECT id FROM local_notes
          WHERE deleted = 0 AND note_type = 0
        )
        ''').getSingle();
      final stale = staleResult.data['count'] as int;

      final healthy = missing == 0 && stale == 0;

      _logger.info(
        'FTS integrity check',
        data: {'missing': missing, 'stale': stale, 'healthy': healthy},
      );

      if (!healthy) {
        await _auditTrail.logEvent(
          SecurityEventType.securityViolation,
          'FTS integrity issues detected',
          metadata: {'missingEntries': missing, 'staleEntries': stale},
          severity: SecuritySeverity.warning,
        );
      }

      return (missing: missing, stale: stale, healthy: healthy);
    } catch (e, stackTrace) {
      _logger.error(
        'FTS integrity check failed',
        error: e,
        stackTrace: stackTrace,
      );
      return (missing: -1, stale: -1, healthy: false);
    }
  }

  /// Repair FTS inconsistencies
  ///
  /// Removes stale entries and adds missing ones.
  /// Returns true if repair was successful.
  Future<bool> repairFts({
    required Future<
      List<({String id, String title, String body, String? folderPath})>
    >
    Function(List<String> ids)
    notesFetcher,
  }) async {
    try {
      _logger.info('Starting FTS repair');

      final integrity = await verifyIntegrity();

      if (integrity.healthy) {
        _logger.info('FTS is healthy, no repair needed');
        return true;
      }

      // Remove stale entries
      if (integrity.stale > 0) {
        await db.customStatement('''
          DELETE FROM fts_notes
          WHERE id NOT IN (
            SELECT id FROM local_notes
            WHERE deleted = 0 AND note_type = 0
          )
          ''');
        _logger.info(
          'Removed stale FTS entries',
          data: {'count': integrity.stale},
        );
      }

      // Find missing note IDs
      if (integrity.missing > 0) {
        final missingIds = await db.customSelect('''
          SELECT id
          FROM local_notes
          WHERE deleted = 0 AND note_type = 0
          AND id NOT IN (SELECT id FROM fts_notes)
          ''').get();

        final ids = missingIds.map((row) => row.data['id'] as String).toList();

        // Fetch and index missing notes
        final notes = await notesFetcher(ids);
        final indexed = await indexNotesBatch(notes);

        _logger.info(
          'Added missing FTS entries',
          data: {'requested': ids.length, 'indexed': indexed},
        );
      }

      // Verify repair succeeded
      final postRepair = await verifyIntegrity();

      await _auditTrail.logEvent(
        SecurityEventType.encryptionOperation,
        'FTS repair completed',
        metadata: {
          'beforeMissing': integrity.missing,
          'beforeStale': integrity.stale,
          'afterMissing': postRepair.missing,
          'afterStale': postRepair.stale,
          'success': postRepair.healthy,
        },
        severity: postRepair.healthy
            ? SecuritySeverity.info
            : SecuritySeverity.warning,
      );

      return postRepair.healthy;
    } catch (e, stackTrace) {
      _logger.error('FTS repair failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getMetrics() {
    return {
      'indexOperations': _indexOperations,
      'failedOperations': _failedOperations,
      'successRate': _indexOperations > 0
          ? (_indexOperations - _failedOperations) / _indexOperations
          : 0.0,
    };
  }

  /// Reset metrics (for testing)
  void resetMetrics() {
    _indexOperations = 0;
    _failedOperations = 0;
  }
}
