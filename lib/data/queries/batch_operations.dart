import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Batch operations to eliminate N+1 queries
///
/// This class provides efficient batch operations that replace
/// individual queries in loops with single optimized queries.
class BatchOperations {
  BatchOperations(this.db) : _logger = LoggerFactory.instance;

  final AppDb db;
  final AppLogger _logger;

  /// Batch get tags for multiple notes (eliminates N+1 in tag repository)
  Future<Map<String, List<String>>> getTagsForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return {};

    final stopwatch = Stopwatch()..start();

    try {
      // Single query to get all tags for all notes
      final tags = await (db.select(db.noteTags)
        ..where((t) => t.noteId.isIn(noteIds)))
        .get();

      // Group by note ID
      final result = <String, List<String>>{};
      for (final tag in tags) {
        result.putIfAbsent(tag.noteId, () => []).add(tag.tag);
      }

      // Ensure all notes have an entry (even if empty)
      for (final noteId in noteIds) {
        result.putIfAbsent(noteId, () => []);
      }

      _logger.debug('Batch getTagsForNotes completed', data: {
        'note_count': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'tags_found': tags.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch getTagsForNotes failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch get links for multiple notes
  Future<Map<String, List<NoteLink>>> getLinksForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return {};

    final stopwatch = Stopwatch()..start();

    try {
      // Single query to get all links for all notes
      final links = await (db.select(db.noteLinks)
        ..where((l) => l.sourceId.isIn(noteIds)))
        .get();

      // Group by note ID
      final result = <String, List<NoteLink>>{};
      for (final link in links) {
        result.putIfAbsent(link.sourceId, () => []).add(link);
      }

      // Ensure all notes have an entry (even if empty)
      for (final noteId in noteIds) {
        result.putIfAbsent(noteId, () => []);
      }

      _logger.debug('Batch getLinksForNotes completed', data: {
        'note_count': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'links_found': links.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch getLinksForNotes failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch get attachments for multiple notes
  ///
  /// TODO(schema): Implement when LocalAttachments table is created
  /// For now returns empty lists to maintain API compatibility
  Future<Map<String, List<dynamic>>> getAttachmentsForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return {};

    final stopwatch = Stopwatch()..start();

    try {
      // Stubbed - requires database migration to create local_attachments table
      final result = <String, List<dynamic>>{};

      // Ensure all notes have an entry (even if empty)
      for (final noteId in noteIds) {
        result[noteId] = [];
      }

      _logger.debug('Batch getAttachmentsForNotes completed (stubbed)', data: {
        'note_count': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'attachments_found': 0,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch getAttachmentsForNotes failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch get tasks for multiple notes
  Future<Map<String, List<NoteTask>>> getTasksForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return {};

    final stopwatch = Stopwatch()..start();

    try {
      // Single query to get all tasks for all notes
      final tasks = await (db.select(db.noteTasks)
        ..where((t) => t.noteId.isIn(noteIds) & t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();

      // Group by note ID
      final result = <String, List<NoteTask>>{};
      for (final task in tasks) {
        result.putIfAbsent(task.noteId, () => []).add(task);
      }

      // Ensure all notes have an entry (even if empty)
      for (final noteId in noteIds) {
        result.putIfAbsent(noteId, () => []);
      }

      _logger.debug('Batch getTasksForNotes completed', data: {
        'note_count': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'tasks_found': tasks.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch getTasksForNotes failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch check folder existence (for folder integrity operations)
  Future<Map<String, bool>> checkFoldersExist(List<String> folderIds) async {
    if (folderIds.isEmpty) return {};

    final stopwatch = Stopwatch()..start();

    try {
      // Single query to check all folder existence
      final existingFolders = await (db.select(db.localFolders)
        ..where((f) => f.id.isIn(folderIds) & f.deleted.equals(false)))
        .get();

      final existingIds = existingFolders.map((f) => f.id).toSet();

      // Create result map
      final result = <String, bool>{};
      for (final folderId in folderIds) {
        result[folderId] = existingIds.contains(folderId);
      }

      _logger.debug('Batch checkFoldersExist completed', data: {
        'folder_count': folderIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'existing_count': existingFolders.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch checkFoldersExist failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch update note tags (replaces individual tag operations)
  Future<void> updateTagsForNotes(Map<String, List<String>> noteTagMap) async {
    if (noteTagMap.isEmpty) return;

    final stopwatch = Stopwatch()..start();

    try {
      await db.transaction(() async {
        // First, delete existing tags for all notes
        final noteIds = noteTagMap.keys.toList();
        await (db.delete(db.noteTags)..where((t) => t.noteId.isIn(noteIds))).go();

        // Then insert new tags in batch
        final tagsToInsert = <NoteTagsCompanion>[];
        for (final entry in noteTagMap.entries) {
          final noteId = entry.key;
          final tags = entry.value;

          for (final tag in tags) {
            tagsToInsert.add(NoteTagsCompanion(
              noteId: Value(noteId),
              tag: Value(tag),
            ));
          }
        }

        if (tagsToInsert.isNotEmpty) {
          await db.batch((batch) {
            batch.insertAll(db.noteTags, tagsToInsert);
          });
        }
      });

      _logger.debug('Batch updateTagsForNotes completed', data: {
        'note_count': noteTagMap.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'total_tags': noteTagMap.values.expand((tags) => tags).length,
      });

    } catch (e, stackTrace) {
      _logger.error('Batch updateTagsForNotes failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch get notes by IDs with all relations
  Future<List<NoteWithAllRelations>> getNotesWithAllRelations(List<String> noteIds) async {
    if (noteIds.isEmpty) return [];

    final stopwatch = Stopwatch()..start();

    try {
      // Get all notes
      final notes = await (db.select(db.localNotes)
        ..where((n) => n.id.isIn(noteIds) & n.deleted.equals(false)))
        .get();

      // Batch load all relations
      final futures = await Future.wait<Map<String, List<dynamic>>>([
        getTagsForNotes(noteIds),
        getLinksForNotes(noteIds),
        getAttachmentsForNotes(noteIds),
        getTasksForNotes(noteIds),
      ]);

      final tagsByNote = futures[0] as Map<String, List<String>>;
      final linksByNote = futures[1] as Map<String, List<NoteLink>>;
      final attachmentsByNote = futures[2]; // Already Map<String, List<dynamic>>
      final tasksByNote = futures[3] as Map<String, List<NoteTask>>;

      // Build results
      final results = notes.map((note) {
        return NoteWithAllRelations(
          note: note,
          tags: tagsByNote[note.id] ?? [],
          links: linksByNote[note.id] ?? [],
          attachments: attachmentsByNote[note.id] ?? [],
          tasks: tasksByNote[note.id] ?? [],
        );
      }).toList();

      _logger.debug('Batch getNotesWithAllRelations completed', data: {
        'note_count': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
        'results_count': results.length,
      });

      return results;

    } catch (e, stackTrace) {
      _logger.error('Batch getNotesWithAllRelations failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Batch rename tags across multiple notes (optimized version)
  Future<int> batchRenameTag(String oldTag, String newTag) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Get all notes with the old tag in a single query
      final notesWithTag = await (db.select(db.noteTags)
        ..where((t) => t.tag.equals(oldTag)))
        .get();

      if (notesWithTag.isEmpty) return 0;

      final noteIds = notesWithTag.map((t) => t.noteId).toList();

      await db.transaction(() async {
        // Delete old tag entries
        await (db.delete(db.noteTags)
          ..where((t) => t.tag.equals(oldTag)))
          .go();

        // Insert new tag entries only if they don't already exist
        for (final noteId in noteIds) {
          await db.into(db.noteTags).insertOnConflictUpdate(
            NoteTagsCompanion(
              noteId: Value(noteId),
              tag: Value(newTag),
            ),
          );
        }
      });

      _logger.debug('Batch batchRenameTag completed', data: {
        'old_tag': oldTag,
        'new_tag': newTag,
        'affected_notes': noteIds.length,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
      });

      return noteIds.length;

    } catch (e, stackTrace) {
      _logger.error('Batch batchRenameTag failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Get performance statistics for batch operations
  Map<String, dynamic> getPerformanceStats() {
    return {
      'batch_operations_available': [
        'getTagsForNotes',
        'getLinksForNotes',
        'getAttachmentsForNotes',
        'getTasksForNotes',
        'checkFoldersExist',
        'updateTagsForNotes',
        'getNotesWithAllRelations',
        'batchRenameTag',
      ],
      'performance_target': '<50ms for batch operations',
      'optimization_level': 'maximum',
    };
  }
}

/// Data transfer object for notes with all relations
class NoteWithAllRelations {
  const NoteWithAllRelations({
    required this.note,
    required this.tags,
    required this.links,
    required this.attachments,
    required this.tasks,
  });

  final LocalNote note;
  final List<String> tags;
  final List<NoteLink> links;
  final List<dynamic> attachments; // Changed to dynamic until schema is created
  final List<NoteTask> tasks;

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'tags': tags,
      'links': links,
      'attachments': attachments,
      'tasks': tasks,
    };
  }
}