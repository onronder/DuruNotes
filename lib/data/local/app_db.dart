import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/data/migrations/migration_12_phase3_optimization.dart';
import 'package:duru_notes/data/migrations/migration_23_local_encryption.dart';
import 'package:duru_notes/data/migrations/migration_24_drop_plaintext_columns.dart';
import 'package:duru_notes/data/migrations/migration_26_saved_searches_userid.dart';
import 'package:duru_notes/data/migrations/migration_27_performance_indexes.dart';
import 'package:duru_notes/data/migrations/migration_32_phase1_performance_indexes.dart';
import 'package:duru_notes/data/migrations/migration_33_pending_ops_userid.dart';
import 'package:duru_notes/data/migrations/migration_34_note_tasks_userid.dart';
import 'package:duru_notes/data/migrations/migration_37_note_tags_links_userid.dart';
import 'package:duru_notes/data/migrations/migration_38_note_folders_userid.dart';
import 'package:duru_notes/models/note_kind.dart';

part 'app_db.g.dart';

/// ----------------------
/// Table definitions
/// ----------------------
@DataClassName('LocalNote')
class LocalNotes extends Table {
  TextColumn get id => text()();

  // ENCRYPTED COLUMNS (Post-Migration 24 - Security Fix)
  // Note: plaintext title/body columns removed for zero-knowledge architecture
  TextColumn get titleEncrypted =>
      text().named('title_encrypted').withDefault(const Constant(''))();
  TextColumn get bodyEncrypted =>
      text().named('body_encrypted').withDefault(const Constant(''))();
  TextColumn get metadataEncrypted =>
      text().named('metadata_encrypted').nullable()();
  IntColumn get encryptionVersion =>
      integer().named('encryption_version').withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get encryptedMetadata => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(
    const Constant(false),
  )(); // For pinning notes to top
  IntColumn get noteType => intEnum<NoteKind>().withDefault(
    const Constant(0),
  )(); // 0=note, 1=template

  // Added for domain model migration
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get userId => text().nullable()();
  TextColumn get attachmentMeta => text().nullable()();
  TextColumn get metadata => text().nullable()();

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
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {noteId, tag};
}

@DataClassName('NoteLink')
class NoteLinks extends Table {
  TextColumn get sourceId => text()();
  TextColumn get targetTitle => text()();
  TextColumn get targetId => text().nullable()();
  TextColumn get userId => text()();

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

  /// User ID who owns this reminder (P0.5 SECURITY: prevents cross-user access)
  TextColumn get userId => text()();

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

  /// User ID who owns this task (mirrors parent note ownership)
  TextColumn get userId => text()();

  // ENCRYPTED COLUMNS (Post-Migration 24 - Security Fix)
  // Note: plaintext content/labels/notes columns removed for zero-knowledge architecture
  TextColumn get contentEncrypted => text().named('content_encrypted')();
  TextColumn get labelsEncrypted =>
      text().named('labels_encrypted').nullable()();
  TextColumn get notesEncrypted => text().named('notes_encrypted').nullable()();
  IntColumn get encryptionVersion =>
      integer().named('encryption_version').withDefault(const Constant(1))();

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

  /// User ID who owns this folder
  TextColumn get userId => text()();

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
@TableIndex(name: 'idx_note_folders_note', columns: {#noteId})
@TableIndex(name: 'idx_note_folders_folder', columns: {#folderId})
@TableIndex(
  name: 'idx_note_folders_folder_updated',
  columns: {#folderId, #updatedAt},
)
class NoteFolders extends Table {
  /// Note ID (foreign key to local_notes)
  TextColumn get noteId => text()();

  /// Folder ID (foreign key to local_folders)
  TextColumn get folderId => text()();

  /// When the note was added to this folder
  DateTimeColumn get addedAt => dateTime()();

  /// Last update timestamp for sorting and performance indexes
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// User ID who owns this relationship
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {noteId}; // One folder per note
}

/// Saved searches table for persisting user-defined queries/chips
@DataClassName('SavedSearch')
class SavedSearches extends Table {
  /// Unique identifier for the saved search
  TextColumn get id => text()();

  /// User ID who owns this saved search
  /// Nullable to support migration scenarios where userId is populated later
  TextColumn get userId => text().nullable()();

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

/// Templates table for note templates (system and user-defined)
@DataClassName('LocalTemplate')
class LocalTemplates extends Table {
  /// Unique identifier for the template
  TextColumn get id => text()();

  /// User ID who owns this template (null for system templates)
  TextColumn get userId => text().nullable()();

  /// Template title
  TextColumn get title => text()();

  /// Template body/content
  TextColumn get body => text()();

  /// Associated tags (JSON array)
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// Whether this is a system template (true) or user-created (false)
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Template category (work, personal, meeting, etc.)
  TextColumn get category => text()();

  /// Short description for the template
  TextColumn get description => text()();

  /// Icon identifier for UI display
  TextColumn get icon => text()();

  /// Display order in template picker
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Additional metadata (JSON)
  TextColumn get metadata => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Attachments table for file attachments to notes
@DataClassName('LocalAttachment')
class Attachments extends Table {
  /// Unique identifier for the attachment
  TextColumn get id => text()();

  /// User ID who owns this attachment (SECURITY: prevents cross-user access)
  TextColumn get userId => text()();

  /// Reference to parent note ID
  TextColumn get noteId => text()();

  /// Original file name
  TextColumn get filename => text()();

  /// MIME type (image/png, application/pdf, etc.)
  TextColumn get mimeType => text()();

  /// File size in bytes
  IntColumn get size => integer()();

  /// Remote URL if uploaded to cloud storage
  TextColumn get url => text().nullable()();

  /// Local file path if stored locally
  TextColumn get localPath => text().nullable()();

  /// Upload/creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Additional metadata (JSON)
  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inbox items table for email-in and web clips
@DataClassName('InboxItem')
class InboxItems extends Table {
  /// Unique identifier for the inbox item
  TextColumn get id => text()();

  /// User ID who owns this item
  TextColumn get userId => text()();

  /// Source type: 'email_in' or 'web'
  TextColumn get sourceType => text()();

  /// Payload data as JSON string
  TextColumn get payload => text()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Whether this item has been processed into a note
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();

  /// Reference to note ID if processed
  TextColumn get noteId => text().nullable()();

  /// When the item was processed
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuickCaptureQueueEntry')
class QuickCaptureQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get payloadEncrypted =>
      text().named('payload_encrypted')(); // Base64 encoded encrypted payload
  TextColumn get platform => text().nullable()();
  IntColumn get retryCount =>
      integer().named('retry_count').withDefault(const Constant(0))();
  BoolColumn get processed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt =>
      dateTime().named('processed_at').nullable()();
  IntColumn get encryptionVersion =>
      integer().named('encryption_version').withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuickCaptureWidgetCacheEntry')
class QuickCaptureWidgetCacheEntries extends Table {
  TextColumn get userId => text()();
  TextColumn get dataEncrypted =>
      text().named('data_encrypted')(); // Base64 encoded encrypted payload
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  IntColumn get encryptionVersion =>
      integer().named('encryption_version').withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {userId};
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
    LocalTemplates,
    Attachments,
    InboxItems,
    QuickCaptureQueueEntries,
    QuickCaptureWidgetCacheEntries,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  /// Test constructor for in-memory database
  AppDb.forTesting(super.executor);

  @override
  int get schemaVersion => 38; // Migration 38: note_tags/links/folders user isolation

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
      await _createAttachmentIndexes();
      await _createInboxIndexes();
      await _createQuickCaptureIndexes();
      await Migration32Phase1PerformanceIndexes.apply(this);

      // FTS seed removed – index is populated from the application after
      // notes are decrypted (see FTSIndexingService).
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

        // Legacy task extraction/backfill removed post-encryption.
      }
      if (from < 10) {
        // Version 10: Add noteType column to support templates
        await m.addColumn(localNotes, localNotes.noteType);
      }
      if (from < 11) {
        // Version 11: Add proper templates table (separate from notes)
        await m.createTable(localTemplates);

        // Initialize system templates
        await _initializeSystemTemplates();
      }
      if (from < 12) {
        // Version 12: Phase 3 optimization - foreign keys and performance indexes
        // Note: This migration recreates tables with foreign key constraints
        // Make sure to backup data before running this migration

        // Apply Phase 3 optimizations (foreign keys and performance indexes)
        await Migration12Phase3Optimization.apply(this);
      }

      if (from < 13) {
        // Version 13: Domain model migration - Add fields for clean architecture
        // These fields support the migration from database models to domain entities
        await m.addColumn(localNotes, localNotes.version);
        await m.addColumn(localNotes, localNotes.userId);
        await m.addColumn(localNotes, localNotes.attachmentMeta);
        await m.addColumn(localNotes, localNotes.metadata);
      }

      // PHASE 0 SECURITY MIGRATIONS (Critical)

      if (from < 23) {
        // Version 23: Add encrypted columns for zero-knowledge architecture
        await Migration23LocalEncryption.run(m, from);
      }

      if (from < 24) {
        // Version 24: Drop plaintext columns (SECURITY FIX)
        await Migration24DropPlaintextColumns.run(m, from);
      }

      if (from < 25) {
        // Version 25: Populate userId for security authorization
        // TODO(security): This migration must be run manually - see migration file
        // Migration25SecurityUserIdPopulation provides methods to populate userId
        // but cannot run automatically without user context
        // await Migration25SecurityUserIdPopulation.run(this, from);
      }

      if (from < 26) {
        // Version 26: Add userId to SavedSearches for authorization
        await Migration26SavedSearchesUserId.run(this, from);
      }

      if (from < 27) {
        // Version 27: Performance optimization indexes for N+1 query prevention
        await Migration27PerformanceIndexes.apply(m);
      }

      if (from < 28) {
        // Version 28: Add Attachments and InboxItems tables
        await m.createTable(attachments);
        await m.createTable(inboxItems);

        // Create indexes for new tables
        await _createAttachmentIndexes();
        await _createInboxIndexes();
      }

      if (from < 29) {
        // Version 29: Add userId columns for user isolation (P0.3 security fix)

        // Add userId to local_folders table
        await m.addColumn(localFolders, localFolders.userId);

        // Add userId to saved_searches table
        await m.addColumn(savedSearches, savedSearches.userId);

        // Add userId to local_templates table (nullable for system templates)
        await m.addColumn(localTemplates, localTemplates.userId);

        // Create indexes for userId columns for performance
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_local_folders_user_id ON local_folders(user_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id ON saved_searches(user_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_local_templates_user_id ON local_templates(user_id)',
        );
      }

      if (from < 30) {
        // Version 30: P0.5 SECURITY FIX - Add userId to Attachments table
        // CRITICAL: Prevents file attachment leakage between users

        await m.addColumn(attachments, attachments.userId);

        // Backfill userId from parent note
        await customStatement('''
          UPDATE attachments
          SET user_id = (
            SELECT user_id FROM local_notes
            WHERE local_notes.id = attachments.note_id
            LIMIT 1
          )
          WHERE user_id IS NULL
        ''');

        // Delete orphaned attachments (no parent note)
        await customStatement('''
          DELETE FROM attachments
          WHERE user_id IS NULL
        ''');

        // Create index for userId filtering performance
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments(user_id)',
        );

        if (kDebugMode) {
          debugPrint('[Migration 30] ✅ Added userId to Attachments table');
        }
      }

      if (from < 31) {
        // Version 31: P0.5 SECURITY FIX - Add userId to NoteReminders table
        // CRITICAL: Prevents reminder leakage between users

        await m.addColumn(noteReminders, noteReminders.userId);

        // Backfill userId from parent note
        await customStatement('''
          UPDATE note_reminders
          SET user_id = (
            SELECT user_id FROM local_notes
            WHERE local_notes.id = note_reminders.note_id
            LIMIT 1
          )
          WHERE user_id IS NULL
        ''');

        // Delete orphaned reminders (no parent note)
        await customStatement('''
          DELETE FROM note_reminders
          WHERE user_id IS NULL
        ''');

        // Create index for userId filtering performance
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_note_reminders_user_id ON note_reminders(user_id)',
        );

        if (kDebugMode) {
          debugPrint('[Migration 31] ✅ Added userId to NoteReminders table');
        }
      }

      if (from < 32) {
        await Migration32Phase1PerformanceIndexes.apply(this);
      }

      if (from < 33) {
        await Migration33PendingOpsUserId.run(this);
      }

      if (from < 34) {
        await Migration34NoteTasksUserId.run(this);
      }

      if (from < 35) {
        await m.createTable(quickCaptureQueueEntries);
        await m.createTable(quickCaptureWidgetCacheEntries);
        await _createQuickCaptureIndexes();
      }

      if (from < 36) {
        // Migration 36: Add created_at column to local_notes
        // This column stores the original creation timestamp of the note
        // and should never change after initial creation
        await customStatement(
          'ALTER TABLE local_notes ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );

        // Backfill existing notes: Use updated_at as the best approximation
        // for created_at since we don't have the original creation time.
        // DEFENSIVE: Only backfill notes that existed BEFORE this migration
        // (have updated_at older than now) to prevent re-running on hot reload.
        final migrationTimestamp = DateTime.now().millisecondsSinceEpoch;
        await customStatement(
          'UPDATE local_notes SET created_at = updated_at WHERE created_at = 0 AND updated_at < ?',
          [migrationTimestamp],
        );

        if (kDebugMode) {
          print(
            '✓ Migration 36: Added created_at column to local_notes with defensive backfill',
          );
        }
      }

      if (from < 37) {
        await Migration37NoteTagsLinksUserId.run(this);
      }

      if (from < 38) {
        await Migration38NoteFoldersUserId.run(this);
      }

      // Always attempt Migration 12 (idempotent) to handle edge cases where
      // schema version is 12 but optimizations weren't applied
      await _ensureMigration12Applied();
    },
  );

  /// Helper to check if a note is visible (not deleted and not a template)
  Expression<bool> noteIsVisible(LocalNotes t) =>
      t.deleted.equals(false) & t.noteType.equals(0);

  /// Ensures Migration 12 Phase 3 optimizations are applied (idempotent)
  /// This handles edge cases where schema version is 12 but optimizations weren't applied
  Future<void> _ensureMigration12Applied() async {
    try {
      // Migration 12 is idempotent, so it's safe to call regardless of current state
      await Migration12Phase3Optimization.apply(this);
    } catch (e) {
      // Log error but don't fail the migration - this is a safety check
      if (kDebugMode) {
        print('Warning: Could not ensure Migration 12 applied: $e');
      }
    }
  }

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
    // CRITICAL FIX: FTS triggers disabled for encrypted content.
    // Title/body columns are stored encrypted; the application populates the
    // in-memory/full-text index after decrypting the note (see FTSIndexingService).

    // Creating no-op triggers to prevent errors, DELETE trigger still works
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_ai
      AFTER INSERT ON local_notes
      BEGIN
        SELECT 1; -- No-op: FTS disabled for encrypted content
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_local_notes_au
      AFTER UPDATE ON local_notes
      BEGIN
        SELECT 1; -- No-op: FTS disabled for encrypted content
      END;
    ''');

    // DELETE -> Remove from FTS (still safe)
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
  }) async {
    // Encryption prevents title-prefix filtering in SQL. Higher layers (domain
    // repositories) provide autocomplete after decryption. Here we simply
    // return the most recent notes when the query is empty.
    final q = query.trim();
    if (q.isEmpty) {
      return (select(localNotes)
            ..where((t) => noteIsVisible(t))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .get();
    }

    // Title search is handled at the domain/service layer.
    return [];

    /*
    final startsWith = '$q%';
    final wordStart = '% $q%';

    return (select(localNotes)
          ..where(
            (t) =>
                noteIsVisible(t) &
                (t.title.like(startsWith) | t.title.like(wordStart)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)])
          ..limit(limit))
        .get();
    */
  }

  Future<List<LocalNote>> allNotes() =>
      (select(localNotes)
            ..where((t) => noteIsVisible(t))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Keyset pagination: Get notes after a given cursor (updatedAt timestamp)
  /// Uses keyset pagination for better performance at scale vs OFFSET
  Future<List<LocalNote>> notesAfter({
    required DateTime? cursor,
    required int limit,
  }) {
    final query = select(localNotes)..where((t) => noteIsVisible(t));

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
            ..where((t) => noteIsVisible(t))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit, offset: offset))
          .get();

  /// Get all notes with pinned notes first
  Future<List<LocalNote>> allNotesWithPinned() =>
      (select(localNotes)
            ..where((t) => noteIsVisible(t))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .get();

  /// Get pinned notes only
  Future<List<LocalNote>> getPinnedNotes() =>
      (select(localNotes)
            ..where((t) => noteIsVisible(t) & t.isPinned.equals(true))
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
      final ownerId = updatedNote.userId;
      if (ownerId != null) {
        await enqueue(userId: ownerId, entityId: noteId, kind: 'upsert_note');
      }
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
      final ownerId = updatedNote.userId;
      if (ownerId != null) {
        await enqueue(userId: ownerId, entityId: noteId, kind: 'upsert_note');
      }
    }
  }

  Future<void> migrateNoteId(String fromNoteId, String toNoteId) async {
    await transaction(() async {
      await customStatement(
        'UPDATE note_tasks SET note_id = ? WHERE note_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE note_reminders SET note_id = ? WHERE note_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE note_folders SET note_id = ? WHERE note_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE note_tags SET note_id = ? WHERE note_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE note_links SET source_id = ? WHERE source_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE note_links SET target_id = ? WHERE target_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE local_notes SET id = ? WHERE id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        'UPDATE pending_ops SET entity_id = ? WHERE entity_id = ?',
        <Object?>[toNoteId, fromNoteId],
      );
      await customStatement(
        "DELETE FROM pending_ops WHERE payload LIKE '%' || ? || '%'",
        <Object?>[fromNoteId],
      );
    });
  }

  /// Get notes in folder with pinned first
  Future<List<LocalNote>> getNotesInFolderWithPinned(
    String folderId, {
    int? limit,
    DateTime? cursor,
  }) {
    final query = select(localNotes).join(
      [leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id))],
    )..where(noteIsVisible(localNotes) & noteFolders.folderId.equals(folderId));

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
  Future<int> enqueue({
    required String userId,
    required String entityId,
    required String kind,
    String? payload,
  }) => into(pendingOps).insert(
    PendingOpsCompanion.insert(
      entityId: entityId,
      kind: kind,
      userId: userId,
      payload: Value(payload),
    ),
  );

  Future<List<PendingOp>> getPendingOpsForUser(String userId) =>
      (select(pendingOps)
            ..where((o) => o.userId.equals(userId))
            ..orderBy([(o) => OrderingTerm.asc(o.id)]))
          .get();

  Future<void> deletePendingByIds({
    required String userId,
    required Iterable<int> ids,
  }) async {
    if (ids.isEmpty) return;
    await (delete(
      pendingOps,
    )..where((t) => t.userId.equals(userId) & t.id.isIn(ids.toList()))).go();
  }

  Future<List<PendingOp>> dequeueAll(String userId) async {
    final ops =
        await (select(pendingOps)
              ..where((o) => o.userId.equals(userId))
              ..orderBy([(o) => OrderingTerm.asc(o.id)]))
            .get();
    await (delete(pendingOps)..where((o) => o.userId.equals(userId))).go();
    return ops;
  }

  // ----------------------
  // Maintenance
  // ----------------------
  /// Clear ALL database tables
  ///
  /// CRITICAL SECURITY: This must clear EVERY table to prevent data leakage between users.
  /// Called during sign-out to ensure no data persists between user sessions.
  ///
  /// SECURITY AUDIT FINDING: Previously missing localTemplates, attachments, inboxItems
  /// which allowed data leakage between users. Now clears ALL 12 tables + FTS index.
  Future<void> clearAll() async {
    await transaction(() async {
      // Clear all tables in reverse dependency order
      // Start with junction/relationship tables that depend on other tables
      await delete(pendingOps).go();
      await delete(noteFolders).go(); // Clear folder relationships first
      await delete(noteTags).go();
      await delete(noteLinks).go();
      await delete(noteReminders).go();
      await delete(noteTasks).go();

      // Clear main entity tables
      await delete(localNotes).go();
      await delete(localFolders).go();
      await delete(savedSearches).go();

      // CRITICAL FIX: Clear previously missing tables
      await delete(
        localTemplates,
      ).go(); // User templates - DATA LEAKAGE if not cleared
      await delete(
        attachments,
      ).go(); // File attachments - DATA LEAKAGE if not cleared
      await delete(
        inboxItems,
      ).go(); // Clipper inbox - DATA LEAKAGE if not cleared

      // Clear full-text search index
      await customStatement('DELETE FROM fts_notes');

      if (kDebugMode) {
        debugPrint(
          '[AppDb] ✅ All 12 tables + FTS cleared - complete database reset for user switch',
        );
      }
    });
  }

  Future<Set<String>> getLocalActiveNoteIds() async {
    final rows = await (select(
      localNotes,
    )..where((t) => noteIsVisible(t))).get();
    return rows.map((e) => e.id).toSet();
  }

  Future<String?> _resolveNoteOwner(String noteId) async {
    final note = await (select(
      localNotes,
    )..where((n) => n.id.equals(noteId))).getSingleOrNull();
    return note?.userId;
  }

  Future<void> replaceTagsForNote(String noteId, Set<String> tags) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      if (tags.isNotEmpty) {
        final ownerId = await _resolveNoteOwner(noteId);
        if (ownerId == null || ownerId.isEmpty) {
          return;
        }

        final normalizedTags = tags
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toSet();

        await batch((b) {
          b.insertAll(
            noteTags,
            normalizedTags.map(
              (t) => NoteTagsCompanion.insert(
                noteId: noteId,
                tag: t,
                userId: ownerId,
              ),
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
        final ownerId = await _resolveNoteOwner(noteId);
        if (ownerId == null || ownerId.isEmpty) {
          return;
        }

        await batch((b) {
          b.insertAll(
            noteLinks,
            links.map(
              (l) => NoteLinksCompanion.insert(
                sourceId: noteId,
                targetTitle: l['title'] ?? '',
                targetId: Value(l['id']),
                userId: ownerId,
              ),
            ),
          );
        });
      }
    });
  }

  Future<List<String>> distinctTags({String? userId}) async {
    final buffer = StringBuffer('''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0 AND n.note_type = 0
    ''');
    final variables = <Variable>[];
    if (userId != null && userId.isNotEmpty) {
      buffer.write(' AND t.user_id = ?');
      variables.add(Variable(userId));
    }
    buffer.write(' ORDER BY LOWER(t.tag) ASC');

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
  }

  /// Get tags with their note counts (normalized, excludes deleted notes).
  ///
  /// SECURITY: Requires [userId]. Returns an empty list if userId is missing to
  /// prevent accidental cross-user aggregation when invoked from unauthenticated
  /// contexts (e.g. legacy background jobs).
  Future<List<TagCount>> getTagsWithCounts({String? userId}) async {
    final owner = userId?.trim();
    if (owner == null || owner.isEmpty) {
      LoggerFactory.instance.warning(
        '[AppDb] getTagsWithCounts denied - missing userId',
      );
      return const <TagCount>[];
    }

    final rows = await customSelect(
      '''
      SELECT nt.tag AS tag, COUNT(*) AS count
      FROM note_tags nt
      JOIN local_notes n ON n.id = nt.note_id
      WHERE n.deleted = 0
        AND n.note_type = 0
        AND nt.user_id = ?
        AND n.user_id = ?
      GROUP BY nt.tag
      ORDER BY count DESC, tag ASC
      ''',
      readsFrom: {noteTags, localNotes},
      variables: [
        Variable<String>(owner),
        Variable<String>(owner),
      ],
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
    if (tag.isEmpty) return;

    final ownerId = await _resolveNoteOwner(noteId);
    if (ownerId == null || ownerId.isEmpty) {
      LoggerFactory.instance.warning(
        '[AppDb] addTagToNote skipped - note missing userId',
        data: {'noteId': noteId, 'tag': rawTag},
      );
      return;
    }

    await into(noteTags).insert(
      NoteTagsCompanion.insert(noteId: noteId, tag: tag, userId: ownerId),
      mode: InsertMode.insertOrIgnore, // idempotent
    );
  }

  /// Remove tag from note
  Future<void> removeTagFromNote(String noteId, String rawTag) async {
    final tag = rawTag.trim().toLowerCase();
    if (tag.isEmpty) return;

    final ownerId = await _resolveNoteOwner(noteId);
    if (ownerId == null || ownerId.isEmpty) {
      LoggerFactory.instance.warning(
        '[AppDb] removeTagFromNote skipped - note missing userId',
        data: {'noteId': noteId, 'tag': rawTag},
      );
      return;
    }

    await (delete(noteTags)..where(
          (t) =>
              t.noteId.equals(noteId) &
              t.tag.equals(tag) &
              t.userId.equals(ownerId),
        ))
        .go();
  }

  /// Rename/merge tag across all notes
  Future<int> renameTagEverywhere(
    String fromRaw,
    String toRaw, {
    String? userId,
  }) async {
    final from = fromRaw.trim().toLowerCase();
    final to = toRaw.trim().toLowerCase();

    if (from == to) return 0;

    final buffer = StringBuffer(
      'UPDATE OR IGNORE note_tags SET tag = ? WHERE tag = ?',
    );
    final variables = <Variable>[Variable<String>(to), Variable<String>(from)];

    if (userId != null && userId.isNotEmpty) {
      buffer.write(' AND user_id = ?');
      variables.add(Variable<String>(userId));
    }

    // Use custom update to handle potential conflicts
    return customUpdate(
      buffer.toString(),
      variables: variables,
      updates: {noteTags},
    );
  }

  /// Filter notes by tags (union of anyTags, excluding noneTags)
  Future<List<LocalNote>> notesByTags({
    required List<String> anyTags,
    required SortSpec sort,
    List<String> noneTags = const [],
    String? userId,
  }) async {
    final tagsAny = anyTags.map((t) => t.trim().toLowerCase()).toList();
    final tagsNone = noneTags.map((t) => t.trim().toLowerCase()).toList();

    final q = select(localNotes)..where((n) => noteIsVisible(n));

    if (userId != null && userId.isNotEmpty) {
      q.where((n) => n.userId.equals(userId));
    }

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
        // Sorting by encrypted title in SQL is meaningless; the repository
        // layer performs title-based sorting after decryption. We therefore
        // fall back to updatedAt ordering here.
        orderFuncs.add(
          (n) => OrderingTerm(
            expression: n.updatedAt,
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
  Future<List<String>> searchTags(String prefix, {String? userId}) async {
    if (prefix.trim().isEmpty) return distinctTags(userId: userId);

    final normalizedPrefix = prefix.trim().toLowerCase();
    final queryBuffer = StringBuffer('''
      SELECT DISTINCT t.tag AS tag
      FROM note_tags t
      JOIN local_notes n ON n.id = t.note_id
      WHERE n.deleted = 0 AND n.note_type = 0 AND t.tag LIKE ?
    ''');
    final variables = <Variable>[Variable('$normalizedPrefix%')];
    if (userId != null && userId.isNotEmpty) {
      queryBuffer.write(' AND t.user_id = ?');
      variables.add(Variable(userId));
    }
    queryBuffer.write(' ORDER BY t.tag ASC LIMIT 20');

    final rows = await customSelect(
      queryBuffer.toString(),
      variables: variables,
      readsFrom: {noteTags, localNotes},
    ).get();

    return rows.map((r) => r.read<String>('tag')).toList();
  }

  Future<List<LocalNote>> notesWithTag(String tag, {String? userId}) async {
    final normalizedTag = tag.trim().toLowerCase();

    final query =
        select(localNotes).join([
          innerJoin(noteTags, noteTags.noteId.equalsExp(localNotes.id)),
        ])..where(
          localNotes.deleted.equals(false) &
              localNotes.noteType.equals(0) &
              noteTags.tag.equals(normalizedTag),
        );

    if (userId != null && userId.isNotEmpty) {
      query.where(noteTags.userId.equals(userId));
    }

    query.orderBy([
      OrderingTerm.desc(localNotes.isPinned),
      OrderingTerm.desc(localNotes.updatedAt),
    ]);

    final results = await query.get();
    return results.map((row) => row.readTable(localNotes)).toList();
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
        // Titles are encrypted; log IDs and metadata instead.
        debugPrint('\nNote ID: ${note.id}');
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
          WHERE n.deleted = 0 AND n.note_type = 0 AND (
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
          WHERE n.deleted = 0 AND n.note_type = 0 AND (
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
          WHERE n.deleted = 0 AND n.note_type = 0 AND (
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
    // Encryption: rely on metadata flags instead of scanning the body text.
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['attachments'] != null) return true;
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse encryptedMetadata for attachments',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }

    // Cannot check encrypted body for #Attachment tag
    return false;
  }

  /// Helper method to check if a note is from email source (for in-memory filtering)
  static bool noteIsFromEmail(LocalNote note) {
    // Encryption: we can only inspect metadata, so the body is ignored.
    // Check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        // Check both old and new format
        if (meta['source'] == 'email_in' || meta['source'] == 'email_inbox') {
          return true;
        }
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse encryptedMetadata for email source',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }

    // Cannot check encrypted body for #Email tag
    return false;
  }

  /// Helper method to check if a note is from web source (for in-memory filtering)
  static bool noteIsFromWeb(LocalNote note) {
    // Encryption: we can only inspect metadata, so the body is ignored.
    // Check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'web') return true;
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse encryptedMetadata for web source',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }

    // Cannot check encrypted body for #Web tag
    return false;
  }

  // ----------------------
  // Domain Note Adapters
  // ----------------------
  // These methods accept domain.Note for UI layer compatibility

  /// Helper method to check if a domain note has attachments
  ///
  /// POST-ENCRYPTION: Adapter for domain.Note (calls LocalNote version)
  static bool noteHasAttachmentsDomain(domain.Note note) {
    // Check metadata for attachments (same logic as LocalNote version)
    if (note.encryptedMetadata != null && note.encryptedMetadata!.isNotEmpty) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['attachments'] != null) return true;
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse domain note metadata for attachments',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }
    return false;
  }

  /// Helper method to check if a domain note is from email source
  ///
  /// POST-ENCRYPTION: Adapter for domain.Note (calls LocalNote version)
  static bool noteIsFromEmailDomain(domain.Note note) {
    // Check metadata source (same logic as LocalNote version)
    if (note.encryptedMetadata != null && note.encryptedMetadata!.isNotEmpty) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'email_in' || meta['source'] == 'email_inbox') {
          return true;
        }
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse domain note metadata for email source',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }
    return false;
  }

  /// Helper method to check if a domain note is from web source
  ///
  /// POST-ENCRYPTION: Adapter for domain.Note (calls LocalNote version)
  static bool noteIsFromWebDomain(domain.Note note) {
    // Check metadata source (same logic as LocalNote version)
    if (note.encryptedMetadata != null && note.encryptedMetadata!.isNotEmpty) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'web') return true;
      } catch (error, stack) {
        LoggerFactory.instance.debug(
          '[AppDb] Failed to parse domain note metadata for web source',
          data: {
            'noteId': note.id,
            'error': error.toString(),
            'stack': stack.toString(),
          },
        );
      }
    }
    return false;
  }

  Future<List<BacklinkPair>> backlinksWithSources(String targetTitle) async {
    final List<NoteLink> links = await (select(
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
  Future<List<LocalNote>> searchNotes(String raw, {String? userId}) async {
    final q = raw.trim();
    String? owner = userId?.trim().isEmpty ?? true ? null : userId;

    if (q.isEmpty) {
      final query = select(localNotes)
        ..where((t) => noteIsVisible(t))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      if (owner != null) {
        query.where((t) => t.userId.equals(owner));
      }
      return query.get();
    }

    String likeWrap(String s) {
      final esc = s.replaceAll('%', r'\%').replaceAll('_', r'\_');
      return '%$esc%';
    }

    if (q.startsWith('#')) {
      final needle = q.substring(1).trim();
      if (needle.isEmpty) return allNotes();

      final tagQuery = select(noteTags)
        ..where((t) => t.tag.like(likeWrap(needle)));
      if (owner != null) {
        tagQuery.where((t) => t.userId.equals(owner));
      }
      final tagRows = await tagQuery.get();

      final ids = tagRows.map((e) => e.noteId).toSet().toList();
      if (ids.isEmpty) return const <LocalNote>[];

      final noteQuery = select(localNotes)
        ..where((t) => noteIsVisible(t) & t.id.isIn(ids))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      if (owner != null) {
        noteQuery.where((t) => t.userId.equals(owner));
      }
      return noteQuery.get();
    }

    final match = _ftsQuery(q);
    if (match.isEmpty) return allNotes();

    try {
      final res = await customSelect(
        '''
        SELECT n.*
        FROM local_notes n
        JOIN fts_notes f ON n.id = f.id
        WHERE n.deleted = 0 AND n.note_type = 0
          AND f MATCH ?
        ORDER BY n.updated_at DESC
        ''',
        variables: [Variable(match)],
        readsFrom: {localNotes},
      ).map<LocalNote>((row) => localNotes.map(row.data)).get();

      var filtered = res;
      if (owner != null) {
        filtered = filtered.where((note) => note.userId == owner).toList();
      }
      return filtered;
    } catch (error, stack) {
      LoggerFactory.instance.warning(
        '[AppDb] Application-side FTS lookup failed, returning empty result',
        data: {
          'query': q,
          'error': error.toString(),
          'stack': stack.toString(),
        },
      );
      return [];
      /*
      // FTS bir nedenden hata verirse LIKE'a dönüş
      final needle = likeWrap(q);
      return (select(localNotes)
            ..where(
              (t) =>
                  noteIsVisible(t) &
                  (t.title.like(needle) | t.body.like(needle)),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
      */
    }
  }

  // ----------------------
  // Advanced Reminders
  // ----------------------

  /// Get all reminders for a specific note
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getRemindersForNote(
    String noteId,
    String userId,
  ) =>
      (select(noteReminders)..where(
            (r) =>
                r.noteId.equals(noteId) &
                r.userId.equals(userId) &
                r.isActive.equals(true),
          ))
          .get();

  /// Get all active reminders
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getActiveReminders(String userId) =>
      (select(noteReminders)
            ..where((r) => r.isActive.equals(true) & r.userId.equals(userId))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .get();

  /// Get a specific reminder by ID
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<NoteReminder?> getReminderById(int id, String userId) => (select(
    noteReminders,
  )..where((r) => r.id.equals(id) & r.userId.equals(userId))).getSingleOrNull();

  /// Create a new reminder
  Future<int> createReminder(NoteRemindersCompanion reminder) =>
      into(noteReminders).insert(reminder);

  /// Update an existing reminder
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder modification
  Future<void> updateReminder(
    int id,
    String userId,
    NoteRemindersCompanion updates,
  ) => (update(
    noteReminders,
  )..where((r) => r.id.equals(id) & r.userId.equals(userId))).write(updates);

  /// Delete a specific reminder
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder deletion
  Future<void> deleteReminderById(int id, String userId) => (delete(
    noteReminders,
  )..where((r) => r.id.equals(id) & r.userId.equals(userId))).go();

  /// Delete all reminders for a note
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder deletion
  Future<void> deleteRemindersForNote(String noteId, String userId) => (delete(
    noteReminders,
  )..where((r) => r.noteId.equals(noteId) & r.userId.equals(userId))).go();

  /// Get all active time-based reminders due before a specific time
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getTimeRemindersToTrigger({
    required DateTime before,
    required String userId,
  }) =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.time.index) &
                r.isActive.equals(true) &
                r.userId.equals(userId) &
                r.remindAt.isSmallerOrEqualValue(before) &
                (r.snoozedUntil.isNull() |
                    r.snoozedUntil.isSmallerOrEqualValue(before)),
          ))
          .get();

  /// Get all active location-based reminders
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getLocationReminders(String userId) =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.location.index) &
                r.isActive.equals(true) &
                r.userId.equals(userId) &
                r.latitude.isNotNull() &
                r.longitude.isNotNull(),
          ))
          .get();

  /// Get all recurring reminders that need to be scheduled
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getRecurringReminders(String userId) =>
      (select(noteReminders)..where(
            (r) =>
                r.type.equals(ReminderType.recurring.index) &
                r.isActive.equals(true) &
                r.userId.equals(userId) &
                r.recurrencePattern.isNotValue(RecurrencePattern.none.index),
          ))
          .get();

  // ----------------------
  // Tasks
  // ----------------------

  /// Get all tasks for a specific note
  Future<List<NoteTask>> getTasksForNote(
    String noteId, {
    required String userId,
  }) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.noteId.equals(noteId) &
                  t.userId.equals(userId) &
                  t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  /// Get a specific task by ID
  Future<NoteTask?> getTaskById(String id, {required String userId}) => (select(
    noteTasks,
  )..where((t) => t.id.equals(id) & t.userId.equals(userId))).getSingleOrNull();

  /// Find a task by its stable content hash within a note.
  Future<NoteTask?> findTaskByContentHash({
    required String noteId,
    required String userId,
    required String contentHash,
  }) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.noteId.equals(noteId) &
                  t.userId.equals(userId) &
                  t.contentHash.equals(contentHash) &
                  t.deleted.equals(false),
            )
            ..limit(1))
          .getSingleOrNull();

  /// Get all open tasks with optional filtering
  Future<List<NoteTask>> getOpenTasks({
    required String userId,
    DateTime? dueBefore,
    TaskPriority? priority,
    String? parentTaskId,
  }) {
    final query = select(noteTasks)
      ..where(
        (t) =>
            t.status.equals(TaskStatus.open.index) &
            t.deleted.equals(false) &
            t.userId.equals(userId),
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
    required String userId,
    required DateTime start,
    required DateTime end,
  }) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.deleted.equals(false) &
                  t.userId.equals(userId) &
                  t.dueDate.isBetweenValues(start, end),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  /// Get overdue tasks
  Future<List<NoteTask>> getOverdueTasks(String userId) {
    final now = DateTime.now();
    return (select(noteTasks)
          ..where(
            (t) =>
                t.status.equals(TaskStatus.open.index) &
                t.deleted.equals(false) &
                t.userId.equals(userId) &
                t.dueDate.isSmallerThanValue(now),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.dueDate),
          ]))
        .get();
  }

  /// Get completed tasks
  /// Get all tasks for the current user
  Future<List<NoteTask>> getAllTasks(String userId) {
    return (select(noteTasks)
          ..where((t) => t.deleted.equals(false) & t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<NoteTask>> getCompletedTasks({
    required String userId,
    DateTime? since,
    int? limit,
  }) {
    final query = select(noteTasks)
      ..where(
        (t) =>
            t.status.equals(TaskStatus.completed.index) &
            t.deleted.equals(false) &
            t.userId.equals(userId),
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

  /// Update an existing task for the specified user
  Future<void> updateTask(
    String id,
    String userId,
    NoteTasksCompanion updates,
  ) => (update(
    noteTasks,
  )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(updates);

  /// Mark task as completed
  Future<void> completeTask(String id, String userId, {String? completedBy}) =>
      (update(
        noteTasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
        NoteTasksCompanion(
          status: const Value(TaskStatus.completed),
          completedAt: Value(DateTime.now()),
          completedBy: Value(completedBy),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Toggle task completion status
  Future<void> toggleTaskStatus(String id, String userId) async {
    final task = await getTaskById(id, userId: userId);
    if (task != null) {
      final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.open
          : TaskStatus.completed;

      await (update(
        noteTasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
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
  Future<void> deleteTaskById(String id, String userId) => (delete(
    noteTasks,
  )..where((t) => t.id.equals(id) & t.userId.equals(userId))).go();

  /// Delete all tasks for a note
  Future<void> deleteTasksForNote(String noteId, String userId) => (delete(
    noteTasks,
  )..where((t) => t.noteId.equals(noteId) & t.userId.equals(userId))).go();

  /// Sync tasks with note content (called when note is saved)
  Future<void> syncTasksWithNoteContent(
    String noteId,
    String noteContent,
  ) async {
    // POST-ENCRYPTION: This method is no longer used for task sync.
    // Task synchronization now happens at the domain layer via DomainTaskController
    // and TaskCoreRepository, which work with decrypted domain.Task objects.
    //
    // This method is kept as a no-op stub for backward compatibility.
    // External callers (TaskService, TaskCoreRepository) invoke this method but
    // actual task management happens through the repository layer after decryption.
    //
    // See: Phase 11 Sprint 1 - Task-Todo Block Integration (completed)
    return;

    /*
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
    */
  }

  /// Watch all open tasks (for UI updates)
  Stream<List<NoteTask>> watchOpenTasks(String userId) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.status.equals(TaskStatus.open.index) &
                  t.deleted.equals(false) &
                  t.userId.equals(userId),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.dueDate),
              (t) => OrderingTerm.desc(t.priority),
            ]))
          .watch();

  /// Watch tasks for a specific note
  Stream<List<NoteTask>> watchTasksForNote(String noteId, String userId) =>
      (select(noteTasks)
            ..where(
              (t) =>
                  t.noteId.equals(noteId) &
                  t.userId.equals(userId) &
                  t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  /// Get snoozed reminders that are ready to be rescheduled
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getSnoozedRemindersToReschedule({
    required DateTime now,
    required String userId,
  }) =>
      (select(noteReminders)..where(
            (r) =>
                r.isActive.equals(true) &
                r.userId.equals(userId) &
                r.snoozedUntil.isNotNull() &
                r.snoozedUntil.isSmallerOrEqualValue(now),
          ))
          .get();

  /// Mark a reminder as triggered
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder modification
  Future<void> markReminderTriggered(
    int id,
    String userId, {
    DateTime? triggeredAt,
  }) =>
      (update(
        noteReminders,
      )..where((r) => r.id.equals(id) & r.userId.equals(userId))).write(
        NoteRemindersCompanion(
          lastTriggered: Value(triggeredAt ?? DateTime.now().toUtc()),
          // Note: trigger_count will be incremented by database trigger
        ),
      );

  /// Snooze a reminder
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder modification
  Future<void> snoozeReminder(int id, String userId, DateTime snoozeUntil) =>
      (update(
        noteReminders,
      )..where((r) => r.id.equals(id) & r.userId.equals(userId))).write(
        NoteRemindersCompanion(
          snoozedUntil: Value(snoozeUntil),
          // Note: snooze_count will be incremented by database trigger
        ),
      );

  /// Clear snooze for a reminder
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder modification
  Future<void> clearSnooze(int id, String userId) =>
      (update(noteReminders)
            ..where((r) => r.id.equals(id) & r.userId.equals(userId)))
          .write(const NoteRemindersCompanion(snoozedUntil: Value(null)));

  /// Deactivate a reminder
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder modification
  Future<void> deactivateReminder(int id, String userId) =>
      (update(noteReminders)
            ..where((r) => r.id.equals(id) & r.userId.equals(userId)))
          .write(const NoteRemindersCompanion(isActive: Value(false)));

  /// Get all reminders (for debugging/admin)
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user reminder access
  Future<List<NoteReminder>> getAllReminders(
    String userId, {
    bool activeOnly = false,
  }) {
    final query = select(noteReminders)..where((r) => r.userId.equals(userId));
    if (activeOnly) {
      query.where((r) => r.isActive.equals(true));
    }
    query.orderBy([(r) => OrderingTerm.desc(r.createdAt)]);
    return query.get();
  }

  /// Clean up reminders for deleted notes or templates
  Future<void> cleanupOrphanedReminders() async {
    await customStatement('''
      DELETE FROM note_reminders 
      WHERE note_id NOT IN (
        SELECT id FROM local_notes WHERE deleted = 0 AND note_type = 0
      )
    ''');
  }

  /// Get reminder statistics for analytics
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user data aggregation
  Future<Map<String, int>> getReminderStats(String userId) async {
    final result = await customSelect(
      '''
      SELECT
        type,
        COUNT(*) as count
      FROM note_reminders
      WHERE is_active = 1 AND user_id = ?
      GROUP BY type
    ''',
      variables: [Variable.withString(userId)],
    ).get();

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

  Future<void> _createQuickCaptureIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qc_queue_user_processed ON quick_capture_queue_entries(user_id, processed, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qc_queue_processed_at ON quick_capture_queue_entries(processed, processed_at)',
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

    // Repopulate FTS with existing data (no folders initially, exclude templates)
    await customStatement('''
      INSERT INTO fts_notes(id, title, body, folder_path)
      SELECT id, title, body, '' 
      FROM local_notes 
      WHERE deleted = 0 AND note_type = 0
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

  /// Create indexes for attachments table
  Future<void> _createAttachmentIndexes() async {
    // Index for finding attachments by note
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attachments_note_id '
      'ON attachments(note_id)',
    );
    // Index for finding attachments by MIME type
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attachments_mime_type '
      'ON attachments(mime_type)',
    );
  }

  /// Create indexes for inbox items table
  Future<void> _createInboxIndexes() async {
    // Index for finding inbox items by user
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inbox_items_user_id '
      'ON inbox_items(user_id)',
    );
    // Index for finding unprocessed items
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inbox_items_unprocessed '
      'ON inbox_items(is_processed, created_at DESC) WHERE is_processed = 0',
    );
    // Index for finding items by source type
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inbox_items_source_type '
      'ON inbox_items(source_type)',
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
    final query = select(localNotes).join(
      [leftOuterJoin(noteFolders, noteFolders.noteId.equalsExp(localNotes.id))],
    )..where(noteIsVisible(localNotes) & noteFolders.folderId.equals(folderId));

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
              ..where(noteIsVisible(localNotes))
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
    ])..where(noteIsVisible(localNotes) & noteFolders.noteId.isNull());

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
  Future<void> moveNoteToFolder(
    String noteId,
    String? folderId, {
    String? expectedUserId,
  }) async {
    final logger = LoggerFactory.instance;

    final note = await findNote(noteId);
    if (note == null) {
      logger.warning(
        '[AppDb] moveNoteToFolder skipped - note not found',
        data: {'noteId': noteId, 'folderId': folderId},
      );
      return;
    }

    final ownerId = note.userId;
    if (ownerId == null || ownerId.isEmpty) {
      logger.warning(
        '[AppDb] moveNoteToFolder skipped - note missing userId',
        data: {'noteId': noteId, 'folderId': folderId},
      );
      return;
    }

    if (expectedUserId != null && expectedUserId != ownerId) {
      logger.warning(
        '[AppDb] moveNoteToFolder skipped - expected user mismatch',
        data: {
          'noteId': noteId,
          'folderId': folderId,
          'expectedUserId': expectedUserId,
          'ownerId': ownerId,
        },
      );
      return;
    }

    if (folderId != null) {
      final folder = await getFolderById(folderId);
      if (folder == null || folder.userId != ownerId || folder.deleted) {
        logger.warning(
          '[AppDb] moveNoteToFolder skipped - folder unauthorized or missing',
          data: {
            'noteId': noteId,
            'folderId': folderId,
            'ownerId': ownerId,
            'folderUserId': folder?.userId,
            'folderDeleted': folder?.deleted,
          },
        );
        return;
      }

      final now = DateTime.now();
      await into(noteFolders).insertOnConflictUpdate(
        NoteFoldersCompanion.insert(
          noteId: noteId,
          folderId: folderId,
          addedAt: now,
          updatedAt: Value(now),
          userId: ownerId,
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
  Future<void> removeNoteFromFolder(
    String noteId, {
    String? expectedUserId,
  }) async {
    final logger = LoggerFactory.instance;

    final note = await findNote(noteId);
    if (note == null) {
      logger.warning(
        '[AppDb] removeNoteFromFolder skipped - note not found',
        data: {'noteId': noteId},
      );
      return;
    }

    final ownerId = note.userId;
    if (ownerId == null || ownerId.isEmpty) {
      logger.warning(
        '[AppDb] removeNoteFromFolder skipped - note missing userId',
        data: {'noteId': noteId},
      );
      return;
    }

    if (expectedUserId != null && expectedUserId != ownerId) {
      logger.warning(
        '[AppDb] removeNoteFromFolder skipped - expected user mismatch',
        data: {
          'noteId': noteId,
          'expectedUserId': expectedUserId,
          'ownerId': ownerId,
        },
      );
      return;
    }

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
    )..where((n) => noteIsVisible(n))).get();
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

  /// Get complete folder tree starting from a root (optimized with single query)
  Future<List<LocalFolder>> getFolderSubtree(String rootId) async {
    // Use a recursive CTE to get all folders in the subtree with a single query
    final query = await customSelect(
      '''
      WITH RECURSIVE folder_tree AS (
        -- Start with the root folder
        SELECT * FROM local_folders
        WHERE id = ? AND deleted = 0

        UNION ALL

        -- Recursively get child folders
        SELECT f.* FROM local_folders f
        INNER JOIN folder_tree ft ON f.parent_id = ft.id
        WHERE f.deleted = 0
      )
      SELECT * FROM folder_tree
      ORDER BY name
      ''',
      variables: [Variable.withString(rootId)],
      readsFrom: {localFolders},
    ).get();

    return query.map((row) {
      return LocalFolder(
        id: row.read<String>('id'),
        userId: row.read<String>('user_id'),
        name: row.read<String>('name'),
        parentId: row.readNullable<String>('parent_id'),
        path: row.read<String>('path'),
        sortOrder: row.read<int>('sort_order'),
        color: row.readNullable<String>('color'),
        icon: row.readNullable<String>('icon'),
        description: row.read<String>('description'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
        deleted: row.read<bool>('deleted'),
      );
    }).toList();
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

  // ----------------------
  // Template Management
  // ----------------------

  /// Get all templates (system and user)
  Future<List<LocalTemplate>> getAllTemplates() {
    return select(localTemplates).get();
  }

  /// Get system templates only
  Future<List<LocalTemplate>> getSystemTemplates() {
    return (select(localTemplates)
          ..where((t) => t.isSystem.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get user templates only
  Future<List<LocalTemplate>> getUserTemplates() {
    return (select(localTemplates)
          ..where((t) => t.isSystem.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Get template by ID
  Future<LocalTemplate?> getTemplate(String id) {
    return (select(
      localTemplates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert or update template
  Future<void> upsertTemplate(LocalTemplate template) async {
    await into(localTemplates).insertOnConflictUpdate(template);
  }

  /// Delete user template (system templates cannot be deleted)
  Future<bool> deleteTemplate(String id) async {
    final template = await getTemplate(id);
    if (template == null || template.isSystem) {
      return false; // Cannot delete system templates
    }

    final deleted = await (delete(
      localTemplates,
    )..where((t) => t.id.equals(id))).go();
    return deleted > 0;
  }

  /// Initialize system templates (called on first launch and upgrades)
  Future<void> _initializeSystemTemplates() async {
    final now = DateTime.now();

    final systemTemplates = [
      LocalTemplate(
        id: 'system_meeting_notes',
        title: '📝 Meeting Notes',
        body: '''# Meeting Notes
**Date:** [Date]
**Time:** [Time]
**Attendees:** [Names]

## Agenda
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

## Discussion Points

### Topic 1
- Key points discussed
- Decisions made

### Topic 2
- Key points discussed
- Decisions made

## Action Items
| Task | Owner | Due Date |
|------|-------|----------|
| | | |

## Next Steps
- 

## Follow-up Meeting
- Date: 
- Time: ''',
        tags: '["meeting", "work"]',
        isSystem: true,
        category: 'meeting',
        description:
            'Structured template for meeting notes with agenda and action items',
        icon: 'meeting_room',
        sortOrder: 1,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      ),
      LocalTemplate(
        id: 'system_daily_standup',
        title: '✅ Daily Standup',
        body: '''# Daily Standup - [Date]

## Yesterday
- Completed:
  - 
- Challenges:
  - 

## Today
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Blockers
- None

## Notes
- ''',
        tags: '["daily", "standup", "work"]',
        isSystem: true,
        category: 'work',
        description: 'Daily standup template for agile teams',
        icon: 'today',
        sortOrder: 2,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      ),
      LocalTemplate(
        id: 'system_project_planning',
        title: '💡 Project Planning',
        body: '''# Project: [Name]

## Overview
Brief description of the project and its goals.

## Problem Statement
What problem are we solving?

## Proposed Solution
How will we solve this problem?

## Key Features
1. **Feature 1**
   - Description
   - User benefit
   
2. **Feature 2**
   - Description
   - User benefit

3. **Feature 3**
   - Description
   - User benefit

## Technical Requirements
- Platform: 
- Technology stack: 
- APIs needed: 
- Database requirements: 

## Timeline
| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Research | | |
| Design | | |
| Development | | |
| Testing | | |
| Launch | | |

## Success Metrics
- [ ] Metric 1
- [ ] Metric 2
- [ ] Metric 3

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| | | |

## Next Steps
1. 
2. 
3. ''',
        tags: '["project", "planning", "ideas"]',
        isSystem: true,
        category: 'planning',
        description: 'Comprehensive project planning template',
        icon: 'rocket_launch',
        sortOrder: 3,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      ),
      LocalTemplate(
        id: 'system_book_notes',
        title: '📚 Book Notes',
        body: '''# Book: [Title]
**Author:** [Name]
**Started:** [Date]
**Finished:** [Date]
**Rating:** ⭐⭐⭐⭐⭐

## Summary
Brief overview of the book's main ideas.

## Key Takeaways
1. **Takeaway 1**
   - Why it matters
   
2. **Takeaway 2**
   - Why it matters
   
3. **Takeaway 3**
   - Why it matters

## Favorite Quotes
> "Quote 1" - Page [X]

> "Quote 2" - Page [X]

> "Quote 3" - Page [X]

## Personal Reflections
How does this book relate to my life/work?

What will I do differently after reading this?

## Action Items
- [ ] Apply concept X to my work
- [ ] Research more about Y
- [ ] Share insight Z with team

## Related Books
- 
- ''',
        tags: '["reading", "books", "learning"]',
        isSystem: true,
        category: 'education',
        description: 'Template for capturing insights from books',
        icon: 'menu_book',
        sortOrder: 4,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      ),
      LocalTemplate(
        id: 'system_weekly_review',
        title: '🎯 Weekly Review',
        body: '''# Weekly Review - Week of [Date]

## Wins This Week 🎉
- 
- 
- 

## Challenges Faced 💪
- 
- 
- 

## Goals Completed ✅
- [ ] Goal 1
- [ ] Goal 2
- [ ] Goal 3

## Goals for Next Week 🎯
- [ ] 
- [ ] 
- [ ] 

## Key Learnings 📚
1. 
2. 
3. 

## Gratitude 🙏
Three things I'm grateful for this week:
1. 
2. 
3. 

## Areas for Improvement 📈
- 
- 

## Priority Focus for Next Week
Main focus: 

## Notes & Reflections''',
        tags: '["review", "weekly", "personal"]',
        isSystem: true,
        category: 'review',
        description: 'Weekly review template for personal reflection',
        icon: 'calendar_view_week',
        sortOrder: 5,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Insert system templates
    for (final template in systemTemplates) {
      await into(localTemplates).insertOnConflictUpdate(template);
    }
  }
}

/// ----------------------
/// Connection (mobile)
/// ----------------------
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await resolveAppDocumentsDirectory();
    final file = File(p.join(dir.path, 'duru.sqlite'));
    return NativeDatabase(file);
  });
}
