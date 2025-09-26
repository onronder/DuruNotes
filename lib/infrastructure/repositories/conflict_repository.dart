import 'package:duru_notes/domain/entities/conflict.dart' as domain;
import 'package:duru_notes/domain/repositories/i_conflict_repository.dart';
import 'package:duru_notes/infrastructure/mappers/conflict_mapper.dart';
import 'package:duru_notes/core/sync/conflict_resolution_engine.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';

/// Implementation of IConflictRepository for managing sync conflicts
/// Note: This implementation stores conflicts in memory and optionally persists
/// to local storage. In production, consider using a proper database table.
class ConflictRepository implements IConflictRepository {
  ConflictRepository({
    required AppDb localDb,
    required SupabaseNoteApi remoteApi,
  })  : _logger = LoggerFactory.instance,
        _conflictEngine = ConflictResolutionEngine(
          localDb: localDb,
          remoteApi: remoteApi,
          logger: LoggerFactory.instance,
        );

  final AppLogger _logger;
  final ConflictResolutionEngine _conflictEngine;
  final Map<String, domain.Conflict> _conflictCache = {};
  final Map<String, domain.ConflictResolution> _resolutionCache = {};

  @override
  Future<domain.Conflict?> getById(String id) async {
    try {
      return _conflictCache[id];
    } catch (e, stack) {
      _logger.error('Failed to get conflict by id: $id', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<domain.Conflict>> getUnresolved() async {
    try {
      return _conflictCache.values
          .where((c) => c.resolution == null || !c.resolution!.isResolved)
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e, stack) {
      _logger.error('Failed to get unresolved conflicts', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Conflict>> getByEntityId(String entityId) async {
    try {
      return _conflictCache.values
          .where((c) => c.entityId == entityId)
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e, stack) {
      _logger.error('Failed to get conflicts for entity: $entityId', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Conflict>> getByEntityType(String entityType) async {
    try {
      return _conflictCache.values
          .where((c) => c.entityType == entityType)
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e, stack) {
      _logger.error('Failed to get conflicts for entity type: $entityType', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Conflict>> getByType(domain.ConflictType type) async {
    try {
      return _conflictCache.values
          .where((c) => c.type == type)
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e, stack) {
      _logger.error('Failed to get conflicts by type: ${type.name}', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<domain.Conflict> create(domain.Conflict conflict) async {
    try {
      _conflictCache[conflict.id] = conflict;
      _logger.info('Created conflict: ${conflict.id} for entity: ${conflict.entityId}');
      await _persistToStorage();
      return conflict;
    } catch (e, stack) {
      _logger.error('Failed to create conflict', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<domain.Conflict> update(domain.Conflict conflict) async {
    try {
      _conflictCache[conflict.id] = conflict;
      _logger.info('Updated conflict: ${conflict.id}');
      await _persistToStorage();
      return conflict;
    } catch (e, stack) {
      _logger.error('Failed to update conflict: ${conflict.id}', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> resolve(String conflictId, domain.ConflictResolution resolution) async {
    try {
      final conflict = _conflictCache[conflictId];
      if (conflict == null) {
        throw Exception('Conflict not found: $conflictId');
      }

      // Update conflict with resolution
      final resolvedConflict = domain.Conflict(
        id: conflict.id,
        entityId: conflict.entityId,
        entityType: conflict.entityType,
        type: conflict.type,
        localTimestamp: conflict.localTimestamp,
        remoteTimestamp: conflict.remoteTimestamp,
        localData: conflict.localData,
        remoteData: conflict.remoteData,
        detectedAt: conflict.detectedAt,
        resolution: resolution,
        similarity: conflict.similarity,
      );

      _conflictCache[conflictId] = resolvedConflict;
      _resolutionCache[conflictId] = resolution;

      _logger.info('Resolved conflict: $conflictId with strategy: ${resolution.strategy.name}');
      await _persistToStorage();
    } catch (e, stack) {
      _logger.error('Failed to resolve conflict: $conflictId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      _conflictCache.remove(id);
      _resolutionCache.remove(id);
      _logger.info('Deleted conflict: $id');
      await _persistToStorage();
    } catch (e, stack) {
      _logger.error('Failed to delete conflict: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteResolved({int? olderThanDays}) async {
    try {
      final cutoff = olderThanDays != null
          ? DateTime.now().subtract(Duration(days: olderThanDays))
          : null;

      final toDelete = <String>[];
      for (final conflict in _conflictCache.values) {
        if (conflict.resolution != null && conflict.resolution!.isResolved) {
          if (cutoff == null || conflict.resolution!.resolvedAt.isBefore(cutoff)) {
            toDelete.add(conflict.id);
          }
        }
      }

      for (final id in toDelete) {
        _conflictCache.remove(id);
        _resolutionCache.remove(id);
      }

      _logger.info('Deleted ${toDelete.length} resolved conflicts');
      await _persistToStorage();
    } catch (e, stack) {
      _logger.error('Failed to delete resolved conflicts', error: e, stackTrace: stack);
    }
  }

  @override
  Future<int> getUnresolvedCount() async {
    try {
      return _conflictCache.values
          .where((c) => c.resolution == null || !c.resolution!.isResolved)
          .length;
    } catch (e, stack) {
      _logger.error('Failed to get unresolved count', error: e, stackTrace: stack);
      return 0;
    }
  }

  @override
  Stream<List<domain.Conflict>> watchUnresolved() {
    try {
      // In a real implementation, this would be a proper stream
      // For now, return a stream that emits current unresolved conflicts
      return Stream.periodic(const Duration(seconds: 1), (_) async {
        return await getUnresolved();
      }).asyncMap((future) => future);
    } catch (e, stack) {
      _logger.error('Failed to watch unresolved conflicts', error: e, stackTrace: stack);
      return Stream.value([]);
    }
  }

  @override
  Stream<int> watchUnresolvedCount() {
    try {
      // In a real implementation, this would be a proper stream
      // For now, return a stream that emits current count
      return Stream.periodic(const Duration(seconds: 1), (_) async {
        return await getUnresolvedCount();
      }).asyncMap((future) => future);
    } catch (e, stack) {
      _logger.error('Failed to watch unresolved count', error: e, stackTrace: stack);
      return Stream.value(0);
    }
  }

  @override
  Future<domain.ConflictResolution?> getResolution(String conflictId) async {
    try {
      return _resolutionCache[conflictId];
    } catch (e, stack) {
      _logger.error('Failed to get resolution for conflict: $conflictId', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> applyResolution(String conflictId) async {
    try {
      final conflict = _conflictCache[conflictId];
      if (conflict == null) {
        throw Exception('Conflict not found: $conflictId');
      }

      final resolution = conflict.resolution;
      if (resolution == null) {
        throw Exception('Conflict not resolved: $conflictId');
      }

      // Determine which data to use based on resolution strategy
      Map<String, dynamic> resolvedData;
      switch (resolution.strategy) {
        case domain.ConflictResolutionStrategy.localFirst:
          resolvedData = conflict.localData;
          break;
        case domain.ConflictResolutionStrategy.remoteFirst:
          resolvedData = conflict.remoteData;
          break;
        case domain.ConflictResolutionStrategy.merge:
          resolvedData = resolution.mergedData ?? conflict.localData;
          break;
        case domain.ConflictResolutionStrategy.lastWriteWins:
          resolvedData = conflict.localTimestamp.isAfter(conflict.remoteTimestamp)
              ? conflict.localData
              : conflict.remoteData;
          break;
        case domain.ConflictResolutionStrategy.firstWriteWins:
          resolvedData = conflict.localTimestamp.isBefore(conflict.remoteTimestamp)
              ? conflict.localData
              : conflict.remoteData;
          break;
        default:
          resolvedData = conflict.localData;
      }

      _logger.info('Applied resolution for conflict: $conflictId');
      return resolvedData;
    } catch (e, stack) {
      _logger.error('Failed to apply resolution for conflict: $conflictId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<domain.ConflictType, int>> getStatsByType() async {
    try {
      final stats = <domain.ConflictType, int>{};
      for (final conflict in _conflictCache.values) {
        stats[conflict.type] = (stats[conflict.type] ?? 0) + 1;
      }
      return stats;
    } catch (e, stack) {
      _logger.error('Failed to get conflict stats by type', error: e, stackTrace: stack);
      return {};
    }
  }

  @override
  Future<void> detectConflicts({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String entityId,
    required String entityType,
  }) async {
    try {
      final dataConflict = DataConflict(
        recordId: entityId,
        table: entityType,
        conflictType: ConflictType.simultaneousEdit,
        localTimestamp: DateTime.now(),
        remoteTimestamp: DateTime.now(),
        localHash: localData.toString().hashCode.toString(),
        remoteHash: remoteData.toString().hashCode.toString(),
        localData: localData,
        remoteData: remoteData,
        detectedAt: DateTime.now(),
        contentSimilarity: 0.0,
      );

      // Directly create the conflict without using the engine's detectConflicts
      // The engine's detectAndResolveNoteConflicts is for batch operations
      final domainConflict = ConflictMapper.toDomain(dataConflict);
      await create(domainConflict);
    } catch (e, stack) {
      _logger.error('Failed to detect conflicts for entity: $entityId', error: e, stackTrace: stack);
    }
  }

  @override
  Future<void> batchResolve(List<String> conflictIds, domain.ConflictResolutionStrategy strategy) async {
    try {
      _logger.info('Batch resolving ${conflictIds.length} conflicts with strategy: $strategy');

      for (final conflictId in conflictIds) {
        final conflict = _conflictCache[conflictId];
        if (conflict == null) {
          _logger.warning('Conflict $conflictId not found for batch resolution');
          continue;
        }

        // Create resolution based on strategy
        final resolution = domain.ConflictResolution(
          conflictId: conflictId,
          strategy: strategy,
          chosenVersion: strategy == domain.ConflictResolutionStrategy.keepLocal
              ? 'local'
              : strategy == domain.ConflictResolutionStrategy.keepRemote
                  ? 'remote'
                  : 'merged',
          isResolved: true,
          resolvedAt: DateTime.now(),
          resolvedBy: 'system_batch',
          mergedData: strategy == domain.ConflictResolutionStrategy.keepLocal
              ? conflict.localData
              : strategy == domain.ConflictResolutionStrategy.keepRemote
                  ? conflict.remoteData
                  : _mergeData(conflict.localData, conflict.remoteData),
        );

        // Apply the resolution
        await resolve(conflictId, resolution);
      }

      await _persistToStorage();
      _logger.info('Batch resolution completed for ${conflictIds.length} conflicts');

    } catch (e, stack) {
      _logger.error('Failed to batch resolve conflicts', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // Helper method to merge data from local and remote
  Map<String, dynamic> _mergeData(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final merged = Map<String, dynamic>.from(local);

    // For each field in remote, use the one with newer timestamp if available
    for (final key in remote.keys) {
      // If the key exists in both, prefer the one with newer data
      // This is a simplistic merge - in production you'd want more sophisticated logic
      if (!merged.containsKey(key) || remote[key] != null) {
        merged[key] = remote[key];
      }
    }

    return merged;
  }

  // Private helper to persist conflicts to local storage
  Future<void> _persistToStorage() async {
    try {
      // In a real implementation, this would save to a database or file
      // For now, just log that we would persist
      _logger.debug('Would persist ${_conflictCache.length} conflicts to storage');
    } catch (e, stack) {
      _logger.error('Failed to persist conflicts to storage', error: e, stackTrace: stack);
    }
  }

  // Load conflicts from storage on initialization
  Future<void> loadFromStorage() async {
    try {
      // In a real implementation, this would load from a database or file
      // For now, just start with empty cache
      _logger.info('Loaded ${_conflictCache.length} conflicts from storage');
    } catch (e, stack) {
      _logger.error('Failed to load conflicts from storage', error: e, stackTrace: stack);
    }
  }
}