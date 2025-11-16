# Repository Test Fix Summary

**Date:** 2025-11-06
**Phase:** 1.1 - Soft Delete & Trash System
**Issue:** Repository tests failing due to Supabase initialization

## Problem Discovered

After implementing soft delete functionality with timestamp columns, the repository unit tests were failing with unexpected behavior:

- **Note tests:** 4/4 passing ✅
- **Folder tests:** 0/4 failing ❌
- **Task tests:** 4/4 passing ✅

### Symptoms

```
Expected: not null
  Actual: <null>
```

Folders created in tests couldn't be retrieved, but they existed in the database. The `getFolder()` method was returning null despite the folder being present.

## Root Cause Analysis

### Investigation Steps

1. **Verified Migration Applied**: Confirmed that `Migration40SoftDeleteTimestamps` properly adds `deletedAt` and `scheduledPurgeAt` columns to all tables.

2. **Checked Repository Methods**: Verified that `deleteFolder()` correctly sets both timestamps when marking folders as deleted.

3. **Examined Database Schema**: Confirmed generated Drift code includes the new columns in `LocalFolder` class.

4. **Created Debug Test**: Built minimal reproduction test that revealed:
   - Folder was created successfully
   - Folder existed in database with correct fields
   - But `getFolder()` returned null

5. **Traced Code Path**: Found that `FolderCoreRepository.getFolder()` calls `FolderMapper.toDomain()` which was throwing an exception.

### The Actual Problem

**File:** `lib/infrastructure/mappers/folder_mapper.dart:23`

```dart
static String _getCurrentUserId() {
  ...
  _cachedUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
  ...
}
```

**The FolderMapper uses `Supabase.instance.client` to get the current user ID.** In test environments, if Supabase isn't initialized, accessing `Supabase.instance` throws an exception:

```
The instance of Supabase is not initialized
```

This exception was caught by the repository's try-catch block, which then returned null.

### Why Note and Task Tests Passed

- `NoteMapper` doesn't use `Supabase.instance` - it gets userId from the repository
- `TaskMapper` doesn't use `Supabase.instance` - it gets userId from the repository
- **Only `FolderMapper` uses the Supabase singleton**, causing only folder tests to fail

## Solution

### Fix Applied

**File:** `test/infrastructure/repositories/soft_delete_repository_test.dart`

Added Supabase initialization in the test setup:

```dart
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Set up shared preferences mock (required by Supabase)
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase for tests (FolderMapper uses Supabase.instance)
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });
  // ... rest of tests
}
```

### Why This Works

1. **Initializes Flutter Test Binding**: Required for PerformanceMonitor in migrations
2. **Mocks SharedPreferences**: Required by Supabase initialization
3. **Initializes Supabase Singleton**: Allows `Supabase.instance.client` to work in tests
4. **Idempotent Check**: Tries to access instance first to avoid re-initialization errors

## Results

All 12 repository tests now pass:

```
✅ Soft Delete - NotesCoreRepository (4 tests)
  ✅ deleteNote sets deletedAt and scheduledPurgeAt timestamps
  ✅ getDeletedNotes returns only soft-deleted notes
  ✅ permanentlyDeleteNote removes note from database
  ✅ restoreNote clears deletion timestamps

✅ Soft Delete - FolderCoreRepository (4 tests)
  ✅ deleteFolder sets deletedAt and scheduledPurgeAt timestamps
  ✅ getDeletedFolders returns only soft-deleted folders
  ✅ permanentlyDeleteFolder removes folder from database
  ✅ restoreFolder clears deletion timestamps

✅ Soft Delete - TaskCoreRepository (4 tests)
  ✅ deleteTask sets deletedAt and scheduledPurgeAt timestamps
  ✅ getDeletedTasks returns only soft-deleted tasks
  ✅ permanentlyDeleteTask removes task from database
  ✅ restoreTask clears deletion timestamps

Total: 12/12 passing ✅
```

## Lessons Learned

### Test Environment Setup

1. **Mappers using singletons need initialization**: Any mapper or utility that uses `Supabase.instance`, `SharedPreferences.instance`, or other singletons must have those initialized in test setup.

2. **Try-catch blocks can mask issues**: The repository's exception handling returned null, which didn't provide visibility into the actual error.

3. **Different code paths in production vs tests**: Production code has Supabase initialized at app startup, but tests run in isolation and need explicit initialization.

### Best Practices Going Forward

1. **Test Setup Template**: Create a standard test initialization helper that includes all singleton initialization:
   ```dart
   static Future<void> initializeTestEnvironment() async {
     TestWidgetsFlutterBinding.ensureInitialized();
     SharedPreferences.setMockInitialValues({});
     await _initializeSupabase();
   }
   ```

2. **Mapper Consistency**: Consider updating all mappers to get userId from the same source (either all use repository-provided userId or all use Supabase singleton, but not mixed).

3. **Better Error Messages**: Add logging in mappers to make singleton access failures more visible during testing.

## Files Modified

1. **test/infrastructure/repositories/soft_delete_repository_test.dart**
   - Added `setUpAll()` with Supabase and SharedPreferences initialization
   - Added import for `package:supabase_flutter` and `package:shared_preferences`

## Verification

Run the tests to verify all pass:

```bash
flutter test test/infrastructure/repositories/soft_delete_repository_test.dart
```

Expected output:
```
00:02 +12: All tests passed!
```

## Next Steps

1. ✅ Repository tests now pass (12/12)
2. ⏭️ Task 17: Write TrashService unit tests
3. ⏭️ Task 18: Write trash_screen widget tests
4. ⏭️ Task 19: Write integration tests for soft delete flow

---

## Notes for Reviewers

- The fix is minimal and non-invasive - only adds test initialization
- No production code changes required
- All existing tests remain unchanged in their test logic
- The root cause was a test environment setup issue, not a logic bug
- FolderMapper's use of `Supabase.instance` is intentional for performance (caching userId)
