# E2.18 Sort UI (Per-Folder Preference) Implementation

## Summary
Implemented a comprehensive sort UI with per-folder preference persistence using SharedPreferences. Each folder remembers its own sort preference, with a mobile-first bottom sheet interface using RadioListTiles.

## Implementation Details

### 1. **Sort Preferences Service** (`lib/services/sort_preferences_service.dart`)
- Created `NoteSortSpec` class combining field and direction
- Sort fields: `updatedAt`, `createdAt`, `title`
- Sort directions: `asc` (oldest/A-Z), `desc` (newest/Z-A)
- Storage key pattern: `prefs.sort.folder.<folderId>` or `prefs.sort.folder.all` for inbox
- Methods:
  - `getSortForFolder()` - Load saved preference
  - `setSortForFolder()` - Save preference
  - `removeSortForFolder()` - Clean up on folder deletion
  - `getAllSortOptions()` - Returns all 6 sort combinations

### 2. **Provider Architecture** (`lib/providers.dart`)
- `sortPreferencesServiceProvider` - Service instance
- `currentSortSpecProvider` - Reactive to folder changes
- `CurrentSortSpecNotifier` - Manages current sort state
- Automatically loads new sort preference when folder changes
- Persists changes immediately to SharedPreferences

### 3. **Sort Dialog UI** (`lib/ui/notes_list_screen.dart`)
- Mobile-first bottom sheet with handle bar
- RadioListTiles for each sort option:
  - Modified (Newest First) - default
  - Modified (Oldest First)
  - Created (Newest First)
  - Created (Oldest First)
  - Title (A-Z)
  - Title (Z-A)
- Icons for visual distinction:
  - 📅 Update icon for Modified
  - ⏰ Time icon for Created
  - 🔤 Alpha icon for Title
- Haptic feedback on selection
- Toast confirmation: "Sorted by [option]"

### 4. **Sort Implementation**
- Maintains pinned-first grouping
- Sort applies within pinned and unpinned groups separately
- Reactive UI updates when sort changes
- Works with existing pagination system

### 5. **Folder Deletion Cleanup**
- Modified `FolderRepository.deleteFolder()` to clean up preferences
- Prevents orphaned preference keys in storage
- Graceful failure if cleanup fails

## Technical Features
- **Per-folder persistence**: Each folder remembers its sort
- **Reactive updates**: UI rebuilds automatically on sort change
- **Pinned grouping preserved**: Sort applies within groups
- **Default handling**: Falls back to Modified (Newest) if no preference
- **Type safety**: Enum-based sort fields and directions
- **Mobile optimized**: Bottom sheet with safe area handling

## Files Modified
1. **`lib/services/sort_preferences_service.dart`** - NEW - Complete sort preference system
2. **`lib/providers.dart`** - Added sort providers and notifier
3. **`lib/ui/notes_list_screen.dart`** - Enhanced sort dialog and integrated preferences
4. **`lib/repository/folder_repository.dart`** - Added preference cleanup on delete

## UI/UX Highlights
- **Visual feedback**: Selected option with radio button and primary color
- **Clear labels**: "Modified (Newest First)", "Title (A-Z)", etc.
- **Smooth animations**: Sheet slides up with handle bar
- **Haptic feedback**: Selection click on choosing option
- **Toast notifications**: Confirms sort change
- **Consistent icons**: Visual cues for each sort type

## Acceptance Criteria ✅
- ✅ Sort changes reflect instantly in the UI
- ✅ Preferences persisted per folder in SharedPreferences
- ✅ Default remains Modified (Newest First)
- ✅ Pinned grouping unaffected by sort changes
- ✅ Bottom sheet UI with RadioListTiles
- ✅ Null folder (Inbox) uses key 'all'
- ✅ Folder deletion removes its preference key

## Edge Cases Handled
- **Null folder**: Uses 'all' key for inbox/unfiled notes
- **Invalid stored values**: Falls back to default sort
- **Folder deletion**: Cleans up associated preferences
- **Missing preferences**: Returns default sort spec
- **Concurrent updates**: State managed through StateNotifier

## Storage Format
Preferences stored as: `prefs.sort.folder.<folderId>` → `<field>:<direction>`
- Example: `prefs.sort.folder.abc123` → `title:asc`
- Inbox: `prefs.sort.folder.all` → `updated_at:desc`

## Future Enhancements (Optional)
- Add sort direction toggle in app bar for quick reversal
- Visual sort indicator in the app bar
- Bulk apply sort to all folders option
- Custom sort orders (e.g., manual ordering)
