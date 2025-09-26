import 'package:duru_notes/domain/entities/conflict.dart';

/// Domain repository interface for managing sync conflicts
/// This provides an abstraction layer for conflict storage and resolution
abstract class IConflictRepository {
  /// Get a specific conflict by ID
  Future<Conflict?> getById(String id);

  /// Get all unresolved conflicts
  Future<List<Conflict>> getUnresolved();

  /// Get conflicts for a specific entity
  Future<List<Conflict>> getByEntityId(String entityId);

  /// Get conflicts for a specific entity type (note, folder, task, etc.)
  Future<List<Conflict>> getByEntityType(String entityType);

  /// Get conflicts by type
  Future<List<Conflict>> getByType(ConflictType type);

  /// Create a new conflict record
  Future<Conflict> create(Conflict conflict);

  /// Update an existing conflict
  Future<Conflict> update(Conflict conflict);

  /// Resolve a conflict with the given resolution
  Future<void> resolve(String conflictId, ConflictResolution resolution);

  /// Delete a specific conflict
  Future<void> delete(String id);

  /// Delete all resolved conflicts older than specified days
  Future<void> deleteResolved({int? olderThanDays});

  /// Get count of unresolved conflicts
  Future<int> getUnresolvedCount();

  /// Watch unresolved conflicts for changes
  Stream<List<Conflict>> watchUnresolved();

  /// Watch unresolved conflict count
  Stream<int> watchUnresolvedCount();

  /// Get the resolution for a specific conflict
  Future<ConflictResolution?> getResolution(String conflictId);

  /// Apply a conflict resolution and return the result
  Future<Map<String, dynamic>> applyResolution(String conflictId);

  /// Get conflict statistics by type
  Future<Map<ConflictType, int>> getStatsByType();

  /// Batch resolve multiple conflicts
  Future<void> batchResolve(List<String> conflictIds, ConflictResolutionStrategy strategy);
}