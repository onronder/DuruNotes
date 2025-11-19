# Sync Fix Testing Guide
**Created:** 2025-11-18
**Purpose:** Verify all 5 sync error fixes are working correctly

## Summary of Fixes Applied

### ✅ Phase 1: Database Schema Fix (Error 2)
- **Migration:** `20251118000000_add_reminder_notification_fields.sql`
- **Added Columns:**
  - `notification_title` TEXT - Custom title for push notification
  - `notification_body` TEXT - Custom body text for push notification
  - `notification_image` TEXT - URL to image for rich notification display
  - `time_zone` TEXT - User timezone identifier (e.g., "America/New_York")
- **Status:** Migration applied to both local and remote database ✓

### ✅ Phase 2: Code Fixes (Errors 1, 3, 4)

**Error 1 - Task Sync Type Cast:**
- **File:** `lib/services/unified_sync_service.dart:1779`
- **Fix:** Added `await` keyword
- **Before:** `final task = _adapter!.createTaskFromSync(taskData);`
- **After:** `final task = await _adapter!.createTaskFromSync(taskData);`

**Error 3 - Reminder ID Validation:**
- **File:** `lib/services/unified_sync_service.dart:1974-2011`
- **Fix:** Enhanced `_parseReminderId()` method with comprehensive validation
- **Validates:** null, non-positive integers, empty strings, unparseable strings
- **Behavior:** Returns null for invalid IDs (skip gracefully), logs detailed errors

**Error 4 - SecretBox Deserialization:**
- **File:** `lib/core/crypto/crypto_box.dart:223-235, 495-513`
- **Fix:** Added Base64 detection and decoding before JSON parsing
- **Detection:** Checks if string starts with 'eyJ' or matches Base64 pattern
- **Behavior:** Decodes Base64-wrapped JSON, falls back to original if not Base64

**Error 5 - Two-Way Sync:**
- **Status:** Should be resolved by fixing Errors 1-4
- **Requires:** Testing to confirm

---

## Testing Checklist

### Test 1: Task Sync Bidirectional ✓
**Objective:** Verify task creation syncs both ways without errors

**Steps:**
1. Create a new task on device with:
   - Title: "Test Task Sync to Backend"
   - Due date: Tomorrow 3:00 PM
   - No reminder
2. Manually trigger sync (if available) or wait for auto-sync
3. Check Supabase `note_tasks` table for the new task
4. Create a task directly in Supabase `note_tasks` table
5. Manually trigger sync on device
6. Verify task appears on device

**Expected Results:**
- ✓ No type cast errors in console
- ✓ Task visible in Supabase after device creation
- ✓ Task visible on device after Supabase creation
- ✓ Console logs show: "Synced X tasks down from backend"

**Console Logs to Check:**
```
Should NOT see: "type 'Future<dynamic>' is not a subtype of type 'Task' in type cast"
Should see: "[UnifiedSyncService] Synced X tasks down from backend"
```

---

### Test 2: Reminder Sync with New Columns ✓
**Objective:** Verify reminder creation uses new schema columns

**Steps:**
1. Create a task with a custom reminder on device:
   - Title: "Test Reminder with New Schema"
   - Due date: Tomorrow 5:00 PM
   - Reminder: Tomorrow 3:00 PM
2. Manually trigger sync
3. Check Supabase `reminders` table:
   - Verify `notification_title` column exists and is populated (or NULL)
   - Verify `notification_body` column exists
   - Verify `notification_image` column exists
   - Verify `time_zone` column exists (should show your timezone like "America/New_York")
4. Create reminder directly in Supabase with all 4 new columns populated
5. Sync on device
6. Verify reminder appears correctly

**Expected Results:**
- ✓ No PostgrestException about missing columns
- ✓ All 4 new columns exist in reminders table
- ✓ time_zone populated with device timezone (e.g., "America/New_York")
- ✓ Reminder syncs down from backend successfully

**Console Logs to Check:**
```
Should NOT see: "Could not find 'notification_body' on table 'reminders'"
Should NOT see: "PostgrestException: column ... does not exist"
Should see: "[UnifiedSyncService] Synced X reminders down from backend"
```

---

### Test 3: Reminder ID Validation ✓
**Objective:** Verify invalid reminder IDs are handled gracefully

**Steps:**
1. Check console logs during sync operations
2. Look for reminder ID error messages
3. Verify app continues functioning if invalid reminders exist

**Expected Results:**
- ✓ App doesn't crash if reminder has NULL/invalid ID
- ✓ Invalid reminders are skipped with error logs
- ✓ Valid reminders continue to sync

**Console Logs to Check:**
```
May see (non-critical): "Reminder ID is null - invalid data from backend"
May see (non-critical): "Reminder ID is non-positive integer: X"
Should NOT see: App crash or unhandled exception
```

---

### Test 4: SecretBox Deserialization ✓
**Objective:** Verify previously failed notes now decrypt correctly

**Steps:**
1. Look for notes that previously showed "Untitled (Decryption Failed)"
2. Trigger a full sync operation
3. Check if those notes now decrypt and show actual content
4. Create a new note with content
5. Verify it encrypts and decrypts correctly

**Expected Results:**
- ✓ Previously failed notes now show content (if Base64-wrapped)
- ✓ New notes encrypt/decrypt without errors
- ✓ No "Unexpected character" FormatException

**Console Logs to Check:**
```
May see: "🔧 Detected and decoded Base64-wrapped SecretBox JSON"
Should NOT see: "FormatException: Unexpected character"
Should NOT see: "❌ SecretBox deserialization error"
```

---

### Test 5: Cross-Device Sync (Reinstall Scenario) ✓
**Objective:** Verify notes/tasks created on one device appear after reinstall

**Steps:**
1. Note current device state (number of notes, tasks, reminders)
2. Uninstall app (or use different test device)
3. Reinstall app
4. Sign in with same account
5. Wait for initial sync to complete
6. Verify all notes, tasks, and reminders appear

**Expected Results:**
- ✓ All notes appear after reinstall
- ✓ All tasks appear with correct metadata
- ✓ All reminders appear and work correctly
- ✓ No sync errors in console

**Console Logs to Check:**
```
Should see: "Initial sync complete" or similar success message
Should see: "Synced X notes, Y tasks, Z reminders"
Should NOT see: Any of the 5 original error types
```

---

## Complete Console Log Review

After running all tests above, perform a final console log review:

### ❌ Errors That Should Be GONE:
1. `type 'Future<dynamic>' is not a subtype of type 'Task' in type cast`
2. `Could not find 'notification_body' on table 'reminders'`
3. `Reminder ID is null` (if all backend data is clean)
4. `FormatException: Unexpected character` (during SecretBox deserialization)
5. Two-way sync failures (tasks/notes not appearing after sync)

### ✅ Logs That Indicate SUCCESS:
- `[UnifiedSyncService] Synced X tasks down from backend`
- `[UnifiedSyncService] Synced X reminders down from backend`
- `[UnifiedSyncService] Synced X notes down from backend`
- `🔧 Detected and decoded Base64-wrapped SecretBox JSON` (if encountered)
- `[DomainTaskController] custom reminder scheduled for task X`

---

## Rollback Plan (If Issues Found)

If any critical issues are discovered during testing:

### Rollback Database Migration:
```bash
# Create rollback migration
cat > supabase/migrations/20251118000001_rollback_reminder_fields.sql << 'EOF'
-- Rollback: Remove notification customization fields from reminders table
ALTER TABLE reminders
  DROP COLUMN IF EXISTS notification_title,
  DROP COLUMN IF EXISTS notification_body,
  DROP COLUMN IF EXISTS notification_image,
  DROP COLUMN IF EXISTS time_zone;

DROP INDEX IF EXISTS idx_reminders_time_zone;
EOF

# Apply rollback
supabase db push
```

### Rollback Code Changes:
```bash
# Revert to previous commit (if needed)
git diff HEAD~1 lib/services/unified_sync_service.dart
git diff HEAD~1 lib/core/crypto/crypto_box.dart

# Review changes and decide if selective revert needed
```

---

## Expected Outcome

After all tests pass, you should observe:

1. **No Black Screen:** Task creation works smoothly (already verified ✓)
2. **No Sync Errors:** Console logs show successful sync operations
3. **Bidirectional Sync:** Data flows both device→backend and backend→device
4. **Data Integrity:** All notes, tasks, and reminders appear correctly
5. **Error Handling:** Invalid data is logged and skipped gracefully

---

## Notes

- **Migration Status:** Confirmed applied both locally and remotely (20251118000000)
- **Code Review:** All 4 fixes verified in codebase
- **time_zone Field:** Uses TEXT (correct) - stores timezone identifiers like "America/New_York", not timestamps
- **Next Steps:** Run app, perform tests, review console logs, report any remaining issues
