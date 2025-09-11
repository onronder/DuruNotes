# Saved Search Hardening Implementation

## Overview
This document describes the hardening of Saved Search functionality to ensure authoritative, complete results with no false negatives.

## Problem Statement
Previously, Saved Search chips relied solely on hashtags, which could miss notes that should be included:
- Notes with attachments but missing #Attachment tag
- Email notes without #Email tag
- Web clips without #Web tag

## Solution Architecture

### 1. Authoritative Data Layer (`lib/data/local/app_db.dart`)
Added `notesForSavedSearch()` method that combines multiple predicates:

```dart
Future<List<LocalNote>> notesForSavedSearch({
  required String savedSearchKey,
}) async
```

#### Search Logic

**Attachments Search:**
- Notes with `#Attachment` tag in note_tags table
- OR notes with `attachments` field in encrypted metadata  
- OR notes with `#Attachment` in body text

**Email Notes Search:**
- Notes with `#Email` tag in note_tags table
- OR notes with `source: "email_in"` in metadata
- OR notes with `#Email` in body text

**Web Clips Search:**
- Notes with `#Web` tag in note_tags table
- OR notes with `source: "web"` in metadata
- OR notes with `#Web` in body text

### 2. UI Layer Updates

#### TagNotesScreen (`lib/ui/tag_notes_screen.dart`)
- Added optional `savedSearchKey` parameter
- When provided, uses `notesForSavedSearch()` instead of `notesWithTag()`
- Preserves friendly empty state messages

#### NotesListScreen (`lib/ui/notes_list_screen.dart`)
- Maps `SavedSearchKey` enum to string keys
- Passes `savedSearchKey` when navigating to TagNotesScreen
- Maintains existing routing logic for Inbox (folder-based)

### 3. Registry (`lib/search/saved_search_registry.dart`)
- Already has proper keys defined in `SavedSearchKey` enum
- No changes needed - keys are properly mapped in UI layer

## Data Flow

1. User taps Saved Search chip
2. `_handleSavedSearchTap()` determines search type
3. For tag-based searches:
   - Maps SavedSearchKey to string
   - Navigates to TagNotesScreen with savedSearchKey
4. TagNotesScreen calls `notesForSavedSearch()`
5. Database combines all predicates to return complete results

## Guarantees

### ✅ No False Negatives
- **Attachments**: Shows ALL notes with attachments regardless of tagging
- **Email Notes**: Shows ALL email-sourced notes regardless of tagging
- **Web Clips**: Shows ALL web-sourced notes regardless of tagging

### ✅ Performance
- Uses SQL queries with appropriate indices
- LEFT JOINs prevent missing untagged notes
- DISTINCT prevents duplicates from multiple matches

### ✅ Backward Compatibility
- Original `notesWithTag()` method unchanged
- Other features using tag-based search unaffected
- Metadata structure unchanged

## Testing Scenarios

### Test Case 1: Email without Tag
1. Create email note via email-in
2. Remove #Email tag manually
3. Tap "Email Notes" chip
4. **Expected**: Note still appears (metadata source = "email_in")

### Test Case 2: Attachment without Tag
1. Add attachment to note
2. Don't add #Attachment tag
3. Tap "Attachments" chip
4. **Expected**: Note appears (has attachments in metadata)

### Test Case 3: Web Clip without Tag
1. Create note via web clipper
2. Remove #Web tag
3. Tap "Web Clips" chip  
4. **Expected**: Note appears (metadata source = "web")

### Test Case 4: Manual Tags
1. Add #Email to any note manually
2. Tap "Email Notes" chip
3. **Expected**: Note appears even without email metadata

## Edge Cases Handled

1. **Multiple matches**: DISTINCT prevents duplicates
2. **Missing metadata**: Falls back to tag/body checks
3. **Encrypted metadata**: Uses LIKE for JSON field matching
4. **Unknown keys**: Returns empty list safely

## Future Enhancements

1. Add attachment count from attachment table joins
2. Create database indices for metadata JSON fields
3. Consider full-text search integration for body hashtags
4. Add telemetry to track false negative prevention
