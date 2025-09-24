import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:flutter/foundation.dart';

/// Search repository implementation
class SearchRepository implements ISearchRepository {
  SearchRepository({
    required this.db,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final AppLogger _logger;

  @override
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch) async {
    await db.upsertSavedSearch(savedSearch);
    // Enqueue for sync
    await db.enqueue(
      savedSearch.id,
      'upsert_saved_search',
      payload: jsonEncode(savedSearch.toJson()),
    );
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    await db.deleteSavedSearch(id);
    // Enqueue for sync
    await db.enqueue(id, 'delete_saved_search');
  }

  @override
  Future<List<SavedSearch>> getSavedSearches() => db.getSavedSearches();

  @override
  Stream<List<SavedSearch>> watchSavedSearches() => db.watchSavedSearches();

  @override
  Future<void> toggleSavedSearchPin(String id) => db.toggleSavedSearchPin(id);

  @override
  Future<void> trackSavedSearchUsage(String id) =>
      db.updateSavedSearchUsage(id);

  @override
  Future<void> reorderSavedSearches(List<String> ids) =>
      db.reorderSavedSearches(ids);

  @override
  Future<List<LocalNote>> executeSavedSearch(SavedSearch savedSearch) async {
    // Parse the saved search query
    final query = savedSearch.query;
    final searchType = savedSearch.searchType;

    // Parse parameters JSON if present
    Map<String, dynamic>? params;
    if (savedSearch.parameters != null) {
      try {
        params = jsonDecode(savedSearch.parameters!) as Map<String, dynamic>;
      } catch (e) {
        _logger.error('Failed to parse saved search parameters', error: e);
      }
    }

    // Execute based on search type
    switch (searchType) {
      case 'text':
        return db.searchNotes(query);
      case 'tags':
        final tags = (params?['tags'] as List?)?.cast<String>() ?? [];
        return db.notesByTags(
          anyTags: tags,
          noneTags: [],
          sort: const SortSpec(),
        );
      case 'folder':
        final folderId = params?['folderId'] as String?;
        if (folderId != null) {
          return db.getNotesInFolder(folderId);
        }
        return [];
      case 'advanced':
        // Advanced search with multiple criteria
        return _executeAdvancedSearch(params ?? {});
      default:
        _logger.warning('Unknown search type: $searchType');
        return [];
    }
  }

  Future<List<LocalNote>> _executeAdvancedSearch(
      Map<String, dynamic> params) async {
    // This would implement complex search logic
    // For now, returning empty list
    _logger.debug('Executing advanced search with params: $params');
    return [];
  }
}