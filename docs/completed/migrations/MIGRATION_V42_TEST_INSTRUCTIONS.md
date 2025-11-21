# Migration v42: Reminder Encryption - Test Instructions

**Created:** 2025-11-18
**Status:** Implementation Complete - Testing In Progress
**Priority:** P0 (Critical Security Fix)

---

## Overview

Migration v42 adds end-to-end encryption to reminders using XChaCha20-Poly1305 AEAD cipher. This document provides comprehensive testing instructions to validate the migration.

---

## Implementation Status ✅

### Completed Components:

1. **Backend Schema** (`supabase/migrations/20251118120000_add_reminder_encryption_columns.sql`)
   - ✅ Added `title_enc`, `body_enc`, `location_name_enc` (bytea columns)
   - ✅ Added `encryption_version` tracking
   - ✅ Created indexes for migration progress tracking
   - ✅ Zero-downtime approach (plaintext columns retained)

2. **Local Database Schema** (`lib/data/local/app_db.dart`)
   - ✅ Schema version 41 → 42
   - ✅ Added encrypted blob columns to `NoteReminders` table
   - ✅ Marked plaintext columns as deprecated

3. **Migration Implementation** (`lib/data/migrations/migration_42_reminder_encryption.dart`)
   - ✅ Lazy encryption strategy (adds columns only)
   - ✅ Fast migration with no user session dependency
   - ✅ Progress tracking helper method

4. **Sync Service** (`lib/services/unified_sync_service.dart`)
   - ✅ `_serializeReminder()` - encrypts before upload
   - ✅ `_upsertLocalReminder()` - decrypts after download
   - ✅ Dual-write strategy (both plaintext and encrypted)
   - ✅ Graceful error handling with fallback

5. **Reminder Services** (`lib/services/reminders/`)
   - ✅ `BaseReminderService` - encryption/decryption helpers
   - ✅ `ReminderConfig.toCompanionWithEncryption()` - encrypt on create
   - ✅ `decryptReminderFields()` - decrypt on read
   - ✅ `ensureReminderEncrypted()` - lazy encryption
   - ✅ All subclasses updated (`RecurringReminderService`, `GeofenceReminderService`, `SnoozeReminderService`)
   - ✅ `ReminderCoordinator` - passes CryptoBox to all services

---

## Manual Testing Checklist

### Phase 1: Fresh Installation (No Existing Data)

**Test 1.1: Create New Encrypted Reminder**
```
1. Clean install app (v42)
2. Create note
3. Add time-based reminder: "Doctor appointment at 3pm"
4. Save reminder
5. Verify in database:
   - `title` = "Doctor appointment at 3pm" (plaintext for compatibility)
   - `title_encrypted` = <blob data> (not null)
   - `encryption_version` = 1
```

**Expected Result:** ✅ Both plaintext and encrypted fields populated

**Test 1.2: Create Location Reminder**
```
1. Create note
2. Add location reminder: "Buy groceries" at "Supermarket"
3. Save reminder
4. Verify in database:
   - `title_encrypted` = <blob data>
   - `body_encrypted` = <blob data>
   - `location_name_encrypted` = <blob data>
   - `encryption_version` = 1
```

**Expected Result:** ✅ All sensitive fields encrypted

**Test 1.3: Sync to Remote**
```
1. Create encrypted reminder locally
2. Trigger sync
3. Check network traffic/Supabase logs:
   - Uploaded payload contains both `title` AND `title_enc`
   - `encryption_version` = 1
```

**Expected Result:** ✅ Dual-write to ensure backward compatibility

---

### Phase 2: Migration from v41 (Existing Plaintext Reminders)

**Test 2.1: App Upgrade**
```
1. Start with app v41 (plaintext reminders)
2. Create 5 plaintext reminders
3. Upgrade to app v42
4. Verify migration runs:
   - Check logs for "[Migration 42] Starting reminder encryption migration..."
   - Check logs for "[Migration 42] ✅ Reminder encryption migration complete"
5. Verify database schema:
   - `title_encrypted` column exists
   - `encryption_version` column exists
```

**Expected Result:** ✅ Migration completes in <1 second (lazy encryption)

**Test 2.2: Lazy Encryption on Access**
```
1. After v42 upgrade, open note with reminders
2. View existing reminder
3. Verify database shows reminder is now encrypted:
   - `title_encrypted` = <blob data>
   - `encryption_version` = 1
```

**Expected Result:** ✅ Plaintext reminder encrypted on first access

**Test 2.3: Migration Progress Tracking**
```
1. Create 10 plaintext reminders on v41
2. Upgrade to v42
3. Access 3 reminders (to trigger lazy encryption)
4. Run migration progress query in database:
   SELECT
     COUNT(*) as total_reminders,
     COUNT(encryption_version) as encrypted_reminders,
     ROUND(100.0 * COUNT(encryption_version) / COUNT(*), 2) as percent_encrypted
   FROM note_reminders;
```

**Expected Result:**
```
total_reminders: 10
encrypted_reminders: 3
percent_encrypted: 30%
```

---

### Phase 3: Sync Between v41 and v42 Apps (Gradual Rollout)

**Test 3.1: v42 → v41 Sync (Backward Compatibility)**
```
1. Device A: App v42 - create encrypted reminder
2. Sync to remote (uploads both plaintext and encrypted)
3. Device B: App v41 - sync from remote
4. Verify Device B can read reminder:
   - Uses plaintext `title` field
   - Ignores encrypted fields (not present in v41 schema)
```

**Expected Result:** ✅ v41 app continues working (reads plaintext)

**Test 3.2: v41 → v42 Sync (Forward Compatibility)**
```
1. Device A: App v41 - create plaintext reminder
2. Sync to remote (uploads plaintext only)
3. Device B: App v42 - sync from remote
4. Verify Device B handles plaintext:
   - Stores plaintext in `title` field
   - `title_encrypted` = null
   - `encryption_version` = null
   - On next access, lazy encryption triggers
```

**Expected Result:** ✅ v42 app accepts plaintext and encrypts lazily

**Test 3.3: Conflict Resolution**
```
1. Device A (v42): Create reminder "Meeting at 2pm"
2. Go offline
3. Device B (v42): Edit same reminder to "Meeting at 3pm"
4. Sync Device B
5. Device A: Go online and sync
6. Verify conflict resolution:
   - Uses `createdAt` timestamp for resolution
   - Winner reminder is encrypted
   - Loser reminder data not leaked
```

**Expected Result:** ✅ Conflict resolved, encryption maintained

---

### Phase 4: Security Validation

**Test 4.1: Encryption Uniqueness**
```
1. Create two reminders with identical content: "Daily standup"
2. Verify in database:
   - `title_encrypted` values are DIFFERENT (unique per reminder)
   - No pattern reveals identical content
```

**Expected Result:** ✅ Same plaintext encrypts to different ciphertext

**Test 4.2: Decryption Requires User Key**
```
1. Create encrypted reminder
2. Export encrypted blob from database
3. Attempt to decrypt without user's master key
4. Verify decryption fails
```

**Expected Result:** ✅ Encrypted data unreadable without user key

**Test 4.3: Encryption Failure Graceful Degradation**
```
1. Mock CryptoBox to throw exception
2. Create reminder
3. Verify:
   - Reminder still created (plaintext)
   - `encryption_version` = null
   - Error logged but app continues
```

**Expected Result:** ✅ App degrades gracefully, reminder still functional

**Test 4.4: Backend Admin Cannot Read Reminders**
```
1. Create encrypted reminder: "Bank PIN reminder: 1234"
2. Connect to Supabase database as admin
3. Query reminders table
4. Verify:
   - `title` = "Bank PIN reminder: 1234" (temporary, will be removed in future migration)
   - `title_enc` = <unreadable blob>
   - Admin cannot decrypt `title_enc`
```

**Expected Result:** ✅ Encrypted field unreadable by backend (zero-knowledge architecture)

---

### Phase 5: Performance & Reliability

**Test 5.1: Encryption Performance**
```
1. Create 100 reminders in quick succession
2. Measure time to encrypt each
3. Verify encryption overhead < 50ms per reminder
```

**Expected Result:** ✅ Negligible performance impact

**Test 5.2: Large Reminder Content**
```
1. Create reminder with large body (2000 characters)
2. Verify encryption succeeds
3. Verify sync succeeds
4. Verify decryption succeeds
```

**Expected Result:** ✅ Handles large content without issues

**Test 5.3: Migration at Scale**
```
1. Create 1000 plaintext reminders
2. Upgrade to v42
3. Verify migration completes quickly (< 5 seconds)
4. Verify no OOM errors
```

**Expected Result:** ✅ Handles large datasets efficiently

**Test 5.4: Network Failure During Encrypted Sync**
```
1. Create encrypted reminder
2. Start sync
3. Disconnect network mid-sync
4. Verify:
   - Local reminder remains encrypted
   - Retry sync succeeds when network returns
   - No data corruption
```

**Expected Result:** ✅ Resilient to network failures

---

## Automated Test Coverage

### Unit Tests (`test/services/reminder_encryption_test.dart`)

**Status:** ⚠️ In Progress (mock configuration issues)

**Test Cases:**
- ✅ `ReminderConfig.toCompanionWithEncryption()` encrypts all fields
- ✅ `toCompanionWithEncryption()` handles null CryptoBox gracefully
- ⚠️ `toCompanionWithEncryption()` continues with plaintext on encryption error
- ⚠️ `decryptReminderFields()` prefers encrypted data when available
- ⚠️ `decryptReminderFields()` falls back to plaintext on decryption error
- ⚠️ `decryptReminderFields()` returns plaintext when no encrypted data
- ⚠️ `ensureReminderEncrypted()` encrypts plaintext reminder
- ✅ `ensureReminderEncrypted()` skips already encrypted reminder
- ✅ `ensureReminderEncrypted()` returns false when no CryptoBox
- ⚠️ `ensureReminderEncrypted()` handles user mismatch
- ⚠️ `getRemindersForNote()` triggers lazy encryption in background

**Action Required:** Fix Mockito stub configuration for CryptoBox methods

### Integration Tests (`test/services/reminder_encryption_integration_test.dart`)

**Status:** ⚠️ Created - pending compilation fix

**Test Cases:**
- ✅ Upload: encrypts reminder before sending to remote
- ✅ Download: decrypts encrypted reminder from remote
- ✅ Backward compatibility: handles plaintext-only reminders
- ✅ Sync round-trip: upload encrypted, download decrypted
- ✅ Migration progress: tracks encryption adoption

**Action Required:** Fix import conflicts (`isNull` from drift vs matcher)

---

## Rollout Plan

### Stage 1: Internal Testing (Week 1)
- Manual testing following Phase 1-5 checklist
- Verify unit tests pass
- Verify integration tests pass
- Performance benchmarking

### Stage 2: Beta Release (Week 2)
- Deploy to 10% of users
- Monitor encryption adoption rate
- Track lazy encryption performance
- Monitor error rates

### Stage 3: Gradual Rollout (Week 3-4)
- 25% → 50% → 75% → 100% over 2 weeks
- Monitor migration progress query
- Target: 95%+ encryption adoption within 30 days

### Stage 4: Cleanup (Week 5+)
- After 95%+ adoption, plan Migration v43:
  - Drop plaintext columns (`title`, `body`, `location_name`)
  - Make encrypted columns non-nullable
  - Enforce `encryption_version = 1`

---

## Rollback Plan

**If Critical Issues Occur:**

1. **Rollback to v41:**
   ```sql
   -- Revert to reading plaintext fields only
   -- No data loss - plaintext columns still intact
   ```

2. **Database Cleanup (if needed):**
   ```sql
   ALTER TABLE note_reminders
     DROP COLUMN IF EXISTS title_encrypted,
     DROP COLUMN IF EXISTS body_encrypted,
     DROP COLUMN IF EXISTS location_name_encrypted,
     DROP COLUMN IF EXISTS encryption_version;
   ```

3. **Supabase Cleanup:**
   ```sql
   ALTER TABLE reminders
     DROP COLUMN IF EXISTS title_enc,
     DROP COLUMN IF EXISTS body_enc,
     DROP COLUMN IF EXISTS location_name_enc,
     DROP COLUMN IF EXISTS encryption_version;
   ```

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Migration Success Rate | > 99.9% | Monitor app logs |
| Encryption Adoption (30 days) | > 95% | Query `encryption_version` |
| Sync Error Rate | < 0.1% | Monitor Sentry |
| Encryption Performance | < 50ms | Profile encryption calls |
| Zero Data Loss | 100% | Compare reminder counts pre/post migration |

---

## Known Issues & Limitations

1. **Test Suite Status:**
   - Unit tests need Mockito configuration fixes
   - Integration tests need import conflict resolution
   - **ETA to fix:** 2-4 hours of focused work

2. **Temporary Dual Storage:**
   - Reminders stored in BOTH plaintext and encrypted formats
   - Increases database size by ~2x for reminder data
   - Will be cleaned up in future migration after 95%+ adoption

3. **Backend Visibility:**
   - Backend admins can still see plaintext during transition period
   - Zero-knowledge architecture achieved only after plaintext columns dropped
   - Target: Complete zero-knowledge within 60 days

---

## Related Documentation

- **Migration Implementation:** `/lib/data/migrations/migration_42_reminder_encryption.dart`
- **Supabase Migration:** `/supabase/migrations/20251118120000_add_reminder_encryption_columns.sql`
- **Sync Service Changes:** `/lib/services/unified_sync_service.dart` (lines 2252-2495)
- **Reminder Services:** `/lib/services/reminders/base_reminder_service.dart` (lines 207-358)
- **Error Handling Standard:** `/MasterImplementation Phases/SYNC_ERROR_HANDLING_STANDARD.md`

---

## Change Log

- **2025-11-18:** Initial implementation complete
- **2025-11-18:** Test instructions created
- **2025-11-18:** Unit tests written (pending fixes)
- **2025-11-18:** Integration tests created (pending fixes)

---

## Contact

For questions or issues with Migration v42:
- Review this document first
- Check related documentation
- Test locally following manual checklist
- Report issues with full test results and logs
