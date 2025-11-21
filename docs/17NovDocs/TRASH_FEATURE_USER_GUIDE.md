# Trash Feature - User Guide

## Overview

The Trash feature in Duru Notes provides a safety net for deleted items. When you delete a note, folder, or task, it's not immediately removed from your device. Instead, it's moved to the Trash where you can restore it or permanently delete it.

## Key Features

- **30-Day Retention**: Deleted items are kept in Trash for 30 days before automatic removal
- **Restore Capability**: Quickly restore any deleted item back to your active notes
- **Permanent Deletion**: Manually remove items from Trash when you're certain you don't need them
- **Bulk Operations**: Restore or delete multiple items at once, or empty the entire Trash
- **Auto-Purge Countdown**: See exactly how many days remain before an item is automatically removed

## How It Works

### Deleting Items

When you delete a note, folder, or task:

1. **The item moves to Trash** - It's hidden from your main notes list, search results, and folders
2. **A countdown starts** - The item will be automatically removed after 30 days
3. **You can still restore it** - Access Trash anytime to bring the item back

**How to delete an item:**
- Swipe left on any note, folder, or task in your list
- Tap the "Delete" action
- Or use the delete button when viewing the item

### Viewing Trash

**To open Trash:**
1. Tap the menu icon (≡) in the top-left corner
2. Select "Trash" from the navigation drawer
3. You'll see all deleted items organized by type

**Trash Tabs:**
- **All**: Shows all deleted items (notes, folders, and tasks combined)
- **Notes**: Shows only deleted notes
- **Folders**: Shows only deleted folders
- **Tasks**: Shows only deleted tasks

### Understanding Item Cards

Each item in Trash displays:

- **Title**: The name of the deleted item
- **Type Icon**: Note, folder, or task indicator
- **Deletion Date**: When the item was deleted (e.g., "Deleted on Jan 15, 2025")
- **Purge Countdown**: Days remaining until automatic removal (e.g., "Auto-purge in 23 days")
- **Overdue Indicator**: Items past their purge date show "Auto-purge overdue" in red

### Restoring Items

**To restore a single item:**
1. Open Trash
2. Tap the item you want to restore
3. A bottom sheet appears with options
4. Tap "Restore"
5. The item returns to your active notes

**To restore multiple items:**
1. Long-press any item in Trash to enter selection mode
2. Tap additional items to select them (checkboxes appear)
3. Tap the "Restore" button at the bottom
4. All selected items are restored

**What happens when you restore:**
- The item becomes active again
- It appears in your main notes list, folder list, or task list
- All content, tags, and metadata are preserved
- The deletion timestamp is cleared

### Permanent Deletion

**Warning:** Permanent deletion cannot be undone. The item is completely removed from your device and cloud storage.

**To permanently delete a single item:**
1. Open Trash
2. Tap the item you want to permanently delete
3. Tap "Delete Forever" in the bottom sheet
4. Confirm the action in the dialog
5. The item is permanently removed

**To permanently delete multiple items:**
1. Long-press to enter selection mode
2. Select the items you want to remove
3. Tap the "Delete Forever" button at the bottom
4. Confirm the action
5. All selected items are permanently removed

### Empty Trash

You can permanently delete all items in Trash at once.

**To empty Trash:**
1. Open Trash
2. Tap the three-dot menu (⋯) in the top-right corner
3. Select "Empty Trash"
4. Review the confirmation dialog (shows total item count)
5. Tap "Empty Trash" to confirm
6. All items are permanently deleted

**Best Practice:** Review items in Trash before emptying to ensure you don't need any of them.

## Automatic Purging

### How Auto-Purge Works

- **30-Day Retention**: Items deleted on January 1 will be auto-purged on January 31
- **Startup Check**: The app checks for overdue items when you open it
- **Once Daily**: Auto-purge runs at most once per 24 hours to avoid performance impact
- **Silent Operation**: Overdue items are removed automatically without notification

### Viewing the Countdown

Each item in Trash shows how many days remain:

- **"Auto-purge in 30 days"** - Recently deleted
- **"Auto-purge in 7 days"** - Will be removed soon
- **"Auto-purge in 1 day"** - Will be removed tomorrow
- **"Auto-purge overdue"** - Scheduled for removal (in red text)

### Before Auto-Purge Happens

If you see items with low countdown numbers or overdue status:

1. **Review immediately** - Decide if you need to restore them
2. **Restore if needed** - Better to restore now and delete later if you're unsure
3. **Don't worry about overdue items** - They won't be removed until you restart the app

## Special Behaviors

### Folder Deletion

When you delete a folder:

- **Notes inside are NOT deleted** - They remain in your active notes list
- **Only the folder container is deleted** - Notes are simply unorganized
- **Restoring the folder** - Does NOT restore notes that were inside it

**Example:**
1. You have a folder "Work" with 10 notes inside
2. You delete the "Work" folder
3. The 10 notes remain in your "All Notes" list
4. The "Work" folder appears in Trash
5. Restoring "Work" gives you an empty folder

**Best Practice:** If you want to delete both the folder and its contents, delete the notes first, then delete the folder.

### Note Deletion with Tasks

When you delete a note that has tasks:

- **All tasks are also deleted** - Tasks cannot exist without their parent note
- **Tasks appear separately in Trash** - You can see them under the "Tasks" tab
- **Restoring the note** - Automatically restores all its tasks
- **Restoring individual tasks** - Restores just that task (note remains deleted)

**Example:**
1. Note "Project Plan" has 5 tasks
2. You delete "Project Plan"
3. Trash shows: 1 note + 5 tasks (6 items total)
4. Restoring "Project Plan" brings back the note with all 5 tasks
5. Or restore just specific tasks if you want them in a different note

### Selection Mode

**Entering Selection Mode:**
- Long-press any item in Trash
- The item is selected (checkmark appears)
- Selection toolbar appears at the bottom

**While in Selection Mode:**
- Tap items to toggle selection (tap again to deselect)
- The counter shows "X selected"
- Use "Restore" or "Delete Forever" buttons
- Tap "×" to cancel selection mode

**Bulk Actions:**
- Restore multiple items: Tap "Restore" button
- Delete multiple items: Tap "Delete Forever" button (requires confirmation)

## Tips and Best Practices

### 1. Review Before Deleting Forever

Always double-check items before permanent deletion. Once deleted forever, data cannot be recovered.

### 2. Use Trash as a Short-Term Archive

If you're unsure about deleting something, let it sit in Trash for a few days. You have 30 days to change your mind.

### 3. Regular Trash Maintenance

Check Trash weekly to:
- Restore items you accidentally deleted
- Permanently delete items you're certain you don't need
- Free up storage space

### 4. Understand Folder Behavior

Remember that deleting a folder does NOT delete its contents. Delete notes separately if you want to remove everything.

### 5. Use Tabs for Organization

When Trash has many items, use tabs to filter by type:
- Tap "Notes" to see only deleted notes
- Tap "Folders" to see only deleted folders
- Tap "Tasks" to see only deleted tasks

### 6. Watch the Countdown

Items with "Auto-purge in 7 days" or less should be reviewed soon. After 30 days, they're automatically removed.

### 7. Bulk Operations Save Time

Instead of restoring items one-by-one:
- Long-press to enter selection mode
- Select multiple items
- Restore or delete them all at once

## Troubleshooting

### "I deleted something by accident"

**Solution:**
1. Open Trash immediately
2. Find the item (use tabs if needed)
3. Tap it and select "Restore"
4. The item returns to your active notes

### "I can't find an item I deleted"

**Check:**
1. Use the correct tab (Notes/Folders/Tasks)
2. Scroll through the entire list
3. Check if it was deleted more than 30 days ago (auto-purged)
4. Verify it wasn't permanently deleted

### "Empty Trash is grayed out"

**Reason:** Trash is already empty. There are no items to delete.

### "An item shows 'Auto-purge overdue' but it's still there"

**Explanation:** Auto-purge only runs when you open the app, and at most once per 24 hours. The item will be removed the next time auto-purge runs. You can restore it before then.

### "I restored a folder but it's empty"

**Expected Behavior:** Restoring a folder does NOT restore its contents. The folder is restored as an empty container. If you want the notes back, restore them separately from Trash.

### "I restored a task but I can't find it"

**Check:** Look for the task in the note it belongs to. Tasks are attached to notes, not shown in the main notes list. If the parent note was also deleted, restore it first.

## Privacy and Security

### Encryption

- **Trash content is encrypted** - Just like active notes, deleted items remain encrypted on your device
- **Titles are visible in Trash** - For usability, but content remains encrypted until you open it
- **Audit logs store decrypted titles** - For debugging purposes (stored securely in cloud database)

### Data Retention

- **30 days local storage** - Deleted items stay on your device for 30 days
- **Cloud sync** - Trash state syncs across your devices via Supabase
- **Permanent deletion is immediate** - Removed from both local storage and cloud database

### User Isolation

- **Your trash is private** - Only you can see your deleted items
- **Row-level security** - Cloud database enforces user isolation
- **No shared trash** - Deleted items are never visible to other users

## Accessibility

### VoiceOver Support

- **All buttons are labeled** - "Restore", "Delete Forever", "Empty Trash"
- **Item cards announce correctly** - Includes title, type, and countdown
- **Selection mode is announced** - "Selection mode active, X items selected"

### Haptic Feedback (iOS)

- **Long-press vibration** - When entering selection mode
- **Selection toggle** - Light tap when selecting/deselecting items
- **Deletion confirmation** - Subtle feedback on permanent deletion

### Dynamic Type

- **Text scales with system settings** - All text respects iOS Dynamic Type settings
- **Readable at all sizes** - UI remains usable with large text

## Frequently Asked Questions

### How long do items stay in Trash?

Items are kept for 30 days from the deletion date. After 30 days, they're automatically removed.

### Can I change the retention period?

Not currently. The 30-day period is fixed. This may be configurable in a future update.

### What happens if I delete something, then delete it forever, then sync to another device?

The permanent deletion syncs across all your devices. The item is removed everywhere.

### Can I turn off auto-purge?

Auto-purge is currently enabled by default and cannot be disabled. Items are removed after 30 days to prevent unbounded storage growth.

### Does emptying Trash free up storage space?

Yes. Permanently deleting items (individually or via Empty Trash) removes them from local storage and cloud storage, freeing up space.

### What if I accidentally empty Trash?

Unfortunately, emptying Trash is permanent and cannot be undone. Always review the confirmation dialog before proceeding.

### Can I search within Trash?

Not currently. You can filter by type (Notes/Folders/Tasks) using tabs, but search within Trash is not available. This may be added in a future update.

### Do deleted items count toward my storage quota?

Yes. Items in Trash still consume storage space until they're permanently deleted or auto-purged.

## Version History

- **Phase 1.1** (Current): Initial Trash feature with 30-day retention, restore, permanent delete, empty trash, auto-purge
- **Future**: Configurable retention periods, trash search, selective auto-purge settings

## Feedback

If you encounter issues or have suggestions for the Trash feature, please submit feedback through the app settings or contact support.

---

**Last Updated**: January 2025
**Version**: Phase 1.1 - Soft Delete & Trash System
