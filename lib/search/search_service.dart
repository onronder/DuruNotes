import 'package:drift/drift.dart' hide Column;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/search/search_parser.dart';

/// Service for executing searches with tag and folder support
class SearchService {
  final AppDb db;
  final NotesRepository repo;

  SearchService({
    required this.db,
    required this.repo,
  });

  /// Execute a search query string
  Future<List<LocalNote>> search(String query) async {
    final searchQuery = SearchParser.parse(query);
    return executeQuery(searchQuery);
  }

  /// Execute a parsed search query
  Future<List<LocalNote>> executeQuery(SearchQuery query) async {
    // Start with all notes or FTS search if keywords present
    List<LocalNote> results;
    
    if (query.keywords.isNotEmpty) {
      // Use FTS for keyword search
      results = await db.searchNotes(query.keywords);
    } else if (query.includeTags.isNotEmpty || query.excludeTags.isNotEmpty) {
      // Tag-only search
      results = await repo.queryNotesByTags(
        anyTags: query.includeTags,
        noneTags: query.excludeTags,
        sort: const SortSpec(),
      );
    } else {
      // No filters - return all notes
      results = await db.allNotes();
    }
    
    // Apply folder filter if specified
    if (query.folderName != null) {
      final folder = await db.findFolderByPath(query.folderName!);
      if (folder != null) {
        final notesInFolder = await db.getNotesInFolder(folder.id);
        final folderNoteIds = notesInFolder.map((n) => n.id).toSet();
        results = results.where((n) => folderNoteIds.contains(n.id)).toList();
      } else {
        // Folder not found - return empty
        return [];
      }
    }
    
    // Apply tag filters if we started with FTS
    if (query.keywords.isNotEmpty && (query.includeTags.isNotEmpty || query.excludeTags.isNotEmpty)) {
      // Post-filter by tags
      final noteIds = results.map((n) => n.id).toSet();
      final tagFiltered = await repo.queryNotesByTags(
        anyTags: query.includeTags,
        noneTags: query.excludeTags,
        sort: const SortSpec(),
      );
      final tagFilteredIds = tagFiltered.map((n) => n.id).toSet();
      
      // Intersection of FTS results and tag results
      results = results.where((n) => tagFilteredIds.contains(n.id)).toList();
    }
    
    // Apply sorting if not already sorted
    if (query.keywords.isEmpty && query.includeTags.isEmpty && query.excludeTags.isEmpty) {
      results = _sortNotes(results, const SortSpec());
    }
    
    return results;
  }

  /// Sort notes according to SortSpec
  List<LocalNote> _sortNotes(List<LocalNote> notes, SortSpec sort) {
    final sorted = List<LocalNote>.from(notes);
    
    sorted.sort((a, b) {
      // Pinned first if enabled
      if (sort.pinnedFirst) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
      }
      
      // Then by sort field
      int comparison;
      switch (sort.sortBy) {
        case SortBy.title:
          comparison = a.title.compareTo(b.title);
          break;
        case SortBy.createdAt:
        case SortBy.updatedAt:
        default:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      
      return sort.ascending ? comparison : -comparison;
    });
    
    return sorted;
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
  Future<List<LocalNote>> executeSavedSearch(String savedSearchId) async {
    final savedSearch = await db.getSavedSearchById(savedSearchId);
    if (savedSearch == null) return [];
    
    // Update usage stats
    await db.updateSavedSearchUsage(savedSearchId);
    
    // Parse and execute
    if (savedSearch.parameters != null) {
      try {
        final json = savedSearch.parameters!;
        final query = SearchQuery.fromJson(json as Map<String, dynamic>);
        return executeQuery(query);
      } catch (e) {
        // Fallback to parsing the query string
        return search(savedSearch.query);
      }
    } else {
      return search(savedSearch.query);
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
