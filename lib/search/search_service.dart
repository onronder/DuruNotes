import 'package:drift/drift.dart' hide Column;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/search/search_parser.dart';
import 'package:duru_notes/search/search_unified.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Legacy type alias for backward compatibility
typedef NotesRepository = NotesCoreRepository;

/// Service for executing searches with tag and folder support
class SearchService {
  SearchService({
    required this.db,
    required this.repo,
    required CryptoBox crypto,
  }) : _unifiedSearch = UnifiedSearchService(db: db, crypto: crypto);

  final AppDb db;
  final NotesRepository repo;
  final UnifiedSearchService _unifiedSearch;

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
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user search results
  Future<List<LocalNote>> executeQuery(
    SearchQuery query, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    // P0.5 SECURITY FIX: Get current userId to filter search results
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // No authenticated user - return empty results
      return const <LocalNote>[];
    }

    // Use unified search that combines FTS, folder, and tag filtering in one SQL pass
    return _unifiedSearch.search(query, userId: userId, sort: sort, limit: limit);
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
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    final savedSearch = SavedSearch(
      id: searchId,
      userId: userId,
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
