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
import 'package:flutter/foundation.dart';
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

  // Expose client for compatibility
  SupabaseClient get client => _supabase;

  @override
  Future<domain.Note?> getNoteById(String id) async {
    final localNote = await (db.select(db.localNotes)
          ..where((note) => note.id.equals(id)))
        .getSingleOrNull();

    if (localNote == null) return null;

    // Get tags and links for the note
    final tags = await db.getTagsForNote(id);
    final links = await db.getLinksFromNote(id);

    // Map to domain entity
    return NoteMapper.toDomain(
      localNote,
      tags: tags,
      links: links.map((l) => NoteMapper.linkToDomain(l)).toList(),
    );
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
    final existingNote = await (db.select(db.localNotes)
          ..where((note) => note.id.equals(noteId)))
        .getSingleOrNull();

    final now = DateTime.now().toUtc();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot create note without authenticated user');
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
      conflictState: NoteConflictState.none,
      folderId: folderId,
      attachmentMeta: attachmentMeta != null
          ? jsonEncode(attachmentMeta)
          : existingNote?.attachmentMeta,
      metadata: metadataJson != null
          ? jsonEncode(metadataJson)
          : existingNote?.metadata,
      isPinned: isPinned ?? existingNote?.isPinned ?? false,
    ));

    // Update tags
    await db.replaceTagsForNote(noteId, tags.toSet());

    // Update links
    // TODO: Implement setLinksForNote method in AppDb or use existing method

    // Index the note
    final noteToIndex = await getNoteById(noteId);
    if (noteToIndex != null) {
      await _indexer.indexNote(noteToIndex);
    }

    // Enqueue for sync
    await db.enqueue(noteId, 'upsert_note');

    return await getNoteById(noteId);
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
    final existing = await (db.select(db.localNotes)
          ..where((note) => note.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) return;

    await db.upsertNote(LocalNote(
      id: id,
      title: title ?? existing.title,
      body: body ?? existing.body,
      deleted: deleted ?? existing.deleted,
      updatedAt: DateTime.now().toUtc(),
      userId: existing.userId,
      noteType: existing.noteType,
      version: existing.version + 1,
      conflictState: existing.conflictState,
      folderId: folderId ?? existing.folderId,
      attachmentMeta: attachmentMeta != null
          ? jsonEncode(attachmentMeta)
          : existing.attachmentMeta,
      metadata: metadata != null
          ? jsonEncode(metadata)
          : existing.metadata,
      isPinned: isPinned ?? existing.isPinned,
    ));

    // Update links if provided
    // TODO: Implement setLinksForNote method in AppDb or use existing method

    // Re-index the note
    final updated = await getNoteById(id);
    if (updated != null) {
      await _indexer.indexNote(updated);
    }

    // Enqueue for sync
    await db.enqueue(id, deleted == true ? 'delete' : 'upsert_note');
  }

  @override
  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

  @override
  Future<List<domain.Note>> localNotes() async {
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

    // Convert to domain entities with tags and links
    final List<domain.Note> domainNotes = [];
    for (final localNote in localNotes) {
      final tags = await db.getTagsForNote(localNote.id);
      final links = await db.getLinksFromNote(localNote.id);
      final domainLinks = links.map(NoteMapper.linkToDomain).toList();

      domainNotes.add(NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: domainLinks,
      ));
    }

    return domainNotes;
  }

  @override
  Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
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

    // Convert to domain entities with tags and links
    final List<domain.Note> domainNotes = [];
    for (final localNote in localNotes) {
      final tags = await db.getTagsForNote(localNote.id);
      final links = await db.getLinksFromNote(localNote.id);
      final domainLinks = links.map(NoteMapper.linkToDomain).toList();

      domainNotes.add(NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: domainLinks,
      ));
    }

    return domainNotes;
  }

  @override
  Future<List<domain.Note>> listAfter(DateTime? cursor, {int limit = 20}) async {
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

    // Convert to domain entities with tags and links
    final List<domain.Note> domainNotes = [];
    for (final localNote in localNotes) {
      final tags = await db.getTagsForNote(localNote.id);
      final links = await db.getLinksFromNote(localNote.id);
      final domainLinks = links.map(NoteMapper.linkToDomain).toList();

      domainNotes.add(NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: domainLinks,
      ));
    }

    return domainNotes;
  }

  @override
  Future<void> toggleNotePin(String noteId) => db.toggleNotePin(noteId);

  @override
  Future<void> setNotePin(String noteId, bool isPinned) =>
      db.setNotePin(noteId, isPinned);

  @override
  Future<List<domain.Note>> getPinnedNotes() async {
    final localNotes = await db.getPinnedNotes();

    // Convert to domain entities with tags and links
    final List<domain.Note> domainNotes = [];
    for (final localNote in localNotes) {
      final tags = await db.getTagsForNote(localNote.id);
      final links = await db.getLinksFromNote(localNote.id);
      final domainLinks = links.map(NoteMapper.linkToDomain).toList();

      domainNotes.add(NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: domainLinks,
      ));
    }

    return domainNotes;
  }

  @override
  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    return db.watchNotesWithFilters(
      folderId: folderId,
      anyTags: anyTags,
      noneTags: noneTags,
      pinnedFirst: pinnedFirst,
    ).asyncMap((localNotes) async {
      // Convert to domain entities with tags and links
      final List<domain.Note> domainNotes = [];
      for (final localNote in localNotes) {
        final tags = await db.getTagsForNote(localNote.id);
        final links = await db.getLinksFromNote(localNote.id);
        final domainLinks = links.map(NoteMapper.linkToDomain).toList();

        domainNotes.add(NoteMapper.toDomain(
          localNote,
          tags: tags,
          links: domainLinks,
        ));
      }
      return domainNotes;
    });
  }

  @override
  Future<List<domain.Note>> list({int? limit}) async {
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

    // Convert to domain entities with tags and links
    final List<domain.Note> domainNotes = [];
    for (final localNote in localNotes) {
      final tags = await db.getTagsForNote(localNote.id);
      final links = await db.getLinksFromNote(localNote.id);
      final domainLinks = links.map(NoteMapper.linkToDomain).toList();

      domainNotes.add(NoteMapper.toDomain(
        localNote,
        tags: tags,
        links: domainLinks,
      ));
    }

    return domainNotes;
  }

  @override
  Future<void> sync() async {
    await pushAllPending();
    final lastSync = await getLastSyncTime();
    await pullSince(lastSync);
  }

  @override
  Future<void> pushAllPending() async {
    try {
      _logger.info('Starting push of all pending changes');

      // Get all pending sync operations
      final pendingOperations = await db.getPendingSyncOperations();

      for (final operation in pendingOperations) {
        try {
          switch (operation.operation) {
            case 'upsert_note':
              final note = await getNoteById(operation.entityId);
              if (note != null) {
                await api.upsertNote(note);
                await db.removeSyncOperation(operation.id);
              }
              break;
            case 'delete':
              await api.deleteNote(operation.entityId);
              await db.removeSyncOperation(operation.id);
              break;
          }
        } catch (e) {
          _logger.error('Failed to push operation ${operation.id}', e);
        }
      }

      _logger.info('Completed pushing pending changes');
    } catch (e, stack) {
      _logger.error('Failed to push pending changes', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> pullSince(DateTime? since) async {
    try {
      _logger.info('Starting pull of changes since $since');

      final remoteChanges = await api.getChangesSince(since);

      for (final change in remoteChanges) {
        try {
          if (change.deleted) {
            await updateLocalNote(change.id, deleted: true);
          } else {
            // Convert remote note to local and upsert
            await createOrUpdate(
              id: change.id,
              title: change.title,
              body: change.body,
              folderId: change.folderId,
              tags: change.tags ?? [],
              isPinned: change.isPinned,
            );
          }
        } catch (e) {
          _logger.error('Failed to apply change ${change.id}', e);
        }
      }

      // Update last sync time
      await db.setLastSyncTime(DateTime.now().toUtc());

      _logger.info('Completed pulling changes');
    } catch (e, stack) {
      _logger.error('Failed to pull changes', e, stack);
      rethrow;
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    try {
      return await db.getLastSyncTime();
    } catch (e) {
      _logger.error('Failed to get last sync time', e);
      return null;
    }
  }
}