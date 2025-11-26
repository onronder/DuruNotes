import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/saved_search.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_saved_search_repository.dart';
import 'package:duru_notes/services/search/saved_search_query_parser.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

/// Production-grade service for saved search operations
/// Phase 2.1: Organization Features - Service Layer
///
/// Responsibilities:
/// - Business logic for saved search management
/// - Query parsing and execution
/// - Usage tracking and analytics
/// - Integration between repositories
/// - Performance optimization
class SavedSearchService {
  SavedSearchService({
    required ISavedSearchRepository savedSearchRepository,
    required INotesRepository notesRepository,
    required SavedSearchQueryParser queryParser,
    required AppLogger logger,
  }) : _savedSearchRepo = savedSearchRepository,
       _notesRepo = notesRepository,
       _parser = queryParser,
       _logger = logger;

  final ISavedSearchRepository _savedSearchRepo;
  final INotesRepository _notesRepo;
  final SavedSearchQueryParser _parser;
  final AppLogger _logger;
  final _uuid = const Uuid();

  /// Create a new saved search
  ///
  /// Validates query syntax before saving.
  /// Returns the created search with generated ID.
  Future<SavedSearch> createSavedSearch({
    required String name,
    required String query,
    bool isPinned = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Saved search name cannot be empty');
    }

    if (query.trim().isEmpty) {
      throw ArgumentError('Saved search query cannot be empty');
    }

    try {
      _logger.info(
        '[SavedSearchService] Creating saved search',
        data: {'name': name, 'query': query},
      );

      // Validate query syntax
      final errors = _parser.validate(query);
      if (errors.isNotEmpty) {
        _logger.warning(
          '[SavedSearchService] Invalid query syntax',
          data: {'errors': errors},
        );
        throw ArgumentError('Invalid query syntax: ${errors.join(", ")}');
      }

      // Parse query to extract filters
      final parsed = _parser.parse(query);

      // Create saved search entity
      final search = SavedSearch(
        id: _uuid.v4(),
        name: name,
        query: query,
        filters: parsed.filters,
        isPinned: isPinned,
        createdAt: DateTime.now(),
        usageCount: 0,
        displayOrder: 0,
      );

      // Save to repository
      final created = await _savedSearchRepo.upsertSavedSearch(search);

      _logger.info(
        '[SavedSearchService] Saved search created successfully',
        data: {'id': created.id, 'name': created.name},
      );

      return created;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to create saved search',
        error: e,
        stackTrace: stack,
        data: {'name': name, 'query': query},
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'createSavedSearch');
            scope.setContexts('input', {'name': name, 'query': query});
          },
        ),
      );
      rethrow;
    }
  }

  /// Execute a saved search and return matching notes
  ///
  /// Updates usage statistics automatically.
  /// Returns list of notes matching the search criteria.
  Future<List<Note>> executeSavedSearch(String searchId) async {
    try {
      _logger.info(
        '[SavedSearchService] Executing saved search',
        data: {'searchId': searchId},
      );

      final startTime = DateTime.now();

      // Get saved search
      final search = await _savedSearchRepo.getSavedSearchById(searchId);
      if (search == null) {
        throw StateError('Saved search not found: $searchId');
      }

      // Parse query
      final parsed = _parser.parse(search.query);

      // Execute search with filters
      final notes = await _executeSearchWithFilters(
        textQuery: parsed.textQuery,
        filters: parsed.filters,
      );

      // Update usage statistics (async, non-blocking)
      unawaited(_updateUsageStatistics(searchId));

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        '[SavedSearchService] Search executed successfully',
        data: {
          'searchId': searchId,
          'resultCount': notes.length,
          'durationMs': duration.inMilliseconds,
        },
      );

      return notes;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to execute saved search',
        error: e,
        stackTrace: stack,
        data: {'searchId': searchId},
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'executeSavedSearch');
            scope.setContexts('input', {'searchId': searchId});
          },
        ),
      );
      rethrow;
    }
  }

  /// Execute search with structured filters
  Future<List<Note>> _executeSearchWithFilters({
    required String textQuery,
    required SearchFilters filters,
  }) async {
    // Get all notes from repository (using localNotes for in-memory filtering)
    var notes = await _notesRepo.localNotes();

    _logger.debug('[SavedSearchService] Initial notes count: ${notes.length}');

    // Apply filters sequentially
    notes = _applyFilters(notes, filters);

    _logger.debug('[SavedSearchService] After filters: ${notes.length} notes');

    // Apply text search if present
    if (textQuery.isNotEmpty) {
      notes = _applyTextSearch(notes, textQuery);
      _logger.debug(
        '[SavedSearchService] After text search: ${notes.length} notes',
      );
    }

    return notes;
  }

  /// Apply structured filters to notes list
  List<Note> _applyFilters(List<Note> notes, SearchFilters filters) {
    var filtered = notes;

    // Filter by folder
    if (filters.folderId != null) {
      filtered = filtered
          .where((note) => note.folderId == filters.folderId)
          .toList();
      _logger.debug(
        '[SavedSearchService] Folder filter applied: ${filtered.length} notes',
      );
    }

    // Filter by tags
    if (filters.tags != null && filters.tags!.isNotEmpty) {
      filtered = filtered.where((note) {
        // Note must have ALL specified tags (AND logic)
        return filters.tags!.every((tag) => note.tags.contains(tag));
      }).toList();
      _logger.debug(
        '[SavedSearchService] Tag filter applied: ${filtered.length} notes',
      );
    }

    // Filter by date range
    if (filters.startDate != null) {
      filtered = filtered
          .where(
            (note) =>
                note.createdAt.isAfter(filters.startDate!) ||
                note.createdAt.isAtSameMomentAs(filters.startDate!),
          )
          .toList();
    }

    if (filters.endDate != null) {
      filtered = filtered
          .where(
            (note) =>
                note.createdAt.isBefore(filters.endDate!) ||
                note.createdAt.isAtSameMomentAs(filters.endDate!),
          )
          .toList();
    }

    // Filter by attachments
    if (filters.hasAttachments == true) {
      filtered = filtered.where((note) {
        // Check if note has attachments (attachmentMeta is non-null and non-empty)
        return note.attachmentMeta != null && note.attachmentMeta!.isNotEmpty;
      }).toList();
      _logger.debug(
        '[SavedSearchService] Attachment filter applied: ${filtered.length} notes',
      );
    }

    // Filter by pinned status (if using for reminders)
    if (filters.isPinned != null) {
      filtered = filtered
          .where((note) => note.isPinned == filters.isPinned)
          .toList();
    }

    return filtered;
  }

  /// Apply text search to notes
  List<Note> _applyTextSearch(List<Note> notes, String query) {
    final lowerQuery = query.toLowerCase();

    return notes.where((note) {
      // Search in title
      if (note.title.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Search in body
      if (note.body.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Search in tags
      if (note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Update usage statistics for a saved search
  Future<void> _updateUsageStatistics(String searchId) async {
    try {
      await _savedSearchRepo.updateUsageStatistics(searchId);
      _logger.debug(
        '[SavedSearchService] Updated usage statistics for $searchId',
      );
    } catch (e) {
      // Don't fail the search if usage tracking fails
      _logger.warning(
        '[SavedSearchService] Failed to update usage statistics: $e',
        data: {'searchId': searchId},
      );
    }
  }

  /// Get all saved searches
  ///
  /// Returns searches ordered by:
  /// 1. Pinned searches first
  /// 2. Most frequently used
  /// 3. Most recently created
  Future<List<SavedSearch>> getAllSavedSearches() async {
    try {
      final searches = await _savedSearchRepo.getAllSavedSearches();

      _logger.info(
        '[SavedSearchService] Retrieved ${searches.length} saved searches',
      );

      return searches;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to get saved searches',
        error: e,
        stackTrace: stack,
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'getAllSavedSearches');
          },
        ),
      );
      rethrow;
    }
  }

  /// Get saved searches by type
  Future<List<SavedSearch>> getSavedSearchesByType(String searchType) async {
    try {
      final searches = await _savedSearchRepo.getSavedSearchesByType(
        searchType,
      );

      _logger.info(
        '[SavedSearchService] Retrieved ${searches.length} searches of type: $searchType',
      );

      return searches;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to get searches by type',
        error: e,
        stackTrace: stack,
        data: {'searchType': searchType},
      );
      rethrow;
    }
  }

  /// Update a saved search
  Future<SavedSearch> updateSavedSearch(SavedSearch search) async {
    try {
      _logger.info(
        '[SavedSearchService] Updating saved search',
        data: {'id': search.id, 'name': search.name},
      );

      // Validate query if changed
      if (search.query.isNotEmpty) {
        final errors = _parser.validate(search.query);
        if (errors.isNotEmpty) {
          throw ArgumentError('Invalid query syntax: ${errors.join(", ")}');
        }
      }

      final updated = await _savedSearchRepo.upsertSavedSearch(search);

      _logger.info(
        '[SavedSearchService] Saved search updated successfully',
        data: {'id': updated.id},
      );

      return updated;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to update saved search',
        error: e,
        stackTrace: stack,
        data: {'id': search.id, 'name': search.name},
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'updateSavedSearch');
            scope.setContexts('input', {'searchId': search.id});
          },
        ),
      );
      rethrow;
    }
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String searchId) async {
    try {
      _logger.info(
        '[SavedSearchService] Deleting saved search',
        data: {'searchId': searchId},
      );

      await _savedSearchRepo.deleteSavedSearch(searchId);

      _logger.info(
        '[SavedSearchService] Saved search deleted successfully',
        data: {'searchId': searchId},
      );
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to delete saved search',
        error: e,
        stackTrace: stack,
        data: {'searchId': searchId},
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'deleteSavedSearch');
            scope.setContexts('input', {'searchId': searchId});
          },
        ),
      );
      rethrow;
    }
  }

  /// Toggle pin status
  Future<void> togglePin(String searchId) async {
    try {
      _logger.info(
        '[SavedSearchService] Toggling pin for saved search',
        data: {'searchId': searchId},
      );

      await _savedSearchRepo.togglePin(searchId);

      _logger.info(
        '[SavedSearchService] Pin toggled successfully',
        data: {'searchId': searchId},
      );
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to toggle pin',
        error: e,
        stackTrace: stack,
        data: {'searchId': searchId},
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'togglePin');
            scope.setContexts('input', {'searchId': searchId});
          },
        ),
      );
      rethrow;
    }
  }

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> orderedIds) async {
    try {
      _logger.info(
        '[SavedSearchService] Reordering saved searches',
        data: {'count': orderedIds.length},
      );

      await _savedSearchRepo.reorderSavedSearches(orderedIds);

      _logger.info(
        '[SavedSearchService] Saved searches reordered successfully',
      );
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to reorder saved searches',
        error: e,
        stackTrace: stack,
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('service', 'SavedSearchService');
            scope.setTag('method', 'reorderSavedSearches');
          },
        ),
      );
      rethrow;
    }
  }

  /// Watch saved searches for real-time updates
  Stream<List<SavedSearch>> watchSavedSearches() {
    try {
      _logger.debug('[SavedSearchService] Watching saved searches');
      return _savedSearchRepo.watchSavedSearches();
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to watch saved searches',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Search within saved searches by name
  Future<List<SavedSearch>> searchByName(String query) async {
    try {
      _logger.debug(
        '[SavedSearchService] Searching saved searches',
        data: {'query': query},
      );

      final results = await _savedSearchRepo.searchByName(query);

      _logger.debug(
        '[SavedSearchService] Found ${results.length} matching saved searches',
      );

      return results;
    } catch (e, stack) {
      _logger.error(
        '[SavedSearchService] Failed to search saved searches',
        error: e,
        stackTrace: stack,
        data: {'query': query},
      );
      rethrow;
    }
  }

  /// Get query suggestions for autocomplete
  List<String> getQuerySuggestions(String partial) {
    return _parser.getSuggestions(partial);
  }

  /// Validate query syntax
  List<String> validateQuery(String query) {
    return _parser.validate(query);
  }
}
