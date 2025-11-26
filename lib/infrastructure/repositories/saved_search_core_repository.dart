import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/repositories/i_saved_search_repository.dart';
import 'package:duru_notes/infrastructure/mappers/saved_search_mapper.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Production-grade repository for saved search operations
/// Phase 2.1: Organization Features
///
/// Follows clean architecture patterns established in Phase 1:
/// - Repository pattern for data access
/// - Domain entities for business logic
/// - Error handling and logging
/// - Sentry integration for monitoring
class SavedSearchCoreRepository implements ISavedSearchRepository {
  SavedSearchCoreRepository({required this.db, required this.client})
    : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final _uuid = const Uuid();

  String? get _currentUserId => client.auth.currentUser?.id;

  String _requireUserId({required String method, Map<String, dynamic>? data}) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      final error = StateError(
        'No authenticated user for saved search operation',
      );
      _logger.warning('$method denied - unauthenticated user', data: data);
      _captureRepositoryException(
        method: method,
        error: error,
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      throw error;
    }
    return userId;
  }

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'SavedSearchCoreRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  @override
  Future<List<domain.SavedSearch>> getAllSavedSearches() async {
    final userId = _requireUserId(method: 'getAllSavedSearches');

    try {
      final dbSearches = await db.getSavedSearches();

      // Filter by user ID (security)
      final userSearches = dbSearches.where((s) => s.userId == userId).toList();

      // Map to domain entities
      final domainSearches = userSearches
          .map((dbSearch) => SavedSearchMapper.toDomain(dbSearch))
          .toList();

      _logger.info(
        '[SavedSearchRepository] Retrieved ${domainSearches.length} saved searches',
      );

      return domainSearches;
    } catch (e, stack) {
      _logger.error(
        'Failed to get all saved searches',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getAllSavedSearches',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.SavedSearch>> getSavedSearchesByType(
    String searchType,
  ) async {
    final userId = _requireUserId(
      method: 'getSavedSearchesByType',
      data: {'searchType': searchType},
    );

    try {
      final dbSearches = await db.getSavedSearchesByType(searchType);

      // Filter by user ID (security)
      final userSearches = dbSearches.where((s) => s.userId == userId).toList();

      final domainSearches = userSearches
          .map((dbSearch) => SavedSearchMapper.toDomain(dbSearch))
          .toList();

      _logger.info(
        '[SavedSearchRepository] Retrieved ${domainSearches.length} saved searches of type: $searchType',
      );

      return domainSearches;
    } catch (e, stack) {
      _logger.error(
        'Failed to get saved searches by type: $searchType',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getSavedSearchesByType',
        error: e,
        stackTrace: stack,
        data: {'searchType': searchType},
      );
      rethrow;
    }
  }

  @override
  Future<domain.SavedSearch?> getSavedSearchById(String id) async {
    final userId = _requireUserId(
      method: 'getSavedSearchById',
      data: {'id': id},
    );

    try {
      final dbSearch = await db.getSavedSearchById(id);

      if (dbSearch == null) {
        _logger.debug('[SavedSearchRepository] Saved search not found: $id');
        return null;
      }

      // Security: Verify ownership
      if (dbSearch.userId != userId) {
        _logger.warning(
          '[SavedSearchRepository] Access denied - user $userId attempted to access saved search $id owned by ${dbSearch.userId}',
        );
        throw StateError(
          'Access denied: saved search belongs to different user',
        );
      }

      return SavedSearchMapper.toDomain(dbSearch);
    } catch (e, stack) {
      _logger.error(
        'Failed to get saved search by ID: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getSavedSearchById',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
      rethrow;
    }
  }

  @override
  Future<domain.SavedSearch> upsertSavedSearch(
    domain.SavedSearch search,
  ) async {
    final userId = _requireUserId(
      method: 'upsertSavedSearch',
      data: {'searchId': search.id, 'searchName': search.name},
    );

    try {
      // Generate ID for new searches
      final searchId = search.id.isEmpty ? _uuid.v4() : search.id;

      // Map to database entity
      final dbSearch = SavedSearchMapper.toInfrastructure(
        search.copyWith(id: searchId),
      );

      // Upsert to database
      await db.upsertSavedSearch(dbSearch);

      _logger.info(
        '[SavedSearchRepository] Upserted saved search: $searchId (${search.name})',
      );

      // Return updated domain entity
      return search.copyWith(id: searchId);
    } catch (e, stack) {
      _logger.error(
        'Failed to upsert saved search: ${search.name}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'upsertSavedSearch',
        error: e,
        stackTrace: stack,
        data: {'searchId': search.id, 'searchName': search.name},
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    final userId = _requireUserId(
      method: 'deleteSavedSearch',
      data: {'id': id},
    );

    try {
      // Verify ownership before deletion
      final search = await getSavedSearchById(id);
      if (search == null) {
        _logger.warning(
          '[SavedSearchRepository] Cannot delete non-existent saved search: $id',
        );
        return;
      }

      await db.deleteSavedSearch(id);

      _logger.info('[SavedSearchRepository] Deleted saved search: $id');
    } catch (e, stack) {
      _logger.error(
        'Failed to delete saved search: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'deleteSavedSearch',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
      rethrow;
    }
  }

  @override
  Future<void> updateUsageStatistics(String id) async {
    final userId = _requireUserId(
      method: 'updateUsageStatistics',
      data: {'id': id},
    );

    try {
      // Verify ownership
      final search = await getSavedSearchById(id);
      if (search == null) {
        _logger.warning(
          '[SavedSearchRepository] Cannot update usage for non-existent saved search: $id',
        );
        return;
      }

      await db.updateSavedSearchUsage(id);

      _logger.debug(
        '[SavedSearchRepository] Updated usage statistics for saved search: $id',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to update usage statistics for saved search: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateUsageStatistics',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
      // Don't rethrow - usage tracking is non-critical
    }
  }

  @override
  Future<void> togglePin(String id) async {
    final userId = _requireUserId(method: 'togglePin', data: {'id': id});

    try {
      // Verify ownership
      final search = await getSavedSearchById(id);
      if (search == null) {
        _logger.warning(
          '[SavedSearchRepository] Cannot toggle pin for non-existent saved search: $id',
        );
        return;
      }

      await db.toggleSavedSearchPin(id);

      _logger.info('[SavedSearchRepository] Toggled pin for saved search: $id');
    } catch (e, stack) {
      _logger.error(
        'Failed to toggle pin for saved search: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'togglePin',
        error: e,
        stackTrace: stack,
        data: {'id': id},
      );
      rethrow;
    }
  }

  @override
  Future<void> reorderSavedSearches(List<String> orderedIds) async {
    final userId = _requireUserId(
      method: 'reorderSavedSearches',
      data: {'count': orderedIds.length},
    );

    try {
      // Verify all searches belong to user
      for (final id in orderedIds) {
        final search = await getSavedSearchById(id);
        if (search == null) {
          throw StateError(
            'Cannot reorder: saved search $id does not exist or access denied',
          );
        }
      }

      await db.reorderSavedSearches(orderedIds);

      _logger.info(
        '[SavedSearchRepository] Reordered ${orderedIds.length} saved searches',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to reorder saved searches',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'reorderSavedSearches',
        error: e,
        stackTrace: stack,
        data: {'count': orderedIds.length},
      );
      rethrow;
    }
  }

  @override
  Stream<List<domain.SavedSearch>> watchSavedSearches() {
    final userId = _requireUserId(method: 'watchSavedSearches');

    try {
      // Watch database changes and filter by user ID (security)
      return db.watchSavedSearches().map((dbSearches) {
        return dbSearches
            .where((dbSearch) => dbSearch.userId == userId)
            .map((dbSearch) => SavedSearchMapper.toDomain(dbSearch))
            .toList();
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to watch saved searches',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'watchSavedSearches',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.SavedSearch>> searchByName(String query) async {
    final userId = _requireUserId(
      method: 'searchByName',
      data: {'query': query},
    );

    try {
      final allSearches = await getAllSavedSearches();

      // Simple case-insensitive contains search
      final matchingSearches = allSearches
          .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      _logger.debug(
        '[SavedSearchRepository] Found ${matchingSearches.length} saved searches matching "$query"',
      );

      return matchingSearches;
    } catch (e, stack) {
      _logger.error(
        'Failed to search saved searches by name: $query',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'searchByName',
        error: e,
        stackTrace: stack,
        data: {'query': query},
      );
      rethrow;
    }
  }
}
