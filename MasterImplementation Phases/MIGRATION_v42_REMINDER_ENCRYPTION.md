# Migration v42: Reminder Encryption Implementation

**Status:** 🔴 CRITICAL - P0 Security Issue
**Created:** 2025-11-18
**Priority:** P0 (Must fix before production release)
**Estimated Effort:** 3-5 days
**Risk Level:** High (Data migration + sync changes)

---

## 🚨 Security Issue

### Current State - INSECURE ⚠️

Reminders currently sync to Supabase **in plaintext**, exposing sensitive user data:

```sql
CREATE TABLE public.reminders (
  id uuid PRIMARY KEY,
  note_id uuid NOT NULL,
  user_id uuid NOT NULL,
  title text NOT NULL DEFAULT '',              -- ⚠️ PLAINTEXT
  body text NOT NULL DEFAULT '',               -- ⚠️ PLAINTEXT
  location_name text,                          -- ⚠️ PLAINTEXT
  type text NOT NULL,                          -- OK (system field)
  remind_at timestamptz,                       -- OK (system field)
  recurrence_pattern text NOT NULL,            -- OK (system field)
  -- ... other system fields
);
```

### What Data Is Exposed?

1. **Reminder titles**: "Doctor appointment", "Call mom about birthday"
2. **Reminder bodies**: Detailed reminder notes and context
3. **Location names**: Home address, workplace, sensitive locations
4. **Implicit patterns**: Meeting schedules, personal routines

### Why This Matters

- **Privacy Risk**: Backend admins can read reminder content
- **Compliance Risk**: Violates user expectation of end-to-end encryption
- **Consistency Gap**: Notes and folders are encrypted, reminders are not
- **Attack Surface**: Database breach exposes reminder data

---

## ✅ Expected State - SECURE

### After Migration v42:

```sql
CREATE TABLE public.reminders (
  id uuid PRIMARY KEY,
  note_id uuid NOT NULL,
  user_id uuid NOT NULL,

  -- Encrypted fields (bytea columns)
  title_enc bytea NOT NULL,                    -- ✅ ENCRYPTED
  body_enc bytea NOT NULL,                     -- ✅ ENCRYPTED
  location_name_enc bytea,                     -- ✅ ENCRYPTED

  -- System fields remain unencrypted (required for queries)
  type text NOT NULL,
  remind_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  recurrence_pattern text NOT NULL DEFAULT 'none',
  recurrence_interval integer NOT NULL DEFAULT 1,
  recurrence_end_date timestamptz,
  latitude double precision,
  longitude double precision,
  radius double precision,
  snoozed_until timestamptz,
  snooze_count integer NOT NULL DEFAULT 0,
  trigger_count integer NOT NULL DEFAULT 0,
  last_triggered timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);
```

### Why These Fields?

**Encrypted (bytea):**
- `title_enc`: User-visible reminder title (contains PII)
- `body_enc`: Detailed reminder notes (contains PII)
- `location_name_enc`: Human-readable location (contains PII)

**Unencrypted (system fields):**
- `type`: Required for filtering (time/location/recurring)
- `remind_at`: Required for scheduling queries
- `is_active`: Required for filtering active reminders
- `latitude/longitude`: Required for geofence queries
- `recurrence_pattern`: Required for recurrence logic
- Timestamps and counters: System metadata

---

## 📋 Implementation Plan

### Phase 1: Database Schema Migration (v42)

#### Step 1.1: Create Migration Script

**File:** `supabase/migrations/20251118000000_reminder_encryption.sql`

```sql
-- Migration v42: Add encrypted columns to reminders table
-- This is a NON-BREAKING additive migration

BEGIN;

-- Add new encrypted columns (nullable during migration)
ALTER TABLE public.reminders
  ADD COLUMN IF NOT EXISTS title_enc bytea,
  ADD COLUMN IF NOT EXISTS body_enc bytea,
  ADD COLUMN IF NOT EXISTS location_name_enc bytea;

-- Create indexes for encrypted lookups (if needed)
-- Note: Cannot create functional indexes on bytea, queries must filter by system fields

COMMIT;
```

**Migration Strategy:** Additive (non-breaking)
- Existing plaintext columns remain temporarily
- New encrypted columns added as nullable
- Allows gradual migration of existing data
- Old app versions continue working during rollout

#### Step 1.2: Deploy Backend Migration

```bash
# Test migration locally first
supabase db reset  # Test in local environment

# Deploy to staging
supabase db push --db-url <staging-url>

# Verify migration succeeded
supabase db lint

# Deploy to production (after testing)
supabase db push --db-url <production-url>
```

### Phase 2: Local Database Schema Update

#### Step 2.1: Update `app_db.dart` Schema

**File:** `lib/data/local/app_db.dart`

Current (v41):
```dart
class NoteReminders extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get type => textEnum<ReminderType>()();
  // ... other fields
}
```

After (v42):
```dart
class NoteReminders extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text()();

  // Encrypted fields
  BlobColumn get titleEncrypted => blob()();
  BlobColumn get bodyEncrypted => blob()();
  BlobColumn get locationNameEncrypted => blob().nullable()();

  // Encryption version tracking
  IntColumn get encryptionVersion => integer().withDefault(const Constant(1))();

  // System fields remain unencrypted
  TextColumn get type => textEnum<ReminderType>()();
  DateTimeColumn get remindAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // ... other system fields
}
```

#### Step 2.2: Create Local Migration v42

**File:** `lib/data/migrations/migration_42_reminder_encryption.dart`

```dart
import 'package:drift/drift.dart';
import '../local/app_db.dart';
import '../../core/crypto/crypto_box.dart';
import '../../core/monitoring/app_logger.dart';

class Migration42ReminderEncryption {
  static final _logger = LoggerFactory.instance;

  static Future<void> migrate(
    AppDb db,
    CryptoBox crypto,
    String userId,
  ) async {
    _logger.info('[Migration 42] Starting reminder encryption migration...');

    // Get all reminders for this user
    final reminders = await (db.select(db.noteReminders)
          ..where((r) => r.userId.equals(userId)))
        .get();

    _logger.info('[Migration 42] Encrypting ${reminders.length} reminders...');

    int encrypted = 0;
    int errors = 0;

    for (final reminder in reminders) {
      try {
        // Encrypt title, body, location_name
        final titleEnc = await crypto.encrypt(reminder.title);
        final bodyEnc = await crypto.encrypt(reminder.body);
        final locationEnc = reminder.locationName != null
            ? await crypto.encrypt(reminder.locationName!)
            : null;

        // Update reminder with encrypted data
        await db.update(db.noteReminders).replace(
              reminder.copyWith(
                titleEncrypted: titleEnc,
                bodyEncrypted: bodyEnc,
                locationNameEncrypted: locationEnc,
                encryptionVersion: 1,
              ),
            );

        encrypted++;
      } catch (e, stack) {
        _logger.error(
          '[Migration 42] Failed to encrypt reminder ${reminder.id}',
          error: e,
          stackTrace: stack,
        );
        errors++;
      }
    }

    _logger.info(
      '[Migration 42] ✅ Reminder encryption migration complete: '
      '$encrypted encrypted, $errors errors',
    );

    if (errors > 0) {
      throw Exception(
        'Migration 42 completed with errors: $errors reminders failed encryption',
      );
    }
  }
}
```

#### Step 2.3: Update `app_db.dart` Migration Hook

```dart
@override
int get schemaVersion => 42;  // Increment from 41 to 42

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // ... existing migrations v1-v41 ...

      // Migration v42: Reminder encryption
      if (from < 42) {
        // Add encrypted columns
        await m.addColumn(noteReminders, noteReminders.titleEncrypted);
        await m.addColumn(noteReminders, noteReminders.bodyEncrypted);
        await m.addColumn(noteReminders, noteReminders.locationNameEncrypted);
        await m.addColumn(noteReminders, noteReminders.encryptionVersion);

        // Encrypt existing data
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Migration42ReminderEncryption.migrate(this, _crypto, userId);
        }
      }
    },
  );
}
```

### Phase 3: Sync Service Updates

#### Step 3.1: Update `_serializeReminder()` - Upload Encryption

**File:** `lib/services/unified_sync_service.dart` (around line 1048)

Current (INSECURE):
```dart
Map<String, dynamic> _serializeReminder(NoteReminder reminder) {
  return {
    'id': reminder.id,
    'note_id': reminder.noteId,
    'user_id': reminder.userId,
    'title': reminder.title,  // ⚠️ PLAINTEXT
    'body': reminder.body,    // ⚠️ PLAINTEXT
    'location_name': reminder.locationName,  // ⚠️ PLAINTEXT
    // ... other fields
  };
}
```

After v42 (SECURE):
```dart
/// Serialize reminder for upload with encryption
///
/// SECURITY: Encrypts title, body, and location_name before upload
/// Following same pattern as notes and folders
Map<String, dynamic> _serializeReminder(NoteReminder reminder) async {
  // Encrypt sensitive fields
  final titleEnc = await _crypto!.encrypt(reminder.title);
  final bodyEnc = await _crypto!.encrypt(reminder.body);
  final locationEnc = reminder.locationName != null
      ? await _crypto!.encrypt(reminder.locationName!)
      : null;

  return {
    'id': reminder.id,
    'note_id': reminder.noteId,
    'user_id': reminder.userId,

    // Encrypted fields (bytea)
    'title_enc': titleEnc,
    'body_enc': bodyEnc,
    'location_name_enc': locationEnc,

    // System fields (unencrypted)
    'type': reminder.type.name,
    'remind_at': reminder.remindAt?.toIso8601String(),
    'is_active': reminder.isActive,
    'recurrence_pattern': reminder.recurrencePattern,
    'recurrence_interval': reminder.recurrenceInterval,
    'recurrence_end_date': reminder.recurrenceEndDate?.toIso8601String(),
    'latitude': reminder.latitude,
    'longitude': reminder.longitude,
    'radius': reminder.radius,
    'snoozed_until': reminder.snoozedUntil?.toIso8601String(),
    'snooze_count': reminder.snoozeCount,
    'trigger_count': reminder.triggerCount,
    'last_triggered': reminder.lastTriggered?.toIso8601String(),
    'created_at': reminder.createdAt.toIso8601String(),
    'updated_at': reminder.updatedAt.toIso8601String(),
  };
}
```

#### Step 3.2: Update `_upsertLocalReminder()` - Download Decryption

**File:** `lib/services/unified_sync_service.dart` (around line 1077)

Current (INSECURE):
```dart
Future<void> _upsertLocalReminder(
  Map<String, dynamic> remote,
  String userId,
) async {
  await _db!.into(_db!.noteReminders).insertOnConflictUpdate(
        NoteRemindersCompanion(
          id: Value(remote['id'] as String),
          noteId: Value(remote['note_id'] as String),
          userId: Value(userId),
          title: Value(remote['title'] as String? ?? ''),  // ⚠️ PLAINTEXT
          body: Value(remote['body'] as String? ?? ''),    // ⚠️ PLAINTEXT
          locationName: Value(remote['location_name'] as String?),  // ⚠️ PLAINTEXT
          // ... other fields
        ),
      );
}
```

After v42 (SECURE):
```dart
/// Upsert remote reminder to local DB with decryption
///
/// SECURITY: Decrypts title, body, and location_name after download
Future<void> _upsertLocalReminder(
  Map<String, dynamic> remote,
  String userId,
) async {
  // Decrypt sensitive fields
  final titleEncBytes = remote['title_enc'] as List<int>?;
  final bodyEncBytes = remote['body_enc'] as List<int>?;
  final locationEncBytes = remote['location_name_enc'] as List<int>?;

  if (titleEncBytes == null || bodyEncBytes == null) {
    _logger.warning(
      '[Sync] Reminder ${remote['id']} missing encrypted fields, skipping',
      data: {'reminderId': remote['id']},
    );
    return;
  }

  final title = await _crypto!.decrypt(Uint8List.fromList(titleEncBytes));
  final body = await _crypto!.decrypt(Uint8List.fromList(bodyEncBytes));
  final locationName = locationEncBytes != null
      ? await _crypto!.decrypt(Uint8List.fromList(locationEncBytes))
      : null;

  await _db!.into(_db!.noteReminders).insertOnConflictUpdate(
        NoteRemindersCompanion(
          id: Value(remote['id'] as String),
          noteId: Value(remote['note_id'] as String),
          userId: Value(userId),

          // Decrypted fields
          titleEncrypted: Value(Uint8List.fromList(titleEncBytes)),
          bodyEncrypted: Value(Uint8List.fromList(bodyEncBytes)),
          locationNameEncrypted: locationEncBytes != null
              ? Value(Uint8List.fromList(locationEncBytes))
              : const Value.absent(),
          encryptionVersion: const Value(1),

          // System fields
          type: Value(_parseReminderType(remote['type'])),
          remindAt: Value(_parseDateTime(remote['remind_at'])),
          isActive: Value(remote['is_active'] as bool? ?? true),
          recurrencePattern: Value(remote['recurrence_pattern'] as String? ?? 'none'),
          recurrenceInterval: Value(remote['recurrence_interval'] as int? ?? 1),
          recurrenceEndDate: Value(_parseDateTime(remote['recurrence_end_date'])),
          latitude: Value(remote['latitude'] as double?),
          longitude: Value(remote['longitude'] as double?),
          radius: Value(remote['radius'] as double?),
          snoozedUntil: Value(_parseDateTime(remote['snoozed_until'])),
          snoozeCount: Value(remote['snooze_count'] as int? ?? 0),
          triggerCount: Value(remote['trigger_count'] as int? ?? 0),
          lastTriggered: Value(_parseDateTime(remote['last_triggered'])),
          createdAt: Value(_parseDateTime(remote['created_at']) ?? DateTime.now()),
          updatedAt: Value(_parseDateTime(remote['updated_at']) ?? DateTime.now()),
        ),
      );
}
```

### Phase 4: Repository Layer Updates

#### Step 4.1: Update All Reminder Access Points

**Files to update:**
- `lib/services/reminders/base_reminder_service.dart`
- `lib/services/reminders/reminder_coordinator.dart`
- `lib/services/reminders/recurring_reminder_service.dart`
- `lib/services/reminders/geofence_reminder_service.dart`
- `lib/services/reminders/snooze_reminder_service.dart`
- `lib/services/advanced_reminder_service.dart`
- `lib/services/task_reminder_bridge.dart`

**Pattern:** All database reads must decrypt, all writes must encrypt

Example for `base_reminder_service.dart`:
```dart
Future<NoteReminder?> getReminderById(String id) async {
  final reminder = await (_db.select(_db.noteReminders)
        ..where((r) => r.id.equals(id)))
      .getSingleOrNull();

  if (reminder == null) return null;

  // Decrypt before returning
  return reminder.copyWith(
    title: await _crypto.decrypt(reminder.titleEncrypted),
    body: await _crypto.decrypt(reminder.bodyEncrypted),
    locationName: reminder.locationNameEncrypted != null
        ? await _crypto.decrypt(reminder.locationNameEncrypted!)
        : null,
  );
}

Future<void> createReminder(NoteReminder reminder) async {
  // Encrypt before storing
  final titleEnc = await _crypto.encrypt(reminder.title);
  final bodyEnc = await _crypto.encrypt(reminder.body);
  final locationEnc = reminder.locationName != null
      ? await _crypto.encrypt(reminder.locationName!)
      : null;

  await _db.into(_db.noteReminders).insert(
        reminder.copyWith(
          titleEncrypted: titleEnc,
          bodyEncrypted: bodyEnc,
          locationNameEncrypted: locationEnc,
          encryptionVersion: 1,
        ),
      );
}
```

### Phase 5: Data Migration & Cleanup

#### Step 5.1: Backend Data Migration Script

Once all clients have upgraded to v42:

```sql
-- After confirming all clients upgraded, remove plaintext columns
-- DO NOT RUN THIS until 100% of users on v42+

BEGIN;

-- Verify all reminders have encrypted data
DO $$
DECLARE
  unencrypted_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO unencrypted_count
  FROM public.reminders
  WHERE title_enc IS NULL OR body_enc IS NULL;

  IF unencrypted_count > 0 THEN
    RAISE EXCEPTION 'Cannot remove plaintext columns: % reminders not yet encrypted', unencrypted_count;
  END IF;
END;
$$;

-- Drop plaintext columns (destructive - requires 100% adoption)
ALTER TABLE public.reminders
  DROP COLUMN IF EXISTS title,
  DROP COLUMN IF EXISTS body,
  DROP COLUMN IF EXISTS location_name;

-- Make encrypted columns NOT NULL
ALTER TABLE public.reminders
  ALTER COLUMN title_enc SET NOT NULL,
  ALTER COLUMN body_enc SET NOT NULL;

COMMIT;
```

**⚠️ IMPORTANT:** Only run after:
1. All active users upgraded to app version with v42
2. Verified via analytics/logging that no plaintext writes occurring
3. Tested thoroughly in staging environment
4. Created database backup

---

## 🧪 Testing Strategy

### Unit Tests

**File:** `test/infrastructure/mappers/reminder_mapper_test.dart` (NEW)

```dart
import 'package:flutter_test/flutter_test.dart';
import '../helpers/security_test_setup.dart';

void main() {
  group('Reminder Encryption Tests', () {
    late CryptoBox crypto;

    setUp(() {
      crypto = SecurityTestSetup.createTestCryptoBox();
    });

    test('Encrypt and decrypt reminder title', () async {
      const plaintext = 'Doctor appointment at 3pm';

      final encrypted = await crypto.encrypt(plaintext);
      expect(encrypted, isNot(equals(plaintext)));
      expect(encrypted.length, greaterThan(0));

      final decrypted = await crypto.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('Encrypt and decrypt reminder body', () async {
      const plaintext = 'Bring insurance card and list of medications';

      final encrypted = await crypto.encrypt(plaintext);
      final decrypted = await crypto.decrypt(encrypted);

      expect(decrypted, equals(plaintext));
    });

    test('Encrypt and decrypt location name', () async {
      const plaintext = '123 Main St, Medical Center';

      final encrypted = await crypto.encrypt(plaintext);
      final decrypted = await crypto.decrypt(encrypted);

      expect(decrypted, equals(plaintext));
    });

    test('Null location name handled correctly', () async {
      // Should not throw when location_name is null
      expect(() async {
        final encrypted = null;
        if (encrypted != null) {
          await crypto.decrypt(encrypted);
        }
      }, returnsNormally);
    });
  });
}
```

### Integration Tests

**File:** `test/integration/reminder_encryption_sync_test.dart` (NEW)

```dart
void main() {
  group('Reminder Encryption Sync Tests', () {
    test('Upload reminder with encryption', () async {
      final harness = _SyncTestHarness();

      // Create reminder locally
      final reminder = await harness.createReminder(
        title: 'Sensitive reminder title',
        body: 'Sensitive reminder body',
        locationName: 'Secret location',
      );

      // Trigger sync (uploads to backend)
      await harness.sync();

      // Verify backend received ENCRYPTED data
      final remoteReminder = await harness.getRemoteReminder(reminder.id);
      expect(remoteReminder['title'], isNull);  // No plaintext column
      expect(remoteReminder['title_enc'], isNotNull);  // Has encrypted column
      expect(remoteReminder['title_enc'], isNot(contains('Sensitive')));
    });

    test('Download reminder with decryption', () async {
      final harness = _SyncTestHarness();

      // Seed backend with encrypted reminder
      await harness.seedRemoteReminder(
        id: 'reminder-1',
        titleEnc: await crypto.encrypt('Test reminder'),
        bodyEnc: await crypto.encrypt('Test body'),
      );

      // Trigger sync (downloads from backend)
      await harness.sync();

      // Verify local reminder is decrypted
      final localReminder = await harness.getLocalReminder('reminder-1');
      expect(localReminder.title, equals('Test reminder'));
      expect(localReminder.body, equals('Test body'));
    });
  });
}
```

### Manual Testing Checklist

#### ✅ Phase 1: Pre-Migration State
- [ ] Create test reminders with various content
- [ ] Verify reminders sync to backend (plaintext - pre-v42)
- [ ] Check Supabase UI - verify plaintext visible
- [ ] Note reminder count for verification

#### ✅ Phase 2: Run Migration
- [ ] Upgrade app to v42
- [ ] Observe migration logs in console
- [ ] Verify migration success message
- [ ] Check for any error logs

#### ✅ Phase 3: Post-Migration Verification
- [ ] Verify existing reminders still work
- [ ] Verify reminder titles/bodies display correctly
- [ ] Create new reminder - verify it's created
- [ ] Trigger sync - verify no errors
- [ ] Check Supabase UI - verify encrypted bytea columns

#### ✅ Phase 4: Sync Testing
- [ ] Create reminder on device A
- [ ] Sync device A
- [ ] Sync device B
- [ ] Verify reminder appears on device B with correct content
- [ ] Modify reminder on device B
- [ ] Sync both devices
- [ ] Verify changes propagate correctly

#### ✅ Phase 5: Edge Cases
- [ ] Test reminder with empty body
- [ ] Test reminder with null location_name
- [ ] Test reminder with special characters
- [ ] Test reminder with emoji in title
- [ ] Test very long reminder body (>1000 chars)

#### ✅ Phase 6: Security Verification
- [ ] Open Supabase table editor
- [ ] Verify `title` column is NOT readable
- [ ] Verify `title_enc` column shows bytea (not readable)
- [ ] Verify system fields (remind_at, is_active) still readable
- [ ] Confirm RLS policies still enforced

---

## 🚀 Rollout Plan

### Stage 1: Development & Testing (Week 1)
- [ ] Implement database migrations (local + remote)
- [ ] Update sync service encryption/decryption
- [ ] Update reminder services
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Manual testing in dev environment

### Stage 2: Staging Deployment (Week 2)
- [ ] Deploy backend migration to staging
- [ ] Deploy app build with v42 to staging
- [ ] Run full test suite
- [ ] Perform manual QA testing
- [ ] Load testing with 1000+ reminders
- [ ] Security audit of encrypted data

### Stage 3: Production Rollout (Week 3)
- [ ] Create database backup
- [ ] Deploy backend migration to production
- [ ] Soft launch: Release to 10% of users
- [ ] Monitor error logs and sync success rates
- [ ] Gradually increase rollout (25%, 50%, 100%)
- [ ] Monitor for 48 hours at each stage

### Stage 4: Cleanup (Week 4+)
- [ ] Wait for 95%+ adoption (analytics)
- [ ] Verify all reminders encrypted
- [ ] Schedule plaintext column removal
- [ ] Execute cleanup migration (DROP old columns)
- [ ] Final security audit

---

## ⚠️ Risks & Mitigation

### Risk 1: Migration Failure
**Risk:** Migration v42 fails, leaving reminders in inconsistent state
**Impact:** High - Users lose reminder data
**Probability:** Low
**Mitigation:**
- Comprehensive testing before production
- Database backups before migration
- Rollback plan ready
- Migration is additive (non-breaking)
- Can retry migration if it fails

### Risk 2: Sync Incompatibility
**Risk:** Old app versions can't sync after backend migration
**Impact:** High - Sync breaks for non-upgraded users
**Probability:** Medium
**Mitigation:**
- Additive migration keeps old columns temporarily
- Backend accepts both plaintext AND encrypted writes
- Gradual rollout allows monitoring
- Force update prompt for critical security fix

### Risk 3: Performance Degradation
**Risk:** Encryption/decryption slows down reminder operations
**Impact:** Medium - User experience degraded
**Probability:** Low
**Mitigation:**
- Batch processing already implemented (10 reminders/batch)
- Encryption is fast (XChaCha20-Poly1305)
- Benchmark tests before rollout
- Monitor performance metrics

### Risk 4: Data Loss During Migration
**Risk:** Encryption fails, some reminders lost
**Impact:** Critical - User data lost
**Probability:** Very Low
**Mitigation:**
- Try-catch around each reminder encryption
- Migration continues even if individual reminder fails
- Error logging for failed encryptions
- Manual recovery process for failed reminders
- Database backup before migration

---

## 📊 Success Metrics

### Technical Metrics
- **Migration Success Rate:** >99.9% of reminders encrypted without errors
- **Sync Success Rate:** No degradation from current baseline
- **Performance:** <100ms additional latency for encryption/decryption
- **Error Rate:** <0.1% sync errors post-migration

### Security Metrics
- **Encryption Coverage:** 100% of reminders have encrypted title/body
- **Plaintext Exposure:** 0 reminders with readable plaintext in backend
- **RLS Enforcement:** 100% of queries filtered by user_id

### User Metrics
- **Zero Data Loss:** No user-reported reminder data loss
- **Zero Functionality Regression:** Reminders work as before migration
- **Adoption Rate:** 95%+ users on v42+ within 30 days

---

## 🔗 Related Documentation

- **SYNC_ANALYSIS_REPORT.md** - Issue #4 (Reminder Encryption)
- **MIGRATION_v41_TEST_INSTRUCTIONS.md** - UUID migration precedent
- **ARCHITECTURE_VIOLATIONS.md** - Repository pattern enforcement
- **DELETION_PATTERNS.md** - Soft delete patterns

---

## 📝 Notes

### Why Not Encrypt System Fields?

**Question:** Why not encrypt `remind_at`, `recurrence_pattern`, etc.?

**Answer:** System fields must remain queryable:
- `remind_at`: Required for "show reminders due in next 24 hours" queries
- `is_active`: Required for filtering active vs dismissed reminders
- `latitude/longitude`: Required for geofence queries
- `recurrence_pattern`: Required for recurrence scheduling logic

Encrypting these would break essential functionality. They don't contain PII.

### Encryption Algorithm

**XChaCha20-Poly1305 AEAD** (same as notes/folders):
- Authenticated encryption (prevents tampering)
- Extended nonce (24 bytes) - prevents nonce reuse
- Fast (software-only implementation)
- Industry standard (IETF RFC 8439)

### Key Management

User encryption keys are stored in:
- **Local:** Secure storage (iOS Keychain, Android KeyStore)
- **Backend:** `user_encryption_keys` table (encrypted with user password)

Same key used for notes, folders, tasks, and reminders (consistent approach).

---

## 🎯 Definition of Done

- [ ] Backend migration deployed (adds `*_enc` columns)
- [ ] Local migration v42 implemented (encrypts existing data)
- [ ] Sync service updated (encrypt on upload, decrypt on download)
- [ ] All reminder services updated (encrypt/decrypt at boundaries)
- [ ] Unit tests pass (100% coverage for encryption logic)
- [ ] Integration tests pass (end-to-end sync with encryption)
- [ ] Manual testing complete (all checklist items verified)
- [ ] Security audit complete (verified no plaintext leaks)
- [ ] Documentation updated (this file + code comments)
- [ ] Rollout complete (95%+ users on v42+)
- [ ] Cleanup migration executed (plaintext columns removed)

---

**Next Steps:** Prioritize this work immediately after completing Phase 1 sync fixes. This is a critical security issue that must be resolved before any production release.
