import 'dart:async';
import 'package:drift/drift.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/cache/batch_loader.dart';
import 'package:duru_notes/infrastructure/cache/decryption_cache.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Core folder repository implementation with performance optimizations
class FolderCoreRepository implements IFolderRepository {
  FolderCoreRepository({
    required this.db,
    required this.client,
    required CryptoBox crypto,
    DecryptionCache? decryptionCache,
    String? Function()? userIdResolver,
  }) : _logger = LoggerFactory.instance,
       _decryptionCache = decryptionCache ?? DecryptionCache(crypto),
       _userIdResolver = userIdResolver;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final DecryptionCache _decryptionCache;
  final _uuid = const Uuid();
  final String? Function()? _userIdResolver;
  final SecurityAuditTrail _securityAuditTrail = SecurityAuditTrail();

  String? _currentUserId() =>
      _userIdResolver?.call() ?? client.auth.currentUser?.id;

  Future<void> _enqueuePendingOp({
    required String entityId,
    required String kind,
    String? payload,
  }) async {
    final userId = _currentUserId();
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
          scope.setTag('repository', 'FolderCoreRepository');
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
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      _logger.warning(
        'folders.$method called without authenticated user',
        data: data,
      );
      _captureRepositoryException(
        method: method,
        error: StateError('Unauthenticated access'),
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      _auditAccess('folders.$method', granted: false, reason: 'missing_user');
      return null;
    }
    return userId;
  }

  @override
  Future<domain.Folder?> getFolder(String id) async {
    try {
      final userId = _requireUserId(
        method: 'getFolder',
        data: {'folderId': id},
      );
      if (userId == null) {
        return null;
      }

      final localFolder =
          await (db.select(db.localFolders)
                ..where((f) => f.id.equals(id))
                ..where((f) => f.userId.equals(userId)))
              .getSingleOrNull();

      if (localFolder == null) {
        _auditAccess('folders.getFolder', granted: false, reason: 'not_found');
        return null;
      }

      final folder = FolderMapper.toDomain(localFolder);
      _auditAccess('folders.getFolder', granted: true, reason: 'folderId=$id');

      return folder;
    } catch (e, stack) {
      _logger.error(
        'Failed to get folder by id: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': id},
      );
      _auditAccess(
        'folders.getFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return null;
    }
  }

  @override
  Future<List<domain.Folder>> listFolders() async {
    try {
      final userId = _requireUserId(method: 'listFolders');
      if (userId == null) {
        return const <domain.Folder>[];
      }

      final localFolders =
          await (db.select(db.localFolders)
                ..where((f) => f.userId.equals(userId))
                ..where((f) => f.deleted.equals(false))
                ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]))
              .get();

      final folders = FolderMapper.toDomainList(localFolders);
      _auditAccess(
        'folders.listFolders',
        granted: true,
        reason: 'count=${folders.length}',
      );
      return folders;
    } catch (e, stack) {
      _logger.error('Failed to list all folders', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'listFolders',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'folders.listFolders',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Folder>[];
    }
  }

  @override
  Future<List<domain.Folder>> getRootFolders() async {
    try {
      final userId = _requireUserId(method: 'getRootFolders');
      if (userId == null) {
        return const <domain.Folder>[];
      }

      final localFolders =
          await (db.select(db.localFolders)
                ..where((f) => f.userId.equals(userId))
                ..where((f) => f.deleted.equals(false))
                ..where((f) => f.parentId.isNull())
                ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]))
              .get();

      final folders = FolderMapper.toDomainList(localFolders);
      _auditAccess(
        'folders.getRootFolders',
        granted: true,
        reason: 'count=${folders.length}',
      );
      return folders;
    } catch (e, stack) {
      _logger.error('Failed to get root folders', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getRootFolders',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'folders.getRootFolders',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Folder>[];
    }
  }

  @override
  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();
      final userId = _requireUserId(
        method: 'createFolder',
        data: {'name': name, 'parentId': parentId},
      );
      if (userId == null) {
        throw StateError('Cannot create folder without authenticated user');
      }

      final localFolder = LocalFolder(
        id: id,
        userId: userId, // Security: Set folder owner
        name: name,
        parentId: parentId,
        path: parentId != null ? '' : '/$name', // Will be updated by trigger
        color: color ?? '#048ABF',
        icon: icon ?? 'folder',
        description: description ?? '',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        deleted: false,
      );

      await db.upsertFolder(localFolder);

      // Enqueue for sync
      await _enqueuePendingOp(entityId: id, kind: 'upsert_folder');

      final domainFolder = FolderMapper.toDomain(localFolder);
      _auditAccess(
        'folders.createFolder',
        granted: true,
        reason: 'folderId=$id',
      );
      return domainFolder;
    } catch (e, stack) {
      _logger.error(
        'Failed to create folder: $name',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createFolder',
        error: e,
        stackTrace: stack,
        data: {'name': name, 'parentId': parentId},
      );
      _auditAccess(
        'folders.createFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    try {
      final folderId = id ?? _uuid.v4();
      final isUpdate = id != null;
      final userId = _requireUserId(
        method: 'createOrUpdateFolder',
        data: {'folderId': folderId, 'name': name},
      );
      if (userId == null) {
        throw StateError(
          'Cannot create/update folder without authenticated user',
        );
      }

      // Security: If updating, verify folder belongs to user
      final existingFolder = id != null
          ? await (db.select(db.localFolders)
                  ..where((f) => f.id.equals(folderId))
                  ..where((f) => f.userId.equals(userId)))
                .getSingleOrNull()
          : null;

      if (id != null && existingFolder == null) {
        final missingError = StateError(
          'Folder not found or does not belong to user',
        );
        _logger.warning(
          'Folder not found or does not belong to user during update',
          data: {'folderId': folderId, 'userId': userId},
        );
        _captureRepositoryException(
          method: 'createOrUpdateFolder',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'folderId': folderId, 'userId': userId},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final now = DateTime.now().toUtc();

      final localFolder = LocalFolder(
        id: folderId,
        userId: userId, // Security: Set folder owner
        name: name,
        parentId: parentId,
        path:
            existingFolder?.path ??
            (parentId != null ? '' : '/$name'), // Will be updated by trigger
        color: color ?? existingFolder?.color ?? '#048ABF',
        icon: icon ?? existingFolder?.icon ?? 'folder',
        description: description ?? existingFolder?.description ?? '',
        sortOrder: sortOrder ?? existingFolder?.sortOrder ?? 0,
        createdAt: existingFolder?.createdAt ?? now,
        updatedAt: now,
        deleted: existingFolder?.deleted ?? false,
      );

      await db.upsertFolder(localFolder);

      // Enqueue for sync
      await _enqueuePendingOp(entityId: folderId, kind: 'upsert_folder');

      _auditAccess(
        'folders.createOrUpdateFolder',
        granted: true,
        reason: 'folderId=$folderId isUpdate=$isUpdate',
      );
      return folderId;
    } catch (e, stack) {
      _logger.error(
        'Failed to create/update folder: $name',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createOrUpdateFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': id, 'name': name},
      );
      _auditAccess(
        'folders.createOrUpdateFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> renameFolder(String folderId, String newName) async {
    try {
      final userId = _requireUserId(
        method: 'renameFolder',
        data: {'folderId': folderId, 'newName': newName},
      );
      if (userId == null) {
        throw StateError('Cannot rename folder without authenticated user');
      }

      final existingFolder =
          await (db.select(db.localFolders)
                ..where((f) => f.id.equals(folderId))
                ..where((f) => f.userId.equals(userId)))
              .getSingleOrNull();

      if (existingFolder == null) {
        final missingError = StateError(
          'Folder not found or does not belong to user',
        );
        _logger.warning(
          'Folder rename attempted on non-existent folder',
          data: {'folderId': folderId, 'userId': userId},
        );
        _captureRepositoryException(
          method: 'renameFolder',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'folderId': folderId, 'userId': userId},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final updatedFolder = LocalFolder(
        id: existingFolder.id,
        userId: existingFolder.userId, // Preserve owner
        name: newName,
        parentId: existingFolder.parentId,
        path: existingFolder.path, // Will be updated by trigger
        color: existingFolder.color,
        icon: existingFolder.icon,
        description: existingFolder.description,
        sortOrder: existingFolder.sortOrder,
        createdAt: existingFolder.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deleted: existingFolder.deleted,
      );

      await db.upsertFolder(updatedFolder);

      // Enqueue for sync
      await _enqueuePendingOp(entityId: folderId, kind: 'upsert_folder');
      _auditAccess(
        'folders.renameFolder',
        granted: true,
        reason: 'folderId=$folderId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to rename folder: $folderId to $newName',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'renameFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId, 'newName': newName},
      );
      _auditAccess(
        'folders.renameFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> moveFolder(String folderId, String? newParentId) async {
    try {
      final userId = _requireUserId(
        method: 'moveFolder',
        data: {'folderId': folderId, 'newParentId': newParentId},
      );
      if (userId == null) {
        throw StateError('Cannot move folder without authenticated user');
      }

      final existingFolder =
          await (db.select(db.localFolders)
                ..where((f) => f.id.equals(folderId))
                ..where((f) => f.userId.equals(userId)))
              .getSingleOrNull();

      if (existingFolder == null) {
        final missingError = StateError(
          'Folder not found or does not belong to user',
        );
        _logger.warning(
          'Folder move attempted on non-existent folder',
          data: {'folderId': folderId, 'userId': userId},
        );
        _captureRepositoryException(
          method: 'moveFolder',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'folderId': folderId, 'userId': userId},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      // Validate that we're not creating a circular reference
      if (newParentId != null &&
          await _wouldCreateCircularReference(folderId, newParentId)) {
        final cycleError = StateError(
          'Moving folder would create circular reference',
        );
        _logger.warning(
          'Prevented circular folder move',
          data: {'folderId': folderId, 'targetParentId': newParentId},
        );
        _captureRepositoryException(
          method: 'moveFolder',
          error: cycleError,
          stackTrace: StackTrace.current,
          data: {'folderId': folderId, 'targetParentId': newParentId},
          level: SentryLevel.warning,
        );
        throw cycleError;
      }

      final updatedFolder = LocalFolder(
        id: existingFolder.id,
        userId: existingFolder.userId, // Preserve owner
        name: existingFolder.name,
        parentId: newParentId,
        path: existingFolder.path, // Will be updated by trigger
        color: existingFolder.color,
        icon: existingFolder.icon,
        description: existingFolder.description,
        sortOrder: existingFolder.sortOrder,
        createdAt: existingFolder.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deleted: existingFolder.deleted,
      );

      await db.upsertFolder(updatedFolder);

      // Enqueue for sync
      await _enqueuePendingOp(entityId: folderId, kind: 'upsert_folder');
      _auditAccess(
        'folders.moveFolder',
        granted: true,
        reason: 'folderId=$folderId target=$newParentId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to move folder: $folderId to parent $newParentId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'moveFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId, 'newParentId': newParentId},
      );
      _auditAccess(
        'folders.moveFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    try {
      final userId = _requireUserId(
        method: 'deleteFolder',
        data: {'folderId': folderId},
      );
      if (userId == null) {
        throw StateError('Cannot delete folder without authenticated user');
      }

      final folderExistsForUser =
          await (db.select(db.localFolders)
                ..where((f) => f.id.equals(folderId))
                ..where((f) => f.userId.equals(userId)))
              .getSingleOrNull();
      if (folderExistsForUser == null) {
        _auditAccess(
          'folders.deleteFolder',
          granted: false,
          reason: 'not_found',
        );
        throw StateError('Folder not found or does not belong to user');
      }

      // First, move all notes in this folder to unfiled
      await _moveNotesToUnfiled(folderId, userId);

      // Move all child folders to parent or root
      final childFolders = await db.getChildFolders(folderId);
      final parentFolder = await db.getFolderById(folderId);
      final newParentId = parentFolder?.parentId;

      for (final child in childFolders) {
        await moveFolder(child.id, newParentId);
      }

      // Now delete the folder itself
      await db.transaction(() async {
        // Remove folder-note relationships
        await db.removeNoteFromFolder(folderId);

        // Delete the folder
        await (db.delete(
          db.localFolders,
        )..where((f) => f.id.equals(folderId))).go();
      });

      // Enqueue for sync deletion
      await _enqueuePendingOp(entityId: folderId, kind: 'delete_folder');
      _auditAccess(
        'folders.deleteFolder',
        granted: true,
        reason: 'folderId=$folderId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to delete folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'deleteFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      _auditAccess(
        'folders.deleteFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> getNotesInFolder(String folderId) async {
    try {
      final userId = _requireUserId(
        method: 'getNotesInFolder',
        data: {'folderId': folderId},
      );
      if (userId == null) {
        return const <domain.Note>[];
      }

      // Verify folder belongs to user
      final folder =
          await (db.select(db.localFolders)
                ..where((f) => f.id.equals(folderId))
                ..where((f) => f.userId.equals(userId)))
              .getSingleOrNull();

      if (folder == null) {
        _logger.warning(
          'Folder $folderId not found or does not belong to user $userId',
        );
        _auditAccess(
          'folders.getNotesInFolder',
          granted: false,
          reason: 'not_found',
        );
        return const <domain.Note>[];
      }

      final localNotes = await db.getNotesInFolder(folderId);
      if (localNotes.isEmpty) {
        _auditAccess(
          'folders.getNotesInFolder',
          granted: true,
          reason: 'count=0',
        );
        return const <domain.Note>[];
      }

      // Additional security: Filter notes by userId (defense in depth)
      final userNotes = localNotes.where((n) => n.userId == userId).toList();
      if (userNotes.isEmpty) {
        _auditAccess(
          'folders.getNotesInFolder',
          granted: true,
          reason: 'count=0',
        );
        return const <domain.Note>[];
      }

      final noteIds = userNotes.map((n) => n.id).toList();

      // Batch load related data in parallel (3 queries total)
      final results = await Future.wait([
        BatchLoader.loadTagsForNotes(db, noteIds),
        BatchLoader.loadLinksForNotes(db, noteIds),
        _decryptionCache.decryptNotesBatch(userNotes),
      ]);

      final tagsByNote = results[0] as Map<String, List<String>>;
      final linksByNote = results[1] as Map<String, List<NoteLink>>;
      final decryptedContent = results[2] as Map<String, DecryptedContent>;

      // Convert to domain entities
      final notes = userNotes.map((localNote) {
        final content = decryptedContent[localNote.id];
        final tags = tagsByNote[localNote.id] ?? [];
        final links = linksByNote[localNote.id] ?? [];

        return NoteMapper.toDomain(
          localNote,
          title: content?.title ?? '',
          body: content?.body ?? '',
          tags: tags,
          links: links.map(NoteMapper.linkToDomain).toList(),
        );
      }).toList();

      _auditAccess(
        'folders.getNotesInFolder',
        granted: true,
        reason: 'count=${notes.length}',
      );
      return notes;
    } catch (e, stack) {
      _logger.error(
        'Failed to get notes in folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getNotesInFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      _auditAccess(
        'folders.getNotesInFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<domain.Note>> getUnfiledNotes() async {
    try {
      final userId = _requireUserId(method: 'getUnfiledNotes');
      if (userId == null) {
        return const <domain.Note>[];
      }

      // Get notes with no folder assignment using the NoteFolders junction table
      final noteIdsWithFolders =
          await (db.select(db.noteFolders).map((nf) => nf.noteId)).get();

      final localNotes =
          await (db.select(db.localNotes)..where(
                (note) =>
                    note.id.isNotIn(noteIdsWithFolders) &
                    note.deleted.equals(false) &
                    note.userId.equals(userId),
              )) // Security: Filter by userId
              .get();

      if (localNotes.isEmpty) {
        _auditAccess(
          'folders.getUnfiledNotes',
          granted: true,
          reason: 'count=0',
        );
        return const <domain.Note>[];
      }

      final noteIds = localNotes.map((n) => n.id).toList();

      // Batch load related data in parallel (3 queries total)
      final results = await Future.wait([
        BatchLoader.loadTagsForNotes(db, noteIds),
        BatchLoader.loadLinksForNotes(db, noteIds),
        _decryptionCache.decryptNotesBatch(localNotes),
      ]);

      final tagsByNote = results[0] as Map<String, List<String>>;
      final linksByNote = results[1] as Map<String, List<NoteLink>>;
      final decryptedContent = results[2] as Map<String, DecryptedContent>;

      // Convert to domain entities
      final notes = localNotes.map((localNote) {
        final content = decryptedContent[localNote.id];
        final tags = tagsByNote[localNote.id] ?? [];
        final links = linksByNote[localNote.id] ?? [];

        return NoteMapper.toDomain(
          localNote,
          title: content?.title ?? '',
          body: content?.body ?? '',
          tags: tags,
          links: links.map(NoteMapper.linkToDomain).toList(),
        );
      }).toList();
      _auditAccess(
        'folders.getUnfiledNotes',
        granted: true,
        reason: 'count=${notes.length}',
      );
      return notes;
    } catch (e, stack) {
      _logger.error('Failed to get unfiled notes', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getUnfiledNotes',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'folders.getUnfiledNotes',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    try {
      final userId = _requireUserId(
        method: 'addNoteToFolder',
        data: {'noteId': noteId, 'folderId': folderId},
      );
      if (userId == null) {
        return;
      }

      await db.moveNoteToFolder(noteId, folderId, expectedUserId: userId);

      // Enqueue note update for sync
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');
      _auditAccess(
        'folders.addNoteToFolder',
        granted: true,
        reason: 'noteId=$noteId folderId=$folderId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to add note $noteId to folder $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'addNoteToFolder',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId, 'folderId': folderId},
      );
      _auditAccess(
        'folders.addNoteToFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    try {
      final userId = _requireUserId(
        method: 'moveNoteToFolder',
        data: {'noteId': noteId, 'folderId': folderId},
      );
      if (userId == null) {
        return;
      }

      await db.moveNoteToFolder(noteId, folderId, expectedUserId: userId);

      // Enqueue note update for sync
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');
      _auditAccess(
        'folders.moveNoteToFolder',
        granted: true,
        reason: 'noteId=$noteId folderId=${folderId ?? 'null'}',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to move note $noteId to folder $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'moveNoteToFolder',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId, 'folderId': folderId},
      );
      _auditAccess(
        'folders.moveNoteToFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeNoteFromFolder(String noteId) async {
    try {
      final userId = _requireUserId(
        method: 'removeNoteFromFolder',
        data: {'noteId': noteId},
      );
      if (userId == null) {
        return;
      }

      await db.removeNoteFromFolder(noteId, expectedUserId: userId);

      // Enqueue note update for sync
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');
      _auditAccess(
        'folders.removeNoteFromFolder',
        granted: true,
        reason: 'noteId=$noteId',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to remove note $noteId from folder',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'removeNoteFromFolder',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      _auditAccess(
        'folders.removeNoteFromFolder',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getFolderNoteCounts() async {
    try {
      return await db.getFolderNoteCounts();
    } catch (e, stack) {
      _logger.error(
        'Failed to get folder note counts',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getFolderNoteCounts',
        error: e,
        stackTrace: stack,
      );
      return const <String, int>{};
    }
  }

  @override
  Future<domain.Folder?> getFolderForNote(String noteId) async {
    try {
      final localFolder = await db.getFolderForNote(noteId);
      if (localFolder == null) return null;

      return FolderMapper.toDomain(localFolder);
    } catch (e, stack) {
      _logger.error(
        'Failed to get folder for note: $noteId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getFolderForNote',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      return null;
    }
  }

  @override
  Future<List<domain.Folder>> getChildFolders(String parentId) async {
    try {
      final localFolders = await db.getChildFolders(parentId);
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error(
        'Failed to get child folders for: $parentId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getChildFolders',
        error: e,
        stackTrace: stack,
        data: {'parentId': parentId},
      );
      return const <domain.Folder>[];
    }
  }

  @override
  Future<List<domain.Folder>> getChildFoldersRecursive(String parentId) async {
    try {
      final localFolders = await db.getFolderSubtree(parentId);
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error(
        'Failed to get child folders recursively for: $parentId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getChildFoldersRecursive',
        error: e,
        stackTrace: stack,
        data: {'parentId': parentId},
      );
      return const <domain.Folder>[];
    }
  }

  @override
  Future<void> ensureFolderIntegrity() async {
    try {
      _logger.info('Starting folder integrity check');

      // Check for orphaned notes (notes referencing non-existent folders)
      await _fixOrphanedNotes();

      // Check for circular references in folder hierarchy
      await _fixCircularReferences();

      // Validate folder hierarchy depth
      await _validateFolderDepth();

      _logger.info('Folder integrity check completed');
    } catch (e, stack) {
      _logger.error(
        'Failed to ensure folder integrity',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'ensureFolderIntegrity',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() async {
    try {
      final results = <String, dynamic>{};

      // Count total folders
      final allFolders = await db.allFolders();
      results['total_folders'] = allFolders.length;

      // Count root folders
      final rootFolders = await db.getRootFolders();
      results['root_folders'] = rootFolders.length;

      // Check for orphaned notes
      final orphanedNotes = await _findOrphanedNotes();
      results['orphaned_notes'] = orphanedNotes.length;

      // Check for circular references
      final circularRefs = await _findCircularReferences();
      results['circular_references'] = circularRefs.length;

      // Check folder depths
      final maxDepth = await _calculateMaxFolderDepth();
      results['max_folder_depth'] = maxDepth;

      // Overall health score
      final healthScore = _calculateHealthScore(results);
      results['health_score'] = healthScore;
      results['status'] = healthScore >= 0.9
          ? 'healthy'
          : healthScore >= 0.7
          ? 'warning'
          : 'critical';

      results['timestamp'] = DateTime.now().toIso8601String();

      return results;
    } catch (e, stack) {
      _logger.error(
        'Failed to perform folder health check',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'performFolderHealthCheck',
        error: e,
        stackTrace: stack,
      );
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  @override
  Future<void> validateAndRepairFolderStructure() async {
    try {
      _logger.info('Starting folder structure validation and repair');

      // Fix orphaned notes
      await _fixOrphanedNotes();

      // Fix circular references
      await _fixCircularReferences();

      // Validate and fix folder depths
      await _validateFolderDepth();

      // Update folder note counts
      await _updateFolderNoteCounts();

      _logger.info('Folder structure validation and repair completed');
    } catch (e, stack) {
      _logger.error(
        'Failed to validate and repair folder structure',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'validateAndRepairFolderStructure',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> cleanupOrphanedRelationships() async {
    try {
      _logger.info('Starting cleanup of orphaned relationships');

      // Remove note-folder relationships where folder doesn't exist
      await db.transaction(() async {
        final orphanedRelations = await db.getAllNoteFolderRelationships();

        for (final relation in orphanedRelations) {
          final folderExists =
              await db.getFolderById(relation.folderId) != null;
          final noteExists =
              await (db.select(db.localNotes)
                    ..where((n) => n.id.equals(relation.noteId)))
                  .getSingleOrNull() !=
              null;

          if (!folderExists || !noteExists) {
            await (db.delete(db.noteFolders)..where(
                  (nf) =>
                      nf.noteId.equals(relation.noteId) &
                      nf.folderId.equals(relation.folderId),
                ))
                .go();
          }
        }
      });

      _logger.info('Cleanup of orphaned relationships completed');
    } catch (e, stack) {
      _logger.error(
        'Failed to cleanup orphaned relationships',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'cleanupOrphanedRelationships',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> resolveFolderConflicts() async {
    try {
      _logger.info('Starting folder conflict resolution');

      // Find and resolve duplicate folder names in same parent
      await _resolveDuplicateFolderNames();

      // Fix invalid parent references
      await _fixInvalidParentReferences();

      _logger.info('Folder conflict resolution completed');
    } catch (e, stack) {
      _logger.error(
        'Failed to resolve folder conflicts',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'resolveFolderConflicts',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // Private helper methods

  Future<bool> _wouldCreateCircularReference(
    String folderId,
    String parentId,
  ) async {
    String? currentParentId = parentId;

    while (currentParentId != null) {
      if (currentParentId == folderId) {
        return true;
      }
      final parentFolder = await db.getFolderById(currentParentId);
      currentParentId = parentFolder?.parentId;
    }

    return false;
  }

  Future<void> _moveNotesToUnfiled(String folderId, String userId) async {
    final noteIds = await db.getNoteIdsInFolder(folderId);

    for (final noteId in noteIds) {
      await db.moveNoteToFolder(noteId, null, expectedUserId: userId);
    }
  }

  Future<List<String>> _findOrphanedNotes() async {
    // Find notes with folder references that don't exist in the folders table
    final noteFolderRels = await db.select(db.noteFolders).get();

    final orphanedNotes = <String>[];

    for (final rel in noteFolderRels) {
      final folderExists = await db.getFolderById(rel.folderId) != null;
      if (!folderExists) {
        orphanedNotes.add(rel.noteId);
      }
    }

    return orphanedNotes;
  }

  Future<void> _fixOrphanedNotes() async {
    final orphanedNotes = await _findOrphanedNotes();

    for (final noteId in orphanedNotes) {
      final note = await db.findNote(noteId);
      await db.moveNoteToFolder(noteId, null, expectedUserId: note?.userId);
    }

    _logger.info('Fixed ${orphanedNotes.length} orphaned notes');
  }

  Future<List<String>> _findCircularReferences() async {
    final allFolders = await db.allFolders();
    final circularRefs = <String>[];

    for (final folder in allFolders) {
      if (folder.parentId != null &&
          await _wouldCreateCircularReference(folder.id, folder.parentId!)) {
        circularRefs.add(folder.id);
      }
    }

    return circularRefs;
  }

  Future<void> _fixCircularReferences() async {
    final circularRefs = await _findCircularReferences();

    for (final folderId in circularRefs) {
      await moveFolder(folderId, null); // Move to root
    }

    _logger.info('Fixed ${circularRefs.length} circular references');
  }

  Future<int> _calculateMaxFolderDepth() async {
    final allFolders = await db.allFolders();
    int maxDepth = 0;

    for (final folder in allFolders) {
      final depth = await db.getFolderDepth(folder.id);
      if (depth > maxDepth) {
        maxDepth = depth;
      }
    }

    return maxDepth;
  }

  Future<void> _validateFolderDepth() async {
    const maxAllowedDepth = 10;
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      final depth = await db.getFolderDepth(folder.id);
      if (depth > maxAllowedDepth) {
        // Move deeply nested folders to root
        await moveFolder(folder.id, null);
        _logger.warning('Moved deeply nested folder ${folder.name} to root');
      }
    }
  }

  Future<void> _updateFolderNoteCounts() async {
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      await db.getNotesCountInFolder(folder.id);
    }
  }

  Future<void> _resolveDuplicateFolderNames() async {
    final allFolders = await db.allFolders();
    final foldersByParent = <String?, List<LocalFolder>>{};

    // Group folders by parent
    for (final folder in allFolders) {
      foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
    }

    // Check for duplicates within each parent
    for (final parentId in foldersByParent.keys) {
      final folders = foldersByParent[parentId]!;
      final nameGroups = <String, List<LocalFolder>>{};

      for (final folder in folders) {
        nameGroups.putIfAbsent(folder.name, () => []).add(folder);
      }

      // Rename duplicates
      for (final name in nameGroups.keys) {
        final duplicates = nameGroups[name]!;
        if (duplicates.length > 1) {
          for (int i = 1; i < duplicates.length; i++) {
            final newName = '${duplicates[i].name} (${i + 1})';
            await renameFolder(duplicates[i].id, newName);
          }
        }
      }
    }
  }

  Future<void> _fixInvalidParentReferences() async {
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      if (folder.parentId != null) {
        final parentExists = await db.getFolderById(folder.parentId!) != null;
        if (!parentExists) {
          await moveFolder(folder.id, null); // Move to root
        }
      }
    }
  }

  double _calculateHealthScore(Map<String, dynamic> results) {
    double score = 1.0;

    // Penalize orphaned notes
    final orphanedNotes = results['orphaned_notes'] as int? ?? 0;
    score -= (orphanedNotes * 0.1).clamp(0.0, 0.3);

    // Penalize circular references
    final circularRefs = results['circular_references'] as int? ?? 0;
    score -= (circularRefs * 0.2).clamp(0.0, 0.5);

    // Penalize excessive depth
    final maxDepth = results['max_folder_depth'] as int? ?? 0;
    if (maxDepth > 10) {
      score -= 0.2;
    } else if (maxDepth > 7) {
      score -= 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  // ===== Legacy method aliases for backward compatibility =====

  /// Alias for getFolder() - returns LocalFolder for backward compatibility
  Future<LocalFolder?> getFolderById(String id) async {
    final folder = await getFolder(id);
    if (folder == null) return null;
    return FolderMapper.toInfrastructure(folder);
  }

  /// Alias for listFolders() - returns LocalFolders for backward compatibility
  Future<List<LocalFolder>> getAllFolders() async {
    final folders = await listFolders();
    return FolderMapper.toInfrastructureList(folders);
  }

  /// Alias for createFolder() - returns LocalFolder for backward compatibility
  Future<LocalFolder> createLocalFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final folder = await createFolder(
      name: name,
      parentId: parentId,
      color: color,
      icon: icon,
      description: description,
    );
    return FolderMapper.toInfrastructure(folder);
  }

  /// Alias for createOrUpdateFolder() - for backward compatibility
  Future<void> updateLocalFolder(LocalFolder folder) async {
    await createOrUpdateFolder(
      id: folder.id,
      name: folder.name,
      parentId: folder.parentId,
      color: folder.color,
      icon: folder.icon,
      description: folder.description,
    );
  }

  /// Alias for deleteFolder() - for backward compatibility
  Future<void> deleteLocalFolder(String folderId) async {
    await deleteFolder(folderId);
  }

  @override
  Future<domain.Folder?> findFolderByName(String name) async {
    try {
      final allFolders = await listFolders();
      return allFolders.where((f) => f.name == name).firstOrNull;
    } catch (e, stack) {
      _logger.error(
        'Failed to find folder by name: $name',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'findFolderByName',
        error: e,
        stackTrace: stack,
        data: {'name': name},
      );
      return null;
    }
  }

  @override
  Future<int> getFolderDepth(String folderId) async {
    try {
      return await db.getFolderDepth(folderId);
    } catch (e, stack) {
      _logger.error(
        'Failed to get folder depth for: $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getFolderDepth',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      return 0;
    }
  }

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) async {
    try {
      return await db.getNoteIdsInFolder(folderId);
    } catch (e, stack) {
      _logger.error(
        'Failed to get note IDs in folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getNoteIdsInFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      return const <String>[];
    }
  }

  @override
  Future<int> getNotesCountInFolder(String folderId) async {
    try {
      return await db.getNotesCountInFolder(folderId);
    } catch (e, stack) {
      _logger.error(
        'Failed to get notes count in folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getNotesCountInFolder',
        error: e,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      return 0;
    }
  }

  @override
  String? getCurrentUserId() {
    return _currentUserId();
  }
}
