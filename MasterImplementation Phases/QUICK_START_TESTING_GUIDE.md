# Quick Start Testing Guide - Soft Delete & GDPR

**Your app is running on iPhone "O"**
**Current User**: test82@test.com
**User ID**: 05a1e86f-5d86-4462-bcaf-a5a3f1be73d0

---

## 🎯 What You Can Test Right Now

### Option 1: Test Soft Delete (Safe - Recommended First)

**This is safe to test with your current account!**

#### Step 1: Delete a Note
1. In your running app, find any note
2. Swipe left or long-press on it
3. Tap "Delete"
4. ✅ Note should disappear from the list

-- OK DELETED ✅ 

#### Step 2: View Trash
1. Open Settings (tap gear icon)
2. Look for "Trash" section
3. You should see your deleted note there

-- OK I See 2 deleted Note in Trash ✅ 

#### Step 3: Restore a Note
1. In Trash, find the deleted note
2. Tap "Restore"
3. ✅ Note should reappear in your main list

-- OK Restored ✅ 

#### Step 4: Permanently Delete
1. Delete a note again (moves to trash)
2. In Trash, select the note
3. Tap "Permanently Delete"
4. Confirm
5. ✅ Note is GONE forever (actual deletion from database)

OK Deleted ✅ 

---

### Option 2: Test GDPR Anonymization (⚠️ IRREVERSIBLE)

**⚠️ WARNING: DO NOT TEST WITH YOUR MAIN ACCOUNT!**

The GDPR anonymization is **IRREVERSIBLE** after Phase 3. Here's the safe approach:

#### Recommended: Create Test Account First

**Step 1: Create Test Account**
1. In your current app, tap Profile/Settings
2. Find "Sign Out" or "Logout"
3. Create new account: `gdpr-test@test.com` (or any test email)
4. Complete onboarding

**Step 2: Add Sample Data to Test Account**
Create some test data:
- 5 notes with different content
- 3-5 tasks
- 2 folders
- Some tags

**Step 3: Access GDPR Anonymization**
1. Open Settings (gear icon in app)
2. Scroll down to find **"GDPR Anonymization"** section
3. Tap on "GDPR Anonymization"

**Step 4: Read and Confirm**
You'll see a dialog with warnings:
- ⚠️ This action is irreversible
- ⚠️ All your data will be permanently anonymized
- ⚠️ You'll be logged out of all devices

**Step 5: Complete Confirmations**
Check all required boxes:
- ✅ "I have backed up my data"
- ✅ "I understand this is irreversible"
- Enter confirmation token (format: `ANONYMIZE_ACCOUNT_yourUserId`)

**Step 6: Monitor Progress**
Watch the progress indicator go through all 7 phases:
- Phase 1: Validation (0-14%)
- Phase 2: Account Anonymization (14-28%)
- Phase 3: Key Destruction ⚠️ **POINT OF NO RETURN** (28-42%)
- Phase 4: Content Tombstoning (42-57%)
- Phase 5: Metadata Clearing (57-71%)
- Phase 6: Sync Invalidation (71-85%)
- Phase 7: Compliance Proof (85-100%)

**Step 7: View Compliance Certificate**
- ✅ Certificate appears automatically
- Contains all phase details
- Shows anonymization ID
- Shows key destruction report
- Can be exported/saved

---

## 🔍 Verify Results in Database

After testing GDPR anonymization, run these queries in Supabase Dashboard → SQL Editor:

### Query 1: Verify Profile Anonymized
```sql
SELECT
  id,
  email,
  display_name,
  password_hint
FROM user_profiles
WHERE id = 'your-test-user-id';
```

**Expected**: Email like `anon_12345678@anonymized.local`

### Query 2: Verify Content Tombstoned
```sql
SELECT
  id,
  encrypted_title,
  length(encrypted_title) as title_length
FROM notes
WHERE user_id = 'your-test-user-id'
LIMIT 5;
```

**Expected**: Random bytes, not original encrypted data

### Query 3: Verify Metadata Cleared
```sql
-- Should all return 0
SELECT COUNT(*) FROM tags WHERE user_id = 'your-test-user-id';
SELECT COUNT(*) FROM saved_searches WHERE user_id = 'your-test-user-id';
```

### Query 4: Verify Audit Trail
```sql
SELECT
  phase_number,
  event_type,
  details,
  created_at
FROM anonymization_events
WHERE user_id = 'your-test-user-id'
ORDER BY phase_number;
```

**Expected**: 7 phase completion events

### Query 5: Verify Compliance Proof
```sql
SELECT
  anonymization_id,
  user_id_hash,
  created_at,
  verify_proof_integrity(anonymization_id) as is_valid
FROM anonymization_proofs
WHERE user_id_hash = encode(sha256(convert_to('your-test-user-id', 'UTF8')), 'hex');
```

**Expected**: Proof record with `is_valid = true`

---

## 📊 Quick Database Checks

### Check GDPR Functions Deployed
```sql
SELECT proname
FROM pg_proc
WHERE proname LIKE '%anonymize%' OR proname LIKE '%gdpr%'
ORDER BY proname;
```

**Expected**: 15+ functions listed

### Check GDPR Tables Deployed
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('anonymization_events', 'anonymization_proofs', 'key_revocation_events');
```

**Expected**: All 3 tables listed

### Check Current Soft-Deleted Items
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
  AND deleted_at IS NOT NULL;
```

---

## 🎬 Recommended Testing Order

### Phase 1: Soft Delete Testing (30 minutes)
1. ✅ Test note deletion (your current account is safe)
2. ✅ Test note restoration
3. ✅ Test permanent deletion
4. ✅ Test task deletion
5. ✅ Verify trash view

### Phase 2: Database Verification (15 minutes)
1. ✅ Run verification queries in Supabase
2. ✅ Verify GDPR functions exist
3. ✅ Verify GDPR tables exist
4. ✅ Check soft-deleted items count

### Phase 3: GDPR Testing (45 minutes)
1. ✅ Create test account (gdpr-test@test.com)
2. ✅ Add sample data
3. ✅ Run GDPR anonymization
4. ✅ Monitor all 7 phases
5. ✅ Save compliance certificate
6. ✅ Verify results in database

---

## ✅ Success Checklist

After completing all tests, you should have:

**Soft Delete:**
- ✅ Successfully deleted items
- ✅ Successfully restored items
- ✅ Successfully permanently deleted items
- ✅ Trash view working

**GDPR:**
- ✅ Test account anonymized
- ✅ All 7 phases completed
- ✅ Compliance certificate generated
- ✅ Database verification confirms:
  - Profile anonymized
  - Content tombstoned
  - Metadata cleared
  - Audit trail complete
  - Proof valid

---

## 🐛 Troubleshooting

### Issue: Cannot Find "GDPR Anonymization" in Settings
**Solution**: Look in Settings screen, should be near bottom. Search for red text or look for "Privacy & Data" section.

### Issue: Confirmation Token Format?
**Format**: `ANONYMIZE_ACCOUNT_yourUserId`
**Example**: `ANONYMIZE_ACCOUNT_05a1e86f-5d86-4462-bcaf-a5a3f1be73d0`

### Issue: Where is My User ID?
**In App**: Usually in Profile or Account Settings
**In Database**: Run `SELECT id FROM auth.users WHERE email = 'your-email@test.com';`

### Issue: Phase 3 Failed
**Check**: Encryption key access, KeyManager initialization
**Logs**: Look for errors in console output

### Issue: Cannot See Deleted Items in Trash
**Check**: Trash view implementation
**Query**: Run soft-delete verification queries

---

## 📁 Documentation Files Reference

Detailed guides created for you:

1. **TESTING_PLAN_SOFT_DELETE_AND_GDPR.md** - Complete test plan with all scenarios
2. **GDPR_VERIFICATION_QUERIES.sql** - All SQL queries for verification
3. **DEPLOYMENT_SUCCESS_REPORT.md** - Deployment details and verification
4. **QUICK_START_TESTING_GUIDE.md** - This file

All located in: `/Users/onronder/duru-notes/MasterImplementation Phases/`

---

## 🚀 Ready to Start!

Your app is running, database is deployed, and everything is ready for testing.

**Recommended First Step**: Test soft delete with your current account (safe!)

**Next Step**: Create test account and run GDPR anonymization

**Remember**: GDPR anonymization is **IRREVERSIBLE** - use a test account!

---

Good luck with testing! 🎉
