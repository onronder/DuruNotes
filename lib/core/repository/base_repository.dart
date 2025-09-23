import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base query specification for filtering and sorting
@immutable
class QuerySpec {
  const QuerySpec({
    this.filters = const {},
    this.orderBy,
    this.orderDescending = false,
    this.limit,
    this.offset,
  });

  final Map<String, dynamic> filters;
  final String? orderBy;
  final bool orderDescending;
  final int? limit;
  final int? offset;

  QuerySpec copyWith({
    Map<String, dynamic>? filters,
    String? orderBy,
    bool? orderDescending,
    int? limit,
    int? offset,
  }) {
    return QuerySpec(
      filters: filters ?? this.filters,
      orderBy: orderBy ?? this.orderBy,
      orderDescending: orderDescending ?? this.orderDescending,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// Result wrapper for repository operations
@immutable
class RepositoryResult<T> {
  const RepositoryResult.success(this.data)
      : error = null,
        isSuccess = true;

  const RepositoryResult.failure(this.error)
      : data = null,
        isSuccess = false;

  final T? data;
  final RepositoryError? error;
  final bool isSuccess;

  bool get isFailure => !isSuccess;

  R when<R>({
    required R Function(T data) success,
    required R Function(RepositoryError error) failure,
  }) {
    if (isSuccess) {
      return success(data as T);
    } else {
      return failure(error!);
    }
  }

  T? getOrNull() => data;

  T getOrThrow() {
    if (isSuccess) {
      return data as T;
    } else {
      throw error!;
    }
  }

  T getOrElse(T defaultValue) => data ?? defaultValue;
}

/// Repository error types
class RepositoryError implements Exception {
  const RepositoryError({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
    this.retryable = false,
  });

  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;
  final bool retryable;

  @override
  String toString() => 'RepositoryError: $message (code: $code)';
}

/// Common repository error codes
class RepositoryErrorCodes {
  static const String notFound = 'NOT_FOUND';
  static const String alreadyExists = 'ALREADY_EXISTS';
  static const String invalidData = 'INVALID_DATA';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String networkError = 'NETWORK_ERROR';
  static const String databaseError = 'DATABASE_ERROR';
  static const String cacheError = 'CACHE_ERROR';
  static const String syncError = 'SYNC_ERROR';
  static const String unknown = 'UNKNOWN';
}

/// Base repository interface
abstract class Repository<T, ID> {
  /// Get a single entity by ID
  Future<RepositoryResult<T>> get(ID id);

  /// Get all entities
  Future<RepositoryResult<List<T>>> getAll();

  /// Get entities matching query
  Future<RepositoryResult<List<T>>> query(QuerySpec spec);

  /// Create a new entity
  Future<RepositoryResult<T>> create(T entity);

  /// Update an existing entity
  Future<RepositoryResult<T>> update(T entity);

  /// Delete an entity by ID
  Future<RepositoryResult<void>> delete(ID id);

  /// Check if entity exists
  Future<RepositoryResult<bool>> exists(ID id);

  /// Get count of entities
  Future<RepositoryResult<int>> count([QuerySpec? spec]);
}

/// Extended repository with batch operations
abstract class BatchRepository<T, ID> extends Repository<T, ID> {
  /// Create multiple entities
  Future<RepositoryResult<List<T>>> createMany(List<T> entities);

  /// Update multiple entities
  Future<RepositoryResult<List<T>>> updateMany(List<T> entities);

  /// Delete multiple entities
  Future<RepositoryResult<void>> deleteMany(List<ID> ids);
}

/// Repository with streaming capabilities
abstract class StreamRepository<T, ID> extends Repository<T, ID> {
  /// Watch a single entity
  Stream<T?> watch(ID id);

  /// Watch all entities
  Stream<List<T>> watchAll();

  /// Watch entities matching query
  Stream<List<T>> watchQuery(QuerySpec spec);

  /// Watch count of entities
  Stream<int> watchCount([QuerySpec? spec]);
}

/// Repository with caching capabilities
abstract class CachedRepository<T, ID> extends Repository<T, ID> {
  /// Clear cache for specific entity
  Future<void> invalidate(ID id);

  /// Clear all cache
  Future<void> invalidateAll();

  /// Refresh cache for specific entity
  Future<RepositoryResult<T>> refresh(ID id);

  /// Check if entity is cached
  bool isCached(ID id);

  /// Get cache statistics
  CacheStats getCacheStats();
}

/// Cache statistics
@immutable
class CacheStats {
  const CacheStats({
    required this.hits,
    required this.misses,
    required this.size,
    required this.maxSize,
  });

  final int hits;
  final int misses;
  final int size;
  final int maxSize;

  double get hitRate => hits > 0 ? hits / (hits + misses) : 0.0;
  bool get isFull => size >= maxSize;
}

/// Repository with sync capabilities
abstract class SyncRepository<T, ID> extends Repository<T, ID> {
  /// Sync with remote source
  Future<RepositoryResult<SyncResult>> sync();

  /// Push local changes
  Future<RepositoryResult<void>> push();

  /// Pull remote changes
  Future<RepositoryResult<void>> pull();

  /// Get sync status
  Future<RepositoryResult<SyncStatus>> getSyncStatus();

  /// Resolve conflicts
  Future<RepositoryResult<void>> resolveConflict(ID id, T resolved);
}

/// Sync result information
@immutable
class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.errors,
    required this.duration,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
  final List<RepositoryError> errors;
  final Duration duration;

  bool get hasConflicts => conflicts > 0;
  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => !hasErrors;
}

/// Sync status
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

/// Transaction support for repositories
abstract class TransactionalRepository<T, ID> extends Repository<T, ID> {
  /// Execute operations in a transaction
  Future<RepositoryResult<R>> transaction<R>(
    Future<R> Function(TransactionContext<T, ID> context) action,
  );
}

/// Transaction context for atomic operations
abstract class TransactionContext<T, ID> {
  Future<T> get(ID id);
  Future<List<T>> getAll();
  Future<T> create(T entity);
  Future<T> update(T entity);
  Future<void> delete(ID id);
  Future<void> rollback();
}

/// Repository factory for dependency injection
abstract class RepositoryFactory {
  T create<T>();
  void register<T>(T Function() factory);
  void unregister<T>();
}

/// Base implementation with common functionality
abstract class BaseRepository<T, ID> implements Repository<T, ID> {
  @protected
  RepositoryError createError({
    required String message,
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
    bool retryable = false,
  }) {
    return RepositoryError(
      message: message,
      code: code ?? RepositoryErrorCodes.unknown,
      originalError: originalError,
      stackTrace: stackTrace ?? StackTrace.current,
      retryable: retryable,
    );
  }

  @protected
  Future<RepositoryResult<R>> executeWithErrorHandling<R>(
    Future<R> Function() operation, {
    String? errorMessage,
    bool retryable = false,
  }) async {
    try {
      final result = await operation();
      return RepositoryResult.success(result);
    } catch (error, stackTrace) {
      return RepositoryResult.failure(
        createError(
          message: errorMessage ?? error.toString(),
          originalError: error,
          stackTrace: stackTrace,
          retryable: retryable,
        ),
      );
    }
  }

  @override
  Future<RepositoryResult<bool>> exists(ID id) async {
    final result = await get(id);
    return result.when(
      success: (data) => RepositoryResult.success(true),
      failure: (error) {
        if (error.code == RepositoryErrorCodes.notFound) {
          return RepositoryResult.success(false);
        }
        return RepositoryResult.failure(error);
      },
    );
  }

  @override
  Future<RepositoryResult<int>> count([QuerySpec? spec]) async {
    if (spec == null) {
      final result = await getAll();
      return result.when(
        success: (data) => RepositoryResult.success(data.length),
        failure: (error) => RepositoryResult.failure(error),
      );
    } else {
      final result = await query(spec);
      return result.when(
        success: (data) => RepositoryResult.success(data.length),
        failure: (error) => RepositoryResult.failure(error),
      );
    }
  }
}