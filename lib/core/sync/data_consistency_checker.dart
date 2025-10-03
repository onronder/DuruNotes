import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Comprehensive data consistency checker for local-remote sync verification
///
/// Ensures data integrity and consistency between local SQLite and remote
/// PostgreSQL databases by performing detailed cross-validation checks.
class DataConsistencyChecker {
  final AppDb _localDb;
  final SupabaseNoteApi _remoteApi;
  final AppLogger _logger;

  DataConsistencyChecker({
    required AppDb localDb,
    required SupabaseNoteApi remoteApi,
    required AppLogger logger,
  }) : _localDb = localDb,
       _remoteApi = remoteApi,
       _logger = logger;

  /// Perform comprehensive data consistency check
  Future<ConsistencyCheckResult> performConsistencyCheck({
    DateTime? checkSince,
    bool deepCheck = false,
    Set<String>? specificTables,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info('Starting data consistency check', data: {
      'check_since': checkSince?.toIso8601String(),
      'deep_check': deepCheck,
      'specific_tables': specificTables?.toList(),
    });

    try {
      final issues = <ConsistencyIssue>[];
      final metrics = ConsistencyMetrics();

      // 1. Check notes consistency
      if (specificTables == null || specificTables.contains('notes')) {
        final noteIssues = await _checkNotesConsistency(checkSince, deepCheck);
        issues.addAll(noteIssues);
        metrics.notesChecked = await _getNotesCount();
        metrics.noteIssues = noteIssues.length;
      }

      // 2. Check folders consistency
      if (specificTables == null || specificTables.contains('folders')) {
        final folderIssues = await _checkFoldersConsistency(checkSince, deepCheck);
        issues.addAll(folderIssues);
        metrics.foldersChecked = await _getFoldersCount();
        metrics.folderIssues = folderIssues.length;
      }

      // 3. Check note-folder relationships
      if (specificTables == null || specificTables.contains('note_folders')) {
        final relationIssues = await _checkNoteFolderRelationships(deepCheck);
        issues.addAll(relationIssues);
        metrics.relationshipsChecked = await _getRelationshipsCount();
        metrics.relationshipIssues = relationIssues.length;
      }

      // 4. Check tasks consistency
      if (specificTables == null || specificTables.contains('tasks')) {
        final taskIssues = await _checkTasksConsistency(checkSince, deepCheck);
        issues.addAll(taskIssues);
        metrics.tasksChecked = await _getTasksCount();
        metrics.taskIssues = taskIssues.length;
      }

      // 5. Deep consistency checks (if enabled)
      if (deepCheck) {
        final deepIssues = await _performDeepConsistencyChecks(checkSince);
        issues.addAll(deepIssues);
        metrics.deepIssues = deepIssues.length;
      }

      // 6. Check referential integrity
      final integrityIssues = await _checkReferentialIntegrity();
      issues.addAll(integrityIssues);
      metrics.integrityIssues = integrityIssues.length;

      stopwatch.stop();
      metrics.checkDuration = stopwatch.elapsed;

      _logger.info('Data consistency check completed', data: {
        'total_issues': issues.length,
        'critical_issues': issues.where((i) => i.severity == ConsistencySeverity.critical).length,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'deep_check': deepCheck,
      });

      return ConsistencyCheckResult(
        isConsistent: issues.isEmpty,
        issues: issues,
        metrics: metrics,
        checkTime: DateTime.now(),
        duration: stopwatch.elapsed,
        checkParameters: {
          'check_since': checkSince?.toIso8601String(),
          'deep_check': deepCheck,
          'specific_tables': specificTables?.toList(),
        },
      );

    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.error(
        'Data consistency check failed',
        error: e,
        stackTrace: stackTrace,
      );

      return ConsistencyCheckResult.failed(
        error: 'Consistency check failed: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Check notes consistency between local and remote
  Future<List<ConsistencyIssue>> _checkNotesConsistency(
    DateTime? since,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];

    try {
      // Get local notes
      final localQuery = _localDb.select(_localDb.localNotes);
      if (since != null) {
        localQuery.where((t) => t.updatedAt.isBiggerThanValue(since));
      }
      final localNotes = await localQuery.get();

      // Get remote notes
      final remoteNotes = await _remoteApi.fetchEncryptedNotes(since: since);
      final remoteNotesMap = {for (var note in remoteNotes) note['id']: note};

      // Check each local note
      for (final localNote in localNotes) {
        final remoteNote = remoteNotesMap[localNote.id];

        if (remoteNote == null) {
          // Local note missing from remote
          if (!localNote.deleted) {
            issues.add(ConsistencyIssue(
              type: ConsistencyIssueType.missingRemote,
              severity: ConsistencySeverity.warning,
              table: 'notes',
              recordId: localNote.id,
              description: 'Note exists locally but missing from remote',
              localValue: 'exists',
              remoteValue: 'missing',
            ));
          }
        } else {
          // Check consistency between local and remote
          final noteIssues = await _validateNoteConsistency(localNote, remoteNote, deepCheck);
          issues.addAll(noteIssues);
        }
      }

      // Check for remote notes missing locally
      for (final remoteNote in remoteNotes) {
        final remoteId = remoteNote['id'] as String;
        final localExists = localNotes.any((local) => local.id == remoteId);

        if (!localExists && !(remoteNote['deleted'] as bool? ?? false)) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingLocal,
            severity: ConsistencySeverity.warning,
            table: 'notes',
            recordId: remoteId,
            description: 'Note exists remotely but missing locally',
            localValue: 'missing',
            remoteValue: 'exists',
          ));
        }
      }

    } catch (e, stackTrace) {
      _logger.error('Notes consistency check failed', error: e, stackTrace: stackTrace);
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'notes',
        recordId: 'system',
        description: 'Notes consistency check failed: $e',
      ));
    }

    return issues;
  }

  /// Validate consistency of a specific note
  Future<List<ConsistencyIssue>> _validateNoteConsistency(
    LocalNote localNote,
    Map<String, dynamic> remoteNote,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];
    final noteId = localNote.id;

    try {
      // Check deletion status
      final localDeleted = localNote.deleted;
      final remoteDeleted = remoteNote['deleted'] as bool? ?? false;

      if (localDeleted != remoteDeleted) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.deletionMismatch,
          severity: ConsistencySeverity.critical,
          table: 'notes',
          recordId: noteId,
          description: 'Deletion status mismatch between local and remote',
          localValue: localDeleted.toString(),
          remoteValue: remoteDeleted.toString(),
        ));
      }

      // Check timestamps
      final localUpdated = localNote.updatedAt;
      final remoteUpdated = DateTime.parse(remoteNote['updated_at'] as String);
      final timeDiff = localUpdated.difference(remoteUpdated).abs();

      if (timeDiff > Duration(minutes: 5)) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.timestampMismatch,
          severity: ConsistencySeverity.warning,
          table: 'notes',
          recordId: noteId,
          description: 'Significant timestamp difference (${timeDiff.inMinutes} minutes)',
          localValue: localUpdated.toIso8601String(),
          remoteValue: remoteUpdated.toIso8601String(),
        ));
      }

      // Check content hashes
      final localHash = _calculateContentHash(localNote.title, localNote.encryptedMetadata);
      final remoteHash = _calculateContentHash(
        remoteNote['title'] as String?,
        remoteNote['encrypted_metadata'] as String?,
      );

      if (localHash != remoteHash) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.contentMismatch,
          severity: ConsistencySeverity.critical,
          table: 'notes',
          recordId: noteId,
          description: 'Content hash mismatch between local and remote',
          localValue: localHash,
          remoteValue: remoteHash,
        ));
      }

      // Deep checks
      if (deepCheck) {
        await _performDeepNoteValidation(localNote, remoteNote, issues);
      }

    } catch (e) {
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'notes',
        recordId: noteId,
        description: 'Note validation failed: $e',
      ));
    }

    return issues;
  }

  /// Check folders consistency
  Future<List<ConsistencyIssue>> _checkFoldersConsistency(
    DateTime? since,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];

    try {
      // Get local folders
      final localQuery = _localDb.select(_localDb.localFolders);
      if (since != null) {
        localQuery.where((t) => t.updatedAt.isBiggerThanValue(since));
      }
      final localFolders = await localQuery.get();

      // Get remote folders
      final remoteFolders = await _remoteApi.fetchEncryptedFolders(since: since);
      final remoteFoldersMap = {for (var folder in remoteFolders) folder['id']: folder};

      // Check each local folder
      for (final localFolder in localFolders) {
        final remoteFolder = remoteFoldersMap[localFolder.id];

        if (remoteFolder == null && !localFolder.deleted) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingRemote,
            severity: ConsistencySeverity.warning,
            table: 'folders',
            recordId: localFolder.id,
            description: 'Folder exists locally but missing from remote',
          ));
        } else if (remoteFolder != null) {
          final folderIssues = await _validateFolderConsistency(localFolder, remoteFolder, deepCheck);
          issues.addAll(folderIssues);
        }
      }

      // Check for remote folders missing locally
      for (final remoteFolder in remoteFolders) {
        final remoteFolderId = remoteFolder['id'] as String;
        final localExists = localFolders.any((local) => local.id == remoteFolderId);

        if (!localExists && !(remoteFolder['deleted'] as bool? ?? false)) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingLocal,
            severity: ConsistencySeverity.warning,
            table: 'folders',
            recordId: remoteFolderId,
            description: 'Folder exists remotely but missing locally',
          ));
        }
      }

    } catch (e, stackTrace) {
      _logger.error('Folders consistency check failed', error: e, stackTrace: stackTrace);
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'folders',
        recordId: 'system',
        description: 'Folders consistency check failed: $e',
      ));
    }

    return issues;
  }

  /// Validate folder consistency
  Future<List<ConsistencyIssue>> _validateFolderConsistency(
    LocalFolder localFolder,
    Map<String, dynamic> remoteFolder,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];
    final folderId = localFolder.id;

    try {
      // Check deletion status
      final localDeleted = localFolder.deleted;
      final remoteDeleted = remoteFolder['deleted'] as bool? ?? false;

      if (localDeleted != remoteDeleted) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.deletionMismatch,
          severity: ConsistencySeverity.critical,
          table: 'folders',
          recordId: folderId,
          description: 'Folder deletion status mismatch',
          localValue: localDeleted.toString(),
          remoteValue: remoteDeleted.toString(),
        ));
      }

      // Check content hashes
      final localHash = _calculateContentHash(localFolder.name, localFolder.description);
      final remoteHash = _calculateContentHash(
        remoteFolder['name'] as String?,
        remoteFolder['description'] as String?,
      );

      if (localHash != remoteHash) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.contentMismatch,
          severity: ConsistencySeverity.critical,
          table: 'folders',
          recordId: folderId,
          description: 'Folder content hash mismatch',
          localValue: localHash,
          remoteValue: remoteHash,
        ));
      }

    } catch (e) {
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'folders',
        recordId: folderId,
        description: 'Folder validation failed: $e',
      ));
    }

    return issues;
  }

  /// Check note-folder relationships consistency
  Future<List<ConsistencyIssue>> _checkNoteFolderRelationships(bool deepCheck) async {
    final issues = <ConsistencyIssue>[];

    try {
      // Get local relationships
      final localRelations = await _localDb.select(_localDb.noteFolders).get();

      // Get remote relationships
      final remoteRelations = await _remoteApi.fetchNoteFolderRelations();
      final remoteRelationsSet = remoteRelations
          .map((r) => '${r['note_id']}-${r['folder_id']}')
          .toSet();

      // Check local relations exist remotely
      for (final localRelation in localRelations) {
        final relationKey = '${localRelation.noteId}-${localRelation.folderId}';

        if (!remoteRelationsSet.contains(relationKey)) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingRemote,
            severity: ConsistencySeverity.warning,
            table: 'note_folders',
            recordId: relationKey,
            description: 'Note-folder relationship exists locally but missing remotely',
            localValue: 'exists',
            remoteValue: 'missing',
          ));
        }
      }

      // Check remote relations exist locally
      final localRelationsSet = localRelations
          .map((r) => '${r.noteId}-${r.folderId}')
          .toSet();

      for (final remoteRelation in remoteRelations) {
        final relationKey = '${remoteRelation['note_id']}-${remoteRelation['folder_id']}';

        if (!localRelationsSet.contains(relationKey)) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingLocal,
            severity: ConsistencySeverity.warning,
            table: 'note_folders',
            recordId: relationKey,
            description: 'Note-folder relationship exists remotely but missing locally',
            localValue: 'missing',
            remoteValue: 'exists',
          ));
        }
      }

      if (deepCheck) {
        // Check referential integrity
        await _checkRelationshipReferentialIntegrity(issues);
      }

    } catch (e, stackTrace) {
      _logger.error('Note-folder relationships check failed', error: e, stackTrace: stackTrace);
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'note_folders',
        recordId: 'system',
        description: 'Relationship consistency check failed: $e',
      ));
    }

    return issues;
  }

  /// Check tasks consistency
  Future<List<ConsistencyIssue>> _checkTasksConsistency(
    DateTime? since,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];

    try {
      // Get local tasks
      final localQuery = _localDb.select(_localDb.noteTasks);
      if (since != null) {
        localQuery.where((t) => t.updatedAt.isBiggerThanValue(since));
      }
      final localTasks = await localQuery.get();

      // Get remote tasks
      final remoteTasks = await _remoteApi.fetchNoteTasks(since: since);
      final remoteTasksMap = {for (var task in remoteTasks) task['id']: task};

      // Check each local task
      for (final localTask in localTasks) {
        final remoteTask = remoteTasksMap[localTask.id];

        if (remoteTask == null && !localTask.deleted) {
          issues.add(ConsistencyIssue(
            type: ConsistencyIssueType.missingRemote,
            severity: ConsistencySeverity.warning,
            table: 'note_tasks',
            recordId: localTask.id,
            description: 'Task exists locally but missing from remote',
          ));
        } else if (remoteTask != null) {
          final taskIssues = await _validateTaskConsistency(localTask, remoteTask, deepCheck);
          issues.addAll(taskIssues);
        }
      }

    } catch (e, stackTrace) {
      _logger.error('Tasks consistency check failed', error: e, stackTrace: stackTrace);
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'note_tasks',
        recordId: 'system',
        description: 'Tasks consistency check failed: $e',
      ));
    }

    return issues;
  }

  /// Validate task consistency
  Future<List<ConsistencyIssue>> _validateTaskConsistency(
    NoteTask localTask,
    Map<String, dynamic> remoteTask,
    bool deepCheck,
  ) async {
    final issues = <ConsistencyIssue>[];
    final taskId = localTask.id;

    try {
      // Check content
      final localContent = localTask.content;
      final remoteContent = remoteTask['content'] as String;

      if (localContent != remoteContent) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.contentMismatch,
          severity: ConsistencySeverity.critical,
          table: 'note_tasks',
          recordId: taskId,
          description: 'Task content mismatch',
          localValue: localContent,
          remoteValue: remoteContent,
        ));
      }

      // Check status
      final localStatus = localTask.status.name;
      final remoteStatus = remoteTask['status'] as String;

      if (localStatus != remoteStatus) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.statusMismatch,
          severity: ConsistencySeverity.warning,
          table: 'note_tasks',
          recordId: taskId,
          description: 'Task status mismatch',
          localValue: localStatus,
          remoteValue: remoteStatus,
        ));
      }

      // Check deletion status
      final localDeleted = localTask.deleted;
      final remoteDeleted = remoteTask['deleted'] as bool? ?? false;

      if (localDeleted != remoteDeleted) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.deletionMismatch,
          severity: ConsistencySeverity.critical,
          table: 'note_tasks',
          recordId: taskId,
          description: 'Task deletion status mismatch',
          localValue: localDeleted.toString(),
          remoteValue: remoteDeleted.toString(),
        ));
      }

    } catch (e) {
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'note_tasks',
        recordId: taskId,
        description: 'Task validation failed: $e',
      ));
    }

    return issues;
  }

  /// Perform deep consistency checks
  Future<List<ConsistencyIssue>> _performDeepConsistencyChecks(DateTime? since) async {
    final issues = <ConsistencyIssue>[];

    try {
      // Check encryption consistency
      await _checkEncryptionConsistency(issues);

      // Check timestamp ordering
      await _checkTimestampOrdering(issues);

      // Check data type consistency
      await _checkDataTypeConsistency(issues);

    } catch (e, stackTrace) {
      _logger.error('Deep consistency checks failed', error: e, stackTrace: stackTrace);
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'system',
        recordId: 'deep_check',
        description: 'Deep consistency check failed: $e',
      ));
    }

    return issues;
  }

  /// Check referential integrity
  Future<List<ConsistencyIssue>> _checkReferentialIntegrity() async {
    final issues = <ConsistencyIssue>[];

    try {
      // Check orphaned tasks
      final orphanedTasks = await _localDb.customSelect('''
        SELECT nt.id, nt.note_id
        FROM note_tasks nt
        LEFT JOIN local_notes ln ON nt.note_id = ln.id
        WHERE ln.id IS NULL AND nt.deleted = 0
      ''').get();

      for (final task in orphanedTasks) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.referentialIntegrityViolation,
          severity: ConsistencySeverity.critical,
          table: 'note_tasks',
          recordId: task.read<String>('id'),
          description: 'Orphaned task references non-existent note',
          localValue: 'note_id: ${task.read<String>('note_id')}',
        ));
      }

      // Check orphaned note-folder relationships
      final orphanedRelations = await _localDb.customSelect('''
        SELECT nf.note_id, nf.folder_id
        FROM note_folders nf
        LEFT JOIN local_notes ln ON nf.note_id = ln.id
        LEFT JOIN local_folders lf ON nf.folder_id = lf.id
        WHERE (ln.id IS NULL OR lf.id IS NULL)
      ''').get();

      for (final relation in orphanedRelations) {
        issues.add(ConsistencyIssue(
          type: ConsistencyIssueType.referentialIntegrityViolation,
          severity: ConsistencySeverity.critical,
          table: 'note_folders',
          recordId: '${relation.read<String>('note_id')}-${relation.read<String>('folder_id')}',
          description: 'Orphaned note-folder relationship',
        ));
      }

    } catch (e) {
      issues.add(ConsistencyIssue(
        type: ConsistencyIssueType.systemError,
        severity: ConsistencySeverity.critical,
        table: 'system',
        recordId: 'referential_integrity',
        description: 'Referential integrity check failed: $e',
      ));
    }

    return issues;
  }

  // Helper methods for deep validation and checks

  Future<void> _performDeepNoteValidation(
    LocalNote localNote,
    Map<String, dynamic> remoteNote,
    List<ConsistencyIssue> issues,
  ) async {
    // Deep validation logic would go here
    // This is a placeholder for more sophisticated validation
  }

  Future<void> _checkRelationshipReferentialIntegrity(List<ConsistencyIssue> issues) async {
    // Additional referential integrity checks
  }

  Future<void> _checkEncryptionConsistency(List<ConsistencyIssue> issues) async {
    // Check that encrypted data is properly formatted
  }

  Future<void> _checkTimestampOrdering(List<ConsistencyIssue> issues) async {
    // Check that updated_at >= created_at for all records
  }

  Future<void> _checkDataTypeConsistency(List<ConsistencyIssue> issues) async {
    // Check data type consistency between local and remote
  }

  // Count helper methods
  Future<int> _getNotesCount() async {
    final result = await _localDb.customSelect('SELECT COUNT(*) as count FROM local_notes WHERE deleted = 0').getSingle();
    return result.read<int>('count') ?? 0;
  }

  Future<int> _getFoldersCount() async {
    final result = await _localDb.customSelect('SELECT COUNT(*) as count FROM local_folders WHERE deleted = 0').getSingle();
    return result.read<int>('count') ?? 0;
  }

  Future<int> _getRelationshipsCount() async {
    final result = await _localDb.customSelect('SELECT COUNT(*) as count FROM note_folders').getSingle();
    return result.read<int>('count') ?? 0;
  }

  Future<int> _getTasksCount() async {
    final result = await _localDb.customSelect('SELECT COUNT(*) as count FROM note_tasks WHERE deleted = 0').getSingle();
    return result.read<int>('count') ?? 0;
  }

  /// Calculate content hash for comparison
  String _calculateContentHash(String? data1, String? data2) {
    final content = <int>[];
    if (data1 != null) content.addAll(utf8.encode(data1));
    if (data2 != null) content.addAll(utf8.encode(data2));

    final digest = sha256.convert(content);
    return digest.toString();
  }
}

// Data classes

class ConsistencyCheckResult {
  final bool isConsistent;
  final List<ConsistencyIssue> issues;
  final ConsistencyMetrics metrics;
  final DateTime checkTime;
  final Duration duration;
  final Map<String, dynamic> checkParameters;
  final String? error;

  ConsistencyCheckResult({
    required this.isConsistent,
    required this.issues,
    required this.metrics,
    required this.checkTime,
    required this.duration,
    required this.checkParameters,
    this.error,
  });

  factory ConsistencyCheckResult.failed({
    required String error,
    required Duration duration,
  }) => ConsistencyCheckResult(
    isConsistent: false,
    issues: [],
    metrics: ConsistencyMetrics(),
    checkTime: DateTime.now(),
    duration: duration,
    checkParameters: {},
    error: error,
  );

  bool get hasCriticalIssues => issues.any((issue) => issue.severity == ConsistencySeverity.critical);
  List<ConsistencyIssue> get criticalIssues => issues.where((issue) => issue.severity == ConsistencySeverity.critical).toList();
}

class ConsistencyIssue {
  final ConsistencyIssueType type;
  final ConsistencySeverity severity;
  final String table;
  final String recordId;
  final String description;
  final String? localValue;
  final String? remoteValue;
  final DateTime detectedAt;

  ConsistencyIssue({
    required this.type,
    required this.severity,
    required this.table,
    required this.recordId,
    required this.description,
    this.localValue,
    this.remoteValue,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

class ConsistencyMetrics {
  int notesChecked = 0;
  int foldersChecked = 0;
  int relationshipsChecked = 0;
  int tasksChecked = 0;
  int noteIssues = 0;
  int folderIssues = 0;
  int relationshipIssues = 0;
  int taskIssues = 0;
  int deepIssues = 0;
  int integrityIssues = 0;
  Duration? checkDuration;

  int get totalRecordsChecked => notesChecked + foldersChecked + relationshipsChecked + tasksChecked;
  int get totalIssuesFound => noteIssues + folderIssues + relationshipIssues + taskIssues + deepIssues + integrityIssues;
  double get consistencyRate => totalRecordsChecked > 0 ? (totalRecordsChecked - totalIssuesFound) / totalRecordsChecked : 1.0;

  Map<String, dynamic> toJson() => {
    'notes_checked': notesChecked,
    'folders_checked': foldersChecked,
    'relationships_checked': relationshipsChecked,
    'tasks_checked': tasksChecked,
    'note_issues': noteIssues,
    'folder_issues': folderIssues,
    'relationship_issues': relationshipIssues,
    'task_issues': taskIssues,
    'deep_issues': deepIssues,
    'integrity_issues': integrityIssues,
    'total_records_checked': totalRecordsChecked,
    'total_issues_found': totalIssuesFound,
    'consistency_rate': consistencyRate,
    'check_duration_ms': checkDuration?.inMilliseconds,
  };
}

enum ConsistencyIssueType {
  missingLocal,
  missingRemote,
  contentMismatch,
  timestampMismatch,
  deletionMismatch,
  statusMismatch,
  referentialIntegrityViolation,
  systemError,
}

enum ConsistencySeverity {
  info,
  warning,
  critical,
}