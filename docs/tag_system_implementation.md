# Tag System Implementation - Complete Guide

## Overview

This document describes the comprehensive tag system implementation with normalized storage, offline-first sync, and UI components for the Duru Notes app. The implementation follows production-grade standards and enhances existing code without breaking functionality.

## Architecture Decisions

### 1. Normalized Tag Storage
- Tags are stored as **lowercase** in the database for consistency
- Display casing is preserved in-session for better UX
- Ensures "Travel", "travel", and "TRAVEL" are treated as the same tag
- No separate tags table - tags are stored directly in `note_tags` table

### 2. Offline-First Approach
- All tag operations work offline with immediate UI feedback
- Changes are queued in `pending_ops` for later sync
- Tag operations sync after note operations to ensure consistency

## Database Layer (AppDb)

### New DAO Methods

#### 1. `getTagsWithCounts()`
```dart
Future<List<TagCount>> getTagsWithCounts()
```
- Returns all tags with their note counts
- Excludes deleted notes
- Ordered by count (descending) then alphabetically

#### 2. `addTagToNote()`
```dart
Future<void> addTagToNote(String noteId, String rawTag)
```
- Adds a normalized tag to a note
- Idempotent - duplicate additions are ignored
- Automatically trims and lowercases the tag

#### 3. `removeTagFromNote()`
```dart
Future<void> removeTagFromNote(String noteId, String rawTag)
```
- Removes a tag from a note
- Normalizes the tag before removal

#### 4. `renameTagEverywhere()`
```dart
Future<int> renameTagEverywhere(String fromRaw, String toRaw)
```
- Renames/merges a tag across all notes
- Handles conflicts with existing tags automatically
- Returns count of affected rows

#### 5. `notesByTags()`
```dart
Future<List<LocalNote>> notesByTags({
  required List<String> anyTags,
  List<String> noneTags = const [],
  SortBy sortBy = SortBy.updatedAt,
  bool ascending = false,
})
```
- Filters notes by tags (union of anyTags, excluding noneTags)
- Supports multiple sort options
- Pinned notes always appear first

### Updated Methods

#### `replaceTagsForNote()`
- Now normalizes all tags to lowercase before storage
- Filters out empty tags

#### `notesWithTag()`
- Normalizes the query tag
- Orders results with pinned notes first

#### `searchTags()`
- Performs normalized prefix search
- Returns up to 20 matching tags

## Repository Layer (NotesRepository)

### New Tag Management Methods

#### `listTagsWithCounts()`
- Wrapper for `db.getTagsWithCounts()`
- Used by TagsScreen and autocomplete

#### `addTag()`
```dart
Future<void> addTag({required String noteId, required String tag})
```
- Adds tag to local database
- Enqueues `upsert_note_tag` operation for sync

#### `removeTag()`
```dart
Future<void> removeTag({required String noteId, required String tag})
```
- Removes tag from local database
- Enqueues `delete_note_tag` operation for sync

#### `renameTagEverywhere()`
```dart
Future<int> renameTagEverywhere({required String from, required String to})
```
- Bulk rename/merge tags
- Enqueues `rename_tag` operation for sync

#### `queryNotesByTags()`
```dart
Future<List<LocalNote>> queryNotesByTags({
  required List<String> anyTags,
  List<String> noneTags = const [],
  SortBy sortBy = SortBy.updatedAt,
  bool ascending = false,
})
```
- Query notes by tag filters
- Supports inclusion and exclusion lists

#### `searchTags()`
- Autocomplete support for tag input

#### `getTagsForNote()`
- Get all tags for a specific note

### Extended Pending Operations

Added handling for new operation types in `pushAllPending()`:
- `upsert_note_tag`: Add tag to note
- `delete_note_tag`: Remove tag from note  
- `rename_tag`: Bulk rename tag (optional)

## UI Components

### NoteTagChips Widget

Located in `/lib/ui/widgets/note_tag_chips.dart`

#### Features
- Displays tags as chips with delete buttons
- "+" button to add new tags
- Remembers display casing for current session
- Autocomplete dialog with popular tags

#### Usage
```dart
NoteTagChips(
  noteId: noteId,
  onTagsChanged: () {
    // Handle tag changes
  },
)
```

### Tag Autocomplete Dialog

#### Features
- Shows popular tags when empty
- Real-time search suggestions
- Filters out already-added tags
- Allows free-form tag entry

## Integration Points

### 1. Note Editor
Add `NoteTagChips` widget below the title or in the toolbar:
```dart
Container(
  padding: EdgeInsets.all(16),
  child: NoteTagChips(
    noteId: widget.noteId,
    onTagsChanged: _handleTagsChanged,
  ),
)
```

### 2. Search Integration
When implementing search parser, handle tag tokens:
- `#tag` → add to `anyTags` filter
- `-#tag` → add to `noneTags` filter

Example:
```dart
if (token.startsWith('#')) {
  anyTags.add(token.substring(1).toLowerCase());
} else if (token.startsWith('-#')) {
  noneTags.add(token.substring(2).toLowerCase());
}
```

### 3. Saved Searches
Store tag filters in saved search parameters:
```dart
final search = SavedSearch(
  id: uuid.v4(),
  name: 'Work Notes',
  query: '#work -#personal',
  searchType: 'compound',
  parameters: jsonEncode({
    'anyTags': ['work'],
    'noneTags': ['personal'],
  }),
  // ...
);
```

## Existing Screens Enhanced

### TagsScreen
- Already displays tags with counts
- Tapping a tag navigates to filtered notes
- Pull-to-refresh support
- Search functionality

### TagNotesScreen  
- Shows notes with a specific tag
- Already normalized tag queries
- Supports pinned notes first
- Integrates with saved searches

## Testing Checklist

### Offline Operations
- [x] Add tag while offline - persists after restart
- [x] Remove tag while offline - persists after restart
- [x] Multiple tag operations queue properly
- [x] Tags sync after reconnection

### Normalization
- [x] "Travel" and "travel" treated as same tag
- [x] Whitespace is trimmed
- [x] Empty tags are ignored

### UI Behavior
- [x] Tag chips appear immediately on add
- [x] Tag chips disappear immediately on remove
- [x] Autocomplete shows relevant suggestions
- [x] Display casing preserved in session

### Data Integrity
- [x] Deleted notes excluded from tag counts
- [x] Duplicate tags prevented (idempotent add)
- [x] Tag rename/merge handles conflicts

## Performance Optimizations

1. **Normalized storage**: Faster queries and deduplication
2. **Indexed columns**: Tag queries use existing indexes
3. **Limited suggestions**: Autocomplete returns max 20 results
4. **Cached display casing**: Avoids repeated lookups

## Migration Notes

No schema migration required - the existing `note_tags` table is used with normalized values. New tags are automatically normalized on insert.

## Future Enhancements

1. **Bulk tag operations**: Select multiple notes to add/remove tags
2. **Tag colors/icons**: Visual differentiation
3. **Tag hierarchies**: Nested tags like "work/projects/2024"
4. **Smart tag suggestions**: Based on note content
5. **Tag aliases**: Multiple names for the same concept

## Example Usage Flow

1. User creates a note
2. User clicks "+ Tag" chip
3. Autocomplete shows popular tags
4. User types "tra" - sees "travel" suggestion
5. User selects or types "Travel" (any case)
6. Tag is stored as "travel" in database
7. Chip shows "#Travel" (preserved casing)
8. Operation queued for sync
9. On reconnection, tag syncs to server

## API Compatibility

The tag system is designed to work with the existing Supabase API. Tags are included in the note's encrypted properties during sync. No new API endpoints are required for basic functionality.

## Summary

This implementation provides a robust, normalized tag system that:
- Works fully offline with sync capabilities
- Prevents duplicate tags through normalization
- Provides intuitive UI with autocomplete
- Integrates seamlessly with existing code
- Follows production-grade standards
- Maintains backward compatibility

The system is ready for production use and can be extended with additional features as needed.
