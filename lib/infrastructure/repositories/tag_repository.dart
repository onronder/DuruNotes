import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Tag repository implementation
class TagRepository implements ITagRepository {
  TagRepository({
    required this.db,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final AppLogger _logger;

  @override
  Future<List<TagCount>> listTagsWithCounts() => db.getTagsWithCounts();

  @override
  Future<void> addTag({required String noteId, required String tag}) async {
    final currentTags = await getTagsForNote(noteId);
    if (!currentTags.contains(tag)) {
      currentTags.add(tag);
      await db.replaceTagsForNote(noteId, currentTags.toSet());
      await db.enqueue(noteId, 'upsert_note');
    }
  }

  @override
  Future<void> removeTag({required String noteId, required String tag}) async {
    final currentTags = await getTagsForNote(noteId);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
      await db.replaceTagsForNote(noteId, currentTags.toSet());
      await db.enqueue(noteId, 'upsert_note');
    }
  }

  @override
  Future<int> renameTagEverywhere({
    required String oldTag,
    required String newTag,
  }) async {
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
        await db.enqueue(note.id, 'upsert_note');
        count++;
      }
    }

    _logger.info('Renamed tag "$oldTag" to "$newTag" in $count notes');
    return count;
  }

  @override
  Future<List<LocalNote>> queryNotesByTags({
    List<String> anyTags = const [],
    List<String> allTags = const [],
    List<String> noneTags = const [],
  }) {
    return db.notesByTags(
      anyTags: anyTags,
      noneTags: noneTags,
      sort: const SortSpec(),
    );
  }

  @override
  Future<List<String>> searchTags(String prefix) => db.searchTags(prefix);

  @override
  Future<List<String>> getTagsForNote(String noteId) async {
    final tags = await (db.select(db.noteTags)
          ..where((t) => t.noteId.equals(noteId)))
        .get();

    return tags.map((t) => t.tag).toList();
  }
}