// ==========================================================================
// PRODUCTION-GRADE FULL-TEXT SEARCH INDEXING SERVICE
// ==========================================================================
//
// Application-side FTS implementation for encrypted notes.
// Uses in-memory inverted index with persistence to disk.
//
// Features:
// - Case-insensitive search
// - Boolean operators (AND, OR, NOT)
// - Phrase search with quotes
// - Wildcard search with *
// - TF-IDF ranking
// - Incremental updates
// - Thread-safe operations
// - Persistent index (optional)
//
// Performance: O(1) term lookup, O(n) ranking where n = matching docs
// ==========================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Full-Text Search Indexing Service
///
/// Manages an in-memory inverted index for fast text search.
/// Designed for encrypted content where SQL FTS5 cannot be used.
class FTSIndexingService {
  FTSIndexingService({
    required AppLogger logger,
    this.persistToDisk = true,
    this.autoSaveInterval = const Duration(minutes: 5),
  }) : _logger = logger;

  final AppLogger _logger;
  final bool persistToDisk;
  final Duration autoSaveInterval;

  // Inverted index: term -> Set of document IDs
  final Map<String, Set<String>> _index = {};

  // Document store: noteId -> IndexedDocument
  final Map<String, IndexedDocument> _documents = {};

  // Term frequency: noteId -> term -> frequency
  final Map<String, Map<String, int>> _termFrequencies = {};

  // Document frequency: term -> count of documents containing term
  final Map<String, int> _documentFrequencies = {};

  // Total documents indexed
  int get documentCount => _documents.length;

  // Auto-save timer
  Timer? _autoSaveTimer;

  // Stop words (common words to ignore for better relevance)
  static const _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'he',
    'in',
    'is',
    'it',
    'its',
    'of',
    'on',
    'that',
    'the',
    'to',
    'was',
    'will',
    'with',
    'you',
    'your',
    'this',
    'they',
    'but',
    'have',
    'had',
    'what',
    'when',
    'where',
    'who',
    'which',
    'why',
    'how',
  };

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _logger.info('[FTS] Initializing FTS Indexing Service');

      if (persistToDisk) {
        await _loadIndexFromDisk();
        _startAutoSave();
      }

      _logger.info(
        '[FTS] Initialization complete. Indexed $documentCount documents',
      );
    } catch (e, stack) {
      _logger.error('[FTS] Failed to initialize', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    _autoSaveTimer?.cancel();
    if (persistToDisk) {
      await _saveIndexToDisk();
    }
  }

  /// Index a note for full-text search
  ///
  /// [noteId] - Unique identifier for the note
  /// [title] - Note title (plaintext, decrypted)
  /// [body] - Note body (plaintext, decrypted)
  /// [tags] - Optional tags for the note
  Future<void> indexNote({
    required String noteId,
    required String title,
    required String body,
    List<String> tags = const [],
  }) async {
    try {
      // Remove old index if exists
      await removeNote(noteId);

      // Combine all searchable text
      final searchableText = [
        title,
        body,
        ...tags,
      ].where((s) => s.isNotEmpty).join(' ');

      if (searchableText.trim().isEmpty) {
        _logger.debug('[FTS] Skipping empty note: $noteId');
        return;
      }

      // Tokenize the text
      final tokens = _tokenize(searchableText);

      // Calculate term frequencies for this document
      final termFreqs = <String, int>{};
      for (final token in tokens) {
        termFreqs[token] = (termFreqs[token] ?? 0) + 1;
      }

      // Update inverted index
      for (final term in termFreqs.keys) {
        _index.putIfAbsent(term, () => <String>{}).add(noteId);
        _documentFrequencies[term] = (_documentFrequencies[term] ?? 0) + 1;
      }

      // Store document metadata
      _documents[noteId] = IndexedDocument(
        id: noteId,
        title: title,
        body: body,
        tags: tags,
        tokenCount: tokens.length,
        indexedAt: DateTime.now(),
      );

      // Store term frequencies
      _termFrequencies[noteId] = termFreqs;

      _logger.debug('[FTS] Indexed note $noteId with ${tokens.length} tokens');
    } catch (e, stack) {
      _logger.error(
        '[FTS] Failed to index note $noteId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Remove a note from the index
  Future<void> removeNote(String noteId) async {
    try {
      // Remove from term frequencies
      final termFreqs = _termFrequencies.remove(noteId);

      if (termFreqs != null) {
        // Update inverted index and document frequencies
        for (final term in termFreqs.keys) {
          _index[term]?.remove(noteId);
          if (_index[term]?.isEmpty ?? false) {
            _index.remove(term);
          }

          final docFreq = _documentFrequencies[term];
          if (docFreq != null) {
            if (docFreq <= 1) {
              _documentFrequencies.remove(term);
            } else {
              _documentFrequencies[term] = docFreq - 1;
            }
          }
        }
      }

      // Remove document metadata
      _documents.remove(noteId);

      _logger.debug('[FTS] Removed note $noteId from index');
    } catch (e, stack) {
      _logger.error(
        '[FTS] Failed to remove note $noteId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Search the index for notes matching the query
  ///
  /// Query syntax:
  /// - Simple: "apple" - matches documents containing "apple"
  /// - AND: "apple AND banana" - both terms must be present
  /// - OR: "apple OR banana" - either term must be present
  /// - NOT: "apple NOT banana" - apple but not banana
  /// - Phrase: '"apple pie"' - exact phrase match
  /// - Wildcard: "appl*" - matches apple, application, etc.
  ///
  /// Returns list of note IDs ranked by relevance (TF-IDF)
  Future<List<SearchResult>> search(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      _logger.debug('[FTS] Searching for: $query');

      // Parse and execute query
      final matchingDocs = _executeQuery(query);

      if (matchingDocs.isEmpty) {
        return [];
      }

      // Rank results using TF-IDF
      final rankedResults = _rankResults(query, matchingDocs);

      _logger.debug('[FTS] Found ${rankedResults.length} results for: $query');
      return rankedResults;
    } catch (e, stack) {
      _logger.error(
        '[FTS] Search failed for query: $query',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Clear the entire index
  Future<void> clearIndex() async {
    _index.clear();
    _documents.clear();
    _termFrequencies.clear();
    _documentFrequencies.clear();
    _logger.info('[FTS] Index cleared');

    if (persistToDisk) {
      await _saveIndexToDisk();
    }
  }

  /// Get index statistics
  Map<String, dynamic> getStats() {
    return {
      'documentCount': documentCount,
      'termCount': _index.length,
      'averageTermsPerDocument': documentCount > 0
          ? _termFrequencies.values
                    .map((tf) => tf.length)
                    .reduce((a, b) => a + b) /
                documentCount
          : 0,
      'indexSizeBytes': _estimateMemoryUsage(),
    };
  }

  // ========================================================================
  // PRIVATE METHODS
  // ========================================================================

  /// Tokenize text into search terms
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 2) // Minimum length
        .where((token) => !_stopWords.contains(token)) // Remove stop words
        .toList();
  }

  /// Execute a search query
  Set<String> _executeQuery(String query) {
    // Handle phrase search with quotes
    if (query.contains('"')) {
      return _executePhraseSearch(query);
    }

    // Handle boolean operators
    if (query.contains(' AND ')) {
      return _executeAndQuery(query);
    } else if (query.contains(' OR ')) {
      return _executeOrQuery(query);
    } else if (query.contains(' NOT ')) {
      return _executeNotQuery(query);
    }

    // Simple term search
    final tokens = _tokenize(query);
    final results = <String>{};

    for (final token in tokens) {
      if (token.contains('*')) {
        // Wildcard search
        final matches = _executeWildcardSearch(token);
        results.addAll(matches);
      } else {
        // Exact term search
        final docs = _index[token];
        if (docs != null) {
          results.addAll(docs);
        }
      }
    }

    return results;
  }

  /// Execute phrase search (exact match)
  Set<String> _executePhraseSearch(String query) {
    // Extract phrase from quotes
    final phraseMatch = RegExp(r'"([^"]*)"').firstMatch(query);
    if (phraseMatch == null) {
      return _executeQuery(query.replaceAll('"', ''));
    }

    final phrase = phraseMatch.group(1) ?? '';
    final phraseTokens = _tokenize(phrase);

    if (phraseTokens.isEmpty) {
      return {};
    }

    // Find documents containing all phrase tokens
    final firstToken = phraseTokens.first;
    var candidates = _index[firstToken]?.toSet() ?? <String>{};

    for (final token in phraseTokens.skip(1)) {
      final docs = _index[token];
      if (docs == null) {
        return {};
      }
      candidates = candidates.intersection(docs);
    }

    // Verify phrase order in original text
    final results = <String>{};
    for (final docId in candidates) {
      final doc = _documents[docId];
      if (doc != null) {
        final fullText = '${doc.title} ${doc.body}'.toLowerCase();
        if (fullText.contains(phrase.toLowerCase())) {
          results.add(docId);
        }
      }
    }

    return results;
  }

  /// Execute AND query
  Set<String> _executeAndQuery(String query) {
    final parts = query.split(' AND ').map((s) => s.trim()).toList();
    if (parts.length < 2) {
      return _executeQuery(query);
    }

    var results = _executeQuery(parts[0]);
    for (var i = 1; i < parts.length; i++) {
      final partResults = _executeQuery(parts[i]);
      results = results.intersection(partResults);
    }

    return results;
  }

  /// Execute OR query
  Set<String> _executeOrQuery(String query) {
    final parts = query.split(' OR ').map((s) => s.trim()).toList();
    final results = <String>{};

    for (final part in parts) {
      results.addAll(_executeQuery(part));
    }

    return results;
  }

  /// Execute NOT query
  Set<String> _executeNotQuery(String query) {
    final parts = query.split(' NOT ').map((s) => s.trim()).toList();
    if (parts.length != 2) {
      return _executeQuery(query);
    }

    final include = _executeQuery(parts[0]);
    final exclude = _executeQuery(parts[1]);

    return include.difference(exclude);
  }

  /// Execute wildcard search
  Set<String> _executeWildcardSearch(String pattern) {
    final regex = RegExp('^${pattern.replaceAll('*', '.*')}\$');
    final results = <String>{};

    for (final term in _index.keys) {
      if (regex.hasMatch(term)) {
        final docs = _index[term];
        if (docs != null) {
          results.addAll(docs);
        }
      }
    }

    return results;
  }

  /// Rank search results using TF-IDF
  List<SearchResult> _rankResults(String query, Set<String> matchingDocs) {
    final queryTerms = _tokenize(query);
    final scores = <String, double>{};

    for (final docId in matchingDocs) {
      final termFreqs = _termFrequencies[docId];
      if (termFreqs == null) continue;

      double score = 0.0;

      for (final term in queryTerms) {
        final tf = termFreqs[term] ?? 0;
        if (tf == 0) continue;

        // Term frequency
        final normalizedTF = tf / termFreqs.values.reduce((a, b) => a + b);

        // Inverse document frequency
        final docFreq = _documentFrequencies[term] ?? 1;
        final idf = documentCount > 0
            ? (1.0 + (documentCount / docFreq)).clamp(1.0, 10.0)
            : 1.0;

        // TF-IDF score
        score += normalizedTF * idf;
      }

      scores[docId] = score;
    }

    // Sort by score descending
    final sortedDocs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedDocs.map((entry) {
      final doc = _documents[entry.key]!;
      return SearchResult(
        noteId: entry.key,
        title: doc.title,
        snippet: _generateSnippet(doc.body, queryTerms),
        score: entry.value,
        highlightedTerms: queryTerms,
      );
    }).toList();
  }

  /// Generate a snippet from the document body
  String _generateSnippet(String body, List<String> queryTerms) {
    const maxLength = 150;

    if (body.length <= maxLength) {
      return body;
    }

    // Find the first occurrence of any query term
    final lowerBody = body.toLowerCase();
    int? firstMatch;

    for (final term in queryTerms) {
      final index = lowerBody.indexOf(term.toLowerCase());
      if (index >= 0 && (firstMatch == null || index < firstMatch)) {
        firstMatch = index;
      }
    }

    if (firstMatch == null) {
      return '${body.substring(0, maxLength)}...';
    }

    // Center snippet around match
    final start = (firstMatch - maxLength ~/ 2).clamp(
      0,
      body.length - maxLength,
    );
    final end = (start + maxLength).clamp(0, body.length);

    var snippet = body.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < body.length) snippet = '$snippet...';

    return snippet;
  }

  /// Estimate memory usage of the index
  int _estimateMemoryUsage() {
    int size = 0;

    // Inverted index
    for (final entry in _index.entries) {
      size +=
          entry.key.length + entry.value.length * 36; // String + Set overhead
    }

    // Documents
    for (final doc in _documents.values) {
      size += doc.title.length + doc.body.length + doc.tags.join().length;
    }

    return size;
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) {
      _saveIndexToDisk();
    });
  }

  /// Save index to disk for persistence
  Future<void> _saveIndexToDisk() async {
    try {
      final dir = await resolveAppDocumentsDirectory();
      final file = File('${dir.path}/fts_index.json');

      final data = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'documentCount': documentCount,
        'documents': _documents.map((id, doc) => MapEntry(id, doc.toJson())),
        'index': _index.map((term, docs) => MapEntry(term, docs.toList())),
        'documentFrequencies': _documentFrequencies,
        'termFrequencies': _termFrequencies,
      };

      await file.writeAsString(jsonEncode(data));
      _logger.debug('[FTS] Index saved to disk');
    } catch (e, stack) {
      _logger.error(
        '[FTS] Failed to save index to disk',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Load index from disk
  Future<void> _loadIndexFromDisk() async {
    try {
      final dir = await resolveAppDocumentsDirectory();
      final file = File('${dir.path}/fts_index.json');

      if (!await file.exists()) {
        _logger.info('[FTS] No persisted index found, starting fresh');
        return;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Restore documents
      final docs = data['documents'] as Map<String, dynamic>?;
      if (docs != null) {
        for (final entry in docs.entries) {
          _documents[entry.key] = IndexedDocument.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      // Restore inverted index
      final index = data['index'] as Map<String, dynamic>?;
      if (index != null) {
        for (final entry in index.entries) {
          _index[entry.key] = Set<String>.from(entry.value as List);
        }
      }

      // Restore document frequencies
      final docFreqs = data['documentFrequencies'] as Map<String, dynamic>?;
      if (docFreqs != null) {
        _documentFrequencies.addAll(docFreqs.cast<String, int>());
      }

      // Restore term frequencies
      final termFreqs = data['termFrequencies'] as Map<String, dynamic>?;
      if (termFreqs != null) {
        for (final entry in termFreqs.entries) {
          _termFrequencies[entry.key] = Map<String, int>.from(
            entry.value as Map,
          );
        }
      }

      _logger.info('[FTS] Loaded index from disk: $documentCount documents');
    } catch (e, stack) {
      _logger.error(
        '[FTS] Failed to load index from disk',
        error: e,
        stackTrace: stack,
      );
      // Continue with empty index on error
    }
  }
}

// ========================================================================
// DATA MODELS
// ========================================================================

/// Indexed document metadata
class IndexedDocument {
  const IndexedDocument({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.tokenCount,
    required this.indexedAt,
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final int tokenCount;
  final DateTime indexedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'tags': tags,
    'tokenCount': tokenCount,
    'indexedAt': indexedAt.toIso8601String(),
  };

  factory IndexedDocument.fromJson(Map<String, dynamic> json) {
    return IndexedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      tokenCount: json['tokenCount'] as int,
      indexedAt: DateTime.parse(json['indexedAt'] as String),
    );
  }
}

/// Search result with ranking
class SearchResult {
  const SearchResult({
    required this.noteId,
    required this.title,
    required this.snippet,
    required this.score,
    required this.highlightedTerms,
  });

  final String noteId;
  final String title;
  final String snippet;
  final double score;
  final List<String> highlightedTerms;

  @override
  String toString() => 'SearchResult(noteId: $noteId, score: $score)';
}
