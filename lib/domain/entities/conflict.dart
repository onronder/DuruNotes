/// Domain entity representing a sync conflict
class Conflict {
  final String id;
  final String entityId; // ID of the conflicted entity
  final String entityType; // 'note', 'folder', 'task', etc.
  final ConflictType type;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime detectedAt;
  final ConflictResolution? resolution;
  final double? similarity; // Content similarity score 0-1

  const Conflict({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.type,
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.localData,
    required this.remoteData,
    required this.detectedAt,
    this.resolution,
    this.similarity,
  });

  bool get isResolved => resolution != null && resolution!.isResolved;
  bool get requiresManualReview =>
      resolution?.strategy == ConflictResolutionStrategy.manual;

  Conflict copyWith({
    String? id,
    String? entityId,
    String? entityType,
    ConflictType? type,
    DateTime? localTimestamp,
    DateTime? remoteTimestamp,
    Map<String, dynamic>? localData,
    Map<String, dynamic>? remoteData,
    DateTime? detectedAt,
    ConflictResolution? resolution,
    double? similarity,
  }) {
    return Conflict(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      type: type ?? this.type,
      localTimestamp: localTimestamp ?? this.localTimestamp,
      remoteTimestamp: remoteTimestamp ?? this.remoteTimestamp,
      localData: localData ?? this.localData,
      remoteData: remoteData ?? this.remoteData,
      detectedAt: detectedAt ?? this.detectedAt,
      resolution: resolution ?? this.resolution,
      similarity: similarity ?? this.similarity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conflict &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for conflict types
enum ConflictType {
  simultaneousEdit, // Both local and remote edited
  localNewer, // Local version is newer
  remoteNewer, // Remote version is newer
  deleteConflict, // One deleted, other modified
  typeConflict, // Entity type changed
  mergeConflict, // Content merge conflict
}

/// Conflict resolution information
class ConflictResolution {
  final String conflictId;
  final ConflictResolutionStrategy strategy;
  final String chosenVersion; // 'local', 'remote', or 'merged'
  final bool isResolved;
  final DateTime resolvedAt;
  final String? resolvedBy; // User ID who resolved
  final String? notes; // Resolution notes
  final Map<String, dynamic>? mergedData; // If merged

  const ConflictResolution({
    required this.conflictId,
    required this.strategy,
    required this.chosenVersion,
    required this.isResolved,
    required this.resolvedAt,
    this.resolvedBy,
    this.notes,
    this.mergedData,
  });

  ConflictResolution copyWith({
    String? conflictId,
    ConflictResolutionStrategy? strategy,
    String? chosenVersion,
    bool? isResolved,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? notes,
    Map<String, dynamic>? mergedData,
  }) {
    return ConflictResolution(
      conflictId: conflictId ?? this.conflictId,
      strategy: strategy ?? this.strategy,
      chosenVersion: chosenVersion ?? this.chosenVersion,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      notes: notes ?? this.notes,
      mergedData: mergedData ?? this.mergedData,
    );
  }
}

/// Enum for resolution strategies
enum ConflictResolutionStrategy {
  lastWriteWins, // Use the most recent version
  firstWriteWins, // Keep the first version
  localFirst, // Always prefer local
  remoteFirst, // Always prefer remote
  manual, // Requires user intervention
  merge, // Automatic merge attempt
  smart, // AI-assisted resolution
  keepLocal, // Keep local version (alias for localFirst)
  keepRemote, // Keep remote version (alias for remoteFirst)
}