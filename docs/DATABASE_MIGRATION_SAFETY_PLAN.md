# Database Migration Safety Plan
## Security Phases P1-P3 - Complete Implementation Guide

**Document Version:** 1.0
**Last Updated:** 2025-10-24
**Status:** CRITICAL - Pre-Production Security Hardening

---

## Executive Summary

**CRITICAL FINDING:** 6 out of 12 local database tables are missing `userId` columns, creating severe security vulnerabilities:
- Users can see each other's tags, links, reminders, and tasks after login/logout
- Sync queue (`PendingOps`) can push wrong user's data to Supabase
- No authorization checks in local queries

**Impact:** HIGH - Data leakage between users, sync integrity failures
**Priority:** P0 (Critical) - Must fix before production
**Complexity:** MEDIUM - Requires schema changes + data migration + query rewrites

---

## Current State Analysis

### Local Database Schema (app_db.dart v29)

| Table | userId Column | Status | Risk Level |
|-------|--------------|--------|------------|
| LocalNotes | ✅ nullable | Added v29 | LOW |
| LocalFolders | ✅ non-null | Added v29 | LOW |
| SavedSearches | ✅ nullable | Added v29 | LOW |
| LocalTemplates | ✅ nullable | Added v29 | LOW |
| InboxItems | ✅ non-null | Added v28 | LOW |
| **PendingOps** | ❌ MISSING | **CRITICAL** | **CRITICAL** |
| **NoteTasks** | ❌ MISSING | **CRITICAL** | **HIGH** |
| **NoteReminders** | ❌ MISSING | **CRITICAL** | **HIGH** |
| **NoteTags** | ❌ MISSING | **HIGH** | **MEDIUM** |
| **NoteLinks** | ❌ MISSING | **HIGH** | **MEDIUM** |
| **NoteFolders** | ❌ MISSING | **MEDIUM** | **MEDIUM** |
| Attachments | ❌ MISSING | **MEDIUM** | **MEDIUM** |

### Remote Database (Supabase)

**All tables have complete userId implementation:**
- `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
- Row Level Security (RLS) policies: `user_id = auth.uid()`
- Composite indexes including `user_id`

**Gap:** Local database is 6 tables behind remote schema for user isolation.

---

## Phase-by-Phase Migration Plan

### **Phase 1 (P1): Critical Security Fixes** 🚨

**Goal:** Fix sync queue and task privacy vulnerabilities
**Duration:** 2-3 days
**Risk:** Medium (schema changes + data backfill)

#### Step 1.1: Add userId to PendingOps Table

**Why Critical:** Sync queue currently has NO user isolation. When User B logs in after User A, User B's sync pushes User A's pending operations to Supabase.

**Migration SQL:**
```sql
-- Schema version 30
ALTER TABLE pending_ops ADD COLUMN user_id TEXT;

-- Backfill strategy options:
-- OPTION A: Safe but aggressive - Clear entire queue (recommended)
DELETE FROM pending_ops;

-- OPTION B: Attempt backfill (complex, risky)
-- Match pending ops to entities by entityId
UPDATE pending_ops
SET user_id = (
  CASE
    WHEN kind LIKE '%note%' THEN (SELECT user_id FROM local_notes WHERE id = entity_id)
    WHEN kind LIKE '%folder%' THEN (SELECT user_id FROM local_folders WHERE id = entity_id)
    WHEN kind LIKE '%task%' THEN (SELECT user_id FROM note_tasks WHERE id = entity_id)
    ELSE NULL
  END
);

-- Delete orphaned operations
DELETE FROM pending_ops WHERE user_id IS NULL;
```

**Index Creation:**
```sql
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_id ON pending_ops(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_kind ON pending_ops(user_id, kind);
```

**Repository Query Changes:**
```dart
// BEFORE (lib/services/unified_sync_service.dart:626)
final allPendingOps = await _db!.select(_db!.pendingOps).get();

// AFTER
final userId = _client.auth.currentUser?.id;
if (userId == null) throw StateError('Not authenticated');

final allPendingOps = await (_db!.select(_db!.pendingOps)
  ..where((op) => op.userId.equals(userId))
).get();
```

**Rollback Plan:**
```sql
-- Rollback: Drop userId column if migration fails
ALTER TABLE pending_ops DROP COLUMN user_id;
-- Restore from backup if needed
```

**Data Loss Risk:** HIGH if using Option B backfill
- **Mitigation:** Use Option A (clear queue) for clean state
- **Alternative:** Show user warning dialog: "Pending sync operations will be cleared. Please re-save any recent changes after logging in."

---

#### Step 1.2: Add userId to NoteTasks Table

**Why Critical:** Tasks have NO user isolation. User B can see User A's tasks.

**Migration SQL:**
```sql
-- Schema version 31
ALTER TABLE note_tasks ADD COLUMN user_id TEXT;

-- Backfill userId from parent note
UPDATE note_tasks
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = note_tasks.note_id
);

-- Validate: Check for tasks with no parent note
SELECT COUNT(*) FROM note_tasks WHERE user_id IS NULL;

-- Delete orphaned tasks (no parent note found)
DELETE FROM note_tasks WHERE user_id IS NULL;
```

**Index Creation:**
```sql
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_id ON note_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_note ON note_tasks(user_id, note_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status ON note_tasks(user_id, status) WHERE deleted = 0;
```

**Repository Query Changes (lib/infrastructure/repositories/task_core_repository.dart):**
```dart
// BEFORE (line 141)
final localTasks = await db.getTasksForNote(noteId);

// AFTER
@override
Future<List<domain.Task>> getTasksForNote(String noteId) async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot get tasks without authenticated user');
      return [];
    }

    final localTasks = await (db.select(db.noteTasks)
      ..where((t) => t.noteId.equals(noteId))
      ..where((t) => t.userId.equals(userId))  // NEW: User isolation
      ..where((t) => t.deleted.equals(false))
    ).get();

    return await _decryptTasks(localTasks);
  } catch (e, stack) {
    // error handling...
  }
}
```

**Rollback Plan:**
```sql
-- Backup before migration
CREATE TABLE note_tasks_backup AS SELECT * FROM note_tasks;

-- Rollback: Drop userId column
ALTER TABLE note_tasks DROP COLUMN user_id;

-- Restore from backup if needed
INSERT INTO note_tasks SELECT * FROM note_tasks_backup;
DROP TABLE note_tasks_backup;
```

**Data Loss Risk:** MEDIUM
- **Scenario:** Tasks with deleted parent notes will be removed
- **Mitigation:**
  1. Run validation query BEFORE migration:
     ```sql
     SELECT nt.id, nt.note_id
     FROM note_tasks nt
     LEFT JOIN local_notes ln ON nt.note_id = ln.id
     WHERE ln.id IS NULL;
     ```
  2. If count > 0, investigate orphaned tasks
  3. Option to reassign to current user or delete

---

#### Step 1.3: Add userId Filtering to Repository Queries

**Critical Repositories to Update:**

1. **NotesCoreRepository** (lib/infrastructure/repositories/notes_core_repository.dart)
   - `getNoteById()` - Add userId filter ✅
   - `list()` - Add userId filter
   - `listAfter()` - Add userId filter
   - `localNotes()` - Add userId filter
   - `watchNotes()` - Add userId filter

2. **TaskCoreRepository** (lib/infrastructure/repositories/task_core_repository.dart)
   - `getAllTasks()` - Add userId filter
   - `getPendingTasks()` - Add userId filter
   - `getTaskById()` - Add userId filter
   - `watchTasks()` - Add userId filter

3. **FolderCoreRepository** (lib/infrastructure/repositories/folder_core_repository.dart)
   - Already has userId filtering (lines 59-70) ✅
   - All queries properly isolated ✅

**Pattern for Adding userId Filters:**
```dart
// BEFORE
final localNotes = await (db.select(db.localNotes)
  ..where((note) => note.deleted.equals(false))
).get();

// AFTER
final userId = client.auth.currentUser?.id;
if (userId == null || userId.isEmpty) {
  _logger.warning('Cannot list notes without authenticated user');
  return [];
}

final localNotes = await (db.select(db.localNotes)
  ..where((note) => note.deleted.equals(false))
  ..where((note) => note.userId.equals(userId))  // NEW: User isolation
).get();
```

**Testing Checklist:**
- [ ] Run `flutter test` - All repository tests pass
- [ ] Manual test: Login as User A, create note/task
- [ ] Manual test: Logout, login as User B
- [ ] Verify: User B cannot see User A's data
- [ ] Verify: clearAll() removes all User A's data

---

### **Phase 2 (P2): Complete User Isolation**

**Goal:** Add userId to remaining tables + make non-nullable
**Duration:** 3-4 days
**Risk:** Medium-High (multiple schema changes)

#### Step 2.1: Add userId to NoteReminders Table

**Migration SQL:**
```sql
-- Schema version 32
ALTER TABLE note_reminders ADD COLUMN user_id TEXT;

-- Backfill from parent note
UPDATE note_reminders
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = note_reminders.note_id
);

-- Delete orphaned reminders
DELETE FROM note_reminders WHERE user_id IS NULL;
```

**Index:**
```sql
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_id ON note_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_active ON note_reminders(user_id, is_active) WHERE remind_at IS NOT NULL;
```

**Query Updates:**
All reminder queries in `lib/services/advanced_reminder_service.dart` need userId filtering.

---

#### Step 2.2: Add userId to NoteTags Table

**Migration SQL:**
```sql
-- Schema version 33
ALTER TABLE note_tags ADD COLUMN user_id TEXT;

-- Backfill from parent note
UPDATE note_tags
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = note_tags.note_id
);

-- Delete orphaned tags
DELETE FROM note_tags WHERE user_id IS NULL;
```

**Index:**
```sql
CREATE INDEX IF NOT EXISTS idx_note_tags_user_tag ON note_tags(user_id, tag);
CREATE INDEX IF NOT EXISTS idx_note_tags_user_note ON note_tags(user_id, note_id);
```

**Query Updates:**
```dart
// lib/data/local/app_db.dart:1126
Future<List<String>> distinctTags() async {
  final userId = _currentUserId; // Need to pass this

  final rows = await customSelect(
    '''
    SELECT DISTINCT t.tag AS tag
    FROM note_tags t
    JOIN local_notes n ON n.id = t.note_id
    WHERE n.deleted = 0
      AND n.note_type = 0
      AND t.user_id = ?  -- NEW: User isolation
    ORDER BY LOWER(t.tag) ASC
    ''',
    variables: [Variable<String>(userId)],
    readsFrom: {noteTags, localNotes},
  ).get();

  return rows.map((r) => r.read<String>('tag')).toList();
}
```

---

#### Step 2.3: Add userId to NoteLinks Table

**Migration SQL:**
```sql
-- Schema version 34
ALTER TABLE note_links ADD COLUMN user_id TEXT;

-- Backfill from source note
UPDATE note_links
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = note_links.source_id
);

-- Delete orphaned links
DELETE FROM note_links WHERE user_id IS NULL;
```

**Index:**
```sql
CREATE INDEX IF NOT EXISTS idx_note_links_user_id ON note_links(user_id);
CREATE INDEX IF NOT EXISTS idx_note_links_user_source ON note_links(user_id, source_id);
```

---

#### Step 2.4: Add userId to NoteFolders Table

**Migration SQL:**
```sql
-- Schema version 35
ALTER TABLE note_folders ADD COLUMN user_id TEXT;

-- Backfill from note (first) or folder (fallback)
UPDATE note_folders
SET user_id = COALESCE(
  (SELECT user_id FROM local_notes WHERE id = note_folders.note_id),
  (SELECT user_id FROM local_folders WHERE id = note_folders.folder_id)
);

-- Delete orphaned relationships
DELETE FROM note_folders WHERE user_id IS NULL;
```

**Index:**
```sql
CREATE INDEX IF NOT EXISTS idx_note_folders_user_id ON note_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder ON note_folders(user_id, folder_id);
```

---

#### Step 2.5: Add userId to Attachments Table

**Migration SQL:**
```sql
-- Schema version 36
ALTER TABLE attachments ADD COLUMN user_id TEXT;

-- Backfill from parent note
UPDATE attachments
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = attachments.note_id
);

-- Delete orphaned attachments
DELETE FROM attachments WHERE user_id IS NULL;
```

**Index:**
```sql
CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_note ON attachments(user_id, note_id);
```

---

#### Step 2.6: Make userId Non-Nullable (All Tables)

**CRITICAL:** Only do this after backfilling ALL tables.

**Migration SQL:**
```sql
-- Schema version 37 - The "Hardening" Migration
-- Make userId non-nullable for all tables

-- Validate: Check for any NULL userId values
SELECT 'local_notes' as table_name, COUNT(*) as null_count FROM local_notes WHERE user_id IS NULL
UNION ALL
SELECT 'local_folders', COUNT(*) FROM local_folders WHERE user_id IS NULL
UNION ALL
SELECT 'pending_ops', COUNT(*) FROM pending_ops WHERE user_id IS NULL
UNION ALL
SELECT 'note_tasks', COUNT(*) FROM note_tasks WHERE user_id IS NULL
UNION ALL
SELECT 'note_reminders', COUNT(*) FROM note_reminders WHERE user_id IS NULL
UNION ALL
SELECT 'note_tags', COUNT(*) FROM note_tags WHERE user_id IS NULL
UNION ALL
SELECT 'note_links', COUNT(*) FROM note_links WHERE user_id IS NULL
UNION ALL
SELECT 'note_folders', COUNT(*) FROM note_folders WHERE user_id IS NULL
UNION ALL
SELECT 'attachments', COUNT(*) FROM attachments WHERE user_id IS NULL;

-- If ALL counts are 0, proceed with non-nullable constraint
-- WARNING: SQLite doesn't support ALTER COLUMN, need to recreate tables

-- For each table, use Drift migration pattern:
-- 1. Create new table with NOT NULL constraint
-- 2. Copy data
-- 3. Drop old table
-- 4. Rename new table
```

**Drift Schema Update:**
```dart
// app_db.dart - Update all table definitions
TextColumn get userId => text()(); // Change from nullable() to required
```

**Data Loss Risk:** ZERO if validation passes
- **Mitigation:** Run validation query BEFORE migration
- **Rollback:** Restore from backup if validation fails

---

### **Phase 3 (P3): Performance Optimization**

**Goal:** Ensure queries perform well with userId filtering
**Duration:** 2-3 days
**Risk:** Low (index additions only)

#### Step 3.1: Add Composite Indexes

**Performance Indexes:**
```sql
-- Schema version 38 - Performance optimization
-- Notes
CREATE INDEX IF NOT EXISTS idx_local_notes_user_updated
  ON local_notes(user_id, updated_at DESC) WHERE deleted = 0;
CREATE INDEX IF NOT EXISTS idx_local_notes_user_pinned
  ON local_notes(user_id, is_pinned DESC, updated_at DESC) WHERE deleted = 0;

-- Tasks
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status_due
  ON note_tasks(user_id, status, due_date) WHERE deleted = 0;
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_priority
  ON note_tasks(user_id, priority DESC, created_at DESC) WHERE deleted = 0;

-- Folders
CREATE INDEX IF NOT EXISTS idx_local_folders_user_parent
  ON local_folders(user_id, parent_id) WHERE deleted = 0;
CREATE INDEX IF NOT EXISTS idx_local_folders_user_path
  ON local_folders(user_id, path) WHERE deleted = 0;

-- Reminders
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_remind
  ON note_reminders(user_id, remind_at) WHERE is_active = 1;
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_note_active
  ON note_reminders(user_id, note_id, is_active);

-- Junction tables
CREATE INDEX IF NOT EXISTS idx_note_folders_user_note
  ON note_folders(user_id, note_id);
CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder_updated
  ON note_folders(user_id, folder_id, updated_at DESC);

-- Pending operations
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_created
  ON pending_ops(user_id, created_at ASC);
```

#### Step 3.2: Query Performance Testing

**Benchmark Queries:**
```dart
// Test with 10,000 notes per user
void benchmarkUserIsolationQueries() async {
  final stopwatch = Stopwatch()..start();

  // Query 1: List all notes for user
  final notes = await (db.select(db.localNotes)
    ..where((n) => n.userId.equals(currentUserId))
    ..where((n) => n.deleted.equals(false))
    ..orderBy([(n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)])
  ).get();
  print('Query 1 (list notes): ${stopwatch.elapsedMilliseconds}ms');

  stopwatch.reset();

  // Query 2: Get tasks for note
  final tasks = await (db.select(db.noteTasks)
    ..where((t) => t.userId.equals(currentUserId))
    ..where((t) => t.noteId.equals(noteId))
    ..where((t) => t.deleted.equals(false))
  ).get();
  print('Query 2 (note tasks): ${stopwatch.elapsedMilliseconds}ms');

  // Target: <50ms for all queries
}
```

**Performance Targets:**
- Notes list query: <50ms for 10,000 notes
- Task queries: <20ms
- Folder hierarchy: <100ms for 1,000 folders
- Tag distinct query: <30ms

---

## Encryption Format Migration (P2)

**Separate from userId changes - can run in parallel**

### Current State
- Notes: Base64-encoded encrypted data (correct ✅)
- Tasks: UTF8-encoded encrypted data (INCORRECT ❌)
- Reminders: Not encrypted
- Templates: UTF8-encoded encrypted data (INCORRECT ❌)

### Migration Strategy

**Step 1: Fix Task Encryption Format**
```dart
// lib/infrastructure/repositories/task_core_repository.dart
// BEFORE (line 247)
final contentEncrypted = base64.encode(contentEncryptedBytes);

// This is CORRECT - no change needed ✅

// However, check decryption (line 64-66):
// BEFORE
final contentData = Uint8List.fromList(utf8.encode(localTask.contentEncrypted));

// AFTER - Support both formats during migration
Future<String> _decryptTaskContent(NoteTask localTask, String userId) async {
  try {
    // Try base64 format first (new format)
    final contentData = base64.decode(localTask.contentEncrypted);
    return await crypto.decryptStringForNote(
      userId: userId,
      noteId: localTask.noteId,
      data: contentData,
    );
  } catch (e) {
    // Fallback to UTF8 format (legacy format)
    try {
      final contentData = Uint8List.fromList(utf8.encode(localTask.contentEncrypted));
      final decrypted = await crypto.decryptStringForNote(
        userId: userId,
        noteId: localTask.noteId,
        data: contentData,
      );

      // Re-encrypt with correct format and update DB
      final contentEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: localTask.noteId,
        text: decrypted,
      );
      final contentEncrypted = base64.encode(contentEncryptedBytes);

      await db.updateTask(localTask.id, NoteTasksCompanion(
        contentEncrypted: Value(contentEncrypted),
      ));

      return decrypted;
    } catch (fallbackError) {
      _logger.error('Failed to decrypt task content with both formats',
        error: fallbackError);
      rethrow;
    }
  }
}
```

**Step 2: Batch Re-encryption Job**
```dart
// tools/batch_reencrypt_tasks.dart
Future<void> batchReencryptTasks() async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('Not authenticated');

  final tasks = await db.select(db.noteTasks).get();
  int reencrypted = 0;
  int failed = 0;

  for (final task in tasks) {
    try {
      // Attempt decryption with legacy format
      final contentData = Uint8List.fromList(utf8.encode(task.contentEncrypted));
      final decrypted = await crypto.decryptStringForNote(
        userId: userId,
        noteId: task.noteId,
        data: contentData,
      );

      // Re-encrypt with correct base64 format
      final contentEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: task.noteId,
        text: decrypted,
      );
      final contentEncrypted = base64.encode(contentEncryptedBytes);

      await db.updateTask(task.id, NoteTasksCompanion(
        contentEncrypted: Value(contentEncrypted),
      ));

      reencrypted++;
    } catch (e) {
      // Already in correct format or unrecoverable error
      failed++;
    }
  }

  print('Re-encrypted $reencrypted tasks, $failed failed/already correct');
}
```

---

## Testing Strategy

### Unit Tests

**1. Test userId Filtering:**
```dart
// test/repositories/user_isolation_test.dart
void main() {
  group('User Isolation Tests', () {
    late AppDb db;
    late NotesCoreRepository repo;

    setUp(() async {
      db = AppDb.forTesting(NativeDatabase.memory());
      // Initialize with test users
    });

    test('User A cannot see User B notes', () async {
      // Create note as User A
      await loginAsUserA();
      final noteA = await repo.createOrUpdate(title: 'User A Note', body: 'Private');

      // Switch to User B
      await loginAsUserB();

      // Verify User B cannot see User A's note
      final noteB = await repo.getNoteById(noteA!.id);
      expect(noteB, isNull);
    });

    test('clearAll() removes all user data', () async {
      await loginAsUserA();
      await repo.createOrUpdate(title: 'Test', body: 'Test');

      await db.clearAll();

      final notes = await repo.list();
      expect(notes, isEmpty);
    });

    test('PendingOps filtered by userId', () async {
      await loginAsUserA();
      await db.enqueue('note-123', 'upsert_note');

      await loginAsUserB();
      final ops = await db.getPendingOps(); // Should be filtered

      expect(ops, isEmpty); // User B should not see User A's pending ops
    });
  });
}
```

**2. Test Data Integrity:**
```dart
// test/repositories/migration_integrity_test.dart
void main() {
  group('Migration Data Integrity', () {
    test('NoteTasks userId backfilled correctly', () async {
      // Create note with tasks
      final note = await createNote(userId: 'user-123');
      final task = await createTask(noteId: note.id);

      // Simulate migration
      await runMigration31();

      // Verify userId backfilled
      final taskAfter = await db.getTaskById(task.id);
      expect(taskAfter?.userId, equals('user-123'));
    });

    test('Orphaned tasks removed during migration', () async {
      // Create task with non-existent noteId
      await db.createTask(NoteTasksCompanion.insert(
        id: 'orphan-task',
        noteId: 'non-existent-note',
        contentEncrypted: 'encrypted',
      ));

      // Run migration
      await runMigration31();

      // Verify orphaned task removed
      final task = await db.getTaskById('orphan-task');
      expect(task, isNull);
    });
  });
}
```

### Integration Tests

**1. Multi-User Scenario:**
```dart
// integration_test/multi_user_test.dart
void main() {
  testWidgets('Multi-user data isolation', (tester) async {
    // User A: Create 100 notes
    await loginAs('user-a@example.com');
    for (int i = 0; i < 100; i++) {
      await createNote(title: 'User A Note $i');
    }

    // User A: Logout and clear
    await logout(); // Should trigger clearAll()

    // User B: Login
    await loginAs('user-b@example.com');

    // Verify: User B sees 0 notes (all User A's data cleared)
    await tester.pumpAndSettle();
    expect(find.text('User A Note'), findsNothing);

    // User B: Create notes
    await createNote(title: 'User B Note 1');

    // Verify: User B sees only their note
    await tester.pumpAndSettle();
    expect(find.text('User B Note 1'), findsOneWidget);
  });
}
```

**2. Sync Integrity Test:**
```dart
// integration_test/sync_integrity_test.dart
void main() {
  testWidgets('Sync queue user isolation', (tester) async {
    // User A: Create notes offline
    await disableNetwork();
    await loginAs('user-a@example.com');
    await createNote(title: 'Offline Note A');

    // Verify: Pending op enqueued
    final opsA = await db.getPendingOps();
    expect(opsA.length, equals(1));
    expect(opsA.first.userId, equals('user-a-id'));

    // User A: Logout
    await logout();

    // User B: Login
    await loginAs('user-b@example.com');
    await enableNetwork();

    // Trigger sync
    await syncAll();

    // Verify: User A's pending op NOT pushed by User B
    // (Should have been cleared during logout/login)
    final remoteNotes = await fetchRemoteNotes(userId: 'user-b-id');
    expect(remoteNotes.where((n) => n.title == 'Offline Note A'), isEmpty);
  });
}
```

### Manual Testing Scenarios

**Scenario 1: User Switch After Heavy Usage**
```
1. Login as user-a@example.com
2. Create 1,000 notes with tasks and reminders
3. Create 50 folders with nested hierarchy
4. Add 100 tags across notes
5. Queue 50 pending operations (airplane mode)
6. Logout (verify clearAll() performance)
7. Login as user-b@example.com
8. Verify:
   - Zero notes visible
   - Zero folders visible
   - Zero tags visible
   - Zero pending operations
9. Create new note as user-b
10. Logout
11. Login as user-a@example.com again
12. Verify: All 1,000 notes restored from Supabase
```

**Scenario 2: Orphaned Data Cleanup**
```
1. Login as user-a@example.com
2. Create note "Note A" with 5 tasks
3. Directly delete note from local DB (simulate corruption)
4. Run migration that adds userId to tasks
5. Verify: Orphaned tasks deleted
6. Check logs for warning about orphaned tasks
```

**Scenario 3: Encryption Format Migration**
```
1. Identify tasks stored with legacy UTF8 format
2. Run batch re-encryption job
3. Verify: All tasks decrypt correctly after migration
4. Verify: New tasks always use base64 format
```

---

## Performance Impact Estimates

### Index Creation Impact

| Index | Table Size | Creation Time | Space Overhead |
|-------|-----------|---------------|----------------|
| `idx_pending_ops_user_id` | <1,000 rows | <50ms | +5KB |
| `idx_note_tasks_user_note` | 1,000-10,000 | 100-500ms | +50-500KB |
| `idx_local_notes_user_updated` | 10,000+ | 500ms-2s | +500KB-5MB |
| `idx_note_reminders_user_remind` | 1,000-5,000 | 100-200ms | +20-100KB |

**Total overhead:** ~5-10MB for 10,000 notes

### Query Performance Impact

**Before userId filtering:**
```sql
SELECT * FROM local_notes WHERE deleted = 0;
-- Seq Scan: 10ms for 10,000 rows
```

**After userId filtering + index:**
```sql
SELECT * FROM local_notes WHERE user_id = ? AND deleted = 0;
-- Index Scan: 5-8ms for 10,000 rows (filtered to ~5,000 per user)
```

**Net impact:** 20-40% faster queries (smaller result sets + index usage)

### Migration Downtime

| Phase | Tables Affected | Estimated Downtime | User Impact |
|-------|----------------|-------------------|-------------|
| P1.1 (PendingOps) | 1 | <1 second | None (background) |
| P1.2 (NoteTasks) | 1 | 1-5 seconds | None (background) |
| P2 (All tables) | 6 | 5-30 seconds | Brief loading screen |
| P3 (Indexes) | All | 10-60 seconds | Background, no UX impact |

**Total worst-case:** ~2 minutes for complete migration
**Mitigation:** Run during app startup with progress indicator

---

## Rollback Procedures

### Emergency Rollback (Production)

**If migration fails mid-flight:**

1. **Detect failure:**
   ```dart
   try {
     await runMigration31();
   } catch (e) {
     _logger.critical('Migration 31 failed: $e');
     await rollbackMigration31();
     throw MigrationFailedException('Migration 31 failed', cause: e);
   }
   ```

2. **Restore from backup:**
   ```dart
   // Pre-migration backup
   final backupPath = await createDatabaseBackup();

   try {
     await runMigration();
   } catch (e) {
     await restoreDatabaseBackup(backupPath);
     throw e;
   }
   ```

3. **User communication:**
   ```dart
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Update Failed'),
       content: Text(
         'Database migration failed. Please contact support with error code: ${error.code}'
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: Text('OK'),
         ),
       ],
     ),
   );
   ```

### Manual Recovery

**If app crashes during migration:**

1. App detects incomplete migration on next launch
2. User sees: "Database update interrupted. Restore from backup?"
3. Options:
   - "Restore Backup" → Restore pre-migration state
   - "Retry Migration" → Attempt migration again
   - "Clear Data" → Fresh start (re-download from Supabase)

---

## Monitoring & Validation

### Pre-Migration Health Check

```dart
// tools/pre_migration_health_check.dart
Future<MigrationHealthReport> runHealthCheck() async {
  final report = MigrationHealthReport();

  // Check 1: Database size
  final dbSize = await getDatabaseSize();
  report.databaseSizeMB = dbSize / 1024 / 1024;
  report.canMigrate = dbSize < 100 * 1024 * 1024; // <100MB safe

  // Check 2: Orphaned data
  final orphanedTasks = await countOrphanedTasks();
  report.orphanedTasksCount = orphanedTasks;
  report.warnings.add('$orphanedTasks tasks will be deleted (no parent note)');

  // Check 3: NULL userId counts
  final nullUserIdCounts = await countNullUserIds();
  report.nullUserIdCounts = nullUserIdCounts;

  // Check 4: Pending operations
  final pendingOps = await db.getPendingOps();
  report.pendingOperationsCount = pendingOps.length;
  if (pendingOps.length > 100) {
    report.warnings.add('${pendingOps.length} pending operations will be cleared');
  }

  return report;
}
```

### Post-Migration Validation

```dart
// tools/post_migration_validation.dart
Future<ValidationReport> validateMigration() async {
  final report = ValidationReport();

  // Validation 1: All tables have userId
  final tablesWithNullUserId = await findTablesWithNullUserId();
  report.allTablesHaveUserId = tablesWithNullUserId.isEmpty;

  // Validation 2: Indexes created
  final missingIndexes = await findMissingIndexes([
    'idx_pending_ops_user_id',
    'idx_note_tasks_user_note',
    'idx_local_notes_user_updated',
  ]);
  report.allIndexesCreated = missingIndexes.isEmpty;

  // Validation 3: Query performance
  final queryTimes = await benchmarkQueries();
  report.queryPerformanceAcceptable = queryTimes.values.every((t) => t < 100);

  // Validation 4: Data integrity
  final dataIntegrity = await checkDataIntegrity();
  report.dataIntegrityOK = dataIntegrity.allChecksPass;

  return report;
}
```

### Continuous Monitoring (Production)

```dart
// Monitor userId filtering effectiveness
Sentry.captureMessage(
  'Query executed without userId filter',
  level: SentryLevel.warning,
  hint: Hint.withMap({
    'query': query,
    'stackTrace': StackTrace.current.toString(),
  }),
);
```

---

## Appendix A: Complete Migration SQL Scripts

See separate file: `tools/migrations/migration_30_to_37_complete.sql`

## Appendix B: Rollback SQL Scripts

See separate file: `tools/migrations/rollback_30_to_37_complete.sql`

## Appendix C: Testing Checklists

See separate file: `DATABASE_TESTING_SCENARIOS.md`
