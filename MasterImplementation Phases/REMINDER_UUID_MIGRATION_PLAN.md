# Reminder ID Migration Plan: INTEGER → UUID
**Created:** 2025-11-18
**Status:** Planning
**Estimated Duration:** 3-4 weeks
**Risk Level:** HIGH

---

## Executive Summary

**Goal:** Migrate local NoteReminders table from INTEGER IDs to TEXT (UUID) IDs to match Supabase schema.

**Why:** Current INT→UUID mismatch breaks reminder sync completely. Local creates ID `1`, remote expects UUID format.

**Scope:**
- 36 files requiring changes
- 150+ code locations
- 120+ test modifications
- 40+ method signatures
- 1 foreign key relationship (NoteTasks.reminder_id)

---

## Phase 1: Foundation & Preparation (Days 1-3)

###  1.1 Backup & Safety
- [ ] Create full database backup
- [ ] Document current reminder count
- [ ] Export all existing reminders to JSON
- [ ] Create rollback SQL scripts
- [ ] Set up test environment

### 1.2 Schema Analysis
- [ ] Document all foreign key relationships
- [ ] Identify cascade rules
- [ ] Map all INT ID usages
- [ ] Create type mapping strategy

### 1.3 Test Infrastructure
- [ ] Create UUID test utilities
- [ ] Build migration test suite
- [ ] Set up integration test environment
- [ ] Prepare data validation scripts

**Deliverables:**
- Backup verified
- Test infrastructure ready
- Rollback plan documented

---

## Phase 2: Database Schema Migration (Days 4-7)

### 2.1 Local Schema Changes

**File:** `lib/data/local/app_db.dart`

**Changes Required:**

1. **Update NoteReminders table (lines 125-169)**
```dart
// BEFORE:
IntColumn get id => integer().autoIncrement()(); // Primary key

// AFTER:
TextColumn get id => text().clientDefault(() => Uuid().v4())(); // Primary key UUID
```

2. **Update NoteTasks foreign key (line 227)**
```dart
// BEFORE:
IntColumn get reminderId => integer().nullable()();

// AFTER:
TextColumn get reminderId => text().nullable()();
```

3. **Update schema version (line 585)**
```dart
// BEFORE:
int get schemaVersion => 40;

// AFTER:
int get schemaVersion => 41; // Reminder UUID migration
```

### 2.2 Migration Logic

**File:** `lib/data/local/app_db.dart` (lines 588-640, onUpgrade section)

Add migration from schema 40 → 41:

```dart
if (from == 40) {
  // Migration 41: Convert reminder IDs from INTEGER to TEXT (UUID)
  debugPrint('[Migration 41] Converting reminder IDs to UUID...');

  // Step 1: Create new table with UUID IDs
  await customStatement('''
    CREATE TABLE note_reminders_new (
      id TEXT PRIMARY KEY NOT NULL,
      note_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      body TEXT NOT NULL DEFAULT '',
      type INTEGER NOT NULL,
      remind_at INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      latitude REAL,
      longitude REAL,
      radius REAL,
      location_name TEXT,
      recurrence_pattern INTEGER NOT NULL DEFAULT 0,
      recurrence_interval INTEGER NOT NULL DEFAULT 1,
      recurrence_end_date INTEGER,
      snoozed_until INTEGER,
      snooze_count INTEGER NOT NULL DEFAULT 0,
      notification_title TEXT,
      notification_body TEXT,
      notification_image TEXT,
      time_zone TEXT,
      created_at INTEGER NOT NULL,
      last_triggered INTEGER,
      trigger_count INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Step 2: Migrate data with UUID generation
  final reminders = await customSelect('SELECT * FROM note_reminders').get();
  debugPrint('[Migration 41] Migrating ${reminders.length} reminders...');

  final uuidMap = <int, String>{}; // Maps old INT ID → new UUID

  for (final reminder in reminders) {
    final oldId = reminder.read<int>('id');
    final newId = Uuid().v4();
    uuidMap[oldId] = newId;

    await customStatement(
      '''
      INSERT INTO note_reminders_new (
        id, note_id, user_id, title, body, type, remind_at, is_active,
        latitude, longitude, radius, location_name, recurrence_pattern,
        recurrence_interval, recurrence_end_date, snoozed_until, snooze_count,
        notification_title, notification_body, notification_image, time_zone,
        created_at, last_triggered, trigger_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        newId,
        reminder.read<String>('note_id'),
        reminder.read<String>('user_id'),
        reminder.read<String>('title'),
        reminder.read<String>('body'),
        reminder.read<int>('type'),
        reminder.readNullable<int>('remind_at'),
        reminder.read<int>('is_active'),
        reminder.readNullable<double>('latitude'),
        reminder.readNullable<double>('longitude'),
        reminder.readNullable<double>('radius'),
        reminder.readNullable<String>('location_name'),
        reminder.read<int>('recurrence_pattern'),
        reminder.read<int>('recurrence_interval'),
        reminder.readNullable<int>('recurrence_end_date'),
        reminder.readNullable<int>('snoozed_until'),
        reminder.read<int>('snooze_count'),
        reminder.readNullable<String>('notification_title'),
        reminder.readNullable<String>('notification_body'),
        reminder.readNullable<String>('notification_image'),
        reminder.readNullable<String>('time_zone'),
        reminder.read<int>('created_at'),
        reminder.readNullable<int>('last_triggered'),
        reminder.read<int>('trigger_count'),
      ],
    );
  }

  // Step 3: Update NoteTasks foreign key references
  final tasks = await customSelect('SELECT * FROM note_tasks WHERE reminder_id IS NOT NULL').get();
  debugPrint('[Migration 41] Updating ${tasks.length} task reminder references...');

  for (final task in tasks) {
    final oldReminderId = task.read<int>('reminder_id');
    final newReminderId = uuidMap[oldReminderId];

    if (newReminderId != null) {
      await customStatement(
        'UPDATE note_tasks SET reminder_id = ? WHERE id = ?',
        [newReminderId, task.read<String>('id')],
      );
    } else {
      // Orphaned reminder reference - set to null
      await customStatement(
        'UPDATE note_tasks SET reminder_id = NULL WHERE id = ?',
        [task.read<String>('id')],
      );
      debugPrint('[Migration 41] WARNING: Task ${task.read<String>('id')} had invalid reminder_id=$oldReminderId');
    }
  }

  // Step 4: Drop old table and rename new one
  await customStatement('DROP TABLE note_reminders');
  await customStatement('ALTER TABLE note_reminders_new RENAME TO note_reminders');

  // Step 5: Recreate indexes
  await customStatement('CREATE INDEX idx_note_reminders_note_user ON note_reminders(note_id, user_id)');
  await customStatement('CREATE INDEX idx_note_reminders_active ON note_reminders(user_id, is_active)');

  debugPrint('[Migration 41] ✅ Reminder UUID migration complete');
  debugPrint('[Migration 41] Migrated ${reminders.length} reminders, updated ${tasks.length} task references');

  // Step 6: Force re-sync all reminders (old IDs invalid)
  await customStatement('DELETE FROM pending_ops WHERE kind = "upsert_reminder" OR kind = "delete_reminder"');

  // Enqueue all reminders for fresh upload with new UUIDs
  for (final entry in uuidMap.entries) {
    await customStatement(
      '''
      INSERT INTO pending_ops (user_id, entity_id, kind, payload, created_at)
      SELECT user_id, ?, 'upsert_reminder', '{}', ?
      FROM note_reminders
      WHERE id = ?
      ''',
      [entry.value, DateTime.now().millisecondsSinceEpoch ~/ 1000, entry.value],
    );
  }
}
```

### 2.3 Foreign Key Updates

**File:** `lib/data/local/app_db.dart` (line 227)

```dart
// Update NoteTasks.reminderId type
TextColumn get reminderId => text().nullable()(); // Was: integer()
```

**Deliverables:**
- Schema updated to version 41
- Migration script tested
- Foreign keys updated
- Data integrity verified

---

## Phase 3: Code Updates - Database Layer (Days 8-10)

### 3.1 AppDb Methods

**File:** `lib/data/local/app_db.dart`

**Methods to Update:**

1. **getReminderById** (lines 2059-2061)
```dart
// BEFORE:
Future<NoteReminder?> getReminderById(int id, String userId)

// AFTER:
Future<NoteReminder?> getReminderById(String id, String userId)
```

2. **createReminder** (lines 2064-2065)
```dart
// BEFORE:
Future<int> createReminder(NoteRemindersCompanion reminder)

// AFTER:
Future<String> createReminder(NoteRemindersCompanion reminder) {
  // Generate UUID if not provided
  final companion = reminder.id.present
    ? reminder
    : reminder.copyWith(id: Value(Uuid().v4()));
  return into(noteReminders).insert(companion);
}
```

3. **updateReminder** (lines 2080-2085)
```dart
// Parameter type changes from int → String
Future<void> updateReminder(String reminderId, String userId, Insertable<NoteReminder> update)
```

4. **deleteReminder** (line 2087)
```dart
// Parameter type changes from int → String
Future<void> deleteReminder(String reminderId, String userId)
```

5. **getRemindersByNote** (lines 2089-2090)
```dart
// Return type stays Stream<List<NoteReminder>>
// No parameter changes needed
```

**Deliverables:**
- All AppDb reminder methods updated
- UUID generation added
- Parameter types changed

---

## Phase 4: Code Updates - Service Layer (Days 11-14)

### 4.1 BaseReminderService

**File:** `lib/services/reminders/base_reminder_service.dart`

**Changes Required:**

1. **createReminderInDb** (lines 203-225)
```dart
// BEFORE:
Future<int?> createReminderInDb({required NoteRemindersCompanion companion})

// AFTER:
Future<String?> createReminderInDb({required NoteRemindersCompanion companion})
```

2. **updateReminderInDb** (lines 227-236)
```dart
// BEFORE:
Future<void> updateReminderInDb({required int reminderId, ...})

// AFTER:
Future<void> updateReminderInDb({required String reminderId, ...})
```

3. **deleteReminderFromDb** (lines 237-245)
```dart
// BEFORE:
Future<void> deleteReminderFromDb(int reminderId)

// AFTER:
Future<void> deleteReminderFromDb(String reminderId)
```

### 4.2 ReminderCoordinator

**File:** `lib/services/reminders/reminder_coordinator.dart`

**Changes Required:**

1. **createTimeReminder** (line 170)
```dart
// BEFORE:
Future<int?> createTimeReminder({...})

// AFTER:
Future<String?> createTimeReminder({...})
```

2. **createLocationReminder** (line 319)
```dart
// BEFORE:
Future<int?> createLocationReminder({...})

// AFTER:
Future<String?> createLocationReminder({...})
```

3. **cancelReminder** (line 531)
```dart
// BEFORE:
Future<void> cancelReminder(int reminderId)

// AFTER:
Future<void> cancelReminder(String reminderId)
```

4. **snoozeReminder** (line 582)
```dart
// BEFORE:
Future<void> snoozeReminder(int reminderId, ...)

// AFTER:
Future<void> snoozeReminder(String reminderId, ...)
```

### 4.3 Other Services

**Files to Update:**
- `lib/services/reminders/recurring_reminder_service.dart` (15 locations)
- `lib/services/reminders/geofence_reminder_service.dart` (8 locations)
- `lib/services/reminders/snooze_reminder_service.dart` (5 locations)
- `lib/services/advanced_reminder_service.dart` (12 locations)

**Pattern:** Change all `int reminderId` → `String reminderId`

**Deliverables:**
- All service methods updated
- Return types changed
- Parameter types changed

---

## Phase 5: Code Updates - Sync Layer (Days 15-17)

### 5.1 UnifiedSyncService

**File:** `lib/services/unified_sync_service.dart`

**Critical Changes:**

1. **_parseReminderId** (lines 1974-2011)
```dart
// BEFORE:
int? _parseReminderId(dynamic value) {
  if (value is int) return value > 0 ? value : null;
  if (value is String) {
    final parsed = int.tryParse(value);
    return (parsed != null && parsed > 0) ? parsed : null;
  }
  return null;
}

// AFTER:
String? _parseReminderId(dynamic value) {
  if (value == null) {
    _logger.error('Reminder ID is null');
    return null;
  }

  if (value is String) {
    // Validate UUID format
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (uuidPattern.hasMatch(value)) {
      return value;
    }
    _logger.error('Invalid UUID format: $value');
    return null;
  }

  _logger.error('Reminder ID must be UUID string, got: ${value.runtimeType}');
  return null;
}
```

2. **_deserializeReminder** (lines 1914-1958)
```dart
// Change line 1923:
// BEFORE:
final id = _parseReminderId(data['id']);

// AFTER (no type change needed, but validation improved):
final id = _parseReminderId(data['id']); // Now returns String? instead of int?
```

3. **_serializeReminder** (lines 1879-1907)
```dart
// No changes needed - already sends ID as-is
// Line 1881: 'id': reminder.id, (now String instead of int)
```

**Deliverables:**
- Sync code handles UUIDs
- UUID validation added
- All type conversions removed

---

## Phase 6: Code Updates - UI & Bridge (Days 18-20)

### 6.1 TaskReminderBridge

**File:** `lib/services/task_reminder_bridge.dart`

**Changes Required:**

1. **linkTaskToReminder** (line 171)
```dart
// BEFORE:
Future<void> linkTaskToReminder({required String taskId, required int reminderId})

// AFTER:
Future<void> linkTaskToReminder({required String taskId, required String reminderId})
```

2. **unlinkTaskReminder** (line 196)
```dart
// BEFORE:
Future<void> unlinkTaskReminder(String taskId)

// AFTER (no parameter change needed):
Future<void> unlinkTaskReminder(String taskId)
```

### 6.2 UI Components

**File:** `lib/ui/reminders_screen.dart`

**Changes Required:**
- Line 89: `int? selectedReminderId` → `String? selectedReminderId`
- Line 142: `onTap: (int id)` → `onTap: (String id)`
- All reminder ID displays (no visual change)

**Deliverables:**
- Bridge layer updated
- UI code updated
- No user-facing changes

---

## Phase 7: Test Updates (Days 21-24)

### 7.1 Test Files to Update (18 files)

**Pattern for all tests:**
```dart
// BEFORE:
final reminderId = 1;
final reminder = NoteRemindersCompanion(id: Value(1), ...);

// AFTER:
final reminderId = Uuid().v4();
final reminder = NoteRemindersCompanion(id: Value(Uuid().v4()), ...);
```

**Files:**
1. `test/services/base_reminder_service_test.dart` (25 changes)
2. `test/services/snooze_functionality_test.dart` (18 changes)
3. `test/security/reminder_coordinator_authorization_test.dart` (15 changes)
4. `test/security/task_reminder_authorization_test.dart` (12 changes)
5. `test/security/advanced_reminder_service_authorization_test.dart` (10 changes)
6. `test/services/task_reminder_linking_test.dart` (8 changes)
7. ... and 12 more files

### 7.2 Test Utilities

**Create:** `test/utils/uuid_test_helper.dart`
```dart
import 'package:uuid/uuid.dart';

class UuidTestHelper {
  static const _uuid = Uuid();
  static final _cache = <String, String>{};

  /// Get consistent UUID for testing (same input = same UUID)
  static String deterministicUuid(String seed) {
    return _cache.putIfAbsent(seed, () => _uuid.v5(Uuid.NAMESPACE_OID, seed));
  }

  /// Generate new random UUID
  static String randomUuid() => _uuid.v4();

  /// Validate UUID format
  static bool isValidUuid(String? value) {
    if (value == null) return false;
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return pattern.hasMatch(value);
  }
}
```

**Deliverables:**
- All 120+ test assertions updated
- Test utilities created
- All tests passing

---

## Phase 8: Integration Testing & Validation (Days 25-28)

### 8.1 Integration Tests

**Create:** `test/integration/reminder_uuid_migration_test.dart`

```dart
void main() {
  group('Reminder UUID Migration', () {
    test('Migration converts INT IDs to UUID', () async {
      // Create test DB with schema v40 (INT IDs)
      // Run migration to v41
      // Verify all IDs are valid UUIDs
      // Verify foreign keys updated
      // Verify data integrity
    });

    test('New reminders use UUID format', () async {
      // Create new reminder
      // Verify ID is UUID
      // Verify can query by UUID
    });

    test('Sync uploads UUID to backend', () async {
      // Create reminder locally
      // Trigger sync
      // Verify backend received UUID
      // Verify no type conversion errors
    });

    test('Sync downloads UUID from backend', () async {
      // Create reminder in Supabase with UUID
      // Trigger sync down
      // Verify local DB has UUID
      // Verify no parsing errors
    });
  });
}
```

### 8.2 Validation Checklist

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Migration tested on real data
- [ ] Rollback tested and verified
- [ ] Sync tested bidirectionally
- [ ] Performance benchmarked
- [ ] Memory usage checked
- [ ] No regression in task/note sync
- [ ] Foreign key constraints verified
- [ ] Data integrity confirmed

**Deliverables:**
- Integration test suite
- Validation report
- Performance metrics

---

## Rollback Plan

If critical issues discovered:

### Immediate Rollback (< 1 hour)
```bash
# 1. Restore database from backup
cp duru_notes_backup.db duru_notes.db

# 2. Revert code changes
git revert <migration-commit-hash>

# 3. Rebuild app
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Partial Rollback (Revert schema only)
```dart
// Add to migration strategy:
if (from == 41 && to == 40) {
  // Downgrade migration: UUID → INT
  // WARNING: Will lose any new reminders created with UUIDs
  await customStatement('DROP TABLE note_reminders');
  await customStatement('CREATE TABLE note_reminders (id INTEGER PRIMARY KEY AUTOINCREMENT, ...)');
  // Restore data from backup
}
```

---

## Risk Mitigation

### High Risks
1. **Data Loss during migration**
   - Mitigation: Full backup before each phase, incremental backups, JSON exports

2. **Sync breaks for existing users**
   - Mitigation: Feature flag to disable reminders, graceful degradation

3. **Type conversion errors in production**
   - Mitigation: Comprehensive validation, canary rollout, monitoring

### Medium Risks
1. **Performance degradation**
   - Mitigation: Benchmark before/after, optimize queries, add indexes

2. **Foreign key constraint violations**
   - Mitigation: Thorough FK validation, orphan cleanup scripts

---

## Success Criteria

### Phase Completion
- ✅ All tests pass (100% green)
- ✅ No regression in sync functionality
- ✅ Migration completes in < 5 seconds for 1000 reminders
- ✅ Zero data loss during migration
- ✅ All foreign keys valid
- ✅ UUID format validated
- ✅ Sync works bidirectionally
- ✅ No console errors during operation

### Final Validation
- ✅ Production deployment successful
- ✅ User acceptance testing passed
- ✅ Performance within acceptable range
- ✅ Monitoring shows no errors
- ✅ Documentation updated
- ✅ Team trained on new system

---

## Timeline Summary

| Phase | Duration | Key Activities |
|-------|----------|----------------|
| 1 | Days 1-3 | Backup, test infrastructure, prep |
| 2 | Days 4-7 | Database schema migration |
| 3 | Days 8-10 | Database layer code updates |
| 4 | Days 11-14 | Service layer code updates |
| 5 | Days 15-17 | Sync layer code updates |
| 6 | Days 18-20 | UI & bridge layer updates |
| 7 | Days 21-24 | Test updates & fixes |
| 8 | Days 25-28 | Integration testing & validation |

**Total: 28 days (4 weeks)**

---

## Next Steps

1. Review and approve this plan
2. Create backup of current database
3. Set up test environment
4. Begin Phase 1 (Foundation & Preparation)
5. Execute phases sequentially with validation gates

**Start Date:** TBD
**Target Completion:** 4 weeks from start
**Review Checkpoints:** End of each phase
