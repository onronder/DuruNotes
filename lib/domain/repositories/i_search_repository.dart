import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/saved_search.dart';

/// Domain interface for search operations
abstract class ISearchRepository {
  /// Create or update a saved search
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch);

  /// Delete a saved search
  Future<void> deleteSavedSearch(String id);

  /// Get all saved searches
  Future<List<SavedSearch>> getSavedSearches();

  /// Watch saved searches stream
  Stream<List<SavedSearch>> watchSavedSearches();

  /// Toggle saved search pin status
  Future<void> toggleSavedSearchPin(String id);

  /// Track saved search usage
  Future<void> trackSavedSearchUsage(String id);

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> ids);

  /// Execute a saved search
  Future<List<Note>> executeSavedSearch(SavedSearch savedSearch);
}