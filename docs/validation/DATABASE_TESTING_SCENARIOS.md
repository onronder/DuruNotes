# Database Testing Scenarios
## Comprehensive Edge Cases & Validation Scripts

**Document Version:** 1.0
**Last Updated:** 2025-10-24
**Purpose:** Zero data loss, zero security vulnerabilities

---

## Overview

This document provides **executable test scenarios** for validating database migrations P1-P3. Each scenario includes:
1. **Setup:** Test data creation scripts
2. **Execution:** Migration steps
3. **Validation:** SQL queries to verify correctness
4. **Expected Results:** Pass/fail criteria
5. **Rollback:** Recovery procedures if test fails

---

## Test Environment Setup

### Prerequisites
```bash
# 1. Create test database
cd /Users/onronder/duru-notes
flutter test --setup-test-database

# 2. Install test dependencies
flutter pub get

# 3. Run database schema creation
flutter test test/helpers/test_environment.dart
```

### Test User Accounts
```dart
// test/helpers/test_users.dart
class TestUsers {
  static const userA = TestUser(
    id: 'test-user-a-id',
    email: 'user-a@test.com',
    password: 'testpassword123',
  );

  static const userB = TestUser(
    id: 'test-user-b-id',
    email: 'user-b@test.com',
    password: 'testpassword123',
  );

  static const userC = TestUser(
    id: 'test-user-c-id',
    email: 'user-c@test.com',
    password: 'testpassword123',
  );
}
```

---

## Scenario 1: User A Creates Data, User B Logs In

**Goal:** Verify User B cannot see User A's data after login/logout.

### Setup
```sql
-- Run as: User A logged in
INSERT INTO local_notes (id, user_id, title_encrypted, body_encrypted, updated_at, deleted)
VALUES
  ('note-a-1', 'test-user-a-id', 'encrypted_title_1', 'encrypted_body_1', datetime('now'), 0),
  ('note-a-2', 'test-user-a-id', 'encrypted_title_2', 'encrypted_body_2', datetime('now'), 0);

INSERT INTO local_folders (id, user_id, name, parent_id, path, created_at, updated_at, deleted)
VALUES
  ('folder-a-1', 'test-user-a-id', 'Work', NULL, '/Work', datetime('now'), datetime('now'), 0);

INSERT INTO note_tasks (id, note_id, user_id, content_encrypted, status, created_at, updated_at, deleted)
VALUES
  ('task-a-1', 'note-a-1', 'test-user-a-id', 'encrypted_task', 0, datetime('now'), datetime('now'), 0);

INSERT INTO note_tags (note_id, tag, user_id)
VALUES
  ('note-a-1', 'important', 'test-user-a-id'),
  ('note-a-2', 'work', 'test-user-a-id');

INSERT INTO pending_ops (entity_id, kind, user_id, payload, created_at)
VALUES
  ('note-a-1', 'upsert_note', 'test-user-a-id', '{}', datetime('now'));
```

### Execution
```dart
// test/scenarios/scenario_1_user_switch_test.dart
testWidgets('Scenario 1: User switch data isolation', (tester) async {
  // 1. Login as User A
  await loginAs(TestUsers.userA);

  // 2. Create data
  final noteA = await createNote(title: 'Private Note A', body: 'Secret');
  await createTask(noteId: noteA.id, content: 'Private Task');
  await addTag(noteId: noteA.id, tag: 'private');

  // 3. Verify User A sees data
  final notesA = await listNotes();
  expect(notesA.length, equals(1));
  expect(notesA.first.title, contains('Private'));

  // 4. Logout User A (should trigger clearAll())
  await logout();

  // 5. Verify local database is empty
  final notesAfterLogout = await db.select(db.localNotes).get();
  expect(notesAfterLogout.length, equals(0));

  // 6. Login as User B
  await loginAs(TestUsers.userB);

  // 7. Verify User B sees NO notes
  final notesB = await listNotes();
  expect(notesB, isEmpty);

  // 8. Verify User B cannot query User A's note by ID
  final noteById = await getNoteById(noteA.id);
  expect(noteById, isNull);
});
```

### Validation Queries
```sql
-- After User A logout, verify database is empty
SELECT COUNT(*) as count FROM local_notes;
-- Expected: 0

SELECT COUNT(*) as count FROM note_tasks;
-- Expected: 0

SELECT COUNT(*) as count FROM pending_ops;
-- Expected: 0

-- After User B login, verify queries filtered by userId
SELECT COUNT(*) as count FROM local_notes WHERE user_id = 'test-user-b-id';
-- Expected: 0

-- Verify no User A data visible
SELECT COUNT(*) as count FROM local_notes WHERE user_id = 'test-user-a-id';
-- Expected: 0 (clearAll() removed it)
```

### Expected Results
- ✅ User A's data completely removed after logout
- ✅ User B sees empty database
- ✅ User B cannot access User A's data by ID
- ✅ `clearAll()` execution time <500ms for 1,000 notes

### Pass Criteria
```dart
expect(notesAfterLogout, isEmpty, reason: 'clearAll() should remove all data');
expect(notesB, isEmpty, reason: 'User B should see no notes');
expect(noteById, isNull, reason: 'Cross-user access should fail');
```

---

## Scenario 2: Migration with 10,000 Tasks

**Goal:** Verify NoteTasks userId backfill handles large datasets without data loss.

### Setup
```sql
-- Create 10,000 notes with tasks
DO $$
DECLARE
  i INTEGER;
  note_id TEXT;
  user_id TEXT := 'test-user-a-id';
BEGIN
  FOR i IN 1..10000 LOOP
    note_id := 'note-' || i;

    INSERT INTO local_notes (id, user_id, title_encrypted, body_encrypted, updated_at, deleted)
    VALUES (note_id, user_id, 'title_' || i, 'body_' || i, NOW(), false);

    INSERT INTO note_tasks (id, note_id, content_encrypted, status, created_at, updated_at, deleted)
    VALUES ('task-' || i, note_id, 'task_content_' || i, 0, NOW(), NOW(), false);
  END LOOP;
END $$;

-- Verify count
SELECT COUNT(*) FROM note_tasks;
-- Expected: 10,000
```

### Execution
```dart
// test/scenarios/scenario_2_large_migration_test.dart
test('Scenario 2: Migrate 10,000 tasks with userId backfill', () async {
  // 1. Setup: Create 10,000 notes with tasks (no userId)
  await populateLargeDataset(
    userId: TestUsers.userA.id,
    noteCount: 10000,
    tasksPerNote: 1,
  );

  // 2. Pre-migration validation
  final tasksBeforeMigration = await db.select(db.noteTasks).get();
  expect(tasksBeforeMigration.length, equals(10000));
  expect(tasksBeforeMigration.every((t) => t.userId == null), isTrue);

  // 3. Run migration (schema version 31)
  final stopwatch = Stopwatch()..start();
  await runMigration31_AddUserIdToTasks();
  stopwatch.stop();

  // 4. Post-migration validation
  final tasksAfterMigration = await db.select(db.noteTasks).get();

  // Verify count unchanged
  expect(tasksAfterMigration.length, equals(10000));

  // Verify all userId backfilled
  expect(tasksAfterMigration.every((t) => t.userId != null), isTrue);
  expect(
    tasksAfterMigration.every((t) => t.userId == TestUsers.userA.id),
    isTrue,
  );

  // Verify migration performance
  expect(
    stopwatch.elapsedMilliseconds,
    lessThan(5000),
    reason: 'Migration should complete in <5s for 10k tasks',
  );
});
```

### Validation Queries
```sql
-- Post-migration: Verify all tasks have userId
SELECT COUNT(*) as tasks_with_null_userId
FROM note_tasks
WHERE user_id IS NULL;
-- Expected: 0

-- Verify userId matches parent note
SELECT COUNT(*) as mismatched_userIds
FROM note_tasks t
JOIN local_notes n ON n.id = t.note_id
WHERE t.user_id != n.user_id;
-- Expected: 0

-- Verify no orphaned tasks (tasks without parent note)
SELECT COUNT(*) as orphaned_tasks
FROM note_tasks t
LEFT JOIN local_notes n ON n.id = t.note_id
WHERE n.id IS NULL;
-- Expected: 0 (should have been deleted during migration)
```

### Expected Results
- ✅ All 10,000 tasks have userId populated
- ✅ userId matches parent note's userId
- ✅ No orphaned tasks remain
- ✅ Migration completes in <5 seconds

### Pass Criteria
```dart
expect(orphanedCount, equals(0));
expect(nullUserIdCount, equals(0));
expect(mismatchedCount, equals(0));
expect(stopwatch.elapsedMilliseconds, lessThan(5000));
```

---

## Scenario 3: Orphaned Tasks (Deleted Parent Notes)

**Goal:** Verify orphaned tasks are safely removed during migration.

### Setup
```sql
-- Create note with tasks
INSERT INTO local_notes (id, user_id, title_encrypted, body_encrypted, updated_at, deleted)
VALUES ('parent-note', 'test-user-a-id', 'title', 'body', datetime('now'), 0);

INSERT INTO note_tasks (id, note_id, content_encrypted, status, created_at, updated_at, deleted)
VALUES
  ('task-1', 'parent-note', 'task_content_1', 0, datetime('now'), datetime('now'), 0),
  ('task-2', 'non-existent-note', 'orphaned_task', 0, datetime('now'), datetime('now'), 0),
  ('task-3', 'parent-note', 'task_content_3', 0, datetime('now'), datetime('now'), 0);

-- Now delete the parent note
DELETE FROM local_notes WHERE id = 'parent-note';

-- Verify orphaned state
SELECT COUNT(*) FROM note_tasks t
LEFT JOIN local_notes n ON n.id = t.note_id
WHERE n.id IS NULL;
-- Expected: 3 (all tasks now orphaned)
```

### Execution
```dart
// test/scenarios/scenario_3_orphaned_tasks_test.dart
test('Scenario 3: Orphaned tasks removed during migration', () async {
  // 1. Setup: Create tasks with deleted parent notes
  final note = await createNote(title: 'Parent', body: 'Content');
  await createTask(noteId: note.id, content: 'Task 1');
  await createTask(noteId: note.id, content: 'Task 2');
  await createTask(noteId: 'non-existent-note', content: 'Orphaned');

  // 2. Delete parent note (creates orphaned tasks)
  await deleteNote(note.id);

  // 3. Count orphaned tasks before migration
  final orphanedBefore = await countOrphanedTasks();
  expect(orphanedBefore, equals(3));

  // 4. Run migration with orphan cleanup
  await runMigration31_AddUserIdToTasks();

  // 5. Verify orphaned tasks removed
  final orphanedAfter = await countOrphanedTasks();
  expect(orphanedAfter, equals(0));

  // 6. Verify no tasks with NULL userId remain
  final nullUserIdCount = await db.customSelect(
    'SELECT COUNT(*) as count FROM note_tasks WHERE user_id IS NULL',
  ).getSingle();
  expect(nullUserIdCount.read<int>('count'), equals(0));
});
```

### Validation Queries
```sql
-- Helper function to find orphaned tasks
CREATE VIEW orphaned_tasks AS
SELECT t.id, t.note_id
FROM note_tasks t
LEFT JOIN local_notes n ON n.id = t.note_id
WHERE n.id IS NULL;

-- Before migration: Count orphans
SELECT COUNT(*) as count FROM orphaned_tasks;
-- Expected: 3

-- After migration: Verify orphans deleted
SELECT COUNT(*) as count FROM orphaned_tasks;
-- Expected: 0

-- Verify migration log captured orphans
-- (Migration should log warning about deleted orphaned tasks)
```

### Expected Results
- ✅ Orphaned tasks identified and logged
- ✅ All orphaned tasks removed during migration
- ✅ Valid tasks preserved
- ✅ Warning logged: "Removed 3 orphaned tasks with no parent note"

### Pass Criteria
```dart
expect(orphanedAfter, equals(0));
expect(validTasksCount, equals(0)); // All were orphaned in this test
```

---

## Scenario 4: Pending Sync Operations Leak

**Goal:** Verify PendingOps queue doesn't leak operations between users.

### Setup
```sql
-- User A: Create pending operations (offline mode)
INSERT INTO pending_ops (entity_id, kind, user_id, payload, created_at)
VALUES
  ('note-a-1', 'upsert_note', 'test-user-a-id', '{"title": "User A Note"}', datetime('now')),
  ('note-a-2', 'upsert_note', 'test-user-a-id', '{"title": "User A Note 2"}', datetime('now')),
  ('task-a-1', 'upsert_task', 'test-user-a-id', '{"content": "User A Task"}', datetime('now'));
```

### Execution
```dart
// test/scenarios/scenario_4_pending_ops_leak_test.dart
test('Scenario 4: PendingOps queue user isolation', () async {
  // 1. User A: Create pending operations (offline)
  await disableNetwork();
  await loginAs(TestUsers.userA);

  await createNote(title: 'Offline Note A', body: 'Content');
  await createTask(noteId: 'note-a-1', content: 'Offline Task');

  // 2. Verify pending operations enqueued
  final pendingOpsA = await db.getPendingOps();
  expect(pendingOpsA.length, greaterThan(0));
  expect(pendingOpsA.every((op) => op.userId == TestUsers.userA.id), isTrue);

  // 3. User A: Logout (should clear pending ops)
  await logout();

  // 4. Verify pending ops cleared
  final pendingOpsAfterLogout = await db.select(db.pendingOps).get();
  expect(pendingOpsAfterLogout, isEmpty);

  // 5. User B: Login
  await loginAs(TestUsers.userB);
  await enableNetwork();

  // 6. User B: Trigger sync
  await syncAll();

  // 7. Verify User A's operations NOT pushed by User B
  final remoteNotesForUserB = await fetchRemoteNotes(userId: TestUsers.userB.id);
  expect(remoteNotesForUserB.where((n) => n.title.contains('User A')), isEmpty);

  // 8. Verify no pending ops from User A visible to User B
  final pendingOpsB = await db.getPendingOps();
  expect(pendingOpsB, isEmpty); // User B has no pending ops
});
```

### Validation Queries
```sql
-- After User A logout, verify pending_ops cleared
SELECT COUNT(*) as count FROM pending_ops WHERE user_id = 'test-user-a-id';
-- Expected: 0

-- After User B login, verify no User A operations
SELECT COUNT(*) as count FROM pending_ops WHERE user_id != 'test-user-b-id';
-- Expected: 0

-- Verify sync didn't push wrong user's data
-- (This requires checking remote Supabase database)
SELECT COUNT(*) FROM notes WHERE user_id = 'test-user-b-id' AND title LIKE '%User A%';
-- Expected: 0
```

### Expected Results
- ✅ User A's pending operations cleared on logout
- ✅ User B doesn't see User A's pending operations
- ✅ Sync doesn't push wrong user's data to Supabase
- ✅ Supabase RLS prevents wrong user data insertion

### Pass Criteria
```dart
expect(pendingOpsAfterLogout, isEmpty);
expect(wrongUserOps, isEmpty);
expect(remoteNotesWithWrongUser, isEmpty);
```

---

## Scenario 5: Real-time Subscription Filtering

**Goal:** Verify User B doesn't receive User A's real-time updates.

### Setup
```dart
// test/scenarios/scenario_5_realtime_filtering_test.dart
test('Scenario 5: Real-time updates filtered by userId', () async {
  // 1. User A: Login and subscribe to notes stream
  await loginAs(TestUsers.userA);
  final notesStreamA = watchNotes();

  // 2. User B: Login in separate session (different device simulation)
  await loginAs(TestUsers.userB, newSession: true);

  // 3. User B: Create note (triggers real-time update)
  await createNote(title: 'User B Note', body: 'Content');

  // 4. Wait for real-time propagation
  await Future.delayed(Duration(seconds: 2));

  // 5. Verify User A's stream didn't receive User B's note
  final notesA = await notesStreamA.first;
  expect(notesA.where((n) => n.title.contains('User B')), isEmpty);

  // 6. Verify Supabase real-time filter applied
  // (Check subscription payload includes user_id filter)
});
```

### Validation
```sql
-- Check Supabase real-time subscriptions
SELECT *
FROM pg_stat_subscription
WHERE subname LIKE '%notes%';

-- Verify RLS policy applied to real-time
-- (Supabase automatically applies RLS to real-time subscriptions)
SHOW rls_policy FOR notes;
```

### Expected Results
- ✅ User A's stream doesn't receive User B's updates
- ✅ Supabase RLS filters real-time subscription
- ✅ No cross-user data leakage via real-time

---

## Scenario 6: Encryption Format Migration

**Goal:** Verify tasks re-encrypted from UTF8 to Base64 format without data loss.

### Setup
```sql
-- Create tasks with legacy UTF8 encryption format
-- (Simulate old data by directly inserting UTF8-encoded encrypted data)
INSERT INTO note_tasks (id, note_id, content_encrypted, status, created_at, updated_at, deleted)
VALUES
  -- These are UTF8-encoded instead of Base64 (legacy format)
  ('task-utf8-1', 'note-1', 'utf8_encrypted_content_1', 0, datetime('now'), datetime('now'), 0),
  ('task-utf8-2', 'note-1', 'utf8_encrypted_content_2', 0, datetime('now'), datetime('now'), 0);
```

### Execution
```dart
// test/scenarios/scenario_6_encryption_migration_test.dart
test('Scenario 6: Encryption format migration (UTF8 → Base64)', () async {
  // 1. Create tasks with legacy UTF8 format
  final legacyTasks = await createLegacyTasks(count: 100);

  // 2. Verify legacy format (UTF8)
  for (final task in legacyTasks) {
    expect(isBase64(task.contentEncrypted), isFalse);
  }

  // 3. Run encryption format migration
  await batchReencryptTasks();

  // 4. Verify all tasks now use Base64 format
  final migratedTasks = await db.select(db.noteTasks).get();
  for (final task in migratedTasks) {
    expect(isBase64(task.contentEncrypted), isTrue);
  }

  // 5. Verify decryption works for all tasks
  for (final task in migratedTasks) {
    final decrypted = await decryptTaskContent(task);
    expect(decrypted, isNotEmpty);
  }

  // 6. Verify no data loss (compare decrypted content)
  expect(migratedTasks.length, equals(100));
});
```

### Validation Queries
```sql
-- Check encryption format (Base64 has specific character set)
SELECT id, content_encrypted,
  CASE
    WHEN content_encrypted GLOB '*[^A-Za-z0-9+/=]*' THEN 'UTF8'
    ELSE 'Base64'
  END as format
FROM note_tasks;

-- Count tasks with incorrect format
SELECT COUNT(*) as utf8_tasks
FROM note_tasks
WHERE content_encrypted GLOB '*[^A-Za-z0-9+/=]*';
-- Expected: 0 (after migration)
```

### Expected Results
- ✅ All tasks re-encrypted from UTF8 to Base64
- ✅ No data loss (all tasks decrypt successfully)
- ✅ Migration handles both formats (backwards compatible)
- ✅ New tasks always use Base64 format

---

## Scenario 7: Full-Text Search User Isolation

**Goal:** Verify FTS queries filtered by userId.

### Setup
```sql
-- User A: Create notes with searchable content
INSERT INTO local_notes (id, user_id, title_encrypted, body_encrypted, updated_at, deleted)
VALUES
  ('note-a-1', 'test-user-a-id', 'My Secret Project', 'Confidential information', datetime('now'), 0);

-- FTS index (decrypted content)
INSERT INTO fts_notes (id, title, body, folder_path)
VALUES
  ('note-a-1', 'My Secret Project', 'Confidential information', '/Private');

-- User B: Create notes
INSERT INTO local_notes (id, user_id, title_encrypted, body_encrypted, updated_at, deleted)
VALUES
  ('note-b-1', 'test-user-b-id', 'My Public Project', 'Public information', datetime('now'), 0);

INSERT INTO fts_notes (id, title, body, folder_path)
VALUES
  ('note-b-1', 'My Public Project', 'Public information', '/Public');
```

### Execution
```dart
// test/scenarios/scenario_7_fts_filtering_test.dart
test('Scenario 7: FTS queries filtered by userId', () async {
  // 1. User A: Create notes with searchable content
  await loginAs(TestUsers.userA);
  await createNote(title: 'Secret Project', body: 'Confidential data');

  // 2. User B: Create notes
  await loginAs(TestUsers.userB);
  await createNote(title: 'Public Project', body: 'Public data');

  // 3. User B: Search for "Project"
  final searchResults = await searchNotes('Project');

  // 4. Verify User B sees only their note
  expect(searchResults.length, equals(1));
  expect(searchResults.first.title, contains('Public'));
  expect(searchResults.where((n) => n.title.contains('Secret')), isEmpty);

  // 5. Verify FTS index doesn't leak cross-user data
  final rawFTSResults = await db.customSelect(
    'SELECT id FROM fts_notes WHERE fts_notes MATCH ?',
    variables: [Variable('Project')],
  ).get();

  // Both notes match FTS, but application filters by userId
  expect(rawFTSResults.length, equals(2));

  // 6. Verify application-level filtering works
  final filteredResults = await filterNotesByUserId(
    rawFTSResults.map((r) => r.read<String>('id')).toList(),
    TestUsers.userB.id,
  );
  expect(filteredResults.length, equals(1));
});
```

### Expected Results
- ✅ FTS search returns only current user's notes
- ✅ No cross-user data leakage via FTS
- ✅ Application filters FTS results by userId

---

## Scenario 8: High-Volume Data Integrity

**Goal:** Verify database integrity with 100,000 records.

### Setup
```dart
// test/scenarios/scenario_8_high_volume_test.dart
test('Scenario 8: High-volume data integrity (100k records)', () async {
  // 1. Create massive dataset
  await loginAs(TestUsers.userA);
  await populateLargeDataset(
    noteCount: 10000,
    tasksPerNote: 5,
    tagsPerNote: 3,
    remindersPerNote: 1,
  );
  // Total: 10k notes + 50k tasks + 30k tags + 10k reminders = 100k records

  // 2. Verify counts
  final noteCount = await db.select(db.localNotes).get().then((l) => l.length);
  final taskCount = await db.select(db.noteTasks).get().then((l) => l.length);
  final tagCount = await db.select(db.noteTags).get().then((l) => l.length);

  expect(noteCount, equals(10000));
  expect(taskCount, equals(50000));
  expect(tagCount, equals(30000));

  // 3. Run clearAll() performance test
  final stopwatch = Stopwatch()..start();
  await db.clearAll();
  stopwatch.stop();

  // 4. Verify clearAll() performance (<2s for 100k records)
  expect(stopwatch.elapsedMilliseconds, lessThan(2000));

  // 5. Verify all data deleted
  final remainingNotes = await db.select(db.localNotes).get();
  final remainingTasks = await db.select(db.noteTasks).get();
  final remainingTags = await db.select(db.noteTags).get();

  expect(remainingNotes, isEmpty);
  expect(remainingTasks, isEmpty);
  expect(remainingTags, isEmpty);
});
```

### Validation Queries
```sql
-- After clearAll(), verify all tables empty
SELECT 'local_notes' as table_name, COUNT(*) as count FROM local_notes
UNION ALL
SELECT 'note_tasks', COUNT(*) FROM note_tasks
UNION ALL
SELECT 'note_tags', COUNT(*) FROM note_tags
UNION ALL
SELECT 'note_reminders', COUNT(*) FROM note_reminders
UNION ALL
SELECT 'local_folders', COUNT(*) FROM local_folders
UNION ALL
SELECT 'pending_ops', COUNT(*) FROM pending_ops;

-- Expected: All counts = 0
```

### Expected Results
- ✅ clearAll() completes in <2s for 100k records
- ✅ All 12 tables emptied
- ✅ FTS index cleared
- ✅ No database corruption

---

## Edge Case Testing

### Edge Case 1: NULL userId Values
```sql
-- Setup: Create records with NULL userId (simulate pre-migration state)
INSERT INTO note_tasks (id, note_id, user_id, content_encrypted, status, created_at, updated_at, deleted)
VALUES ('task-null', 'note-1', NULL, 'content', 0, datetime('now'), datetime('now'), 0);

-- Validation: Migration should handle NULL
-- Either backfill from parent note OR delete if orphaned
```

### Edge Case 2: Circular Foreign Keys
```sql
-- Setup: Create circular task hierarchy
INSERT INTO note_tasks (id, note_id, parent_task_id, ...)
VALUES
  ('task-a', 'note-1', 'task-b', ...),
  ('task-b', 'note-1', 'task-a', ...); -- Circular!

-- Validation: Migration should detect and break circular references
```

### Edge Case 3: Unicode and Special Characters
```dart
test('Edge Case: Unicode in encrypted data', () async {
  await createNote(
    title: '日本語のタイトル 🎌',
    body: 'Emoji content: 😀👍🎉\nUnicode: Ω≈ç√∫˜µ≤',
  );

  // Verify encryption/decryption handles Unicode
  final note = await getNoteById(noteId);
  expect(note!.title, contains('日本語'));
  expect(note.body, contains('😀'));
});
```

### Edge Case 4: Very Long Strings
```dart
test('Edge Case: Very long note body (1MB)', () async {
  final largeBody = 'x' * 1024 * 1024; // 1MB string

  await createNote(title: 'Large Note', body: largeBody);

  // Verify no truncation or corruption
  final note = await getNoteById(noteId);
  expect(note!.body.length, equals(1024 * 1024));
});
```

### Edge Case 5: Concurrent Updates
```dart
test('Edge Case: Concurrent updates to same note', () async {
  final note = await createNote(title: 'Original', body: 'Content');

  // Simulate concurrent updates
  await Future.wait([
    updateNote(note.id, title: 'Update 1'),
    updateNote(note.id, title: 'Update 2'),
    updateNote(note.id, title: 'Update 3'),
  ]);

  // Verify database consistency (one update wins)
  final finalNote = await getNoteById(note.id);
  expect(finalNote, isNotNull);
  expect(finalNote!.title, matches(RegExp('Update [1-3]')));
});
```

---

## Automated Test Suite

### Run All Scenarios
```bash
# Run all database testing scenarios
flutter test test/scenarios/

# Run specific scenario
flutter test test/scenarios/scenario_1_user_switch_test.dart

# Run with coverage
flutter test --coverage test/scenarios/
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Continuous Integration
```yaml
# .github/workflows/database-tests.yml
name: Database Testing
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Install dependencies
        run: flutter pub get
      - name: Run database tests
        run: flutter test test/scenarios/
      - name: Generate coverage
        run: |
          flutter test --coverage test/scenarios/
          lcov --list coverage/lcov.info
```

---

## Performance Benchmarks

### Target Performance Metrics
| Operation | Target | Acceptable | Critical |
|-----------|--------|-----------|----------|
| clearAll() (1k records) | <100ms | <500ms | <1s |
| clearAll() (10k records) | <500ms | <1s | <2s |
| Migration 31 (10k tasks) | <2s | <5s | <10s |
| userId backfill (10k rows) | <3s | <8s | <15s |
| Query with userId filter | <50ms | <100ms | <200ms |

### Benchmark Script
```dart
// test/benchmarks/database_benchmarks.dart
void main() {
  group('Database Performance Benchmarks', () {
    test('clearAll() performance with 10k records', () async {
      await populateLargeDataset(noteCount: 10000);

      final stopwatch = Stopwatch()..start();
      await db.clearAll();
      stopwatch.stop();

      print('clearAll(10k): ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('userId query performance', () async {
      await populateLargeDataset(noteCount: 10000);

      final stopwatch = Stopwatch()..start();
      final notes = await (db.select(db.localNotes)
        ..where((n) => n.userId.equals(currentUserId))
        ..where((n) => n.deleted.equals(false))
      ).get();
      stopwatch.stop();

      print('Query with userId filter: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
```

---

## Summary Checklist

### Pre-Migration Validation
- [ ] Run Scenario 1 (user switch)
- [ ] Run Scenario 2 (large migration)
- [ ] Run Scenario 3 (orphaned tasks)
- [ ] Verify all validation queries pass
- [ ] Benchmark performance metrics

### Post-Migration Validation
- [ ] Run Scenario 4 (pending ops)
- [ ] Run Scenario 5 (real-time filtering)
- [ ] Run Scenario 6 (encryption migration)
- [ ] Run Scenario 7 (FTS filtering)
- [ ] Run Scenario 8 (high-volume)

### Edge Case Coverage
- [ ] Test NULL userId handling
- [ ] Test circular references
- [ ] Test Unicode/special characters
- [ ] Test very long strings (>1MB)
- [ ] Test concurrent updates

### Production Readiness
- [ ] All scenarios pass (0 failures)
- [ ] Performance metrics meet targets
- [ ] Rollback procedures tested
- [ ] Monitoring alerts configured
- [ ] User communication prepared

---

## Conclusion

This comprehensive test suite ensures:
1. **Zero data loss** during migrations
2. **Zero security vulnerabilities** from cross-user leakage
3. **Acceptable performance** for large datasets
4. **Reliable rollback** procedures
5. **Production readiness** with edge case coverage

**Next Steps:**
1. Run automated test suite: `flutter test test/scenarios/`
2. Review failed tests and fix issues
3. Benchmark performance on target devices
4. Deploy to staging environment
5. Monitor production metrics post-deployment
