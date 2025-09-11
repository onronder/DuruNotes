# DuruNotes Local Database Report

## Database Overview
- **Database Type**: SQLite with Drift ORM (formerly Moor)
- **Database File**: `duru.sqlite` (stored in application documents directory)
- **Current Schema Version**: 7
- **Database Location**: `~/Documents/duru.sqlite` (Platform specific)

## Core Tables

### 1. **local_notes** (LocalNotes)
Main table for storing notes locally.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT | PRIMARY KEY | Unique identifier for the note |
| title | TEXT | DEFAULT '' | Note title |
| body | TEXT | DEFAULT '' | Note content |
| updated_at | DATETIME | NOT NULL | Last modification timestamp |
| deleted | BOOLEAN | DEFAULT false | Soft delete flag |
| encrypted_metadata | TEXT | NULLABLE | Encrypted metadata for attachments and email info |

### 2. **pending_ops** (PendingOps)
Queue for synchronization operations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Operation ID |
| entity_id | TEXT | NOT NULL | ID of the entity being operated on |
| kind | TEXT | NOT NULL | Operation type: 'upsert_note' or 'delete_note' |
| payload | TEXT | NULLABLE | JSON payload for the operation |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | When operation was queued |

### 3. **note_tags** (NoteTags)
Many-to-many relationship for note tags.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| note_id | TEXT | COMPOSITE PRIMARY KEY | Reference to note |
| tag | TEXT | COMPOSITE PRIMARY KEY | Tag name |

### 4. **note_links** (NoteLinks)
Backlinks/forward links between notes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| source_id | TEXT | COMPOSITE PRIMARY KEY | Source note ID |
| target_title | TEXT | COMPOSITE PRIMARY KEY | Title of linked note |
| target_id | TEXT | NULLABLE | ID of target note (if resolved) |

### 5. **note_reminders** (NoteReminders)
Advanced reminder system for notes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Reminder ID |
| note_id | TEXT | NOT NULL | Associated note ID |
| title | TEXT | DEFAULT '' | Reminder title |
| body | TEXT | DEFAULT '' | Reminder body text |
| type | INTEGER (ENUM) | NOT NULL | ReminderType: time/location/recurring |
| remind_at | DATETIME | NULLABLE | When to trigger (UTC) |
| is_active | BOOLEAN | DEFAULT true | Whether reminder is active |
| **Location Fields** |
| latitude | REAL | NULLABLE | Geofence latitude |
| longitude | REAL | NULLABLE | Geofence longitude |
| radius | REAL | NULLABLE | Geofence radius in meters |
| location_name | TEXT | NULLABLE | Location description |
| **Recurrence Fields** |
| recurrence_pattern | INTEGER (ENUM) | DEFAULT none | daily/weekly/monthly/yearly |
| recurrence_end_date | DATETIME | NULLABLE | When recurrence ends |
| recurrence_interval | INTEGER | DEFAULT 1 | Every X days/weeks/months |
| **Snooze Fields** |
| snoozed_until | DATETIME | NULLABLE | Snooze end time |
| snooze_count | INTEGER | DEFAULT 0 | Number of times snoozed |
| **Notification Fields** |
| notification_title | TEXT | NULLABLE | Custom notification title |
| notification_body | TEXT | NULLABLE | Custom notification body |
| notification_image | TEXT | NULLABLE | Notification image path/URL |
| **Metadata** |
| time_zone | TEXT | NULLABLE | User's timezone |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| last_triggered | DATETIME | NULLABLE | Last trigger time |
| trigger_count | INTEGER | DEFAULT 0 | Number of triggers |

### 6. **local_folders** (LocalFolders)
Hierarchical folder system for organizing notes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT | PRIMARY KEY | Unique folder identifier |
| name | TEXT | NOT NULL | Folder display name |
| parent_id | TEXT | NULLABLE | Parent folder ID (null for root) |
| path | TEXT | NOT NULL | Full path (e.g., "/Work/Projects") |
| sort_order | INTEGER | DEFAULT 0 | Display order within parent |
| color | TEXT | NULLABLE | Hex color for display |
| icon | TEXT | NULLABLE | Icon name for display |
| description | TEXT | DEFAULT '' | Folder description |
| created_at | DATETIME | NOT NULL | Creation timestamp |
| updated_at | DATETIME | NOT NULL | Last modification timestamp |
| deleted | BOOLEAN | DEFAULT false | Soft delete flag |

### 7. **note_folders** (NoteFolders)
Maps notes to folders (one note per folder).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| note_id | TEXT | PRIMARY KEY | Note ID (one folder per note) |
| folder_id | TEXT | NOT NULL | Folder ID |
| added_at | DATETIME | NOT NULL | When note was added to folder |

## Full-Text Search Tables

### 8. **fts_notes** (Virtual FTS5 Table)
SQLite FTS5 virtual table for full-text search.

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT UNINDEXED | Note ID (not searchable) |
| title | TEXT | Searchable note title |
| body | TEXT | Searchable note content |
| folder_path | TEXT UNINDEXED | Folder path (not searchable) |

## Database Indexes

### Performance Indexes
1. `idx_local_notes_updated_notdeleted` - ON local_notes(updated_at DESC) WHERE deleted = 0
2. `idx_note_tags_tag` - ON note_tags(tag)
3. `idx_note_links_target_title` - ON note_links(target_title)

### Reminder Indexes
4. `idx_note_reminders_remind_at` - ON note_reminders(remind_at)
5. `idx_note_reminders_note_id` - ON note_reminders(note_id)
6. `idx_note_reminders_type` - ON note_reminders(type)
7. `idx_note_reminders_active` - ON note_reminders(is_active)
8. `idx_note_reminders_location` - ON note_reminders(latitude, longitude) WHERE latitude IS NOT NULL
9. `idx_note_reminders_snoozed` - ON note_reminders(snoozed_until) WHERE snoozed_until IS NOT NULL
10. `idx_note_reminders_next_trigger` - ON note_reminders(remind_at, is_active) WHERE remind_at IS NOT NULL

### Folder Indexes
11. `idx_local_folders_parent_id` - ON local_folders(parent_id)
12. `idx_local_folders_path` - ON local_folders(path)
13. `idx_local_folders_deleted` - ON local_folders(deleted)
14. `idx_local_folders_sort_order` - ON local_folders(parent_id, sort_order)
15. `idx_note_folders_folder_id` - ON note_folders(folder_id)

## Database Triggers

### FTS Synchronization Triggers
1. **trg_local_notes_ai** (AFTER INSERT)
   - Adds new notes to FTS index when inserted (if not deleted)

2. **trg_local_notes_au** (AFTER UPDATE)
   - Updates FTS index when notes are modified
   - Removes from FTS if marked as deleted

3. **trg_local_notes_ad** (AFTER DELETE)
   - Removes notes from FTS index when deleted

## Enumerations

### ReminderType
- `time` - Time-based reminder
- `location` - Location-based reminder (geofence)
- `recurring` - Recurring reminder

### RecurrencePattern
- `none` - No recurrence
- `daily` - Daily recurrence
- `weekly` - Weekly recurrence
- `monthly` - Monthly recurrence
- `yearly` - Yearly recurrence

### SnoozeDuration
- `fiveMinutes` - 5 minutes
- `tenMinutes` - 10 minutes
- `fifteenMinutes` - 15 minutes
- `thirtyMinutes` - 30 minutes
- `oneHour` - 1 hour
- `twoHours` - 2 hours
- `tomorrow` - Next day

## Migration History

### Version 1 (Initial)
- Created base tables: local_notes, pending_ops

### Version 2
- Added note_tags table
- Added note_links table

### Version 3
- Created FTS5 virtual table
- Added synchronization triggers
- Created performance indexes

### Version 4
- Added note_reminders table
- Created reminder indexes

### Version 5
- Migrated to advanced reminders system
- Added location-based reminders
- Added recurring reminders
- Enhanced notification customization

### Version 6
- Added folder system (local_folders, note_folders)
- Created folder indexes
- Updated FTS to include folder paths
- Created default folders

### Version 7 (Current)
- Added encrypted_metadata column to local_notes
- Support for email attachments and metadata persistence

## Key Features

1. **Full-Text Search**: Uses SQLite FTS5 for fast, efficient text search
2. **Soft Deletes**: Notes and folders use soft delete flags for recovery
3. **Hierarchical Organization**: Folder system with parent-child relationships
4. **Advanced Reminders**: Time, location, and recurring reminders with snooze
5. **Backlinks**: Automatic tracking of note-to-note links
6. **Tags**: Flexible tagging system for notes
7. **Offline-First**: Pending operations queue for sync when online
8. **Encrypted Metadata**: Secure storage of sensitive attachment info

## Database Access Patterns

### Common Queries
- Notes by updated date (with pagination)
- Notes by title prefix (autocomplete)
- Full-text search across all notes
- Tags with note counts
- Backlinks resolution
- Active reminders by time
- Folder hierarchy traversal
- Notes in specific folders

### Write Operations
- Upsert notes with conflict resolution
- Batch operations for tags and links
- Queue sync operations
- Folder hierarchy management
- Reminder scheduling

## Storage Statistics
- Database file: `duru.sqlite`
- Typical size: Varies based on content (10MB - 500MB+)
- FTS index: Additional 20-30% of content size
- Backup recommended: Daily or on significant changes

## Performance Considerations
1. All frequently queried columns are indexed
2. FTS5 provides sub-millisecond search on thousands of notes
3. Keyset pagination used for large result sets
4. Batch operations minimize transaction overhead
5. Triggers maintain data consistency automatically

## Security Notes
- Sensitive metadata is encrypted using app-level encryption
- Database file is stored in app's private documents directory
- No sensitive data in plain text (except note content which users expect to see)
- Secure storage used for encryption keys

---

*Generated on: Thursday, September 11, 2025*
*Database Schema Version: 7*
*Drift ORM Version: 2.28.1*
