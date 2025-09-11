import 'package:duru_notes/data/local/app_db.dart';

/// Search query result with parsed components
class SearchQuery {
  final List<String> keywords;
  final List<String> anyTags;
  final List<String> noneTags;
  final String? folderPath;
  final SortSpec sort;

  const SearchQuery({
    this.keywords = const [],
    this.anyTags = const [],
    this.noneTags = const [],
    this.folderPath,
    this.sort = const SortSpec(),
  });

  /// Convert to JSON for saved searches
  Map<String, dynamic> toJson() => {
    'keywords': keywords,
    'anyTags': anyTags,
    'noneTags': noneTags,
    'folderPath': folderPath,
    'sortBy': sort.sortBy.name,
    'ascending': sort.ascending,
    'pinnedFirst': sort.pinnedFirst,
  };

  /// Create from JSON (for saved searches)
  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery(
    keywords: List<String>.from((json['keywords'] as List<dynamic>?) ?? []),
    anyTags: List<String>.from((json['anyTags'] as List<dynamic>?) ?? []),
    noneTags: List<String>.from((json['noneTags'] as List<dynamic>?) ?? []),
    folderPath: json['folderPath'] as String?,
    sort: SortSpec(
      sortBy: SortBy.values.firstWhere(
        (e) => e.name == json['sortBy'],
        orElse: () => SortBy.updatedAt,
      ),
      ascending: (json['ascending'] as bool?) ?? false,
      pinnedFirst: (json['pinnedFirst'] as bool?) ?? true,
    ),
  );
}

/// Parser for search queries with tag support
class SearchParser {
  /// Parse search input into structured query
  SearchQuery parse(String input) {
    final tokens = input.split(' ').where((t) => t.isNotEmpty).toList();
    final anyTags = <String>[];
    final noneTags = <String>[];
    final keywords = <String>[];
    String? folderPath;
    
    for (final token in tokens) {
      if (token.startsWith('-#') && token.length > 2) {
        // Exclude tag
        noneTags.add(token.substring(2).toLowerCase());
      } else if (token.startsWith('#') && token.length > 1) {
        // Include tag
        anyTags.add(token.substring(1).toLowerCase());
      } else if (token.startsWith('folder:') && token.length > 7) {
        // Folder filter
        folderPath = token.substring(7);
      } else {
        // Regular keyword
        keywords.add(token);
      }
    }
    
    return SearchQuery(
      keywords: keywords,
      anyTags: anyTags,
      noneTags: noneTags,
      folderPath: folderPath,
    );
  }

  /// Build display string from query (for saved searches)
  String buildQueryString(SearchQuery query) {
    final parts = <String>[];
    
    // Add keywords
    parts.addAll(query.keywords);
    
    // Add include tags
    for (final tag in query.anyTags) {
      parts.add('#$tag');
    }
    
    // Add exclude tags
    for (final tag in query.noneTags) {
      parts.add('-#$tag');
    }
    
    // Add folder filter
    if (query.folderPath != null) {
      parts.add('folder:${query.folderPath}');
    }
    
    return parts.join(' ');
  }
}
