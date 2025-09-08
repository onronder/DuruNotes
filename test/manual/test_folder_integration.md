# Testing Guide: Folder Selection and Organization Integration (E2.6)

## Overview
This test guide verifies that folder selection and organization features work correctly in the Modern Note Editor.

## Prerequisites
- Have at least 2-3 folders created in the app
- Have some notes already assigned to folders
- Have some unfiled notes

## Test Cases

### 1. Folder Display for Existing Notes

#### Note with Folder
- [ ] Open an existing note that's in a folder
- [ ] Folder chip should appear below title field
- [ ] Chip should show folder name
- [ ] Chip should display folder's custom color (if set)
- [ ] Chip should show folder's custom icon (if set)
- [ ] Dropdown arrow indicates it's clickable

#### Unfiled Note
- [ ] Open an existing note without a folder
- [ ] Should show "Add to folder" chip
- [ ] Chip should have outline style (less prominent)
- [ ] Should show create folder icon

### 2. New Note Creation

#### From Main Screen
- [ ] Create new note from main + button
- [ ] Should show "Add to folder" chip by default
- [ ] Can tap to assign a folder

#### From Within Folder (if supported)
- [ ] Navigate to a specific folder
- [ ] Create new note from that context
- [ ] Folder chip should automatically show that folder
- [ ] Note is pre-assigned to the context folder

### 3. Folder Picker Interaction

#### Opening Picker
- [ ] Tap the folder chip
- [ ] Folder picker bottom sheet should open
- [ ] Current folder (if any) should be highlighted
- [ ] Should see all available folders
- [ ] Should have "Unfiled" option
- [ ] Should have "Create new folder" option

#### Selecting Different Folder
- [ ] Select a different folder from picker
- [ ] Picker should close
- [ ] Folder chip updates immediately
- [ ] Shows new folder name, color, icon
- [ ] Save button activates (shows unsaved changes)

#### Removing from Folder
- [ ] Open note with folder
- [ ] Tap folder chip
- [ ] Select "Unfiled" option
- [ ] Chip changes to "Add to folder"
- [ ] Save button shows unsaved changes

#### Creating New Folder
- [ ] Tap "Create new folder" in picker
- [ ] Enter folder name
- [ ] Choose color (if supported)
- [ ] Choose icon (if supported)
- [ ] New folder is created and selected
- [ ] Chip shows new folder immediately

### 4. Save Functionality

#### Save with Folder Assignment
- [ ] Create new note
- [ ] Add content
- [ ] Assign to folder
- [ ] Save note
- [ ] Check notes list - note appears
- [ ] Check folder view - note is in selected folder
- [ ] Folder counts update correctly

#### Save with Folder Change
- [ ] Open existing note in Folder A
- [ ] Change to Folder B
- [ ] Save note
- [ ] Check Folder A - note no longer there
- [ ] Check Folder B - note now appears
- [ ] Counts update for both folders

#### Save with Folder Removal
- [ ] Open note with folder
- [ ] Remove from folder (select Unfiled)
- [ ] Save note
- [ ] Note no longer in previous folder
- [ ] Note appears in "All Notes" only

### 5. Unsaved Changes Tracking

#### Folder Change Marks as Unsaved
- [ ] Open existing note
- [ ] Change folder
- [ ] Save button should activate
- [ ] Status bar shows "Unsaved"
- [ ] Header shows "Editing..."

#### Cancel Without Saving
- [ ] Change folder
- [ ] Try to go back without saving
- [ ] Should trigger unsaved changes dialog (E2.7)
- [ ] If discard, folder remains unchanged
- [ ] If save, folder change is applied

### 6. Visual Design

#### Folder Chip Styling
- [ ] Chip has appropriate padding
- [ ] Text is readable
- [ ] Icon size is appropriate (18px)
- [ ] Border and background subtle
- [ ] Dropdown arrow visible when folder selected

#### Custom Colors
- [ ] If folder has custom color:
  - Text uses that color
  - Icon uses that color
  - Border tinted with that color
- [ ] Color has sufficient contrast
- [ ] Works in both light and dark themes

#### Theme Compatibility
- [ ] Light mode: chip visible and readable
- [ ] Dark mode: chip adapts appropriately
- [ ] Custom folder colors work in both

### 7. Edge Cases

#### Very Long Folder Names
- [ ] Create folder with long name
- [ ] Assign note to it
- [ ] Chip should handle text appropriately
- [ ] May truncate with ellipsis if too long

#### Special Characters in Folder
- [ ] Folder with emojis in name
- [ ] Should display correctly in chip

#### Rapid Folder Changes
- [ ] Change folder multiple times quickly
- [ ] UI should update each time
- [ ] No crashes or lag

#### Deleted Folder (if possible)
- [ ] If folder is deleted while editing
- [ ] Note should handle gracefully
- [ ] Might show as unfiled

### 8. Integration with Other Features

#### With Preview Mode
- [ ] Make folder change
- [ ] Switch to preview mode
- [ ] Folder chip remains visible
- [ ] Can still change folder from preview

#### With Formatting
- [ ] Apply text formatting
- [ ] Change folder
- [ ] Both changes tracked as unsaved

#### With Statistics Bar
- [ ] Folder chip doesn't interfere with stats
- [ ] Layout remains clean

### 9. Performance

#### Large Number of Folders
- [ ] If 50+ folders exist
- [ ] Picker should still open quickly
- [ ] Scrolling should be smooth
- [ ] Search works efficiently

#### Memory
- [ ] No memory leaks when opening/closing picker
- [ ] Folder state properly disposed

### 10. Data Consistency

#### After Save
- [ ] Folder assignment persists
- [ ] Reopen note - correct folder shown
- [ ] Folder counts accurate
- [ ] No duplicate entries

#### Sync
- [ ] Folder assignment syncs to server
- [ ] Other devices show same folder

## Expected Behavior Summary

1. **Folder chip always visible** below title field
2. **Tappable chip** opens folder picker
3. **Visual feedback** with colors and icons
4. **Changes tracked** as unsaved
5. **Save updates** folder assignment
6. **Smooth animations** and transitions
7. **Theme-aware** styling
8. **Consistent** across app

## Common Workflows

### Organize New Note
1. Create new note
2. Add title and content
3. Tap "Add to folder"
4. Select or create folder
5. Save note
6. ✓ Note organized

### Move Existing Note
1. Open note from list
2. See current folder
3. Tap to change
4. Select new folder
5. Save changes
6. ✓ Note moved

### Remove from Folder
1. Open organized note
2. Tap folder chip
3. Select "Unfiled"
4. Save changes
5. ✓ Note unfiled

## UI/UX Verification

- Folder feature is discoverable
- Clear visual indication of folder state
- Easy to change folders
- No accidental folder changes
- Consistent with app's folder system
