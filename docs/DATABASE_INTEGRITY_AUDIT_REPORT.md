# DATABASE INTEGRITY & RLS AUDIT REPORT

**Date**: 2025-10-24
**Severity**: CRITICAL
**Issue**: Data leakage - User B sees User A's data

---

## EXECUTIVE SUMMARY

### CRITICAL FINDINGS

1. **Local Database Schema Gaps**: Multiple tables missing `user_id` columns
2. **Incomplete Database Clearing**: `clearAll()` does not clear ALL tables
3. **Missing User Filtering**: Repository queries don't filter by `user_id` in local database
4. **Sync Validation Gap**: No validation that synced data belongs to current user

### SECURITY ASSESSMENT

- **Supabase RLS**: ✅ EXCELLENT - All tables have proper RLS policies
- **Local Database**: ❌ CRITICAL - Missing user_id filtering and columns
- **Repository Layer**: ⚠️ PARTIAL - Inconsistent user_id enforcement
- **Sync Layer**: ⚠️ PARTIAL - Missing user_id validation on download

---

## PART 1: LOCAL SCHEMA ISSUES

### 1.1 Missing user_id Columns

**CRITICAL**: These tables lack `user_id` columns, making user isolation impossible:

| Table | Has user_id? | Impact | Fix Priority |
|-------|-------------|--------|--------------|
| `NoteTasks` | ❌ NO | Tasks from User A visible to User B | P0 - CRITICAL |
| `NoteTags` | ❌ NO | Tags from User A visible to User B | P0 - CRITICAL |
| `NoteLinks` | ❌ NO | Links from User A visible to User B | P0 - CRITICAL |
| `NoteReminders` | ❌ NO | Reminders from User A visible to User B | P0 - CRITICAL |
| `PendingOps` | ❌ NO | Sync queue mixed between users | P0 - CRITICAL |
| `Attachments` | ❌ NO | Attachments from User A visible to User B | P1 - HIGH |
| `NoteFolders` | ❌ NO | Junction table (may be OK if note has user_id) | P2 - MEDIUM |

**ACCEPTABLE** (Has user_id):
- ✅ `LocalNotes` - has `userId` (nullable)
- ✅ `LocalFolders` - has `userId`
- ✅ `SavedSearches` - has `userId` (nullable)
- ✅ `LocalTemplates` - has `userId` (nullable)
- ✅ `InboxItems` - has `userId`

**Location**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

### 1.2 Database Clearing - INCOMPLETE

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:1037-1055`

**Current Implementation**:
```dart
Future<void> clearAll() async {
  await transaction(() async {
    await delete(pendingOps).go();
    await delete(noteFolders).go();
    await delete(noteTags).go();
    await delete(noteLinks).go();
    await delete(noteReminders).go();
    await delete(noteTasks).go();
    await delete(localNotes).go();
    await delete(localFolders).go();
    await delete(savedSearches).go();
    await customStatement('DELETE FROM fts_notes');
  });
}
```

**MISSING TABLES** (not cleared):
1. ❌ `LocalTemplates` - user templates persist after logout
2. ❌ `Attachments` - attachment metadata persists
3. ❌ `InboxItems` - inbox items persist

**Impact**: When User A logs out and User B logs in, they may see User A's:
- Templates
- Attachment references
- Inbox items

---

## PART 2: SUPABASE RLS POLICIES

### 2.1 RLS Status - EXCELLENT ✅

**Location**: `/Users/onronder/duru-notes/supabase/migrations/20250301000000_initial_baseline_schema.sql`

All Supabase tables have correct RLS policies:

| Table | RLS Enabled | SELECT Policy | INSERT Policy | UPDATE Policy | DELETE Policy |
|-------|-------------|---------------|---------------|---------------|---------------|
| `notes` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `folders` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `note_folders` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `note_tasks` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `note_tags` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `note_links` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `reminders` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `templates` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `saved_searches` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `attachments` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |
| `clipper_inbox` | ✅ | `user_id = auth.uid()` | ✅ | ✅ | ✅ |

**Conclusion**: Supabase security is EXCELLENT. The issue is NOT in Supabase.

---

## PART 3: USER ID ENFORCEMENT IN REPOSITORIES

### 3.1 NotesCoreRepository

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

**Issues**:

1. ❌ **localNotes()** (line 1839) - NO user_id filter:
```dart
Future<List<domain.Note>> localNotes() async {
  final localNotes = await (db.select(db.localNotes)
    ..where((note) => note.deleted.equals(false))  // ❌ No userId filter!
    ..orderBy([...])).get();
}
```

2. ❌ **allNotes()** - NO user_id filter
3. ❌ **listAfter()** - NO user_id filter
4. ✅ **createOrUpdate()** - SETS user_id correctly (line 1505)
5. ⚠️ **_hydrateDomainNote()** - Gets userId from note OR currentUser (line 121)

**Root Cause**: Queries don't filter by userId because local database queries assume single-user device.

### 3.2 TaskCoreRepository

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart`

**Issues**:

1. ❌ **getAllTasks()** (line 160) - NO user_id filter:
```dart
Future<List<domain.Task>> getAllTasks() async {
  final localTasks = await db.getAllTasks();  // ❌ No userId filter!
  return await _decryptTasks(localTasks);
}
```

2. ❌ **getPendingTasks()** - NO user_id filter
3. ❌ **watchTasks()** - NO user_id filter
4. ✅ **createTask()** - Checks for authenticated user (line 217)

### 3.3 FolderCoreRepository - BEST PRACTICE ✅

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/folder_core_repository.dart`

**Excellent Implementation**:

1. ✅ **getFolder()** (line 67) - FILTERS by user_id:
```dart
final localFolder = await (db.select(db.localFolders)
  ..where((f) => f.id.equals(id))
  ..where((f) => f.userId.equals(userId)))  // ✅ User isolation!
  .getSingleOrNull();
```

2. ✅ **listFolders()** (line 102) - FILTERS by user_id
3. ✅ **getRootFolders()** (line 132) - FILTERS by user_id
4. ✅ **createFolder()** (line 183) - SETS user_id
5. ✅ **Security comments** throughout code

**This is the CORRECT pattern** - all other repositories should follow this.

---

## PART 4: SYNC VALIDATION GAPS

### 4.1 Sync Download - Missing Validation

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart:1999-2313`

**pullSince() Method**:

```dart
Future<void> pullSince(DateTime? since) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    return;  // ✅ Good - early return if no user
  }

  final remoteNotes = await _secureApi.fetchEncryptedNotes(since: since);
  for (final note in remoteNotes) {
    await _applyRemoteNote(note);  // ❌ No validation that note belongs to userId
  }
}
```

**Issue**: While Supabase RLS will only return notes for the current user, there's no defensive validation in the client. If RLS were somehow bypassed or misconfigured, the app would accept any data.

### 4.2 Missing user_id on Sync Operations

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:1005-1012`

```dart
Future<int> enqueue(String entityId, String kind, {String? payload}) =>
  into(pendingOps).insert(
    PendingOpsCompanion.insert(
      entityId: entityId,
      kind: kind,
      payload: Value(payload),
      // ❌ No userId stored!
    ),
  );
```

**Impact**: When User A creates operations and logs out, User B will sync User A's pending operations.

---

## PART 5: RECOMMENDED FIXES

### Priority 0 - CRITICAL (Deploy Immediately)

#### Fix 1: Add user_id filtering to ALL repository queries

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

```dart
// BEFORE (line 1839):
Future<List<domain.Note>> localNotes() async {
  final localNotes = await (db.select(db.localNotes)
    ..where((note) => note.deleted.equals(false))
    ..orderBy([...])).get();
}

// AFTER:
Future<List<domain.Note>> localNotes() async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    _logger.warning('Cannot list notes without authenticated user');
    return [];
  }

  final localNotes = await (db.select(db.localNotes)
    ..where((note) =>
      note.deleted.equals(false) &
      note.userId.equals(userId))  // ✅ Filter by userId
    ..orderBy([...])).get();
}
```

**Apply to**:
- `localNotes()` (line 1839)
- `allNotes()` (line 849)
- `notesAfter()` (line 857)
- `listAfter()` (line 1906)
- All other query methods

#### Fix 2: Add user_id filtering to TaskCoreRepository

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart`

**CRITICAL**: Tasks table doesn't even have a user_id column in local DB!

**Step 1**: Add migration to add user_id column:

```dart
// File: lib/data/local/app_db.dart
// In NoteTasks table definition (line 163):

@DataClassName('NoteTask')
class NoteTasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();  // ✅ ADD THIS
  // ... rest of columns
}
```

**Step 2**: Create migration (schema version 30):

```dart
if (from < 30) {
  // Add userId to note_tasks
  await m.addColumn(noteTasks, noteTasks.userId);

  // Backfill userId from current user or parent note
  final currentUser = _supabase?.auth.currentUser?.id;
  if (currentUser != null) {
    await customStatement(
      'UPDATE note_tasks SET user_id = ?',
      [currentUser],
    );
  }
}
```

**Step 3**: Update queries to filter by userId:

```dart
Future<List<domain.Task>> getAllTasks() async {
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    _logger.warning('Cannot get tasks without authenticated user');
    return [];
  }

  final localTasks = await (db.select(db.noteTasks)
    ..where((t) =>
      t.deleted.equals(false) &
      t.userId.equals(userId)))  // ✅ Filter by userId
    .get();
  return await _decryptTasks(localTasks);
}
```

#### Fix 3: Complete database clearing

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:1037`

```dart
Future<void> clearAll() async {
  await transaction(() async {
    // Clear all tables in reverse dependency order
    await delete(pendingOps).go();
    await delete(noteFolders).go();
    await delete(noteTags).go();
    await delete(noteLinks).go();
    await delete(noteReminders).go();
    await delete(noteTasks).go();
    await delete(localNotes).go();
    await delete(localFolders).go();
    await delete(savedSearches).go();
    await delete(localTemplates).go();  // ✅ ADD THIS
    await delete(attachments).go();     // ✅ ADD THIS
    await delete(inboxItems).go();      // ✅ ADD THIS
    await customStatement('DELETE FROM fts_notes');

    if (kDebugMode) {
      debugPrint('[AppDb] ✅ All tables cleared - database reset for user switch');
    }
  });
}
```

#### Fix 4: Add user_id to PendingOps

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:59`

```dart
@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text().nullable()();
  TextColumn get userId => text()();  // ✅ ADD THIS
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

Update enqueue method:

```dart
Future<int> enqueue(String entityId, String kind, {String? payload}) {
  final userId = _supabase?.auth.currentUser?.id ?? '';
  return into(pendingOps).insert(
    PendingOpsCompanion.insert(
      entityId: entityId,
      kind: kind,
      payload: Value(payload),
      userId: userId,  // ✅ ADD THIS
    ),
  );
}
```

Update getPendingOps to filter by user:

```dart
Future<List<PendingOp>> getPendingOps() {
  final userId = _supabase?.auth.currentUser?.id;
  if (userId == null) return Future.value([]);

  return (select(pendingOps)
    ..where((o) => o.userId.equals(userId))  // ✅ Filter by userId
    ..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
}
```

### Priority 1 - HIGH (Deploy Within Week)

#### Fix 5: Add user_id to junction tables

**NoteReminders** (line 109):
```dart
@DataClassName('NoteReminder')
class NoteReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();  // ✅ ADD THIS
  // ... rest
}
```

**NoteTags** (line 69):
```dart
@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();
  TextColumn get userId => text()();  // ✅ ADD THIS

  @override
  Set<Column> get primaryKey => {noteId, tag};
}
```

**NoteLinks** (line 78):
```dart
@DataClassName('NoteLink')
class NoteLinks extends Table {
  TextColumn get sourceId => text()();
  TextColumn get targetTitle => text()();
  TextColumn get targetId => text().nullable()();
  TextColumn get userId => text()();  // ✅ ADD THIS

  @override
  Set<Column> get primaryKey => {sourceId, targetTitle};
}
```

#### Fix 6: Add defensive validation in sync

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart:1999`

```dart
Future<void> pullSince(DateTime? since) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    _logger.warning('Cannot pull without authenticated user');
    return;
  }

  final remoteNotes = await _secureApi.fetchEncryptedNotes(since: since);
  for (final note in remoteNotes) {
    // ✅ ADD: Defensive validation
    final noteUserId = note['user_id'] as String?;
    if (noteUserId != userId) {
      _logger.error(
        'SECURITY VIOLATION: Note belongs to different user',
        data: {'noteId': note['id'], 'expectedUser': userId, 'actualUser': noteUserId},
      );
      continue;  // Skip this note
    }

    await _applyRemoteNote(note);
  }
}
```

### Priority 2 - MEDIUM (Deploy Within Month)

#### Fix 7: Add Attachments user_id

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:420`

```dart
@DataClassName('LocalAttachment')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();  // ✅ ADD THIS
  TextColumn get filename => text()();
  // ... rest
}
```

---

## PART 6: TESTING QUERIES

### Query 1: Check for orphaned tasks (no user_id)

**After Fix 2 is applied:**

```sql
-- Find tasks without user_id
SELECT id, note_id, content_encrypted
FROM note_tasks
WHERE user_id IS NULL OR user_id = '';
```

### Query 2: Check for mixed user data in local DB

**Run on device after User B logs in:**

```sql
-- Find notes belonging to different users
SELECT user_id, COUNT(*) as count
FROM local_notes
WHERE deleted = 0
GROUP BY user_id;

-- Should return only 1 row with current user's ID
-- If multiple rows = DATA LEAKAGE
```

### Query 3: Verify clearAll() works

**Before logout:**

```sql
SELECT
  (SELECT COUNT(*) FROM local_notes) as notes,
  (SELECT COUNT(*) FROM local_folders) as folders,
  (SELECT COUNT(*) FROM note_tasks) as tasks,
  (SELECT COUNT(*) FROM local_templates) as templates,
  (SELECT COUNT(*) FROM attachments) as attachments,
  (SELECT COUNT(*) FROM inbox_items) as inbox;
```

**After logout and re-login as different user:**

```sql
-- Should all be 0 or only contain new user's data
SELECT
  (SELECT COUNT(*) FROM local_notes WHERE user_id != auth.uid()) as leaked_notes,
  (SELECT COUNT(*) FROM local_folders WHERE user_id != auth.uid()) as leaked_folders,
  (SELECT COUNT(*) FROM note_tasks WHERE user_id != auth.uid()) as leaked_tasks;

-- All counts should be 0
```

### Query 4: Verify Supabase RLS is working

**Run in Supabase SQL Editor as User A:**

```sql
-- This should return only User A's notes
SELECT id, user_id, created_at
FROM notes
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- user_id should all equal auth.uid()
```

**Switch to User B and run again** - should see completely different notes.

---

## PART 7: TESTING CHECKLIST

### Pre-Deployment Testing

- [ ] **Test 1**: Fresh install → User A login → verify user_id set on all created entities
- [ ] **Test 2**: User A creates 5 notes, 3 tasks, 2 folders
- [ ] **Test 3**: User A logs out
- [ ] **Test 4**: Verify clearAll() deleted ALL data (no orphaned records)
- [ ] **Test 5**: User B logs in → should see ZERO data from User A
- [ ] **Test 6**: User B creates data → verify isolated from User A
- [ ] **Test 7**: User B logs out, User A logs back in → verify User A's data restored from Supabase
- [ ] **Test 8**: Run Query 2 (mixed user data check) → should return 1 row
- [ ] **Test 9**: Test concurrent user scenario (edge case)
- [ ] **Test 10**: Test offline → online sync with user switch

### Post-Deployment Monitoring

```sql
-- Alert if multiple users' data exists in single device DB
CREATE OR REPLACE FUNCTION check_user_isolation()
RETURNS TABLE(device_id text, user_count bigint, user_ids text[]) AS $$
  SELECT
    device_id,
    COUNT(DISTINCT user_id) as user_count,
    ARRAY_AGG(DISTINCT user_id) as user_ids
  FROM local_notes
  WHERE deleted = false
  GROUP BY device_id
  HAVING COUNT(DISTINCT user_id) > 1;
$$ LANGUAGE sql;
```

---

## PART 8: ROOT CAUSE ANALYSIS

### Why Did This Happen?

1. **Architecture Assumption**: Local database was designed assuming **single user per device**
   - Drift ORM queries don't filter by user_id
   - No user_id columns in many tables

2. **Incomplete Migration**: When multi-user support was added:
   - Some tables got user_id (LocalNotes, LocalFolders)
   - Others were missed (NoteTasks, NoteTags, NoteLinks, NoteReminders)

3. **clearAll() Not Updated**: When new tables added (LocalTemplates, Attachments, InboxItems), clearAll() wasn't updated

4. **Repository Inconsistency**:
   - FolderCoreRepository follows best practices (user_id filtering)
   - NotesCoreRepository and TaskCoreRepository don't filter by user_id

### Prevention Measures

1. **Code Review Checklist**: Every new table must have:
   - [ ] user_id column
   - [ ] Added to clearAll()
   - [ ] Repository queries filter by user_id
   - [ ] Supabase RLS policy

2. **Automated Test**: Add integration test that verifies user isolation:
   ```dart
   test('User data isolation', () async {
     // Login as User A, create data
     // Logout, clearAll()
     // Login as User B
     // Verify User A's data not visible
   });
   ```

3. **Linter Rule**: Create custom lint rule that flags queries without user_id filter

---

## APPENDIX A: All Tables Audit Summary

| Table | Local user_id | Supabase RLS | Query Filters | clearAll() | Status |
|-------|---------------|--------------|---------------|------------|--------|
| LocalNotes | ✅ (nullable) | ✅ | ❌ NO | ✅ | NEEDS FIX |
| NoteTasks | ❌ NO | ✅ | ❌ NO | ✅ | CRITICAL FIX |
| LocalFolders | ✅ | ✅ | ✅ YES | ✅ | ✅ GOOD |
| NoteFolders | ❌ NO | ✅ | N/A | ✅ | NEEDS FIX |
| NoteTags | ❌ NO | ✅ | N/A | ✅ | NEEDS FIX |
| NoteLinks | ❌ NO | ✅ | N/A | ✅ | NEEDS FIX |
| NoteReminders | ❌ NO | ✅ | N/A | ✅ | NEEDS FIX |
| SavedSearches | ✅ (nullable) | ✅ | ❌ NO | ✅ | NEEDS FIX |
| LocalTemplates | ✅ (nullable) | ✅ | ❌ NO | ❌ NO | CRITICAL FIX |
| Attachments | ❌ NO | ✅ | N/A | ❌ NO | CRITICAL FIX |
| InboxItems | ✅ | ✅ | ❌ NO | ❌ NO | NEEDS FIX |
| PendingOps | ❌ NO | N/A | ❌ NO | ✅ | CRITICAL FIX |

**Legend**:
- ✅ GOOD: Implemented correctly
- ❌ NO: Missing implementation
- ⚠️ PARTIAL: Partially implemented
- N/A: Not applicable

---

## APPENDIX B: Implementation Priority Matrix

### CRITICAL (P0) - Deploy Immediately
1. Add user_id to NoteTasks + filter queries
2. Add user_id to PendingOps + filter queries
3. Fix clearAll() to include all tables
4. Add user_id filtering to NotesCoreRepository queries

### HIGH (P1) - Deploy Within Week
5. Add user_id to NoteTags, NoteLinks, NoteReminders
6. Add defensive validation in sync download
7. Add user_id filtering to TaskCoreRepository queries

### MEDIUM (P2) - Deploy Within Month
8. Add user_id to Attachments
9. Add automated integration tests
10. Create linter rules

---

## CONCLUSION

**The root cause is clear**: The local database layer lacks proper user isolation. While Supabase has excellent RLS policies, the local SQLite database queries don't filter by user_id, and some tables don't even have user_id columns.

**The fix is straightforward but requires careful execution**:
1. Add user_id columns to all tables
2. Add user_id filtering to all queries
3. Complete the clearAll() implementation
4. Add defensive validation

**Estimated Implementation Time**:
- P0 fixes: 2-3 days
- P1 fixes: 2 days
- P2 fixes: 1 day
- Testing: 2 days
- **Total: ~1 week**

**Risk**: CRITICAL - Data leakage between users is a security violation that could lead to:
- Privacy breach
- Legal liability
- Loss of user trust
- App store removal

**Recommendation**: Deploy P0 fixes immediately as a hotfix, then follow with P1/P2 in subsequent releases.
