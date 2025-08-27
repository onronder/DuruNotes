import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:duru_notes_app/data/local/app_db.dart';

/// Production-grade note indexer for search functionality
class NoteIndexer {
  final AppDb _db;
  final AppLogger _logger;
  
  // Configuration
  static const int _maxIndexedContentLength = 100000; // 100KB
  static const int _maxTagsPerNote = 50;
  static const Duration _operationTimeout = Duration(seconds: 30);

  NoteIndexer({
    required AppDb db,
    required AppLogger logger,
  }) : _db = db, _logger = logger;

  /// Index a note for search with comprehensive validation
  Future<void> indexNote({
    required String id,
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    try {
      // Validate inputs
      if (id.trim().isEmpty) {
        throw ArgumentError('Note ID cannot be empty');
      }
      
      if (title.trim().isEmpty) {
        throw ArgumentError('Note title cannot be empty');
      }

      // Sanitize and limit content
      final sanitizedContent = _sanitizeContent(content);
      final limitedContent = sanitizedContent.length > _maxIndexedContentLength
          ? sanitizedContent.substring(0, _maxIndexedContentLength)
          : sanitizedContent;

      // Sanitize and limit tags
      final sanitizedTags = _sanitizeTags(tags);

      // Create search index entry
      await _db.into(_db.searchIndex).insertOnConflictUpdate(
        SearchIndexCompanion.insert(
          noteId: id,
          title: title.trim(),
          content: limitedContent,
          tags: sanitizedTags.join(' '),
          lastIndexed: DateTime.now(),
        ),
      ).timeout(_operationTimeout);

      _logger.info('Note indexed successfully', data: {
        'noteId': id,
        'title': title,
        'contentLength': limitedContent.length,
        'tagCount': sanitizedTags.length,
      });

    } catch (e, stackTrace) {
      _logger.error('Failed to index note', 
        error: e, 
        stackTrace: stackTrace,
        data: {
          'noteId': id,
          'title': title,
          'contentLength': content.length,
          'tagCount': tags.length,
        },
      );
      rethrow;
    }
  }

  /// Remove note from search index
  Future<void> removeNote(String noteId) async {
    try {
      if (noteId.trim().isEmpty) {
        throw ArgumentError('Note ID cannot be empty');
      }

      await (_db.delete(_db.searchIndex)
        ..where((tbl) => tbl.noteId.equals(noteId))
      ).go().timeout(_operationTimeout);

      _logger.info('Note removed from index', data: {'noteId': noteId});

    } catch (e, stackTrace) {
      _logger.error('Failed to remove note from index', 
        error: e, 
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      rethrow;
    }
  }

  /// Search notes with advanced filtering
  Future<List<SearchResult>> searchNotes({
    required String query,
    List<String>? tags,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty && (tags == null || tags.isEmpty)) {
        return [];
      }

      // Validate parameters
      if (limit < 1 || limit > 1000) {
        throw ArgumentError('Limit must be between 1 and 1000');
      }
      
      if (offset < 0) {
        throw ArgumentError('Offset cannot be negative');
      }

      final sanitizedQuery = _sanitizeSearchQuery(query);
      final sanitizedTags = tags?.map(_sanitizeTag).where((tag) => tag.isNotEmpty).toList();

      // Build search query
      final searchQuery = _db.select(_db.searchIndex);
      
      if (sanitizedQuery.isNotEmpty) {
        searchQuery.where((tbl) => 
          tbl.title.contains(sanitizedQuery) |
          tbl.content.contains(sanitizedQuery) |
          tbl.tags.contains(sanitizedQuery)
        );
      }

      if (sanitizedTags != null && sanitizedTags.isNotEmpty) {
        for (final tag in sanitizedTags) {
          searchQuery.where((tbl) => tbl.tags.contains(tag));
        }
      }

      // Apply pagination and ordering
      searchQuery
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.lastIndexed)])
        ..limit(limit, offset: offset);

      final results = await searchQuery.get().timeout(_operationTimeout);

      final searchResults = results.map((row) => SearchResult(
        noteId: row.noteId,
        title: row.title,
        content: row.content,
        tags: row.tags.split(' ').where((tag) => tag.isNotEmpty).toList(),
        lastIndexed: row.lastIndexed,
        relevanceScore: _calculateRelevanceScore(row, sanitizedQuery, sanitizedTags),
      )).toList();

      // Sort by relevance score
      searchResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      _logger.info('Search completed', data: {
        'query': sanitizedQuery,
        'tags': sanitizedTags,
        'resultCount': searchResults.length,
        'limit': limit,
        'offset': offset,
      });

      return searchResults;

    } catch (e, stackTrace) {
      _logger.error('Search failed', 
        error: e, 
        stackTrace: stackTrace,
        data: {
          'query': query,
          'tags': tags,
          'limit': limit,
          'offset': offset,
        },
      );
      rethrow;
    }
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSearchSuggestions(String partialQuery, {int limit = 10}) async {
    try {
      if (partialQuery.trim().isEmpty) {
        return [];
      }

      final sanitizedQuery = _sanitizeSearchQuery(partialQuery);
      if (sanitizedQuery.length < 2) {
        return [];
      }

      // Get titles that start with the query
      final titleMatches = await (_db.selectOnly(_db.searchIndex)
        ..addColumns([_db.searchIndex.title])
        ..where(_db.searchIndex.title.like('$sanitizedQuery%'))
        ..limit(limit)
      ).get().timeout(_operationTimeout);

      final suggestions = titleMatches
          .map((row) => row.read(_db.searchIndex.title))
          .where((title) => title != null)
          .cast<String>()
          .toSet() // Remove duplicates
          .toList();

      _logger.info('Search suggestions generated', data: {
        'query': sanitizedQuery,
        'suggestionCount': suggestions.length,
      });

      return suggestions;

    } catch (e, stackTrace) {
      _logger.error('Failed to get search suggestions', 
        error: e, 
        stackTrace: stackTrace,
        data: {'query': partialQuery},
      );
      return [];
    }
  }

  /// Rebuild the entire search index
  Future<void> rebuildIndex() async {
    try {
      _logger.info('Starting search index rebuild');

      // Clear existing index
      await _db.delete(_db.searchIndex).go().timeout(_operationTimeout);

      // Get all notes
      final notes = await _db.select(_db.notes).get().timeout(_operationTimeout);

      for (final note in notes) {
        try {
          // Extract content from blocks
          final content = note.content; // Assuming content is stored as text
          
          // Extract tags (this would depend on your tag storage implementation)
          final tags = <String>[]; // Get tags from your tag storage
          
          await indexNote(
            id: note.id,
            title: note.title,
            content: content,
            tags: tags,
          );
        } catch (e) {
          _logger.warn('Failed to index note during rebuild', 
            error: e, 
            data: {'noteId': note.id},
          );
        }
      }

      _logger.info('Search index rebuild completed', data: {
        'totalNotes': notes.length,
      });

    } catch (e, stackTrace) {
      _logger.error('Failed to rebuild search index', 
        error: e, 
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get index statistics
  Future<IndexStats> getIndexStats() async {
    try {
      final totalNotes = await (_db.selectOnly(_db.searchIndex)
        ..addColumns([_db.searchIndex.noteId.count()])
      ).getSingle().timeout(_operationTimeout);

      final avgContentLength = await (_db.selectOnly(_db.searchIndex)
        ..addColumns([_db.searchIndex.content.length.avg()])
      ).getSingle().timeout(_operationTimeout);

      final oldestIndex = await (_db.selectOnly(_db.searchIndex)
        ..addColumns([_db.searchIndex.lastIndexed.min()])
      ).getSingle().timeout(_operationTimeout);

      final newestIndex = await (_db.selectOnly(_db.searchIndex)
        ..addColumns([_db.searchIndex.lastIndexed.max()])
      ).getSingle().timeout(_operationTimeout);

      return IndexStats(
        totalNotes: totalNotes.read(_db.searchIndex.noteId.count()) ?? 0,
        avgContentLength: avgContentLength.read(_db.searchIndex.content.length.avg())?.toInt() ?? 0,
        oldestIndexDate: oldestIndex.read(_db.searchIndex.lastIndexed.min()),
        newestIndexDate: newestIndex.read(_db.searchIndex.lastIndexed.max()),
      );

    } catch (e, stackTrace) {
      _logger.error('Failed to get index stats', error: e, stackTrace: stackTrace);
      return IndexStats(
        totalNotes: 0,
        avgContentLength: 0,
        oldestIndexDate: null,
        newestIndexDate: null,
      );
    }
  }

  // Private helper methods

  /// Sanitize content for indexing
  String _sanitizeContent(String content) {
    // Remove potential script tags and other dangerous content
    String sanitized = content
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();

    return sanitized;
  }

  /// Sanitize tags for indexing
  List<String> _sanitizeTags(List<String> tags) {
    final sanitized = tags
        .map(_sanitizeTag)
        .where((tag) => tag.isNotEmpty)
        .take(_maxTagsPerNote)
        .toSet()
        .toList();

    return sanitized;
  }

  /// Sanitize a single tag
  String _sanitizeTag(String tag) {
    return tag
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w-]'), '') // Only allow word characters and hyphens
        .replaceAll(RegExp(r'-+'), '-') // Normalize multiple hyphens
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens
  }

  /// Sanitize search query
  String _sanitizeSearchQuery(String query) {
    return query
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ') // Remove special characters except spaces and hyphens
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Calculate relevance score for search results
  double _calculateRelevanceScore(
    SearchIndexData row, 
    String query, 
    List<String>? tags,
  ) {
    double score = 0.0;

    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      final lowerTitle = row.title.toLowerCase();
      final lowerContent = row.content.toLowerCase();

      // Title matches are more important
      if (lowerTitle.contains(lowerQuery)) {
        score += 10.0;
        if (lowerTitle.startsWith(lowerQuery)) {
          score += 5.0; // Boost for prefix matches
        }
      }

      // Content matches
      if (lowerContent.contains(lowerQuery)) {
        score += 1.0;
      }

      // Tag matches
      if (row.tags.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }
    }

    // Tag-specific scoring
    if (tags != null && tags.isNotEmpty) {
      final rowTags = row.tags.split(' ').map((tag) => tag.toLowerCase()).toSet();
      final queryTags = tags.map((tag) => tag.toLowerCase()).toSet();
      
      final intersection = rowTags.intersection(queryTags);
      score += intersection.length * 5.0;
    }

    // Recency boost (newer notes get slight preference)
    final daysSinceIndexed = DateTime.now().difference(row.lastIndexed).inDays;
    score += (30 - daysSinceIndexed.clamp(0, 30)) * 0.1;

    return score;
  }
}

/// Search result data class
class SearchResult {
  final String noteId;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime lastIndexed;
  final double relevanceScore;

  const SearchResult({
    required this.noteId,
    required this.title,
    required this.content,
    required this.tags,
    required this.lastIndexed,
    required this.relevanceScore,
  });

  /// Get a preview of the content (first 200 characters)
  String get contentPreview {
    if (content.length <= 200) return content;
    return '${content.substring(0, 197)}...';
  }
}

/// Index statistics
class IndexStats {
  final int totalNotes;
  final int avgContentLength;
  final DateTime? oldestIndexDate;
  final DateTime? newestIndexDate;

  const IndexStats({
    required this.totalNotes,
    required this.avgContentLength,
    this.oldestIndexDate,
    this.newestIndexDate,
  });

  /// Check if index needs rebuilding (if oldest entry is very old)
  bool get needsRebuild {
    if (oldestIndexDate == null) return totalNotes > 0;
    
    final daysSinceOldest = DateTime.now().difference(oldestIndexDate!).inDays;
    return daysSinceOldest > 30; // Rebuild if oldest entry is more than 30 days old
  }
}
