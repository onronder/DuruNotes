# DATABASE INTEGRITY - IMMEDIATE FIXES (P0)

**CRITICAL**: These fixes must be deployed immediately to prevent data leakage.

---

## FIX 1: Add user_id Filtering to NotesCoreRepository

### Files to Modify

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

### Changes Required

#### Change 1: localNotes() method (line ~1839)

```dart
// BEFORE:
Future<List<domain.Note>> localNotes() async {
  try {
    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) => note.deleted.equals(false))
              ..orderBy([
                (note) => OrderingTerm(
                  expression: note.isPinned,
                  mode: OrderingMode.desc,
                ),
                (note) => OrderingTerm(
                  expression: note.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return await _hydrateDomainNotes(localNotes);
  }
}

// AFTER:
Future<List<domain.Note>> localNotes() async {
  try {
    // SECURITY FIX: Filter by user_id to prevent data leakage
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot list notes without authenticated user');
      return const <domain.Note>[];
    }

    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) =>
                note.deleted.equals(false) &
                note.userId.equals(userId))  // ✅ ADD USER FILTER
              ..orderBy([
                (note) => OrderingTerm(
                  expression: note.isPinned,
                  mode: OrderingMode.desc,
                ),
                (note) => OrderingTerm(
                  expression: note.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return await _hydrateDomainNotes(localNotes);
  }
}
```

#### Change 2: localNotesForSync() method (line ~1801)

```dart
// BEFORE:
Future<List<domain.Note>> localNotesForSync() async {
  try {
    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) => note.deleted.equals(false))
              ..orderBy([...]))
            .get();

// AFTER:
Future<List<domain.Note>> localNotesForSync() async {
  try {
    // SECURITY FIX: Filter by user_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot sync notes without authenticated user');
      return const <domain.Note>[];
    }

    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) =>
                note.deleted.equals(false) &
                note.userId.equals(userId))  // ✅ ADD USER FILTER
              ..orderBy([...]))
            .get();
```

#### Change 3: getRecentlyViewedNotes() method (line ~1873)

```dart
// BEFORE:
Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
  try {
    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) => note.deleted.equals(false))
              ..orderBy([...])
              ..limit(limit))
            .get();

// AFTER:
Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
  try {
    // SECURITY FIX: Filter by user_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot get recently viewed notes without authenticated user');
      return const <domain.Note>[];
    }

    final localNotes =
        await (db.select(db.localNotes)
              ..where((note) =>
                note.deleted.equals(false) &
                note.userId.equals(userId))  // ✅ ADD USER FILTER
              ..orderBy([...])
              ..limit(limit))
            .get();
```

#### Change 4: listAfter() method (line ~1906)

```dart
// BEFORE:
Future<List<domain.Note>> listAfter(
  DateTime? cursor, {
  int limit = 20,
}) async {
  try {
    final query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false));

    if (cursor != null) {
      query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
    }

// AFTER:
Future<List<domain.Note>> listAfter(
  DateTime? cursor, {
  int limit = 20,
}) async {
  try {
    // SECURITY FIX: Filter by user_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot list notes without authenticated user');
      return const <domain.Note>[];
    }

    final query = db.select(db.localNotes)
      ..where((note) =>
        note.deleted.equals(false) &
        note.userId.equals(userId));  // ✅ ADD USER FILTER

    if (cursor != null) {
      query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
    }
```

#### Change 5: list() method (line ~2073)

```dart
// BEFORE:
Future<List<domain.Note>> list({int? limit}) async {
  try {
    final query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..orderBy([...]);

// AFTER:
Future<List<domain.Note>> list({int? limit}) async {
  try {
    // SECURITY FIX: Filter by user_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot list notes without authenticated user');
      return const <domain.Note>[];
    }

    final query = db.select(db.localNotes)
      ..where((note) =>
        note.deleted.equals(false) &
        note.userId.equals(userId))  // ✅ ADD USER FILTER
      ..orderBy([...]);
```

#### Change 6: getPinnedNotes() method (line ~2004)

```dart
// BEFORE:
Future<List<domain.Note>> getPinnedNotes() async {
  try {
    final localNotes = await db.getPinnedNotes();
    return await _hydrateDomainNotes(localNotes);

// AFTER:
Future<List<domain.Note>> getPinnedNotes() async {
  try {
    // SECURITY FIX: Filter by user_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot get pinned notes without authenticated user');
      return const <domain.Note>[];
    }

    final localNotes = await (db.select(db.localNotes)
      ..where((note) =>
        note.deleted.equals(false) &
        note.isPinned.equals(true) &
        note.userId.equals(userId))  // ✅ ADD USER FILTER
      ..orderBy([(note) => OrderingTerm.desc(note.updatedAt)])).get();
    return await _hydrateDomainNotes(localNotes);
```

---

## FIX 2: Complete Database Clearing

### File to Modify

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

### Changes Required

#### Update clearAll() method (line ~1037)

```dart
// BEFORE:
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
    await customStatement('DELETE FROM fts_notes');

    if (kDebugMode) {
      debugPrint('[AppDb] ✅ All tables cleared - database reset for user switch');
    }
  });
}

// AFTER:
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
      debugPrint('[AppDb] ✅ All tables cleared (including templates, attachments, inbox) - database reset for user switch');
    }
  });
}
```

---

## FIX 3: Add user_id to NoteTasks Table

### Files to Modify

**File 1**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

#### Change 1: Add userId column to NoteTasks table (line ~163)

```dart
// BEFORE:
@DataClassName('NoteTask')
class NoteTasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();

  // ENCRYPTED COLUMNS
  TextColumn get contentEncrypted => text().named('content_encrypted')();
  // ... rest

// AFTER:
@DataClassName('NoteTask')
class NoteTasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();  // ✅ ADD THIS

  // ENCRYPTED COLUMNS
  TextColumn get contentEncrypted => text().named('content_encrypted')();
  // ... rest
```

#### Change 2: Add migration (line ~509)

```dart
@override
int get schemaVersion => 30; // Increment from 29 to 30

// In migration strategy onUpgrade:
if (from < 30) {
  // Version 30: Add userId to note_tasks for user isolation (P0 security fix)
  await m.addColumn(noteTasks, noteTasks.userId);

  // Backfill userId from notes table (best effort)
  // Note: This requires notes to already have userId populated
  await customStatement('''
    UPDATE note_tasks
    SET user_id = (
      SELECT user_id
      FROM local_notes
      WHERE local_notes.id = note_tasks.note_id
      LIMIT 1
    )
    WHERE user_id IS NULL OR user_id = ''
  ''');

  _logger.info('Migration 30: Added userId to note_tasks table');
}
```

#### Change 3: Update getTasksForNote query (in AppDb class)

```dart
// Find existing getTasksForNote method and add user filter:
Future<List<NoteTask>> getTasksForNote(String noteId) {
  final userId = _supabase?.auth.currentUser?.id;
  if (userId == null) {
    return Future.value([]);
  }

  return (select(noteTasks)
    ..where((t) =>
      t.noteId.equals(noteId) &
      t.deleted.equals(false) &
      t.userId.equals(userId))  // ✅ ADD USER FILTER
    ..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
}
```

**File 2**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart`

#### Change 4: Add user_id filtering to all query methods

```dart
// Update createTask() method (line ~215) to set userId:
Future<domain.Task> createTask(domain.Task task) async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      final authorizationError = StateError(
        'Cannot create task without authenticated user',
      );
      // ... error handling
      throw authorizationError;
    }

    // ... rest of method

    // In taskCompanion creation, add userId:
    final taskCompanion = NoteTasksCompanion(
      id: Value(taskToCreate.id),
      noteId: Value(taskToCreate.noteId),
      userId: Value(userId),  // ✅ ADD THIS
      contentEncrypted: Value(contentEncrypted),
      // ... rest
    );
```

#### Change 5: Add user_id filtering to getAllTasks() (line ~160)

```dart
// BEFORE:
Future<List<domain.Task>> getAllTasks() async {
  try {
    final localTasks = await db.getAllTasks();
    return await _decryptTasks(localTasks);
  }
}

// AFTER:
Future<List<domain.Task>> getAllTasks() async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot get all tasks without authenticated user');
      return const <domain.Task>[];
    }

    final localTasks = await (db.select(db.noteTasks)
      ..where((t) =>
        t.deleted.equals(false) &
        t.userId.equals(userId))  // ✅ ADD USER FILTER
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

    return await _decryptTasks(localTasks);
  }
}
```

#### Change 6: Add user_id filtering to getPendingTasks() (line ~176)

```dart
// BEFORE:
Future<List<domain.Task>> getPendingTasks() async {
  try {
    final localTasks = await db.getOpenTasks();
    return await _decryptTasks(localTasks);
  }
}

// AFTER:
Future<List<domain.Task>> getPendingTasks() async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot get pending tasks without authenticated user');
      return const <domain.Task>[];
    }

    final localTasks = await (db.select(db.noteTasks)
      ..where((t) =>
        t.deleted.equals(false) &
        t.status.equals(TaskStatus.open.index) &
        t.userId.equals(userId))  // ✅ ADD USER FILTER
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

    return await _decryptTasks(localTasks);
  }
}
```

---

## FIX 4: Add user_id to PendingOps Table

### File to Modify

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

#### Change 1: Add userId column (line ~59)

```dart
// BEFORE:
@DataClassName('PendingOp')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// AFTER:
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

#### Change 2: Add migration (in onUpgrade)

```dart
if (from < 30) {
  // ... previous note_tasks migration

  // Add userId to pending_ops
  await m.addColumn(pendingOps, pendingOps.userId);

  // Delete all existing pending ops (can't backfill reliably)
  await delete(pendingOps).go();

  _logger.info('Migration 30: Added userId to pending_ops and cleared queue');
}
```

#### Change 3: Update enqueue method (line ~1005)

```dart
// BEFORE:
Future<int> enqueue(String entityId, String kind, {String? payload}) =>
  into(pendingOps).insert(
    PendingOpsCompanion.insert(
      entityId: entityId,
      kind: kind,
      payload: Value(payload),
    ),
  );

// AFTER:
Future<int> enqueue(String entityId, String kind, {String? payload}) {
  // Get current user ID
  final userId = _supabase?.auth.currentUser?.id ?? '';

  if (userId.isEmpty) {
    _logger.warning('Cannot enqueue operation without authenticated user');
    throw StateError('No authenticated user for enqueue');
  }

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

#### Change 4: Update getPendingOps method (line ~1014)

```dart
// BEFORE:
Future<List<PendingOp>> getPendingOps() =>
  (select(pendingOps)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

// AFTER:
Future<List<PendingOp>> getPendingOps() {
  final userId = _supabase?.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    _logger.warning('Cannot get pending ops without authenticated user');
    return Future.value([]);
  }

  return (select(pendingOps)
    ..where((o) => o.userId.equals(userId))  // ✅ ADD USER FILTER
    ..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
}
```

---

## FIX 5: Add Defensive Validation in Sync

### File to Modify

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

#### Change: Add user_id validation in _applyRemoteNote (line ~999)

```dart
// Find the _applyRemoteNote method and add validation at the start:

Future<void> _applyRemoteNote(Map<String, dynamic> remoteNote) async {
  final noteId = remoteNote['id'] as String;
  try {
    // ✅ ADD: Get current user
    final currentUserId = _supabase.auth.currentUser?.id;

    final userId =
        remoteNote['user_id'] as String? ??
        _supabase.auth.currentUser?.id ??
        '';

    // ✅ ADD: Defensive validation - ensure note belongs to current user
    if (currentUserId != null && currentUserId.isNotEmpty && userId != currentUserId) {
      _logger.error(
        'SECURITY VIOLATION: Attempted to apply note from different user',
        data: {
          'noteId': noteId,
          'currentUserId': currentUserId,
          'noteUserId': userId,
        },
      );
      _captureRepositoryException(
        method: '_applyRemoteNote.securityViolation',
        error: StateError('Note user_id mismatch'),
        stackTrace: StackTrace.current,
        data: {
          'noteId': noteId,
          'currentUserId': currentUserId,
          'noteUserId': userId,
        },
        level: SentryLevel.fatal,
      );
      return; // Skip this note
    }

    if (userId.isEmpty) {
      throw StateError('Missing user id for remote note $noteId');
    }

    // ... rest of method
```

Apply the same pattern to:
- `_applyRemoteFolder` (line ~1138)
- `_applyRemoteTask` (line ~1219)
- `_applyRemoteTemplate` (line ~1340)

---

## Testing Checklist

After implementing all fixes, test in this order:

### Test 1: Clean State Test
```bash
1. Uninstall app completely
2. Install fresh build
3. Login as User A
4. Create 3 notes, 2 tasks, 1 folder
5. Verify all have userId set
6. Logout
7. Login as User B
8. Verify User B sees ZERO data
9. Create 2 notes
10. Logout, login as User A again
11. Verify User A sees their 3 original notes (synced from Supabase)
```

### Test 2: Database Inspection
```dart
// Run this query after logout:
final notesCount = await db.customSelect(
  'SELECT COUNT(*) as count FROM local_notes',
).getSingle();

// Should be 0 after logout
assert(notesCount['count'] == 0, 'Database not cleared!');
```

### Test 3: User Isolation Test
```dart
// After User B logs in:
final userId = client.auth.currentUser?.id;
final wrongUserNotes = await db.customSelect(
  'SELECT COUNT(*) as count FROM local_notes WHERE user_id != ?',
  variables: [Variable.withString(userId!)],
).getSingle();

// Should be 0 - no other user's data
assert(wrongUserNotes['count'] == 0, 'Data leakage detected!');
```

---

## Deployment Steps

1. **Create feature branch**: `git checkout -b fix/critical-data-isolation`

2. **Apply all fixes** in this order:
   - Fix 2 (clearAll) - easiest, no migration
   - Fix 1 (NotesCoreRepository queries) - no migration
   - Fix 3 (NoteTasks user_id) - requires migration
   - Fix 4 (PendingOps user_id) - requires migration
   - Fix 5 (Defensive validation) - no migration

3. **Test locally**: Run all tests above

4. **Test on device**: Install on physical device and test user switching

5. **Code review**: Get approval

6. **Merge to main**

7. **Deploy as HOTFIX**:
   - Version bump: `x.y.z` -> `x.y.z+1`
   - Build and submit to App Store/Play Store as critical update
   - Release notes: "Critical security fix for user data isolation"

8. **Monitor**: Watch Sentry for any security violations

---

## Rollback Plan

If issues arise:

1. **Revert schema migration**: Keep version 29, remove version 30 migration

2. **Deploy previous version**: Use last known good build

3. **Data recovery**: Run this SQL on affected devices:
```sql
-- Mark all local data as needing re-sync
UPDATE local_notes SET deleted = 1;
UPDATE local_folders SET deleted = 1;
UPDATE note_tasks SET deleted = 1;
UPDATE pending_ops SET payload = NULL;
```

4. **Force full sync**: Clear local DB and re-download from Supabase

---

## Support Resources

- **Full Audit Report**: `DATABASE_INTEGRITY_AUDIT_REPORT.md`
- **Test Queries**: See Part 6 of audit report
- **Monitoring**: Check Sentry for errors tagged with `securityViolation`

---

## Questions or Issues?

If you encounter any issues during implementation:

1. Check the full audit report for context
2. Test each fix independently before moving to the next
3. Monitor logs for security violations
4. Verify clearAll() actually clears the database after each logout

**Remember**: This is a CRITICAL security fix. Take time to test thoroughly before deploying.
