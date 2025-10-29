import 'dart:async';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/helpers/note_decryption_helper.dart';
import 'package:duru_notes/domain/entities/tag.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Tag repository implementation
class TagRepository implements ITagRepository {
  TagRepository({
    required this.db,
    required this.client,
    required CryptoBox crypto,
  }) : _logger = LoggerFactory.instance,
       _decryptHelper = NoteDecryptionHelper(crypto);

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final NoteDecryptionHelper _decryptHelper;
  final SecurityAuditTrail _auditTrail = SecurityAuditTrail();

  String? get _currentUserId => client.auth.currentUser?.id;

  Future<void> _enqueueNoteSync(String noteId) async {
    final userId = _currentUserId;
    if (userId == null) {
      _logger.warning(
        'Skipping note enqueue - no authenticated user',
        data: {'noteId': noteId},
      );
      return;
    }

    await db.enqueue(userId: userId, entityId: noteId, kind: 'upsert_note');
  }

  Future<bool> _noteOwnedByUser(String noteId, String userId) async {
    final existing =
        await (db.select(db.localNotes)
              ..where((n) => n.id.equals(noteId))
              ..where((n) => n.userId.equals(userId)))
            .getSingleOrNull();
    return existing != null;
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
          scope.setTag('repository', 'TagRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  @override
  Future<List<domain.TagWithCount>> listTagsWithCounts() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError(
          'Cannot get tags without authenticated user',
        );
        _logger.warning('Cannot get tags without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.listTagsWithCounts',
          granted: false,
          reason: 'missing_user',
        );
        _captureRepositoryException(
          method: 'listTagsWithCounts',
          error: authorizationError,
          stackTrace: StackTrace.current,
          level: SentryLevel.warning,
        );
        return const <domain.TagWithCount>[];
      }

      final tagCounts = await db.getTagsWithCounts(userId: userId);
      if (tagCounts.isEmpty) {
        await _auditTrail.logAccess(
          resource: 'tag.listTagsWithCounts',
          granted: true,
          reason: 'results=0',
        );
        return const <domain.TagWithCount>[];
      }

      final results = tagCounts
          .map(
            (entry) => domain.TagWithCount(
              tag: entry.tag,
              noteCount: entry.count,
            ),
          )
          .toList();

      results.sort((a, b) => b.noteCount.compareTo(a.noteCount));
      await _auditTrail.logAccess(
        resource: 'tag.listTagsWithCounts',
        granted: true,
        reason: 'results=${results.length}',
      );
      return results;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to list tags with counts',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'listTagsWithCounts',
        error: error,
        stackTrace: stackTrace,
      );
      await _auditTrail.logAccess(
        resource: 'tag.listTagsWithCounts',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <domain.TagWithCount>[];
    }
  }

  @override
  Future<void> addTag({required String noteId, required String tag}) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot add tag without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.addTag',
          granted: false,
          reason: 'missing_user',
        );
        return;
      }
      if (!await _noteOwnedByUser(noteId, userId)) {
        _logger.warning(
          'Skipping addTag - note not owned by current user',
          data: {'noteId': noteId, 'tag': tag},
        );
        await _auditTrail.logAccess(
          resource: 'tag.addTag',
          granted: false,
          reason: 'note_not_owned',
        );
        return;
      }

      final currentTags = await getTagsForNote(noteId);
      if (!currentTags.contains(tag)) {
        currentTags.add(tag);
        await db.replaceTagsForNote(noteId, currentTags.toSet());
        await _enqueueNoteSync(noteId);
      }
      await _auditTrail.logAccess(
        resource: 'tag.addTag',
        granted: true,
        reason: 'noteId=$noteId',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to add tag to note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'tag': tag},
      );
      _captureRepositoryException(
        method: 'addTag',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'tag': tag},
      );
      await _auditTrail.logAccess(
        resource: 'tag.addTag',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeTag({required String noteId, required String tag}) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot remove tag without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.removeTag',
          granted: false,
          reason: 'missing_user',
        );
        return;
      }
      if (!await _noteOwnedByUser(noteId, userId)) {
        _logger.warning(
          'Skipping removeTag - note not owned by current user',
          data: {'noteId': noteId, 'tag': tag},
        );
        await _auditTrail.logAccess(
          resource: 'tag.removeTag',
          granted: false,
          reason: 'note_not_owned',
        );
        return;
      }

      final currentTags = await getTagsForNote(noteId);
      if (currentTags.contains(tag)) {
        currentTags.remove(tag);
        await db.replaceTagsForNote(noteId, currentTags.toSet());
        await _enqueueNoteSync(noteId);
      }
      await _auditTrail.logAccess(
        resource: 'tag.removeTag',
        granted: true,
        reason: 'noteId=$noteId',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to remove tag from note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'tag': tag},
      );
      _captureRepositoryException(
        method: 'removeTag',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'tag': tag},
      );
      await _auditTrail.logAccess(
        resource: 'tag.removeTag',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<int> renameTagEverywhere({
    required String oldTag,
    required String newTag,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot rename tags without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.renameTagEverywhere',
          granted: false,
          reason: 'missing_user',
        );
        return 0;
      }

      final affectedNotes = await queryNotesByTags(anyTags: [oldTag]);
      var count = 0;

      for (final note in affectedNotes) {
        final tags = await getTagsForNote(note.id);
        if (tags.contains(oldTag)) {
          tags.remove(oldTag);
          if (!tags.contains(newTag)) {
            tags.add(newTag);
          }
          await db.replaceTagsForNote(note.id, tags.toSet());
          await _enqueueNoteSync(note.id);
          count++;
        }
      }

      _logger.info('Renamed tag "$oldTag" to "$newTag" in $count notes');
      await _auditTrail.logAccess(
        resource: 'tag.renameTagEverywhere',
        granted: true,
        reason: 'renamed=$count',
      );
      return count;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to rename tag',
        error: error,
        stackTrace: stackTrace,
        data: {'oldTag': oldTag, 'newTag': newTag},
      );
      _captureRepositoryException(
        method: 'renameTagEverywhere',
        error: error,
        stackTrace: stackTrace,
        data: {'oldTag': oldTag, 'newTag': newTag},
      );
      await _auditTrail.logAccess(
        resource: 'tag.renameTagEverywhere',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> queryNotesByTags({
    List<String> anyTags = const [],
    List<String> allTags = const [],
    List<String> noneTags = const [],
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError(
          'Cannot query notes by tags without authenticated user',
        );
        _logger.warning(
          'Cannot query notes by tags without authenticated user',
        );
        await _auditTrail.logAccess(
          resource: 'tag.queryNotesByTags',
          granted: false,
          reason: 'missing_user',
        );
        _captureRepositoryException(
          method: 'queryNotesByTags',
          error: authorizationError,
          stackTrace: StackTrace.current,
          level: SentryLevel.warning,
        );
        return const <domain.Note>[];
      }

      final allNotes = await db.notesByTags(
        anyTags: anyTags,
        noneTags: noneTags,
        sort: const SortSpec(),
        userId: userId,
      );

      final List<domain.Note> domainNotes = [];
      for (final localNote in allNotes) {
        final title = await _decryptHelper.decryptTitle(localNote);
        final body = await _decryptHelper.decryptBody(localNote);

        domainNotes.add(
          NoteMapper.toDomain(localNote, title: title, body: body),
        );
      }

      await _auditTrail.logAccess(
        resource: 'tag.queryNotesByTags',
        granted: true,
        reason: 'result=${domainNotes.length}',
      );
      return domainNotes;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to query notes by tags',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'queryNotesByTags',
        error: error,
        stackTrace: stackTrace,
        data: {
          'anyTagsCount': anyTags.length,
          'allTagsCount': allTags.length,
          'noneTagsCount': noneTags.length,
        },
      );
      await _auditTrail.logAccess(
        resource: 'tag.queryNotesByTags',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<String>> searchTags(String prefix) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot search tags without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.searchTags',
          granted: false,
          reason: 'missing_user',
        );
        return const <String>[];
      }
      final results = await db.searchTags(prefix, userId: userId);
      await _auditTrail.logAccess(
        resource: 'tag.searchTags',
        granted: true,
        reason: 'result=${results.length}',
      );
      return results;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to search tags',
        error: error,
        stackTrace: stackTrace,
        data: {'prefixLength': prefix.length},
      );
      _captureRepositoryException(
        method: 'searchTags',
        error: error,
        stackTrace: stackTrace,
        data: {'prefixLength': prefix.length},
      );
      await _auditTrail.logAccess(
        resource: 'tag.searchTags',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <String>[];
    }
  }

  @override
  Future<List<String>> getTagsForNote(String noteId) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot fetch tags without authenticated user');
        await _auditTrail.logAccess(
          resource: 'tag.getTagsForNote',
          granted: false,
          reason: 'missing_user',
        );
        return const <String>[];
      }

      final tags =
          await (db.select(db.noteTags)
                ..where((t) => t.noteId.equals(noteId))
                ..where((t) => t.userId.equals(userId)))
              .get();

      final results = tags.map((t) => t.tag).toList();
      await _auditTrail.logAccess(
        resource: 'tag.getTagsForNote',
        granted: true,
        reason: 'noteId=$noteId',
      );
      return results;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get tags for note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: 'getTagsForNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      await _auditTrail.logAccess(
        resource: 'tag.getTagsForNote',
        granted: false,
        reason: 'error=${error.runtimeType}',
      );
      return const <String>[];
    }
  }
}
