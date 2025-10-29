import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Domain-aware note indexer that works with decrypted [domain.Note] objects.
///
/// This replaces the legacy indexer that operated on Drift `LocalNote`s.  By
/// indexing notes after they have been decrypted by the repository we restore
/// tag extraction, backlinks, and keyword search while remaining compatible
/// with the encrypted database schema.
class NoteIndexer {
  NoteIndexer(this._ref);

  final Ref _ref;
  AppLogger get _logger => _ref.read(loggerProvider);

  // In-memory index structures
  final Map<String, Set<String>> _tagIndex = {};
  final Map<String, Set<String>> _linkIndex = {};
  final Map<String, Set<String>> _wordIndex = {};

  static const int _minWordLength = 2;
  static const int _maxWordLength = 50;

  /// Index a decrypted domain note.
  Future<void> indexNote(domain.Note note) async {
    try {
      _logger.debug('[NoteIndexer] Indexing note: ${note.id}');

      // Clear existing entries for this note so we get a clean rebuild.
      await removeNoteFromIndex(note.id);

      _indexTags(note);
      _indexLinks(note);
      _indexWords(note);

      _logger.debug('[NoteIndexer] Successfully indexed note: ${note.id}');
    } catch (e, stackTrace) {
      _logger.error(
        '[NoteIndexer] Failed to index note',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': note.id},
      );
    }
  }

  /// Remove a note from all indexes.
  Future<void> removeNoteFromIndex(String noteId) async {
    try {
      for (final noteIds in _tagIndex.values) {
        noteIds.remove(noteId);
      }
      _tagIndex.removeWhere((tag, ids) => ids.isEmpty);

      for (final noteIds in _linkIndex.values) {
        noteIds.remove(noteId);
      }
      _linkIndex.removeWhere((link, ids) => ids.isEmpty);

      for (final noteIds in _wordIndex.values) {
        noteIds.remove(noteId);
      }
      _wordIndex.removeWhere((word, ids) => ids.isEmpty);

      _logger.debug('[NoteIndexer] Removed note from index: $noteId');
    } catch (e) {
      _logger.error(
        '[NoteIndexer] Failed to remove note from index',
        error: e,
        data: {'noteId': noteId},
      );
    }
  }

  /// Find notes that contain a specific tag.
  Set<String> findNotesByTag(String tag) {
    return _tagIndex[tag.toLowerCase()] ?? {};
  }

  /// Find notes that link to a specific note.
  Set<String> findNotesLinkingTo(String noteId) {
    return _linkIndex[noteId] ?? {};
  }

  /// Search notes by free text (AND across search terms).
  Set<String> searchNotes(String query) {
    if (query.trim().isEmpty) return {};

    final searchTerms = query.toLowerCase().split(RegExp(r'\s+'));
    Set<String>? results;

    for (final term in searchTerms) {
      final termResults = <String>{};

      for (final entry in _wordIndex.entries) {
        if (entry.key.contains(term)) {
          termResults.addAll(entry.value);
        }
      }

      if (results == null) {
        results = termResults;
      } else {
        results = results.intersection(termResults);
      }

      if (results.isEmpty) break;
    }

    return results ?? {};
  }

  /// Retrieve index statistics (useful for debugging).
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

  /// Clear all indexes.
  Future<void> clearIndex() async {
    _tagIndex.clear();
    _linkIndex.clear();
    _wordIndex.clear();
    _logger.info('[NoteIndexer] All indexes cleared');
  }

  /// Rebuild the index for an entire note collection.
  Future<void> rebuildIndex(List<domain.Note> allNotes) async {
    try {
      _logger.info(
        '[NoteIndexer] Rebuilding note index',
        data: {'total_notes': allNotes.length},
      );

      await clearIndex();

      for (final note in allNotes) {
        await indexNote(note);
      }

      _logger.info(
        '[NoteIndexer] Note index rebuilt successfully',
        data: getIndexStats(),
      );
    } catch (e, stackTrace) {
      _logger.error(
        '[NoteIndexer] Failed to rebuild index',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _indexTags(domain.Note note) {
    for (final tag in note.tags) {
      final normalizedTag = tag.toLowerCase().trim();
      if (normalizedTag.isNotEmpty) {
        _tagIndex.putIfAbsent(normalizedTag, () => {}).add(note.id);
      }
    }
  }

  void _indexLinks(domain.Note note) {
    for (final link in _extractNoteLinks(note.body)) {
      _linkIndex.putIfAbsent(link, () => {}).add(note.id);
    }
  }

  void _indexWords(domain.Note note) {
    final combinedText = '${note.title} ${note.body}';
    final normalized = combinedText.toLowerCase();
    final words = normalized.split(RegExp(r'\W+'));

    for (final word in words) {
      if (word.isEmpty) continue;
      final trimmed = word.trim();
      if (trimmed.length < _minWordLength || trimmed.length > _maxWordLength) {
        continue;
      }
      _wordIndex.putIfAbsent(trimmed, () => {}).add(note.id);
    }
  }

  Set<String> _extractNoteLinks(String text) {
    final linkPattern = RegExp(r'\[\[([a-zA-Z0-9\-]+)(?:\|[^\]]+)?\]\]');
    return linkPattern.allMatches(text).map((m) => m.group(1)!).toSet();
  }
}
