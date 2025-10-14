import 'dart:async';
import 'dart:convert';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;
import 'package:uuid/uuid.dart';

/// Core notes repository implementation
class NotesCoreRepository implements INotesRepository {
  NotesCoreRepository({
    required this.db,
    required this.crypto,
    required this.api,
    required SupabaseClient client,
    required NoteIndexer indexer,
  })  : _supabase = client,
        _indexer = indexer,
        _logger = LoggerFactory.instance;

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseNoteApi api;
  final SupabaseClient _supabase;
  final NoteIndexer _indexer;
  final AppLogger _logger;
  final _uuid = const Uuid();

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
          scope.setTag('repository', 'NotesCoreRepository');
          scope.setTag('method', method);
          data?.forEach((key, value) => scope.setExtra(key, value));
        },
      ),
    );
  }

  Future<List<String>> _loadTags(String noteId) async {
    try {
      final tagRecords = await (db.select(db.noteTags)
            ..where((t) => t.noteId.equals(noteId)))
          .get();
      return tagRecords.map((t) => t.tag).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load tags for note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: '_loadTags',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      return const <String>[];
    }
  }

  Future<List<Map<String, String?>>> _loadDomainLinks(String noteId) async {
    try {
      final linkRecords = await (db.select(db.noteLinks)
            ..where((l) => l.sourceId.equals(noteId)))
          .get();
      return linkRecords.map(NoteMapper.linkToDomain).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load links for note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: '_loadDomainLinks',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      return const <Map<String, String?>>[];
    }
  }

  Future<domain.Note?> _hydrateDomainNote(LocalNote localNote) async {
    try {
      final tags = await _loadTags(localNote.id);
      final links = await _loadDomainLinks(localNote.id);
      return NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: links,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to hydrate local note to domain',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      _captureRepositoryException(
        method: '_hydrateDomainNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      return null;
    }
  }

  Future<List<domain.Note>> _hydrateDomainNotes(List<LocalNote> localNotes) async {
    final List<domain.Note> notes = [];
    for (final localNote in localNotes) {
      final hydrated = await _hydrateDomainNote(localNote);
      if (hydrated != null) {
        notes.add(hydrated);
      }
    }
    return notes;
  }

  // Expose client for compatibility
  SupabaseClient get client => _supabase;

  @override
  Future<domain.Note?> getNoteById(String id) async {
    try {
      final localNote = await (db.select(db.localNotes)
            ..where((note) => note.id.equals(id)))
          .getSingleOrNull();

      if (localNote == null) {
        return null;
      }

      return await _hydrateDomainNote(localNote);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get note by id',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id},
      );
      _captureRepositoryException(
        method: 'getNoteById',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id},
      );
      return null;
    }
  }

  @override
  Future<domain.Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
  }) async {
    final noteId = id ?? _uuid.v4();
    try {
      final existingNote = await (db.select(db.localNotes)
            ..where((note) => note.id.equals(noteId)))
          .getSingleOrNull();

      final now = DateTime.now().toUtc();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError('Cannot create note without authenticated user');
        _logger.warning(
          'Cannot create note without authenticated user',
          data: {'noteId': noteId, 'hasIncomingId': id != null},
        );
        _captureRepositoryException(
          method: 'createOrUpdate',
          error: authorizationError,
          stackTrace: StackTrace.current,
          data: {'noteId': noteId, 'hasIncomingId': id != null},
          level: SentryLevel.warning,
        );
        return null;
      }

      await db.upsertNote(LocalNote(
        id: noteId,
        title: title,
        body: body,
        deleted: false,
        updatedAt: now,
        userId: userId,
        noteType: NoteKind.note,
        version: (existingNote?.version ?? 0) + 1,
        attachmentMeta: attachmentMeta != null
            ? jsonEncode(attachmentMeta)
            : existingNote?.attachmentMeta,
        metadata: metadataJson != null
            ? jsonEncode(metadataJson)
            : existingNote?.metadata,
        isPinned: isPinned ?? existingNote?.isPinned ?? false,
      ));

      // Update folder relationship if provided
      if (folderId != null) {
        await db.moveNoteToFolder(noteId, folderId);
      }

      // Update tags
      await db.replaceTagsForNote(noteId, tags.toSet());

      // Update links
      // TODO: Implement setLinksForNote method in AppDb or use existing method

      // Index the note - convert domain.Note back to LocalNote for indexer
      final noteToIndex = await getNoteById(noteId);
      if (noteToIndex != null) {
        final localNote = NoteMapper.toInfrastructure(noteToIndex);
        await _indexer.indexNote(localNote);
      }

      // Enqueue for sync
      await db.enqueue(noteId, 'upsert_note');

      return await getNoteById(noteId);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to create or update note',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': noteId,
          'hasIncomingId': id != null,
          'folderId': folderId,
          'tagCount': tags.length,
        },
      );
      _captureRepositoryException(
        method: 'createOrUpdate',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': noteId,
          'hasIncomingId': id != null,
          'folderId': folderId,
          'tagCount': tags.length,
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
  }) async {
    try {
      final existing = await (db.select(db.localNotes)
            ..where((note) => note.id.equals(id)))
          .getSingleOrNull();

      if (existing == null) {
        final missingError = StateError('Note not found');
        _logger.warning(
          'Attempted to update non-existent note',
          data: {'noteId': id},
        );
        _captureRepositoryException(
          method: 'updateLocalNote',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'noteId': id},
          level: SentryLevel.warning,
        );
        return;
      }

      await db.upsertNote(LocalNote(
        id: id,
        title: title ?? existing.title,
        body: body ?? existing.body,
        deleted: deleted ?? existing.deleted,
        updatedAt: DateTime.now().toUtc(),
        userId: existing.userId,
        noteType: existing.noteType,
        version: existing.version + 1,
        attachmentMeta: attachmentMeta != null
            ? jsonEncode(attachmentMeta)
            : existing.attachmentMeta,
        metadata: metadata != null
            ? jsonEncode(metadata)
            : existing.metadata,
        isPinned: isPinned ?? existing.isPinned,
      ));

      // Update folder relationship if provided
      if (folderId != null) {
        await db.moveNoteToFolder(id, folderId);
      }

      // Update links if provided
      // TODO: Implement setLinksForNote method in AppDb or use existing method

      // Re-index the note - convert domain.Note back to LocalNote for indexer
      final updated = await getNoteById(id);
      if (updated != null) {
        final localNote = NoteMapper.toInfrastructure(updated);
        await _indexer.indexNote(localNote);
      }

      // Enqueue for sync
      await db.enqueue(id, deleted == true ? 'delete' : 'upsert_note');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update local note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id, 'markedDeleted': deleted == true},
      );
      _captureRepositoryException(
        method: 'updateLocalNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id, 'markedDeleted': deleted == true},
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

  @override
  Future<List<domain.Note>> localNotes() async {
    try {
      final localNotes = await (db.select(db.localNotes)
            ..where((note) => note.deleted.equals(false))
            ..orderBy([
              (note) => OrderingTerm(
                    expression: note.isPinned,
                    mode: OrderingMode.desc,
                  ),
              (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
            ]))
          .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load local notes',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'localNotes',
        error: error,
        stackTrace: stackTrace,
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
    try {
      final localNotes = await (db.select(db.localNotes)
            ..where((note) => note.deleted.equals(false))
            ..orderBy([
              (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
            ])
            ..limit(limit))
          .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load recently viewed notes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      _captureRepositoryException(
        method: 'getRecentlyViewedNotes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<domain.Note>> listAfter(DateTime? cursor, {int limit = 20}) async {
    try {
      final query = db.select(db.localNotes)
        ..where((note) => note.deleted.equals(false));

      if (cursor != null) {
        query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
      }

      final localNotes = await (query
            ..orderBy([
              (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
            ])
            ..limit(limit))
          .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to list notes after cursor',
        error: error,
        stackTrace: stackTrace,
        data: {
          'cursor': cursor?.toIso8601String(),
          'limit': limit,
        },
      );
      _captureRepositoryException(
        method: 'listAfter',
        error: error,
        stackTrace: stackTrace,
        data: {
          'cursor': cursor?.toIso8601String(),
          'limit': limit,
        },
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<void> toggleNotePin(String noteId) async {
    try {
      await db.toggleNotePin(noteId);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle note pin state',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: 'toggleNotePin',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      rethrow;
    }
  }

  @override
  Future<void> setNotePin(String noteId, bool isPinned) async {
    try {
      await db.setNotePin(noteId, isPinned);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set note pin state',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'isPinned': isPinned},
      );
      _captureRepositoryException(
        method: 'setNotePin',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'isPinned': isPinned},
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> getPinnedNotes() async {
    try {
      final localNotes = await db.getPinnedNotes();
      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get pinned notes',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getPinnedNotes',
        error: error,
        stackTrace: stackTrace,
      );
      return const <domain.Note>[];
    }
  }

  @override
  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    // Build query with filters
    return (db.select(db.localNotes)
          ..where((n) => n.deleted.equals(false))
          ..orderBy([
            if (pinnedFirst)
              (n) => OrderingTerm(
                    expression: n.isPinned,
                    mode: OrderingMode.desc,
                  ),
            (n) => OrderingTerm(
                  expression: n.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch()
        .asyncMap((localNotes) async {
          try {
            return await _hydrateDomainNotes(localNotes);
          } catch (error, stackTrace) {
            _logger.error(
              'Failed to hydrate notes for watch stream',
              error: error,
              stackTrace: stackTrace,
              data: {
                'folderId': folderId,
                'anyTagsCount': anyTags?.length ?? 0,
                'noneTagsCount': noneTags?.length ?? 0,
                'pinnedFirst': pinnedFirst,
              },
            );
            _captureRepositoryException(
              method: 'watchNotes',
              error: error,
              stackTrace: stackTrace,
              data: {
                'folderId': folderId,
                'anyTagsCount': anyTags?.length ?? 0,
                'noneTagsCount': noneTags?.length ?? 0,
                'pinnedFirst': pinnedFirst,
              },
            );
            return const <domain.Note>[];
          }
        });
  }

  @override
  Future<List<domain.Note>> list({int? limit}) async {
    try {
      final query = db.select(db.localNotes)
        ..where((note) => note.deleted.equals(false))
        ..orderBy([
          (note) => OrderingTerm(
                expression: note.isPinned,
                mode: OrderingMode.desc,
              ),
          (note) => OrderingTerm(
                expression: note.updatedAt,
                mode: OrderingMode.desc,
              ),
        ]);

      if (limit != null) {
        query.limit(limit);
      }

      final localNotes = await query.get();
      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to list notes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      _captureRepositoryException(
        method: 'list',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<void> sync() async {
    await pushAllPending();
    final lastSync = await getLastSyncTime();
    await pullSince(lastSync);
  }

  @override
  Future<void> pushAllPending() async {
    // TODO(sync): Implement when sync infrastructure is ready
    // This requires database methods: getPendingSyncOperations, removeSyncOperation
    _logger.warning('pushAllPending not yet implemented - sync infrastructure pending');
  }

  @override
  Future<void> pullSince(DateTime? since) async {
    // TODO(sync): Implement when sync infrastructure is ready
    // This requires API method: getChangesSince
    _logger.warning('pullSince not yet implemented - sync infrastructure pending');
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    // TODO(sync): Implement when sync infrastructure is ready
    // This requires database method: getLastSyncTime
    return null;
  }
}
