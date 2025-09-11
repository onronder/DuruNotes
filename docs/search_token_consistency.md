# Search Token Consistency Implementation

## Overview
This document describes how search tokens in NoteSearchDelegate now use the same authoritative filtering logic as Saved Search chips.

## Architecture

### Shared Logic Layer (`lib/data/local/app_db.dart`)
Added static helper methods that can be used both for database queries and in-memory filtering:

```dart
static bool noteHasAttachments(LocalNote note)
static bool noteIsFromEmail(LocalNote note) 
static bool noteIsFromWeb(LocalNote note)
```

Each helper checks multiple sources in order:
1. Metadata fields (authoritative source)
2. Body hashtags (fallback/manual tagging)

### Search Delegate Updates (`lib/ui/note_search_delegate.dart`)
Updated filtering to use the shared helpers:

```dart
// Before: Complex inline logic with different behavior
if (fromEmail) {
  // Multiple nested checks...
}

// After: Consistent with chip behavior
if (fromEmail && !AppDb.noteIsFromEmail(note)) {
  return false;
}
```

## Token Behavior

### `from:email`
Matches notes where:
- Metadata `source` = "email_in" OR "email_inbox"
- OR body contains "#Email"

### `from:web`
Matches notes where:
- Metadata `source` = "web"
- OR body contains "#Web"

### `has:attachment`
Matches notes where:
- Metadata contains `attachments` field
- OR body contains "#Attachment"

### `folder:"Incoming Mail"`
Unchanged - filters to notes in specified folder

### Type and Filename Filters
- `type:pdf` - Filters attachments by MIME type
- `filename:report` - Filters attachments by filename
- These require actual attachment metadata

## Consistency Guarantees

### Search Bar = Chip Results
Typing `from:web design` in search bar returns:
- Same set as clicking "Web Clips" chip then searching "design"
- Both use `AppDb.noteIsFromWeb()` for filtering

### No False Negatives
- Email note without #Email tag: ✓ Found
- Web clip without #Web tag: ✓ Found  
- Note with attachments but no #Attachment tag: ✓ Found

### Performance
- In-memory filtering for search delegate
- No additional database queries
- Fast metadata parsing with try-catch

## Testing

### Manual Test Cases

1. **Search Token vs Chip - Email**
   - Click "Email Notes" chip → Note count = X
   - Type `from:email` in search → Note count = X
   - Add keyword: `from:email meeting` → Subset of X

2. **Search Token vs Chip - Web**
   - Click "Web Clips" chip → Note count = Y
   - Type `from:web` in search → Note count = Y
   - Add keyword: `from:web article` → Subset of Y

3. **Search Token vs Chip - Attachments**
   - Click "Attachments" chip → Note count = Z
   - Type `has:attachment` in search → Note count = Z
   - Add type: `has:attachment type:pdf` → PDF subset

4. **Combined Tokens**
   - `from:email has:attachment` → Email notes with attachments
   - `from:web react` → Web clips mentioning React

### Edge Cases Tested

1. **Missing Tags**: Note from email without #Email tag
   - Chip: ✓ Shows in list
   - Token: ✓ Shows in search

2. **Manual Tags**: Regular note with #Web added manually
   - Chip: ✓ Shows in list
   - Token: ✓ Shows in search

3. **Invalid Metadata**: Corrupted JSON in encryptedMetadata
   - Falls back to tag checking
   - No crashes, graceful degradation

## Implementation Benefits

1. **Single Source of Truth**: One logic definition used everywhere
2. **Maintainability**: Changes to filtering logic in one place
3. **Consistency**: Users get same results regardless of entry point
4. **Backwards Compatible**: Existing searches continue to work
5. **Future Proof**: Easy to add new search tokens with same pattern
