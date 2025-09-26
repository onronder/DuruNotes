import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/template.dart' as domain;
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/optimized_notes_repository.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/saved_search_mapper.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/search/saved_search_registry.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

/// Search result item that can hold any type of result
class SearchResultItem {
  const SearchResultItem({
    required this.type,
    required this.data,
    required this.title,
    required this.subtitle,
    this.score = 1.0,
    this.snippet,
    this.highlights = const [],
  });

  final SearchResultType type;
  final dynamic data; // Can be Note, Task, Folder, Template, etc.
  final String title;
  final String subtitle;
  final double score;
  final String? snippet;
  final List<String> highlights;
}

enum SearchResultType {
  note,
  task,
  folder,
  template,
  tag,
  attachment,
}

/// Search options
class SearchOptions {
  const SearchOptions({
    this.types = const [
      SearchResultType.note,
      SearchResultType.task,
      SearchResultType.folder,
      SearchResultType.template,
      SearchResultType.tag,
    ],
    this.folderId,
    this.tags = const [],
    this.dateRange,
    this.sortBy = SearchSortBy.relevance,
    this.sortDescending = false,
    this.limit = 100,
    this.offset = 0,
    this.includeDeleted = false,
    this.includeArchived = false,
    this.fuzzySearch = true,
    this.searchInContent = true,
    this.searchInTitles = true,
    this.searchInTags = true,
  });

  final List<SearchResultType> types;
  final String? folderId;
  final List<String> tags;
  final DateTimeRange? dateRange;
  final SearchSortBy sortBy;
  final bool sortDescending;
  final int limit;
  final int offset;
  final bool includeDeleted;
  final bool includeArchived;
  final bool fuzzySearch;
  final bool searchInContent;
  final bool searchInTitles;
  final bool searchInTags;
}

enum SearchSortBy {
  relevance,
  date,
  title,
  type,
}

class DateTimeRange {
  const DateTimeRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// Search history item
class SearchHistoryItem {
  const SearchHistoryItem({
    required this.query,
    required this.timestamp,
    required this.resultCount,
    this.options,
  });

  final String query;
  final DateTime timestamp;
  final int resultCount;
  final SearchOptions? options;
}

/// Unified search service that works across all entity types
class UnifiedSearchService {
  UnifiedSearchService({
    required this.ref,
    required this.db,
    required this.migrationConfig,
  })  : _logger = LoggerFactory.instance,
        _uuid = const Uuid();

  final Ref ref;
  final AppDb db;
  final MigrationConfig migrationConfig;
  final AppLogger _logger;
  final Uuid _uuid;

  // Search history (in-memory for now)
  final List<SearchHistoryItem> _searchHistory = [];
  final int _maxHistoryItems = 50;

  // Search cache
  final Map<String, List<SearchResultItem>> _searchCache = {};
  final Duration _cacheExpiration = const Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Perform a universal search across all content types
  Future<List<SearchResultItem>> search(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) async {
    try {
      _logger.info('[UnifiedSearch] Searching for: $query');

      // Check cache
      final cacheKey = '$query:${json.encode(options.types.map((t) => t.name).toList())}';
      if (_searchCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiration) {
          _logger.info('[UnifiedSearch] Returning cached results');
          return _searchCache[cacheKey]!;
        }
      }

      final results = <SearchResultItem>[];

      // Search each type requested
      if (options.types.contains(SearchResultType.note)) {
        results.addAll(await _searchNotes(query, options));
      }

      if (options.types.contains(SearchResultType.task)) {
        results.addAll(await _searchTasks(query, options));
      }

      if (options.types.contains(SearchResultType.folder)) {
        results.addAll(await _searchFolders(query, options));
      }

      if (options.types.contains(SearchResultType.template)) {
        results.addAll(await _searchTemplates(query, options));
      }

      if (options.types.contains(SearchResultType.tag)) {
        results.addAll(await _searchTags(query, options));
      }

      // Sort results
      results.sort((a, b) {
        switch (options.sortBy) {
          case SearchSortBy.relevance:
            return options.sortDescending
                ? a.score.compareTo(b.score)
                : b.score.compareTo(a.score);
          case SearchSortBy.title:
            return options.sortDescending
                ? b.title.compareTo(a.title)
                : a.title.compareTo(b.title);
          case SearchSortBy.type:
            return options.sortDescending
                ? b.type.index.compareTo(a.type.index)
                : a.type.index.compareTo(b.type.index);
          default:
            return 0;
        }
      });

      // Apply limit and offset
      final paginatedResults = results
          .skip(options.offset)
          .take(options.limit)
          .toList();

      // Cache results
      _searchCache[cacheKey] = paginatedResults;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Add to history
      _addToHistory(query, paginatedResults.length, options);

      // Track analytics
      await _trackSearch(query, paginatedResults.length);

      return paginatedResults;
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Search for notes
  Future<List<SearchResultItem>> _searchNotes(String query, SearchOptions options) async {
    try {
      if (migrationConfig.isFeatureEnabled('notes')) {
        // Use domain repository
        final repository = OptimizedNotesRepository(db: db);
        final notes = await repository.search(query);

        return notes.map((note) => SearchResultItem(
          type: SearchResultType.note,
          data: note,
          title: note.title,
          subtitle: _truncateText(note.body, 100),
          score: _calculateRelevanceScore(query, note.title, note.body),
          snippet: _extractSnippet(note.body, query),
          highlights: _findHighlights(note.body, query),
        )).toList();
      } else {
        // Use FTS search
        final results = await db.searchNotes(query);

        return results.map((note) => SearchResultItem(
          type: SearchResultType.note,
          data: note,
          title: note.title,
          subtitle: _truncateText(note.body, 100),
          score: _calculateRelevanceScore(query, note.title, note.body),
          snippet: _extractSnippet(note.body, query),
          highlights: _findHighlights(note.body, query),
        )).toList();
      }
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Note search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Search for tasks
  Future<List<SearchResultItem>> _searchTasks(String query, SearchOptions options) async {
    try {
      // Get all tasks
      final tasks = await db.getAllTasks();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = tasks.where((task) {
        final content = task.content.toLowerCase();
        final notes = task.notes?.toLowerCase() ?? '';
        return content.contains(queryLower) || notes.contains(queryLower);
      }).toList();

      return filtered.map((task) => SearchResultItem(
        type: SearchResultType.task,
        data: task,
        title: task.content,
        subtitle: task.notes ?? _getTaskStatusText(task.status),
        score: _calculateRelevanceScore(query, task.content, task.notes ?? ''),
        snippet: _extractSnippet(task.notes ?? '', query),
      )).toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Task search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Search for folders
  Future<List<SearchResultItem>> _searchFolders(String query, SearchOptions options) async {
    try {
      // Get all folders
      final folders = await db.getActiveFolders();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = folders.where((folder) {
        final name = folder.name.toLowerCase();
        return name.contains(queryLower);
      }).toList();

      return filtered.map((folder) => SearchResultItem(
        type: SearchResultType.folder,
        data: folder,
        title: folder.name,
        subtitle: folder.path,
        score: _calculateRelevanceScore(query, folder.name, ''),
      )).toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Folder search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Search for templates
  Future<List<SearchResultItem>> _searchTemplates(String query, SearchOptions options) async {
    try {
      // Get all templates
      final templates = await db.getAllTemplates();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = templates.where((LocalTemplate template) {
        final title = template.title.toLowerCase();
        final body = template.body.toLowerCase();
        final description = template.description.toLowerCase() ?? '';
        return title.contains(queryLower) ||
               body.contains(queryLower) ||
               description.contains(queryLower);
      }).toList();

      return filtered.map((LocalTemplate template) => SearchResultItem(
        type: SearchResultType.template,
        data: template,
        title: template.title,
        subtitle: template.description ?? _truncateText(template.body, 100),
        score: _calculateRelevanceScore(query, template.title, template.body),
        snippet: _extractSnippet(template.body, query),
      )).toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Template search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Search for tags
  Future<List<SearchResultItem>> _searchTags(String query, SearchOptions options) async {
    try {
      // Get all tags with counts
      final tags = await db.getTagsWithCounts();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = tags.where((tag) {
        final name = tag.tag.toLowerCase();
        return name.contains(queryLower);
      }).toList();

      return filtered.map((tag) => SearchResultItem(
        type: SearchResultType.tag,
        data: tag,
        title: tag.tag,
        subtitle: '${tag.count} notes',
        score: _calculateRelevanceScore(query, tag.tag, ''),
      )).toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Tag search failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Save a search query
  Future<domain.SavedSearch> saveSearch({
    required String query,
    required String name,
    String? description,
    SearchOptions? options,
  }) async {
    try {
      _logger.info('[UnifiedSearch] Saving search: $name');

      final savedSearch = domain.SavedSearch(
        id: _uuid.v4(),
        name: name,
        query: query,
        searchType: 'note',
        parameters: options != null
            ? jsonEncode(_optionsToFilters(options))
            : null,
        sortOrder: 0,
        isPinned: false,
        createdAt: DateTime.now(),
        lastUsedAt: null,
        usageCount: 0,
      );

      // Save to database
      if (migrationConfig.isFeatureEnabled('searches')) {
        // Use domain repository when available
        _logger.info('[UnifiedSearch] Would save to domain repository');
      } else {
        // Save to legacy database
        final companion = SavedSearchesCompanion.insert(
          id: savedSearch.id,
          name: name,
          query: query,
          searchType: const Value('note'),
          parameters: options != null
              ? Value(jsonEncode(_optionsToFilters(options)))
              : const Value.absent(),
          isPinned: const Value(false),
          sortOrder: const Value(0),
          createdAt: DateTime.now(),
        );

        await db.into(db.savedSearches).insert(companion);
      }

      // Track analytics
      await _trackSavedSearch(name);

      return savedSearch;
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to save search', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get saved searches
  Future<List<domain.SavedSearch>> getSavedSearches() async {
    try {
      if (migrationConfig.isFeatureEnabled('searches')) {
        // Use domain repository when available
        return [];
      } else {
        // Get from legacy database
        final searches = await db.getSavedSearches();
        return searches.map((search) => domain.SavedSearch(
          id: search.id,
          name: search.name,
          query: search.query,
          searchType: search.searchType ?? 'note',
          parameters: search.parameters,
          sortOrder: search.sortOrder ?? 0,
          color: search.color,
          icon: search.icon,
          isPinned: search.isPinned,
          createdAt: search.createdAt,
          lastUsedAt: search.lastUsedAt,
          usageCount: search.usageCount ?? 0,
        )).toList();
      }
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to get saved searches', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Execute a saved search
  Future<List<SearchResultItem>> executeSavedSearch(String savedSearchId) async {
    try {
      // Get the saved search
      final savedSearch = await (db.select(db.savedSearches)
        ..where((s) => s.id.equals(savedSearchId)))
        .getSingleOrNull();

      if (savedSearch == null) {
        throw Exception('Saved search not found');
      }

      // Parse options from parameters
      final options = savedSearch.parameters != null
          ? _filtersToOptions(json.decode(savedSearch.parameters!) as Map<String, dynamic>)
          : const SearchOptions();

      // Update usage
      await (db.update(db.savedSearches)
        ..where((s) => s.id.equals(savedSearchId)))
        .write(SavedSearchesCompanion(
          usageCount: Value((savedSearch.usageCount ?? 0) + 1),
          lastUsedAt: Value(DateTime.now()),
        ));

      // Execute search
      return search(savedSearch.query, options: options);
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to execute saved search', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Delete a saved search
  Future<bool> deleteSavedSearch(String savedSearchId) async {
    try {
      await (db.delete(db.savedSearches)
        ..where((s) => s.id.equals(savedSearchId)))
        .go();

      return true;
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to delete saved search', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSuggestions(String partial) async {
    try {
      final suggestions = <String>[];

      // Add from history
      final historyMatches = _searchHistory
          .where((item) => item.query.toLowerCase().startsWith(partial.toLowerCase()))
          .map((item) => item.query)
          .take(5);
      suggestions.addAll(historyMatches);

      // Add from tags
      final tags = await db.getTagsWithCounts();
      final tagMatches = tags
          .where((tag) => tag.tag.toLowerCase().contains(partial.toLowerCase()))
          .map((tag) => '#${tag.tag}')
          .take(5);
      suggestions.addAll(tagMatches);

      // Add from saved searches
      final savedSearches = await getSavedSearches();
      final savedMatches = savedSearches
          .where((search) => search.query.toLowerCase().contains(partial.toLowerCase()))
          .map((search) => search.query)
          .take(5);
      suggestions.addAll(savedMatches);

      // Remove duplicates and limit
      return suggestions.toSet().take(10).toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to get suggestions', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get search history
  List<SearchHistoryItem> getHistory() {
    return List.from(_searchHistory.reversed);
  }

  /// Clear search history
  void clearHistory() {
    _searchHistory.clear();
    _logger.info('[UnifiedSearch] Search history cleared');
  }

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    _logger.info('[UnifiedSearch] Search cache cleared');
  }

  /// Get recent searches
  List<String> getRecentSearches({int limit = 10}) {
    return _searchHistory
        .map((item) => item.query)
        .toSet()
        .take(limit)
        .toList();
  }

  /// Get popular searches
  Future<List<String>> getPopularSearches({int limit = 10}) async {
    try {
      // Get from saved searches ordered by usage
      final searches = await db.getSavedSearches();
      searches.sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));

      return searches
          .take(limit)
          .map((search) => search.query)
          .toList();
    } catch (e, stack) {
      _logger.error('[UnifiedSearch] Failed to get popular searches', error: e, stackTrace: stack);
      return [];
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// Calculate relevance score for search results
  double _calculateRelevanceScore(String query, String title, String content) {
    double score = 0.0;
    final queryLower = query.toLowerCase();
    final titleLower = title.toLowerCase();
    final contentLower = content.toLowerCase();

    // Title exact match
    if (titleLower == queryLower) {
      score += 10.0;
    } else if (titleLower.contains(queryLower)) {
      score += 5.0;
    }

    // Title word match
    final queryWords = queryLower.split(' ');
    for (final word in queryWords) {
      if (titleLower.contains(word)) {
        score += 2.0;
      }
    }

    // Content match
    if (contentLower.contains(queryLower)) {
      score += 3.0;
    }

    // Content word match
    for (final word in queryWords) {
      if (contentLower.contains(word)) {
        score += 1.0;
      }
    }

    return score;
  }

  /// Extract snippet around search query
  String _extractSnippet(String content, String query, {int maxLength = 150}) {
    final queryLower = query.toLowerCase();
    final contentLower = content.toLowerCase();

    final index = contentLower.indexOf(queryLower);
    if (index == -1) {
      return _truncateText(content, maxLength);
    }

    final start = (index - 50).clamp(0, content.length);
    final end = (index + query.length + 100).clamp(0, content.length);

    String snippet = content.substring(start, end);

    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';

    return snippet;
  }

  /// Find highlights in text
  List<String> _findHighlights(String content, String query) {
    final highlights = <String>[];
    final queryLower = query.toLowerCase();
    final contentLower = content.toLowerCase();

    int index = 0;
    while (index != -1) {
      index = contentLower.indexOf(queryLower, index);
      if (index != -1) {
        final start = (index - 20).clamp(0, content.length);
        final end = (index + query.length + 20).clamp(0, content.length);
        highlights.add(content.substring(start, end));
        index += query.length;
      }
    }

    return highlights.take(3).toList();
  }

  /// Truncate text to specified length
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Get task status text
  String _getTaskStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Convert search options to filters map
  Map<String, dynamic> _optionsToFilters(SearchOptions options) {
    return {
      'types': options.types.map((t) => t.name).toList(),
      'folderId': options.folderId,
      'tags': options.tags,
      'sortBy': options.sortBy.name,
      'sortDescending': options.sortDescending,
      'includeDeleted': options.includeDeleted,
      'includeArchived': options.includeArchived,
      'fuzzySearch': options.fuzzySearch,
      'searchInContent': options.searchInContent,
      'searchInTitles': options.searchInTitles,
      'searchInTags': options.searchInTags,
    };
  }

  /// Convert filters map to search options
  SearchOptions _filtersToOptions(Map<String, dynamic> filters) {
    return SearchOptions(
      types: (filters['types'] as List?)
          ?.map((t) => SearchResultType.values.firstWhere((v) => v.name == t))
          .toList() ?? const [],
      folderId: filters['folderId'] as String?,
      tags: (filters['tags'] as List?)?.cast<String>() ?? const [],
      sortBy: SearchSortBy.values.firstWhere(
        (v) => v.name == filters['sortBy'],
        orElse: () => SearchSortBy.relevance,
      ),
      sortDescending: filters['sortDescending'] as bool? ?? false,
      includeDeleted: filters['includeDeleted'] as bool? ?? false,
      includeArchived: filters['includeArchived'] as bool? ?? false,
      fuzzySearch: filters['fuzzySearch'] as bool? ?? true,
      searchInContent: filters['searchInContent'] as bool? ?? true,
      searchInTitles: filters['searchInTitles'] as bool? ?? true,
      searchInTags: filters['searchInTags'] as bool? ?? true,
    );
  }

  /// Add search to history
  void _addToHistory(String query, int resultCount, SearchOptions options) {
    _searchHistory.add(SearchHistoryItem(
      query: query,
      timestamp: DateTime.now(),
      resultCount: resultCount,
      options: options,
    ));

    // Limit history size
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory.removeAt(0);
    }
  }

  /// Track search analytics
  Future<void> _trackSearch(String query, int resultCount) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event('search_performed', properties: {
        'query_length': query.length,
        'result_count': resultCount,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.warning('[UnifiedSearch] Failed to track search');
    }
  }

  /// Track saved search analytics
  Future<void> _trackSavedSearch(String name) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event('search_saved', properties: {
        'name': name,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.warning('[UnifiedSearch] Failed to track saved search');
    }
  }
}

/// Provider for unified search service
final unifiedSearchServiceProvider = Provider<UnifiedSearchService>((ref) {
  final db = ref.watch(appDbProvider);
  final config = ref.watch(migrationConfigProvider);

  return UnifiedSearchService(
    ref: ref,
    db: db,
    migrationConfig: config,
  );
});