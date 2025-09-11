import 'package:flutter/foundation.dart';

/// Result of parsing a search query
@immutable
class SearchQuery {
  final String keywords;
  final List<String> includeTags;
  final List<String> excludeTags;
  final String? folderName;
  final bool hasAttachment;
  final String? attachmentType;
  final String? attachmentFilename;
  final bool fromEmail;
  final bool fromWeb;
  final bool isPinned;
  final Map<String, dynamic> rawFilters;

  const SearchQuery({
    this.keywords = '',
    this.includeTags = const [],
    this.excludeTags = const [],
    this.folderName,
    this.hasAttachment = false,
    this.attachmentType,
    this.attachmentFilename,
    this.fromEmail = false,
    this.fromWeb = false,
    this.isPinned = false,
    this.rawFilters = const {},
  });

  bool get hasFilters => 
      includeTags.isNotEmpty ||
      excludeTags.isNotEmpty ||
      folderName != null ||
      hasAttachment ||
      attachmentType != null ||
      attachmentFilename != null ||
      fromEmail ||
      fromWeb ||
      isPinned;

  SearchQuery copyWith({
    String? keywords,
    List<String>? includeTags,
    List<String>? excludeTags,
    String? folderName,
    bool? hasAttachment,
    String? attachmentType,
    String? attachmentFilename,
    bool? fromEmail,
    bool? fromWeb,
    bool? isPinned,
    Map<String, dynamic>? rawFilters,
  }) {
    return SearchQuery(
      keywords: keywords ?? this.keywords,
      includeTags: includeTags ?? this.includeTags,
      excludeTags: excludeTags ?? this.excludeTags,
      folderName: folderName ?? this.folderName,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentFilename: attachmentFilename ?? this.attachmentFilename,
      fromEmail: fromEmail ?? this.fromEmail,
      fromWeb: fromWeb ?? this.fromWeb,
      isPinned: isPinned ?? this.isPinned,
      rawFilters: rawFilters ?? this.rawFilters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'includeTags': includeTags,
      'excludeTags': excludeTags,
      'folderName': folderName,
      'hasAttachment': hasAttachment,
      'attachmentType': attachmentType,
      'attachmentFilename': attachmentFilename,
      'fromEmail': fromEmail,
      'fromWeb': fromWeb,
      'isPinned': isPinned,
      'rawFilters': rawFilters,
    };
  }

  factory SearchQuery.fromJson(Map<String, dynamic> json) {
    return SearchQuery(
      keywords: json['keywords'] as String? ?? '',
      includeTags: (json['includeTags'] as List<dynamic>?)?.cast<String>() ?? [],
      excludeTags: (json['excludeTags'] as List<dynamic>?)?.cast<String>() ?? [],
      folderName: json['folderName'] as String?,
      hasAttachment: json['hasAttachment'] as bool? ?? false,
      attachmentType: json['attachmentType'] as String?,
      attachmentFilename: json['attachmentFilename'] as String?,
      fromEmail: json['fromEmail'] as bool? ?? false,
      fromWeb: json['fromWeb'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      rawFilters: json['rawFilters'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Parser for search queries with special tokens
class SearchParser {
  /// Parse a search query string into structured components
  static SearchQuery parse(String query) {
    if (query.trim().isEmpty) {
      return const SearchQuery();
    }

    final tokens = <String>[];
    final includeTags = <String>[];
    final excludeTags = <String>[];
    final keywords = <String>[];
    String? folderName;
    bool hasAttachment = false;
    String? attachmentType;
    String? attachmentFilename;
    bool fromEmail = false;
    bool fromWeb = false;
    bool isPinned = false;

    // Split query into tokens, preserving quoted strings
    final parts = _tokenize(query);
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Check for tag tokens
      if (trimmed.startsWith('#')) {
        final tag = trimmed.substring(1).trim();
        if (tag.isNotEmpty) {
          includeTags.add(tag.toLowerCase());
        }
      } 
      // Check for excluded tag tokens
      else if (trimmed.startsWith('-#')) {
        final tag = trimmed.substring(2).trim();
        if (tag.isNotEmpty) {
          excludeTags.add(tag.toLowerCase());
        }
      }
      // Check for folder filter
      else if (trimmed.startsWith('folder:')) {
        folderName = trimmed.substring(7).trim();
        if (folderName!.startsWith('"') && folderName!.endsWith('"')) {
          folderName = folderName!.substring(1, folderName!.length - 1);
        }
      }
      // Check for attachment filters
      else if (trimmed == 'has:attachment') {
        hasAttachment = true;
      }
      else if (trimmed.startsWith('type:')) {
        attachmentType = trimmed.substring(5).trim();
      }
      else if (trimmed.startsWith('filename:')) {
        attachmentFilename = trimmed.substring(9).trim();
        if (attachmentFilename!.startsWith('"') && attachmentFilename!.endsWith('"')) {
          attachmentFilename = attachmentFilename!.substring(1, attachmentFilename!.length - 1);
        }
      }
      // Check for source filters
      else if (trimmed == 'from:email') {
        fromEmail = true;
      }
      else if (trimmed == 'from:web') {
        fromWeb = true;
      }
      // Check for pinned filter
      else if (trimmed == 'is:pinned') {
        isPinned = true;
      }
      // Regular keyword
      else {
        keywords.add(trimmed);
      }
    }

    return SearchQuery(
      keywords: keywords.join(' '),
      includeTags: includeTags,
      excludeTags: excludeTags,
      folderName: folderName,
      hasAttachment: hasAttachment,
      attachmentType: attachmentType,
      attachmentFilename: attachmentFilename,
      fromEmail: fromEmail,
      fromWeb: fromWeb,
      isPinned: isPinned,
      rawFilters: {
        'originalQuery': query,
      },
    );
  }

  /// Tokenize a query string, preserving quoted strings
  static List<String> _tokenize(String query) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escaped = false;

    for (int i = 0; i < query.length; i++) {
      final char = query[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"') {
        if (inQuotes) {
          // End of quoted string
          tokens.add(buffer.toString());
          buffer.clear();
          inQuotes = false;
        } else {
          // Start of quoted string
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
          inQuotes = true;
        }
        continue;
      }

      if (!inQuotes && char == ' ') {
        // Space outside quotes = token separator
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    // Add remaining buffer content
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Build a query string from components
  static String build(SearchQuery query) {
    final parts = <String>[];

    // Add keywords
    if (query.keywords.isNotEmpty) {
      parts.add(query.keywords);
    }

    // Add include tags
    for (final tag in query.includeTags) {
      parts.add('#$tag');
    }

    // Add exclude tags
    for (final tag in query.excludeTags) {
      parts.add('-#$tag');
    }

    // Add folder filter
    if (query.folderName != null) {
      final name = query.folderName!;
      if (name.contains(' ')) {
        parts.add('folder:"$name"');
      } else {
        parts.add('folder:$name');
      }
    }

    // Add attachment filters
    if (query.hasAttachment) {
      parts.add('has:attachment');
    }

    if (query.attachmentType != null) {
      parts.add('type:${query.attachmentType}');
    }

    if (query.attachmentFilename != null) {
      final filename = query.attachmentFilename!;
      if (filename.contains(' ')) {
        parts.add('filename:"$filename"');
      } else {
        parts.add('filename:$filename');
      }
    }

    // Add source filters
    if (query.fromEmail) {
      parts.add('from:email');
    }

    if (query.fromWeb) {
      parts.add('from:web');
    }

    // Add pinned filter
    if (query.isPinned) {
      parts.add('is:pinned');
    }

    return parts.join(' ');
  }

  /// Get tag suggestions for autocomplete
  static List<String> getTagSuggestions(String input, List<String> availableTags) {
    if (input.isEmpty || !input.startsWith('#')) {
      return [];
    }

    final prefix = input.substring(1).toLowerCase();
    if (prefix.isEmpty) {
      return availableTags.take(10).toList();
    }

    return availableTags
        .where((tag) => tag.toLowerCase().startsWith(prefix))
        .take(10)
        .toList();
  }
}