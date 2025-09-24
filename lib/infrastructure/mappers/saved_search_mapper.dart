import 'dart:convert';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;

/// Maps between domain SavedSearch entity and infrastructure SavedSearch
class SavedSearchMapper {
  /// Convert infrastructure SavedSearch to domain SavedSearch
  static domain.SavedSearch toDomain(db.SavedSearch dbSearch) {
    return domain.SavedSearch(
      id: dbSearch.id,
      name: dbSearch.name,
      query: dbSearch.query,
      filters: dbSearch.filters != null
          ? domain.SearchFilters.fromJson(jsonDecode(dbSearch.filters!))
          : null,
      isPinned: dbSearch.isPinned,
      createdAt: dbSearch.createdAt,
      lastUsedAt: dbSearch.lastUsedAt,
      usageCount: dbSearch.usageCount,
      displayOrder: dbSearch.displayOrder,
    );
  }

  /// Convert domain SavedSearch to infrastructure SavedSearch
  static db.SavedSearch toInfrastructure(domain.SavedSearch search) {
    return db.SavedSearch(
      id: search.id,
      name: search.name,
      query: search.query,
      filters: search.filters != null
          ? jsonEncode(search.filters!.toJson())
          : null,
      isPinned: search.isPinned,
      createdAt: search.createdAt,
      lastUsedAt: search.lastUsedAt,
      usageCount: search.usageCount,
      displayOrder: search.displayOrder,
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