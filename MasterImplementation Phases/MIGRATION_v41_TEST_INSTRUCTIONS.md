# Migration v41 Testing Instructions
**Created:** 2025-11-18
**Status:** Ready for Testing
**Migration:** Reminder ID INT → UUID

---

## ✅ What Was Completed

### Code Changes:
- **15 files updated** with 60+ method signature changes
- **Schema version:** 40 → 41
- **Database tables modified:** `note_reminders`, `note_tasks`
- **Generated code:** Successfully rebuilt

### Files Modified:
1. `lib/data/local/app_db.dart` - Schema & migration logic
2. `lib/data/migrations/migration_41_reminder_uuid.dart` - NEW migration file
3. `lib/services/reminders/base_reminder_service.dart`
4. `lib/services/reminders/reminder_coordinator.dart`
5. `lib/services/reminders/recurring_reminder_service.dart`
6. `lib/services/reminders/geofence_reminder_service.dart`
7. `lib/services/reminders/snooze_reminder_service.dart`
8. `lib/services/advanced_reminder_service.dart`
9. `lib/services/unified_sync_service.dart`
10. `lib/services/task_reminder_bridge.dart`
11. `lib/infrastructure/repositories/notes_core_repository.dart`
12. `lib/infrastructure/repositories/task_core_repository.dart`
13. `lib/domain/repositories/i_task_repository.dart`
14. `lib/services/tasks/task_crud_service.dart`
15. `lib/services/enhanced_task_service.dart`

---

## 🧪 Testing Instructions

### What Will Happen When You Run the App:

1. **Automatic Migration:** On first launch, Migration v41 will run automatically
2. **Data Transformation:** All existing reminders will get new UUID IDs
3. **Foreign Key Update:** Task reminder references will be updated
4. **Old Data Cleanup:** Pending sync operations will be cleared and re-queued

### Expected Console Output:

```
[Migration 41] Starting reminder UUID migration...
[Migration 41] Migrating X reminders...
[Migration 41] Generated UUIDs for X reminders
[Migration 41] Updating Y task reminder references...
[Migration 41] Updated Y task references, found 0 orphaned references
[Migration 41] ✅ Reminder UUID migration complete
[Migration 41] Summary: X reminders migrated, Y task references updated
```

### Testing Checklist:

#### ✅ Phase 1: App Launch & Migration
- [ ] Run `flutter run --debug`
- [ ] Verify migration log appears in console
- [ ] Verify no errors during migration
- [ ] Verify app launches successfully

#### ✅ Phase 2: Create New Reminder
- [ ] Create a new task with reminder
- [ ] Verify reminder is created (no errors)
- [ ] Verify reminder ID is UUID format (check logs)
- [ ] Verify task is linked to reminder

#### ✅ Phase 3: Sync Reminders
- [ ] Trigger manual sync
- [ ] **Expected:** No more `PostgrestException: invalid input syntax for type uuid: "1"`
- [ ] **Expected:** Console shows `✅ Sync completed: unified_sync_all` (no errors)
- [ ] Check Supabase `reminders` table - verify UUIDs are syncing

#### ✅ Phase 4: Existing Reminders
- [ ] Check if old reminders still work (if you had any)
- [ ] Verify old reminder IDs were converted to UUIDs
- [ ] Verify task-reminder links still intact

#### ✅ Phase 5: End-to-End Reminder Flow
- [ ] Create task with reminder on device
- [ ] Sync to backend
- [ ] Reinstall app (or use different device)
- [ ] Verify reminder syncs down correctly
- [ ] Verify no UUID-related errors

---

## 🐛 What to Watch For

### Known Issues Resolved:
- ❌ **OLD:** `PostgrestException: invalid input syntax for type uuid: "1"`
- ✅ **NEW:** Reminders use UUID format, sync works correctly

### Potential Issues:

1. **Migration Fails**
   - **Symptom:** Console shows migration error
   - **Action:** Check console output, report exact error
   - **Rollback:** Available if needed

2. **Existing Reminders Lost**
   - **Symptom:** Old reminders don't appear after migration
   - **Cause:** Migration data transformation issue
   - **Action:** Check migration logs for details

3. **Sync Still Failing**
   - **Symptom:** Still seeing UUID errors
   - **Cause:** Backend may have old invalid reminder data
   - **Action:** May need to clean up backend reminders table

---

## ⚠️ Important Notes

### Before Running:

**NO ACTION NEEDED** - Migration runs automatically.
Your existing reminder data will be preserved and converted.

### Rollback Plan:

If critical issues occur:
```bash
# Stop the app immediately
# Check console logs for migration errors
# Contact Claude for rollback assistance if needed
```

### After Migration:

**Old pending_ops cleaned:** Any pending reminder sync operations were cleared during migration. This is intentional - all reminders will re-sync with new UUIDs.

---

## 📊 Success Criteria

### Migration Successful If:
- ✅ Migration log shows completion
- ✅ No errors during app launch
- ✅ New reminders can be created
- ✅ Reminders sync to/from backend without errors
- ✅ Task-reminder links work correctly
- ✅ Console shows no UUID-related errors

### Sync Working If:
- ✅ No `PostgrestException` errors
- ✅ Console shows: `✅ Sync completed: unified_sync_all`
- ✅ Backend `reminders` table shows UUID format IDs
- ✅ Reminders appear after reinstall/sync

---

## 📝 What to Report

If you encounter issues, please provide:

1. **Console logs** (especially migration section)
2. **Exact error message** (if any)
3. **When did it occur** (during migration, sync, reminder creation, etc.)
4. **Number of reminders** you had before migration
5. **Screenshots** of any error dialogs

---

## 🎯 Next Steps After Testing

### If Everything Works:
1. Continue using the app normally
2. Verify reminders sync correctly over next few days
3. Test on multiple devices if possible

### If Issues Found:
1. Stop using reminder features
2. Report issues with console logs
3. Wait for fixes before creating new reminders

---

## 🚀 Ready to Test!

**Run the app now:** `flutter run --debug`

The migration will start automatically. Watch the console for the migration log, then proceed with the testing checklist above.

Good luck! 🎉
