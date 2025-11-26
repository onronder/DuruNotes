import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/saved_search.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_saved_search_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/search/saved_search_query_parser.dart';
import 'package:duru_notes/services/search/saved_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production-grade unit tests for SavedSearchService
/// Phase 2.1: Organization Features - Service Layer Tests
///
/// Test Coverage:
/// - Create saved searches with validation
/// - Execute searches with filtering
/// - Update and delete operations
/// - Usage tracking
/// - Pin toggling
/// - Reordering
/// - Error handling
/// - Security (user isolation is tested at repository level)

/// Fake repository for saved searches
class _FakeSavedSearchRepository implements ISavedSearchRepository {
  final Map<String, SavedSearch> _searches = {};
  bool shouldThrowOnUpsert = false;
  bool shouldThrowOnDelete = false;
  int usageUpdateCount = 0;

  @override
  Future<List<SavedSearch>> getAllSavedSearches() async {
    final searches = _searches.values.toList();
    // Sort: pinned first, then by usage count, then by created date
    searches.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (a.usageCount != b.usageCount) {
        return b.usageCount.compareTo(a.usageCount);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return searches;
  }

  @override
  Future<SavedSearch?> getSavedSearchById(String id) async {
    return _searches[id];
  }

  @override
  Future<SavedSearch> upsertSavedSearch(SavedSearch search) async {
    if (shouldThrowOnUpsert) {
      throw Exception('Simulated upsert error');
    }
    _searches[search.id] = search;
    return search;
  }

  @override
  Future<void> deleteSavedSearch(String searchId) async {
    if (shouldThrowOnDelete) {
      throw Exception('Simulated delete error');
    }
    _searches.remove(searchId);
  }

  @override
  Future<void> updateUsageStatistics(String searchId) async {
    usageUpdateCount++;
    final search = _searches[searchId];
    if (search != null) {
      _searches[searchId] = search.copyWith(
        usageCount: search.usageCount + 1,
        lastUsedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> togglePin(String searchId) async {
    final search = _searches[searchId];
    if (search != null) {
      _searches[searchId] = search.copyWith(isPinned: !search.isPinned);
    }
  }

  @override
  Future<void> reorderSavedSearches(List<String> orderedIds) async {
    // Update display order based on position in list
    for (var i = 0; i < orderedIds.length; i++) {
      final search = _searches[orderedIds[i]];
      if (search != null) {
        _searches[orderedIds[i]] = search.copyWith(displayOrder: i);
      }
    }
  }

  @override
  Stream<List<SavedSearch>> watchSavedSearches() {
    return Stream.value(_searches.values.toList());
  }

  @override
  Future<List<SavedSearch>> searchByName(String query) async {
    final lowerQuery = query.toLowerCase();
    return _searches.values
        .where((s) => s.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Future<List<SavedSearch>> getSavedSearchesByType(String searchType) async {
    // SearchType field doesn't exist on SavedSearch entity
    // This is a placeholder implementation for testing
    return _searches.values.toList();
  }

  void clear() => _searches.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake notes repository for testing
class _FakeNotesRepository implements INotesRepository {
  final List<Note> _notes = [];

  void addNote(Note note) => _notes.add(note);

  @override
  Future<List<Note>> localNotes() async => List.of(_notes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Test helper to create notes
Note _createNote({
  required String id,
  required String title,
  String body = '',
  List<String> tags = const [],
  String? folderId,
  bool isPinned = false,
  DateTime? createdAt,
  String? attachmentMeta,
}) {
  return Note(
    id: id,
    title: title,
    body: body,
    tags: tags,
    folderId: folderId,
    isPinned: isPinned,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
    userId: 'test-user-id',
    noteType: NoteKind.note,
    deleted: false,
    version: 1,
    attachmentMeta: attachmentMeta,
  );
}

void main() {
  group('SavedSearchService - Create Operations', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository repository;
    late SavedSearchQueryParser parser;

    setUp(() {
      repository = _FakeSavedSearchRepository();
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
      service = SavedSearchService(
        savedSearchRepository: repository,
        notesRepository: _FakeNotesRepository(),
        queryParser: parser,
        logger: const ConsoleLogger(),
      );
    });

    test('creates saved search with valid query', () async {
      final search = await service.createSavedSearch(
        name: 'Work Notes',
        query: 'folder:Work',
      );

      expect(search.name, equals('Work Notes'));
      expect(search.query, equals('folder:Work'));
      expect(search.filters?.folderId, equals('Work'));
      expect(search.usageCount, equals(0));
      expect(search.isPinned, isFalse);
    });

    test('creates pinned saved search', () async {
      final search = await service.createSavedSearch(
        name: 'Important',
        query: 'tag:urgent',
        isPinned: true,
      );

      expect(search.isPinned, isTrue);
    });

    test('throws on empty name', () async {
      expect(
        () => service.createSavedSearch(name: '', query: 'folder:Work'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.createSavedSearch(name: '   ', query: 'folder:Work'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty query', () async {
      expect(
        () => service.createSavedSearch(name: 'Test', query: ''),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.createSavedSearch(name: 'Test', query: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on invalid query syntax', () async {
      expect(
        () => service.createSavedSearch(
          name: 'Test',
          query: 'before:invalid-date',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates query before creating', () async {
      // Valid query should succeed
      await service.createSavedSearch(
        name: 'Valid',
        query: 'folder:Work tag:urgent',
      );

      // Invalid query should fail
      expect(
        () => service.createSavedSearch(
          name: 'Invalid',
          query: 'before:not-a-date',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SavedSearchService - Execute Operations', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository searchRepo;
    late _FakeNotesRepository notesRepo;
    late SavedSearchQueryParser parser;

    setUp(() {
      searchRepo = _FakeSavedSearchRepository();
      notesRepo = _FakeNotesRepository();
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
      service = SavedSearchService(
        savedSearchRepository: searchRepo,
        notesRepository: notesRepo,
        queryParser: parser,
        logger: const ConsoleLogger(),
      );
    });

    test('executes saved search and returns matching notes', () async {
      // Create test notes
      notesRepo.addNote(
        _createNote(id: '1', title: 'Work Meeting', folderId: 'work-folder'),
      );
      notesRepo.addNote(
        _createNote(
          id: '2',
          title: 'Personal Note',
          folderId: 'personal-folder',
        ),
      );

      // Create saved search
      final search = await service.createSavedSearch(
        name: 'Work Notes',
        query: 'folder:work-folder',
      );

      // Execute search
      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
      expect(results.first.title, equals('Work Meeting'));
    });

    test('executes search with text query', () async {
      notesRepo.addNote(
        _createNote(id: '1', title: 'Meeting Notes', body: 'Important meeting'),
      );
      notesRepo.addNote(
        _createNote(id: '2', title: 'Random Note', body: 'Nothing important'),
      );

      final search = await service.createSavedSearch(
        name: 'Meeting Search',
        query: 'meeting',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
    });

    test('executes search with tag filter', () async {
      notesRepo.addNote(
        _createNote(id: '1', title: 'Urgent Task', tags: ['urgent', 'work']),
      );
      notesRepo.addNote(
        _createNote(id: '2', title: 'Normal Task', tags: ['work']),
      );

      final search = await service.createSavedSearch(
        name: 'Urgent',
        query: 'tag:urgent',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
    });

    test('executes search with multiple tags (AND logic)', () async {
      notesRepo.addNote(
        _createNote(id: '1', title: 'Note 1', tags: ['urgent', 'work']),
      );
      notesRepo.addNote(
        _createNote(id: '2', title: 'Note 2', tags: ['urgent']),
      );
      notesRepo.addNote(_createNote(id: '3', title: 'Note 3', tags: ['work']));

      final search = await service.createSavedSearch(
        name: 'Urgent Work',
        query: 'tag:urgent tag:work',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
    });

    test('executes search with attachment filter', () async {
      notesRepo.addNote(
        _createNote(
          id: '1',
          title: 'With Attachment',
          attachmentMeta: '{"file1": "data"}',
        ),
      );
      notesRepo.addNote(_createNote(id: '2', title: 'No Attachment'));

      final search = await service.createSavedSearch(
        name: 'Has Attachments',
        query: 'has:attachment',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
    });

    test('executes search with date range', () async {
      final oldDate = DateTime(2024, 1, 1);
      final recentDate = DateTime(2025, 6, 1);

      notesRepo.addNote(
        _createNote(id: '1', title: 'Old Note', createdAt: oldDate),
      );
      notesRepo.addNote(
        _createNote(id: '2', title: 'Recent Note', createdAt: recentDate),
      );

      final search = await service.createSavedSearch(
        name: 'Recent Notes',
        query: 'after:2025-01-01',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('2'));
    });

    test('executes complex search with multiple filters', () async {
      notesRepo.addNote(
        _createNote(
          id: '1',
          title: 'Perfect Match',
          body: 'meeting notes',
          folderId: 'work',
          tags: ['urgent'],
          attachmentMeta: '{"file": "data"}',
        ),
      );
      notesRepo.addNote(
        _createNote(
          id: '2',
          title: 'Partial Match',
          body: 'meeting notes',
          folderId: 'work',
        ),
      );
      notesRepo.addNote(
        _createNote(id: '3', title: 'No Match', body: 'random'),
      );

      final search = await service.createSavedSearch(
        name: 'Complex',
        query: 'folder:work tag:urgent has:attachment meeting',
      );

      final results = await service.executeSavedSearch(search.id);

      expect(results, hasLength(1));
      expect(results.first.id, equals('1'));
    });

    test('updates usage statistics when executing search', () async {
      notesRepo.addNote(_createNote(id: '1', title: 'Test'));

      final search = await service.createSavedSearch(
        name: 'Test',
        query: 'test',
      );

      expect(searchRepo.usageUpdateCount, equals(0));

      await service.executeSavedSearch(search.id);

      // Give async operation time to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchRepo.usageUpdateCount, equals(1));
    });

    test('throws when search not found', () async {
      expect(
        () => service.executeSavedSearch('non-existent-id'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SavedSearchService - Update Operations', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository repository;
    late SavedSearchQueryParser parser;

    setUp(() {
      repository = _FakeSavedSearchRepository();
      parser = SavedSearchQueryParser(logger: const ConsoleLogger());
      service = SavedSearchService(
        savedSearchRepository: repository,
        notesRepository: _FakeNotesRepository(),
        queryParser: parser,
        logger: const ConsoleLogger(),
      );
    });

    test('updates saved search', () async {
      final original = await service.createSavedSearch(
        name: 'Original',
        query: 'folder:Work',
      );

      final updated = await service.updateSavedSearch(
        original.copyWith(name: 'Updated', query: 'folder:Personal'),
      );

      expect(updated.name, equals('Updated'));
      expect(updated.query, equals('folder:Personal'));
    });

    test('validates query when updating', () async {
      final original = await service.createSavedSearch(
        name: 'Test',
        query: 'folder:Work',
      );

      expect(
        () => service.updateSavedSearch(
          original.copyWith(query: 'before:invalid-date'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toggles pin status', () async {
      final search = await service.createSavedSearch(
        name: 'Test',
        query: 'folder:Work',
      );

      expect(search.isPinned, isFalse);

      await service.togglePin(search.id);

      final updated = await repository.getSavedSearchById(search.id);
      expect(updated!.isPinned, isTrue);

      await service.togglePin(search.id);

      final updated2 = await repository.getSavedSearchById(search.id);
      expect(updated2!.isPinned, isFalse);
    });

    test('reorders saved searches', () async {
      final search1 = await service.createSavedSearch(
        name: 'First',
        query: 'folder:A',
      );
      final search2 = await service.createSavedSearch(
        name: 'Second',
        query: 'folder:B',
      );
      final search3 = await service.createSavedSearch(
        name: 'Third',
        query: 'folder:C',
      );

      await service.reorderSavedSearches([search3.id, search1.id, search2.id]);

      final updated1 = await repository.getSavedSearchById(search1.id);
      final updated2 = await repository.getSavedSearchById(search2.id);
      final updated3 = await repository.getSavedSearchById(search3.id);

      expect(updated3!.displayOrder, equals(0));
      expect(updated1!.displayOrder, equals(1));
      expect(updated2!.displayOrder, equals(2));
    });
  });

  group('SavedSearchService - Delete Operations', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository repository;

    setUp(() {
      repository = _FakeSavedSearchRepository();
      service = SavedSearchService(
        savedSearchRepository: repository,
        notesRepository: _FakeNotesRepository(),
        queryParser: SavedSearchQueryParser(logger: const ConsoleLogger()),
        logger: const ConsoleLogger(),
      );
    });

    test('deletes saved search', () async {
      final search = await service.createSavedSearch(
        name: 'Test',
        query: 'folder:Work',
      );

      await service.deleteSavedSearch(search.id);

      final deleted = await repository.getSavedSearchById(search.id);
      expect(deleted, isNull);
    });

    test('handles delete of non-existent search', () async {
      // Repository should throw, service propagates exception
      repository.shouldThrowOnDelete = true;

      expect(
        () => service.deleteSavedSearch('non-existent'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SavedSearchService - Query Operations', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository repository;

    setUp(() {
      repository = _FakeSavedSearchRepository();
      service = SavedSearchService(
        savedSearchRepository: repository,
        notesRepository: _FakeNotesRepository(),
        queryParser: SavedSearchQueryParser(logger: const ConsoleLogger()),
        logger: const ConsoleLogger(),
      );
    });

    test('gets all saved searches', () async {
      await service.createSavedSearch(name: 'First', query: 'folder:A');
      await service.createSavedSearch(name: 'Second', query: 'folder:B');
      await service.createSavedSearch(name: 'Third', query: 'folder:C');

      final all = await service.getAllSavedSearches();

      expect(all, hasLength(3));
    });

    test('searches by name', () async {
      await service.createSavedSearch(name: 'Work Meeting', query: 'folder:A');
      await service.createSavedSearch(name: 'Personal', query: 'folder:B');
      await service.createSavedSearch(name: 'Work Project', query: 'folder:C');

      final results = await repository.searchByName('work');

      expect(results, hasLength(2));
      expect(
        results.every((s) => s.name.toLowerCase().contains('work')),
        isTrue,
      );
    });

    test('watches saved searches stream', () async {
      final stream = service.watchSavedSearches();

      expect(stream, isA<Stream<List<SavedSearch>>>());
    });

    test('validates query syntax', () {
      final errors = service.validateQuery('before:invalid-date');

      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid date format'));
    });

    test('validates correct query', () {
      final errors = service.validateQuery('folder:Work tag:urgent meeting');

      expect(errors, isEmpty);
    });

    test('gets query suggestions', () {
      final suggestions = service.getQuerySuggestions('fol');

      expect(suggestions, contains('folder:'));
    });
  });

  group('SavedSearchService - Error Handling', () {
    late SavedSearchService service;
    late _FakeSavedSearchRepository repository;

    setUp(() {
      repository = _FakeSavedSearchRepository();
      service = SavedSearchService(
        savedSearchRepository: repository,
        notesRepository: _FakeNotesRepository(),
        queryParser: SavedSearchQueryParser(logger: const ConsoleLogger()),
        logger: const ConsoleLogger(),
      );
    });

    test('handles repository errors on create', () async {
      repository.shouldThrowOnUpsert = true;

      expect(
        () => service.createSavedSearch(name: 'Test', query: 'folder:Work'),
        throwsA(isA<Exception>()),
      );
    });

    test('handles repository errors on update', () async {
      final search = await service.createSavedSearch(
        name: 'Test',
        query: 'folder:Work',
      );

      repository.shouldThrowOnUpsert = true;

      expect(
        () => service.updateSavedSearch(search.copyWith(name: 'Updated')),
        throwsA(isA<Exception>()),
      );
    });

    test('handles repository errors on delete', () async {
      final search = await service.createSavedSearch(
        name: 'Test',
        query: 'folder:Work',
      );

      repository.shouldThrowOnDelete = true;

      expect(
        () => service.deleteSavedSearch(search.id),
        throwsA(isA<Exception>()),
      );
    });
  });
}
