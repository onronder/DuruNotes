import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Optimized database queries to prevent N+1 problems
///
/// **PRODUCTION NOTE**: This query layer has been updated to remove references
/// to non-existent tables (LocalAttachment, LocalInboxItem). These features
/// will be implemented in future database migrations.
class OptimizedQueries {
  OptimizedQueries(this.db);

  final AppDb db;

  /// Get a note with all its related data in a single query
  ///
  /// **SECURITY**: This method enforces authorization by requiring userId.
  /// Only returns the note if it belongs to the specified user.
  Future<NoteWithRelations?> getNoteWithRelations(
    String noteId, {
    required String userId,
  }) async {
    // SECURITY: Filter by both noteId AND userId to enforce authorization
    final query = db.select(db.localNotes)
      ..where((n) => n.id.equals(noteId) & n.userId.equals(userId));

    final note = await query.getSingleOrNull();
    if (note == null) return null;

    // Batch load all related data
    final futures = await Future.wait([
      _getTasksForNote(noteId),
      _getTagsForNote(noteId),
    ]);

    return NoteWithRelations(
      note: note,
      tasks: futures[0] as List<NoteTask>,
      tags: futures[1] as List<NoteTag>,
      // TODO(schema): Add attachments when LocalAttachments table is created
      attachments: const [],
    );
  }

  /// Get multiple notes with their relations efficiently
  Future<List<NoteWithRelations>> getNotesWithRelations({
    required String userId,
    int limit = 50,
    int offset = 0,
    String? folderId,
  }) async {
    // Main notes query
    final notesQuery = db.select(db.localNotes)
      ..where((n) => n.userId.equals(userId) & n.deleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit, offset: offset);

    if (folderId != null) {
      // Join with NoteFolders table to filter by folder
      notesQuery.join([
        leftOuterJoin(
          db.noteFolders,
          db.noteFolders.noteId.equalsExp(db.localNotes.id),
        ),
      ]);
      notesQuery.where((tbl) => db.noteFolders.folderId.equals(folderId));
    }

    final notes = await notesQuery.get();
    if (notes.isEmpty) return [];

    final noteIds = notes.map((n) => n.id).toList();

    // Batch load all related data
    final allTasks = await _getTasksForNotes(noteIds);
    final allTags = await _getTagsForNotes(noteIds);
    // TODO(schema): Add attachments when LocalAttachments table is created

    // Group by note ID
    final tasksByNote = <String, List<NoteTask>>{};
    final tagsByNote = <String, List<NoteTag>>{};

    for (final task in allTasks) {
      tasksByNote.putIfAbsent(task.noteId, () => []).add(task);
    }

    for (final tag in allTags) {
      tagsByNote.putIfAbsent(tag.noteId, () => []).add(tag);
    }

    // Build results
    return notes.map((note) {
      return NoteWithRelations(
        note: note,
        tasks: tasksByNote[note.id] ?? [],
        tags: tagsByNote[note.id] ?? [],
        // TODO(schema): Add attachments when LocalAttachments table is created
        attachments: const [],
      );
    }).toList();
  }

  /// Get folders with note counts efficiently
  Future<List<FolderWithCount>> getFoldersWithCounts(String userId) async {
    // Use raw SQL for efficient counting
    final result = await db
        .customSelect(
          '''
      SELECT
        f.*,
        COUNT(DISTINCT n.id) as note_count
      FROM folders f
      LEFT JOIN local_notes n ON f.id = n.folder_id AND n.deleted = false
      WHERE f.user_id = ? AND f.deleted = false
      GROUP BY f.id
      ORDER BY f.position, f.name
      ''',
          variables: [Variable.withString(userId)],
          readsFrom: {db.localFolders, db.localNotes},
        )
        .get();

    return result.map((row) {
      final folder = db.localFolders.map(row.data);
      final noteCount = row.read<int>('note_count');

      return FolderWithCount(folder: folder, noteCount: noteCount);
    }).toList();
  }

  /// Get tasks with subtasks efficiently
  Future<List<TaskWithSubtasks>> getTasksWithSubtasks(String noteId) async {
    final allTasks =
        await (db.select(db.noteTasks)
              ..where((t) => t.noteId.equals(noteId))
              ..orderBy([(t) => OrderingTerm(expression: t.position)]))
            .get();

    // Build hierarchy map
    final taskMap = <String, TaskWithSubtasks>{};
    final rootTasks = <TaskWithSubtasks>[];

    // First pass: create all task nodes
    for (final task in allTasks) {
      taskMap[task.id] = TaskWithSubtasks(task: task, subtasks: []);
    }

    // Second pass: build hierarchy
    for (final task in allTasks) {
      final node = taskMap[task.id]!;

      if (task.parentTaskId != null && taskMap.containsKey(task.parentTaskId)) {
        taskMap[task.parentTaskId]!.subtasks.add(node);
      } else {
        rootTasks.add(node);
      }
    }

    return rootTasks;
  }

  /// Private helper methods
  Future<List<NoteTask>> _getTasksForNote(String noteId) async {
    return (db.select(db.noteTasks)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();
  }

  Future<List<NoteTask>> _getTasksForNotes(List<String> noteIds) async {
    return (db.select(db.noteTasks)
          ..where((t) => t.noteId.isIn(noteIds))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();
  }

  Future<List<NoteTag>> _getTagsForNote(String noteId) async {
    return (db.select(
      db.noteTags,
    )..where((t) => t.noteId.equals(noteId))).get();
  }

  Future<List<NoteTag>> _getTagsForNotes(List<String> noteIds) async {
    return (db.select<$NoteTagsTable, NoteTag>(
      db.noteTags,
    )..where((t) => t.noteId.isIn(noteIds))).get();
  }

  // ============================================================================
  // Stubbed methods for future implementation
  // ============================================================================

  /// TODO(schema): Implement when LocalInboxItems table is created
  ///
  /// Get unprocessed inbox items efficiently
  Future<List<dynamic>> getUnprocessedInboxItems({
    required String userId,
    int limit = 50,
  }) async {
    // Stubbed - requires database migration to create local_inbox_items table
    return [];
  }

  /// TODO(schema): Implement when LocalInboxItems table is created
  ///
  /// Get inbox items by source type efficiently
  Future<List<dynamic>> getInboxItemsBySource({
    required String userId,
    required String sourceType,
    int limit = 50,
  }) async {
    // Stubbed - requires database migration to create local_inbox_items table
    return [];
  }

  /// TODO(schema): Implement when LocalInboxItems table is created
  ///
  /// Get inbox statistics efficiently
  Future<Map<String, int>> getInboxStats(String userId) async {
    // Stubbed - requires database migration to create local_inbox_items table
    return {
      'total': 0,
      'unprocessed': 0,
      'processed': 0,
      'email_in': 0,
      'web': 0,
    };
  }
}

/// Data transfer objects for optimized queries
class NoteWithRelations {
  const NoteWithRelations({
    required this.note,
    required this.tasks,
    required this.tags,
    required this.attachments,
  });

  final LocalNote note;
  final List<NoteTask> tasks;
  final List<NoteTag> tags;
  final List<dynamic> attachments; // Changed to dynamic until schema is created

  /// Convert to domain model if needed
  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'tasks': tasks,
      'tags': tags,
      'attachments': attachments,
    };
  }
}

class FolderWithCount {
  const FolderWithCount({required this.folder, required this.noteCount});

  final LocalFolder folder;
  final int noteCount;

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {'folder': folder, 'note_count': noteCount};
  }
}

class TaskWithSubtasks {
  TaskWithSubtasks({required this.task, required this.subtasks});

  final NoteTask task;
  final List<TaskWithSubtasks> subtasks;

  /// Get total number of tasks including subtasks
  int get totalTasks {
    return 1 + subtasks.fold(0, (sum, subtask) => sum + subtask.totalTasks);
  }

  /// Check if all tasks (including subtasks) are completed
  bool get allCompleted {
    if (task.status != TaskStatus.completed) return false;
    return subtasks.every((subtask) => subtask.allCompleted);
  }
}
