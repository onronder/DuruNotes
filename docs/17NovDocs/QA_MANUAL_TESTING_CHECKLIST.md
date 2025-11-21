# QA Manual Testing Checklist - Phase 1.1: Soft Delete & Trash System

**Date Created:** 2025-11-07
**Phase:** 1.1 - Soft Delete & Trash System
**Platform Focus:** iOS
**Status:** Ready for Testing

---

## Document Overview

This checklist provides comprehensive manual testing procedures for the Soft Delete & Trash System implementation. It covers all user-facing features, data integrity checks, edge cases, and platform-specific iOS behaviors.

**Testing Scope:**
- Soft delete with 30-day retention period
- Trash screen with multi-entity support (notes, folders, tasks)
- Restore and permanent delete operations
- Bulk operations (multi-select, empty trash)
- Auto-purge countdown display
- Database timestamp integrity
- Audit trail logging

**Prerequisites:**
- iOS device or simulator (iOS 14+)
- Test build with Drift Migration 40 applied
- Supabase backend with trash_events table
- Clean test environment (can populate with test data)

---

## Pre-Test Setup Checklist

### Environment Verification
- [ ] Drift Migration 40 applied successfully
  - Verify: `local_notes`, `local_folders`, `note_tasks` tables have `deleted_at` and `scheduled_purge_at` columns
  - SQL: `PRAGMA table_info(local_notes);`

- [ ] Supabase migration applied
  - Verify: `trash_events` table exists in remote database
  - SQL: `SELECT * FROM trash_events LIMIT 1;`

- [ ] iOS build installed on test device
  - Build number: _____________
  - iOS version: _____________
  - Device model: _____________

### Test Data Creation
- [ ] Create 10+ test notes with varying content
  - Include notes with: plain text, rich formatting, attachments, tasks
  - Create notes in different folders

- [ ] Create 3+ test folders
  - Include: empty folder, folder with 1 note, folder with 5+ notes
  - Create nested folders (if supported)

- [ ] Create 5+ standalone tasks
  - Attach some tasks to notes
  - Leave some tasks unattached

- [ ] Clear existing trash to start fresh
  - Navigate to Trash → Empty Trash

### Feature Flag Configuration
- [ ] Auto-purge feature flag status: ⬜ Enabled ⬜ Disabled
  - If testing auto-purge: Enable `enable_automatic_trash_purge` flag
  - Default: Disabled in production

---

## Core User Flow Tests

### QA-SD-001: Basic Soft Delete → View in Trash

**Test Steps:**
1. Create a new note with title "Test Note 001" and content "This is a test note for deletion"
2. Navigate back to notes list
3. Delete the note (swipe-to-delete or tap delete button)
4. Navigate to Trash screen from sidebar/menu
5. Verify note appears in Trash

**Expected Results:**
- ✅ Note appears in Trash with original title "Test Note 001"
- ✅ Content preview shows "This is a test note for deletion"
- ✅ "Deleted X ago" timestamp displays (should show "just now" or "1m ago")
- ✅ "Auto-purge in 29 days" or "Auto-purge in 30 days" countdown displays
- ✅ Note icon is blue (doc_text icon)
- ✅ Trash count in app bar shows "1 item"
- ✅ "All" tab shows count (1), "Notes" tab shows count (1)

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-002: Restore Single Item

**Test Steps:**
1. Ensure test note from QA-SD-001 is in Trash
2. Tap the note card in Trash
3. Bottom sheet appears with "Restore" and "Delete Forever" options
4. Tap "Restore" button
5. Verify note disappears from Trash
6. Navigate to notes list
7. Verify note appears in original location

**Expected Results:**
- ✅ Bottom sheet displays with correct title "Test Note 001"
- ✅ Restore icon (counterclockwise arrow) visible
- ✅ Tapping Restore dismisses bottom sheet
- ✅ Green snackbar appears: "Test Note 001 restored" or similar
- ✅ Note removed from Trash immediately
- ✅ Trash count decrements to "Empty" or updates count
- ✅ Note appears in notes list at original position
- ✅ Note content intact, no data loss
- ✅ If note was in a folder, it returns to that folder

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-003: Permanent Delete Single Item

**Test Steps:**
1. Delete a note to send it to Trash
2. Navigate to Trash
3. Tap the note card
4. Tap "Delete Forever" in bottom sheet
5. Confirmation dialog appears
6. Read dialog text to verify correct item
7. Tap "Cancel" first to test cancellation
8. Re-open item and tap "Delete Forever" again
9. This time tap "Delete Forever" in dialog to confirm
10. Restart app and check Trash

**Expected Results:**
- ✅ Confirmation dialog shows: "Delete Forever?"
- ✅ Dialog content: "This will permanently delete [Title]. This action cannot be undone."
- ✅ Dialog has "Cancel" and "Delete Forever" buttons
- ✅ Tapping "Cancel" dismisses dialog without deleting
- ✅ Item still in Trash after cancel
- ✅ Tapping "Delete Forever" removes item immediately
- ✅ Red/error snackbar: "[Title] permanently deleted"
- ✅ Trash count updates
- ✅ After app restart, item does NOT reappear in Trash
- ✅ Item not in notes list (database record removed)

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-004: Folder Deletion Cascade

**Test Steps:**
1. Create a new folder "Test Folder Cascade"
2. Add 3 notes to this folder
3. Add 2 tasks to one of the notes in the folder
4. Delete the folder
5. Navigate to Trash
6. Check "All" tab for all items
7. Check "Folders" tab for folder
8. Check "Notes" tab for notes
9. Check "Tasks" tab for tasks (if tasks independently deleted)

**Expected Results:**
- ✅ Folder appears in Trash immediately
- ✅ All 3 notes from folder also appear in Trash
- ✅ "All" tab shows count (4) = 1 folder + 3 notes
- ✅ "Folders" tab shows (1)
- ✅ "Notes" tab shows (3)
- ✅ All items show same deletion timestamp (within same second)
- ✅ All items show ~30 days purge countdown
- ✅ Note tasks are soft-deleted in database (verify with restore)

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-005: Folder Restore (Contents NOT Included)

**Test Steps:**
1. Use folder from QA-SD-004 (folder with 3 notes in Trash)
2. Navigate to Trash
3. Filter to "Folders" tab
4. Tap the folder
5. Tap "Restore" in bottom sheet
6. Check folder restored in folders list
7. Check notes still in Trash

**Expected Results:**
- ✅ Folder appears in folders list
- ✅ Folder is empty (no notes inside)
- ✅ All 3 notes remain in Trash (not auto-restored)
- ✅ "Folders" tab count decrements by 1
- ✅ "Notes" tab count unchanged (still 3)
- ✅ Snackbar: "Test Folder Cascade restored"

**Note:** Current implementation defaults to `restoreContents=false`. This behavior is by design. Notes must be restored separately.

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-006: Multi-Select Bulk Restore

**Test Steps:**
1. Ensure Trash has at least 5 items (mix of notes, folders, tasks)
2. Navigate to Trash
3. Long-press any item to enter selection mode
4. Tap 3 additional items to select (total 4 selected)
5. Tap restore button (counterclockwise arrow) in app bar
6. Verify all selected items restored
7. Exit selection mode
8. Check original locations for restored items

**Expected Results:**
- ✅ Long press triggers haptic feedback (medium impact)
- ✅ Selection mode activates: app bar shows "4 selected"
- ✅ Selected items show blue border + checkmark
- ✅ Unselected items show empty circle
- ✅ Restore button enabled in app bar
- ✅ Tapping restore immediately restores all 4 items
- ✅ Items removed from Trash
- ✅ Selection mode exits automatically
- ✅ Snackbar shows success message
- ✅ All 4 items appear in their original locations
- ✅ Trash counts update correctly

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-007: Multi-Select Bulk Permanent Delete

**Test Steps:**
1. Populate Trash with 5+ items
2. Enter selection mode (long press)
3. Select 3 items
4. Tap delete button (trash icon) in app bar
5. Confirmation dialog appears
6. Tap "Cancel" first
7. Re-select items and tap delete again
8. Tap "Delete Forever" in dialog
9. Restart app and verify

**Expected Results:**
- ✅ Delete button (trash icon) enabled when items selected
- ✅ Confirmation dialog: "Delete Forever?"
- ✅ Dialog content: "This will permanently delete 3 items. This action cannot be undone."
- ✅ "Cancel" button works, items remain in Trash
- ✅ "Delete Forever" removes all selected items
- ✅ Success snackbar: "3 items permanently deleted"
- ✅ If partial failure: "X deleted, Y failed" message
- ✅ Selection mode exits after deletion
- ✅ Trash counts update
- ✅ After app restart, deleted items do NOT reappear

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-008: Empty Trash

**Test Steps:**
1. Populate Trash with 8+ items (mix of notes, folders, tasks)
2. Note the exact count in "All" tab
3. Tap more options button (ellipsis icon) in app bar
4. Tap "Empty Trash" in menu
5. Confirmation dialog appears
6. Verify dialog shows correct item count
7. Tap "Cancel" first
8. Re-open menu and tap "Empty Trash" again
9. Tap "Empty Trash" in dialog to confirm
10. Wait for completion
11. Restart app and verify

**Expected Results:**
- ✅ More options button visible when Trash not empty
- ✅ "Empty Trash" option appears in menu
- ✅ Confirmation dialog: "Empty Trash?"
- ✅ Dialog shows exact count: "This will permanently delete all X items in the trash..."
- ✅ "Cancel" works, all items remain
- ✅ "Empty Trash" removes all items from Trash
- ✅ Progress indicator or loading state during deletion
- ✅ Success snackbar: "Trash emptied: X items permanently deleted"
- ✅ Trash shows empty state: trash icon + "Trash is empty" + "Deleted items will appear here"
- ✅ All tab counts show (0)
- ✅ More options button hidden when empty
- ✅ After restart, Trash still empty

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-009: Task Cascade on Note Delete

**Test Steps:**
1. Create a new note with title "Note with Tasks"
2. Add 3 checklist tasks to the note
3. Delete the note
4. Navigate to Trash
5. Verify note appears
6. Check "Tasks" tab count
7. Restore the note
8. Open the note and verify tasks present

**Expected Results:**
- ✅ Note appears in Trash
- ✅ Tasks are soft-deleted in database (internal check)
- ✅ "Tasks" tab may or may not show tasks depending on implementation (verify)
- ✅ Restoring note also restores all 3 tasks
- ✅ Tasks appear in note with original content
- ✅ Task completion states preserved

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### QA-SD-010: Tab Filtering

**Test Steps:**
1. Populate Trash with known quantities:
   - 3 notes
   - 2 folders
   - 4 tasks
   - Total: 9 items
2. Navigate to Trash
3. Tap each tab and verify counts and filtered items

**Expected Results:**
- ✅ "All" tab shows count (9), displays all 9 items
- ✅ "Notes" tab shows count (3), displays only 3 notes
- ✅ "Folders" tab shows count (2), displays only 2 folders
- ✅ "Tasks" tab shows count (4), displays only 4 tasks
- ✅ Tab switching is instant (no loading delay)
- ✅ Active tab highlighted/underlined
- ✅ Scroll position resets when switching tabs
- ✅ Pull-to-refresh works on all tabs

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

## UI Elements Verification

### App Bar Elements

- [ ] **Title:** "Trash" displays in app bar
- [ ] **Subtitle:** Shows "Empty" when trash empty
- [ ] **Subtitle:** Shows "X items" or "X item" (singular) when trash has content
- [ ] **More options button (ellipsis icon):**
  - [ ] Visible when Trash has items
  - [ ] Hidden when Trash is empty
  - [ ] Tapping opens menu with "Empty Trash" option

### Selection Mode UI

- [ ] **Entry:** Long press item enters selection mode with haptic feedback
- [ ] **App bar changes:**
  - [ ] Shows "X selected" count (e.g., "3 selected")
  - [ ] Close button (X icon) appears on left
  - [ ] Restore button (counterclockwise arrow) appears
  - [ ] Delete button (trash icon) appears
- [ ] **Item visual state:**
  - [ ] Selected items have blue border
  - [ ] Selected items show checkmark icon
  - [ ] Unselected items show empty circle
- [ ] **Interactions:**
  - [ ] Tapping item toggles selection with click haptic
  - [ ] Tapping close (X) exits selection mode
  - [ ] Selection persists during scroll
  - [ ] Tap restore button → all selected items restored
  - [ ] Tap delete button → confirmation dialog appears

### Tab Bar

- [ ] **Tab labels:** All, Notes, Folders, Tasks
- [ ] **Tab counts:** Each tab shows count in parentheses, e.g., "Notes (5)"
- [ ] **Active tab:** Highlighted/underlined
- [ ] **Tap behavior:** Switching tabs filters items immediately
- [ ] **Empty tab:** If tab has 0 items, shows "(0)" and displays empty state

### Item Card Display

For each item card in Trash:

**Icon & Color Coding:**
- [ ] Note icon: Blue `doc_text` icon
- [ ] Folder icon: Purple `folder` icon
- [ ] Task icon: Green `check_mark_circled` icon

**Text Content:**
- [ ] **Title:** Displays note/folder/task title, or "Untitled Note" if blank
- [ ] **Subtitle:**
  - Notes: Content preview (first ~50 chars)
  - Folders: Shows "Folder"
  - Tasks: Shows "Task"
- [ ] **Deletion timestamp:** "Deleted X ago" with relative time:
  - "just now" (< 1 min)
  - "5m ago" (minutes)
  - "2h ago" (hours)
  - "3d ago" (days)
  - "Jan 15, 2025" (absolute date after 7 days)
- [ ] **Purge countdown:** "Auto-purge in X days" where X is 29-30
  - If overdue: "Auto-purge overdue" in red text

### Empty State

When Trash is empty:
- [ ] Large gray trash icon displays
- [ ] Heading: "Trash is empty"
- [ ] Subtext: "Deleted items will appear here"
- [ ] No action buttons or tabs with content

### Dialogs

**Permanent Delete Dialog (Single Item):**
- [ ] Title: "Delete Forever?"
- [ ] Content: 'This will permanently delete "[Item Title]". This action cannot be undone.'
- [ ] Buttons: "Cancel" (left), "Delete Forever" (right, red/destructive)

**Permanent Delete Dialog (Bulk):**
- [ ] Title: "Delete Forever?"
- [ ] Content: "This will permanently delete X items. This action cannot be undone."
- [ ] Buttons: "Cancel", "Delete Forever"

**Empty Trash Dialog:**
- [ ] Title: "Empty Trash?"
- [ ] Content: "This will permanently delete all X items in the trash. This action cannot be undone."
- [ ] Buttons: "Cancel", "Empty Trash" (destructive)

### Snackbars / Feedback

- [ ] **Restore success:** Green snackbar with "[Title] restored" message
- [ ] **Permanent delete success:** Red/error snackbar with "[Title] permanently deleted"
- [ ] **Bulk restore:** "X items restored"
- [ ] **Bulk delete:** "X items permanently deleted" or "X deleted, Y failed"
- [ ] **Empty trash:** "Trash emptied: X items permanently deleted"
- [ ] **Error states:** Red snackbar with error message if operation fails

---

## Data Integrity Tests

### Database Verification After Soft Delete

**Test:** Delete a note, then query database

**SQL Queries:**
```sql
-- Check deleted flag and timestamps
SELECT id, title, deleted, deleted_at, scheduled_purge_at, updated_at
FROM local_notes
WHERE deleted = 1;
```

**Expected Results:**
- [ ] `deleted` column = `1` (true)
- [ ] `deleted_at` timestamp is set (UTC format, recent)
- [ ] `scheduled_purge_at` = `deleted_at` + 30 days (86400 * 30 seconds)
- [ ] `updated_at` matches `deleted_at` (same transaction)

**Verification:**
```
Example expected data:
id: abc-123
title: Test Note
deleted: 1
deleted_at: 2025-11-07 14:30:00.000
scheduled_purge_at: 2025-12-07 14:30:00.000
updated_at: 2025-11-07 14:30:00.000
```

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Database Verification After Restore

**Test:** Restore a deleted note, then query database

**SQL:**
```sql
SELECT id, title, deleted, deleted_at, scheduled_purge_at, updated_at
FROM local_notes
WHERE id = '[restored-note-id]';
```

**Expected Results:**
- [ ] `deleted` column = `0` (false)
- [ ] `deleted_at` = `NULL`
- [ ] `scheduled_purge_at` = `NULL`
- [ ] `updated_at` updated to restore time (newer than original deleted_at)

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Database Verification After Permanent Delete

**Test:** Permanently delete a note, then query database

**SQL:**
```sql
SELECT COUNT(*) FROM local_notes WHERE id = '[deleted-note-id]';
```

**Expected Results:**
- [ ] Query returns `0` (no record found)
- [ ] Record completely removed from table
- [ ] No orphaned tasks remain (if note had tasks)
- [ ] After app restart, record still absent

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Cascade Verification: Note → Tasks

**Test:** Delete note with tasks, check task deletion

**SQL:**
```sql
-- Find tasks for deleted note
SELECT id, title, deleted, deleted_at
FROM note_tasks
WHERE note_id = '[deleted-note-id]';
```

**Expected Results:**
- [ ] All tasks have `deleted = 1`
- [ ] All tasks have `deleted_at` matching note's `deleted_at`
- [ ] All tasks have `scheduled_purge_at` set

**Test Restore:**
- [ ] Restore note → All tasks also have `deleted = 0` and timestamps cleared

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Cascade Verification: Folder → Notes

**Test:** Delete folder with notes, check note deletion

**SQL:**
```sql
-- Find notes in deleted folder
SELECT id, title, deleted, deleted_at
FROM local_notes
WHERE folder_id = '[deleted-folder-id]';
```

**Expected Results:**
- [ ] All notes in folder have `deleted = 1`
- [ ] All notes have `deleted_at` matching folder's `deleted_at`
- [ ] Restoring folder does NOT auto-restore notes (current behavior)
- [ ] Notes must be restored individually

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Active Queries Exclude Deleted Items

**Test:** Verify main app queries filter out deleted items

**Areas to Check:**
- [ ] **Main notes list:** Deleted notes do NOT appear
- [ ] **Folder contents:** Opening folder shows only active notes (deleted notes hidden)
- [ ] **Search results:** Searching does NOT return deleted notes
- [ ] **Tag filtering:** Filtering by tag excludes deleted notes
- [ ] **Smart folders:** Smart folder queries exclude deleted items

**SQL to verify:**
```sql
-- This should return 0 if queries are correct
SELECT COUNT(*) FROM local_notes
WHERE deleted = 1 AND id IN (
  -- Insert IDs from main notes list here
);
```

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

### Audit Log Verification (Supabase)

**Test:** Perform operations and check audit events

**Operations to Test:**
1. Soft delete a note
2. Restore the note
3. Delete again and permanently delete

**SQL (Supabase):**
```sql
SELECT event_type, item_type, item_id, title, created_at, metadata
FROM trash_events
WHERE item_id = '[test-note-id]'
ORDER BY created_at ASC;
```

**Expected Results:**
- [ ] **Event 1:** `event_type = 'soft_delete'`, `item_type = 'note'`, title matches
- [ ] **Event 2:** `event_type = 'restore'`, same item_id
- [ ] **Event 3:** `event_type = 'soft_delete'` (second deletion)
- [ ] **Event 4:** `event_type = 'permanent_delete'`
- [ ] All events have correct `created_at` timestamps (chronological)
- [ ] Metadata field contains relevant info (e.g., `note_count` for folders)

**Result:** ⬜ Pass ⬜ Fail
**Notes:** _______________________________________________

---

## Edge Cases & Error Scenarios

### Edge Case 1: Empty Trash Operations

**Test 1A:** Empty trash when already empty
- Steps: Navigate to Trash (empty) → Tap more options
- Expected: "Empty Trash" option hidden OR disabled
- Result: ⬜ Pass ⬜ Fail

**Test 1B:** Zero items selected in selection mode
- Steps: Enter selection mode → Deselect all items → Tap restore/delete
- Expected: Buttons disabled OR operation is no-op
- Result: ⬜ Pass ⬜ Fail

---

### Edge Case 2: Large Trash Counts

**Test 2A:** 100+ items in Trash
- Steps: Populate Trash with 100+ items → Navigate to Trash
- Expected: UI renders smoothly, no lag, scroll performance acceptable
- Result: ⬜ Pass ⬜ Fail

**Test 2B:** Bulk delete 50+ items
- Steps: Select 50+ items → Tap delete → Confirm
- Expected: Operation completes in <10 seconds, progress indicator shown
- Result: ⬜ Pass ⬜ Fail

**Test 2C:** Tab counts with 3-digit numbers
- Steps: Populate Trash with 100+ notes
- Expected: "Notes (123)" displays correctly, no layout overflow
- Result: ⬜ Pass ⬜ Fail

---

### Edge Case 3: Purge Countdown Boundary Conditions

**Test 3A:** Item with scheduledPurgeAt in past
- Setup: Manually set `scheduled_purge_at` to yesterday in database
- Expected: Shows "Auto-purge overdue" in red text
- Result: ⬜ Pass ⬜ Fail

**Test 3B:** Item with scheduledPurgeAt < 1 hour away
- Setup: Set `scheduled_purge_at` to 30 minutes from now
- Expected: Shows "Auto-purge in 30m" or "Auto-purge in <1h"
- Result: ⬜ Pass ⬜ Fail

**Test 3C:** Item with scheduledPurgeAt exactly 1 day
- Setup: Set to 24 hours from now
- Expected: Shows "Auto-purge in 1 day" (singular, not "1 days")
- Result: ⬜ Pass ⬜ Fail

---

### Edge Case 4: Already Deleted/Restored Items

**Test 4A:** Delete already-deleted note
- Steps: Delete note → Try to delete same note again via repository
- Expected: No error, no-op or warning logged
- Result: ⬜ Pass ⬜ Fail

**Test 4B:** Restore already-active note
- Steps: Restore note → Try to restore again
- Expected: No error, warning logged, UI shows already restored
- Result: ⬜ Pass ⬜ Fail

---

### Edge Case 5: Missing Parent Folder

**Test 5:** Note's folder permanently deleted, then restore note
- Steps:
  1. Create folder "Parent Folder"
  2. Add note to folder
  3. Delete folder (note also deleted)
  4. Permanently delete folder from Trash
  5. Restore the note
- Expected: Note restored to Inbox/root folder OR UI shows error
- Result: ⬜ Pass ⬜ Fail
- Notes: _______________________________________________

---

### Edge Case 6: Selection Mode Exit Behaviors

**Test 6A:** Navigate away during selection
- Steps: Enter selection mode → Navigate to different screen → Return to Trash
- Expected: Selection mode exited, no items selected
- Result: ⬜ Pass ⬜ Fail

**Test 6B:** Delete all selected items
- Steps: Select 3 items → Delete all → Verify selection mode
- Expected: Selection mode auto-exits after deletion completes
- Result: ⬜ Pass ⬜ Fail

---

### Edge Case 7: Mixed Entity Type Operations

**Test 7A:** Bulk restore with notes + folders + tasks
- Steps: Select 2 notes, 1 folder, 2 tasks → Tap restore
- Expected: All 5 items restored correctly to original locations
- Result: ⬜ Pass ⬜ Fail

**Test 7B:** Empty Trash with only folders (no notes)
- Steps: Populate Trash with 3 folders only → Empty Trash
- Expected: All folders removed, no errors
- Result: ⬜ Pass ⬜ Fail

---

### Error Scenario 8: Network Offline

**Test 8A:** Delete item while offline
- Steps: Enable airplane mode → Delete note → Check Trash
- Expected: Note appears in Trash, sync operation queued
- Result: ⬜ Pass ⬜ Fail

**Test 8B:** Restore while offline
- Steps: Airplane mode ON → Restore item from Trash
- Expected: Item restored locally, sync queued, appears in notes list
- Result: ⬜ Pass ⬜ Fail

**Test 8C:** Permanent delete while offline
- Steps: Airplane mode ON → Permanently delete item
- Expected: Item removed from Trash and database locally, sync queued
- Result: ⬜ Pass ⬜ Fail

---

### Error Scenario 9: Repository Failures (Simulated)

**Note:** These require code modification or debugging tools to simulate failures.

**Test 9A:** Restore fails
- Expected: Item stays in Trash, red snackbar shows error message
- Result: ⬜ Pass ⬜ Fail ⬜ Not Tested

**Test 9B:** Permanent delete fails
- Expected: Item stays in Trash, error snackbar shown
- Result: ⬜ Pass ⬜ Fail ⬜ Not Tested

**Test 9C:** Empty Trash partial failure
- Expected: Success snackbar shows "X deleted, Y failed", failed items remain
- Result: ⬜ Pass ⬜ Fail ⬜ Not Tested

---

### Auto-Purge Scenarios (If Feature Enabled)

**Prerequisite:** Enable `enable_automatic_trash_purge` feature flag

**Test 10A:** Startup purge with overdue items
- Steps:
  1. Manually set 5 items to have `scheduled_purge_at` in past
  2. Force quit app
  3. Relaunch app
  4. Navigate to Trash
- Expected: 5 items automatically purged, Trash count updated
- Result: ⬜ Pass ⬜ Fail

**Test 10B:** Startup purge with no overdue items
- Steps: Launch app with no overdue items
- Expected: No purge runs, log shows "No overdue items to purge"
- Result: ⬜ Pass ⬜ Fail

**Test 10C:** 24-hour interval enforcement
- Steps: Launch app twice within same day
- Expected: Second launch skips purge (too soon), log shows throttling
- Result: ⬜ Pass ⬜ Fail

---

### Folder Cascade Complexity

**Test 11:** Nested folder deletion (if supported)
- Steps:
  1. Create folder hierarchy: Parent → Child → Grandchild
  2. Add notes at each level
  3. Delete parent folder
- Expected: All folders and notes soft-deleted with same timestamp
- Result: ⬜ Pass ⬜ Fail

**Test 12:** Folder restore with `restoreContents=true` (if implemented)
- Steps: Delete folder with contents → Restore with flag enabled
- Expected: Folder AND all notes AND tasks restored
- Result: ⬜ Pass ⬜ Fail ⬜ Not Implemented

---

## iOS-Specific Tests

### Haptic Feedback

- [ ] **Long press to enter selection mode:** Medium impact haptic fires
- [ ] **Toggle item selection:** Selection click haptic fires
- [ ] **No haptics on restore/delete actions** (snackbar provides feedback)

**Result:** ⬜ Pass ⬜ Fail

---

### Cupertino Icons

Verify all icons render correctly:
- [ ] Restore: `CupertinoIcons.arrow_counterclockwise`
- [ ] Delete: `CupertinoIcons.trash`
- [ ] Close selection: `CupertinoIcons.xmark`
- [ ] More options: `CupertinoIcons.ellipsis_circle`
- [ ] Note icon: `CupertinoIcons.doc_text`
- [ ] Folder icon: `CupertinoIcons.folder`
- [ ] Task icon: `CupertinoIcons.check_mark_circled`

**Result:** ⬜ Pass ⬜ Fail

---

### Gestures

- [ ] **Pull-to-refresh:** Works on all tabs, refreshes trash contents
- [ ] **Long press:** Doesn't conflict with scroll, reliably enters selection mode
- [ ] **Bottom sheet:** Appears from bottom, respects safe area (no overlap with home indicator)

**Result:** ⬜ Pass ⬜ Fail

---

### Database Persistence

- [ ] **Test:** Delete items → Force quit app → Relaunch
- [ ] **Expected:** Trash persists, all items still present with correct data
- [ ] **Test:** Permanently delete → Force quit → Relaunch
- [ ] **Expected:** Deleted items do not reappear

**Result:** ⬜ Pass ⬜ Fail

---

### Background/Foreground Transitions

- [ ] **Test:** Delete note → Background app → Wait 30s → Resume
- [ ] **Expected:** Note still in Trash, countdown unchanged
- [ ] **Test:** Open Trash → Background → Resume
- [ ] **Expected:** Trash screen displays correctly, no crashes

**Result:** ⬜ Pass ⬜ Fail

---

### Memory Usage

- [ ] **Test:** Populate Trash with 100+ items, open Trash screen
- [ ] **Expected:** No memory warnings, smooth scrolling
- [ ] **Test:** Select/deselect many items rapidly
- [ ] **Expected:** No lag, memory stable

**Result:** ⬜ Pass ⬜ Fail

---

### VoiceOver Accessibility

- [ ] **Test:** Enable VoiceOver → Navigate to Trash
- [ ] **Expected:** Screen title "Trash" announced
- [ ] **Test:** Swipe through items
- [ ] **Expected:** Each item announces title, type, deletion time
- [ ] **Test:** Select item in selection mode
- [ ] **Expected:** Selection state announced ("Selected", "Not selected")
- [ ] **Test:** Restore/Delete buttons
- [ ] **Expected:** Button labels announced clearly

**Result:** ⬜ Pass ⬜ Fail

---

### Dynamic Type

- [ ] **Test:** Change text size in iOS Settings → Return to Trash screen
- [ ] **Expected:** All text scales appropriately, no layout breaks
- [ ] **Test:** Use largest accessibility size
- [ ] **Expected:** Text still readable, no truncation of critical info

**Result:** ⬜ Pass ⬜ Fail

---

## Performance Tests

### P1: Large Trash Rendering

**Test:** 100+ items in Trash
- Metric: Time to load Trash screen
- Expected: < 2 seconds
- Actual: _______ seconds
- Result: ⬜ Pass ⬜ Fail

---

### P2: Bulk Delete Performance

**Test:** Bulk delete 50 items
- Metric: Time from confirm to completion
- Expected: < 5 seconds
- Actual: _______ seconds
- Result: ⬜ Pass ⬜ Fail

---

### P3: Tab Switching Responsiveness

**Test:** Switch between All/Notes/Folders/Tasks tabs
- Metric: UI response time
- Expected: Instant (< 100ms perceived)
- Actual: ⬜ Instant ⬜ Noticeable lag
- Result: ⬜ Pass ⬜ Fail

---

### P4: Selection Mode Toggle

**Test:** Enter/exit selection mode, select/deselect items
- Metric: UI responsiveness
- Expected: Instant with haptic feedback
- Actual: ⬜ Instant ⬜ Lag noticed
- Result: ⬜ Pass ⬜ Fail

---

### P5: Memory Leak Test

**Test:** Use Trash screen for 5 minutes (delete, restore, scroll, select)
- Metric: Memory usage growth
- Expected: Stable memory, no continuous increase
- Actual: Start: _____ MB, End: _____ MB
- Result: ⬜ Pass ⬜ Fail

---

## Regression Tests

Ensure existing functionality still works after Trash implementation:

### R1: Active Notes List

- [ ] Notes list shows only active (non-deleted) notes
- [ ] Deleted notes do NOT appear in main list
- [ ] Creating new note works correctly

**Result:** ⬜ Pass ⬜ Fail

---

### R2: Search Functionality

- [ ] Search excludes deleted notes
- [ ] Search results only show active notes
- [ ] Searching for deleted note title returns no results

**Result:** ⬜ Pass ⬜ Fail

---

### R3: Tag Filtering

- [ ] Filtering by tag excludes deleted notes
- [ ] Tagged note deleted → Tag filter no longer shows it
- [ ] Tagged note restored → Reappears in tag filter

**Result:** ⬜ Pass ⬜ Fail

---

### R4: Folder Contents

- [ ] Opening folder shows only active notes
- [ ] Deleted note in folder does NOT appear in folder view
- [ ] Creating note in folder works normally

**Result:** ⬜ Pass ⬜ Fail

---

### R5: Sync Functionality

- [ ] Sync still runs after implementing trash
- [ ] Pending operations queue includes upsert for deleted notes
- [ ] Multi-device sync works (if testable)

**Result:** ⬜ Pass ⬜ Fail

---

### R6: Note CRUD Operations

- [ ] Creating note works
- [ ] Editing note works
- [ ] Viewing note works
- [ ] Deleting note (soft delete) works

**Result:** ⬜ Pass ⬜ Fail

---

## Critical P0 Tests (Must-Pass for iOS Release)

These 10 tests MUST pass before iOS deployment. Any failure is a blocker.

### P0-001: Delete → Trash → Restore Flow
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-002: Permanent Delete Persistence
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-003: Empty Trash Functionality
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-004: Multi-Select Bulk Restore
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-005: Purge Countdown Display
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-006: Tab Filtering Accuracy
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-007: Selection Mode Stability
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-008: Database Timestamps Correct
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-009: Audit Events Logged
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

### P0-010: Folder Delete Cascade
- [ ] **Pass** ⬜ **Fail** ⬜ **Blocked**
- Issue: _______________________________________________

---

## Test Results Summary

**Test Date:** _______________
**Tester Name:** _______________
**Device:** _______________
**iOS Version:** _______________
**Build Number:** _______________

### Test Statistics

| Category | Total | Passed | Failed | Blocked | Pass Rate |
|----------|-------|--------|--------|---------|-----------|
| Core User Flows (10) | 10 | ___ | ___ | ___ | ___% |
| UI Elements | ___ | ___ | ___ | ___ | ___% |
| Data Integrity (7) | 7 | ___ | ___ | ___ | ___% |
| Edge Cases (12) | 12 | ___ | ___ | ___ | ___% |
| iOS-Specific (8) | 8 | ___ | ___ | ___ | ___% |
| Performance (5) | 5 | ___ | ___ | ___ | ___% |
| Regression (6) | 6 | ___ | ___ | ___ | ___% |
| P0 Critical (10) | 10 | ___ | ___ | ___ | ___% |
| **TOTAL** | **___** | **___** | **___** | **___** | **___%** |

### Overall Status

⬜ **PASS** - All P0 tests passed, ready for release
⬜ **CONDITIONAL PASS** - Minor issues, can release with known issues documented
⬜ **FAIL** - P0 tests failed, blocking issues require fixes

---

## Issues Found

### High Priority (P0)

| ID | Test | Description | Severity | Status |
|----|------|-------------|----------|--------|
| ISS-001 | | | P0 | Open |

### Medium Priority (P1)

| ID | Test | Description | Severity | Status |
|----|------|-------------|----------|--------|
| ISS-002 | | | P1 | Open |

### Low Priority (P2)

| ID | Test | Description | Severity | Status |
|----|------|-------------|----------|--------|
| ISS-003 | | | P2 | Open |

---

## Known Issues / Limitations

**From Development:**

1. **Integration Test Timer Warnings**
   - **Issue:** Integration tests 1 & 2 fail on pending timer assertion
   - **Cause:** PerformanceMonitor and RateLimitingMiddleware create persistent timers
   - **Impact:** Test infrastructure only, functional logic is correct
   - **Status:** Documented, not a functional bug

2. **Folder Restore Default Behavior**
   - **Issue:** Restoring folder does NOT auto-restore contents
   - **Cause:** `restoreContents` parameter defaults to `false`
   - **Impact:** Users must manually restore notes after restoring parent folder
   - **Status:** By design, may enhance in future

3. **Auto-Purge Feature Disabled**
   - **Issue:** Automatic purge at startup is disabled by default
   - **Cause:** `enable_automatic_trash_purge` feature flag set to false
   - **Impact:** Overdue items not auto-purged unless flag enabled
   - **Status:** Intentional for production safety

4. **Overdue Countdown Not Integration Tested**
   - **Issue:** No automated test for overdue countdown display
   - **Cause:** Requires manual database manipulation with encrypted fields
   - **Impact:** Must manually verify in QA
   - **Status:** Covered in this QA checklist (Edge Case 3A)

---

## Sign-Off

**QA Engineer:** _______________________  **Date:** __________

**Tech Lead:** _______________________  **Date:** __________

**Product Owner:** _______________________  **Date:** __________

---

**Notes:**
- Attach screenshots of key UI states to this document
- Archive test database snapshot for future reference
- Log all P0/P1 issues in issue tracker before release
- Update INTEGRATION_TESTS_SUMMARY.md if new automated tests added

---

**End of QA Manual Testing Checklist**
