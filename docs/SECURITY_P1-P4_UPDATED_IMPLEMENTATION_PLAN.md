# Updated Security Implementation Plan - P1-P4 Phases

**Generated**: 2025-10-24
**Status**: REVISED - Includes critical gaps and staged rollout
**Timeline**: 4-6 weeks total (was 3-4 weeks)

---

## 🔴 PHASE 0.5: URGENT SECURITY PATCHES (NEW)

**Timeline**: 2-3 days IMMEDIATE
**Risk**: CRITICAL - Active vulnerabilities
**Breaking Changes**: LOW - Additive changes only

### Critical Gap #1: Attachments User Isolation

#### Step 1: Add userId to Attachments Table
```dart
// lib/data/local/app_db.dart - Add to Attachments class
TextColumn get userId => text()();

// Migration (version 30)
if (from < 30) {
  await m.addColumn(attachments, attachments.userId);

  // Backfill userId from parent notes
  await customStatement('''
    UPDATE attachments SET user_id = (
      SELECT user_id FROM local_notes
      WHERE local_notes.id = attachments.note_id
      LIMIT 1
    )
  ''');

  // Add index for performance
  await customStatement(
    'CREATE INDEX idx_attachments_user_id ON attachments(user_id)'
  );
}
```

#### Step 2: Update Attachment Repository
```dart
// lib/infrastructure/repositories/attachment_repository.dart
Future<List<Attachment>> getAttachmentsForNote(String noteId) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];

  return await (db.select(db.attachments)
    ..where((a) => a.noteId.equals(noteId))
    ..where((a) => a.userId.equals(userId))) // ADD THIS
    .get();
}
```

### Critical Gap #2: FTS Index User Scoping

#### Step 1: Rebuild FTS with userId
```sql
-- Migration (version 31)
-- Drop old FTS
DROP TABLE IF EXISTS fts_notes;

-- Create new FTS with user_id
CREATE VIRTUAL TABLE fts_notes USING fts5(
  id UNINDEXED,
  user_id UNINDEXED,  -- NEW
  title,
  body,
  folder_path UNINDEXED
);

-- Rebuild index with user_id
INSERT INTO fts_notes (id, user_id, title, body, folder_path)
SELECT
  n.id,
  n.user_id,  -- NEW
  n.title_encrypted,  -- Will be decrypted in app layer
  n.body_encrypted,    -- Will be decrypted in app layer
  f.path
FROM local_notes n
LEFT JOIN note_folders nf ON nf.note_id = n.id
LEFT JOIN local_folders f ON f.id = nf.folder_id
WHERE n.deleted = 0;
```

#### Step 2: Update Search Queries
```dart
// lib/search/search_service.dart
Future<List<Note>> searchNotes(String query) async {
  final userId = _auth.currentUser?.id;
  if (userId == null) return [];

  final results = await db.customSelect('''
    SELECT DISTINCT n.*
    FROM fts_notes fts
    JOIN local_notes n ON n.id = fts.id
    WHERE fts MATCH ?
    AND fts.user_id = ?  -- NEW: Filter by user
    AND n.deleted = 0
    ORDER BY rank
  ''', variables: [
    Variable.withString(query),
    Variable.withString(userId),
  ]).get();

  return _mapToNotes(results);
}
```

### Critical Gap #3: Reminders Persistence

#### Step 1: Create Reminders Table
```dart
// lib/data/local/app_db.dart
@DataClassName('Reminder')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // CRITICAL
  TextColumn get entityId => text()();
  TextColumn get entityType => text()(); // 'note' or 'task'
  TextColumn get title => text()();
  TextColumn get message => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get frequency => text()(); // 'once', 'daily', 'weekly', etc
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### Step 2: Update Reminder Service
```dart
// lib/services/unified_reminder_service.dart
Future<void> _saveReminder(UnifiedReminder reminder) async {
  final userId = _auth.currentUser?.id;
  if (userId == null) throw StateError('No authenticated user');

  await _db.into(_db.reminders).insert(
    RemindersCompanion.insert(
      id: reminder.id,
      userId: userId, // CRITICAL
      entityId: reminder.entityId,
      entityType: reminder.type.toString(),
      title: reminder.title,
      message: reminder.message,
      scheduledAt: reminder.scheduledAt,
      frequency: reminder.frequency.toString(),
      metadata: jsonEncode(reminder.metadata),
    ),
  );
}

Future<List<UnifiedReminder>> _loadReminders() async {
  final userId = _auth.currentUser?.id;
  if (userId == null) return [];

  final dbReminders = await (_db.select(_db.reminders)
    ..where((r) => r.userId.equals(userId))  // CRITICAL
    ..where((r) => r.isActive.equals(true)))
    .get();

  return dbReminders.map(_mapToUnifiedReminder).toList();
}
```

### Critical Gap #4: Analytics User Scoping

```dart
// lib/services/task_analytics_service.dart
Future<TaskAnalytics> getAnalytics() async {
  final userId = _auth.currentUser?.id;
  if (userId == null) return TaskAnalytics.empty();

  // Add userId filter to all queries
  final tasks = await (_db.select(_db.noteTasks)
    ..where((t) => t.userId.equals(userId)))  // After P1
    .get();

  return _calculateAnalytics(tasks);
}
```

---

## 🟡 PHASE 1: ENHANCED REPOSITORY FILTERING

**Timeline**: 5-7 days (was 8 hours)
**Risk**: MEDIUM - Performance impact
**Breaking Changes**: MEDIUM - Query modifications

### Implementation with Feature Flags

#### Step 1: Add Feature Flag System
```dart
// lib/core/security_flags.dart
class SecurityFlags {
  static bool enforceUserIdFiltering = false; // Start disabled
  static bool enableQueryPerformanceMonitoring = true;
  static bool useOptimizedIndexes = false;

  static Future<void> updateFromRemoteConfig() async {
    // Fetch from Firebase Remote Config
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();

    enforceUserIdFiltering = remoteConfig.getBool('enforce_user_id_filtering');
    useOptimizedIndexes = remoteConfig.getBool('use_optimized_indexes');
  }
}
```

#### Step 2: Repository Changes with Gradual Rollout
```dart
// lib/infrastructure/repositories/notes_core_repository.dart
Future<List<domain.Note>> getPinnedNotes() async {
  // Performance monitoring
  final stopwatch = Stopwatch()..start();

  try {
    SelectionCreator<LocalNotes, LocalNote> query;

    if (SecurityFlags.enforceUserIdFiltering) {
      // NEW: With userId filtering
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('No authenticated user for getPinnedNotes');
        return const <domain.Note>[];
      }

      query = db.select(db.localNotes)
        ..where((n) => n.deleted.equals(false))
        ..where((n) => n.isPinned.equals(true))
        ..where((n) => n.userId.equals(userId)); // NEW
    } else {
      // LEGACY: Without userId filtering (for rollback)
      query = db.select(db.localNotes)
        ..where((n) => n.deleted.equals(false))
        ..where((n) => n.isPinned.equals(true));
    }

    final localNotes = await query.get();
    return await _hydrateDomainNotes(localNotes);

  } finally {
    stopwatch.stop();

    if (SecurityFlags.enableQueryPerformanceMonitoring) {
      _monitorQueryPerformance('getPinnedNotes', stopwatch.elapsedMilliseconds);
    }
  }
}

void _monitorQueryPerformance(String method, int milliseconds) {
  if (milliseconds > 100) {
    _logger.warning('Slow query detected: $method took ${milliseconds}ms');

    Sentry.captureMessage(
      'Slow query: $method',
      level: SentryLevel.warning,
      withScope: (scope) {
        scope.setTag('query', method);
        scope.setExtra('duration_ms', milliseconds);
        scope.setExtra('userId_filtering', SecurityFlags.enforceUserIdFiltering);
      },
    );
  }
}
```

#### Step 3: Add Performance Indexes (CRITICAL)
```sql
-- Migration (version 32)
-- Composite indexes for common query patterns
CREATE INDEX idx_notes_user_deleted_pinned
  ON local_notes(user_id, deleted, is_pinned);

CREATE INDEX idx_notes_user_deleted_updated
  ON local_notes(user_id, deleted, updated_at DESC);

CREATE INDEX idx_folders_user_parent
  ON local_folders(user_id, parent_id);

CREATE INDEX idx_tasks_user_status
  ON note_tasks(user_id, status); -- After userId added

-- Analyze tables for query optimizer
ANALYZE local_notes;
ANALYZE local_folders;
ANALYZE note_tasks;
```

### NoteTasks userId Addition

#### Step 1: Schema Change with Safe Migration
```dart
// lib/data/local/app_db.dart
class NoteTasks extends Table {
  // ... existing columns ...
  TextColumn get userId => text().nullable()(); // Start nullable for safety
}

// Migration (version 33)
if (from < 33) {
  // Add column as nullable first
  await m.addColumn(noteTasks, noteTasks.userId);

  // Backfill in batches to avoid timeout
  await customStatement('''
    UPDATE note_tasks
    SET user_id = (
      SELECT user_id FROM local_notes
      WHERE local_notes.id = note_tasks.note_id
      LIMIT 1
    )
    WHERE user_id IS NULL
    AND note_id IN (
      SELECT id FROM local_notes WHERE user_id IS NOT NULL
    )
  ''');

  // Log orphaned tasks for investigation
  final orphaned = await customSelect('''
    SELECT COUNT(*) as count
    FROM note_tasks
    WHERE user_id IS NULL
  ''').getSingle();

  if (orphaned.read<int>('count') > 0) {
    _logger.warning('Found ${orphaned.read<int>('count')} orphaned tasks during migration');
  }
}
```

#### Step 2: Update Task Queries Safely
```dart
// lib/infrastructure/repositories/task_core_repository.dart
Future<List<domain.Task>> getTasksForNote(String noteId) async {
  try {
    SelectionCreator<NoteTasks, NoteTask> query;

    if (SecurityFlags.enforceUserIdFiltering) {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      query = db.select(db.noteTasks)
        ..where((t) => t.noteId.equals(noteId))
        ..where((t) => t.userId.equals(userId)); // NEW
    } else {
      // Legacy query without userId filter
      query = db.select(db.noteTasks)
        ..where((t) => t.noteId.equals(noteId));
    }

    final localTasks = await query.get();
    return await _decryptTasks(localTasks);

  } catch (e, stack) {
    _logger.error('Failed to get tasks for note', error: e);
    return const <domain.Task>[];
  }
}
```

### Rollout Strategy

```dart
// Gradual rollout controller
class P1RolloutController {
  static const ROLLOUT_PHASES = {
    'phase1': 0.01,  // 1% of users
    'phase2': 0.10,  // 10% of users
    'phase3': 0.50,  // 50% of users
    'phase4': 1.00,  // 100% of users
  };

  static bool isEnabledForUser(String userId) {
    // Use consistent hashing for stable assignment
    final hash = userId.hashCode.abs();
    final bucket = (hash % 100) / 100.0;

    final currentPhase = RemoteConfig.getString('p1_rollout_phase');
    final threshold = ROLLOUT_PHASES[currentPhase] ?? 0.0;

    return bucket <= threshold;
  }
}
```

---

## 🟡 PHASE 2: STAGED NON-NULLABLE MIGRATION

**Timeline**: 2-3 weeks (was 1 week)
**Risk**: HIGH - Data migration required
**Breaking Changes**: HIGH - Schema changes

### Week 1: Deploy with Feature Flag Disabled

```dart
// lib/core/migration_flags.dart
class MigrationFlags {
  // Start with everything disabled
  static bool enforceNonNullableUserId = false;
  static bool validateUserIdOnWrite = true; // Monitoring only
  static bool blockNullUserIdWrites = false;
}
```

### Week 2: Enable Validation and Monitoring

```dart
// lib/data/local/app_db.dart
Future<void> insertNote(LocalNotesCompanion note) async {
  // Validation without blocking
  if (MigrationFlags.validateUserIdOnWrite) {
    if (note.userId.value == null) {
      _logger.warning('Attempting to insert note without userId');

      if (MigrationFlags.blockNullUserIdWrites) {
        throw StateError('userId is required for all notes');
      }

      // Auto-fill userId for transition period
      final currentUserId = _auth.currentUser?.id;
      if (currentUserId != null) {
        note = note.copyWith(userId: Value(currentUserId));
      }
    }
  }

  await into(localNotes).insert(note);
}
```

### Week 3: Gradual Schema Enforcement

```dart
// Phased migration approach
class P2MigrationPhases {
  static Future<void> phase1_monitoring() async {
    // Log all null userId occurrences
    final nullCount = await db.customSelect('''
      SELECT COUNT(*) as count
      FROM local_notes
      WHERE user_id IS NULL
    ''').getSingle();

    Analytics.track('p2_migration_nulls', {
      'count': nullCount.read<int>('count'),
      'table': 'local_notes',
    });
  }

  static Future<void> phase2_backfill() async {
    // Backfill with current user
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    await db.customStatement('''
      UPDATE local_notes
      SET user_id = ?
      WHERE user_id IS NULL
      AND id IN (
        SELECT id FROM local_notes
        WHERE user_id IS NULL
        LIMIT 100  -- Process in batches
      )
    ''', [userId]);
  }

  static Future<void> phase3_enforce() async {
    // Only after all data migrated
    await db.customStatement('''
      ALTER TABLE local_notes
      ALTER COLUMN user_id SET NOT NULL
    ''');
  }
}
```

### Encryption Format Migration (Safe Approach)

```dart
// lib/services/encryption_migration_service.dart
class EncryptionFormatMigration {
  static bool isLegacyFormat(String encrypted) {
    // Legacy: Raw JSON
    if (encrypted.startsWith('{') || encrypted.startsWith('[')) {
      return true;
    }
    // Modern: Base64
    try {
      base64.decode(encrypted);
      return false;
    } catch (_) {
      // Unknown format
      return true;
    }
  }

  static Future<void> migrateLazyOnAccess(LocalNote note) async {
    // Only migrate when user accesses the note
    if (!isLegacyFormat(note.titleEncrypted)) {
      return; // Already modern format
    }

    try {
      // Extract from legacy format
      final legacy = jsonDecode(note.titleEncrypted);
      final plainTitle = legacy['title'] ?? '';

      // Re-encrypt in modern format
      final encrypted = await crypto.encryptStringForNote(
        userId: note.userId!,
        noteId: note.id,
        text: plainTitle,
      );

      // Update database
      await db.update(db.localNotes).replace(
        note.copyWith(
          titleEncrypted: base64.encode(encrypted),
          encryptionVersion: 2, // Mark as migrated
        ),
      );

      _logger.info('Migrated note ${note.id} to modern encryption format');

    } catch (e) {
      _logger.error('Failed to migrate note ${note.id}', error: e);
      // Don't break user experience - show as [Encrypted]
    }
  }
}
```

---

## 🟢 PHASE 3: ARCHITECTURE IMPROVEMENTS

**Timeline**: 4 weeks (as planned)
**Risk**: LOW - Refactoring only
**Breaking Changes**: LOW - Internal changes

### No changes to original P3 plan
The architectural improvements remain valid and low-risk.

---

## Rollback Procedures

### P0.5 Rollback (Urgent Patches)
```bash
# Feature flag disable
firebase remoteconfig:set security.enforce_attachments false
firebase remoteconfig:set security.enforce_fts false
firebase remoteconfig:set security.enforce_reminders false
```

### P1 Rollback (Repository Filtering)
```dart
// Immediate rollback via feature flag
SecurityFlags.enforceUserIdFiltering = false;

// Remove indexes if causing issues (rare)
DROP INDEX idx_notes_user_deleted_pinned;
DROP INDEX idx_notes_user_deleted_updated;
```

### P2 Rollback (Non-nullable)
```sql
-- Make nullable again
ALTER TABLE local_notes
ALTER COLUMN user_id DROP NOT NULL;

-- Revert to version 31
flutter pub run drift_dev schema revert 31
```

---

## Monitoring Dashboard

### Key Metrics to Track

```dart
class SecurityMetrics {
  // Real-time monitoring
  static void track() {
    // P0 Metrics
    trackDataLeakageAttempts();
    trackKeychainCollisions();
    trackProviderInvalidations();

    // P1 Metrics
    trackQueryPerformance();
    trackUserIdFilteringCoverage();

    // P2 Metrics
    trackNullUserIdOccurrences();
    trackMigrationProgress();

    // P4 Metrics
    trackAttachmentIsolation();
    trackSearchIsolation();
    trackReminderIsolation();
  }
}
```

### Alert Configuration
```yaml
alerts:
  - name: data_leakage_detected
    condition: error.message contains "wrong user_id"
    severity: CRITICAL
    action: page_oncall

  - name: slow_query_detected
    condition: query.duration > 500ms
    severity: WARNING
    action: log_and_notify

  - name: migration_failure
    condition: migration.error_rate > 0.01
    severity: HIGH
    action: rollback_and_alert
```

---

## Success Criteria

### Phase 0.5 (Urgent Patches)
- [ ] Attachments table has userId column
- [ ] FTS rebuilt with user_id
- [ ] Reminders persisted with userId
- [ ] Analytics scoped by user
- [ ] Zero security test failures

### Phase 1 (Enhanced)
- [ ] All repositories filter by userId
- [ ] NoteTasks has userId column
- [ ] Performance degradation < 20%
- [ ] Feature flags operational
- [ ] Monitoring in place

### Phase 2 (Staged)
- [ ] All userId columns non-nullable
- [ ] Legacy data migrated
- [ ] Encryption format unified
- [ ] Zero data loss
- [ ] Rollback tested

### Phase 3 (Architecture)
- [ ] Unified services created
- [ ] Security middleware operational
- [ ] Automated tests running
- [ ] Documentation complete

---

This updated plan addresses all critical security gaps, implements staged rollouts for safety, and includes comprehensive monitoring and rollback procedures.