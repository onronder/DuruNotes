import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get kind => text()(); // 'upsert_note' | 'delete_note'
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
  time,      // Time-based reminder
  location,  // Location-based reminder (geofence)
  recurring, // Recurring reminder
}

// Recurring patterns
enum RecurrencePattern {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

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
  DateTimeColumn get remindAt => dateTime().nullable()(); // for time-based reminders (UTC)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  // Location-based fields
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get radius => real().nullable()(); // in meters
  TextColumn get locationName => text().nullable()();
  
  // Recurring reminder fields
  IntColumn get recurrencePattern => intEnum<RecurrencePattern>().withDefault(Constant(RecurrencePattern.none.index))();
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();
  IntColumn get recurrenceInterval => integer().withDefault(const Constant(1))(); // every X days/weeks/months
  
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

/// ----------------------
/// Database
/// ----------------------
@DriftDatabase(tables: [LocalNotes, PendingOps, NoteTags, NoteLinks, NoteReminders, LocalFolders, NoteFolders])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // FTS tablosu
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS fts_notes USING fts5(id UNINDEXED, title, body)',
          );

          // Tetikleyiciler: local_notes <-> fts_notes senkron
          await _createFtsTriggers();

          // İndeksler
          await _createIndexes();
          await _createReminderIndexes();

          // Mevcut veriyi FTS’ye tohumla
          await customStatement(
            'INSERT INTO fts_notes(id, title, body) '
            'SELECT id, title, body FROM local_notes WHERE deleted = 0',
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
    // INSERT -> fts’ye ekle (silinmiş değilse)
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ai
      AFTER INSERT ON local_notes
      BEGIN
        INSERT INTO fts_notes(id, title, body)
        SELECT NEW.id, NEW.title, NEW.body WHERE NEW.deleted = 0;
      END;
    ''');

    // UPDATE -> fts’yi güncelle / sil
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_au
      AFTER UPDATE ON local_notes
      BEGIN
        DELETE FROM fts_notes WHERE id = NEW.id;
        INSERT INTO fts_notes(id, title, body)
        SELECT NEW.id, NEW.title, NEW.body WHERE NEW.deleted = 0;
      END;
    ''');

    // DELETE -> fts’den sil
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
          ..where((t) =>
              t.deleted.equals(false) &
              (t.title.like(startsWith) | t.title.like(wordStart)))
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
    final ops = await (select(pendingOps)
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
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
    final rows =
        await (select(localNotes)..where((t) => t.deleted.equals(false))).get();
    return rows.map((e) => e.id).toSet();
  }

  // ----------------------
  // Tags & Links index
  // ----------------------
  Future<void> replaceTagsForNote(String noteId, Set<String> tags) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      if (tags.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            noteTags,
            tags.map(
              (t) => NoteTagsCompanion.insert(noteId: noteId, tag: t),
            ),
          );
        });
      }
    });
  }

  Future<void> replaceLinksForNote(String noteId, List<Map<String, String?>> links) async {
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

  /// Get tags with their note counts
  Future<List<TagCount>> getTagsWithCounts() async {
    final rows = await customSelect(
      '''
      SELECT t.tag AS tag, COUNT(DISTINCT t.note_id) AS count
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0
      GROUP BY t.tag
      ORDER BY LOWER(t.tag) ASC
      ''',
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => TagCount(
      tag: r.read<String>('tag'),
      count: r.read<int>('count'),
    )).toList();
  }

  /// Search tags by prefix
  Future<List<String>> searchTags(String prefix) async {
    if (prefix.trim().isEmpty) return distinctTags();
    
    final rows = await customSelect(
      '''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0 AND LOWER(t.tag) LIKE LOWER(?)
      ORDER BY LOWER(t.tag) ASC
      LIMIT 20
      ''',
      variables: [Variable('${prefix.trim()}%')],
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
  }

  Future<List<LocalNote>> notesWithTag(String tag) async {
    final list = await customSelect(
      '''
      SELECT n.*
      FROM local_notes n
      JOIN note_tags t ON n.id = t.note_id
      WHERE n.deleted = 0 AND t.tag = ?
      ORDER BY n.updated_at DESC
      ''',
      variables: [Variable(tag)],
      readsFrom: {localNotes, noteTags},
    ).map<LocalNote>((row) => localNotes.map(row.data)).get();

    return list;
  }

  Future<List<BacklinkPair>> backlinksWithSources(String targetTitle) async {
    final links = await (select(noteLinks)
          ..where((l) => l.targetTitle.equals(targetTitle)))
        .get();

    if (links.isEmpty) return const <BacklinkPair>[];

    final sourceIds = links.map((l) => l.sourceId).toSet().toList();
    final sources = await (select(localNotes)
          ..where((n) => n.deleted.equals(false) & n.id.isIn(sourceIds)))
        .get();

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
    }).toList();
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

      final tagRows = await (select(noteTags)
            ..where((t) => t.tag.like(likeWrap(needle))))
          .get();

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
            ..where((t) =>
                t.deleted.equals(false) &
                (t.title.like(needle) | t.body.like(needle)))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
    }
  }

  // ----------------------
  // Advanced Reminders
  // ----------------------
  
  /// Get all reminders for a specific note
  Future<List<NoteReminder>> getRemindersForNote(String noteId) =>
      (select(noteReminders)..where((r) => r.noteId.equals(noteId) & r.isActive.equals(true)))
          .get();

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
  Future<List<NoteReminder>> getTimeRemindersToTrigger({required DateTime before}) =>
      (select(noteReminders)
            ..where((r) => 
                r.type.equals(ReminderType.time.index) &
                r.isActive.equals(true) &
                r.remindAt.isSmallerOrEqualValue(before) &
                (r.snoozedUntil.isNull() | r.snoozedUntil.isSmallerOrEqualValue(before))))
          .get();

  /// Get all active location-based reminders
  Future<List<NoteReminder>> getLocationReminders() =>
      (select(noteReminders)
            ..where((r) => 
                r.type.equals(ReminderType.location.index) &
                r.isActive.equals(true) &
                r.latitude.isNotNull() &
                r.longitude.isNotNull()))
          .get();

  /// Get all recurring reminders that need to be scheduled
  Future<List<NoteReminder>> getRecurringReminders() =>
      (select(noteReminders)
            ..where((r) => 
                r.type.equals(ReminderType.recurring.index) &
                r.isActive.equals(true) &
                r.recurrencePattern.isNotValue(RecurrencePattern.none.index)))
          .get();

  /// Get snoozed reminders that are ready to be rescheduled
  Future<List<NoteReminder>> getSnoozedRemindersToReschedule({required DateTime now}) =>
      (select(noteReminders)
            ..where((r) => 
                r.isActive.equals(true) &
                r.snoozedUntil.isNotNull() &
                r.snoozedUntil.isSmallerOrEqualValue(now)))
          .get();

  /// Mark a reminder as triggered
  Future<void> markReminderTriggered(int id, {DateTime? triggeredAt}) =>
      (update(noteReminders)..where((r) => r.id.equals(id)))
          .write(NoteRemindersCompanion(
            lastTriggered: Value(triggeredAt ?? DateTime.now().toUtc()),
                          // Note: trigger_count will be incremented by database trigger
          ));

  /// Snooze a reminder
  Future<void> snoozeReminder(int id, DateTime snoozeUntil) =>
      (update(noteReminders)..where((r) => r.id.equals(id)))
          .write(NoteRemindersCompanion(
            snoozedUntil: Value(snoozeUntil),
                           // Note: snooze_count will be incremented by database trigger
          ));

  /// Clear snooze for a reminder
  Future<void> clearSnooze(int id) =>
      (update(noteReminders)..where((r) => r.id.equals(id)))
          .write(const NoteRemindersCompanion(
            snoozedUntil: Value(null),
          ));

  /// Deactivate a reminder
  Future<void> deactivateReminder(int id) =>
      (update(noteReminders)..where((r) => r.id.equals(id)))
          .write(const NoteRemindersCompanion(
            isActive: Value(false),
          ));

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
    print('📁 Folder system initialized - existing notes remain unfiled');
  }

  /// ----------------------
  /// Folder CRUD Operations  
  /// ----------------------
  
  /// Get all root folders (parent_id is null)
  Future<List<LocalFolder>> getRootFolders() {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.parentId.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder), (f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  /// Get child folders of a parent
  Future<List<LocalFolder>> getChildFolders(String parentId) {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & f.parentId.equals(parentId))
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder), (f) => OrderingTerm.asc(f.name)]))
        .get();
  }

  /// Get folder by ID
  Future<LocalFolder?> getFolderById(String id) {
    return (select(localFolders)..where((f) => f.id.equals(id))).getSingleOrNull();
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
      ..where(localNotes.deleted.equals(false) & noteFolders.folderId.equals(folderId))
      ..addColumns([countExp]);
    
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Get notes in a specific folder
  Future<List<LocalNote>> getNotesInFolder(String folderId, {int? limit, DateTime? cursor}) {
    final query = select(localNotes).join([
      leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id)),
    ])
      ..where(localNotes.deleted.equals(false) & noteFolders.folderId.equals(folderId));
    
    if (cursor != null) {
      query.where(localNotes.updatedAt.isSmallerThanValue(cursor));
    }
    
    query.orderBy([OrderingTerm.desc(localNotes.updatedAt)]);
    
    if (limit != null) {
      query.limit(limit);
    }

    return query.map((row) => row.readTable(localNotes)).get();
  }

  /// Get unfiled notes (not in any folder)
  Future<List<LocalNote>> getUnfiledNotes({int? limit, DateTime? cursor}) {
    final query = select(localNotes).join([
      leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id)),
    ])
      ..where(localNotes.deleted.equals(false) & noteFolders.noteId.isNull());
    
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
    return (select(localFolders)
          ..orderBy([(f) => OrderingTerm.asc(f.path)]))
        .get();
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
    final notes = await (select(localNotes)
          ..where((n) => n.deleted.equals(false)))
        .get();
    return notes.map((n) => n.id).toSet();
  }

  /// Get local active folder IDs
  Future<Set<String>> getLocalActiveFolderIds() async {
    final folders = await (select(localFolders)
          ..where((f) => f.deleted.equals(false)))
        .get();
    return folders.map((f) => f.id).toSet();
  }

  /// Get recently updated folders
  Future<List<LocalFolder>> getRecentlyUpdatedFolders({required DateTime since}) {
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

    while (currentId != null && depth < 100) { // Safety limit
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
          ..where((f) => f.deleted.equals(false) & 
                         f.name.contains(query))
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .get();
  }
  
  /// Find folder by exact name
  Future<LocalFolder?> findFolderByName(String name) async {
    return (select(localFolders)
          ..where((f) => f.deleted.equals(false) & 
                         f.name.equals(name)))
        .getSingleOrNull();
  }
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
