import 'dart:async';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/helpers/note_decryption_helper.dart';
import 'package:duru_notes/domain/entities/tag.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
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
      // Security: Only return tags from user's notes
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError(
          'Cannot get tags without authenticated user',
        );
        _logger.warning('Cannot get tags without authenticated user');
        _captureRepositoryException(
          method: 'listTagsWithCounts',
          error: authorizationError,
          stackTrace: StackTrace.current,
          level: SentryLevel.warning,
        );
        return const <domain.TagWithCount>[];
      }

      // Get all note IDs for current user
      final userNotes =
          await (db.select(db.localNotes)
                ..where((n) => n.userId.equals(userId))
                ..where((n) => n.deleted.equals(false)))
              .get();

      if (userNotes.isEmpty) {
        return const <domain.TagWithCount>[];
      }

      final userNoteIds = userNotes.map((note) => note.id).toSet();

      // Get all tags and filter by user's notes
      final allTagCounts = await db.getTagsWithCounts();

      // Filter to only tags from user's notes by recounting
      final Map<String, int> userTagCounts = {};
      for (final tagCount in allTagCounts) {
        final notesWithTag = await (db.select(
          db.noteTags,
        )..where((t) => t.tag.equals(tagCount.tag))).get();

        final userNoteCount = notesWithTag
            .where((nt) => userNoteIds.contains(nt.noteId))
            .length;
        if (userNoteCount > 0) {
          userTagCounts[tagCount.tag] = userNoteCount;
        }
      }

      return userTagCounts.entries
          .map(
            (entry) =>
                domain.TagWithCount(tag: entry.key, noteCount: entry.value),
          )
          .toList();
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
      return const <domain.TagWithCount>[];
    }
  }

  @override
  Future<void> addTag({required String noteId, required String tag}) async {
    try {
      final currentTags = await getTagsForNote(noteId);
      if (!currentTags.contains(tag)) {
        currentTags.add(tag);
        await db.replaceTagsForNote(noteId, currentTags.toSet());
        await _enqueueNoteSync(noteId);
      }
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
      rethrow;
    }
  }

  @override
  Future<void> removeTag({required String noteId, required String tag}) async {
    try {
      final currentTags = await getTagsForNote(noteId);
      if (currentTags.contains(tag)) {
        currentTags.remove(tag);
        await db.replaceTagsForNote(noteId, currentTags.toSet());
        await _enqueueNoteSync(noteId);
      }
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
      rethrow;
    }
  }

  @override
  Future<int> renameTagEverywhere({
    required String oldTag,
    required String newTag,
  }) async {
    try {
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
      );

      final localNotes = allNotes
          .where((note) => note.userId == userId)
          .toList();

      final List<domain.Note> domainNotes = [];
      for (final localNote in localNotes) {
        final title = await _decryptHelper.decryptTitle(localNote);
        final body = await _decryptHelper.decryptBody(localNote);

        domainNotes.add(
          NoteMapper.toDomain(localNote, title: title, body: body),
        );
      }

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
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<String>> searchTags(String prefix) async {
    try {
      return await db.searchTags(prefix);
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
      return const <String>[];
    }
  }

  @override
  Future<List<String>> getTagsForNote(String noteId) async {
    try {
      final tags = await (db.select(
        db.noteTags,
      )..where((t) => t.noteId.equals(noteId))).get();

      return tags.map((t) => t.tag).toList();
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
      return const <String>[];
    }
  }
}
