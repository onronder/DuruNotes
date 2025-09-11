# Tag System Integration Guide

## Quick Start - Adding Tags to Note Editor

To integrate the tag system into your existing note editor, follow these steps:

### 1. Import the Tag Chips Widget

In your note editor screen (e.g., `ModernEditNoteScreen`):

```dart
import 'package:duru_notes/ui/widgets/note_tag_chips.dart';
```

### 2. Add Tag Chips to the UI

Place the widget where you want tags to appear (typically below the title or in a toolbar):

```dart
// In your build method, after the title field:
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: NoteTagChips(
    noteId: widget.noteId ?? _currentNoteId,
    onTagsChanged: () {
      // Optional: Handle tag changes
      setState(() {
        _hasUnsavedChanges = true;
      });
    },
  ),
)
```

### 3. Example Full Integration

```dart
Column(
  children: [
    // Title field
    TextField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: 'Note title',
      ),
    ),
    
    // Tag chips (NEW)
    if (widget.noteId != null)
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: NoteTagChips(
          noteId: widget.noteId!,
          onTagsChanged: _handleTagsChanged,
        ),
      ),
    
    // Body field
    Expanded(
      child: TextField(
        controller: _bodyController,
        maxLines: null,
        decoration: InputDecoration(
          hintText: 'Start typing...',
        ),
      ),
    ),
  ],
)
```

## Using Tags in Search

### 1. Basic Tag Filtering

```dart
// Get notes with specific tags
final repo = ref.read(notesRepositoryProvider);
final notes = await repo.queryNotesByTags(
  anyTags: ['work', 'important'],  // Notes with ANY of these tags
  noneTags: ['archive'],           // Exclude notes with these tags
  sortBy: SortBy.updatedAt,
  ascending: false,
);
```

### 2. Tag Autocomplete

```dart
// Get tag suggestions for autocomplete
final suggestions = await repo.searchTags('tra');
// Returns: ['travel', 'training', 'transportation', ...]
```

### 3. Display All Tags

```dart
// Get all tags with counts
final tags = await repo.listTagsWithCounts();
for (final tag in tags) {
  print('${tag.tag}: ${tag.count} notes');
}
```

## Programmatic Tag Management

### Add Tag to Note

```dart
final repo = ref.read(notesRepositoryProvider);
await repo.addTag(
  noteId: 'note-123',
  tag: 'important',
);
```

### Remove Tag from Note

```dart
await repo.removeTag(
  noteId: 'note-123',
  tag: 'draft',
);
```

### Rename Tag Globally

```dart
// Rename 'todo' to 'task' across all notes
final affected = await repo.renameTagEverywhere(
  from: 'todo',
  to: 'task',
);
print('Updated $affected tag references');
```

## Search Integration Example

When implementing search with tag support:

```dart
class SearchParser {
  SearchQuery parse(String input) {
    final tokens = input.split(' ');
    final anyTags = <String>[];
    final noneTags = <String>[];
    final keywords = <String>[];
    
    for (final token in tokens) {
      if (token.startsWith('#')) {
        // Include tag
        anyTags.add(token.substring(1).toLowerCase());
      } else if (token.startsWith('-#')) {
        // Exclude tag
        noneTags.add(token.substring(2).toLowerCase());
      } else {
        // Regular keyword
        keywords.add(token);
      }
    }
    
    return SearchQuery(
      keywords: keywords,
      anyTags: anyTags,
      noneTags: noneTags,
    );
  }
}

// Usage
final query = parser.parse('meeting #work -#personal');
// Result: 
// - keywords: ['meeting']
// - anyTags: ['work']
// - noneTags: ['personal']
```

## Saved Search with Tags

```dart
// Save a search that includes tag filters
final search = SavedSearch(
  id: _uuid.v4(),
  name: 'Active Projects',
  query: '#project -#completed',
  searchType: 'compound',
  parameters: jsonEncode({
    'anyTags': ['project'],
    'noneTags': ['completed'],
    'sortBy': 'updatedAt',
  }),
  isPinned: true,
  createdAt: DateTime.now(),
  usageCount: 0,
);

await db.upsertSavedSearch(search);
```

## Testing Tag Features

### Manual Testing Steps

1. **Add Tags**:
   - Open a note
   - Click "+ Tag" chip
   - Type "Work" and press Enter
   - Verify chip shows "#work"

2. **Remove Tags**:
   - Click X on a tag chip
   - Verify tag is removed immediately

3. **Offline Sync**:
   - Turn on Airplane Mode
   - Add/remove tags
   - Close and reopen app
   - Verify tags persist
   - Turn off Airplane Mode
   - Verify tags sync

4. **Normalization**:
   - Add tag "Travel"
   - Try to add "travel" again
   - Verify duplicate is prevented

5. **Search**:
   - Search for "#work"
   - Verify only notes with work tag appear
   - Search for "-#personal"
   - Verify personal notes are excluded

## Common Issues & Solutions

### Tags Not Showing
- Ensure noteId is provided to NoteTagChips
- Check that note exists in database

### Duplicate Tags Appearing
- Tags should be normalized (lowercase)
- Check addTagToNote uses insertOrIgnore mode

### Tags Not Syncing
- Verify pending_ops contains tag operations
- Check pushAllPending handles tag op types

### Autocomplete Not Working
- Ensure searchTags returns results
- Check that existing tags are filtered out

## Performance Tips

1. **Batch Operations**: When adding multiple tags, consider using a transaction
2. **Limit Suggestions**: Tag autocomplete returns max 20 results
3. **Cache Popular Tags**: Store frequently used tags locally
4. **Index Usage**: Tag queries use existing database indexes

## Next Steps

1. Implement search parser with tag token support
2. Add tag management UI to settings
3. Create tag-based smart folders
4. Add tag colors and icons
5. Implement tag hierarchies

The tag system is now fully functional and ready for integration into your UI!
