import 'package:drift/drift.dart' hide Column;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/search/search_parser.dart';
import 'package:duru_notes/search/search_unified.dart';

/// Service for executing searches with tag and folder support
class SearchService {
  SearchService({required this.db, required this.repo}) {
    _unifiedSearch = UnifiedSearchService(db: db);
  }
  final AppDb db;
  final NotesRepository repo;
  late final UnifiedSearchService _unifiedSearch;

  /// Execute a search query string
  Future<List<LocalNote>> search(
    String query, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final searchQuery = SearchParser.parse(query);
    return executeQuery(searchQuery, sort: sort, limit: limit);
  }

  /// Execute a parsed search query using unified SQL approach
  Future<List<LocalNote>> executeQuery(
    SearchQuery query, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    // Use unified search that combines FTS, folder, and tag filtering in one SQL pass
    return _unifiedSearch.search(query, sort: sort, limit: limit);
  }

  /// Save a search query
  Future<void> saveSearch({
    required String name,
    required SearchQuery query,
    String? id,
    String? color,
    String? icon,
  }) async {
    final searchId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final savedSearch = SavedSearch(
      id: searchId,
      name: name,
      query: SearchParser.build(query),
      searchType: 'compound',
      parameters: query.toJson().toString(),
      color: color,
      icon: icon,
      isPinned: false,
      createdAt: DateTime.now(),
      sortOrder: 0,
      usageCount: 0,
    );

    await db.upsertSavedSearch(savedSearch);
  }

  /// Execute a saved search
  Future<List<LocalNote>> executeSavedSearch(
    String savedSearchId, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final savedSearch = await db.getSavedSearchById(savedSearchId);
    if (savedSearch == null) return [];

    // Update usage stats
    await db.updateSavedSearchUsage(savedSearchId);

    // Parse and execute
    if (savedSearch.parameters != null) {
      try {
        final json = savedSearch.parameters!;
        final query = SearchQuery.fromJson(json as Map<String, dynamic>);
        return executeQuery(query, sort: sort, limit: limit);
      } catch (e) {
        // Fallback to parsing the query string
        return search(savedSearch.query, sort: sort, limit: limit);
      }
    } else {
      return search(savedSearch.query, sort: sort, limit: limit);
    }
  }
}

// Extension method for finding folder by path
extension FolderPathExtension on AppDb {
  Future<LocalFolder?> findFolderByPath(String path) async {
    return (select(localFolders)
          ..where((f) => (f.deleted.equals(false)) & (f.path.equals(path))))
        .getSingleOrNull();
  }
}
