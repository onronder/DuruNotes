import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider, analyticsProvider;
import 'package:duru_notes/domain/entities/saved_search.dart' as saved_search;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show ftsIndexingServiceProvider, notesCoreRepositoryProvider;
import 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateCoreRepositoryProvider;
import 'package:duru_notes/services/search/fts_indexing_service.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';

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

enum SearchResultType { note, task, folder, template, tag, attachment }

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

enum SearchSortBy { relevance, date, title, type }

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
///
/// Production-grade search with FTS (Full-Text Search) support:
/// - Uses FTSIndexingService for encrypted content search
/// - Falls back to in-memory search if FTS unavailable
/// - Caches results for performance
/// - Tracks search history and analytics
class UnifiedSearchService {
  UnifiedSearchService({
    required this.ref,
    required this.migrationConfig,
    required INotesRepository notesRepository,
    required ITaskRepository taskRepository,
    required IFolderRepository folderRepository,
    required ITemplateRepository templateRepository,
    required NoteIndexer noteIndexer,
    FTSIndexingService? ftsService,
  }) : _notesRepository = notesRepository,
       _taskRepository = taskRepository,
       _folderRepository = folderRepository,
       _templateRepository = templateRepository,
       _noteIndexer = noteIndexer,
       _ftsService = ftsService,
       _logger = LoggerFactory.instance,
       _uuid = const Uuid();

  final Ref ref;
  final MigrationConfig migrationConfig;
  final INotesRepository _notesRepository;
  final ITaskRepository _taskRepository;
  final IFolderRepository _folderRepository;
  final ITemplateRepository _templateRepository;
  final NoteIndexer _noteIndexer;
  final FTSIndexingService? _ftsService;
  final AppLogger _logger;
  final Uuid _uuid;

  // FTS status
  bool _ftsInitialized = false;
  bool get isFTSEnabled => _ftsService != null && _ftsInitialized;

  // Search history (in-memory for now)
  final List<SearchHistoryItem> _searchHistory = [];
  final int _maxHistoryItems = 50;

  // Search cache
  final Map<String, List<SearchResultItem>> _searchCache = {};
  final Duration _cacheExpiration = const Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Initialize the service (including FTS if available)
  Future<void> initialize() async {
    try {
      if (_ftsService != null) {
        _logger.info('[UnifiedSearch] Initializing FTS indexing service');
        await _ftsService.initialize();
        _ftsInitialized = true;

        // Index all notes in background
        _indexAllNotesInBackground();
      } else {
        _logger.info(
          '[UnifiedSearch] FTS service not available, using in-memory search',
        );
      }
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] FTS initialization failed, falling back to in-memory search',
        error: e,
        stackTrace: stack,
      );
      _ftsInitialized = false;
    }
  }

  /// Index all notes in background for FTS
  void _indexAllNotesInBackground() {
    Future.microtask(() async {
      try {
        _logger.info('[UnifiedSearch] Starting background note indexing');
        final notes = await _notesRepository.localNotes();

        for (final note in notes) {
          await _ftsService?.indexNote(
            noteId: note.id,
            title: note.title,
            body: note.body,
            tags: note.tags,
          );
        }

        _logger.info(
          '[UnifiedSearch] Background indexing complete: ${notes.length} notes',
        );
      } catch (e, stack) {
        _logger.error(
          '[UnifiedSearch] Background indexing failed',
          error: e,
          stackTrace: stack,
        );
      }
    });
  }

  /// Index a single note (call after create/update)
  Future<void> indexNote(
    String noteId,
    String title,
    String body,
    List<String> tags,
  ) async {
    if (_ftsService == null || !_ftsInitialized) return;

    try {
      await _ftsService.indexNote(
        noteId: noteId,
        title: title,
        body: body,
        tags: tags,
      );
      _logger.debug('[UnifiedSearch] Indexed note: $noteId');
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to index note $noteId',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Remove a note from index (call after delete)
  Future<void> removeNoteFromIndex(String noteId) async {
    if (_ftsService == null || !_ftsInitialized) return;

    try {
      await _ftsService.removeNote(noteId);
      _logger.debug('[UnifiedSearch] Removed note from index: $noteId');
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to remove note from index',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    if (_ftsService != null) {
      await _ftsService.dispose();
    }
  }

  /// Perform a universal search across all content types
  Future<List<SearchResultItem>> search(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) async {
    try {
      _logger.info('[UnifiedSearch] Searching for: $query');

      // Check cache
      final cacheKey =
          '$query:${json.encode(options.types.map((t) => t.name).toList())}';
      if (_searchCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < _cacheExpiration) {
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
      _logger.error(
        '[UnifiedSearch] Search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Search for notes
  Future<List<SearchResultItem>> _searchNotes(
    String query,
    SearchOptions options,
  ) async {
    try {
      // Use FTS if available, otherwise fall back to in-memory search
      if (isFTSEnabled) {
        return await _searchNotesWithFTS(query, options);
      } else {
        return await _searchNotesInMemory(query, options);
      }
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Note search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Search notes using FTS (production-grade encrypted search)
  Future<List<SearchResultItem>> _searchNotesWithFTS(
    String query,
    SearchOptions options,
  ) async {
    try {
      _logger.debug('[UnifiedSearch] Using FTS for note search');

      // Get FTS results (already ranked by TF-IDF)
      final ftsResults = await _ftsService!.search(query);

      // Fetch full note objects from repository
      final allNotes = await _notesRepository.localNotes();
      final noteMap = {for (final note in allNotes) note.id: note};

      // Map FTS results to SearchResultItem
      final results = <SearchResultItem>[];
      for (final ftsResult in ftsResults) {
        final note = noteMap[ftsResult.noteId];
        if (note == null) continue;

        results.add(
          SearchResultItem(
            type: SearchResultType.note,
            data: note,
            title: note.title,
            subtitle: _truncateText(note.body, 100),
            score: ftsResult.score, // Use TF-IDF score from FTS
            snippet: ftsResult.snippet,
            highlights: ftsResult.highlightedTerms,
          ),
        );
      }

      _logger.debug(
        '[UnifiedSearch] FTS returned ${results.length} note results',
      );
      return results;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] FTS search failed, falling back to in-memory',
        error: e,
        stackTrace: stack,
      );
      return await _searchNotesInMemory(query, options);
    }
  }

  /// Search notes using in-memory filtering (fallback)
  Future<List<SearchResultItem>> _searchNotesInMemory(
    String query,
    SearchOptions options,
  ) async {
    try {
      _logger.debug('[UnifiedSearch] Using NoteIndexer for note search');

      final trimmedQuery = query.trim();
      Set<String>? candidateIds;

      if (trimmedQuery.isNotEmpty) {
        candidateIds = _noteIndexer.searchNotes(trimmedQuery);
      }

      if (options.tags.isNotEmpty) {
        for (final tag in options.tags) {
          final notesWithTag = _noteIndexer.findNotesByTag(tag);
          if (candidateIds == null) {
            candidateIds = {...notesWithTag};
          } else {
            candidateIds = candidateIds.intersection(notesWithTag);
          }
        }
      }

      List<domain.Note> matchedNotes;

      if (candidateIds == null) {
        // No query or tag filters – fall back to repository list
        matchedNotes = await _notesRepository.localNotes();
      } else if (candidateIds.isEmpty) {
        // Index has no matches – fall back to legacy scan in case index is still warming up
        return _legacyInMemorySearch(query, options);
      } else {
        final noteFutures = candidateIds.map(_notesRepository.getNoteById);
        final fetched = await Future.wait(noteFutures);
        matchedNotes = fetched.whereType<domain.Note>().toList();
      }

      // Apply folder filter if provided
      matchedNotes = matchedNotes.where((note) {
        if (options.folderId != null && note.folderId != options.folderId) {
          return false;
        }
        if (options.tags.isNotEmpty) {
          final noteTagsLower = note.tags.map((t) => t.toLowerCase()).toSet();
          for (final tag in options.tags) {
            if (!noteTagsLower.contains(tag.toLowerCase())) {
              return false;
            }
          }
        }
        return true;
      }).toList();

      if (matchedNotes.isEmpty && trimmedQuery.isNotEmpty) {
        // Final fallback to legacy approach
        return _legacyInMemorySearch(query, options);
      }

      return matchedNotes
          .map(
            (note) => SearchResultItem(
              type: SearchResultType.note,
              data: note,
              title: note.title,
              subtitle: _truncateText(note.body, 100),
              score: _calculateRelevanceScore(query, note.title, note.body),
              snippet: _extractSnippet(note.body, query),
              highlights: _findHighlights(note.body, query),
            ),
          )
          .toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] In-memory note search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<SearchResultItem>> _legacyInMemorySearch(
    String query,
    SearchOptions options,
  ) async {
    final allNotes = await _notesRepository.localNotes();
    final queryLower = query.toLowerCase();
    return allNotes
        .where((note) {
          final titleLower = note.title.toLowerCase();
          final bodyLower = note.body.toLowerCase();

          final matchesQuery =
              queryLower.isEmpty ||
              titleLower.contains(queryLower) ||
              bodyLower.contains(queryLower);
          if (!matchesQuery) return false;

          if (options.folderId != null && note.folderId != options.folderId) {
            return false;
          }
          if (options.tags.isNotEmpty) {
            final noteTagsLower = note.tags.map((t) => t.toLowerCase()).toSet();
            for (final tag in options.tags) {
              if (!noteTagsLower.contains(tag.toLowerCase())) {
                return false;
              }
            }
          }
          return true;
        })
        .map(
          (note) => SearchResultItem(
            type: SearchResultType.note,
            data: note,
            title: note.title,
            subtitle: _truncateText(note.body, 100),
            score: _calculateRelevanceScore(query, note.title, note.body),
            snippet: _extractSnippet(note.body, query),
            highlights: _findHighlights(note.body, query),
          ),
        )
        .toList();
  }

  /// Search for tasks
  Future<List<SearchResultItem>> _searchTasks(
    String query,
    SearchOptions options,
  ) async {
    try {
      // Search tasks (repository handles decryption and filtering)
      final tasks = await _taskRepository.searchTasks(query);

      return tasks
          .map(
            (task) => SearchResultItem(
              type: SearchResultType.task,
              data: task,
              title: task.title,
              subtitle: task.description ?? _getTaskStatusText(task.status),
              score: _calculateRelevanceScore(
                query,
                task.title,
                task.description ?? '',
              ),
              snippet: _extractSnippet(task.description ?? '', query),
            ),
          )
          .toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Task search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Search for folders
  Future<List<SearchResultItem>> _searchFolders(
    String query,
    SearchOptions options,
  ) async {
    try {
      // Get all folders
      final folders = await _folderRepository.listFolders();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = folders.where((folder) {
        final name = folder.name.toLowerCase();
        return name.contains(queryLower);
      }).toList();

      return filtered
          .map(
            (folder) => SearchResultItem(
              type: SearchResultType.folder,
              data: folder,
              title: folder.name,
              subtitle: folder.description ?? '',
              score: _calculateRelevanceScore(
                query,
                folder.name,
                folder.description ?? '',
              ),
            ),
          )
          .toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Folder search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Search for templates
  Future<List<SearchResultItem>> _searchTemplates(
    String query,
    SearchOptions options,
  ) async {
    try {
      // Get all templates
      final templates = await _templateRepository.getAllTemplates();

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = templates.where((template) {
        final name = template.name.toLowerCase();
        final content = template.content.toLowerCase();
        return name.contains(queryLower) || content.contains(queryLower);
      }).toList();

      return filtered
          .map(
            (template) => SearchResultItem(
              type: SearchResultType.template,
              data: template,
              title: template.name,
              subtitle: _truncateText(template.content, 100),
              score: _calculateRelevanceScore(
                query,
                template.name,
                template.content,
              ),
              snippet: _extractSnippet(template.content, query),
            ),
          )
          .toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Template search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Search for tags
  Future<List<SearchResultItem>> _searchTags(
    String query,
    SearchOptions options,
  ) async {
    try {
      // TODO: Add tag repository when available
      // For now, search tags by getting all notes and extracting tags
      final notes = await _notesRepository.localNotes();
      final tagCounts = <String, int>{};

      for (final note in notes) {
        final tags = note.tags;
        for (final tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      // Filter by query
      final queryLower = query.toLowerCase();
      final filtered = tagCounts.entries.where((entry) {
        return entry.key.toLowerCase().contains(queryLower);
      }).toList();

      return filtered
          .map(
            (entry) => SearchResultItem(
              type: SearchResultType.tag,
              data: entry.key,
              title: entry.key,
              subtitle: '${entry.value} notes',
              score: _calculateRelevanceScore(query, entry.key, ''),
            ),
          )
          .toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Tag search failed',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Save a search query
  Future<saved_search.SavedSearch> saveSearch({
    required String query,
    required String name,
    String? description,
    SearchOptions? options,
  }) async {
    try {
      _logger.info('[UnifiedSearch] Saving search: $name');

      final savedSearch = saved_search.SavedSearch(
        id: _uuid.v4(),
        name: name,
        query: query,
        filters: null, // TODO: Convert SearchOptions to SearchFilters
        isPinned: false,
        createdAt: DateTime.now(),
        lastUsedAt: null,
        usageCount: 0,
        displayOrder: 0,
      );

      // TODO: Implement saved search repository
      _logger.info(
        '[UnifiedSearch] Saved search functionality pending repository implementation',
      );

      // Track analytics
      await _trackSavedSearch(name);

      return savedSearch;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to save search',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get saved searches
  Future<List<saved_search.SavedSearch>> getSavedSearches() async {
    try {
      // TODO: Implement saved search repository
      _logger.info(
        '[UnifiedSearch] Saved search functionality pending repository implementation',
      );
      return [];
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to get saved searches',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Execute a saved search
  Future<List<SearchResultItem>> executeSavedSearch(
    String savedSearchId,
  ) async {
    try {
      // TODO: Implement saved search repository
      _logger.info(
        '[UnifiedSearch] Saved search functionality pending repository implementation',
      );
      return [];
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to execute saved search',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Delete a saved search
  Future<bool> deleteSavedSearch(String savedSearchId) async {
    try {
      // TODO: Implement saved search repository
      _logger.info(
        '[UnifiedSearch] Saved search functionality pending repository implementation',
      );
      return true;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to delete saved search',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSuggestions(String partial) async {
    try {
      final suggestions = <String>[];

      // Add from history
      final historyMatches = _searchHistory
          .where(
            (item) =>
                item.query.toLowerCase().startsWith(partial.toLowerCase()),
          )
          .map((item) => item.query)
          .take(5);
      suggestions.addAll(historyMatches);

      // Add from tags (extract from notes)
      final notes = await _notesRepository.localNotes();
      final allTags = <String>{};
      for (final note in notes) {
        final tags = note.tags;
        allTags.addAll(tags);
      }
      final tagMatches = allTags
          .where((tag) => tag.toLowerCase().contains(partial.toLowerCase()))
          .map((tag) => '#$tag')
          .take(5);
      suggestions.addAll(tagMatches);

      // Remove duplicates and limit
      return suggestions.toSet().take(10).toList();
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to get suggestions',
        error: e,
        stackTrace: stack,
      );
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
      // TODO: Implement saved search repository
      _logger.info(
        '[UnifiedSearch] Saved search functionality pending repository implementation',
      );
      return [];
    } catch (e, stack) {
      _logger.error(
        '[UnifiedSearch] Failed to get popular searches',
        error: e,
        stackTrace: stack,
      );
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
  String _getTaskStatusText(dynamic status) {
    // Handle both domain.TaskStatus and database TaskStatus
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'open':
        return 'Open';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return statusStr;
    }
  }

  /// Add search to history
  void _addToHistory(String query, int resultCount, SearchOptions options) {
    _searchHistory.add(
      SearchHistoryItem(
        query: query,
        timestamp: DateTime.now(),
        resultCount: resultCount,
        options: options,
      ),
    );

    // Limit history size
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory.removeAt(0);
    }
  }

  /// Track search analytics
  Future<void> _trackSearch(String query, int resultCount) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event(
        'search_performed',
        properties: {
          'query_length': query.length,
          'result_count': resultCount,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.warning('[UnifiedSearch] Failed to track search');
    }
  }

  /// Track saved search analytics
  Future<void> _trackSavedSearch(String name) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event(
        'search_saved',
        properties: {
          'name': name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.warning('[UnifiedSearch] Failed to track saved search');
    }
  }
}

/// Provider for unified search service
final unifiedSearchServiceProvider = Provider<UnifiedSearchService>((ref) {
  final config = ref.watch(migrationConfigProvider);
  final notesRepo = ref.watch(notesCoreRepositoryProvider);
  final taskRepo = ref.watch(taskCoreRepositoryProvider);
  final folderRepo = ref.watch(folderCoreRepositoryProvider);
  final templateRepo = ref.watch(templateCoreRepositoryProvider);

  // Task repository can be null if user is not authenticated
  if (taskRepo == null) {
    throw StateError('UnifiedSearchService requires authenticated user');
  }

  // Import FTS provider from repository_providers
  final ftsService = ref.watch(ftsIndexingServiceProvider);

  final noteIndexer = ref.watch(noteIndexerProvider);

  final service = UnifiedSearchService(
    ref: ref,
    migrationConfig: config,
    notesRepository: notesRepo,
    taskRepository: taskRepo,
    folderRepository: folderRepo,
    templateRepository: templateRepo,
    noteIndexer: noteIndexer,
    ftsService: ftsService,
  );

  // Initialize FTS/service asynchronously without blocking provider creation.
  unawaited(service.initialize());

  // Ensure resources are released when provider is disposed.
  ref.onDispose(service.dispose);

  return service;
});
