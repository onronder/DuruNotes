import 'dart:async';
import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart' as appdb;
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/infrastructure/mappers/saved_search_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/helpers/note_decryption_helper.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Search repository implementation
class SearchRepository implements ISearchRepository {
  SearchRepository({
    required this.db,
    required this.client,
    required CryptoBox crypto,
    required IFolderRepository folderRepository,
  }) : _logger = LoggerFactory.instance,
       _decryptHelper = NoteDecryptionHelper(crypto),
       _folderRepository = folderRepository;

  final appdb.AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final NoteDecryptionHelper _decryptHelper;
  final IFolderRepository _folderRepository;
  final SecurityAuditTrail _securityAuditTrail = SecurityAuditTrail();

  String? get _currentUserId => client.auth.currentUser?.id;

  Future<void> _enqueuePendingOp({
    required String entityId,
    required String kind,
    String? payload,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _logger.warning(
        'Skipping enqueue - no authenticated user',
        data: {'entityId': entityId, 'kind': kind},
      );
      return;
    }

    await db.enqueue(
      userId: userId,
      entityId: entityId,
      kind: kind,
      payload: payload,
    );
  }

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'SearchRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  void _auditAccess(String resource, {required bool granted, String? reason}) {
    unawaited(
      _securityAuditTrail.logAccess(
        resource: resource,
        granted: granted,
        reason: reason,
      ),
    );
  }

  String? _requireUserId({required String method, Map<String, dynamic>? data}) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      _logger.warning('$method denied - unauthenticated user', data: data);
      _captureRepositoryException(
        method: method,
        error: StateError('Unauthenticated access'),
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      _auditAccess('search.$method', granted: false, reason: 'missing_user');
      return null;
    }
    return userId;
  }

  /// Helper method to convert LocalNote to domain.Note with decryption.
  ///
  /// Ensures all plaintext access happens inside the infrastructure layer so
  /// callers always receive fully decrypted domain entities.
  Future<domain.Note> _toDomainNote(appdb.LocalNote localNote) async {
    try {
      final title = await _decryptHelper.decryptTitle(localNote);
      final body = await _decryptHelper.decryptBody(localNote);

      // Query tags and links from database
      final tagQuery = db.select(db.noteTags)
        ..where((t) => t.noteId.equals(localNote.id));
      if (localNote.userId != null && localNote.userId!.isNotEmpty) {
        tagQuery.where((t) => t.userId.equals(localNote.userId!));
      }
      final tagRecords = await tagQuery.get();
      final tags = tagRecords.map((t) => t.tag).toList();

      final linkQuery = db.select(db.noteLinks)
        ..where((l) => l.sourceId.equals(localNote.id));
      if (localNote.userId != null && localNote.userId!.isNotEmpty) {
        linkQuery.where((l) => l.userId.equals(localNote.userId!));
      }
      final List<appdb.NoteLink> linkRecords = await linkQuery.get();
      final links = linkRecords
          .map<NoteLink>((link) => NoteMapper.linkToDomain(link))
          .toList();

      return NoteMapper.toDomain(
        localNote,
        title: title,
        body: body,
        tags: tags,
        links: links,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to hydrate note for search',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      _captureRepositoryException(
        method: '_toDomainNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      rethrow;
    }
  }

  @override
  Future<void> createOrUpdateSavedSearch(domain.SavedSearch savedSearch) async {
    try {
      // Security: Verify user is authenticated
      final userId = _requireUserId(
        method: 'createOrUpdateSavedSearch',
        data: {'savedSearchId': savedSearch.id},
      );
      if (userId == null) {
        throw StateError(
          'Cannot create/update saved search without authenticated user',
        );
      }

      // Security: If updating, verify belongs to user
      if (savedSearch.id.isNotEmpty) {
        final existing =
            await (db.select(db.savedSearches)
                  ..where((s) => s.id.equals(savedSearch.id))
                  ..where((s) => s.userId.equals(userId)))
                .getSingleOrNull();

        if (existing == null) {
          final missingError = StateError(
            'Saved search not found or does not belong to user',
          );
          _logger.warning(
            'Saved search update attempted for non-existent entity',
            data: {'savedSearchId': savedSearch.id, 'userId': userId},
          );
          _captureRepositoryException(
            method: 'createOrUpdateSavedSearch',
            error: missingError,
            stackTrace: StackTrace.current,
            data: {'savedSearchId': savedSearch.id, 'userId': userId},
            level: SentryLevel.warning,
          );
          _auditAccess(
            'search.createOrUpdateSavedSearch',
            granted: false,
            reason: 'not_found',
          );
          throw missingError;
        }
      }

      final dbSearch = SavedSearchMapper.toInfrastructure(
        savedSearch,
      ).copyWith(userId: Value(userId));
      await db.upsertSavedSearch(dbSearch);
      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: savedSearch.id,
        kind: 'upsert_saved_search',
        payload: jsonEncode(dbSearch.toJson()),
      );
      _auditAccess(
        'search.createOrUpdateSavedSearch',
        granted: true,
        reason: 'savedSearchId=${savedSearch.id}',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to create or update saved search',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': savedSearch.id},
      );
      _captureRepositoryException(
        method: 'createOrUpdateSavedSearch',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': savedSearch.id},
      );
      _auditAccess(
        'search.createOrUpdateSavedSearch',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    try {
      // Security: Verify user is authenticated
      final userId = _requireUserId(
        method: 'deleteSavedSearch',
        data: {'savedSearchId': id},
      );
      if (userId == null) {
        throw StateError(
          'Cannot delete saved search without authenticated user',
        );
      }

      // Security: Verify saved search belongs to user
      final existing =
          await (db.select(db.savedSearches)
                ..where((s) => s.id.equals(id))
                ..where((s) => s.userId.equals(userId)))
              .getSingleOrNull();

      if (existing == null) {
        _logger.warning(
          'Saved search $id not found or does not belong to user $userId',
        );
        _auditAccess(
          'search.deleteSavedSearch',
          granted: false,
          reason: 'not_found',
        );
        _captureRepositoryException(
          method: 'deleteSavedSearch',
          error: StateError(
            'Saved search not found or does not belong to user',
          ),
          stackTrace: StackTrace.current,
          data: {'savedSearchId': id, 'userId': userId},
          level: SentryLevel.warning,
        );
        return;
      }

      await db.deleteSavedSearch(id);
      // Enqueue for sync
      await _enqueuePendingOp(entityId: id, kind: 'delete_saved_search');
      _auditAccess(
        'search.deleteSavedSearch',
        granted: true,
        reason: 'savedSearchId=$id',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to delete saved search',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _captureRepositoryException(
        method: 'deleteSavedSearch',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _auditAccess(
        'search.deleteSavedSearch',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.SavedSearch>> getSavedSearches() async {
    try {
      // Security: Only return user's saved searches
      final userId = _requireUserId(method: 'getSavedSearches');
      if (userId == null) {
        return const <domain.SavedSearch>[];
      }

      final dbSearches =
          await (db.select(db.savedSearches)
                ..where((s) => s.userId.equals(userId))
                ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
              .get();

      final searches = SavedSearchMapper.toDomainList(dbSearches);
      _auditAccess(
        'search.getSavedSearches',
        granted: true,
        reason: 'count=${searches.length}',
      );
      return searches;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load saved searches',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getSavedSearches',
        error: error,
        stackTrace: stackTrace,
      );
      _auditAccess(
        'search.getSavedSearches',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <domain.SavedSearch>[];
    }
  }

  @override
  Stream<List<domain.SavedSearch>> watchSavedSearches() {
    // Security: Only watch user's saved searches
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot watch saved searches without authenticated user');
      _auditAccess(
        'search.watchSavedSearches',
        granted: false,
        reason: 'missing_user',
      );
      return Stream.value(const <domain.SavedSearch>[]);
    }

    try {
      _auditAccess(
        'search.watchSavedSearches',
        granted: true,
        reason: 'stream_start',
      );
      return (db.select(db.savedSearches)
            ..where((s) => s.userId.equals(userId))
            ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
          .watch()
          .map((dbSearches) {
            try {
              return SavedSearchMapper.toDomainList(dbSearches);
            } catch (error, stackTrace) {
              _logger.error(
                'Failed to map saved searches stream',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              _captureRepositoryException(
                method: 'watchSavedSearches.map',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              _auditAccess(
                'search.watchSavedSearches',
                granted: false,
                reason: 'map_error=${error.runtimeType}',
              );
              return const <domain.SavedSearch>[];
            }
          });
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to watch saved searches',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'watchSavedSearches',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      _auditAccess(
        'search.watchSavedSearches',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return Stream.error(error, stackTrace);
    }
  }

  @override
  Future<void> toggleSavedSearchPin(String id) async {
    try {
      final userId = _requireUserId(
        method: 'toggleSavedSearchPin',
        data: {'savedSearchId': id},
      );
      if (userId == null) {
        return;
      }

      final existing =
          await (db.select(db.savedSearches)
                ..where((s) => s.id.equals(id))
                ..where((s) => s.userId.equals(userId)))
              .getSingleOrNull();
      if (existing == null) {
        _auditAccess(
          'search.toggleSavedSearchPin',
          granted: false,
          reason: 'not_found',
        );
        return;
      }

      await db.toggleSavedSearchPin(id);
      _auditAccess(
        'search.toggleSavedSearchPin',
        granted: true,
        reason: 'savedSearchId=$id',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle saved search pin',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _captureRepositoryException(
        method: 'toggleSavedSearchPin',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _auditAccess(
        'search.toggleSavedSearchPin',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> trackSavedSearchUsage(String id) async {
    try {
      final userId = _requireUserId(
        method: 'trackSavedSearchUsage',
        data: {'savedSearchId': id},
      );
      if (userId == null) {
        return;
      }

      final exists =
          await (db.select(db.savedSearches)
                ..where((s) => s.id.equals(id))
                ..where((s) => s.userId.equals(userId)))
              .getSingleOrNull();
      if (exists == null) {
        _auditAccess(
          'search.trackSavedSearchUsage',
          granted: false,
          reason: 'not_found',
        );
        return;
      }

      await db.updateSavedSearchUsage(id);
      _auditAccess(
        'search.trackSavedSearchUsage',
        granted: true,
        reason: 'savedSearchId=$id',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to track saved search usage',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _captureRepositoryException(
        method: 'trackSavedSearchUsage',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': id},
      );
      _auditAccess(
        'search.trackSavedSearchUsage',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> reorderSavedSearches(List<String> ids) async {
    try {
      final userId = _requireUserId(
        method: 'reorderSavedSearches',
        data: {'count': ids.length},
      );
      if (userId == null) {
        return;
      }

      final userSearches = await (db.select(
        db.savedSearches,
      )..where((s) => s.userId.equals(userId))).get();
      final userIds = userSearches.map((s) => s.id).toSet();
      if (!ids.every(userIds.contains)) {
        _auditAccess(
          'search.reorderSavedSearches',
          granted: false,
          reason: 'contains_foreign_ids',
        );
        throw StateError('Cannot reorder saved searches owned by another user');
      }

      await db.reorderSavedSearches(ids);
      _auditAccess(
        'search.reorderSavedSearches',
        granted: true,
        reason: 'count=${ids.length}',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to reorder saved searches',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchIds': ids},
      );
      _captureRepositoryException(
        method: 'reorderSavedSearches',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchCount': ids.length},
      );
      _auditAccess(
        'search.reorderSavedSearches',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> executeSavedSearch(
    domain.SavedSearch savedSearch,
  ) async {
    try {
      // Security: Verify user is authenticated
      final userId = _requireUserId(
        method: 'executeSavedSearch',
        data: {'savedSearchId': savedSearch.id},
      );
      if (userId == null) {
        return const <domain.Note>[];
      }

      // Convert domain SavedSearch to db SavedSearch
      final dbSearch = SavedSearchMapper.toInfrastructure(savedSearch);

      // Parse the saved search query
      final query = dbSearch.query;
      final searchType = dbSearch.searchType;

      // Parse parameters JSON if present
      Map<String, dynamic>? params;
      if (dbSearch.parameters != null) {
        try {
          params = jsonDecode(dbSearch.parameters!) as Map<String, dynamic>;
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to parse saved search parameters',
            error: error,
            stackTrace: stackTrace,
          );
          _captureRepositoryException(
            method: 'executeSavedSearch.parseParams',
            error: error,
            stackTrace: stackTrace,
            data: {'savedSearchId': savedSearch.id},
            level: SentryLevel.warning,
          );
        }
      }

      // Execute based on search type
      List<domain.Note> notes = const <domain.Note>[];
      switch (searchType) {
        case 'text':
          final results = await db.searchNotes(query, userId: userId);
          final userResults = results.where((n) => n.userId == userId).toList();
          notes = [];
          for (final ln in userResults) {
            notes.add(await _toDomainNote(ln));
          }
          break;
        case 'tags':
          final tags = (params?['tags'] as List?)?.cast<String>() ?? [];
          final results = await db.notesByTags(
            anyTags: tags,
            noneTags: const [],
            sort: const appdb.SortSpec(),
            userId: userId,
          );
          final userResults = results.where((n) => n.userId == userId).toList();
          notes = [];
          for (final ln in userResults) {
            notes.add(await _toDomainNote(ln));
          }
          break;
        case 'folder':
          final folderId = params?['folderId'] as String?;
          if (folderId == null || folderId.isEmpty) {
            final missingParameter = StateError(
              'Saved search missing folderId parameter',
            );
            _logger.warning('Saved search $query missing folderId parameter');
            _captureRepositoryException(
              method: 'executeSavedSearch',
              error: missingParameter,
              stackTrace: StackTrace.current,
              data: {'savedSearchId': savedSearch.id},
              level: SentryLevel.warning,
            );
            _auditAccess(
              'search.executeSavedSearch',
              granted: false,
              reason: 'missing_folder_param',
            );
            return const <domain.Note>[];
          }

          notes = await _folderRepository.getNotesInFolder(folderId);
          break;
        case 'advanced':
          final results = await _executeAdvancedSearch(params ?? {});
          final userResults = results.where((n) => n.userId == userId).toList();
          notes = [];
          for (final ln in userResults) {
            notes.add(await _toDomainNote(ln));
          }
          break;
        default:
          _logger.warning('Unknown search type: $searchType');
          _captureRepositoryException(
            method: 'executeSavedSearch',
            error: StateError('Unknown search type'),
            stackTrace: StackTrace.current,
            data: {'savedSearchId': savedSearch.id, 'searchType': searchType},
            level: SentryLevel.warning,
          );
          _auditAccess(
            'search.executeSavedSearch',
            granted: false,
            reason: 'unknown_type=$searchType',
          );
          return const <domain.Note>[];
      }

      if (userId.isNotEmpty) {
        notes = notes.where((note) => note.userId == userId).toList();
      }

      _auditAccess(
        'search.executeSavedSearch',
        granted: true,
        reason: 'type=$searchType count=${notes.length}',
      );
      return notes;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to execute saved search',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': savedSearch.id},
      );
      _captureRepositoryException(
        method: 'executeSavedSearch',
        error: error,
        stackTrace: stackTrace,
        data: {'savedSearchId': savedSearch.id},
      );
      _auditAccess(
        'search.executeSavedSearch',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <domain.Note>[];
    }
  }

  Future<List<appdb.LocalNote>> _executeAdvancedSearch(
    Map<String, dynamic> params,
  ) async {
    // This would implement complex search logic
    // For now, returning empty list
    _logger.debug('Executing advanced search with params: $params');
    return const <appdb.LocalNote>[];
  }
}
