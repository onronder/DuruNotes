import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/core/utils/hash_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

part 'app_db.g.dart';

/// ----------------------
/// Table definitions
/// ----------------------
@DataClassName('LocalNote')
class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get encryptedMetadata => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(
    const Constant(false),
  )(); // For pinning notes to top

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get kind =>
      text()(); // 'upsert_note' | 'delete_note' | 'upsert_folder' | 'delete_folder' | 'upsert_tag' | 'delete_tag' | 'upsert_saved_search' | 'delete_saved_search'
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {noteId, tag};
}

@DataClassName('NoteLink')
class NoteLinks extends Table {
  TextColumn get sourceId => text()();
  TextColumn get targetTitle => text()();
  TextColumn get targetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId, targetTitle};
}

// Reminder types
enum ReminderType {
  time, // Time-based reminder
  location, // Location-based reminder (geofence)
  recurring, // Recurring reminder
}

// Recurring patterns
enum RecurrencePattern { none, daily, weekly, monthly, yearly }

// Snooze durations
enum SnoozeDuration {
  fiveMinutes,
  tenMinutes,
  fifteenMinutes,
  thirtyMinutes,
  oneHour,
  twoHours,
  tomorrow,
}

@DataClassName('NoteReminder')
class NoteReminders extends Table {
  IntColumn get id => integer().autoIncrement()(); // Primary key
  TextColumn get noteId => text()(); // Foreign key to note
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();

  // Reminder type and timing
  IntColumn get type => intEnum<ReminderType>()(); // time, location, recurring
  DateTimeColumn get remindAt =>
      dateTime().nullable()(); // for time-based reminders (UTC)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Location-based fields
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get radius => real().nullable()(); // in meters
  TextColumn get locationName => text().nullable()();

  // Recurring reminder fields
  IntColumn get recurrencePattern => intEnum<RecurrencePattern>().withDefault(
    Constant(RecurrencePattern.none.index),
  )();
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))(); // every X days/weeks/months

  // Snooze functionality
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();

  // Rich notification content
  TextColumn get notificationTitle => text().nullable()();
  TextColumn get notificationBody => text().nullable()();
  TextColumn get notificationImage => text().nullable()(); // path or URL

  // Metadata
  TextColumn get timeZone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastTriggered => dateTime().nullable()();
  IntColumn get triggerCount => integer().withDefault(const Constant(0))();
}

/// Task status enum
enum TaskStatus {
  open, // Task is open/pending
  completed, // Task is completed
  cancelled, // Task was cancelled
}

/// Task priority levels
enum TaskPriority { low, medium, high, urgent }

/// Note tasks table for tracking actionable items from notes
@DataClassName('NoteTask')
class NoteTasks extends Table {
  /// Unique identifier for the task
  TextColumn get id => text()();

  /// Reference to parent note ID
  TextColumn get noteId => text()();

  /// Task content/description
  TextColumn get content => text()();

  /// Task completion status
  IntColumn get status =>
      intEnum<TaskStatus>().withDefault(Constant(TaskStatus.open.index))();

  /// Task priority level
  IntColumn get priority => intEnum<TaskPriority>().withDefault(
    Constant(TaskPriority.medium.index),
  )();

  /// Optional due date for the task
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Date when task was completed
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// User who completed the task (for shared notes)
  TextColumn get completedBy => text().nullable()();

  /// Line number or position in note (for sync with markdown)
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Hash of the task text for deduplication
  TextColumn get contentHash => text()();

  /// Optional reminder ID if a reminder is set for this task
  IntColumn get reminderId => integer().nullable()();

  /// Custom labels/tags for the task
  TextColumn get labels => text().nullable()(); // JSON array

  /// Notes or additional context for the task
  TextColumn get notes => text().nullable()();

  /// Time estimate in minutes
  IntColumn get estimatedMinutes => integer().nullable()();

  /// Actual time spent in minutes
  IntColumn get actualMinutes => integer().nullable()();

  /// Parent task ID for subtasks
  TextColumn get parentTaskId => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last modification timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft delete flag
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// UI'da kullanmak için küçük taşıyıcı
class BacklinkPair {
  const BacklinkPair({required this.link, this.source});
  final NoteLink link;
  final LocalNote? source;
}

/// Tag with note count for UI display
class TagCount {
  const TagCount({required this.tag, required this.count});
  final String tag;
  final int count;
}

/// Sort options for queries
enum SortBy { updatedAt, title, createdAt }

/// Sort specification for queries
class SortSpec {
  const SortSpec({
    this.sortBy = SortBy.updatedAt,
    this.ascending = false,
    this.pinnedFirst = true,
  });
  final SortBy sortBy;
  final bool ascending;
  final bool pinnedFirst;
}

/// Folder system tables for hierarchical organization
@DataClassName('LocalFolder')
class LocalFolders extends Table {
  /// Unique identifier for the folder
  TextColumn get id => text()();

  /// Display name of the folder
  TextColumn get name => text()();

  /// Parent folder ID for hierarchy (null for root folders)
  TextColumn get parentId => text().nullable()();

  /// Full path from root (e.g., "/Work/Projects/2024")
  TextColumn get path => text()();

  /// Display order within parent folder
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Optional color for folder display (hex format)
  TextColumn get color => text().nullable()();

  /// Optional icon name for folder display
  TextColumn get icon => text().nullable()();

  /// Folder description/notes
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete flag
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Note-Folder relationship table (one note can be in one folder)
@DataClassName('NoteFolder')
class NoteFolders extends Table {
  /// Note ID (foreign key to local_notes)
  TextColumn get noteId => text()();

  /// Folder ID (foreign key to local_folders)
  TextColumn get folderId => text()();

  /// When the note was added to this folder
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {noteId}; // One folder per note
}

/// Saved searches table for persisting user-defined queries/chips
@DataClassName('SavedSearch')
class SavedSearches extends Table {
  /// Unique identifier for the saved search
  TextColumn get id => text()();

  /// Display name for the search
  TextColumn get name => text()();

  /// The search query/pattern
  TextColumn get query => text()();

  /// Search type: 'text', 'tag', 'folder', 'date_range', 'compound'
  TextColumn get searchType => text().withDefault(const Constant('text'))();

  /// Optional parameters as JSON (e.g., date ranges, folder IDs, etc.)
  TextColumn get parameters => text().nullable()();

  /// Display order for the saved searches
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Optional color for display (hex format)
  TextColumn get color => text().nullable()();

  /// Optional icon name for display
  TextColumn get icon => text().nullable()();

  /// Whether this search is pinned/favorited
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last used timestamp
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  /// Usage count for sorting by frequency
  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------------------
/// Database
/// ----------------------
@DriftDatabase(
  tables: [
    LocalNotes,
    PendingOps,
    NoteTags,
    NoteLinks,
    NoteReminders,
    NoteTasks,
    LocalFolders,
    NoteFolders,
    SavedSearches,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // FTS table with folder_path support
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body, folder_path UNINDEXED)',
      );

      // Triggers: local_notes <-> fts_notes sync
      await _createFtsTriggers();

      // Triggers: folder path sync
      await _createFolderSyncTriggers();

      // Indexes
      await _createIndexes();
      await _createReminderIndexes();
      await _createFolderIndexes();
      await _createTaskIndexes();
      await _createSavedSearchIndexes();

      // Seed existing data to FTS
      await customStatement(
        'INSERT INTO fts_notes(id, title, body, folder_path) '
        'SELECT id, title, body, NULL FROM local_notes WHERE deleted = 0',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(noteTags);
        await m.createTable(noteLinks);
      }
      // FTS tablosu ve tetikleyiciler/indeksler
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
      );
      if (from < 3) {
        await _createFtsTriggers();
        await _createIndexes();
        await customStatement('DELETE FROM fts_notes');
        await customStatement(
          'INSERT INTO fts_notes(id, title, body) '
          'SELECT id, title, body FROM local_notes WHERE deleted = 0',
        );
      }
      if (from < 4) {
        await m.createTable(noteReminders);
        await _createReminderIndexes();
      }
      if (from < 5) {
        // Migration from simple reminders to advanced reminders
        await _migrateToAdvancedReminders(m);
        await _createAdvancedReminderIndexes();
      }
      if (from < 6) {
        // Add folder system tables
        await m.createTable(localFolders);
        await m.createTable(noteFolders);

        // Create folder indexes for performance
        await _createFolderIndexes();

        // Update FTS to include folder path
        await _updateFtsForFolders();

        // Create default "Unfiled" folder for existing notes (optional)
        await _createDefaultFolders();
      }
      if (from < 7) {
        // Add metadata column for attachment and email information persistence
        await m.addColumn(localNotes, localNotes.encryptedMetadata);
      }
      if (from < 8) {
        // Version 8: Enhanced folder system, pinning, and saved searches

        // 1. Add is_pinned column to local_notes for pinning functionality
        await m.addColumn(localNotes, localNotes.isPinned);

        // 2. Create saved_searches table for persisting user queries
        await m.createTable(savedSearches);

        // 3. Create triggers to keep fts_notes.folder_path in sync
        await _createFolderSyncTriggers();

        // 4. Create indexes for saved searches
        await _createSavedSearchIndexes();

        // 5. Update existing notes in FTS with folder paths
        await _syncExistingFolderPaths();
      }
      if (from < 9) {
        // Version 9: Add note tasks table for task management
        await m.createTable(noteTasks);

        // Create indexes for task queries
        await _createTaskIndexes();

        // Parse existing notes and extract tasks from checkboxes
        await _extractTasksFromExistingNotes();

        // Backfill content_hash for any existing tasks with stable hash
        await _backfillTaskContentHash();
      }
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_notes_updated_notdeleted '
      'ON local_notes(updated_at DESC) WHERE deleted = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_links_target_title '
      'ON note_links(target_title)',
    );
  }

  Future<void> _createReminderIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_remind_at '
      'ON note_reminders(remind_at)',
    );
  }

  Future<void> _createAdvancedReminderIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_note_id '
      'ON note_reminders(note_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_type '
      'ON note_reminders(type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_active '
      'ON note_reminders(is_active)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_location '
      'ON note_reminders(latitude, longitude) WHERE latitude IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_snoozed '
      'ON note_reminders(snoozed_until) WHERE snoozed_until IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_next_trigger '
      'ON note_reminders(remind_at, is_active) WHERE remind_at IS NOT NULL',
    );
  }

  Future<void> _migrateToAdvancedReminders(Migrator m) async {
    // Drop the old table if it exists (since we're changing the schema significantly)
    await customStatement('DROP TABLE IF EXISTS note_reminders');

    // Create the new advanced table
    await m.createTable(noteReminders);
  }

  Future<void> _createFtsTriggers() async {
    // INSERT -> Add to FTS (if not deleted) with folder_path
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ai
      AFTER INSERT ON local_notes
      BEGIN
        INSERT INTO fts_notes(id, title, body, folder_path)
        SELECT 
          NEW.id, 
          NEW.title, 
          NEW.body,
          (SELECT path FROM local_folders lf 
           JOIN note_folders nf ON nf.folder_id = lf.id 
           WHERE nf.note_id = NEW.id)
        WHERE NEW.deleted = 0;
      END;
    ''');

    // UPDATE -> Update FTS with folder_path
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_au
      AFTER UPDATE ON local_notes
      BEGIN
        DELETE FROM fts_notes WHERE id = NEW.id;
        INSERT INTO fts_notes(id, title, body, folder_path)
        SELECT 
          NEW.id, 
          NEW.title, 
          NEW.body,
          (SELECT path FROM local_folders lf 
           JOIN note_folders nf ON nf.folder_id = lf.id 
           WHERE nf.note_id = NEW.id)
        WHERE NEW.deleted = 0;
      END;
    ''');

    // DELETE -> Remove from FTS
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ad
      AFTER DELETE ON local_notes
      BEGIN
        DELETE FROM fts_notes WHERE id = OLD.id;
      END;
    ''');
  }

  // ----------------------
  // Notes
  // ----------------------
  Future<List<LocalNote>> suggestNotesByTitlePrefix(
    String query, {
    int limit = 8,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .get();
    }

    final startsWith = '$q%';
    final wordStart = '% $q%';

    return (select(localNotes)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                (t.title.like(startsWith) | t.title.like(wordStart)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)])
          ..limit(limit))
        .get();
  }

  Future<List<LocalNote>> allNotes() =>
      (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Keyset pagination: Get notes after a given cursor (updatedAt timestamp)
  /// Uses keyset pagination for better performance at scale vs OFFSET
  Future<List<LocalNote>> notesAfter({
    required DateTime? cursor,
    required int limit,
  }) {
    final query = select(localNotes)..where((t) => t.deleted.equals(false));

    // If cursor is provided, get notes older than cursor
    if (cursor != null) {
      query.where((t) => t.updatedAt.isSmallerThanValue(cursor));
    }

    query
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit);

    return query.get();
  }

  /// Fallback for small datasets or debugging (offset-based pagination)
  Future<List<LocalNote>> pagedNotes({
    required int limit,
    required int offset,
  }) =>
      (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit, offset: offset))
          .get();

  /// Get all notes with pinned notes first
  Future<List<LocalNote>> allNotesWithPinned() =>
      (select(localNotes)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .get();

  /// Get pinned notes only
  Future<List<LocalNote>> getPinnedNotes() =>
      (select(localNotes)
            ..where((t) => t.deleted.equals(false) & t.isPinned.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Pin or unpin a note
  Future<void> toggleNotePin(String noteId) async {
    final note = await findNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
      );
      await upsertNote(updatedNote);
      await enqueue(noteId, 'upsert_note');
    }
  }

  /// Set pin status for a note
  Future<void> setNotePin(String noteId, bool isPinned) async {
    final note = await findNote(noteId);
    if (note != null && note.isPinned != isPinned) {
      final updatedNote = note.copyWith(
        isPinned: isPinned,
        updatedAt: DateTime.now(),
      );
      await upsertNote(updatedNote);
      await enqueue(noteId, 'upsert_note');
    }
  }

  /// Get notes in folder with pinned first
  Future<List<LocalNote>> getNotesInFolderWithPinned(
    String folderId, {
    int? limit,
    DateTime? cursor,
  }) {
    final query =
        select(localNotes).join([
          leftOuterJoin(
            noteFolders,
            noteFolders.noteId.equalsExp(localNotes.id),
          ),
        ])..where(
          localNotes.deleted.equals(false) &
              noteFolders.folderId.equals(folderId),
        );

    if (cursor != null) {
      query.where(localNotes.updatedAt.isSmallerThanValue(cursor));
    }

    query.orderBy([
      OrderingTerm.desc(localNotes.isPinned),
      OrderingTerm.desc(localNotes.updatedAt),
    ]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.map((row) => row.readTable(localNotes)).get();
  }

  Future<void> upsertNote(LocalNote n) =>
      into(localNotes).insertOnConflictUpdate(n);

  Future<LocalNote?> findNote(String id) =>
      (select(localNotes)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ----------------------
  // Queue (PendingOps)
  // ----------------------
  Future<int> enqueue(String entityId, String kind, {String? payload}) =>
      into(pendingOps).insert(
        PendingOpsCompanion.insert(
          entityId: entityId,
          kind: kind,
          payload: Value(payload),
        ),
      );

  Future<List<PendingOp>> getPendingOps() =>
      (select(pendingOps)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

  Future<void> deletePendingByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(pendingOps)..where((t) => t.id.isIn(ids.toList()))).go();
  }

  Future<List<PendingOp>> dequeueAll() async {
    final ops = await (select(
      pendingOps,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
    await delete(pendingOps).go();
    return ops;
  }

  // ----------------------
  // Maintenance
  // ----------------------
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(pendingOps).go();
      await delete(localNotes).go();
      await delete(noteTags).go();
      await delete(noteLinks).go();
      await delete(noteReminders).go();
      await customStatement('DELETE FROM fts_notes');
    });
  }

  Future<Set<String>> getLocalActiveNoteIds() async {
    final rows = await (select(
      localNotes,
    )..where((t) => t.deleted.equals(false))).get();
    return rows.map((e) => e.id).toSet();
  }

  // ----------------------
  // Tags & Links index
  // ----------------------
  Future<void> replaceTagsForNote(String noteId, Set<String> tags) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      if (tags.isNotEmpty) {
        // Normalize tags to lowercase for consistent storage
        final normalizedTags = tags
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toSet();

        await batch((b) {
          b.insertAll(
            noteTags,
            normalizedTags.map(
              (t) => NoteTagsCompanion.insert(noteId: noteId, tag: t),
            ),
          );
        });
      }
    });
  }

  Future<void> replaceLinksForNote(
    String noteId,
    List<Map<String, String?>> links,
  ) async {
    await transaction(() async {
      await (delete(noteLinks)..where((t) => t.sourceId.equals(noteId))).go();
      if (links.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            noteLinks,
            links.map(
              (l) => NoteLinksCompanion.insert(
                sourceId: noteId,
                targetTitle: l['title'] ?? '',
                targetId: Value(l['id']),
              ),
            ),
          );
        });
      }
    });
  }

  Future<List<String>> distinctTags() async {
    final rows = await customSelect(
      '''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0
      ORDER BY LOWER(t.tag) ASC
      ''',
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
  }

  /// Get tags with their note counts (normalized, excludes deleted notes)
  Future<List<TagCount>> getTagsWithCounts() async {
    final rows = await customSelect(
      '''
      SELECT nt.tag AS tag, COUNT(*) AS count
      FROM note_tags nt
      JOIN local_notes n ON n.id = nt.note_id
      WHERE n.deleted = 0
      GROUP BY nt.tag
      ORDER BY count DESC, tag ASC
      ''',
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows
        .map(
          (r) =>
              TagCount(tag: r.read<String>('tag'), count: r.read<int>('count')),
        )
        .toList();
  }

  /// Add tag to note (normalized, idempotent)
  Future<void> addTagToNote(String noteId, String rawTag) async {
    final tag = rawTag.trim().toLowerCase();

    await into(noteTags).insert(
      NoteTag(noteId: noteId, tag: tag),
      mode: InsertMode.insertOrIgnore, // idempotent
    );
  }

  /// Remove tag from note
  Future<void> removeTagFromNote(String noteId, String rawTag) async {
    final tag = rawTag.trim().toLowerCase();
    await (delete(
      noteTags,
    )..where((t) => t.noteId.equals(noteId) & t.tag.equals(tag))).go();
  }

  /// Rename/merge tag across all notes
  Future<int> renameTagEverywhere(String fromRaw, String toRaw) async {
    final from = fromRaw.trim().toLowerCase();
    final to = toRaw.trim().toLowerCase();

    if (from == to) return 0;

    // Use custom update to handle potential conflicts
    return customUpdate(
      'UPDATE OR IGNORE note_tags SET tag = ? WHERE tag = ?',
      variables: [Variable<String>(to), Variable<String>(from)],
      updates: {noteTags},
    );
  }

  /// Filter notes by tags (union of anyTags, excluding noneTags)
  Future<List<LocalNote>> notesByTags({
    required List<String> anyTags,
    required SortSpec sort,
    List<String> noneTags = const [],
  }) async {
    final tagsAny = anyTags.map((t) => t.trim().toLowerCase()).toList();
    final tagsNone = noneTags.map((t) => t.trim().toLowerCase()).toList();

    final q = select(localNotes)..where((n) => n.deleted.equals(false));

    if (tagsAny.isNotEmpty) {
      final sub = selectOnly(noteTags)
        ..where(noteTags.tag.isIn(tagsAny))
        ..addColumns([noteTags.noteId]);
      q.where((n) => n.id.isInQuery(sub));
    }
    if (tagsNone.isNotEmpty) {
      final ex = selectOnly(noteTags)
        ..where(noteTags.tag.isIn(tagsNone))
        ..addColumns([noteTags.noteId]);
      q.where((n) => n.id.isNotInQuery(ex));
    }

    // IMPORTANT: keep your existing pinned-first + sort helper
    _applyPinnedFirstAndSort(q, sort);
    return q.get();
  }

  /// Helper to apply pinned-first and sorting
  void _applyPinnedFirstAndSort(
    SimpleSelectStatement<LocalNotes, LocalNote> q,
    SortSpec sort,
  ) {
    final orderFuncs = <OrderingTerm Function(LocalNotes)>[];

    // Pinned first if enabled
    if (sort.pinnedFirst) {
      orderFuncs.add((n) => OrderingTerm.desc(n.isPinned));
    }

    // Apply sort field
    switch (sort.sortBy) {
      case SortBy.title:
        orderFuncs.add(
          (n) => OrderingTerm(
            expression: n.title,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        );
        break;
      case SortBy.createdAt:
      case SortBy.updatedAt:
      default:
        orderFuncs.add(
          (n) => OrderingTerm(
            expression: n.updatedAt,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        );
        break;
    }

    q.orderBy(orderFuncs);
  }

  /// Search tags by prefix (normalized)
  Future<List<String>> searchTags(String prefix) async {
    if (prefix.trim().isEmpty) return distinctTags();

    final normalizedPrefix = prefix.trim().toLowerCase();

    final rows = await customSelect(
      '''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0 AND t.tag LIKE ?
      ORDER BY t.tag ASC
      LIMIT 20
      ''',
      variables: [Variable('$normalizedPrefix%')],
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
  }

  Future<List<LocalNote>> notesWithTag(String tag) async {
    // Normalize tag for query
    final normalizedTag = tag.trim().toLowerCase();

    final list = await customSelect(
      '''
      SELECT n.*
      FROM local_notes n
      JOIN note_tags t ON n.id = t.note_id
      WHERE n.deleted = 0 AND t.tag = ?
      ORDER BY n.is_pinned DESC, n.updated_at DESC
      ''',
      variables: [Variable(normalizedTag)],
      readsFrom: {localNotes, noteTags},
    ).map<LocalNote>((row) => localNotes.map(row.data)).get();

    return list;
  }

  /// Get notes for saved search with authoritative filtering
  /// Debug method to check metadata content
  Future<void> debugMetadata() async {
    debugPrint('=== DEBUG METADATA ===');
    final allNotes = await select(localNotes).get();
    debugPrint('Total notes: ${allNotes.length}');

    for (final note in allNotes) {
      if (note.encryptedMetadata != null &&
          note.encryptedMetadata!.isNotEmpty) {
        debugPrint('\nNote: ${note.title}');
        debugPrint('Raw metadata: ${note.encryptedMetadata}');

        try {
          final meta = jsonDecode(note.encryptedMetadata!);
          final source = meta['source'];
          if (source != null) {
            debugPrint('  Source: $source');
          }
          if (meta['attachments'] != null) {
            debugPrint('  Has attachments: ${meta['attachments']}');
          }
        } catch (e) {
          debugPrint('  Error parsing: $e');
        }
      }
    }

    // Test simpler queries
    final emailCount = await customSelect(
      "SELECT COUNT(*) as cnt FROM local_notes WHERE encrypted_metadata LIKE '%email_in%'",
    ).getSingle();
    debugPrint('\nNotes with "email_in": ${emailCount.data['cnt']}');

    final webCount = await customSelect(
      "SELECT COUNT(*) as cnt FROM local_notes WHERE encrypted_metadata LIKE '%web%'",
    ).getSingle();
    debugPrint('Notes with "web": ${webCount.data['cnt']}');
  }

  /// Combines metadata, tags, and content checks to prevent false negatives
  Future<List<LocalNote>> notesForSavedSearch({
    required String savedSearchKey,
  }) async {
    String query;

    switch (savedSearchKey) {
      case 'attachments':
        // Get notes with attachments OR tagged #Attachment (case-insensitive)
        query = '''
          SELECT DISTINCT n.*
          FROM local_notes n
          LEFT JOIN note_tags t ON n.id = t.note_id
          WHERE n.deleted = 0 AND (
            -- Has attachment tag (case-insensitive)
            LOWER(t.tag) = 'attachment'
            -- Or has attachments in metadata
            OR n.encrypted_metadata LIKE '%"attachments":%'
            -- Or has #Attachment in body (case-insensitive)
            OR LOWER(n.body) LIKE '%#attachment%'
          )
          ORDER BY n.updated_at DESC
        ''';

      case 'emailNotes':
        // Get notes from email source OR tagged #Email (case-insensitive)
        query = '''
          SELECT DISTINCT n.*
          FROM local_notes n
          LEFT JOIN note_tags t ON n.id = t.note_id
          WHERE n.deleted = 0 AND (
            -- Has email tag (case-insensitive)
            LOWER(t.tag) = 'email'
            -- Or has email source in metadata (with or without spaces in JSON)
            OR n.encrypted_metadata LIKE '%"source"%"email_in"%'
            -- Or has #Email in body (case-insensitive)
            OR LOWER(n.body) LIKE '%#email%'
          )
          ORDER BY n.updated_at DESC
        ''';

      case 'webNotes':
        // Get notes from web source OR tagged #Web (case-insensitive)
        query = '''
          SELECT DISTINCT n.*
          FROM local_notes n
          LEFT JOIN note_tags t ON n.id = t.note_id
          WHERE n.deleted = 0 AND (
            -- Has web tag (case-insensitive)
            LOWER(t.tag) = 'web'
            -- Or has web source in metadata (with or without spaces in JSON)
            OR n.encrypted_metadata LIKE '%"source"%"web"%'
            -- Or has #Web in body (case-insensitive)
            OR LOWER(n.body) LIKE '%#web%'
          )
          ORDER BY n.updated_at DESC
        ''';

      default:
        // Fallback to empty list for unknown keys
        return [];
    }

    final list = await customSelect(
      query,
      readsFrom: {localNotes, noteTags},
    ).map<LocalNote>((row) => localNotes.map(row.data)).get();

    return list;
  }

  /// Helper method to check if a note has attachments (for in-memory filtering)
  static bool noteHasAttachments(LocalNote note) {
    // Check metadata for attachments
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['attachments'] != null) return true;
      } catch (_) {}
    }

    // Check body for #Attachment tag
    return note.body.contains('#Attachment');
  }

  /// Helper method to check if a note is from email source (for in-memory filtering)
  static bool noteIsFromEmail(LocalNote note) {
    // Check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        // Check both old and new format
        if (meta['source'] == 'email_in' || meta['source'] == 'email_inbox') {
          return true;
        }
      } catch (_) {}
    }

    // Check body for #Email tag
    return note.body.contains('#Email');
  }

  /// Helper method to check if a note is from web source (for in-memory filtering)
  static bool noteIsFromWeb(LocalNote note) {
    // Check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'web') return true;
      } catch (_) {}
    }

    // Check body for #Web tag
    return note.body.contains('#Web');
  }

  Future<List<BacklinkPair>> backlinksWithSources(String targetTitle) async {
    final links = await (select(
      noteLinks,
    )..where((l) => l.targetTitle.equals(targetTitle))).get();

    if (links.isEmpty) return const <BacklinkPair>[];

    final sourceIds = links.map((l) => l.sourceId).toSet().toList();
    final sources = await (select(
      localNotes,
    )..where((n) => n.deleted.equals(false) & n.id.isIn(sourceIds))).get();

    final byId = {for (final n in sources) n.id: n};
    return links
        .map((l) => BacklinkPair(link: l, source: byId[l.sourceId]))
        .toList();
  }

  // ----------------------
  // FTS5 support
  // ----------------------
  // Güvenli MATCH ifadesi oluştur
  String _ftsQuery(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) {
          var s = t.replaceAll('"', '').replaceAll("'", '');
          if (!s.endsWith('*')) s = '$s*';
          return s;
        })
        .toList();
    if (parts.isEmpty) return '';
    // Tüm kelimeler eşleşsin
    return parts.join(' AND ');
  }

  /// `#tag` => etiket, diğerleri => FTS5 MATCH (LIKE fallback)
  Future<List<LocalNote>> searchNotes(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      return allNotes();
    }

    String likeWrap(String s) {
      final esc = s.replaceAll('%', r'\%').replaceAll('_', r'\_');
      return '%$esc%';
    }

    if (q.startsWith('#')) {
      final needle = q.substring(1).trim();
      if (needle.isEmpty) return allNotes();

      final tagRows = await (select(
        noteTags,
      )..where((t) => t.tag.like(likeWrap(needle)))).get();

      final ids = tagRows.map((e) => e.noteId).toSet().toList();
      if (ids.isEmpty) return const <LocalNote>[];

      return (select(localNotes)
            ..where((t) => t.deleted.equals(false) & t.id.isIn(ids))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }

    final match = _ftsQuery(q);
    if (match.isEmpty) return allNotes();

    try {
      final res = await customSelect(
        '''
        SELECT n.*
        FROM local_notes n
        JOIN fts_notes f ON n.id = f.id
        WHERE n.deleted = 0
          AND f MATCH ?
        ORDER BY n.updated_at DESC
        ''',
        variables: [Variable(match)],
        readsFrom: {localNotes},
      ).map<LocalNote>((row) => localNotes.map(row.data)).get();

      return res;
    } catch (_) {
      // FTS bir nedenden hata verirse LIKE'a dönüş
      final needle = likeWrap(q);
      return (select(localNotes)
            ..where(
              (t) =>
                  t.deleted.equals(false) &
                  (t.title.like(needle) | t.body.like(needle)),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }
  }

  // ----------------------
  // Advanced Reminders
  // ----------------------

  /// Get all reminders for a specific note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) => (select(
    noteReminders,
  )..where((r) => r.noteId.equals(noteId) & r.isActive.equals(true))).get();

  /// Get a specific reminder by ID
  Future<NoteReminder?> getReminderById(int id) =>
      (select(noteReminders)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Create a new reminder
  Future<int> createReminder(NoteRemindersCompanion reminder) =>
      into(noteReminders).insert(reminder);

  /// Update an existing reminder
  Future<void> updateReminder(int id, NoteRemindersCompanion updates) =>
      (update(noteReminders)..where((r) => r.id.equals(id))).write(updates);

  /// Delete a specific reminder
  Future<void> deleteReminderById(int id) =>
      (delete(noteReminders)..where((r) => r.id.equals(id))).go();

  /// Delete all reminders for a note
  Future<void> deleteRemindersForNote(String noteId) =>
      (delete(noteReminders)..where((r) => r.noteId.equals(noteId))).go();

  /// Get all active time-based reminders due before a specific time
  Future<List<NoteReminder>> getTimeRemindersToTrigger({
    required DateTime before,
  }) =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.time.index) &
                r.isActive.equals(true) &
                r.remindAt.isSmallerOrEqualValue(before) &
                (r.snoozedUntil.isNull() |
                    r.snoozedUntil.isSmallerOrEqualValue(before)),
          ))
          .get();

  /// Get all active location-based reminders
  Future<List<NoteReminder>> getLocationReminders() =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.location.index) &
                r.isActive.equals(true) &
                r.latitude.isNotNull() &
                r.longitude.isNotNull(),
          ))
          .get();

  /// Get all recurring reminders that need to be scheduled
  Future<List<NoteReminder>> getRecurringReminders() =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.recurring.index) &
                r.isActive.equals(true) &
                r.recurrencePattern.isNotValue(RecurrencePattern.none.index),
          ))
          .get();

  // ----------------------
  // Tasks
  // ----------------------

  /// Get all tasks for a specific note
  Future<List<NoteTask>> getTasksForNote(String noteId) =>
      (select(noteTasks)
            ..where((t) => t.noteId.equals(noteId) & t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  /// Get a specific task by ID
  Future<NoteTask?> getTaskById(String id) =>
      (select(noteTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get all open tasks with optional filtering
  Future<List<NoteTask>> getOpenTasks({
    DateTime? dueBefore,
    TaskPriority? priority,
    String? parentTaskId,
  }) {
    final query = select(noteTasks)
      ..where(
        (t) => t.status.equals(TaskStatus.open.index) & t.deleted.equals(false),
      );

    if (dueBefore != null) {
      query.where((t) => t.dueDate.isSmallerOrEqualValue(dueBefore));
    }

    if (priority != null) {
      query.where((t) => t.priority.equals(priority.index));
    }

    if (parentTaskId != null) {
      query.where((t) => t.parentTaskId.equals(parentTaskId));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.dueDate),
      (t) => OrderingTerm.desc(t.priority),
    ]);

    return query.get();
  }

  /// Get tasks by due date range
  Future<List<NoteTask>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.deleted.equals(false) &
                  t.dueDate.isBetweenValues(start, end),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  /// Get overdue tasks
  Future<List<NoteTask>> getOverdueTasks() {
    final now = DateTime.now();
    return (select(noteTasks)
          ..where(
            (t) =>
                t.status.equals(TaskStatus.open.index) &
                t.deleted.equals(false) &
                t.dueDate.isSmallerThanValue(now),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.dueDate),
          ]))
        .get();
  }

  /// Get completed tasks
  Future<List<NoteTask>> getCompletedTasks({DateTime? since, int? limit}) {
    final query = select(noteTasks)
      ..where(
        (t) =>
            t.status.equals(TaskStatus.completed.index) &
            t.deleted.equals(false),
      );

    if (since != null) {
      query.where((t) => t.completedAt.isBiggerOrEqualValue(since));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.completedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  /// Create a new task
  Future<void> createTask(NoteTasksCompanion task) =>
      into(noteTasks).insert(task);

  /// Update an existing task
  Future<void> updateTask(String id, NoteTasksCompanion updates) =>
      (update(noteTasks)..where((t) => t.id.equals(id))).write(updates);

  /// Mark task as completed
  Future<void> completeTask(String id, {String? completedBy}) =>
      (update(noteTasks)..where((t) => t.id.equals(id))).write(
        NoteTasksCompanion(
          status: const Value(TaskStatus.completed),
          completedAt: Value(DateTime.now()),
          completedBy: Value(completedBy),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Toggle task completion status
  Future<void> toggleTaskStatus(String id) async {
    final task = await getTaskById(id);
    if (task != null) {
      final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.open
          : TaskStatus.completed;

      await (update(noteTasks)..where((t) => t.id.equals(id))).write(
        NoteTasksCompanion(
          status: Value(newStatus),
          completedAt: newStatus == TaskStatus.completed
              ? Value(DateTime.now())
              : const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Delete a specific task
  Future<void> deleteTaskById(String id) =>
      (delete(noteTasks)..where((t) => t.id.equals(id))).go();

  /// Delete all tasks for a note
  Future<void> deleteTasksForNote(String noteId) =>
      (delete(noteTasks)..where((t) => t.noteId.equals(noteId))).go();

  /// Sync tasks with note content (called when note is saved)
  Future<void> syncTasksWithNoteContent(
    String noteId,
    String noteContent,
  ) async {
    // Parse note content for checkboxes
    final lines = noteContent.split('\n');
    final taskPositions = <int, _ParsedTask>{};
    var position = 0;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('- [ ]') || trimmedLine.startsWith('- [x]')) {
        final isCompleted = trimmedLine.startsWith('- [x]');
        final content = trimmedLine.substring(5).trim();

        if (content.isNotEmpty) {
          taskPositions[position] = _ParsedTask(
            content: content,
            isCompleted: isCompleted,
          );
          position++;
        }
      }
    }

    // Get existing tasks for this note
    final existingTasks = await getTasksForNote(noteId);
    final existingByPosition = {
      for (final task in existingTasks) task.position: task,
    };

    // Update or create tasks based on parsed content
    for (final entry in taskPositions.entries) {
      final position = entry.key;
      final parsed = entry.value;
      final contentHash = stableTaskHash(noteId, parsed.content);

      final existing = existingByPosition[position];

      if (existing != null) {
        // Update existing task if content or status changed
        if (existing.content != parsed.content ||
            (existing.status == TaskStatus.completed) != parsed.isCompleted) {
          await updateTask(
            existing.id,
            NoteTasksCompanion(
              content: Value(parsed.content),
              contentHash: Value(contentHash),
              status: Value(
                parsed.isCompleted ? TaskStatus.completed : TaskStatus.open,
              ),
              completedAt:
                  parsed.isCompleted && existing.status != TaskStatus.completed
                  ? Value(DateTime.now())
                  : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        existingByPosition.remove(position);
      } else {
        // Create new task
        final taskId = '${noteId}_task_$position';
        await createTask(
          NoteTasksCompanion.insert(
            id: taskId,
            noteId: noteId,
            content: parsed.content,
            contentHash: contentHash,
            status: Value(
              parsed.isCompleted ? TaskStatus.completed : TaskStatus.open,
            ),
            position: Value(position),
            completedAt: parsed.isCompleted
                ? Value(DateTime.now())
                : const Value.absent(),
          ),
        );
      }
    }

    // Mark removed tasks as deleted
    for (final task in existingByPosition.values) {
      await (update(noteTasks)..where((t) => t.id.equals(task.id))).write(
        NoteTasksCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Watch all open tasks (for UI updates)
  Stream<List<NoteTask>> watchOpenTasks() =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.status.equals(TaskStatus.open.index) &
                  t.deleted.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.dueDate),
              (t) => OrderingTerm.desc(t.priority),
            ]))
          .watch();

  /// Watch tasks for a specific note
  Stream<List<NoteTask>> watchTasksForNote(String noteId) =>
      (select(noteTasks)
            ..where((t) => t.noteId.equals(noteId) & t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  /// Get snoozed reminders that are ready to be rescheduled
  Future<List<NoteReminder>> getSnoozedRemindersToReschedule({
    required DateTime now,
  }) =>
      (select(noteReminders)..where(
            (r) =>
                r.isActive.equals(true) &
                r.snoozedUntil.isNotNull() &
                r.snoozedUntil.isSmallerOrEqualValue(now),
          ))
          .get();

  /// Mark a reminder as triggered
  Future<void> markReminderTriggered(int id, {DateTime? triggeredAt}) =>
      (update(noteReminders)..where((r) => r.id.equals(id))).write(
        NoteRemindersCompanion(
          lastTriggered: Value(triggeredAt ?? DateTime.now().toUtc()),
          // Note: trigger_count will be incremented by database trigger
        ),
      );

  /// Snooze a reminder
  Future<void> snoozeReminder(int id, DateTime snoozeUntil) =>
      (update(noteReminders)..where((r) => r.id.equals(id))).write(
        NoteRemindersCompanion(
          snoozedUntil: Value(snoozeUntil),
          // Note: snooze_count will be incremented by database trigger
        ),
      );

  /// Clear snooze for a reminder
  Future<void> clearSnooze(int id) =>
      (update(noteReminders)..where((r) => r.id.equals(id))).write(
        const NoteRemindersCompanion(snoozedUntil: Value(null)),
      );

  /// Deactivate a reminder
  Future<void> deactivateReminder(int id) =>
      (update(noteReminders)..where((r) => r.id.equals(id))).write(
        const NoteRemindersCompanion(isActive: Value(false)),
      );

  /// Get all reminders (for debugging/admin)
  Future<List<NoteReminder>> getAllReminders({bool activeOnly = false}) {
    final query = select(noteReminders);
    if (activeOnly) {
      query.where((r) => r.isActive.equals(true));
    }
    query.orderBy([(r) => OrderingTerm.desc(r.createdAt)]);
    return query.get();
  }

  /// Clean up reminders for deleted notes
  Future<void> cleanupOrphanedReminders() async {
    await customStatement('''
      DELETE FROM note_reminders 
      WHERE note_id NOT IN (
        SELECT id FROM local_notes WHERE deleted = 0
      )
    ''');
  }

  /// Get reminder statistics for analytics
  Future<Map<String, int>> getReminderStats() async {
    final result = await customSelect('''
      SELECT 
        type,
        COUNT(*) as count
      FROM note_reminders 
      WHERE is_active = 1
      GROUP BY type
    ''').get();

    final stats = <String, int>{};
    for (final row in result) {
      final type = ReminderType.values[row.read<int>('type')];
      final count = row.read<int>('count');
      stats[type.name] = count;
    }
    return stats;
  }

  /// ----------------------
  /// Folder Migration Methods (v5 → v6)
  /// ----------------------

  /// Create indexes for folder performance
  Future<void> _createFolderIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_folders_parent_id ON local_folders(parent_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_folders_path ON local_folders(path)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_folders_deleted ON local_folders(deleted)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_folders_sort_order ON local_folders(parent_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_folders_folder_id ON note_folders(folder_id)',
    );
  }

  Future<void> _createTaskIndexes() async {
    // Index for finding tasks by note
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_note_id ON note_tasks(note_id)',
    );
    // Index for finding open tasks by due date
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date ON note_tasks(due_date) WHERE status = 0 AND deleted = 0',
    );
    // Index for finding tasks by status
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_status ON note_tasks(status) WHERE deleted = 0',
    );
    // Index for finding tasks with reminders
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_reminder_id ON note_tasks(reminder_id) WHERE reminder_id IS NOT NULL',
    );
    // Index for finding subtasks
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_parent ON note_tasks(parent_task_id) WHERE parent_task_id IS NOT NULL',
    );
  }

  Future<void> _extractTasksFromExistingNotes() async {
    // Extract tasks from existing notes that have checkboxes
    final notes = await (select(
      localNotes,
    )..where((n) => n.deleted.equals(false))).get();

    for (final note in notes) {
      // Parse note body for checkbox patterns
      final lines = note.body.split('\n');
      var position = 0;

      for (final line in lines) {
        final trimmedLine = line.trim();

        // Check for markdown checkbox patterns
        if (trimmedLine.startsWith('- [ ]') ||
            trimmedLine.startsWith('- [x]')) {
          final isCompleted = trimmedLine.startsWith('- [x]');
          final content = trimmedLine.substring(5).trim();

          if (content.isNotEmpty) {
            final taskId = '${note.id}_task_$position';
            // Use stable hash for content
            final contentHash = stableTaskHash(note.id, content);

            // Insert task into database
            await into(noteTasks).insertOnConflictUpdate(
              NoteTasksCompanion.insert(
                id: taskId,
                noteId: note.id,
                content: content,
                status: Value(
                  isCompleted ? TaskStatus.completed : TaskStatus.open,
                ),
                position: Value(position),
                contentHash: contentHash,
                completedAt: isCompleted
                    ? Value(DateTime.now())
                    : const Value.absent(),
              ),
            );

            position++;
          }
        }
      }
    }
  }

  Future<void> _backfillTaskContentHash() async {
    // Backfill content_hash for any existing tasks with stable hash
    final tasks = await (select(
      noteTasks,
    )..where((t) => t.deleted.equals(false))).get();

    for (final task in tasks) {
      // Only update if content_hash seems to be using old hashCode
      if (task.contentHash == task.content.hashCode.toString()) {
        final stableHash = stableTaskHash(task.noteId, task.content);

        await (update(noteTasks)..where((t) => t.id.equals(task.id))).write(
          NoteTasksCompanion(contentHash: Value(stableHash)),
        );
      }
    }
  }

  /// Update FTS to include folder path information
  Future<void> _updateFtsForFolders() async {
    // Drop existing FTS table
    await customStatement('DROP TABLE IF EXISTS fts_notes');

    // Create new FTS table with folder_path
    await customStatement(
      'CREATE VIRTUAL TABLE fts_notes USING fts5(id UNINDEXED, title, body, folder_path UNINDEXED)',
    );

    // Recreate FTS triggers with folder support
    await _createFtsTriggers();

    // Repopulate FTS with existing data (no folders initially)
    await customStatement('''
      INSERT INTO fts_notes(id, title, body, folder_path)
      SELECT id, title, body, '' 
      FROM local_notes 
      WHERE deleted = 0
    ''');
  }

  /// Create default folder structure
  Future<void> _createDefaultFolders() async {
    // Create system folders (optional - could be created on first use instead)
    // For now, we'll leave existing notes unfiled
    debugPrint('📁 Folder system initialized - existing notes remain unfiled');
  }

  /// Create triggers to keep fts_notes.folder_path in sync with folder changes
  Future<void> _createFolderSyncTriggers() async {
    // Trigger: When a note is mapped to a folder, update fts_notes.folder_path
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_note_folders_ai
      AFTER INSERT ON note_folders
      BEGIN
        UPDATE fts_notes
        SET folder_path = (SELECT path FROM local_folders WHERE id = NEW.folder_id)
        WHERE id = NEW.note_id;
      END;
    ''');

    // Trigger: When a note's folder mapping is updated
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_note_folders_au
      AFTER UPDATE ON note_folders
      BEGIN
        UPDATE fts_notes
        SET folder_path = (SELECT path FROM local_folders WHERE id = NEW.folder_id)
        WHERE id = NEW.note_id;
      END;
    ''');

    // Trigger: When a note is removed from a folder
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_note_folders_ad
      AFTER DELETE ON note_folders
      BEGIN
        UPDATE fts_notes 
        SET folder_path = NULL 
        WHERE id = OLD.note_id;
      END;
    ''');

    // Trigger: When a folder's path changes (rename/move), update all affected notes in FTS
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_folders_au_path
      AFTER UPDATE OF name, parent_id, path ON local_folders
      BEGIN
        UPDATE fts_notes
        SET folder_path = NEW.path
        WHERE id IN (
          SELECT note_id 
          FROM note_folders 
          WHERE folder_id = NEW.id
        );
      END;
    ''');
  }

  /// Create indexes for saved searches table
  Future<void> _createSavedSearchIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_saved_searches_pinned '
      'ON saved_searches(is_pinned DESC, sort_order ASC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_saved_searches_usage '
      'ON saved_searches(usage_count DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_saved_searches_type '
      'ON saved_searches(search_type)',
    );
  }

  /// Sync existing folder paths to FTS for notes already in folders
  Future<void> _syncExistingFolderPaths() async {
    // Update FTS entries for notes that are already in folders
    await customStatement('''
      UPDATE fts_notes
      SET folder_path = (
        SELECT lf.path 
        FROM local_folders lf
        JOIN note_folders nf ON nf.folder_id = lf.id
        WHERE nf.note_id = fts_notes.id
      )
      WHERE EXISTS (
        SELECT 1 
        FROM note_folders nf 
        WHERE nf.note_id = fts_notes.id
      )
    ''');
  }

  /// ----------------------
  /// Folder CRUD Operations
  /// ----------------------

  /// Get all root folders (parent_id is null)
  Future<List<LocalFolder>> getRootFolders() {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.parentId.isNull())
          ..orderBy([
            (f) => OrderingTerm.asc(f.sortOrder),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .get();
  }

  /// Get child folders of a parent
  Future<List<LocalFolder>> getChildFolders(String parentId) {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.parentId.equals(parentId))
          ..orderBy([
            (f) => OrderingTerm.asc(f.sortOrder),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .get();
  }

  /// Get folder by ID
  Future<LocalFolder?> getFolderById(String id) {
    return (select(
      localFolders,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  /// Insert or update folder
  Future<void> upsertFolder(LocalFolder folder) async {
    await into(localFolders).insertOnConflictUpdate(folder);
  }

  /// Get count of notes in a specific folder
  Future<int> getNotesCountInFolder(String folderId) async {
    final countExp = localNotes.id.count();
    final query = selectOnly(localNotes)
      ..join([
        leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id)),
      ])
      ..where(
        localNotes.deleted.equals(false) &
            noteFolders.folderId.equals(folderId),
      )
      ..addColumns([countExp]);

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Get notes in a specific folder
  Future<List<LocalNote>> getNotesInFolder(
    String folderId, {
    int? limit,
    DateTime? cursor,
  }) {
    final query =
        select(localNotes).join([
          leftOuterJoin(
            noteFolders,
            noteFolders.noteId.equalsExp(localNotes.id),
          ),
        ])..where(
          localNotes.deleted.equals(false) &
              noteFolders.folderId.equals(folderId),
        );

    if (cursor != null) {
      query.where(localNotes.updatedAt.isSmallerThanValue(cursor));
    }

    query.orderBy([OrderingTerm.desc(localNotes.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.map((row) => row.readTable(localNotes)).get();
  }

  /// Batch fetch note counts for all folders
  Future<Map<String, int>> getFolderNoteCounts() async {
    final counts = <String, int>{};
    final folderIdColumn = noteFolders.folderId;
    final countColumn = folderIdColumn.count();

    final query =
        await (selectOnly(noteFolders)
              ..join([
                innerJoin(
                  localNotes,
                  localNotes.id.equalsExp(noteFolders.noteId),
                ),
              ])
              ..where(localNotes.deleted.equals(false))
              ..addColumns([folderIdColumn, countColumn])
              ..groupBy([folderIdColumn]))
            .get();

    for (final row in query) {
      final folderId = row.read(folderIdColumn);
      final count = row.read(countColumn) ?? 0;
      if (folderId != null) {
        counts[folderId] = count;
      }
    }

    return counts;
  }

  /// Remove orphaned note-folder relationships (notes or folders deleted)
  Future<void> cleanupOrphanedRelationships() async {
    final relations = await select(noteFolders).get();

    for (final rel in relations) {
      final note = await getNote(rel.noteId);
      final folder = await (select(
        localFolders,
      )..where((f) => f.id.equals(rel.folderId))).getSingleOrNull();

      if (note == null || folder == null) {
        await (delete(noteFolders)..where(
              (nf) =>
                  nf.noteId.equals(rel.noteId) &
                  nf.folderId.equals(rel.folderId),
            ))
            .go();
      }
    }
  }

  /// Get a single note by ID
  Future<LocalNote?> getNote(String id) =>
      (select(localNotes)..where((n) => n.id.equals(id))).getSingleOrNull();

  /// Watch a single note for changes
  Stream<LocalNote?> watchNote(String id) =>
      (select(localNotes)..where((n) => n.id.equals(id))).watchSingleOrNull();

  /// Update a note
  Future<void> updateNote(String id, LocalNotesCompanion updates) =>
      (update(localNotes)..where((n) => n.id.equals(id))).write(updates);

  /// Get unfiled notes (not in any folder)
  Future<List<LocalNote>> getUnfiledNotes({int? limit, DateTime? cursor}) {
    final query = select(localNotes).join([
      leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id)),
    ])..where(localNotes.deleted.equals(false) & noteFolders.noteId.isNull());

    if (cursor != null) {
      query.where(localNotes.updatedAt.isSmallerThanValue(cursor));
    }

    query.orderBy([OrderingTerm.desc(localNotes.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.map((row) => row.readTable(localNotes)).get();
  }

  /// Move note to folder
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    if (folderId != null) {
      // Add to folder
      await into(noteFolders).insertOnConflictUpdate(
        NoteFoldersCompanion.insert(
          noteId: noteId,
          folderId: folderId,
          addedAt: DateTime.now(),
        ),
      );
    } else {
      // Remove from folder (move to unfiled)
      await (delete(noteFolders)..where((nf) => nf.noteId.equals(noteId))).go();
    }
  }

  /// Get note IDs in a specific folder
  Future<List<String>> getNoteIdsInFolder(String folderId) async {
    final query = select(noteFolders)
      ..where((nf) => nf.folderId.equals(folderId));

    final results = await query.get();
    return results.map((nf) => nf.noteId).toList();
  }

  /// Get folder for a specific note
  Future<LocalFolder?> getNoteFolder(String noteId) async {
    final query = select(localFolders).join([
      innerJoin(noteFolders, noteFolders.folderId.equalsExp(localFolders.id)),
    ])..where(noteFolders.noteId.equals(noteId));

    final result = await query.getSingleOrNull();
    return result?.readTable(localFolders);
  }

  /// Generate folder path string
  Future<String> generateFolderPath(String folderId) async {
    final pathParts = <String>[];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = await getFolderById(currentId);
      if (folder == null) break;

      pathParts.insert(0, folder.name);
      currentId = folder.parentId;
    }

    return '/${pathParts.join('/')}';
  }

  // ==========================================
  // ADDITIONAL FOLDER METHODS FOR REPOSITORY
  // ==========================================

  /// Find folder by ID (alias for getFolderById for repository compatibility)
  Future<LocalFolder?> findFolder(String id) => getFolderById(id);

  /// Get all folders (active and deleted for sync purposes)
  Future<List<LocalFolder>> allFolders() {
    return (select(
      localFolders,
    )..orderBy([(f) => OrderingTerm.asc(f.path)])).get();
  }

  /// Get all active folders
  Future<List<LocalFolder>> getActiveFolders() {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.path)]))
        .get();
  }

  /// Get folder for a specific note (alias for getNoteFolder)
  Future<LocalFolder?> getFolderForNote(String noteId) => getNoteFolder(noteId);

  /// Remove note from any folder
  Future<void> removeNoteFromFolder(String noteId) async {
    await (delete(noteFolders)..where((nf) => nf.noteId.equals(noteId))).go();
  }

  /// Upsert note-folder relationship
  Future<void> upsertNoteFolder(NoteFolder relationship) async {
    await into(noteFolders).insertOnConflictUpdate(relationship);
  }

  /// Get all note-folder relationships
  Future<List<NoteFolder>> getAllNoteFolderRelationships() {
    return select(noteFolders).get();
  }

  /// Get local active note IDs (for repository sync)
  Future<Set<String>> getActiveNoteIds() async {
    final notes = await (select(
      localNotes,
    )..where((n) => n.deleted.equals(false))).get();
    return notes.map((n) => n.id).toSet();
  }

  /// Get local active folder IDs
  Future<Set<String>> getLocalActiveFolderIds() async {
    final folders = await (select(
      localFolders,
    )..where((f) => f.deleted.equals(false))).get();
    return folders.map((f) => f.id).toSet();
  }

  /// Get recently updated folders
  Future<List<LocalFolder>> getRecentlyUpdatedFolders({
    required DateTime since,
  }) {
    return (select(localFolders)
          ..where((f) => f.updatedAt.isBiggerThanValue(since))
          ..orderBy([(f) => OrderingTerm.desc(f.updatedAt)]))
        .get();
  }

  /// Get folders by parent ID (including null for root folders)
  Future<List<LocalFolder>> getFoldersByParent(String? parentId) {
    if (parentId == null) {
      return getRootFolders();
    } else {
      return getChildFolders(parentId);
    }
  }

  /// Count notes in folder
  Future<int> countNotesInFolder(String folderId) async {
    final query = selectOnly(noteFolders)
      ..addColumns([noteFolders.noteId.count()])
      ..where(noteFolders.folderId.equals(folderId));

    final result = await query.getSingleOrNull();
    return result?.read(noteFolders.noteId.count()) ?? 0;
  }

  /// Get folder hierarchy depth
  Future<int> getFolderDepth(String folderId) async {
    var depth = 0;
    String? currentId = folderId;

    while (currentId != null && depth < 100) {
      // Safety limit
      final folder = await findFolder(currentId);
      if (folder == null || folder.parentId == null) break;

      currentId = folder.parentId;
      depth++;
    }

    return depth;
  }

  /// Check if folder has children
  Future<bool> hasChildFolders(String folderId) async {
    final children = await getChildFolders(folderId);
    return children.isNotEmpty;
  }

  /// Get complete folder tree starting from a root
  Future<List<LocalFolder>> getFolderSubtree(String rootId) async {
    final result = <LocalFolder>[];
    final root = await findFolder(rootId);
    if (root != null) {
      result.add(root);

      final children = await getChildFolders(rootId);
      for (final child in children) {
        final subtree = await getFolderSubtree(child.id);
        result.addAll(subtree);
      }
    }
    return result;
  }

  /// Search folders by name
  Future<List<LocalFolder>> searchFolders(String query) {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.name.contains(query))
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  /// Find folder by exact name
  Future<LocalFolder?> findFolderByName(String name) async {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.name.equals(name)))
        .getSingleOrNull();
  }

  // ----------------------
  // Saved Searches CRUD
  // ----------------------

  /// Create or update a saved search
  Future<void> upsertSavedSearch(SavedSearch search) async {
    await into(savedSearches).insertOnConflictUpdate(search);
  }

  /// Get all saved searches ordered by pinned status and sort order
  Future<List<SavedSearch>> getSavedSearches() {
    return (select(savedSearches)..orderBy([
          (s) => OrderingTerm.desc(s.isPinned),
          (s) => OrderingTerm.asc(s.sortOrder),
          (s) => OrderingTerm.desc(s.usageCount),
        ]))
        .get();
  }

  /// Get saved searches by type
  Future<List<SavedSearch>> getSavedSearchesByType(String searchType) {
    return (select(savedSearches)
          ..where((s) => s.searchType.equals(searchType))
          ..orderBy([
            (s) => OrderingTerm.desc(s.isPinned),
            (s) => OrderingTerm.asc(s.sortOrder),
          ]))
        .get();
  }

  /// Get a saved search by ID
  Future<SavedSearch?> getSavedSearchById(String id) {
    return (select(
      savedSearches,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String id) async {
    await (delete(savedSearches)..where((s) => s.id.equals(id))).go();
  }

  /// Update usage statistics for a saved search
  Future<void> updateSavedSearchUsage(String id) async {
    final search = await getSavedSearchById(id);
    if (search != null) {
      await into(savedSearches).insertOnConflictUpdate(
        search.copyWith(
          lastUsedAt: Value(DateTime.now()),
          usageCount: search.usageCount + 1,
        ),
      );
    }
  }

  /// Pin/unpin a saved search
  Future<void> toggleSavedSearchPin(String id) async {
    final search = await getSavedSearchById(id);
    if (search != null) {
      await into(
        savedSearches,
      ).insertOnConflictUpdate(search.copyWith(isPinned: !search.isPinned));
    }
  }

  /// Reorder saved searches
  Future<void> reorderSavedSearches(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final search = await getSavedSearchById(orderedIds[i]);
      if (search != null) {
        await into(
          savedSearches,
        ).insertOnConflictUpdate(search.copyWith(sortOrder: i));
      }
    }
  }

  /// Watch saved searches stream
  Stream<List<SavedSearch>> watchSavedSearches() {
    return (select(savedSearches)..orderBy([
          (s) => OrderingTerm.desc(s.isPinned),
          (s) => OrderingTerm.asc(s.sortOrder),
          (s) => OrderingTerm.desc(s.usageCount),
        ]))
        .watch();
  }

  /// Get pinned saved searches
  Future<List<SavedSearch>> getPinnedSavedSearches() {
    return (select(savedSearches)
          ..where((s) => s.isPinned.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
  }
}

/// Helper class for parsing tasks from markdown
class _ParsedTask {
  const _ParsedTask({required this.content, required this.isCompleted});
  final String content;
  final bool isCompleted;
}

/// ----------------------
/// Connection (mobile)
/// ----------------------
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'duru.sqlite'));
    return NativeDatabase(file);
  });
}
