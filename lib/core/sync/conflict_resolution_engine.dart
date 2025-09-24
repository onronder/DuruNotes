import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/models/note_kind.dart';

/// Advanced conflict detection and resolution engine for bidirectional sync
///
/// Handles conflicts when the same record is modified in both local SQLite
/// and remote PostgreSQL databases, providing multiple resolution strategies
/// and comprehensive conflict tracking.
class ConflictResolutionEngine {
  final AppDb _localDb;
  final SupabaseNoteApi _remoteApi;
  final AppLogger _logger;

  ConflictResolutionEngine({
    required AppDb localDb,
    required SupabaseNoteApi remoteApi,
    required AppLogger logger,
  }) : _localDb = localDb,
       _remoteApi = remoteApi,
       _logger = logger;

  /// Detect and resolve conflicts for notes with comprehensive strategies
  Future<ConflictResolutionResult> detectAndResolveNoteConflicts({
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.lastWriteWins,
    DateTime? conflictWindow,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info('Starting conflict detection and resolution', data: {
      'strategy': strategy.name,
      'conflict_window': conflictWindow?.toIso8601String(),
    });

    try {
      final conflicts = <DataConflict>[];
      final resolutions = <ConflictResolution>[];

      // 1. Detect conflicts
      final detectedConflicts = await _detectNoteConflicts(conflictWindow);
      conflicts.addAll(detectedConflicts);

      // 2. Resolve conflicts based on strategy
      for (final conflict in conflicts) {
        final resolution = await _resolveConflict(conflict, strategy);
        resolutions.add(resolution);

        // Apply resolution
        if (resolution.requiresAction) {
          await _applyResolution(resolution);
        }
      }

      // 3. Update conflict tracking
      await _updateConflictHistory(conflicts, resolutions);

      stopwatch.stop();

      _logger.info('Conflict resolution completed', data: {
        'total_conflicts': conflicts.length,
        'resolved_conflicts': resolutions.where((r) => r.isResolved).length,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'strategy': strategy.name,
      });

      return ConflictResolutionResult(
        totalConflicts: conflicts.length,
        resolvedConflicts: resolutions.where((r) => r.isResolved).length,
        conflicts: conflicts,
        resolutions: resolutions,
        strategy: strategy,
        duration: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );

    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.error(
        'Conflict resolution failed',
        error: e,
        stackTrace: stackTrace,
      );

      return ConflictResolutionResult.failed(
        error: 'Conflict resolution failed: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Detect conflicts between local and remote data
  Future<List<DataConflict>> _detectNoteConflicts(DateTime? since) async {
    final conflicts = <DataConflict>[];

    try {
      // Get potentially conflicted notes (modified recently)
      var localQuery = _localDb.select(_localDb.localNotes)
        ..where((t) => t.deleted.equals(false));

      if (since != null) {
        localQuery.where((t) => t.updatedAt.isBiggerThanValue(since));
      }

      final localNotes = await localQuery.get();
      final localNoteIds = localNotes.map((n) => n.id).toSet();

      // Get corresponding remote notes
      final remoteNotes = await _remoteApi.fetchEncryptedNotes(since: since);
      final remoteNotesMap = {for (var note in remoteNotes) note['id']: note};

      // Check for conflicts
      for (final localNote in localNotes) {
        final remoteNote = remoteNotesMap[localNote.id];
        if (remoteNote == null) continue;

        final conflict = await _analyzeNoteConflict(localNote, remoteNote);
        if (conflict != null) {
          conflicts.add(conflict);
        }
      }

      // Check for remote-only notes that might conflict
      for (final remoteNote in remoteNotes) {
        final remoteId = remoteNote['id'] as String;
        if (!localNoteIds.contains(remoteId)) {
          // Check if this is a genuine remote-only note or a sync issue
          final conflict = await _analyzeRemoteOnlyNote(remoteNote);
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }

    } catch (e, stackTrace) {
      _logger.error(
        'Conflict detection failed',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return conflicts;
  }

  /// Analyze potential conflict between local and remote note
  Future<DataConflict?> _analyzeNoteConflict(
    LocalNote localNote,
    Map<String, dynamic> remoteNote,
  ) async {
    try {
      final localUpdated = localNote.updatedAt;
      final remoteUpdated = DateTime.parse(remoteNote['updated_at'] as String);

      // Calculate content hashes for comparison
      final localHash = _calculateNoteHash(localNote.title, localNote.encryptedMetadata);
      final remoteHash = _calculateNoteHash(
        remoteNote['title'] as String?,
        remoteNote['encrypted_metadata'] as String?,
      );

      // No conflict if content is identical
      if (localHash == remoteHash) {
        return null;
      }

      // Determine conflict type based on timestamps
      ConflictType conflictType;
      final timeDiff = localUpdated.difference(remoteUpdated).abs();

      if (timeDiff <= Duration(seconds: 5)) {
        conflictType = ConflictType.simultaneousEdit;
      } else if (localUpdated.isAfter(remoteUpdated)) {
        conflictType = ConflictType.localNewer;
      } else {
        conflictType = ConflictType.remoteNewer;
      }

      // Calculate content similarity for merge strategies
      final similarity = await _calculateContentSimilarity(localNote, remoteNote);

      return DataConflict(
        recordId: localNote.id,
        table: 'notes',
        conflictType: conflictType,
        localTimestamp: localUpdated,
        remoteTimestamp: remoteUpdated,
        localHash: localHash,
        remoteHash: remoteHash,
        contentSimilarity: similarity,
        localData: {
          'title': localNote.title,
          'encrypted_metadata': localNote.encryptedMetadata,
          'updated_at': localUpdated,
        },
        remoteData: {
          'title': remoteNote['title'] ?? remoteNote['title_enc'],
          'encrypted_metadata': remoteNote['encrypted_metadata'] ?? remoteNote['props_enc'],
          'updated_at': remoteUpdated,
        },
        detectedAt: DateTime.now(),
      );

    } catch (e, stackTrace) {
      _logger.error(
        'Failed to analyze note conflict',
        error: e,
        stackTrace: stackTrace,
        data: {'note_id': localNote.id},
      );
      return null;
    }
  }

  /// Analyze remote-only note for potential conflicts
  Future<DataConflict?> _analyzeRemoteOnlyNote(Map<String, dynamic> remoteNote) async {
    try {
      final remoteId = remoteNote['id'] as String;

      // Check if this note was recently deleted locally
      final recentlyDeleted = await _localDb.customSelect('''
        SELECT * FROM local_notes
        WHERE id = ? AND deleted = 1 AND updated_at > datetime('now', '-1 hour')
      ''').getSingleOrNull();

      if (recentlyDeleted != null) {
        return DataConflict(
          recordId: remoteId,
          table: 'notes',
          conflictType: ConflictType.deleteConflict,
          localTimestamp: recentlyDeleted.read<DateTime>('updated_at'),
          remoteTimestamp: DateTime.parse(remoteNote['updated_at'] as String),
          localHash: 'deleted',
          remoteHash: _calculateNoteHash(
            remoteNote['title'] as String?,
            remoteNote['encrypted_metadata'] as String?,
          ),
          localData: {'deleted': true},
          remoteData: remoteNote,
          detectedAt: DateTime.now(),
        );
      }

      return null;
    } catch (e) {
      _logger.warning('Failed to analyze remote-only note', data: {
        'note_id': remoteNote['id'],
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Resolve a conflict based on the specified strategy
  Future<ConflictResolution> _resolveConflict(
    DataConflict conflict,
    ConflictResolutionStrategy strategy,
  ) async {
    try {
      switch (strategy) {
        case ConflictResolutionStrategy.lastWriteWins:
          return _resolveLastWriteWins(conflict);

        case ConflictResolutionStrategy.localWins:
          return _resolveLocalWins(conflict);

        case ConflictResolutionStrategy.remoteWins:
          return _resolveRemoteWins(conflict);

        case ConflictResolutionStrategy.manualReview:
          return _flagForManualReview(conflict);

        case ConflictResolutionStrategy.intelligentMerge:
          return await _attemptIntelligentMerge(conflict);

        case ConflictResolutionStrategy.createDuplicate:
          return _createDuplicateResolution(conflict);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to resolve conflict',
        error: e,
        stackTrace: stackTrace,
        data: {'conflict_id': conflict.recordId},
      );

      return ConflictResolution(
        conflictId: conflict.recordId,
        strategy: strategy,
        action: ResolutionAction.error,
        isResolved: false,
        errorMessage: 'Resolution failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Resolve using last-write-wins strategy
  ConflictResolution _resolveLastWriteWins(DataConflict conflict) {
    final useLocal = conflict.localTimestamp.isAfter(conflict.remoteTimestamp);

    return ConflictResolution(
      conflictId: conflict.recordId,
      strategy: ConflictResolutionStrategy.lastWriteWins,
      action: useLocal ? ResolutionAction.useLocal : ResolutionAction.useRemote,
      isResolved: true,
      chosenVersion: useLocal ? 'local' : 'remote',
      reasoning: 'Selected newer version (${useLocal ? 'local' : 'remote'} updated at ${useLocal ? conflict.localTimestamp : conflict.remoteTimestamp})',
      timestamp: DateTime.now(),
    );
  }

  /// Resolve using local-wins strategy
  ConflictResolution _resolveLocalWins(DataConflict conflict) {
    return ConflictResolution(
      conflictId: conflict.recordId,
      strategy: ConflictResolutionStrategy.localWins,
      action: ResolutionAction.useLocal,
      isResolved: true,
      chosenVersion: 'local',
      reasoning: 'Local version preferred by strategy',
      timestamp: DateTime.now(),
    );
  }

  /// Resolve using remote-wins strategy
  ConflictResolution _resolveRemoteWins(DataConflict conflict) {
    return ConflictResolution(
      conflictId: conflict.recordId,
      strategy: ConflictResolutionStrategy.remoteWins,
      action: ResolutionAction.useRemote,
      isResolved: true,
      chosenVersion: 'remote',
      reasoning: 'Remote version preferred by strategy',
      timestamp: DateTime.now(),
    );
  }

  /// Flag conflict for manual review
  ConflictResolution _flagForManualReview(DataConflict conflict) {
    return ConflictResolution(
      conflictId: conflict.recordId,
      strategy: ConflictResolutionStrategy.manualReview,
      action: ResolutionAction.requiresManualReview,
      isResolved: false,
      reasoning: 'Conflict flagged for manual user review',
      timestamp: DateTime.now(),
    );
  }

  /// Attempt intelligent merge of conflicting content
  Future<ConflictResolution> _attemptIntelligentMerge(DataConflict conflict) async {
    try {
      // For high similarity content, attempt merge
      if (conflict.contentSimilarity > 0.8) {
        // Simple merge strategy: prefer newer timestamp for metadata,
        // combine content where possible
        return ConflictResolution(
          conflictId: conflict.recordId,
          strategy: ConflictResolutionStrategy.intelligentMerge,
          action: ResolutionAction.merge,
          isResolved: true,
          chosenVersion: 'merged',
          reasoning: 'Content merged due to high similarity (${(conflict.contentSimilarity * 100).toStringAsFixed(1)}%)',
          timestamp: DateTime.now(),
        );
      } else {
        // Fall back to last-write-wins for dissimilar content
        return _resolveLastWriteWins(conflict);
      }
    } catch (e) {
      _logger.warning('Intelligent merge failed, falling back to last-write-wins', data: {
        'conflict_id': conflict.recordId,
        'error': e.toString(),
      });
      return _resolveLastWriteWins(conflict);
    }
  }

  /// Create duplicate resolution
  ConflictResolution _createDuplicateResolution(DataConflict conflict) {
    return ConflictResolution(
      conflictId: conflict.recordId,
      strategy: ConflictResolutionStrategy.createDuplicate,
      action: ResolutionAction.createDuplicate,
      isResolved: true,
      reasoning: 'Created duplicate to preserve both versions',
      timestamp: DateTime.now(),
    );
  }

  /// Apply the resolution to the databases
  Future<void> _applyResolution(ConflictResolution resolution) async {
    try {
      switch (resolution.action) {
        case ResolutionAction.useLocal:
          await _applyLocalVersion(resolution.conflictId);
          break;

        case ResolutionAction.useRemote:
          await _applyRemoteVersion(resolution.conflictId);
          break;

        case ResolutionAction.merge:
          await _applyMergedVersion(resolution.conflictId);
          break;

        case ResolutionAction.createDuplicate:
          await _createDuplicateNote(resolution.conflictId);
          break;

        case ResolutionAction.requiresManualReview:
          await _flagForUserReview(resolution.conflictId);
          break;

        case ResolutionAction.error:
          // No action needed for errors
          break;
      }

      _logger.info('Resolution applied successfully', data: {
        'conflict_id': resolution.conflictId,
        'action': resolution.action.name,
      });

    } catch (e, stackTrace) {
      _logger.error(
        'Failed to apply resolution',
        error: e,
        stackTrace: stackTrace,
        data: {'resolution': resolution.conflictId},
      );
      rethrow;
    }
  }

  /// Apply local version to remote
  Future<void> _applyLocalVersion(String noteId) async {
    final localNote = await _localDb.getNote(noteId);
    if (localNote != null) {
      await _remoteApi.upsertEncryptedNote(
        id: localNote.id,
        titleEnc: Uint8List.fromList(utf8.encode(localNote.title)),
        propsEnc: Uint8List.fromList(utf8.encode(localNote.encryptedMetadata ?? '')),
        deleted: localNote.deleted,
      );
    }
  }

  /// Apply remote version to local
  Future<void> _applyRemoteVersion(String noteId) async {
    final remoteNotes = await _remoteApi.fetchEncryptedNotes();
    final remoteNote = remoteNotes.firstWhere(
      (note) => note['id'] == noteId,
      orElse: () => <String, dynamic>{},
    );

    if (remoteNote.isNotEmpty) {
      await _localDb.into(_localDb.localNotes).insertOnConflictUpdate(
        LocalNotesCompanion.insert(
          id: noteId,
          title: Value(remoteNote['title'] as String? ?? ''),
          body: Value(''),
          noteType: Value(NoteKind.note),
          encryptedMetadata: Value(remoteNote['encrypted_metadata'] as String?),
          updatedAt: DateTime.parse(remoteNote['updated_at'] as String),
          deleted: Value(remoteNote['deleted'] as bool? ?? false),
        ),
      );
    }
  }

  /// Apply merged version (simplified implementation)
  Future<void> _applyMergedVersion(String noteId) async {
    // This is a simplified merge - in production, you'd want more sophisticated merging
    // For now, apply the newer version
    final localNote = await _localDb.getNote(noteId);
    final remoteNotes = await _remoteApi.fetchEncryptedNotes();
    final remoteNote = remoteNotes.firstWhere(
      (note) => note['id'] == noteId,
      orElse: () => <String, dynamic>{},
    );

    if (localNote != null && remoteNote.isNotEmpty) {
      final localTime = localNote.updatedAt;
      final remoteTime = DateTime.parse(remoteNote['updated_at'] as String);

      if (localTime.isAfter(remoteTime)) {
        await _applyLocalVersion(noteId);
      } else {
        await _applyRemoteVersion(noteId);
      }
    }
  }

  /// Create duplicate note to preserve both versions
  Future<void> _createDuplicateNote(String originalId) async {
    final localNote = await _localDb.getNote(originalId);
    if (localNote != null) {
      final duplicateId = SupabaseNoteApi.generateId();

      await _localDb.into(_localDb.localNotes).insert(
        LocalNotesCompanion.insert(
          id: duplicateId,
          title: Value(localNote.title),
          body: Value(localNote.body),
          noteType: Value(localNote.noteType),
          encryptedMetadata: Value(localNote.encryptedMetadata),
          updatedAt: DateTime.now(),
          deleted: Value(false),
        ),
      );

      _logger.info('Created duplicate note for conflict resolution', data: {
        'original_id': originalId,
        'duplicate_id': duplicateId,
      });
    }
  }

  /// Flag note for user review
  Future<void> _flagForUserReview(String noteId) async {
    // Store conflict information for user interface
    await _localDb.customStatement('''
      INSERT OR REPLACE INTO conflict_review_queue (
        note_id, flagged_at, review_required, conflict_type
      ) VALUES (?, ?, ?, ?)
    ''', [noteId, DateTime.now().toIso8601String(), 1, 'sync_conflict']);
  }

  /// Update conflict history for tracking and analytics
  Future<void> _updateConflictHistory(
    List<DataConflict> conflicts,
    List<ConflictResolution> resolutions,
  ) async {
    try {
      for (int i = 0; i < conflicts.length && i < resolutions.length; i++) {
        final conflict = conflicts[i];
        final resolution = resolutions[i];

        await _localDb.customStatement('''
          INSERT OR REPLACE INTO conflict_history (
            record_id, table_name, conflict_type, resolution_strategy,
            detected_at, resolved_at, is_resolved, resolution_action
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          conflict.recordId,
          conflict.table,
          conflict.conflictType.name,
          resolution.strategy.name,
          conflict.detectedAt.toIso8601String(),
          resolution.timestamp.toIso8601String(),
          resolution.isResolved ? 1 : 0,
          resolution.action.name,
        ]);
      }
    } catch (e) {
      _logger.warning('Failed to update conflict history', data: {'error': e.toString()});
    }
  }

  /// Calculate content similarity between local and remote versions
  Future<double> _calculateContentSimilarity(
    LocalNote localNote,
    Map<String, dynamic> remoteNote,
  ) async {
    try {
      // Simple hash-based similarity (in production, you might want more sophisticated comparison)
      final localHash = _calculateNoteHash(localNote.title, localNote.encryptedMetadata);
      final remoteHash = _calculateNoteHash(
        remoteNote['title'] as String?,
        remoteNote['encrypted_metadata'] as String?,
      );

      // Very basic similarity - identical hashes = 1.0, different = 0.0
      // In production, you might implement Levenshtein distance on decrypted content
      return localHash == remoteHash ? 1.0 : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate note hash for comparison
  String _calculateNoteHash(String? title, String? encryptedMetadata) {
    final content = <int>[];
    if (title != null) content.addAll(utf8.encode(title));
    if (encryptedMetadata != null) content.addAll(utf8.encode(encryptedMetadata));

    final digest = sha256.convert(content);
    return digest.toString();
  }
}

// Data classes

class DataConflict {
  final String recordId;
  final String table;
  final ConflictType conflictType;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final String localHash;
  final String remoteHash;
  final double contentSimilarity;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime detectedAt;

  DataConflict({
    required this.recordId,
    required this.table,
    required this.conflictType,
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.localHash,
    required this.remoteHash,
    required this.localData,
    required this.remoteData,
    required this.detectedAt,
    this.contentSimilarity = 0.0,
  });
}

class ConflictResolution {
  final String conflictId;
  final ConflictResolutionStrategy strategy;
  final ResolutionAction action;
  final bool isResolved;
  final String? chosenVersion;
  final String? reasoning;
  final String? errorMessage;
  final DateTime timestamp;
  final bool requiresAction;

  ConflictResolution({
    required this.conflictId,
    required this.strategy,
    required this.action,
    required this.isResolved,
    required this.timestamp,
    this.chosenVersion,
    this.reasoning,
    this.errorMessage,
  }) : requiresAction = action != ResolutionAction.error && action != ResolutionAction.requiresManualReview;
}

class ConflictResolutionResult {
  final int totalConflicts;
  final int resolvedConflicts;
  final List<DataConflict> conflicts;
  final List<ConflictResolution> resolutions;
  final ConflictResolutionStrategy strategy;
  final Duration duration;
  final DateTime timestamp;
  final String? error;

  ConflictResolutionResult({
    required this.totalConflicts,
    required this.resolvedConflicts,
    required this.conflicts,
    required this.resolutions,
    required this.strategy,
    required this.duration,
    required this.timestamp,
    this.error,
  });

  factory ConflictResolutionResult.failed({
    required String error,
    required Duration duration,
  }) =>
      ConflictResolutionResult(
        totalConflicts: 0,
        resolvedConflicts: 0,
        conflicts: [],
        resolutions: [],
        strategy: ConflictResolutionStrategy.lastWriteWins,
        duration: duration,
        timestamp: DateTime.now(),
        error: error,
      );

  bool get hasUnresolvedConflicts => totalConflicts > resolvedConflicts;
  double get resolutionRate => totalConflicts > 0 ? resolvedConflicts / totalConflicts : 1.0;
}

enum ConflictType {
  simultaneousEdit,
  localNewer,
  remoteNewer,
  deleteConflict,
  typeConflict,
}

enum ConflictResolutionStrategy {
  lastWriteWins,
  localWins,
  remoteWins,
  manualReview,
  intelligentMerge,
  createDuplicate,
}

enum ResolutionAction {
  useLocal,
  useRemote,
  merge,
  createDuplicate,
  requiresManualReview,
  error,
}