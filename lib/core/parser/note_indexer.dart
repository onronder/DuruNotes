import 'dart:async';

import '../../data/local/app_db.dart';
import '../monitoring/app_logger.dart';

/// Manages indexing and cross-referencing of notes for search and linking
class NoteIndexer {
  final AppLogger _logger;
  final Map<String, Set<String>> _tagIndex = {};
  final Map<String, Set<String>> _linkIndex = {};
  final Map<String, Set<String>> _wordIndex = {};

  NoteIndexer({
    AppLogger? logger,
  }) : _logger = logger ?? LoggerFactory.instance;

  /// Index a note for search and cross-referencing
  Future<void> indexNote(LocalNote note) async {
    try {
      _logger.debug('Indexing note', data: {
        'note_id': note.id,
        'title': note.title,
      });

      // Clear existing index entries for this note
      await removeNoteFromIndex(note.id);

      // Index tags
      await _indexTags(note);

      // Index links
      await _indexLinks(note);

      // Index words for search
      await _indexWords(note);

      _logger.debug('Note indexed successfully', data: {
        'note_id': note.id,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to index note', error: e, stackTrace: stackTrace, data: {
        'note_id': note.id,
      });
    }
  }

  /// Remove a note from all indexes
  Future<void> removeNoteFromIndex(String noteId) async {
    try {
      // Remove from tag index
      _tagIndex.values.forEach((noteIds) => noteIds.remove(noteId));
      _tagIndex.removeWhere((tag, noteIds) => noteIds.isEmpty);

      // Remove from link index
      _linkIndex.values.forEach((noteIds) => noteIds.remove(noteId));
      _linkIndex.removeWhere((link, noteIds) => noteIds.isEmpty);

      // Remove from word index
      _wordIndex.values.forEach((noteIds) => noteIds.remove(noteId));
      _wordIndex.removeWhere((word, noteIds) => noteIds.isEmpty);

      _logger.debug('Note removed from index', data: {
        'note_id': noteId,
      });
    } catch (e) {
      _logger.error('Failed to remove note from index', error: e, data: {
        'note_id': noteId,
      });
    }
  }

  /// Find notes that contain specific tags
  Set<String> findNotesByTag(String tag) {
    return _tagIndex[tag.toLowerCase()] ?? {};
  }

  /// Find notes that link to a specific note
  Set<String> findNotesLinkingTo(String noteId) {
    return _linkIndex[noteId] ?? {};
  }

  /// Search notes by text content
  Set<String> searchNotes(String query) {
    if (query.trim().isEmpty) return {};

    final searchTerms = query.toLowerCase().split(RegExp(r'\s+'));
    Set<String>? results;

    for (final term in searchTerms) {
      final termResults = <String>{};

      // Find exact word matches
      for (final entry in _wordIndex.entries) {
        if (entry.key.contains(term)) {
          termResults.addAll(entry.value);
        }
      }

      // Intersect with previous results (AND operation)
      if (results == null) {
        results = termResults;
      } else {
        results = results.intersection(termResults);
      }

      // If no results, stop early
      if (results.isEmpty) break;
    }

    return results ?? {};
  }

  /// Get all tags in the index
  Set<String> getAllTags() {
    return _tagIndex.keys.toSet();
  }

  /// Get all indexed words
  Set<String> getAllWords() {
    return _wordIndex.keys.toSet();
  }

  /// Get statistics about the index
  Map<String, int> getIndexStats() {
    return {
      'total_tags': _tagIndex.length,
      'total_links': _linkIndex.length,
      'total_words': _wordIndex.length,
      'notes_with_tags': _tagIndex.values.expand((s) => s).toSet().length,
      'notes_with_links': _linkIndex.values.expand((s) => s).toSet().length,
      'indexed_notes': _wordIndex.values.expand((s) => s).toSet().length,
    };
  }

  /// Clear all indexes
  Future<void> clearIndex() async {
    _tagIndex.clear();
    _linkIndex.clear();
    _wordIndex.clear();
    
    _logger.info('All indexes cleared');
  }

  /// Rebuild index for all notes
  Future<void> rebuildIndex(List<LocalNote> allNotes) async {
    try {
      _logger.info('Rebuilding note index', data: {
        'total_notes': allNotes.length,
      });

      await clearIndex();

      for (final note in allNotes) {
        await indexNote(note);
      }

      _logger.info('Note index rebuilt successfully', data: getIndexStats());
    } catch (e) {
      _logger.error('Failed to rebuild index', error: e);
    }
  }

  // Private helper methods

  Future<void> _indexTags(LocalNote note) async {
    final tags = _extractTags(note.body);
    
    for (final tag in tags) {
      final normalizedTag = tag.toLowerCase();
      _tagIndex.putIfAbsent(normalizedTag, () => <String>{}).add(note.id);
    }
  }

  Future<void> _indexLinks(LocalNote note) async {
    final links = _extractNoteLinks(note.body);
    
    for (final linkedNoteId in links) {
      _linkIndex.putIfAbsent(linkedNoteId, () => <String>{}).add(note.id);
    }
  }

  Future<void> _indexWords(LocalNote note) async {
    final words = _extractWords('${note.title} ${note.body}');
    
    for (final word in words) {
      final normalizedWord = word.toLowerCase();
      if (normalizedWord.length >= 3) { // Index words with 3+ characters
        _wordIndex.putIfAbsent(normalizedWord, () => <String>{}).add(note.id);
      }
    }
  }

  Set<String> _extractTags(String content) {
    final tags = <String>{};
    
    // Extract hashtags (#tag)
    final hashtagRegex = RegExp(r'#(\w+)', multiLine: true);
    final hashtagMatches = hashtagRegex.allMatches(content);
    for (final match in hashtagMatches) {
      if (match.group(1) != null) {
        tags.add(match.group(1)!);
      }
    }
    
    // Extract mention-style tags (@tag)
    final mentionRegex = RegExp(r'@(\w+)', multiLine: true);
    final mentionMatches = mentionRegex.allMatches(content);
    for (final match in mentionMatches) {
      if (match.group(1) != null) {
        tags.add(match.group(1)!);
      }
    }
    
    return tags;
  }

  Set<String> _extractNoteLinks(String content) {
    final links = <String>{};
    
    // Extract note links in format [[note-id]] or [[note-title]]
    final linkRegex = RegExp(r'\[\[([^\]]+)\]\]', multiLine: true);
    final linkMatches = linkRegex.allMatches(content);
    for (final match in linkMatches) {
      if (match.group(1) != null) {
        links.add(match.group(1)!);
      }
    }
    
    return links;
  }

  Set<String> _extractWords(String content) {
    final words = <String>{};
    
    // Remove markdown formatting and special characters
    final cleanContent = content
        .replaceAll(RegExp(r'[#*`>]'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ');
    
    // Split into words
    final wordRegex = RegExp(r'\b\w+\b', multiLine: true);
    final wordMatches = wordRegex.allMatches(cleanContent);
    for (final match in wordMatches) {
      if (match.group(0) != null) {
        final word = match.group(0)!;
        if (word.length >= 2 && !_isStopWord(word)) {
          words.add(word);
        }
      }
    }
    
    return words;
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
      'before', 'after', 'above', 'below', 'between', 'among', 'under', 'over',
      'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
      'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might',
      'must', 'can', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she',
      'it', 'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his',
      'its', 'our', 'their', 'mine', 'yours', 'hers', 'ours', 'theirs',
    };
    
    return stopWords.contains(word.toLowerCase());
  }
}

/// Extension methods for LocalNote to support indexing
extension LocalNoteIndexing on LocalNote {
  /// Extract all tags from the note
  Set<String> get tags {
    final indexer = NoteIndexer();
    return indexer._extractTags(body);
  }

  /// Extract all note links from the note
  Set<String> get noteLinks {
    final indexer = NoteIndexer();
    return indexer._extractNoteLinks(body);
  }

  /// Extract all searchable words from the note
  Set<String> get words {
    final indexer = NoteIndexer();
    return indexer._extractWords('$title $body');
  }

  /// Check if the note contains a specific tag
  bool hasTag(String tag) {
    return tags.contains(tag.toLowerCase());
  }

  /// Check if the note links to another note
  bool linksTo(String noteId) {
    return noteLinks.contains(noteId);
  }
}