# Testing Guide: Save Note Functionality & Animated Save Button (E2.4)

## Overview
This test guide verifies that the save functionality works correctly with proper visual feedback and data persistence.

## Test Cases

### 1. Save Button Appearance & States

#### Initial State
- [ ] Open a new note - Save button shows "Done" with check icon
- [ ] Button should have muted primaryContainer background
- [ ] Button should be disabled (no action on tap)

#### Change Detection
- [ ] Type one character in title or body
- [ ] Save button should immediately change to "Save" with save icon
- [ ] Button should show gradient background (primary to secondary)
- [ ] Button should scale slightly (0.95) with animation
- [ ] "Editing..." text should appear under the title in header

#### Multiple Changes
- [ ] Continue typing - button remains in "Save" state
- [ ] No additional animations on subsequent keystrokes

### 2. Save Operation - New Note

#### With Content
- [ ] Create new note (tap + button)
- [ ] Enter both title and body text
- [ ] Tap Save button
- [ ] Expected behavior:
  - Loading spinner appears in button
  - Haptic feedback (medium impact)
  - Screen closes after save
  - Returns to notes list
  - New note appears in list with correct title

#### Body Only (Auto-generated Title)
- [ ] Create new note
- [ ] Leave title empty, enter body text
- [ ] First line: "This is my note content"
- [ ] Tap Save
- [ ] Note should save with title "This is my note content"

#### With Markdown in First Line
- [ ] Create new note
- [ ] Leave title empty
- [ ] Body starts with "## Heading Text"
- [ ] Tap Save
- [ ] Title should be "Heading Text" (strips ## markers)

#### Long Auto-generated Title
- [ ] Create new note
- [ ] Leave title empty
- [ ] Body starts with 100+ character line
- [ ] Tap Save
- [ ] Title should be truncated to 47 chars + "..."

### 3. Save Operation - Existing Note

#### Edit and Save
- [ ] Open existing note from list
- [ ] Initial state: Save button shows "Done"
- [ ] Make a change to title or body
- [ ] Save button activates
- [ ] Tap Save
- [ ] Screen closes, returns to list
- [ ] Changes are visible in list preview

#### No Changes
- [ ] Open existing note
- [ ] Don't make any changes
- [ ] Save button should remain "Done" and disabled
- [ ] Tapping it should do nothing

### 4. Validation

#### Empty Content
- [ ] Create new note
- [ ] Don't enter any text
- [ ] Try to tap Save (should be disabled)
- [ ] Type a space in title, delete it
- [ ] Save activates then deactivates when empty again

#### Whitespace Only
- [ ] Create new note
- [ ] Enter only spaces/newlines in both fields
- [ ] Tap Save
- [ ] Should show SnackBar: "Add some content first"
- [ ] Note should NOT be saved
- [ ] Editor remains open

### 5. Loading States

#### During Save
- [ ] Enter content and tap Save
- [ ] Button should show circular progress indicator
- [ ] Button should be disabled during save
- [ ] Multiple taps should not trigger multiple saves

#### Quick Save
- [ ] Normal saves should complete quickly (<1 second)
- [ ] Loading spinner visible briefly

### 6. Error Handling

#### Simulated Error (if possible to test)
- [ ] Trigger a save error (e.g., offline mode)
- [ ] Should show error SnackBar with red background
- [ ] Message: "Error: [error details]"
- [ ] Save button returns to "Save" state
- [ ] Editor remains open
- [ ] Content is not lost
- [ ] Can retry save

### 7. Sync Behavior

#### Remote Sync
- [ ] Save a note while online
- [ ] Note should sync to server (check Supabase if accessible)
- [ ] Save completes only after sync attempt

#### Offline Behavior
- [ ] Save while offline
- [ ] Should save locally
- [ ] May show sync error but note is saved locally

### 8. UI Feedback

#### Haptic Feedback
- [ ] Medium impact haptic on Save button tap
- [ ] Light impact on preview toggle (existing)

#### SnackBar Messages
- [ ] Info message (blue/tertiary): "Add some content first"
- [ ] Error message (red): "Error: ..."
- [ ] SnackBars should be floating with rounded corners
- [ ] Include appropriate icons

### 9. Animation Testing

#### Save Button Scale
- [ ] First change triggers scale animation (1.0 → 0.95)
- [ ] Animation duration ~200ms
- [ ] After save, scale returns to 1.0

#### Visual Consistency
- [ ] All animations smooth, no jank
- [ ] Colors adapt to light/dark theme

### 10. Integration with Other Features

#### Preview Mode
- [ ] Make changes in edit mode
- [ ] Switch to preview - Save button remains visible
- [ ] Can save from preview mode
- [ ] After save, preview shows latest content

#### Formatting Toolbar
- [ ] Apply formatting via toolbar
- [ ] Save button activates
- [ ] Formatted content saves correctly

### 11. Data Persistence

#### Local Database
- [ ] Save a note
- [ ] Kill app completely
- [ ] Reopen app
- [ ] Note should be present with all content

#### Title in List
- [ ] Saved note shows correct title in list
- [ ] If auto-generated, shows first line
- [ ] Updated time reflects save time

### 12. Edge Cases

#### Rapid Changes
- [ ] Type quickly after save
- [ ] Should immediately re-enable Save button

#### Special Characters
- [ ] Save note with emojis, symbols, etc.
- [ ] Should save and display correctly

#### Very Long Content
- [ ] Save note with 1000+ words
- [ ] Should save without issues
- [ ] Performance should be acceptable

## Expected Behavior Summary

1. **Save button has 3 states**: Disabled/Done, Active/Save, Loading
2. **Visual feedback**: Gradient when active, scale animation, loading spinner
3. **Validation**: Prevents empty notes
4. **Auto-title**: Generates from body if title empty
5. **Error handling**: Shows errors, allows retry
6. **Navigation**: Closes editor after successful save
7. **Persistence**: Saves to local DB and syncs to remote
8. **Integration**: Works with preview mode and formatting

## Performance Expectations

- Save operation: < 1 second typical
- UI remains responsive during save
- No memory leaks from animations
- Smooth animations at 60fps

## Accessibility

- Save button has adequate touch target (40x40 minimum)
- Visual states clearly distinguishable
- Error messages informative
- Haptic feedback provides tactile confirmation
