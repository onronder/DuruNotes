import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search infrastructure providers
///
/// This file contains providers for search-related infrastructure,
/// including full-text indexing and search query parsing.

/// Note indexer provider
///
/// Provides the NoteIndexer service for full-text search indexing.
/// The indexer builds and maintains search indices for note content,
/// enabling fast full-text search across all notes.
///
final noteIndexerProvider = Provider<NoteIndexer>((ref) {
  return NoteIndexer(ref);
});
