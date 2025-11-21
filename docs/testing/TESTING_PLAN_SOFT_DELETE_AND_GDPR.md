# Soft Delete & GDPR - Comprehensive Testing Plan

**Date**: November 20, 2025
**Test User**: test82@test.com
**User ID**: 05a1e86f-5d86-4462-bcaf-a5a3f1be73d0
**Status**: Ready for Testing

---

## 🎯 Testing Overview

This document provides a step-by-step testing plan for all soft-delete and GDPR anonymization features.

---

## Part 1: Soft Delete Feature Testing

### Test Suite 1.1: Notes Soft Delete

**Objective**: Verify notes can be soft-deleted, viewed in trash, restored, and permanently deleted

#### Test Case 1.1.1: Soft Delete a Note
**Steps**:
1. Open the app (already running with 10 notes)
2. Long-press on a note or swipe to delete
3. Select "Delete" option

**Expected Results**:
- ✅ Note disappears from main list
- ✅ Note is NOT permanently deleted from database
- ✅ Note has `deleted_at` timestamp set
- ✅ Note appears in Trash

**Verification Query**:
```sql
SELECT id, title, deleted_at, is_deleted
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL;
```

#### Test Case 1.1.2: View Trash
**Steps**:
1. Navigate to Settings → Trash (or Trash section)
2. View list of deleted notes

**Expected Results**:
- ✅ Deleted note appears in trash list
- ✅ Shows deletion date
- ✅ Shows restore option
- ✅ Shows permanent delete option

#### Test Case 1.1.3: Restore from Trash
**Steps**:
1. In Trash view, select a deleted note
2. Tap "Restore" button

**Expected Results**:
- ✅ Note reappears in main notes list
- ✅ `deleted_at` is set to NULL
- ✅ `is_deleted` is set to false
- ✅ Note disappears from Trash

**Verification Query**:
```sql
SELECT id, title, deleted_at, is_deleted
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND id = 'note-id-here';
```

#### Test Case 1.1.4: Permanent Delete
**Steps**:
1. Delete a note (moves to trash)
2. In Trash view, select the note
3. Tap "Permanently Delete" button
4. Confirm deletion

**Expected Results**:
- ✅ Confirmation dialog appears
- ✅ After confirmation, note is ACTUALLY deleted from database
- ✅ Note disappears from trash
- ✅ Cannot be restored

**Verification Query**:
```sql
-- Should return 0 rows
SELECT COUNT(*)
FROM notes
WHERE id = 'deleted-note-id';
```

---

### Test Suite 1.2: Tasks Soft Delete

#### Test Case 1.2.1: Soft Delete a Task
**Steps**:
1. Navigate to Tasks section
2. Delete a task

**Expected Results**:
- ✅ Task moves to trash
- ✅ `deleted_at` timestamp set
- ✅ Task disappears from active tasks

#### Test Case 1.2.2: Restore Task
**Steps**:
1. Navigate to Trash
2. Find deleted task
3. Restore it

**Expected Results**:
- ✅ Task reappears in active tasks
- ✅ All task properties preserved (due date, priority, etc.)

---

### Test Suite 1.3: Folders Soft Delete

#### Test Case 1.3.1: Soft Delete a Folder
**Steps**:
1. Navigate to Folders
2. Delete a folder (with or without notes)

**Expected Results**:
- ✅ Folder moves to trash
- ✅ Notes in folder are NOT deleted (if applicable)
- ✅ Folder can be restored

---

### Test Suite 1.4: Reminders Soft Delete

#### Test Case 1.4.1: Soft Delete a Reminder
**Steps**:
1. Create or view a reminder
2. Delete the reminder

**Expected Results**:
- ✅ Reminder soft-deleted
- ✅ Can be restored from trash

---

## Part 2: GDPR Anonymization Testing

### ⚠️ CRITICAL WARNING ⚠️

**GDPR anonymization is IRREVERSIBLE after Phase 3 (Key Destruction)**

**DO NOT test GDPR with your main account!**

**Recommended Approach**:
1. Create a dedicated test account: `gdpr-test@test.com`
2. Add sample data to that account
3. Run anonymization on the test account
4. Verify results
5. Account will be permanently anonymized

---

### Test Suite 2.1: Pre-Anonymization Setup

#### Test Case 2.1.1: Create Test Account
**Steps**:
1. Log out of current account
2. Create new account: `gdpr-test@test.com`
3. Complete onboarding

#### Test Case 2.1.2: Create Sample Data
**Steps**:
Create the following test data:
- 5 notes with different content
- 5 tasks with different due dates
- 2 folders
- 3 tags (applied to notes)
- 2 saved searches
- 3 reminders

**Purpose**: This data will be used to verify anonymization works across all tables

---

### Test Suite 2.2: GDPR Anonymization Flow

#### Test Case 2.2.1: Access GDPR Settings
**Steps**:
1. Navigate to Settings
2. Look for "Privacy & Data" or "Account Deletion" section
3. Find "Anonymize My Data" or similar option

**Expected Results**:
- ✅ GDPR option is visible
- ✅ Clear explanation of what will happen
- ✅ Warning about irreversibility

#### Test Case 2.2.2: Initiate Anonymization
**Steps**:
1. Tap "Anonymize My Data"
2. Read all warnings and confirmations
3. Check all required confirmations:
   - ✅ "I have backed up my data"
   - ✅ "I understand this is irreversible"
4. Enter confirmation token (if required)
5. Confirm final dialog

**Expected Results**:
- ✅ Confirmation dialogs appear
- ✅ Cannot proceed without all confirmations
- ✅ Progress indicator appears

#### Test Case 2.2.3: Monitor Phase Progress
**Expected Progress Indicators**:

**Phase 1: Pre-Anonymization Validation** (0-14%)
- Status: "Validating user identity and consent..."
- Duration: ~10ms

**Phase 2: Account Metadata Anonymization** (14-28%)
- Status: "Anonymizing account metadata..."
- Duration: ~5ms
- Result: Email becomes `anon_xxxxxxxx@anonymized.local`

**Phase 3: Encryption Key Destruction** ⚠️ POINT OF NO RETURN (28-42%)
- Status: "Destroying encryption keys..."
- Duration: ~500ms
- Result: All encryption keys permanently destroyed

**Phase 4: Encrypted Content Tombstoning** (42-57%)
- Status: "Overwriting encrypted content..."
- Duration: ~50-500ms (depends on data size)
- Result: All encrypted data replaced with random bytes

**Phase 5: Unencrypted Metadata Clearing** (57-71%)
- Status: "Clearing metadata..."
- Duration: ~50-500ms
- Result: Tags, searches, preferences deleted

**Phase 6: Cross-Device Sync Invalidation** (71-85%)
- Status: "Invalidating keys on other devices..."
- Duration: ~10ms
- Result: Key revocation event created

**Phase 7: Final Audit Trail & Compliance Proof** (85-100%)
- Status: "Generating compliance proof..."
- Duration: ~20ms
- Result: Immutable compliance proof stored

#### Test Case 2.2.4: Completion and Certificate
**Expected Results**:
- ✅ Progress reaches 100%
- ✅ Success message appears
- ✅ Compliance certificate is generated
- ✅ Certificate contains:
  - Anonymization ID
  - All phase completion status
  - Timestamps
  - Key destruction report
  - Total items processed
- ✅ Option to export/save certificate

---

### Test Suite 2.3: Post-Anonymization Verification

#### Test Case 2.3.1: Verify Profile Anonymization
**Verification Query**:
```sql
SELECT
  id,
  email,
  display_name,
  password_hint
FROM user_profiles
WHERE id = 'test-user-id';
```

**Expected Results**:
- ✅ Email: `anon_12345678@anonymized.local` (8 random chars)
- ✅ Display Name: NULL or anonymized
- ✅ Password Hint: NULL

#### Test Case 2.3.2: Verify Content Tombstoning
**Verification Query**:
```sql
-- Check notes
SELECT
  id,
  encrypted_title,
  encrypted_content,
  length(encrypted_title) as title_length,
  length(encrypted_content) as content_length
FROM notes
WHERE user_id = 'test-user-id'
LIMIT 5;
```

**Expected Results**:
- ✅ `encrypted_title` contains random bytes (not original encrypted data)
- ✅ `encrypted_content` contains random bytes
- ✅ Length might be different (random bytes)
- ✅ Cannot be decrypted (keys destroyed)

#### Test Case 2.3.3: Verify Metadata Clearing
**Verification Queries**:
```sql
-- Should all return 0
SELECT COUNT(*) FROM tags WHERE user_id = 'test-user-id';
SELECT COUNT(*) FROM saved_searches WHERE user_id = 'test-user-id';
SELECT COUNT(*) FROM user_preferences WHERE user_id = 'test-user-id';
SELECT COUNT(*) FROM notification_events WHERE user_id = 'test-user-id';
```

**Expected Results**:
- ✅ All counts = 0

#### Test Case 2.3.4: Verify Audit Trail
**Verification Query**:
```sql
SELECT
  event_type,
  phase_number,
  details,
  created_at
FROM anonymization_events
WHERE user_id = 'test-user-id'
ORDER BY phase_number;
```

**Expected Results**:
- ✅ 7 phase completion events
- ✅ Each phase has details
- ✅ Timestamps in order
- ✅ All phases show success

#### Test Case 2.3.5: Verify Compliance Proof
**Verification Query**:
```sql
SELECT
  anonymization_id,
  user_id_hash,
  proof_hash,
  proof_data,
  created_at
FROM anonymization_proofs
WHERE user_id_hash = encode(sha256(convert_to('test-user-id', 'UTF8')), 'hex');
```

**Expected Results**:
- ✅ Proof record exists
- ✅ Contains all phase reports in `proof_data`
- ✅ `proof_hash` matches computed hash
- ✅ Timestamp recorded

#### Test Case 2.3.6: Verify Proof Integrity
**Verification Query**:
```sql
SELECT verify_proof_integrity('anonymization-id-here');
```

**Expected Results**:
- ✅ Returns `true` (proof has not been tampered with)

#### Test Case 2.3.7: Verify Key Revocation Event
**Verification Query**:
```sql
SELECT
  reason,
  anonymization_id,
  key_type,
  created_at
FROM key_revocation_events
WHERE user_id = 'test-user-id';
```

**Expected Results**:
- ✅ Reason: `GDPR_ANONYMIZATION`
- ✅ Anonymization ID matches
- ✅ Key type: `all` or NULL
- ✅ Timestamp recorded

---

## Part 3: Edge Cases and Error Scenarios

### Test Suite 3.1: Edge Cases

#### Test Case 3.1.1: Anonymize User with No Data
**Steps**:
1. Create new test account
2. Do NOT create any data
3. Immediately run anonymization

**Expected Results**:
- ✅ All phases complete successfully
- ✅ Phase 4-5 report 0 items processed
- ✅ Compliance certificate still generated

#### Test Case 3.1.2: Anonymize User with Large Dataset
**Steps**:
1. Create account with 100+ notes, 50+ tasks
2. Run anonymization

**Expected Results**:
- ✅ All phases complete successfully
- ✅ Performance acceptable (<10 seconds total)
- ✅ All items tombstoned

#### Test Case 3.1.3: Restore After Soft Delete
**Steps**:
1. Delete a note (soft delete)
2. Restore from trash
3. Verify note is fully functional

**Expected Results**:
- ✅ Note restored correctly
- ✅ All content accessible
- ✅ Can edit and save

---

### Test Suite 3.2: Error Scenarios

#### Test Case 3.2.1: Invalid Confirmation Token
**Steps**:
1. Start anonymization
2. Enter wrong confirmation token

**Expected Results**:
- ✅ Error message shown
- ✅ Anonymization does NOT proceed
- ✅ Can retry with correct token

#### Test Case 3.2.2: Network Interruption (Manual Simulation)
**This test requires database access to simulate failure**

**Simulation**:
1. Start anonymization
2. Temporarily disable network during Phase 4 or 5

**Expected Results**:
- ✅ Error caught and logged
- ✅ Phase marked as failed in audit trail
- ✅ User can see error message
- ⚠️ Note: After Phase 3, keys are destroyed, so this is expected behavior

---

## Part 4: Regression Testing

### Test Suite 4.1: Verify Non-GDPR Features Still Work

After GDPR deployment, verify these features still work:

#### Test Case 4.1.1: Normal Note Creation
**Steps**:
1. Create a new note
2. Add content
3. Save

**Expected Results**:
- ✅ Note created successfully
- ✅ Content encrypted properly
- ✅ Note appears in list

#### Test Case 4.1.2: Sync Functionality
**Steps**:
1. Create note on device A
2. Check device B (if available)

**Expected Results**:
- ✅ Note syncs across devices
- ✅ Real-time updates work

#### Test Case 4.1.3: Search Functionality
**Steps**:
1. Search for existing notes

**Expected Results**:
- ✅ Search works correctly
- ✅ Results are accurate

---

## Part 5: Database Direct Verification

### Verification Queries for Current User (test82@test.com)

You can run these queries in Supabase Dashboard → SQL Editor:

#### Query 1: Check Soft-Deleted Items
```sql
SELECT
  'notes' as type, COUNT(*) as count
FROM notes
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'tasks' as type, COUNT(*) as count
FROM tasks
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'folders' as type, COUNT(*) as count
FROM folders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL

UNION ALL

SELECT
  'reminders' as type, COUNT(*) as count
FROM reminders
WHERE user_id = '05a1e86f-5d86-4462-bcaf-a5a3f1be73d0'
  AND deleted_at IS NOT NULL;
```

#### Query 2: Test GDPR Functions (Read-Only)
```sql
-- Test profile anonymization status check (safe, does not modify)
SELECT * FROM get_profile_anonymization_status('05a1e86f-5d86-4462-bcaf-a5a3f1be73d0');

-- This should return: fully_anonymized = false (since we haven't anonymized yet)
```

---

## Test Execution Checklist

### Phase 1: Soft Delete Testing
- [ ] Test note soft delete
- [ ] Test note restore
- [ ] Test note permanent delete
- [ ] Test task soft delete
- [ ] Test folder soft delete
- [ ] Test reminder soft delete
- [ ] Verify trash view shows all deleted items
- [ ] Verify deletion timestamps are correct

### Phase 2: GDPR Testing Setup
- [ ] Create dedicated test account (gdpr-test@test.com)
- [ ] Add sample data (notes, tasks, folders, tags, searches)
- [ ] Document test user ID for verification queries

### Phase 3: GDPR Anonymization Execution
- [ ] Access GDPR settings in UI
- [ ] Read all warnings and confirmations
- [ ] Execute anonymization
- [ ] Monitor all 7 phases
- [ ] Verify progress indicators
- [ ] Save compliance certificate

### Phase 4: GDPR Verification
- [ ] Query database to verify profile anonymized
- [ ] Verify content tombstoned (random bytes)
- [ ] Verify metadata cleared
- [ ] Verify audit trail complete
- [ ] Verify compliance proof stored
- [ ] Verify proof integrity
- [ ] Verify key revocation event

### Phase 5: Edge Cases
- [ ] Test anonymization with no data
- [ ] Test anonymization with large dataset
- [ ] Test invalid confirmation token
- [ ] Verify error handling

### Phase 6: Regression Testing
- [ ] Verify normal features still work
- [ ] Test note creation
- [ ] Test sync
- [ ] Test search
- [ ] Test encryption/decryption

---

## Success Criteria

### Soft Delete Features ✅
- All items can be soft-deleted
- All items can be restored from trash
- Permanent delete actually deletes from database
- Trash view shows all deleted items

### GDPR Features ✅
- All 7 phases complete successfully
- User profile anonymized
- All encrypted content tombstoned
- All metadata cleared
- Audit trail complete
- Compliance certificate generated
- Proof integrity verifiable

### Regression Testing ✅
- No existing features broken
- Normal CRUD operations work
- Sync works
- Encryption works

---

## Troubleshooting Guide

### Issue: Cannot Find GDPR Option in Settings
**Solution**:
- Check if `lib/ui/settings_screen.dart` was deployed
- Verify feature flag enabled (if applicable)
- Check user permissions

### Issue: Anonymization Fails at Phase 3
**Solution**:
- Check encryption key access
- Verify KeyManager is initialized
- Check logs for specific error

### Issue: Phase 4/5 Times Out
**Solution**:
- Check dataset size
- Verify database connection
- Run during off-peak hours

### Issue: Compliance Certificate Not Generated
**Solution**:
- Check Phase 7 logs
- Verify anonymization_proofs table permissions
- Check proof_data generation

---

## Reporting Results

After completing all tests, document:
1. ✅/❌ for each test case
2. Screenshots of key steps
3. Database query results
4. Any errors encountered
5. Performance metrics (time for each phase)
6. Compliance certificate screenshot

---

**Testing Guide Version**: 1.0
**Last Updated**: November 20, 2025
**Status**: Ready for Execution
