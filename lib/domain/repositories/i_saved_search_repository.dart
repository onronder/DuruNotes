import '../entities/saved_search.dart';

/// Domain interface for saved search operations
/// Follows repository pattern established in Phase 1
abstract class ISavedSearchRepository {
  /// Get all saved searches for current user
  Future<List<SavedSearch>> getAllSavedSearches();

  /// Get saved searches by type
  Future<List<SavedSearch>> getSavedSearchesByType(String searchType);

  /// Get saved search by ID
  Future<SavedSearch?> getSavedSearchById(String id);

  /// Create or update a saved search
  Future<SavedSearch> upsertSavedSearch(SavedSearch search);

  /// Delete a saved search
  Future<void> deleteSavedSearch(String id);

  /// Update usage statistics (last used, usage count)
  Future<void> updateUsageStatistics(String id);

  /// Toggle pin status
  Future<void> togglePin(String id);

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> orderedIds);

  /// Watch saved searches stream (real-time updates)
  Stream<List<SavedSearch>> watchSavedSearches();

  /// Search within saved searches by name
  Future<List<SavedSearch>> searchByName(String query);
}
