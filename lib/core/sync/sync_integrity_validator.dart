import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Comprehensive sync integrity validation system
///
/// Ensures data consistency between local SQLite and remote PostgreSQL
/// databases with conflict detection, recovery mechanisms, and health monitoring.
///
/// Critical for production deployment of database optimizations.
class SyncIntegrityValidator {
  final AppDb _localDb;
  final SupabaseNoteApi _remoteApi;
  final AppLogger _logger;

  SyncIntegrityValidator({
    required AppDb localDb,
    required SupabaseNoteApi remoteApi,
    required AppLogger logger,
  }) : _localDb = localDb,
       _remoteApi = remoteApi,
       _logger = logger;

  /// Perform comprehensive sync integrity validation
  Future<ValidationResult> validateSyncIntegrity({
    bool deepValidation = false,
    DateTime? validationWindow,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info('Starting sync integrity validation', data: {
      'deep_validation': deepValidation,
      'validation_window': validationWindow?.toIso8601String(),
    });

    try {
      final issues = <ValidationIssue>[];
      final metrics = SyncMetrics();

      // 1. Basic connectivity validation
      final connectivityResult = await _validateConnectivity();
      if (!connectivityResult.isValid) {
        return ValidationResult.failed(
          connectivityResult.issues,
          metrics: metrics,
          duration: stopwatch.elapsed,
        );
      }

      // 2. Count validation - verify record counts match
      final countResult = await _validateRecordCounts();
      if (!countResult.isValid) {
        issues.addAll(countResult.issues);
        metrics.recordCountMismatch = true;
      }

      // 3. Content hash validation - verify data integrity
      final hashResult = await _validateContentHashes(validationWindow);
      if (!hashResult.isValid) {
        issues.addAll(hashResult.issues);
        metrics.contentHashMismatches = hashResult.issues.length;
      }

      // 4. Task parity validation - ensure task records align across stores
      final taskResult = await _validateTaskParity();
      if (!taskResult.isValid) {
        issues.addAll(taskResult.issues);
        metrics.taskParityMismatches = taskResult.issues.length;
      }

      // 5. Timestamp consistency validation
      final timestampResult = await _validateTimestamps();
      if (!timestampResult.isValid) {
        issues.addAll(timestampResult.issues);
        metrics.timestampInconsistencies = timestampResult.issues.length;
      }

      // 6. Attachment integrity validation
      final attachmentResult = await _validateAttachmentIntegrity();
      if (!attachmentResult.isValid) {
        issues.addAll(attachmentResult.issues);
        metrics.attachmentIntegrityIssues = attachmentResult.issues.length;
      }

      // 7. Deep validation (optional - more thorough but slower)
      if (deepValidation) {
        final deepResult = await _performDeepValidation(validationWindow);
        if (!deepResult.isValid) {
          issues.addAll(deepResult.issues);
          metrics.deepValidationFailures = deepResult.issues.length;
        }
      }

      // 6. Sync health metrics
      await _collectSyncHealthMetrics(metrics);

      stopwatch.stop();
      metrics.validationDuration = stopwatch.elapsed;

      _logger.info('Sync integrity validation completed', data: {
        'total_issues': issues.length,
        'critical_issues': issues.where((i) => i.severity == ValidationSeverity.critical).length,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'deep_validation': deepValidation,
      });

      return ValidationResult(
        isValid: issues.isEmpty,
        issues: issues,
        metrics: metrics,
        validationTime: DateTime.now(),
        duration: stopwatch.elapsed,
      );

    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.error(
        'Sync integrity validation failed',
        error: e,
        stackTrace: stackTrace,
      );

      return ValidationResult.failed([
        ValidationIssue(
          type: ValidationIssueType.systemError,
          severity: ValidationSeverity.critical,
          description: 'Validation system error: $e',
          affectedTable: 'system',
        )
      ], duration: stopwatch.elapsed);
    }
  }

  /// Validate basic connectivity to both databases
  Future<ValidationResult> _validateConnectivity() async {
    final issues = <ValidationIssue>[];

    try {
      // Test local database
      final localCount = await _localDb.managers.localNotes.count();
      _logger.debug('Local database connectivity: OK', data: {'note_count': localCount});
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.connectionError,
        severity: ValidationSeverity.critical,
        description: 'Local database connection failed: $e',
        affectedTable: 'local_notes',
      ));
    }

    try {
      // Test remote database
      final remoteIds = await _remoteApi.fetchAllActiveIds();
      _logger.debug('Remote database connectivity: OK', data: {'note_count': remoteIds.length});
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.connectionError,
        severity: ValidationSeverity.critical,
        description: 'Remote database connection failed: $e',
        affectedTable: 'notes',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  /// Validate record counts between local and remote
  Future<ValidationResult> _validateRecordCounts() async {
    final issues = <ValidationIssue>[];

    try {
      // Notes count validation
      final localNoteCount = await _localDb.customSelect(
        'SELECT COUNT(*) as count FROM local_notes WHERE deleted = 0'
      ).getSingle();

      final remoteActiveIds = await _remoteApi.fetchAllActiveIds();
      final remoteNoteCount = remoteActiveIds.length;

      final localCount = localNoteCount.read<int>('count');

      if (localCount != remoteNoteCount) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.countMismatch,
          severity: ValidationSeverity.warning,
          description: 'Note count mismatch: local=$localCount, remote=$remoteNoteCount',
          affectedTable: 'notes',
          localValue: localCount.toString(),
          remoteValue: remoteNoteCount.toString(),
        ));
      }

      // Folders count validation
      final localFolderCount = await _localDb.customSelect(
        'SELECT COUNT(*) as count FROM local_folders WHERE deleted = 0'
      ).getSingle();

      final remoteFolders = await _remoteApi.fetchAllActiveFolderIds();
      final remoteFolderCount = remoteFolders.length;

      final localFolders = localFolderCount.read<int>('count');

      if (localFolders != remoteFolderCount) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.countMismatch,
          severity: ValidationSeverity.warning,
          description: 'Folder count mismatch: local=$localFolders, remote=$remoteFolderCount',
          affectedTable: 'folders',
          localValue: localFolders.toString(),
          remoteValue: remoteFolderCount.toString(),
        ));
      }

      // Tasks count validation
      final localTaskCount = await _localDb.customSelect(
        'SELECT COUNT(*) as count FROM note_tasks WHERE deleted = 0'
      ).getSingle();

      final remoteActiveTaskIds = await _remoteApi.fetchAllActiveTaskIds();
      final remoteTaskCount = remoteActiveTaskIds.length;

      final localTasks = localTaskCount.read<int>('count');

      if (localTasks != remoteTaskCount) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.countMismatch,
          severity: ValidationSeverity.warning,
          description: 'Task count mismatch: local=$localTasks, remote=$remoteTaskCount',
          affectedTable: 'note_tasks',
          localValue: localTasks.toString(),
          remoteValue: remoteTaskCount.toString(),
        ));
      }

      // Attachments count validation
      final localAttachmentCount = await _localDb.customSelect(
        'SELECT COUNT(*) as count FROM attachments'
      ).getSingle();

      final remoteAttachmentIds = await _remoteApi.fetchAllActiveAttachmentIds();
      final remoteAttachmentCount = remoteAttachmentIds.length;

      final localAttachments = localAttachmentCount.read<int>('count');

      if (localAttachments != remoteAttachmentCount) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.countMismatch,
          severity: ValidationSeverity.warning,
          description: 'Attachment count mismatch: local=$localAttachments, remote=$remoteAttachmentCount',
          affectedTable: 'attachments',
          localValue: localAttachments.toString(),
          remoteValue: remoteAttachmentCount.toString(),
        ));
      }

    } catch (e, stackTrace) {
      _logger.error('Failed to validate record counts', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Record count validation failed: $e',
        affectedTable: 'multiple',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  Future<ValidationResult> _validateTaskParity() async {
    final issues = <ValidationIssue>[];

    try {
      final localRows = await _localDb.customSelect(
        '''
        SELECT id
        FROM note_tasks
        WHERE deleted = 0
        '''
      ).get();

      final localIds = localRows.map((row) => row.read<String>('id')).toSet();
      final remoteIds = await _remoteApi.fetchAllActiveTaskIds();

      for (final localId in localIds) {
        if (!remoteIds.contains(localId)) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingRemote,
            severity: ValidationSeverity.critical,
            description: 'Task exists locally but not remotely',
            affectedTable: 'note_tasks',
            recordId: localId,
          ));
        }
      }

      for (final remoteId in remoteIds) {
        if (!localIds.contains(remoteId)) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingLocal,
            severity: ValidationSeverity.warning,
            description: 'Task exists remotely but not locally',
            affectedTable: 'note_tasks',
            recordId: remoteId,
          ));
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Task parity validation failed', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Task parity validation failed: $e',
        affectedTable: 'note_tasks',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  Future<ValidationResult> _validateAttachmentIntegrity() async {
    final issues = <ValidationIssue>[];

    try {
      final remoteAttachmentRecords = await _remoteApi.fetchAttachments();
      final remoteAttachmentsById = <String, Map<String, dynamic>>{};
      for (final record in remoteAttachmentRecords) {
        final id = record['id'];
        if (id is String && id.isNotEmpty) {
          remoteAttachmentsById[id] = record;
        }
      }

      final localAttachmentIds = <String>{};
      final rows = await _localDb.customSelect('''
        SELECT a.id,
               a.note_id,
               a.user_id,
               a.size,
               ln.id AS note_exists,
               ln.user_id AS note_user_id
        FROM attachments a
        LEFT JOIN local_notes ln ON ln.id = a.note_id
      ''').get();

      for (final row in rows) {
        final noteExists = row.read<String?>('note_exists');
        final attachmentId = row.read<String>('id');
        localAttachmentIds.add(attachmentId);
        if (noteExists == null) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.foreignKeyViolation,
            severity: ValidationSeverity.critical,
            description: 'Attachment references missing note',
            affectedTable: 'attachments',
            recordId: attachmentId,
            localValue: 'note_id=${row.read<String>('note_id')}',
          ));
          continue;
        }

        final attachmentUserId = row.read<String>('user_id');
        final noteUserId = row.read<String?>('note_user_id');
        final remoteAttachment = remoteAttachmentsById[attachmentId];
        if (noteUserId != null && noteUserId != attachmentUserId) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.dataInconsistency,
            severity: ValidationSeverity.critical,
            description: 'Attachment user does not match parent note user',
            affectedTable: 'attachments',
            recordId: attachmentId,
            localValue: 'attachment_user=$attachmentUserId, note_user=$noteUserId',
          ));
        }

        if (remoteAttachment == null) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingRemote,
            severity: ValidationSeverity.critical,
            description: 'Attachment exists locally but not remotely',
            affectedTable: 'attachments',
            recordId: attachmentId,
          ));
        } else {
          final remoteUserId = remoteAttachment['user_id'] as String?;
          if (remoteUserId != null && remoteUserId != attachmentUserId) {
            issues.add(ValidationIssue(
              type: ValidationIssueType.dataInconsistency,
              severity: ValidationSeverity.critical,
              description: 'Attachment user mismatch between local and remote',
              affectedTable: 'attachments',
              recordId: attachmentId,
              localValue: attachmentUserId,
              remoteValue: remoteUserId,
            ));
          }

          final remoteNoteId = remoteAttachment['note_id'] as String?;
          final localNoteId = row.read<String>('note_id');
          if (remoteNoteId != null && remoteNoteId != localNoteId) {
            issues.add(ValidationIssue(
              type: ValidationIssueType.dataInconsistency,
              severity: ValidationSeverity.warning,
              description: 'Attachment note mismatch between local and remote',
              affectedTable: 'attachments',
              recordId: attachmentId,
              localValue: localNoteId,
              remoteValue: remoteNoteId,
            ));
          }
        }

        final size = row.read<int>('size');
        if (size < 0) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.dataInconsistency,
            severity: ValidationSeverity.warning,
            description: 'Attachment size is negative',
            affectedTable: 'attachments',
            recordId: attachmentId,
            localValue: size.toString(),
          ));
        }
      }

      for (final remoteEntry in remoteAttachmentsById.entries) {
        if (!localAttachmentIds.contains(remoteEntry.key)) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingLocal,
            severity: ValidationSeverity.warning,
            description: 'Attachment exists remotely but not locally',
            affectedTable: 'attachments',
            recordId: remoteEntry.key,
          ));
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Attachment integrity validation failed', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Attachment integrity validation failed: $e',
        affectedTable: 'attachments',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  /// Validate content hashes for data integrity
  Future<ValidationResult> _validateContentHashes(DateTime? since) async {
    final issues = <ValidationIssue>[];
    int processedCount = 0;

    try {
      // Get local notes
      var localQuery = _localDb.select(_localDb.localNotes)
        ..where((t) => t.deleted.equals(false));

      if (since != null) {
        localQuery.where((t) => t.updatedAt.isBiggerThanValue(since));
      }

      final localNotes = await localQuery.get();

      // Get remote notes
      final remoteNotes = await _remoteApi.fetchEncryptedNotes(since: since);
      final remoteNotesMap = {for (var note in remoteNotes) note['id']: note};

      for (final localNote in localNotes) {
        processedCount++;
        final remoteNote = remoteNotesMap[localNote.id];

        if (remoteNote == null) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingRemote,
            severity: ValidationSeverity.warning,
            description: 'Note exists locally but not remotely',
            affectedTable: 'notes',
            recordId: localNote.id,
          ));
          continue;
        }

        // Validate content integrity using hashes with encrypted fields
        final localHash = _calculateContentHash(localNote.titleEncrypted, localNote.encryptedMetadata);
        final remoteHash = _calculateContentHash(
          remoteNote['title_encrypted'] as String? ?? remoteNote['title'] as String? ?? '',
          remoteNote['encrypted_metadata'] as String?,
        );

        if (localHash != remoteHash) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.contentMismatch,
            severity: ValidationSeverity.critical,
            description: 'Content hash mismatch detected',
            affectedTable: 'notes',
            recordId: localNote.id,
            localValue: localHash,
            remoteValue: remoteHash,
          ));
        }
      }

      // Check for remote notes not in local
      for (final remoteNote in remoteNotes) {
        final localExists = localNotes.any((local) => local.id == remoteNote['id']);
        if (!localExists) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.missingLocal,
            severity: ValidationSeverity.warning,
            description: 'Note exists remotely but not locally',
            affectedTable: 'notes',
            recordId: remoteNote['id'] as String? ?? '',
          ));
        }
      }

      _logger.info('Content hash validation completed', data: {
        'processed_count': processedCount,
        'mismatches': issues.length,
      });

    } catch (e, stackTrace) {
      _logger.error('Content hash validation failed', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Content hash validation failed: $e',
        affectedTable: 'notes',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  /// Validate timestamp consistency
  Future<ValidationResult> _validateTimestamps() async {
    final issues = <ValidationIssue>[];

    try {
      final hasCreatedAtColumn = await _tableHasColumn('local_notes', 'created_at');

      if (hasCreatedAtColumn) {
        // Check for notes with inconsistent timestamps
        final result = await _localDb.customSelect('''
          SELECT id, created_at, updated_at
          FROM local_notes
          WHERE updated_at < created_at AND deleted = 0
        ''').get();

        for (final row in result) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.timestampInconsistency,
            severity: ValidationSeverity.warning,
            description: 'Updated timestamp is before created timestamp',
            affectedTable: 'local_notes',
            recordId: row.read<String>('id'),
            localValue: 'created: ${row.read<DateTime>('created_at')}, updated: ${row.read<DateTime>('updated_at')}',
          ));
        }
      } else {
        _logger.debug(
          'Skipping created_at timestamp consistency check; column not present in migrated schema',
          data: {'table': 'local_notes'},
        );
      }

      // Check for future timestamps (clock sync issues)
      final futureThreshold = DateTime.now().add(const Duration(minutes: 5));
      final futureTimestamps = await _localDb.customSelect(
        '''
        SELECT id, updated_at
        FROM local_notes
        WHERE updated_at > ?1 AND deleted = 0
      ''',
        variables: [Variable<DateTime>(futureThreshold)],
      ).get();

      for (final row in futureTimestamps) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.timestampInconsistency,
          severity: ValidationSeverity.warning,
          description: 'Future timestamp detected (possible clock sync issue)',
          affectedTable: 'local_notes',
          recordId: row.read<String>('id'),
          localValue: row.read<DateTime>('updated_at').toString(),
        ));
      }

    } catch (e, stackTrace) {
      _logger.error('Timestamp validation failed', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Timestamp validation failed: $e',
        affectedTable: 'local_notes',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final sanitizedTable = tableName.replaceAll('"', '""');
    final rows = await _localDb
        .customSelect('PRAGMA table_info("$sanitizedTable")')
        .get();
    return rows.any((row) => row.read<String>('name') == columnName);
  }

  /// Perform deep validation (more thorough but slower)
  Future<ValidationResult> _performDeepValidation(DateTime? since) async {
    final issues = <ValidationIssue>[];

    try {
      // Validate foreign key integrity
      final foreignKeyIssues = await _validateForeignKeyIntegrity();
      issues.addAll(foreignKeyIssues);

      // Validate task-note relationships
      final taskRelationIssues = await _validateTaskNoteRelationships();
      issues.addAll(taskRelationIssues);

      // Validate folder hierarchy
      final folderHierarchyIssues = await _validateFolderHierarchy();
      issues.addAll(folderHierarchyIssues);

      _logger.info('Deep validation completed', data: {
        'foreign_key_issues': foreignKeyIssues.length,
        'task_relation_issues': taskRelationIssues.length,
        'folder_hierarchy_issues': folderHierarchyIssues.length,
      });

    } catch (e, stackTrace) {
      _logger.error('Deep validation failed', error: e, stackTrace: stackTrace);
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Deep validation failed: $e',
        affectedTable: 'multiple',
      ));
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: SyncMetrics(),
      validationTime: DateTime.now(),
      duration: Duration.zero,
    );
  }

  /// Validate foreign key integrity
  Future<List<ValidationIssue>> _validateForeignKeyIntegrity() async {
    final issues = <ValidationIssue>[];

    try {
      // Check orphaned tasks (note_id references non-existent note)
      final orphanedTasks = await _localDb.customSelect('''
        SELECT nt.id, nt.note_id
        FROM note_tasks nt
        LEFT JOIN local_notes ln ON nt.note_id = ln.id
        WHERE ln.id IS NULL AND nt.deleted = 0
      ''').get();

      for (final task in orphanedTasks) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.foreignKeyViolation,
          severity: ValidationSeverity.critical,
          description: 'Orphaned task references non-existent note',
          affectedTable: 'note_tasks',
          recordId: task.read<String>('id'),
          localValue: 'note_id: ${task.read<String>('note_id')}',
        ));
      }

      // Check orphaned note-folder relationships
      final orphanedNoteFolders = await _localDb.customSelect('''
        SELECT nf.note_id, nf.folder_id
        FROM note_folders nf
        LEFT JOIN local_notes ln ON nf.note_id = ln.id
        LEFT JOIN local_folders lf ON nf.folder_id = lf.id
        WHERE (ln.id IS NULL OR lf.id IS NULL)
      ''').get();

      for (final relation in orphanedNoteFolders) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.foreignKeyViolation,
          severity: ValidationSeverity.critical,
          description: 'Orphaned note-folder relationship',
          affectedTable: 'note_folders',
          recordId: '${relation.read<String>('note_id')}-${relation.read<String>('folder_id')}',
        ));
      }

    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Foreign key validation failed: $e',
        affectedTable: 'multiple',
      ));
    }

    return issues;
  }

  /// Validate task-note relationships
  Future<List<ValidationIssue>> _validateTaskNoteRelationships() async {
    final issues = <ValidationIssue>[];

    try {
      // Check for tasks without content
      final emptyTasks = await _localDb.customSelect('''
        SELECT id FROM note_tasks
        WHERE (content IS NULL OR content = '') AND deleted = 0
      ''').get();

      for (final task in emptyTasks) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.dataInconsistency,
          severity: ValidationSeverity.warning,
          description: 'Task has empty content',
          affectedTable: 'note_tasks',
          recordId: task.read<String>('id'),
        ));
      }

      // Check for circular parent references
      // This would require recursive checking - simplified version
      final selfReferencingTasks = await _localDb.customSelect('''
        SELECT id FROM note_tasks
        WHERE id = parent_task_id AND deleted = 0
      ''').get();

      for (final task in selfReferencingTasks) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.dataInconsistency,
          severity: ValidationSeverity.critical,
          description: 'Task references itself as parent',
          affectedTable: 'note_tasks',
          recordId: task.read<String>('id'),
        ));
      }

    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Task relationship validation failed: $e',
        affectedTable: 'note_tasks',
      ));
    }

    return issues;
  }

  /// Validate folder hierarchy
  Future<List<ValidationIssue>> _validateFolderHierarchy() async {
    final issues = <ValidationIssue>[];

    try {
      // Check for circular folder references
      final selfReferencingFolders = await _localDb.customSelect('''
        SELECT id FROM local_folders
        WHERE id = parent_id AND deleted = 0
      ''').get();

      for (final folder in selfReferencingFolders) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.dataInconsistency,
          severity: ValidationSeverity.critical,
          description: 'Folder references itself as parent',
          affectedTable: 'local_folders',
          recordId: folder.read<String>('id'),
        ));
      }

      // Check for orphaned parent references
      final orphanedParents = await _localDb.customSelect('''
        SELECT f1.id, f1.parent_id
        FROM local_folders f1
        LEFT JOIN local_folders f2 ON f1.parent_id = f2.id
        WHERE f1.parent_id IS NOT NULL AND f2.id IS NULL AND f1.deleted = 0
      ''').get();

      for (final folder in orphanedParents) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.foreignKeyViolation,
          severity: ValidationSeverity.critical,
          description: 'Folder references non-existent parent',
          affectedTable: 'local_folders',
          recordId: folder.read<String>('id'),
          localValue: 'parent_id: ${folder.read<String>('parent_id')}',
        ));
      }

    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.systemError,
        severity: ValidationSeverity.critical,
        description: 'Folder hierarchy validation failed: $e',
        affectedTable: 'local_folders',
      ));
    }

    return issues;
  }

  /// Collect sync health metrics
  Future<void> _collectSyncHealthMetrics(SyncMetrics metrics) async {
    try {
      // Check for recent sync activity
      final recentSyncs = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM pending_ops
        WHERE created_at > datetime('now', '-1 hour')
      ''').getSingleOrNull();

      metrics.recentSyncActivity = recentSyncs?.read<int>('count') ?? 0;

      // Check for failed sync operations
      final failedOps = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM pending_ops
        WHERE operation_type = 'sync_failed'
      ''').getSingleOrNull();

      metrics.failedSyncOperations = failedOps?.read<int>('count') ?? 0;

      // Calculate sync lag (time since last successful sync)
      final lastSync = await _localDb.customSelect('''
        SELECT MAX(created_at) as last_sync FROM pending_ops
        WHERE operation_type = 'sync_completed'
      ''').getSingleOrNull();

      if (lastSync != null) {
        final lastSyncTime = lastSync.read<DateTime>('last_sync');
        metrics.syncLag = DateTime.now().difference(lastSyncTime);
            }

    } catch (e) {
      _logger.warning('Failed to collect sync health metrics', data: {'error': e.toString()});
    }
  }

  /// Calculate content hash for integrity validation
  String _calculateContentHash(String? title, String? encryptedMetadata) {
    final content = <int>[];
    if (title != null) content.addAll(utf8.encode(title));
    if (encryptedMetadata != null) content.addAll(utf8.encode(encryptedMetadata));

    final digest = sha256.convert(content);
    return digest.toString();
  }
}

// Data classes for validation results

class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final SyncMetrics metrics;
  final DateTime validationTime;
  final Duration duration;

  ValidationResult({
    required this.isValid,
    required this.issues,
    required this.metrics,
    required this.validationTime,
    required this.duration,
  });

  factory ValidationResult.failed(
    List<ValidationIssue> issues, {
    SyncMetrics? metrics,
    Duration? duration,
  }) =>
      ValidationResult(
        isValid: false,
        issues: issues,
        metrics: metrics ?? SyncMetrics(),
        validationTime: DateTime.now(),
        duration: duration ?? Duration.zero,
      );

  bool get hasCriticalIssues =>
      issues.any((issue) => issue.severity == ValidationSeverity.critical);

  List<ValidationIssue> get criticalIssues =>
      issues.where((issue) => issue.severity == ValidationSeverity.critical).toList();

  List<ValidationIssue> get warningIssues =>
      issues.where((issue) => issue.severity == ValidationSeverity.warning).toList();
}

class ValidationIssue {
  final ValidationIssueType type;
  final ValidationSeverity severity;
  final String description;
  final String affectedTable;
  final String? recordId;
  final String? localValue;
  final String? remoteValue;
  final DateTime detectedAt;

  ValidationIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.affectedTable,
    this.recordId,
    this.localValue,
    this.remoteValue,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

enum ValidationIssueType {
  connectionError,
  countMismatch,
  contentMismatch,
  timestampInconsistency,
  foreignKeyViolation,
  dataInconsistency,
  missingLocal,
  missingRemote,
  systemError,
}

enum ValidationSeverity {
  info,
  warning,
  critical,
}

class SyncMetrics {
  Duration? validationDuration;
  bool recordCountMismatch = false;
  int contentHashMismatches = 0;
  int timestampInconsistencies = 0;
  int taskParityMismatches = 0;
  int attachmentIntegrityIssues = 0;
  int deepValidationFailures = 0;
  int recentSyncActivity = 0;
  int failedSyncOperations = 0;
  Duration? syncLag;

  Map<String, dynamic> toJson() => {
    'validation_duration_ms': validationDuration?.inMilliseconds,
    'record_count_mismatch': recordCountMismatch,
    'content_hash_mismatches': contentHashMismatches,
    'timestamp_inconsistencies': timestampInconsistencies,
    'task_parity_mismatches': taskParityMismatches,
    'attachment_integrity_issues': attachmentIntegrityIssues,
    'deep_validation_failures': deepValidationFailures,
    'recent_sync_activity': recentSyncActivity,
    'failed_sync_operations': failedSyncOperations,
    'sync_lag_minutes': syncLag?.inMinutes,
  };
}
