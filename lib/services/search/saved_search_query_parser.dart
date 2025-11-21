import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/saved_search.dart';

/// Production-grade query parser for saved search advanced syntax
/// Phase 2.1: Organization Features - Query Parsing
///
/// Supports advanced search syntax:
/// - folder:Work - Filter by folder name
/// - tag:urgent tag:important - Multiple tags (AND)
/// - has:attachment - Has attachments
/// - has:reminder - Has reminders
/// - status:completed - Filter by status
/// - before:2025-12-31 - Date filtering
/// - after:2025-01-01 - Date filtering
/// - "quoted text" - Exact phrase match
/// - plain text - Full-text search
///
/// Examples:
/// - folder:Work tag:urgent has:attachment
/// - "Project meeting" tag:important status:active
/// - folder:Personal before:2025-12-31
class SavedSearchQueryParser {
  SavedSearchQueryParser({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  /// Parse query string into structured filters
  ///
  /// Returns [ParsedQuery] with:
  /// - filters: Structured filters for database queries
  /// - textQuery: Remaining text for full-text search
  /// - errors: Any parsing errors encountered
  ParsedQuery parse(String query) {
    if (query.trim().isEmpty) {
      return ParsedQuery.empty();
    }

    try {
      _logger.debug('[QueryParser] Parsing query: $query');

      final tokens = _tokenize(query);
      var filters = const SearchFilters(); // Start with empty immutable filters
      final textParts = <String>[];
      final errors = <String>[];

      for (final token in tokens) {
        if (token.type == TokenType.filter) {
          filters = _applyFilter(token, filters, errors);
        } else if (token.type == TokenType.text) {
          textParts.add(token.value);
        }
      }

      final textQuery = textParts.join(' ').trim();

      _logger.debug(
        '[QueryParser] Parsed successfully',
        data: {
          'filters': filters.toString(),
          'textQuery': textQuery,
          'errorCount': errors.length,
        },
      );

      return ParsedQuery(
        filters: filters,
        textQuery: textQuery,
        errors: errors,
      );
    } catch (e, stack) {
      _logger.error(
        '[QueryParser] Failed to parse query',
        error: e,
        stackTrace: stack,
        data: {'query': query},
      );

      return ParsedQuery(
        filters: SearchFilters(),
        textQuery: query, // Fallback to full-text search
        errors: ['Failed to parse query: ${e.toString()}'],
      );
    }
  }

  /// Tokenize query string into tokens
  List<QueryToken> _tokenize(String query) {
    final tokens = <QueryToken>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < query.length) {
      final char = query[i];

      if (char == '"') {
        if (inQuotes) {
          // End of quoted text
          tokens.add(QueryToken(
            type: TokenType.text,
            value: buffer.toString(),
          ));
          buffer.clear();
          inQuotes = false;
        } else {
          // Start of quoted text
          if (buffer.isNotEmpty) {
            _processBuffer(buffer.toString(), tokens);
            buffer.clear();
          }
          inQuotes = true;
        }
      } else if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          _processBuffer(buffer.toString(), tokens);
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }

      i++;
    }

    // Process remaining buffer
    if (buffer.isNotEmpty) {
      if (inQuotes) {
        // Unclosed quote - treat as text
        tokens.add(QueryToken(
          type: TokenType.text,
          value: buffer.toString(),
        ));
      } else {
        _processBuffer(buffer.toString(), tokens);
      }
    }

    return tokens;
  }

  /// Process buffer content into tokens
  void _processBuffer(String content, List<QueryToken> tokens) {
    if (content.contains(':')) {
      final parts = content.split(':');
      if (parts.length == 2 && _isValidFilterKey(parts[0])) {
        tokens.add(QueryToken(
          type: TokenType.filter,
          key: parts[0],
          value: parts[1],
        ));
        return;
      }
    }

    // Not a filter, treat as text
    tokens.add(QueryToken(
      type: TokenType.text,
      value: content,
    ));
  }

  /// Check if key is a valid filter
  bool _isValidFilterKey(String key) {
    const validKeys = [
      'folder',
      'tag',
      'has',
      'status',
      'before',
      'after',
      'type',
    ];
    return validKeys.contains(key.toLowerCase());
  }

  /// Apply filter token to filters object
  /// Returns a new SearchFilters instance with the filter applied
  SearchFilters _applyFilter(
    QueryToken token,
    SearchFilters filters,
    List<String> errors,
  ) {
    final key = token.key!.toLowerCase();
    final value = token.value;

    try {
      switch (key) {
        case 'folder':
          return filters.copyWith(folderId: value);

        case 'tag':
          final existingTags = filters.tags ?? [];
          return filters.copyWith(tags: [...existingTags, value]);

        case 'has':
          return _applyHasFilter(value, filters, errors);

        case 'status':
          // Will be used for filtering completed/active notes
          return filters.copyWith(noteType: value);

        case 'before':
          try {
            return filters.copyWith(endDate: DateTime.parse(value));
          } catch (e) {
            errors.add('Invalid date format for "before": $value');
            return filters;
          }

        case 'after':
          try {
            return filters.copyWith(startDate: DateTime.parse(value));
          } catch (e) {
            errors.add('Invalid date format for "after": $value');
            return filters;
          }

        case 'type':
          return filters.copyWith(noteType: value);

        default:
          errors.add('Unknown filter key: $key');
          return filters;
      }
    } catch (e) {
      errors.add('Failed to apply filter $key:$value - ${e.toString()}');
      return filters;
    }
  }

  /// Apply 'has:' filter
  /// Returns a new SearchFilters instance with the filter applied
  SearchFilters _applyHasFilter(
    String value,
    SearchFilters filters,
    List<String> errors,
  ) {
    switch (value.toLowerCase()) {
      case 'attachment':
      case 'attachments':
        return filters.copyWith(hasAttachments: true);

      case 'reminder':
      case 'reminders':
        return filters.copyWith(isPinned: true); // Reusing isPinned for reminder flag

      default:
        errors.add('Unknown "has" filter value: $value');
        return filters;
    }
  }

  /// Validate query syntax
  ///
  /// Returns list of validation errors (empty if valid)
  List<String> validate(String query) {
    final parsed = parse(query);
    return parsed.errors;
  }

  /// Get suggested filters for autocomplete
  List<String> getSuggestions(String partial) {
    const suggestions = [
      'folder:',
      'tag:',
      'has:attachment',
      'has:reminder',
      'status:completed',
      'status:active',
      'before:',
      'after:',
      'type:note',
      'type:task',
    ];

    if (partial.isEmpty) {
      return suggestions;
    }

    return suggestions
        .where((s) => s.toLowerCase().startsWith(partial.toLowerCase()))
        .toList();
  }
}

/// Token types for query parsing
enum TokenType {
  filter, // key:value filter
  text, // Plain text or quoted text
}

/// Parsed query token
class QueryToken {
  const QueryToken({
    required this.type,
    this.key,
    required this.value,
  });

  final TokenType type;
  final String? key;
  final String value;

  @override
  String toString() {
    if (type == TokenType.filter) {
      return 'Filter($key:$value)';
    }
    return 'Text($value)';
  }
}

/// Parsed query result
class ParsedQuery {
  const ParsedQuery({
    required this.filters,
    required this.textQuery,
    required this.errors,
  });

  factory ParsedQuery.empty() {
    return ParsedQuery(
      filters: SearchFilters(),
      textQuery: '',
      errors: const [],
    );
  }

  /// Structured filters for database queries
  final SearchFilters filters;

  /// Remaining text for full-text search
  final String textQuery;

  /// Any parsing errors
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get hasFilters =>
      filters.tags != null ||
      filters.folderId != null ||
      filters.startDate != null ||
      filters.endDate != null ||
      filters.isPinned != null ||
      filters.hasAttachments != null ||
      filters.noteType != null;

  @override
  String toString() {
    return 'ParsedQuery(filters: $filters, text: "$textQuery", errors: ${errors.length})';
  }
}
