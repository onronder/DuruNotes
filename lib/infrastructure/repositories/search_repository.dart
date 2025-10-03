import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/infrastructure/mappers/saved_search_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;

/// Search repository implementation
class SearchRepository implements ISearchRepository {
  SearchRepository({
    required this.db,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final AppLogger _logger;

  @override
  Future<void> createOrUpdateSavedSearch(domain.SavedSearch savedSearch) async {
    final dbSearch = SavedSearchMapper.toInfrastructure(savedSearch);
    await db.upsertSavedSearch(dbSearch);
    // Enqueue for sync
    await db.enqueue(
      savedSearch.id,
      'upsert_saved_search',
      payload: jsonEncode(dbSearch.toJson()),
    );
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    await db.deleteSavedSearch(id);
    // Enqueue for sync
    await db.enqueue(id, 'delete_saved_search');
  }

  @override
  Future<List<domain.SavedSearch>> getSavedSearches() async {
    final dbSearches = await db.getSavedSearches();
    return SavedSearchMapper.toDomainList(dbSearches);
  }

  @override
  Stream<List<domain.SavedSearch>> watchSavedSearches() {
    return db.watchSavedSearches().map((dbSearches) {
      return SavedSearchMapper.toDomainList(dbSearches);
    });
  }

  @override
  Future<void> toggleSavedSearchPin(String id) => db.toggleSavedSearchPin(id);

  @override
  Future<void> trackSavedSearchUsage(String id) =>
      db.updateSavedSearchUsage(id);

  @override
  Future<void> reorderSavedSearches(List<String> ids) =>
      db.reorderSavedSearches(ids);

  @override
  Future<List<domain.Note>> executeSavedSearch(domain.SavedSearch savedSearch) async {
    // Convert domain SavedSearch to db SavedSearch
    final dbSearch = SavedSearchMapper.toInfrastructure(savedSearch);

    // Parse the saved search query
    final query = dbSearch.query;
    final searchType = dbSearch.searchType;

    // Parse parameters JSON if present
    Map<String, dynamic>? params;
    if (dbSearch.parameters != null) {
      try {
        params = jsonDecode(dbSearch.parameters!) as Map<String, dynamic>;
      } catch (e) {
        _logger.error('Failed to parse saved search parameters', error: e);
      }
    }

    // Execute based on search type
    switch (searchType) {
      case 'text':
        final results = await db.searchNotes(query);
        return results.map((ln) => NoteMapper.toDomain(ln)).toList();
      case 'tags':
        final tags = (params?['tags'] as List?)?.cast<String>() ?? [];
        final results = await db.notesByTags(
          anyTags: tags,
          noneTags: [],
          sort: const SortSpec(),
        );
        return results.map<domain.Note>((ln) => NoteMapper.toDomain(ln)).toList();
      case 'folder':
        final folderId = params?['folderId'] as String?;
        if (folderId != null) {
          final results = await db.getNotesInFolder(folderId);
          return results.map((ln) => NoteMapper.toDomain(ln)).toList();
        }
        return [];
      case 'advanced':
        // Advanced search with multiple criteria
        final results = await _executeAdvancedSearch(params ?? {});
        return results.map((ln) => NoteMapper.toDomain(ln)).toList();
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