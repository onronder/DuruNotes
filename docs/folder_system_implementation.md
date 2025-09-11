# Folder System Implementation - Complete Guide

## Overview

This document describes the complete implementation of the folder system with FTS synchronization, pinning, and saved searches for the Duru Notes app.

## Database Schema Changes (Version 8)

### 1. New/Modified Tables

#### LocalNotes (Modified)
```sql
-- Added column:
is_pinned BOOLEAN DEFAULT 0 NOT NULL  -- For pinning notes to top
```

#### SavedSearches (New)
```sql
CREATE TABLE saved_searches (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  query TEXT NOT NULL,
  search_type TEXT DEFAULT 'text',  -- 'text', 'tag', 'folder', 'date_range', 'compound'
  parameters TEXT,  -- JSON for additional params
  sort_order INTEGER DEFAULT 0,
  color TEXT,  -- Hex color for display
  icon TEXT,   -- Icon name
  is_pinned BOOLEAN DEFAULT 0,
  created_at DATETIME NOT NULL,
  last_used_at DATETIME,
  usage_count INTEGER DEFAULT 0
);
```

### 2. FTS Synchronization Triggers

The key innovation is automatic synchronization of `fts_notes.folder_path` when folders or note-folder mappings change:

```sql
-- When a note is mapped to a folder
CREATE TRIGGER trg_note_folders_ai
AFTER INSERT ON note_folders
BEGIN
  UPDATE fts_notes
  SET folder_path = (SELECT path FROM local_folders WHERE id = NEW.folder_id)
  WHERE id = NEW.note_id;
END;

-- When a note's folder mapping changes
CREATE TRIGGER trg_note_folders_au
AFTER UPDATE ON note_folders
BEGIN
  UPDATE fts_notes
  SET folder_path = (SELECT path FROM local_folders WHERE id = NEW.folder_id)
  WHERE id = NEW.note_id;
END;

-- When a note is removed from a folder
CREATE TRIGGER trg_note_folders_ad
AFTER DELETE ON note_folders
BEGIN
  UPDATE fts_notes SET folder_path = NULL WHERE id = OLD.note_id;
END;

-- When a folder's path changes (rename/move)
CREATE TRIGGER trg_local_folders_au_path
AFTER UPDATE OF name, parent_id, path ON local_folders
BEGIN
  UPDATE fts_notes
  SET folder_path = NEW.path
  WHERE id IN (
    SELECT note_id FROM note_folders WHERE folder_id = NEW.id
  );
END;
```

### 3. Extended PendingOps

The `pending_ops.kind` field now supports:
- `upsert_note`, `delete_note` (existing)
- `upsert_folder`, `delete_folder` (new)
- `upsert_tag`, `delete_tag` (new)
- `upsert_saved_search`, `delete_saved_search` (new)

## Repository Layer

### FolderRepository

Located in `/lib/repository/folder_repository.dart`, provides:

#### Core Folder Operations
```dart
// Create folder with automatic path generation
Future<LocalFolder> createFolder({
  required String name,
  String? parentId,
  String? color,
  String? icon,
  String? description,
});

// Rename with descendant path updates
Future<void> renameFolder({
  required String folderId,
  required String newName,
});

// Move with cycle prevention
Future<void> moveFolder({
  required String folderId,
  String? newParentId,
});

// Soft delete with note preservation
Future<void> deleteFolder({
  required String folderId,
  bool moveNotesToInbox = true,
});
```

#### Note-Folder Management
```dart
// Move note to folder with FTS sync
Future<void> moveNoteToFolder({
  required String noteId,
  String? folderId,
});

// Watch notes with sorting
Stream<List<LocalNote>> watchNotesInFolder({
  String? folderId,
  required SortSpec sort,
});
```

#### Helper Features
```dart
// Get folder hierarchy for breadcrumbs
Future<List<LocalFolder>> getFolderBreadcrumbs(String folderId);

// Get folder statistics
Future<Map<String, dynamic>> getFolderStats(String folderId);

// Search folders by name
Future<List<LocalFolder>> searchFolders(String query);
```

## UI Components

### 1. FolderTreeWidget

A complete folder hierarchy viewer with:
- Expandable/collapsible tree structure
- Note counts per folder
- Inline actions (create, rename, move, delete)
- Visual indicators (colors, icons)
- Inbox for unfiled notes

### 2. FolderBreadcrumbsWidget

Navigation breadcrumbs showing:
- Full path from root to current folder
- Clickable navigation to parent folders
- Visual distinction for current folder
- Horizontal scrolling for deep hierarchies

## Migration Strategy

The migration from v7 to v8 handles:
1. Adding `is_pinned` column to `local_notes`
2. Creating `saved_searches` table
3. Installing folder sync triggers
4. Creating saved search indexes
5. Syncing existing folder paths to FTS

## Usage Examples

### Creating a Folder Structure
```dart
final folderRepo = FolderRepository(db: db, userId: userId);

// Create root folder
final workFolder = await folderRepo.createFolder(
  name: 'Work',
  color: '#2196F3',
  icon: 'work',
);

// Create subfolder
final projectsFolder = await folderRepo.createFolder(
  name: 'Projects',
  parentId: workFolder.id,
  description: 'Active projects',
);

// Move note to folder
await folderRepo.moveNoteToFolder(
  noteId: noteId,
  folderId: projectsFolder.id,
);
```

### Watching Notes in Folder
```dart
// Watch notes with pinned first
final notesStream = folderRepo.watchNotesInFolder(
  folderId: folderId,
  sort: SortSpec(
    sortBy: SortBy.pinned,
    order: SortOrder.desc,
  ),
);
```

### Saving a Search
```dart
final search = SavedSearch(
  id: uuid.v4(),
  name: 'Recent Work Notes',
  query: 'folder:/Work updated:week',
  searchType: 'compound',
  parameters: jsonEncode({
    'folder': '/Work',
    'dateRange': 'week',
  }),
  isPinned: true,
  createdAt: DateTime.now(),
  usageCount: 0,
);

await db.upsertSavedSearch(search);
```

## Performance Optimizations

1. **Trigger-based FTS sync**: Eliminates need for manual updates
2. **Path-based hierarchy**: Fast breadcrumb generation without recursive queries
3. **Indexed searches**: All critical columns have appropriate indexes
4. **Stream-based UI**: Reactive updates without polling

## Testing Checklist

- [ ] Create nested folder structure
- [ ] Move notes between folders
- [ ] Rename folder and verify FTS updates
- [ ] Delete folder and verify notes move to inbox
- [ ] Pin/unpin notes and verify sort order
- [ ] Create and use saved searches
- [ ] Verify offline operation queuing
- [ ] Test folder cycle prevention
- [ ] Verify breadcrumb navigation
- [ ] Test folder search functionality

## Next Steps

1. **Tags System**: Similar pattern for tag management
2. **Search UI**: Implement search chips and query builder
3. **Sync Service**: Handle server synchronization for folders
4. **Batch Operations**: Multi-select for bulk moves
5. **Smart Folders**: Dynamic folders based on queries

## Migration SQL

To manually verify the migration:
```sql
-- Check FTS table structure
SELECT sql FROM sqlite_master WHERE name = 'fts_notes';

-- Verify triggers exist
SELECT name FROM sqlite_master 
WHERE type = 'trigger' 
AND name LIKE 'trg_%folder%';

-- Test folder path sync
UPDATE local_folders 
SET name = 'NewName', path = '/NewName' 
WHERE id = 'test-folder-id';

-- Verify FTS was updated
SELECT folder_path FROM fts_notes 
WHERE id IN (
  SELECT note_id FROM note_folders 
  WHERE folder_id = 'test-folder-id'
);
```

## Architecture Benefits

1. **Coherent Search**: FTS always reflects current folder structure
2. **Offline-First**: All operations work offline with queue
3. **Type-Safe**: Drift provides compile-time safety
4. **Reactive**: Stream-based updates throughout
5. **Scalable**: Trigger-based sync handles any volume

This implementation provides a solid foundation for hierarchical organization while maintaining search performance and offline capabilities.
