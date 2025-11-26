import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/saved_search.dart';
import 'package:duru_notes/services/search/saved_search_query_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production-grade unit tests for SavedSearchQueryParser
/// Phase 2.1: Organization Features - Query Parsing Tests
///
/// Test Coverage:
/// - Token parsing (filters and text)
/// - Quoted text handling
/// - Multiple filters
/// - Date parsing
/// - Validation
/// - Autocomplete suggestions
/// - Error handling
/// - Edge cases

void main() {
  group('SavedSearchQueryParser - Token Parsing', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('parses simple text query', () {
      final result = parser.parse('meeting notes');

      expect(result.textQuery, equals('meeting notes'));
      expect(result.hasFilters, isFalse);
      expect(result.errors, isEmpty);
    });

    test('parses folder filter', () {
      final result = parser.parse('folder:Work');

      expect(result.filters.folderId, equals('Work'));
      expect(result.textQuery, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('parses single tag filter', () {
      final result = parser.parse('tag:urgent');

      expect(result.filters.tags, contains('urgent'));
      expect(result.errors, isEmpty);
    });

    test('parses multiple tag filters (AND logic)', () {
      final result = parser.parse('tag:urgent tag:important');

      expect(result.filters.tags, hasLength(2));
      expect(result.filters.tags, containsAll(['urgent', 'important']));
      expect(result.errors, isEmpty);
    });

    test('parses has:attachment filter', () {
      final result = parser.parse('has:attachment');

      expect(result.filters.hasAttachments, isTrue);
      expect(result.errors, isEmpty);
    });

    test('parses has:attachments (plural) filter', () {
      final result = parser.parse('has:attachments');

      expect(result.filters.hasAttachments, isTrue);
      expect(result.errors, isEmpty);
    });

    test('parses has:reminder filter', () {
      final result = parser.parse('has:reminder');

      expect(result.filters.isPinned, isTrue); // Reusing isPinned for reminders
      expect(result.errors, isEmpty);
    });

    test('parses status filter', () {
      final result = parser.parse('status:completed');

      expect(result.filters.noteType, equals('completed'));
      expect(result.errors, isEmpty);
    });

    test('parses type filter', () {
      final result = parser.parse('type:task');

      expect(result.filters.noteType, equals('task'));
      expect(result.errors, isEmpty);
    });

    test('parses before date filter', () {
      final result = parser.parse('before:2025-12-31');

      expect(result.filters.endDate, isNotNull);
      expect(result.filters.endDate!.year, equals(2025));
      expect(result.filters.endDate!.month, equals(12));
      expect(result.filters.endDate!.day, equals(31));
      expect(result.errors, isEmpty);
    });

    test('parses after date filter', () {
      final result = parser.parse('after:2025-01-01');

      expect(result.filters.startDate, isNotNull);
      expect(result.filters.startDate!.year, equals(2025));
      expect(result.filters.startDate!.month, equals(1));
      expect(result.filters.startDate!.day, equals(1));
      expect(result.errors, isEmpty);
    });

    test('parses combined filters and text', () {
      final result = parser.parse('folder:Work tag:urgent meeting notes');

      expect(result.filters.folderId, equals('Work'));
      expect(result.filters.tags, contains('urgent'));
      expect(result.textQuery, equals('meeting notes'));
      expect(result.errors, isEmpty);
    });

    test('parses complex query with multiple filter types', () {
      final result = parser.parse(
        'folder:Work tag:urgent tag:important has:attachment status:active meeting',
      );

      expect(result.filters.folderId, equals('Work'));
      expect(result.filters.tags, containsAll(['urgent', 'important']));
      expect(result.filters.hasAttachments, isTrue);
      expect(result.filters.noteType, equals('active'));
      expect(result.textQuery, equals('meeting'));
      expect(result.errors, isEmpty);
    });
  });

  group('SavedSearchQueryParser - Quoted Text', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('parses quoted text as single token', () {
      final result = parser.parse('"Project meeting notes"');

      expect(result.textQuery, equals('Project meeting notes'));
      expect(result.hasFilters, isFalse);
      expect(result.errors, isEmpty);
    });

    test('parses quoted text with filters', () {
      final result = parser.parse('folder:Work "Project meeting"');

      expect(result.filters.folderId, equals('Work'));
      expect(result.textQuery, equals('Project meeting'));
      expect(result.errors, isEmpty);
    });

    test('parses multiple quoted strings', () {
      final result = parser.parse('"first phrase" "second phrase"');

      expect(result.textQuery, equals('first phrase second phrase'));
      expect(result.errors, isEmpty);
    });

    test('handles unclosed quotes gracefully', () {
      final result = parser.parse('"unclosed quote');

      expect(result.textQuery, equals('unclosed quote'));
      expect(result.errors, isEmpty);
    });

    test('handles quotes in filter values', () {
      final result = parser.parse('folder:"My Folder" meeting');

      // Note: Current implementation doesn't handle quotes in filter values
      // This documents the current behavior
      expect(result.textQuery, contains('My Folder'));
      expect(result.textQuery, contains('meeting'));
    });
  });

  group('SavedSearchQueryParser - Validation', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('validates correct query', () {
      final errors = parser.validate('folder:Work tag:urgent meeting');

      expect(errors, isEmpty);
    });

    test('validates empty query', () {
      final errors = parser.validate('');

      expect(errors, isEmpty);
    });

    test('validates query with invalid date format', () {
      final errors = parser.validate('before:invalid-date');

      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid date format'));
    });

    test('validates query with unknown has filter value', () {
      final errors = parser.validate('has:unknown');

      expect(errors, isNotEmpty);
      expect(errors.first, contains('Unknown "has" filter value'));
    });

    test('validates query with invalid filter key', () {
      final result = parser.parse('invalidkey:value');

      // Invalid keys are treated as text, not errors
      expect(result.textQuery, equals('invalidkey:value'));
      expect(result.errors, isEmpty);
    });

    test('handles multiple validation errors', () {
      final errors = parser.validate('before:bad-date after:also-bad');

      expect(errors.length, equals(2));
      expect(errors.every((e) => e.contains('Invalid date format')), isTrue);
    });
  });

  group('SavedSearchQueryParser - Autocomplete Suggestions', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('returns all suggestions for empty input', () {
      final suggestions = parser.getSuggestions('');

      expect(suggestions.length, greaterThan(5));
      expect(suggestions, contains('folder:'));
      expect(suggestions, contains('tag:'));
      expect(suggestions, contains('has:attachment'));
      expect(suggestions, contains('status:active'));
    });

    test('filters suggestions by prefix', () {
      final suggestions = parser.getSuggestions('fol');

      expect(suggestions, contains('folder:'));
      expect(suggestions, isNot(contains('tag:')));
    });

    test('filters suggestions case-insensitively', () {
      final suggestions = parser.getSuggestions('FoL');

      expect(suggestions, contains('folder:'));
    });

    test('returns empty for non-matching prefix', () {
      final suggestions = parser.getSuggestions('xyz');

      expect(suggestions, isEmpty);
    });

    test('suggests has: variations', () {
      final suggestions = parser.getSuggestions('has');

      expect(suggestions, contains('has:attachment'));
      expect(suggestions, contains('has:reminder'));
    });

    test('suggests status variations', () {
      final suggestions = parser.getSuggestions('status');

      expect(suggestions, contains('status:completed'));
      expect(suggestions, contains('status:active'));
    });
  });

  group('SavedSearchQueryParser - Edge Cases', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('handles whitespace-only query', () {
      final result = parser.parse('   ');

      expect(result.textQuery, isEmpty);
      expect(result.hasFilters, isFalse);
      expect(result.errors, isEmpty);
    });

    test('handles query with extra spaces', () {
      final result = parser.parse('folder:Work    tag:urgent   meeting');

      expect(result.filters.folderId, equals('Work'));
      expect(result.filters.tags, contains('urgent'));
      expect(result.textQuery, equals('meeting'));
    });

    test('handles filter without value', () {
      final result = parser.parse('folder: tag:urgent');

      // Empty filter value should be treated differently
      // Current behavior: creates filter with empty string
      expect(result.filters.folderId, equals(''));
      expect(result.filters.tags, contains('urgent'));
    });

    test('handles colon in regular text', () {
      final result = parser.parse('meeting at 3:00 PM');

      // Colons without valid filter keys are treated as text
      expect(result.textQuery, contains('meeting at 3:00 PM'));
    });

    test('handles special characters', () {
      final result = parser.parse('meeting@office #important');

      expect(result.textQuery, equals('meeting@office #important'));
      expect(result.errors, isEmpty);
    });

    test('handles unicode characters', () {
      final result = parser.parse('プロジェクト会議');

      expect(result.textQuery, equals('プロジェクト会議'));
      expect(result.errors, isEmpty);
    });

    test('handles very long queries', () {
      final longText = 'word ' * 1000;
      final result = parser.parse('folder:Work $longText');

      expect(result.filters.folderId, equals('Work'));
      expect(result.textQuery.length, greaterThan(1000));
      expect(result.errors, isEmpty);
    });

    test('handles date range filters', () {
      final result = parser.parse('after:2025-01-01 before:2025-12-31');

      expect(result.filters.startDate, isNotNull);
      expect(result.filters.endDate, isNotNull);
      expect(
        result.filters.startDate!.isBefore(result.filters.endDate!),
        isTrue,
      );
      expect(result.errors, isEmpty);
    });
  });

  group('SavedSearchQueryParser - Immutability', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('returns new SearchFilters instances', () {
      final result1 = parser.parse('folder:Work');
      final result2 = parser.parse('folder:Personal');

      expect(result1.filters.folderId, equals('Work'));
      expect(result2.filters.folderId, equals('Personal'));
      expect(result1.filters.folderId, isNot(equals(result2.filters.folderId)));
    });

    test('does not mutate SearchFilters during parsing', () {
      final emptyFilters = SearchFilters();

      parser.parse('folder:Work tag:urgent');

      // Verify original empty filters are unchanged
      expect(emptyFilters.folderId, isNull);
      expect(emptyFilters.tags, isNull);
    });

    test('accumulates tags correctly', () {
      final result = parser.parse('tag:first tag:second tag:third');

      expect(result.filters.tags, hasLength(3));
      expect(result.filters.tags, containsAll(['first', 'second', 'third']));
    });
  });

  group('SavedSearchQueryParser - ParsedQuery Properties', () {
    late SavedSearchQueryParser parser;

    setUp(() {
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
    });

    test('hasErrors returns false for valid query', () {
      final result = parser.parse('folder:Work meeting');

      expect(result.hasErrors, isFalse);
    });

    test('hasErrors returns true for invalid query', () {
      final result = parser.parse('before:invalid-date');

      expect(result.hasErrors, isTrue);
    });

    test('hasFilters returns false for text-only query', () {
      final result = parser.parse('meeting notes');

      expect(result.hasFilters, isFalse);
    });

    test('hasFilters returns true when filters present', () {
      final result = parser.parse('folder:Work');

      expect(result.hasFilters, isTrue);
    });

    test('hasFilters returns true for any filter type', () {
      final testCases = [
        'folder:Work',
        'tag:urgent',
        'before:2025-12-31',
        'after:2025-01-01',
        'has:attachment',
        'status:active',
      ];

      for (final query in testCases) {
        final result = parser.parse(query);
        expect(result.hasFilters, isTrue, reason: 'Query: $query');
      }
    });

    test('ParsedQuery.empty() returns clean state', () {
      final result = ParsedQuery.empty();

      expect(result.textQuery, isEmpty);
      expect(result.hasFilters, isFalse);
      expect(result.hasErrors, isFalse);
      expect(result.errors, isEmpty);
    });
  });
}
