import 'package:collection/collection.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:drift/drift.dart';

/// Batch loading utilities to prevent N+1 query patterns
///
/// Instead of:
/// ```dart
/// for (final note in notes) {
///   final tags = await db.getTagsForNote(note.id); // N queries
/// }
/// ```
///
/// Use:
/// ```dart
/// final tagsByNote = await BatchLoader.loadTagsForNotes(db, noteIds);
/// ```
class BatchLoader {
  /// Load tags for multiple notes in a single query
  ///
  /// Performance: 1 query instead of N queries
  static Future<Map<String, List<String>>> loadTagsForNotes(
    AppDb db,
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};

    // Single query to get all tags
    final tagRecords = await (db.select(
      db.noteTags,
    )..where((t) => t.noteId.isIn(noteIds))).get();

    // Group by noteId
    final tagsByNote = groupBy<NoteTag, String>(
      tagRecords,
      (tag) => tag.noteId,
    );

    // Convert to List<String> for each note
    final result = <String, List<String>>{};
    for (final noteId in noteIds) {
      final tags = tagsByNote[noteId] ?? [];
      result[noteId] = tags.map((t) => t.tag).toList();
    }

    return result;
  }

  /// Load links for multiple notes in a single query
  ///
  /// Performance: 1 query instead of N queries
  static Future<Map<String, List<NoteLink>>> loadLinksForNotes(
    AppDb db,
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};

    // Single query to get all links
    final linkRecords = await (db.select(
      db.noteLinks,
    )..where((l) => l.sourceId.isIn(noteIds))).get();

    // Group by sourceId
    final linksByNote = groupBy<NoteLink, String>(
      linkRecords as Iterable<NoteLink>,
      (link) => link.sourceId,
    );

    // Ensure all noteIds are in the result
    final result = <String, List<NoteLink>>{};
    for (final noteId in noteIds) {
      final links = linksByNote[noteId];
      result[noteId] = links != null ? List<NoteLink>.from(links) : [];
    }

    return result;
  }

  /// Load folder relationships for multiple notes in a single query
  ///
  /// Performance: 1 query instead of N queries
  static Future<Map<String, String?>> loadFoldersForNotes(
    AppDb db,
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};

    // Single query to get all folder relationships
    final folderRecords = await (db.select(
      db.noteFolders,
    )..where((nf) => nf.noteId.isIn(noteIds))).get();

    // Map noteId to folderId
    final result = <String, String?>{};
    for (final noteId in noteIds) {
      result[noteId] = null; // Default to no folder
    }

    for (final record in folderRecords) {
      result[record.noteId] = record.folderId;
    }

    return result;
  }

  /// Load tasks for multiple notes in a single query
  ///
  /// Performance: 1 query instead of N queries
  static Future<Map<String, List<NoteTask>>> loadTasksForNotes(
    AppDb db,
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};

    // Single query to get all tasks
    final taskRecords = await (db.select(
      db.noteTasks,
    )..where((t) => t.noteId.isIn(noteIds) & t.deleted.equals(false))).get();

    // Group by noteId
    final tasksByNote = groupBy<NoteTask, String>(
      taskRecords,
      (task) => task.noteId,
    );

    // Ensure all noteIds are in the result
    final result = <String, List<NoteTask>>{};
    for (final noteId in noteIds) {
      result[noteId] = tasksByNote[noteId] ?? [];
    }

    return result;
  }

  /// Load note counts for multiple folders in a single query
  ///
  /// Performance: 1 query instead of N queries
  static Future<Map<String, int>> loadNoteCountsForFolders(
    AppDb db,
    List<String> folderIds,
  ) async {
    if (folderIds.isEmpty) return {};

    // Single query with GROUP BY
    final query = db.selectOnly(db.noteFolders)
      ..addColumns([db.noteFolders.folderId, db.noteFolders.noteId.count()])
      ..where(db.noteFolders.folderId.isIn(folderIds))
      ..groupBy([db.noteFolders.folderId]);

    final results = await query.get();

    // Parse results
    final counts = <String, int>{};
    for (final row in results) {
      final folderId = row.read(db.noteFolders.folderId)!;
      final count = row.read(db.noteFolders.noteId.count())!;
      counts[folderId] = count;
    }

    // Ensure all folderIds are in the result
    for (final folderId in folderIds) {
      counts.putIfAbsent(folderId, () => 0);
    }

    return counts;
  }

  /// Batch load with custom grouping
  ///
  /// Generic batch loader for any entity type
  static Map<K, List<T>> groupByKey<T, K>(
    List<T> items,
    K Function(T) keyExtractor,
  ) {
    return groupBy<T, K>(items, keyExtractor);
  }
}

/// Extension methods for batch loading
extension BatchLoadingExtensions on AppDb {
  /// Batch load tags for notes
  Future<Map<String, List<String>>> batchLoadTags(List<String> noteIds) {
    return BatchLoader.loadTagsForNotes(this, noteIds);
  }

  /// Batch load links for notes
  Future<Map<String, List<NoteLink>>> batchLoadLinks(List<String> noteIds) {
    return BatchLoader.loadLinksForNotes(this, noteIds);
  }

  /// Batch load folders for notes
  Future<Map<String, String?>> batchLoadFolders(List<String> noteIds) {
    return BatchLoader.loadFoldersForNotes(this, noteIds);
  }

  /// Batch load tasks for notes
  Future<Map<String, List<NoteTask>>> batchLoadTasks(List<String> noteIds) {
    return BatchLoader.loadTasksForNotes(this, noteIds);
  }

  /// Batch load note counts for folders
  Future<Map<String, int>> batchLoadNoteCounts(List<String> folderIds) {
    return BatchLoader.loadNoteCountsForFolders(this, folderIds);
  }
}
