# P1-P3 Updated Implementation Plan
## Safe Migration Order, Indexing Strategy, and Deployment

**Document Version:** 1.0
**Last Updated:** 2025-10-24
**Status:** READY FOR IMPLEMENTATION

---

## Executive Summary

Based on comprehensive database analysis, this document provides the **updated implementation plan** for security phases P1-P3, incorporating:

1. **Safe migration order** (indexes BEFORE constraints)
2. **Optimized userId filtering** with performance guarantees
3. **Zero-downtime deployment** strategy
4. **Comprehensive monitoring** and rollback procedures

### Key Findings from Analysis

**CRITICAL GAPS IDENTIFIED:**
- 6 out of 12 local tables missing `userId` column
- PendingOps sync queue has NO user isolation (data leakage risk)
- NoteTasks, NoteReminders, NoteTags lack authorization
- Encryption format inconsistency (UTF8 vs Base64)

**POSITIVE FINDINGS:**
- Remote Supabase schema is correct (all tables have userId + RLS)
- clearAll() implementation is correct (clears all 12 tables)
- Template and Folder repositories already have userId filtering

**PERFORMANCE IMPACT:**
- With proper indexes: **30-50% faster queries** (smaller result sets)
- Without indexes: **50-100% slower queries** (full table scans)
- **Recommendation:** Deploy indexes BEFORE userId filtering

---

## Implementation Timeline

### Week 1: P1 Critical Security Fixes
- **Days 1-2:** Schema migrations (PendingOps, NoteTasks)
- **Days 3-4:** Repository query rewrites
- **Day 5:** Testing and validation

### Week 2: P2 Complete User Isolation
- **Days 1-3:** Add userId to remaining 4 tables
- **Days 4-5:** Make userId non-nullable (hardening)

### Week 3: P3 Performance Optimization
- **Days 1-2:** Create all composite indexes
- **Days 3-4:** FTS auxiliary table implementation
- **Day 5:** Performance benchmarking

### Week 4: Production Deployment
- **Days 1-2:** Staging environment testing
- **Day 3:** Production deployment (phased rollout)
- **Days 4-5:** Monitoring and optimization

**Total Duration:** 4 weeks
**Risk Level:** Medium (schema changes + query rewrites)
**Mitigation:** Comprehensive testing + rollback procedures

---

## Phase 1 (P1): Critical Security Fixes

### Priority 1: Fix Sync Queue (PendingOps)

**Why Critical:** User B can push User A's pending operations to Supabase.

**Schema Version:** 30

**Migration Order:**
```sql
-- Step 1: Add userId column (nullable initially)
ALTER TABLE pending_ops ADD COLUMN user_id TEXT;

-- Step 2: Create index BEFORE backfilling
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_id ON pending_ops(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_kind ON pending_ops(user_id, kind);

-- Step 3: Backfill strategy (SAFE: Clear entire queue)
-- Rationale: Pending ops are transient, better to clear than risk corruption
DELETE FROM pending_ops;

-- Alternative (RISKY: Attempt backfill)
-- UPDATE pending_ops SET user_id = (
--   SELECT user_id FROM local_notes WHERE id = pending_ops.entity_id
-- );
-- DELETE FROM pending_ops WHERE user_id IS NULL;
```

**Repository Changes:**
```dart
// lib/services/unified_sync_service.dart:626
// BEFORE
final allPendingOps = await _db!.select(_db!.pendingOps).get();

// AFTER
final userId = _client.auth.currentUser?.id;
if (userId == null) throw StateError('Not authenticated');

final allPendingOps = await (_db!.select(_db!.pendingOps)
  ..where((op) => op.userId.equals(userId))
).get();
```

**Testing:**
- Run Scenario 4 (pending ops leak) ✅
- Verify User B cannot see User A's pending ops ✅
- Verify clearAll() removes pending ops ✅

---

### Priority 2: Fix Task Privacy (NoteTasks)

**Why Critical:** Users can see each other's tasks.

**Schema Version:** 31

**Migration Order:**
```sql
-- Step 1: Add userId column (nullable initially)
ALTER TABLE note_tasks ADD COLUMN user_id TEXT;

-- Step 2: Create indexes BEFORE backfilling
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_id ON note_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_note ON note_tasks(user_id, note_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status ON note_tasks(user_id, status) WHERE deleted = 0;

-- Step 3: Backfill userId from parent note
UPDATE note_tasks
SET user_id = (
  SELECT user_id FROM local_notes WHERE id = note_tasks.note_id
);

-- Step 4: Clean up orphaned tasks (no parent note)
DELETE FROM note_tasks WHERE user_id IS NULL;

-- Step 5: Validate
SELECT COUNT(*) FROM note_tasks WHERE user_id IS NULL;
-- Expected: 0
```

**Repository Changes:**
```dart
// lib/infrastructure/repositories/task_core_repository.dart

// BEFORE (line 141)
@override
Future<List<domain.Task>> getTasksForNote(String noteId) async {
  final localTasks = await (db.select(db.noteTasks)
    ..where((t) => t.noteId.equals(noteId))
    ..where((t) => t.deleted.equals(false))
  ).get();
  return await _decryptTasks(localTasks);
}

// AFTER
@override
Future<List<domain.Task>> getTasksForNote(String noteId) async {
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
}

// Apply same pattern to:
// - getAllTasks()
// - getPendingTasks()
// - getTaskById()
// - watchTasks()
```

**Testing:**
- Run Scenario 2 (large migration with 10k tasks) ✅
- Run Scenario 3 (orphaned tasks cleanup) ✅
- Verify performance <50ms for task queries ✅

---

### Priority 3: Add userId Filtering to Notes Repository

**Repository:** `lib/infrastructure/repositories/notes_core_repository.dart`

**Queries to Update:**
1. ✅ `getNoteById()` - Already has userId check (line 110)
2. ❌ `list()` - **MISSING userId filter**
3. ❌ `listAfter()` - **MISSING userId filter**
4. ❌ `watchNotes()` - **MISSING userId filter**

**Implementation:**
```dart
// lib/infrastructure/repositories/notes_core_repository.dart

// list() method - Add userId filter
@override
Future<List<domain.Note>> list({
  String? folderId,
  Set<String>? tags,
  SortSpec sortSpec = const SortSpec(),
  int? limit,
}) async {
  try {
    // SECURITY: Get authenticated user
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning('Cannot list notes without authenticated user');
      return [];
    }

    // Build query with userId filter
    var query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.userId.equals(userId))  // NEW: User isolation
      ..where((note) => note.noteType.equals(0));

    // ... rest of query building (folders, tags, sorting)

    final localNotes = await query.get();
    return await _decryptNotes(localNotes, userId);
  } catch (e, stack) {
    // error handling...
  }
}

// Similar pattern for listAfter() and watchNotes()
```

**Testing:**
- Run Scenario 1 (user switch) ✅
- Verify User B cannot see User A's notes ✅
- Benchmark query performance ✅

---

## Phase 2 (P2): Complete User Isolation

### Step 2.1: Add userId to NoteReminders

**Schema Version:** 32

**Migration:**
```sql
-- Add column
ALTER TABLE note_reminders ADD COLUMN user_id TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_id ON note_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_active ON note_reminders(user_id, is_active) WHERE remind_at IS NOT NULL;

-- Backfill from parent note
UPDATE note_reminders
SET user_id = (SELECT user_id FROM local_notes WHERE id = note_reminders.note_id);

-- Delete orphaned reminders
DELETE FROM note_reminders WHERE user_id IS NULL;
```

**Repository:** `lib/services/advanced_reminder_service.dart`

---

### Step 2.2: Add userId to NoteTags

**Schema Version:** 33

**Migration:**
```sql
-- Add column
ALTER TABLE note_tags ADD COLUMN user_id TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_note_tags_user_tag ON note_tags(user_id, tag);
CREATE INDEX IF NOT EXISTS idx_note_tags_user_note ON note_tags(user_id, note_id);

-- Backfill from parent note
UPDATE note_tags
SET user_id = (SELECT user_id FROM local_notes WHERE id = note_tags.note_id);

-- Delete orphaned tags
DELETE FROM note_tags WHERE user_id IS NULL;
```

**Query Updates:**
```dart
// lib/data/local/app_db.dart:1126
Future<List<String>> distinctTags(String userId) async {
  final rows = await customSelect(
    '''
    SELECT DISTINCT t.tag AS tag
    FROM note_tags t
    JOIN local_notes n ON n.id = t.note_id
    WHERE t.user_id = ?
      AND n.user_id = ?
      AND n.deleted = 0
      AND n.note_type = 0
    ORDER BY LOWER(t.tag) ASC
    ''',
    variables: [Variable(userId), Variable(userId)],
    readsFrom: {noteTags, localNotes},
  ).get();

  return rows.map((r) => r.read<String>('tag')).toList();
}
```

---

### Step 2.3: Add userId to NoteLinks

**Schema Version:** 34

**Migration:**
```sql
-- Add column
ALTER TABLE note_links ADD COLUMN user_id TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_note_links_user_id ON note_links(user_id);
CREATE INDEX IF NOT EXISTS idx_note_links_user_source ON note_links(user_id, source_id);
CREATE INDEX IF NOT EXISTS idx_note_links_user_target ON note_links(user_id, target_id);

-- Backfill from source note
UPDATE note_links
SET user_id = (SELECT user_id FROM local_notes WHERE id = note_links.source_id);

-- Delete orphaned links
DELETE FROM note_links WHERE user_id IS NULL;
```

---

### Step 2.4: Add userId to NoteFolders

**Schema Version:** 35

**Migration:**
```sql
-- Add column
ALTER TABLE note_folders ADD COLUMN user_id TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_note_folders_user_id ON note_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder ON note_folders(user_id, folder_id);
CREATE INDEX IF NOT EXISTS idx_note_folders_user_note ON note_folders(user_id, note_id);

-- Backfill from note (first) or folder (fallback)
UPDATE note_folders
SET user_id = COALESCE(
  (SELECT user_id FROM local_notes WHERE id = note_folders.note_id),
  (SELECT user_id FROM local_folders WHERE id = note_folders.folder_id)
);

-- Delete orphaned relationships
DELETE FROM note_folders WHERE user_id IS NULL;
```

---

### Step 2.5: Add userId to Attachments

**Schema Version:** 36

**Migration:**
```sql
-- Add column
ALTER TABLE attachments ADD COLUMN user_id TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_note ON attachments(user_id, note_id);

-- Backfill from parent note
UPDATE attachments
SET user_id = (SELECT user_id FROM local_notes WHERE id = attachments.note_id);

-- Delete orphaned attachments
DELETE FROM attachments WHERE user_id IS NULL;
```

---

### Step 2.6: Make userId Non-Nullable (Hardening)

**Schema Version:** 37

**Pre-Validation:**
```sql
-- CRITICAL: Run this BEFORE making userId non-nullable
SELECT table_name, null_count FROM (
  SELECT 'local_notes' as table_name, COUNT(*) as null_count FROM local_notes WHERE user_id IS NULL
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
  SELECT 'attachments', COUNT(*) FROM attachments WHERE user_id IS NULL
);

-- Expected: All null_count = 0
```

**Migration:**
```dart
// Update app_db.dart table definitions
// BEFORE
TextColumn get userId => text().nullable()();

// AFTER
TextColumn get userId => text()();
```

**Note:** SQLite doesn't support `ALTER COLUMN`, so Drift will recreate tables with NOT NULL constraint during migration.

---

## Phase 3 (P3): Performance Optimization

### Step 3.1: Create Composite Indexes

**Schema Version:** 38

**All Required Indexes:**
```sql
-- Notes (most frequently queried)
CREATE INDEX IF NOT EXISTS idx_local_notes_user_deleted_updated
  ON local_notes(user_id, deleted, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_local_notes_user_pinned_updated
  ON local_notes(user_id, is_pinned DESC, updated_at DESC)
  WHERE deleted = 0;

-- Tasks
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_note_deleted
  ON note_tasks(user_id, note_id, deleted);

CREATE INDEX IF NOT EXISTS idx_note_tasks_user_status_due
  ON note_tasks(user_id, status, due_date)
  WHERE deleted = 0;

-- Folders
CREATE INDEX IF NOT EXISTS idx_local_folders_user_parent_order
  ON local_folders(user_id, parent_id, sort_order)
  WHERE deleted = 0;

-- Reminders
CREATE INDEX IF NOT EXISTS idx_note_reminders_user_active_time
  ON note_reminders(user_id, is_active, remind_at)
  WHERE remind_at IS NOT NULL;

-- Tags
CREATE INDEX IF NOT EXISTS idx_note_tags_user_tag
  ON note_tags(user_id, tag);

-- Links
CREATE INDEX IF NOT EXISTS idx_note_links_user_source
  ON note_links(user_id, source_id);

-- Junction tables
CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder_updated
  ON note_folders(user_id, folder_id, updated_at DESC);

-- Pending operations
CREATE INDEX IF NOT EXISTS idx_pending_ops_user_created
  ON pending_ops(user_id, created_at ASC);
```

**Index Creation Performance:**
- 10,000 notes: ~500ms
- 50,000 tasks: ~2s
- Total: <5s for all indexes

---

### Step 3.2: FTS Auxiliary Table

**Improves FTS search from ~15ms to ~8ms**

**Schema:**
```sql
-- Create auxiliary table for FTS user filtering
CREATE TABLE fts_notes_aux (
  note_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_fts_notes_aux_user ON fts_notes_aux(user_id, deleted);
```

**Sync Trigger:**
```dart
// Update FTS auxiliary table when note changes
Future<void> updateFTSAux(String noteId, String userId, bool deleted) async {
  await db.customStatement(
    '''
    INSERT OR REPLACE INTO fts_notes_aux (note_id, user_id, deleted)
    VALUES (?, ?, ?)
    ''',
    variables: [Variable(noteId), Variable(userId), Variable(deleted ? 1 : 0)],
  );
}
```

**Updated Search Query:**
```dart
Future<List<Note>> searchNotes(String query) async {
  final userId = currentUserId;

  final results = await db.customSelect(
    '''
    SELECT n.*
    FROM fts_notes f
    JOIN fts_notes_aux a ON a.note_id = f.id
    JOIN local_notes n ON n.id = f.id
    WHERE f.fts_notes MATCH ?
      AND a.user_id = ?
      AND a.deleted = 0
    ORDER BY rank
    LIMIT 100
    ''',
    variables: [Variable(query), Variable(userId)],
    readsFrom: {db.localNotes},
  ).get();

  return results.map((row) => row.readTable(db.localNotes)).toList();
}
```

---

## Deployment Strategy

### Phase 1: Development & Testing
```bash
# Week 1-3: Implementation
git checkout -b feature/p1-p3-security-hardening

# Run automated tests
flutter test test/scenarios/

# Run benchmarks
flutter test test/benchmarks/

# Verify no regressions
flutter test
```

### Phase 2: Staging Deployment
```bash
# Week 4 Day 1-2
# Deploy to staging environment
flutter build apk --release --staging
flutter build ios --release --staging

# Run production-like tests with real data
# - Import 10k note export
# - Test user switching
# - Verify sync integrity
```

### Phase 3: Production Rollout (Phased)
```yaml
# Week 4 Day 3-5

# Stage 1: 5% of users (canary)
rollout_percentage: 5
monitoring: high
duration: 24 hours
rollback_threshold: 1% error rate

# Stage 2: 25% of users
rollout_percentage: 25
monitoring: medium
duration: 48 hours
rollback_threshold: 2% error rate

# Stage 3: 100% of users
rollout_percentage: 100
monitoring: normal
duration: ongoing
```

---

## Monitoring & Alerts

### Key Metrics to Monitor

**Database Performance:**
```dart
// Sentry metric tracking
Sentry.captureMessage(
  'Query performance',
  level: SentryLevel.info,
  hint: Hint.withMap({
    'queryName': 'list_notes',
    'durationMs': duration,
    'resultCount': notes.length,
  }),
);
```

**Alert Thresholds:**
- Query time >100ms: WARNING
- Query time >500ms: CRITICAL
- Error rate >1%: CRITICAL
- Crash rate increase >0.5%: CRITICAL

**Custom Monitoring:**
```dart
// lib/core/monitoring/migration_monitor.dart
class MigrationMonitor {
  static void trackMigration({
    required int fromVersion,
    required int toVersion,
    required Duration duration,
    required bool success,
  }) {
    Sentry.captureMessage(
      'Database migration',
      level: success ? SentryLevel.info : SentryLevel.error,
      hint: Hint.withMap({
        'fromVersion': fromVersion,
        'toVersion': toVersion,
        'durationMs': duration.inMilliseconds,
        'success': success,
      }),
    );
  }
}
```

### Rollback Triggers

**Automatic Rollback If:**
1. Migration failure rate >5%
2. App crash rate increases >1%
3. Query performance degrades >50%
4. Data integrity checks fail

**Rollback Procedure:**
```dart
// Detect migration failure
try {
  await runMigration31();
} catch (e) {
  _logger.critical('Migration 31 failed: $e');

  // Attempt rollback
  await rollbackMigration31();

  // Restore from backup
  await restoreDatabaseBackup();

  // Alert developers
  Sentry.captureException(e, level: SentryLevel.fatal);

  // Show user-friendly error
  throw MigrationFailedException('Database update failed. Please contact support.');
}
```

---

## Rollback Procedures

### Scenario 1: Migration Fails Mid-Flight

**Detection:**
- Exception thrown during migration
- Database in inconsistent state
- App crashes on startup

**Recovery:**
```dart
// Pre-migration backup
final backupPath = await createDatabaseBackup();

try {
  await runMigration();
} catch (e) {
  // Restore backup
  await restoreDatabaseBackup(backupPath);

  // Notify user
  showErrorDialog('Database update failed. Previous state restored.');
}
```

### Scenario 2: Performance Degradation Post-Migration

**Detection:**
- Query times >2x baseline
- User complaints about slow performance
- Sentry alerts firing

**Recovery:**
```sql
-- Drop problematic indexes
DROP INDEX idx_local_notes_user_deleted_updated;

-- Rebuild with correct parameters
CREATE INDEX idx_local_notes_user_deleted_updated
  ON local_notes(user_id, deleted, updated_at DESC);

-- Run ANALYZE to update query planner statistics
ANALYZE;
```

### Scenario 3: Data Integrity Issues

**Detection:**
- NULL userId values found
- Orphaned records detected
- Cross-user data leakage reported

**Recovery:**
```sql
-- Identify problematic records
SELECT * FROM note_tasks WHERE user_id IS NULL;

-- Option A: Delete orphaned records
DELETE FROM note_tasks WHERE user_id IS NULL;

-- Option B: Attempt recovery
UPDATE note_tasks
SET user_id = (SELECT user_id FROM local_notes WHERE id = note_tasks.note_id)
WHERE user_id IS NULL;
```

---

## Success Criteria

### Phase 1 (P1) Success Metrics
- ✅ All repository tests pass (0 failures)
- ✅ User A/B isolation verified (Scenario 1 passes)
- ✅ PendingOps leak fixed (Scenario 4 passes)
- ✅ Task privacy secured (Scenario 2 passes)
- ✅ Query performance meets targets (<50ms)

### Phase 2 (P2) Success Metrics
- ✅ All 12 tables have userId column
- ✅ No NULL userId values in database
- ✅ All queries filtered by userId
- ✅ clearAll() performance <2s for 100k records

### Phase 3 (P3) Success Metrics
- ✅ All indexes created successfully
- ✅ Query performance 30-50% faster than baseline
- ✅ FTS search <10ms
- ✅ No N+1 query patterns detected

### Production Success Metrics
- ✅ Zero security incidents reported
- ✅ Zero data loss incidents
- ✅ User satisfaction maintained (>95%)
- ✅ App crash rate unchanged (<1%)
- ✅ Performance improvements visible to users

---

## Risk Mitigation Summary

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Migration data loss | Low | CRITICAL | Pre-migration backup + validation queries |
| Performance degradation | Medium | HIGH | Indexes before filtering + benchmarking |
| Sync queue corruption | Low | HIGH | Clear queue strategy (transient data) |
| Orphaned data accumulation | Medium | MEDIUM | Cleanup queries in migration |
| Cross-user data leakage | High (before fix) | CRITICAL | Comprehensive testing (Scenarios 1,4,5,7) |
| Production rollback needed | Low | HIGH | Phased rollout + automated monitoring |

---

## Final Checklist

### Pre-Implementation
- [ ] Review all 3 deliverables (Safety Plan, Optimization Guide, Testing Scenarios)
- [ ] Set up test environment with multiple users
- [ ] Create database backups
- [ ] Configure Sentry monitoring
- [ ] Prepare rollback procedures

### Implementation (P1)
- [ ] Run migration 30 (PendingOps userId)
- [ ] Run migration 31 (NoteTasks userId)
- [ ] Update repository queries
- [ ] Run automated test suite
- [ ] Benchmark performance

### Implementation (P2)
- [ ] Run migrations 32-36 (remaining tables)
- [ ] Run migration 37 (non-nullable userId)
- [ ] Update all remaining queries
- [ ] Verify data integrity
- [ ] Test clearAll() performance

### Implementation (P3)
- [ ] Create all composite indexes
- [ ] Implement FTS auxiliary table
- [ ] Benchmark query performance
- [ ] Verify 30-50% improvement
- [ ] Test on low-end devices

### Deployment
- [ ] Deploy to staging
- [ ] Run production-like tests
- [ ] Phased rollout (5% → 25% → 100%)
- [ ] Monitor metrics continuously
- [ ] Document lessons learned

---

## References

- [DATABASE_MIGRATION_SAFETY_PLAN.md](./DATABASE_MIGRATION_SAFETY_PLAN.md) - Complete migration SQL and rollback procedures
- [QUERY_OPTIMIZATION_GUIDE.md](./QUERY_OPTIMIZATION_GUIDE.md) - Index strategy and performance patterns
- [DATABASE_TESTING_SCENARIOS.md](./DATABASE_TESTING_SCENARIOS.md) - Comprehensive test scenarios with edge cases
- [P0 Security Implementation](./P0_SECURITY_IMPLEMENTATION.md) - Previously completed clearAll() fixes

**Next Steps:**
1. Review and approve this implementation plan
2. Begin P1 implementation (Week 1)
3. Run automated test suite
4. Deploy to staging environment
5. Production rollout (phased)
