# E2.20 Save Search Implementation

## Summary
Implemented the ability to save any current search query (with keywords, folder, tags, pinned status, and sort) as a Saved Search, which immediately appears as a chip in the saved search row.

## Implementation Details

### 1. **Save Search Button** (`lib/ui/note_search_delegate.dart`)
- Added bookmark icon in search AppBar when query is non-empty
- Icon triggers save dialog with name validation
- Parses current query using SearchParser to extract all filters
- Builds comprehensive parameters map from parsed query

### 2. **Save Dialog with Validation**
- Shows modal dialog with TextField for search name
- Auto-suggests name based on query content:
  - Tag searches: "#tag1 #tag2"
  - Keyword searches: First 20 chars of keywords
  - Full query as fallback
- Validates against duplicate names (case-insensitive)
- Shows inline error for empty or duplicate names
- Uses StatefulBuilder for reactive error handling

### 3. **Database Persistence**
- Creates SavedSearch object with:
  - Unique UUID as ID
  - User-provided name
  - Original query string
  - Search type (text, tag, folder, filter)
  - JSON-encoded parameters
  - Usage tracking fields (count, lastUsedAt)
  - Pin status and sort order
- Saves via `NotesRepository.createOrUpdateSavedSearch()`
- Automatically enqueues for sync with `upsert_saved_search` operation

### 4. **Instant Chip Display** (`lib/ui/widgets/saved_search_chips.dart`)
- Enhanced widget to show both presets and custom searches
- Watches `savedSearchesStreamProvider` for real-time updates
- Custom searches display with bookmark icon (filled if pinned)
- Single scrollable row maintained (no vertical stacking)
- Separate handlers for preset vs custom search taps

### 5. **Search Execution**
- Custom search tap updates usage statistics
- Opens search delegate with saved query
- Query automatically parsed and applied
- All filters restored: keywords, tags, folder, pinned, sort

## Technical Features
- **Offline-first**: Saved searches work without connection
- **Real-time updates**: Stream-based chip updates
- **Duplicate prevention**: Case-insensitive name checking
- **Smart naming**: Context-aware default suggestions
- **Usage tracking**: Count and last-used timestamp
- **Pinning support**: Visual distinction for pinned searches

## Files Modified
1. **`lib/ui/note_search_delegate.dart`**
   - Added NotesRepository and saved searches list
   - Enhanced `_saveCurrentSearch` with full implementation
   - Added imports for repository, UUID, and JSON

2. **`lib/ui/widgets/saved_search_chips.dart`**
   - Added CustomSearchTap callback type
   - Added onCustomSearchTap parameter
   - Enhanced build to show database searches
   - Integrated savedSearchesStreamProvider

3. **`lib/ui/notes_list_screen.dart`**
   - Pass repository and existing searches to delegate
   - Added `_handleCustomSavedSearchTap` method
   - Refactored search opening into `_showSearchScreen`
   - Support initial query parameter

4. **`lib/providers.dart`**
   - Added `savedSearchesStreamProvider` for real-time updates

## Database Schema Used
- **saved_searches table** (already exists):
  - `id`: Unique identifier
  - `name`: Display name
  - `query`: Original search string
  - `search_type`: Type classification
  - `parameters`: JSON-encoded filters
  - `created_at`: Creation timestamp
  - `last_used_at`: Last usage time
  - `usage_count`: Number of uses
  - `is_pinned`: Pin status
  - `sort_order`: Display order

## UI/UX Highlights
- **Save icon**: Only appears when query is active
- **Smart suggestions**: Context-aware default names
- **Inline validation**: Immediate feedback for errors
- **Smooth integration**: Chips appear instantly
- **Visual feedback**: Haptic feedback on save
- **Success confirmation**: Snackbar with saved name

## Acceptance Criteria ✅
- ✅ Save icon appears only when applicable
- ✅ After saving, chip visible immediately
- ✅ Running chip restores exact filter set
- ✅ Duplicate names blocked with inline error
- ✅ Offline-first operation
- ✅ Single scrollable row maintained

## Edge Cases Handled
- **Empty query**: Save button hidden
- **Duplicate names**: Inline error shown
- **Long names**: Ellipsized in chips
- **No repository**: Graceful fallback message
- **Complex queries**: All parameters preserved
- **Auto-naming**: Smart defaults based on content

## Usage Flow
1. User enters search with filters
2. Bookmark icon appears in AppBar
3. Tap bookmark → Save dialog opens
4. Enter name (or use suggestion)
5. Validation checks for duplicates
6. Save → Chip appears immediately
7. Tap chip → Exact search restored

## Future Enhancements (Optional)
- Edit saved searches (rename, update query)
- Delete saved searches from chip (long-press)
- Reorder saved searches by drag
- Export/import saved searches
- Share saved searches between devices
- Search history with conversion to saved
