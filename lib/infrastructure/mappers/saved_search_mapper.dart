import 'dart:convert';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps between domain SavedSearch entity and infrastructure SavedSearch
class SavedSearchMapper {
  // Cache userId to avoid repeated auth calls
  static String? _cachedUserId;
  static DateTime? _cacheTime;
  static const _cacheValidityMinutes = 5;

  /// Get current user ID with caching
  static String _getCurrentUserId() {
    // Return cached value if still valid
    if (_cachedUserId != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age.inMinutes < _cacheValidityMinutes) {
        return _cachedUserId!;
      }
    }

    // Cache expired or not set - refresh
    _cachedUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _cacheTime = DateTime.now();
    return _cachedUserId!;
  }

  /// Convert infrastructure SavedSearch to domain SavedSearch
  static domain.SavedSearch toDomain(db.SavedSearch dbSearch) {
    return domain.SavedSearch(
      id: dbSearch.id,
      name: dbSearch.name,
      query: dbSearch.query,
      filters: dbSearch.parameters != null
          ? domain.SearchFilters.fromJson(jsonDecode(dbSearch.parameters!) as Map<String, dynamic>)
          : null,
      isPinned: dbSearch.isPinned,
      createdAt: dbSearch.createdAt,
      lastUsedAt: dbSearch.lastUsedAt,
      usageCount: dbSearch.usageCount,
      displayOrder: dbSearch.sortOrder,
    );
  }

  /// Convert domain SavedSearch to infrastructure SavedSearch
  static db.SavedSearch toInfrastructure(domain.SavedSearch search) {
    final userId = _getCurrentUserId();

    return db.SavedSearch(
      id: search.id,
      userId: userId,
      name: search.name,
      query: search.query,
      searchType: 'text', // Default to text search
      parameters: search.filters != null
          ? jsonEncode(search.filters!.toJson())
          : null,
      isPinned: search.isPinned,
      createdAt: search.createdAt,
      lastUsedAt: search.lastUsedAt,
      usageCount: search.usageCount,
      sortOrder: search.displayOrder,
    );
  }

  /// Convert SavedSearch list to domain SavedSearch list
  static List<domain.SavedSearch> toDomainList(List<db.SavedSearch> dbSearches) {
    return dbSearches.map((search) => toDomain(search)).toList();
  }

  /// Convert domain SavedSearch list to infrastructure SavedSearch list
  static List<db.SavedSearch> toInfrastructureList(List<domain.SavedSearch> searches) {
    return searches.map((search) => toInfrastructure(search)).toList();
  }
}