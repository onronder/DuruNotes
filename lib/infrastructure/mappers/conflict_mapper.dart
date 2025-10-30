import 'package:duru_notes/domain/entities/conflict.dart' as domain;
import 'package:duru_notes/core/sync/conflict_resolution_engine.dart';
import 'package:uuid/uuid.dart';

/// Mapper for converting between domain and infrastructure conflict representations
class ConflictMapper {
  static const _uuid = Uuid();

  /// Convert infrastructure DataConflict to domain entity
  static domain.Conflict toDomain(DataConflict dataConflict) {
    return domain.Conflict(
      id: _uuid.v4(), // Generate ID if not available
      entityId: dataConflict.recordId,
      entityType: dataConflict.table,
      type: _mapConflictType(dataConflict.conflictType),
      localTimestamp: dataConflict.localTimestamp,
      remoteTimestamp: dataConflict.remoteTimestamp,
      localData: dataConflict.localData,
      remoteData: dataConflict.remoteData,
      detectedAt: dataConflict.detectedAt,
      resolution: null, // Set separately if available
      similarity: dataConflict.contentSimilarity,
    );
  }

  /// Convert domain entity to infrastructure DataConflict
  static DataConflict toInfrastructure(domain.Conflict conflict) {
    return DataConflict(
      recordId: conflict.entityId,
      table: conflict.entityType,
      conflictType: _mapToInfrastructureType(conflict.type),
      localTimestamp: conflict.localTimestamp,
      remoteTimestamp: conflict.remoteTimestamp,
      localHash: _generateHash(conflict.localData),
      remoteHash: _generateHash(conflict.remoteData),
      localData: conflict.localData,
      remoteData: conflict.remoteData,
      detectedAt: conflict.detectedAt,
      contentSimilarity: conflict.similarity ?? 0.0,
    );
  }

  /// Convert ConflictResolution from infrastructure to domain
  static domain.ConflictResolution resolutionToDomain(
    ConflictResolution infraResolution,
  ) {
    return domain.ConflictResolution(
      conflictId: infraResolution.conflictId,
      strategy: _mapResolutionStrategy(infraResolution.strategy),
      chosenVersion: infraResolution.chosenVersion ?? 'unknown',
      isResolved: infraResolution.isResolved,
      resolvedAt: infraResolution.timestamp,
      resolvedBy: null, // Not available in infrastructure
      notes: infraResolution.reasoning,
      mergedData: null, // Would need to be extracted from resolution action
    );
  }

  /// Convert domain ConflictResolution to infrastructure
  static ConflictResolution resolutionToInfrastructure(
    domain.ConflictResolution resolution,
  ) {
    return ConflictResolution(
      conflictId: resolution.conflictId,
      strategy: _mapToInfrastructureStrategy(resolution.strategy),
      action: _determineAction(resolution),
      isResolved: resolution.isResolved,
      timestamp: resolution.resolvedAt,
      chosenVersion: resolution.chosenVersion,
      reasoning: resolution.notes,
      errorMessage: null,
    );
  }

  /// Map infrastructure ConflictType to domain
  static domain.ConflictType _mapConflictType(ConflictType type) {
    switch (type) {
      case ConflictType.simultaneousEdit:
        return domain.ConflictType.simultaneousEdit;
      case ConflictType.localNewer:
        return domain.ConflictType.localNewer;
      case ConflictType.remoteNewer:
        return domain.ConflictType.remoteNewer;
      case ConflictType.deleteConflict:
        return domain.ConflictType.deleteConflict;
      case ConflictType.typeConflict:
        return domain.ConflictType.typeConflict;
    }
  }

  /// Map domain ConflictType to infrastructure
  static ConflictType _mapToInfrastructureType(domain.ConflictType type) {
    switch (type) {
      case domain.ConflictType.simultaneousEdit:
        return ConflictType.simultaneousEdit;
      case domain.ConflictType.localNewer:
        return ConflictType.localNewer;
      case domain.ConflictType.remoteNewer:
        return ConflictType.remoteNewer;
      case domain.ConflictType.deleteConflict:
        return ConflictType.deleteConflict;
      case domain.ConflictType.typeConflict:
        return ConflictType.typeConflict;
      case domain.ConflictType.mergeConflict:
        return ConflictType.simultaneousEdit; // Closest match
    }
  }

  /// Map infrastructure ConflictResolutionStrategy to domain
  static domain.ConflictResolutionStrategy _mapResolutionStrategy(
    ConflictResolutionStrategy strategy,
  ) {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return domain.ConflictResolutionStrategy.lastWriteWins;
      case ConflictResolutionStrategy.localWins:
        return domain.ConflictResolutionStrategy.localFirst;
      case ConflictResolutionStrategy.remoteWins:
        return domain.ConflictResolutionStrategy.remoteFirst;
      case ConflictResolutionStrategy.manualReview:
        return domain.ConflictResolutionStrategy.manual;
      case ConflictResolutionStrategy.intelligentMerge:
        return domain.ConflictResolutionStrategy.smart;
      case ConflictResolutionStrategy.createDuplicate:
        return domain.ConflictResolutionStrategy.merge;
    }
  }

  /// Map domain ConflictResolutionStrategy to infrastructure
  static ConflictResolutionStrategy _mapToInfrastructureStrategy(
    domain.ConflictResolutionStrategy strategy,
  ) {
    switch (strategy) {
      case domain.ConflictResolutionStrategy.lastWriteWins:
        return ConflictResolutionStrategy.lastWriteWins;
      case domain.ConflictResolutionStrategy.firstWriteWins:
        return ConflictResolutionStrategy.lastWriteWins; // Closest match
      case domain.ConflictResolutionStrategy.localFirst:
        return ConflictResolutionStrategy.localWins;
      case domain.ConflictResolutionStrategy.remoteFirst:
        return ConflictResolutionStrategy.remoteWins;
      case domain.ConflictResolutionStrategy.manual:
        return ConflictResolutionStrategy.manualReview;
      case domain.ConflictResolutionStrategy.smart:
        return ConflictResolutionStrategy.intelligentMerge;
      case domain.ConflictResolutionStrategy.merge:
        return ConflictResolutionStrategy.intelligentMerge;
      case domain.ConflictResolutionStrategy.keepLocal:
        return ConflictResolutionStrategy.localWins;
      case domain.ConflictResolutionStrategy.keepRemote:
        return ConflictResolutionStrategy.remoteWins;
    }
  }

  /// Determine resolution action from domain resolution
  static ResolutionAction _determineAction(
    domain.ConflictResolution resolution,
  ) {
    if (!resolution.isResolved) {
      return ResolutionAction.requiresManualReview;
    }
    switch (resolution.chosenVersion) {
      case 'local':
        return ResolutionAction.useLocal;
      case 'remote':
        return ResolutionAction.useRemote;
      case 'merged':
        return ResolutionAction.merge;
      default:
        return ResolutionAction.requiresManualReview;
    }
  }

  /// Generate hash for conflict data
  static String _generateHash(Map<String, dynamic> data) {
    // Simple hash generation - in production use proper hashing
    return data.toString().hashCode.toString();
  }

  /// Create domain entity from JSON
  static domain.Conflict fromJson(Map<String, dynamic> json) {
    domain.ConflictResolution? resolution;
    if (json['resolution'] != null) {
      final resJson = json['resolution'] as Map<String, dynamic>;
      resolution = domain.ConflictResolution(
        conflictId: resJson['conflict_id'] as String,
        strategy: domain.ConflictResolutionStrategy.values.firstWhere(
          (s) => s.name == resJson['strategy'],
          orElse: () => domain.ConflictResolutionStrategy.manual,
        ),
        chosenVersion: resJson['chosen_version'] as String,
        isResolved: resJson['is_resolved'] as bool,
        resolvedAt: DateTime.parse(resJson['resolved_at'] as String),
        resolvedBy: resJson['resolved_by'] as String?,
        notes: resJson['notes'] as String?,
        mergedData: resJson['merged_data'] as Map<String, dynamic>?,
      );
    }

    return domain.Conflict(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      entityType: json['entity_type'] as String,
      type: domain.ConflictType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => domain.ConflictType.mergeConflict,
      ),
      localTimestamp: DateTime.parse(json['local_timestamp'] as String),
      remoteTimestamp: DateTime.parse(json['remote_timestamp'] as String),
      localData: json['local_data'] as Map<String, dynamic>,
      remoteData: json['remote_data'] as Map<String, dynamic>,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      resolution: resolution,
      similarity: json['similarity'] as double?,
    );
  }

  /// Convert domain entity to JSON
  static Map<String, dynamic> toJson(domain.Conflict conflict) {
    return {
      'id': conflict.id,
      'entity_id': conflict.entityId,
      'entity_type': conflict.entityType,
      'type': conflict.type.name,
      'local_timestamp': conflict.localTimestamp.toIso8601String(),
      'remote_timestamp': conflict.remoteTimestamp.toIso8601String(),
      'local_data': conflict.localData,
      'remote_data': conflict.remoteData,
      'detected_at': conflict.detectedAt.toIso8601String(),
      if (conflict.resolution != null)
        'resolution': {
          'conflict_id': conflict.resolution!.conflictId,
          'strategy': conflict.resolution!.strategy.name,
          'chosen_version': conflict.resolution!.chosenVersion,
          'is_resolved': conflict.resolution!.isResolved,
          'resolved_at': conflict.resolution!.resolvedAt.toIso8601String(),
          if (conflict.resolution!.resolvedBy != null)
            'resolved_by': conflict.resolution!.resolvedBy,
          if (conflict.resolution!.notes != null)
            'notes': conflict.resolution!.notes,
          if (conflict.resolution!.mergedData != null)
            'merged_data': conflict.resolution!.mergedData,
        },
      if (conflict.similarity != null) 'similarity': conflict.similarity,
    };
  }
}
