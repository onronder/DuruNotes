# CRITICAL IMPACT ANALYSIS: NoteReminders Table ID Column Change (INTEGER → TEXT UUID)

**Date:** November 18, 2025  
**Severity:** CRITICAL - Requires coordinated schema migration across local and remote databases  
**Affected Components:** Database schema, Reminder system, Sync operations, Tests  

---

## EXECUTIVE SUMMARY

**Current State:** 
- Remote (Supabase): `reminders` table uses `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- Local (Drift): `NoteReminders` table uses `id INTEGER PRIMARY KEY AUTOINCREMENT()`

**Problem:** There is a **CRITICAL MISMATCH** between remote and local databases. The local SQLite database uses INTEGER IDs while the remote Supabase database uses UUID. This creates:
1. Type conversion failures during sync operations
2. Integer overflow/underflow risks on large local IDs
3. ID parsing failures in sync code (expects INT, receives UUID)
4. Foreign key constraint breakage in NoteTasks table

---

## 1. REMINDER CREATION & ID GENERATION

### Current Implementation

**Local Database (Drift)**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 125-169)
- ID Type: `IntColumn get id => integer().autoIncrement()()`
- Auto-increment starts at 1, increments by 1
- ID generation is automatic and implicit

```dart
@DataClassName('NoteReminder')
class NoteReminders extends Table {
  IntColumn get id => integer().autoIncrement()(); // ← INTEGER AUTO-INCREMENT
  TextColumn get noteId => text()();
  TextColumn get userId => text()();
  // ... 40+ other fields
}
```

**Remote Database (Supabase)**
- File: `/Users/onronder/duru-notes/supabase/migrations/20250301000000_initial_baseline_schema.sql` (lines 294-328)
- ID Type: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- UUID generation handled by Supabase on insert

```sql
CREATE TABLE public.reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- ← UUID with server-side generation
  note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
  -- ... other fields
);
```

### ID Creation Methods

1. **BaseReminderService.createReminderInDb()** (lines 203-225)
   - Returns: `Future<int?>`
   - Calls: `db.createReminder(companion)` 
   - Line 207: `final reminderId = await db.createReminder(companion);`

2. **AppDb.createReminder()** (line 2064-2065)
   ```dart
   Future<int> createReminder(NoteRemindersCompanion reminder) =>
       into(noteReminders).insert(reminder);
   ```
   - Returns `int` from SQLite autoincrement
   - No explicit UUID generation

3. **Sync Code: _serializeReminder()** (lines 1879-1907)
   - Line 1881: `'id': reminder.id,` (sends INTEGER to remote)
   - Remote database ignores the `id` field on insert and generates its own UUID
   - **This creates ID mismatch!**

### Impact Assessment

**HIGH RISK** - ID generation mismatch:
- Local: INTEGER (1, 2, 3, ...) generates auto-incrementing numbers
- Remote: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) generates UUIDs
- Result: Every reminder sync creates a DIFFERENT ID locally vs remotely

---

## 2. REMINDER QUERIES & OPERATIONS

### Query Locations

**getReminderById()**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 2059-2061)
- Signature: `Future<NoteReminder?> getReminderById(int id, String userId)`
- Expects `int` parameter
- Used in 30+ locations across codebase

```dart
Future<NoteReminder?> getReminderById(int id, String userId) => (select(
  noteReminders,
)..where((r) => r.id.equals(id) & r.userId.equals(userId))).getSingleOrNull();
```

**Called From (10+ locations):**
1. Line 373: `TaskReminderBridge._snoozeTaskReminder()` - `await _db.getReminderById(task.reminderId!, userId)`
2. Line 415: `TaskReminderBridge.snoozeTaskReminder()` - `final updatedReminder = await _db.getReminderById(...)`
3. Line 44: `SnoozeReminderService.snoozeReminder()` - `await db.getReminderById(reminderId, userId)`
4. Line 165: `RecurringReminderService.getRemindersForNote()` - queries local reminders
5. Line 283: `GeofenceReminderService._triggerLocationReminder()` - `await db.getReminderById(...)`

**updateReminder()**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 2070-2076)
- Signature: `Future<void> updateReminder(int id, String userId, NoteRemindersCompanion updates)`
- Used in 15+ locations:
  - Line 290: `GeofenceReminderService._triggerLocationReminder()`
  - Line 81: `SnoozeReminderService.snoozeReminder()`
  - Line 416: `AdvancedReminderService.snoozeReminder()`
  - Multiple recurring reminder operations

**deleteReminderById()**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 2081-2083)
- Signature: `Future<void> deleteReminderById(int id, String userId)`
- Used in 8+ locations:
  - Line 311: `TaskReminderBridge.cancelTaskReminder()` 
  - Line 1230: `TaskReminderBridge.cleanupOrphanedReminders()`
  - Advanced reminder service deletion

### Integer-Specific Operations

**1. Notification ID Generation (Using hashCode)**
- File: `/Users/onronder/duru-notes/lib/services/unified_reminder_service.dart`
- Uses: `reminder.id.hashCode` for Android notification IDs (must be int)
- File: `/Users/onronder/duru-notes/lib/services/advanced_reminder_service.dart`
- Uses: `reminderId.hashCode.abs()` 

```dart
// These depend on integer ID for notification scheduling
await plugin.zonedSchedule(
  data.id,  // ← Must be int for Android notifications
  data.title,
  data.body,
  tzDate,
  details,
);
```

**2. ID Parsing with int.tryParse()**
- File: `/Users/onronder/duru-notes/lib/services/reminders/geofence_reminder_service.dart` (line 264)
  ```dart
  final reminderId = int.tryParse(reminderIdStr);
  ```
- File: `/Users/onronder/duru-notes/lib/services/task_reminder_bridge.dart` (line 179)
  ```dart
  final int? reminderId = reminderIdResult is int
      ? reminderIdResult
      : int.tryParse('$reminderIdResult');
  ```
- File: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart` (line 1157)
  ```dart
  final reminderId = int.tryParse(reminderIdRaw);
  ```

### Impact Assessment

**CRITICAL** - All these methods assume INTEGER IDs:
- **30+ method calls** expect `int` parameters
- **Geofence system** uses `int.tryParse()` for ID extraction
- **Notification scheduling** uses `.hashCode` which only works with integers
- **Sync code** explicitly expects `int` for `_parseReminderId()`

---

## 3. REMINDER ID REFERENCES & TYPE DECLARATIONS

### Primary ID Storage in Domain Models

**NoteTask Table**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 200-250)
- Line 227: `IntColumn get reminderId => integer().nullable();`
- Foreign key to `NoteReminders.id`
- Stores reminder ID for task-reminder linkage

```dart
class NoteTasks extends Table {
  /// Optional reminder ID if a reminder is set for this task
  IntColumn get reminderId => integer().nullable();  // ← INT FOREIGN KEY
  // ...
}
```

**Generated Code (Drift)**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.g.dart` (lines 3495-3501)
  ```dart
  late final GeneratedColumn<int> reminderId = GeneratedColumn<int>(
    'reminder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  ```

### Type Declarations Across Codebase

| Location | Type | Usage |
|----------|------|-------|
| `NoteTask.reminderId` | `int?` | Local task-reminder link |
| `BaseReminderService.createReminderInDb()` | Returns `int?` | Reminder creation |
| `AppDb.getReminderById()` | Parameter: `int` | Reminder queries |
| `AppDb.updateReminder()` | Parameter: `int` | Reminder updates |
| `AppDb.deleteReminderById()` | Parameter: `int` | Reminder deletion |
| `UnifiedSyncService._parseReminderId()` | Returns `int?` | Sync parsing |
| `ReminderNotificationData.id` | `int` | Notification ID |
| `advanced_reminder_service.dart` | `int reminderId` (line 784) | Method parameter |

### Impact Assessment

**CRITICAL** - Type system dependency:
- **40+ type declarations** assume `int` for reminder IDs
- **Foreign key constraint** in `NoteReminders(id) - NoteTask.reminderId`
- **Auto-increment primary key** prevents UUID migration in local DB
- **Drift code generation** hardcodes `DriftSqlType.int`

---

## 4. SYNC OPERATIONS

### Current Sync Flow

**_syncReminders() Method**
- File: `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` (lines 751-899)
- Lines 771-773: Creates local-by-ID map
  ```dart
  final localById = <int, NoteReminder>{
    for (final reminder in localReminders) reminder.id: reminder,
  };
  ```
- Lines 775-780: Parses remote IDs
  ```dart
  final remoteById = <int, Map<String, dynamic>>{};
  for (final remote in remoteReminders) {
    final remoteId = _parseReminderId(remote['id']);  // ← Expects PARSEABLE as INT
    if (remoteId != null) {
      remoteById[remoteId] = remote;
    }
  }
  ```

**ID Parsing Logic**
- File: `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` (lines 1974-2011)
- `_parseReminderId()` explicitly expects integers:
  ```dart
  int? _parseReminderId(dynamic value) {
    if (value is int) {
      if (value > 0) return value;  // ← Validates as positive integer
      // ...
    }
    if (value is num) {
      final intValue = value.toInt();  // ← Converts to int
      if (intValue > 0) return intValue;
    }
    if (value is String) {
      final parsed = int.tryParse(value);  // ← Parses as int
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }
  ```

**Serialization**
- File: `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` (lines 1879-1907)
- Line 1881: `'id': reminder.id,` (sends local INT to remote)
- Remote database ignores this and generates its own UUID

**Deserialization**
- File: `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` (lines 1909-1972)
- Line 1933: `id: Value(reminderId),` (inserts parsed integer ID)
- Problem: Remote UUID becomes local INT, causing sync failure

### Sync Operation Matrix

| Operation | Local ID | Remote ID | Current Handling | Issue |
|-----------|----------|-----------|------------------|-------|
| **Upload** | INT (42) | UUID (abc-123-def) | Sends INT, server generates UUID | ID mismatch after upload |
| **Download** | INT (1-999) | UUID (uuid-1) | Parses UUID as INT, fails | UUID can't parse as INT |
| **Conflict** | INT (42) | UUID (abc-123-def) | INT comparison fails | Wrong comparison logic |
| **Merge** | INT (local) | UUID (remote) | Can't match on ID | Data duplication |

### Critical Sync Code Failures

**Line 752:** `<int>[]` - Upload list assumes int IDs
**Line 753:** `<int>[]` - Download list assumes int IDs  
**Line 777:** `_parseReminderId()` called on UUID values - **WILL FAIL**
**Line 786:** `_serializeReminder()` sends local INT - **CREATES MISMATCH**
**Line 1933:** Inserts parsed INT from UUID - **TYPE ERROR**

### Impact Assessment

**CRITICAL** - Sync system will break:
- Remote UUID IDs cannot be parsed as integers
- Sync will reject all remote reminders (remoteId == null)
- Upload creates duplicates (local INT != remote UUID)
- Download fails with type conversion errors
- Conflict resolution impossible without matching IDs

---

## 5. FOREIGN KEY RELATIONSHIPS

### Current Schema

**NoteReminders Table (Primary)**
- File: `/Users/onronder/duru-notes/supabase/migrations/20250301000000_initial_baseline_schema.sql` (line 295)
- Primary Key: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`

**NoteTasks Table (Referencing)**
- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (line 227)
- Foreign Key: `IntColumn get reminderId => integer().nullable();`
- Points to: `NoteReminders.id` (INTEGER locally, but UUID remotely)

**Local Migration**
- File: `/Users/onronder/duru-notes/lib/data/migrations/migration_12_phase3_optimization.dart` (lines 266-333)
- Creates foreign key: `FOREIGN KEY (reminder_id) REFERENCES note_reminders(id) ON DELETE SET NULL`

### Cascade Rules

| Rule | Current | Impact |
|------|---------|--------|
| ON DELETE CASCADE | reminders.id | Deletes orphaned tasks |
| ON DELETE SET NULL | task.reminder_id | Sets NULL when reminder deleted |
| ON UPDATE CASCADE | Not used | No update cascading |

### Foreign Key Index

- File: `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (line 2627)
- Index: `idx_note_tasks_reminder_id ON note_tasks(reminder_id) WHERE reminder_id IS NOT NULL`
- Optimizes lookups on INTEGER reminder_id
- Will need optimization adjustment for TEXT/UUID

### Impact Assessment

**HIGH** - Foreign key constraint breakage:
- Local NoteTasks has INT foreign key to NoteReminders INT
- Remote notes.note_tasks has UUID foreign key to reminders UUID
- Migration from INT to UUID requires:
  1. Alter NoteReminders.id type locally
  2. Update all task.reminderId to match
  3. Recreate foreign key constraints
  4. Reindex reminder_id lookups

---

## 6. UI/DISPLAY USAGE

### Reminder ID Display

**ReminderCoordinator Log Output**
- File: `/Users/onronder/duru-notes/lib/services/reminders/reminder_coordinator.dart` (line 228)
- `debugPrint('[ReminderCoordinator] time reminder created id=$reminderId');`
- Displays reminder ID to developer console

**Logger Data**
- Multiple locations log reminder IDs:
  - Line 196-207 (geofence_reminder_service.dart) - tracks reminder creation
  - Line 325-329 (task_reminder_bridge.dart) - logs task reminder linkage
  - Line 1231-1234 (task_reminder_bridge.dart) - logs cleanup operations

**Audit Trail**
- File: `/Users/onronder/duru-notes/services/security/security_audit_trail.dart`
- Logs: `reminderId=$reminderId` in audit reasons (line 209, 447, etc.)

### Notification IDs

**Android Notifications**
- File: `/Users/onronder/duru-notes/lib/services/reminders/base_reminder_service.dart` (line 335)
  ```dart
  await plugin.zonedSchedule(
    data.id,  // ← MUST be int for Android
    data.title,
    data.body,
    // ...
  );
  ```
- Notification ID parameter requires integer
- Line 72: `final int id;` in `ReminderNotificationData`

**Geofence IDs**
- File: `/Users/onronder/duru-notes/lib/services/reminders/geofence_reminder_service.dart` (line 238-241)
  ```dart
  final geofence = Geofence(
    id: 'reminder_$reminderId',  // ← Uses INT in string format
    // ...
  );
  ```
- Creates geofence with ID like `'reminder_42'` (where 42 is INT)

### Widget Keys

**Reminder List Items**
- File: `/Users/onronder/duru-notes/lib/ui/reminders_screen.dart` (line 83)
- Creates list from reminders with implicit integer IDs

### Impact Assessment

**MEDIUM** - UI/Display changes needed:
- Notification IDs use hashCode (can work with UUID)
- Geofence IDs can use string UUID format
- Logging/audit trail can accept UUID strings
- No breaking UI changes, but string formatting adjustments needed

---

## 7. TESTS

### Test Files with Hard-Coded Reminder IDs

**File 1: `/Users/onronder/duru-notes/test/services/task_reminder_linking_test.dart`**
- Line 77: `int reminderIdToReturn = 321;`
- Line 97: `return reminderIdToReturn;`
- Line 357: `expect(result, equals(fakeCoordinator.reminderIdToReturn))`
- **Impact:** Hard-coded reminder ID 321 must be changed to UUID

**File 2: `/Users/onronder/duru-notes/test/services/snooze_functionality_test.dart`**
- Line 116-141: `NoteReminder reminder0()` factory creates reminder with `id: 42`
- Line 150: `when(mockDb.getReminderById(42, 'user-123'))`
- Multiple tests using ID 42 throughout (lines 145, 150, 215, 239)
- **Impact:** All references to ID 42 must use UUID

**File 3: `/Users/onronder/duru-notes/test/security/task_reminder_authorization_test.dart`**
- Line 293: `expect('${latest.metadata?['reason']}', contains('reminderId=321'));`
- Line 354: `verify(mockAdvancedService.deleteReminder(777)).called(1);`
- **Impact:** Mock expectations using integer IDs must be updated

**File 4: `/Users/onronder/duru-notes/test/infrastructure/repositories/notes_core_repository_sync_test.dart`**
- Line 224: `verify(mockApi.deleteReminder('42')).called(1);`
- Line 172: `final reminderId = await db.createReminder(...)`
- **Impact:** Tests assume integer IDs from createReminder()

**File 5: `/Users/onronder/duru-notes/test/security/advanced_reminder_service_authorization_test.dart`**
- Line 173: Creates reminders in test setup
- Line 253-274: Inserts reminders for authorization tests
- **Impact:** All insertReminder() calls return INT, need UUID

### Test Count Impact

| Test Category | Files | Hard-coded IDs | Methods Using int | Total Changes |
|---------------|-------|----------------|-------------------|---------------|
| Reminder Tests | 5 | 4+ locations | 30+ method signatures | 40+ |
| Mock Tests | 8 | Mock return types | `when().thenAnswer()` | 25+ |
| Security Tests | 3 | Authorization checks | ID validation tests | 15+ |
| Integration Tests | 2 | Sync operations | Upload/download | 10+ |
| **TOTAL** | **18** | **50+ locations** | **70+ changes** | **120+ test updates** |

### Mock Signatures Needing Updates

```dart
// Current (INTEGER)
Future<int> createReminder(...)
Future<void> deleteReminder(int reminderId)
Future<NoteReminder?> getReminderById(int id, String userId)

// Required (UUID/STRING)
Future<String> createReminder(...)
Future<void> deleteReminder(String reminderId)
Future<NoteReminder?> getReminderById(String id, String userId)
```

### Impact Assessment

**HIGH** - Extensive test updates required:
- **120+ test changes** across 18 test files
- **50+ hard-coded ID values** must be replaced with UUIDs
- **Mock signatures** must change from `int` to `String`
- **Test setup factories** must generate UUIDs instead of integers
- **Verification assertions** must use UUID strings
- All tests will fail until updated

---

## 8. CRITICAL RISKS & BREAKING CHANGES

### Risk Category 1: Data Loss Risk

| Risk | Severity | Details |
|------|----------|---------|
| **Lost Sync** | CRITICAL | Sync will reject all remote reminders because UUID ≠ INT parse |
| **Orphaned Tasks** | CRITICAL | Tasks with valid reminder IDs become orphaned when local reminder deleted |
| **Duplicate Reminders** | CRITICAL | Upload + download creates two reminders (local INT + remote UUID) |
| **Data Inconsistency** | CRITICAL | Desktop app synced data diverges from mobile app (different ID systems) |

### Risk Category 2: Breaking Changes

| Breaking Change | Impact | Files Affected |
|-----------------|--------|-----------------|
| **Reminder ID Type** | INT → UUID/STRING | 40+ method signatures |
| **Auto-Increment Logic** | Remove autoincrement | Migration 12, app_db.dart |
| **Foreign Keys** | INT FK → UUID FK | Migration code, schema |
| **Sync Parsing** | int.tryParse() → UUID.parse() | unified_sync_service.dart |
| **Notification IDs** | INT → hashCode(UUID) | base_reminder_service.dart |
| **Geofence IDs** | 'reminder_INT' → 'reminder_UUID' | geofence_reminder_service.dart |

### Risk Category 3: Backward Compatibility

**Existing Data Issues:**
1. Users with local reminders (INT IDs) cannot sync with remote (UUID)
2. Desktop app data (INT) incompatible with UUID schema
3. Backups contain INTEGER IDs that won't import

**Migration Complexity:**
1. Two-phase migration needed (local + remote)
2. Requires data transformation during sync
3. Cannot roll back without data loss

### Risk Category 4: Integration Failures

**Known Failure Points:**

1. **UnifiedSyncService._parseReminderId()** (lines 1974-2011)
   - Cannot parse UUID as integer
   - Will return `null` for all remote reminders
   - Sync will skip all remote data

2. **Geofence Setup** (line 264)
   - `int.tryParse(reminderIdStr)` fails on UUID
   - Geofence ID generation breaks
   - Location reminders won't trigger

3. **Task-Reminder Linking** (line 179)
   - `int.tryParse()` on UUID fails
   - Task.reminderId becomes null
   - No task-reminder association

4. **Notification Scheduling** (line 335)
   - Requires int notification ID
   - UUID hashCode() workaround available
   - But changes notification grouping logic

---

## REQUIRED CHANGES SUMMARY

### Phase 1: Local Database Schema
1. Create migration: Alter NoteReminders.id to TEXT
2. Drop AUTOINCREMENT constraint
3. Update NoteTasks.reminderId to TEXT
4. Migrate existing data: Convert INT to UUID format
5. Update foreign key constraints
6. Reindex reminder_id lookups

### Phase 2: Type System Updates
1. Change all `int reminderId` → `String reminderId`
2. Update method signatures (30+ methods)
3. Update return types: `Future<int>` → `Future<String>`
4. Update Drift definitions (app_db.dart)
5. Regenerate Drift code

### Phase 3: Sync Code
1. Rewrite `_parseReminderId()` for UUID parsing
2. Update `_serializeReminder()` to preserve UUID
3. Fix `_upsertLocalReminder()` to accept STRING IDs
4. Remove INT validation (positive check, etc.)
5. Update ID comparison logic

### Phase 4: Reminder Services
1. Update BaseReminderService.createReminderInDb() return type
2. Update GeofenceReminderService ID extraction
3. Update SnoozeReminderService ID handling
4. Update RecurringReminderService ID operations
5. Update ReminderCoordinator signatures

### Phase 5: Task-Reminder Bridge
1. Change task.reminderId to accept STRING
2. Update createTaskReminder() return type
3. Update all getReminderById() calls
4. Update deleteReminder() calls with STRING IDs

### Phase 6: Notifications & UI
1. Update ReminderNotificationData.id to String
2. Keep hashCode() for notification IDs (work-around)
3. Update geofence ID generation
4. Update logger/audit strings

### Phase 7: Tests
1. Update 18 test files
2. Change mock signatures (int → String)
3. Replace 50+ hard-coded integer IDs with UUIDs
4. Update assertions (equality checks)
5. Update setup factories

### Phase 8: Migration Script
1. Add data migration in Supabase
2. Add data migration in local DB
3. Sync validation after migration
4. Rollback procedures

---

## FILES REQUIRING MODIFICATION

### Database Schema (3 files)
- `/Users/onronder/duru-notes/supabase/migrations/20250301000000_initial_baseline_schema.sql` (create migration)
- `/Users/onronder/duru-notes/lib/data/local/app_db.dart` (lines 125-169, 227, 2059-2090)
- `/Users/onronder/duru-notes/lib/data/migrations/migration_12_phase3_optimization.dart` (foreign key migration)

### Core Services (8 files)
- `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` (lines 751-2011) - **CRITICAL**
- `/Users/onronder/duru-notes/lib/services/reminders/base_reminder_service.dart` (lines 203-241)
- `/Users/onronder/duru-notes/lib/services/reminders/geofence_reminder_service.dart` (lines 224-272)
- `/Users/onronder/duru-notes/lib/services/reminders/snooze_reminder_service.dart` (lines 44, 81)
- `/Users/onronder/duru-notes/lib/services/reminders/recurring_reminder_service.dart` (lines 65, 158, 287)
- `/Users/onronder/duru-notes/lib/services/reminders/reminder_coordinator.dart` (line 228)
- `/Users/onronder/duru-notes/lib/services/task_reminder_bridge.dart` (lines 139-354)
- `/Users/onronder/duru-notes/lib/services/advanced_reminder_service.dart` (lines 298, 480, 767-822)

### API Layer (2 files)
- `/Users/onronder/duru-notes/lib/data/remote/supabase_note_api.dart` (lines 708-752)
- `/Users/onronder/duru-notes/lib/data/remote/secure_api_wrapper.dart` (line 369)

### Tests (18 files)
- `/Users/onronder/duru-notes/test/services/task_reminder_linking_test.dart` (line 77)
- `/Users/onronder/duru-notes/test/services/snooze_functionality_test.dart` (lines 116-150)
- `/Users/onronder/duru-notes/test/security/task_reminder_authorization_test.dart` (lines 293, 354)
- `/Users/onronder/duru-notes/test/security/advanced_reminder_service_authorization_test.dart` (lines 173-274)
- `/Users/onronder/duru-notes/test/security/reminder_coordinator_authorization_test.dart` (lines 175-249)
- `+ 13 more test files with mocks and fixtures`

### Other Files (5 files)
- `/Users/onronder/duru-notes/lib/services/unified_reminder_service.dart` (hashCode usage)
- `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart` (lines 1155-1198)
- `/Users/onronder/duru-notes/lib/domain/repositories/i_task_repository.dart` (if reminder ID in interface)
- `/Users/onronder/duru-notes/lib/ui/reminders_screen.dart` (display logic)
- `/Users/onronder/duru-notes/lib/services/gdpr_compliance_service.dart` (line 680)

**Total: 36 files require changes**
**Total: 150+ specific code locations**

---

## IMPLEMENTATION RECOMMENDATION

### Option 1: Complete Migration (Recommended)
- Migrate both local and remote to UUID
- Sync all data during migration
- Update all 36 files
- Complete test rewrite (120+ updates)
- Timeline: 3-4 weeks

**Pros:**
- Consistent system across platforms
- Better data compatibility
- Future-proof architecture

**Cons:**
- Large refactoring effort
- Risk of data loss during migration
- Requires downtime for sync verification

### Option 2: Gradual Migration
- Keep INT locally, add UUID handling in sync
- Wrapper layer for ID conversions
- Extended compatibility period
- Partial test updates

**Pros:**
- Lower immediate risk
- Can roll back easier
- Backward compatible

**Cons:**
- Increased complexity
- More bugs in conversion layer
- Technical debt

### Option 3: Local INT + Remote UUID (Current)
- Accept mismatch as-is
- Work around in sync code
- Keep dual ID systems

**Pros:**
- No migration needed now

**Cons:**
- Sync will be broken (CRITICAL)
- Data inconsistency across devices
- Not sustainable long-term

---

## CONCLUSION

**This is a critical schema mismatch that requires immediate attention.**

The current system has:
- ✅ Remote database correctly uses UUID
- ❌ Local database incorrectly uses INTEGER
- ❌ All 40+ reminder methods expect INTEGER
- ❌ Sync code assumes INTEGER parsing
- ❌ Tests hard-code INTEGER values
- ❌ Foreign keys reference INTEGER ID

**Recommended Action:** Proceed with Option 1 (Complete Migration)

**Estimated Effort:**
- Schema migration: 2-3 days
- Code updates: 5-7 days
- Testing: 3-4 days
- Validation: 2-3 days
- **Total: 3-4 weeks**

**Critical Success Factors:**
1. Back up all user data before migration
2. Create comprehensive test suite FIRST
3. Validate sync integrity after each change
4. Test on staging environment fully
5. Communicate deprecation to users

