# GDPR Anonymization - Testing Guide

**Document Version**: 1.0
**Date**: November 21, 2025
**Environment**: Development & Production

---

## Table of Contents

1. [Pre-Test Checklist](#pre-test-checklist)
2. [Test Account Setup](#test-account-setup)
3. [Test Scenarios](#test-scenarios)
4. [Validation Steps](#validation-steps)
5. [Expected Results](#expected-results)
6. [Rollback Procedures](#rollback-procedures)

---

## Pre-Test Checklist

### Prerequisites

- [ ] Database migration deployed successfully
- [ ] Edge Function deployed and accessible
- [ ] Service role key configured in Supabase
- [ ] Flutter app built with latest changes
- [ ] Backup of test database available

### Environment Setup

```bash
# 1. Verify database migration
supabase db pull

# 2. Check Edge Function deployment
supabase functions list

# 3. Verify service role key
supabase secrets list | grep SUPABASE_SERVICE_ROLE_KEY

# 4. Test database connection
supabase db execute "SELECT * FROM user_profiles LIMIT 1;"
```

---

## Test Account Setup

### Option 1: Create Fresh Test Account

```bash
# Use a disposable email service (e.g., temp-mail.org)
Test Email: gdpr-test-2025@temp-mail.org
Password: TestPassword123!
```

**Steps**:
1. Sign up via the app
2. Verify email (check inbox)
3. Create test data:
   - 5+ notes
   - 3+ folders
   - 2+ tasks
   - 1+ reminder
4. Sync data to ensure it's in database

### Option 2: Use Existing Test Account

**⚠️ WARNING**: This account will be permanently deleted. Use only test accounts.

```
Email: test-user@example.com
Password: [your test password]
```

---

## Test Scenarios

### Scenario 1: Happy Path (Complete Anonymization)

**Objective**: Verify complete anonymization workflow works end-to-end

**Steps**:

1. **Login as test user**
   ```
   Email: gdpr-test-2025@temp-mail.org
   Password: TestPassword123!
   ```

2. **Navigate to Settings → Account → Delete Account**

3. **Complete confirmations**:
   ```
   ✓ I have backed up my important data
   ✓ I understand this action is irreversible
   ✓ I acknowledge all risks
   Final Confirmation: DELETE MY ACCOUNT
   ✓ Allow production override (if in production)
   ```

4. **Initiate anonymization**
   - Click "Delete My Account" button
   - Monitor progress through all 7 phases
   - Expected duration: ~20 seconds

5. **Verify automatic logout**
   - App should automatically sign you out
   - You should see the login screen

6. **Attempt to login again**
   - Use same credentials
   - Expected: "Account Deleted" dialog
   - Expected: Cannot access any data

**Expected Results**:
- ✅ All phases complete successfully
- ✅ User automatically logged out
- ✅ Cannot login again
- ✅ All data inaccessible

### Scenario 2: Safeguard Validation (Rate Limiting)

**Objective**: Verify rate limiting prevents rapid attempts

**Steps**:

1. **Attempt anonymization** (follow Scenario 1)

2. **Create another test account** immediately

3. **Attempt anonymization again** within 24 hours

4. **Expected error**:
   ```
   Rate limit exceeded. You must wait X hours and Y minutes
   before attempting anonymization again.
   ```

**Expected Results**:
- ✅ Second attempt blocked by rate limiting
- ✅ Error message shows remaining cooldown time
- ✅ Attempt recorded in anonymization_events table

### Scenario 3: Unverified Email Block

**Objective**: Verify email verification is required

**Steps**:

1. **Create new account** but DO NOT verify email

2. **Attempt anonymization**

3. **Expected error**:
   ```
   Email address must be verified before account deletion.
   Please verify your email and try again.
   ```

**Expected Results**:
- ✅ Anonymization blocked
- ✅ Email verification required
- ✅ User can verify email and retry

### Scenario 4: Production Safety Check

**Objective**: Verify production environment protection

**Prerequisites**: App built in production mode (`flutter build --release`)

**Steps**:

1. **Attempt anonymization WITHOUT production override**
   ```dart
   final confirmations = UserConfirmations(
     dataBackupComplete: true,
     understandsIrreversibility: true,
     finalConfirmationToken: 'DELETE MY ACCOUNT',
     acknowledgesRisks: true,
     allowProductionOverride: false, // ← No override
   );
   ```

2. **Expected error**:
   ```
   GDPR anonymization in PRODUCTION requires explicit override.
   This is a critical operation that cannot be undone.
   ```

3. **Retry WITH production override**
   ```dart
   allowProductionOverride: true, // ← Explicit override
   ```

4. **Expected**: Anonymization proceeds

**Expected Results**:
- ✅ First attempt blocked in production
- ✅ Second attempt succeeds with override
- ✅ Development environment not affected

### Scenario 5: RLS Policy Verification

**Objective**: Verify RLS blocks data access after anonymization

**Steps**:

1. **Complete anonymization** (Scenario 1)

2. **Verify RLS blocking via database**:
   ```sql
   -- Set context to anonymized user
   SET LOCAL role = 'authenticated';
   SET LOCAL request.jwt.claims = '{
     "sub": "anonymized-user-id-here",
     "role": "authenticated"
   }';

   -- Attempt to query data (should return 0 rows)
   SELECT * FROM notes WHERE user_id = 'anonymized-user-id-here';
   SELECT * FROM folders WHERE user_id = 'anonymized-user-id-here';
   SELECT * FROM note_tasks WHERE user_id = 'anonymized-user-id-here';
   ```

3. **Expected**: All queries return 0 rows

**Expected Results**:
- ✅ RLS blocks all SELECT queries
- ✅ RLS blocks INSERT/UPDATE/DELETE
- ✅ Even with valid (but expired) session token

### Scenario 6: Sync System Resilience

**Objective**: Verify sync doesn't crash when encountering anonymized data

**Steps**:

1. **Device A**: Complete anonymization

2. **Device B** (still logged in with old session):
   - Attempt to sync
   - Expected: Gracefully handles anonymized data
   - Expected: No crashes

3. **Check logs** for:
   ```
   Skipping remote folder with null ID (likely anonymized)
   Skipping remote note with null ID (likely anonymized)
   Skipping remote task with null ID (likely anonymized)
   ```

**Expected Results**:
- ✅ Sync completes without crashing
- ✅ Null IDs handled gracefully
- ✅ Warning logs generated

### Scenario 7: Edge Function Direct Test

**Objective**: Test Edge Function independently

**Steps**:

1. **Get user access token**:
   ```bash
   # Login via Supabase CLI
   supabase projects list
   supabase login
   ```

2. **Call Edge Function directly**:
   ```bash
   curl -X POST https://mizzxiijxtbwrqgflpnp.supabase.co/functions/v1/gdpr-delete-auth-user \
     -H "Authorization: Bearer USER_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "userId": "test-user-id-here",
       "anonymizationId": "test-anonymization-id",
       "environment": "development"
     }'
   ```

3. **Expected response**:
   ```json
   {
     "success": true,
     "userId": "test-user-id-here",
     "anonymizationId": "test-anonymization-id",
     "timestamp": "2025-11-21T...",
     "phases": {
       "appDataCleanup": true,
       "sessionRevocation": true,
       "authUserDeletion": true,
       "auditRecording": true
     }
   }
   ```

**Expected Results**:
- ✅ Edge Function executes successfully
- ✅ All phases return true
- ✅ Timestamps recorded

---

## Validation Steps

### 1. Database Validation

```sql
-- Check anonymization status
SELECT
  user_id,
  is_anonymized,
  anonymization_completed_at,
  auth_deletion_completed_at,
  anonymization_id
FROM user_profiles
WHERE email LIKE '%@anonymized.local';

-- Verify profile anonymization
SELECT
  user_id,
  email,
  first_name,
  last_name,
  passphrase_hint
FROM user_profiles
WHERE is_anonymized = true;

-- Expected:
-- email: anon_xxxxxxxx@anonymized.local
-- first_name: ANONYMIZED
-- last_name: USER
-- passphrase_hint: NULL

-- Check data tombstoning
SELECT
  id,
  title_enc,
  props_enc,
  LENGTH(title_enc) as title_length,
  LENGTH(props_enc) as props_length
FROM notes
WHERE user_id = 'anonymized-user-id-here';

-- Expected: All encrypted fields overwritten with random bytes

-- Verify RLS is active
SELECT COUNT(*) as rls_enabled_tables
FROM pg_policies
WHERE policyname = 'block_anonymized_users';

-- Expected: 10+ (one per table)

-- Check audit trail
SELECT
  event_type,
  phase_number,
  created_at,
  details
FROM anonymization_events
WHERE anonymization_id = 'test-anonymization-id'
ORDER BY created_at;

-- Expected: Events for all phases (0-7)
```

### 2. Auth Validation

```sql
-- Check auth.users deletion
SELECT id, email
FROM auth.users
WHERE id = 'anonymized-user-id-here';

-- Expected: 0 rows (user deleted from auth schema)

-- Verify sessions revoked
SELECT *
FROM auth.sessions
WHERE user_id = 'anonymized-user-id-here';

-- Expected: 0 rows (all sessions revoked)
```

### 3. Client-Side Validation

**Test login attempt**:
```dart
// Attempt login with anonymized account credentials
final response = await Supabase.instance.client.auth.signInWithPassword(
  email: 'gdpr-test-2025@temp-mail.org',
  password: 'TestPassword123!',
);

// Expected: AuthException (invalid login credentials)
```

**Test anonymization status check**:
```dart
// If somehow got a valid token (shouldn't happen)
final status = await _checkAnonymizationStatus();

// Expected: true (is_anonymized = true)
// Expected: "Account Deleted" dialog shown
// Expected: Force logout
```

### 4. Compliance Validation

```sql
-- Verify compliance proof
SELECT
  anonymization_id,
  user_id_hash,
  proof_hash,
  proof_data->>'timestamp' as proof_timestamp,
  created_at
FROM anonymization_proofs
WHERE anonymization_id = 'test-anonymization-id';

-- Expected: SHA-256 hash of all phase reports

-- Verify all required phases completed
SELECT
  proof_data->'phases'->'phase1'->>'success' as phase1,
  proof_data->'phases'->'phase2'->>'success' as phase2,
  proof_data->'phases'->'phase3'->>'success' as phase3,
  proof_data->'phases'->'phase4'->>'success' as phase4,
  proof_data->'phases'->'phase5'->>'success' as phase5,
  proof_data->'phases'->'phase6'->>'success' as phase6
FROM anonymization_proofs
WHERE anonymization_id = 'test-anonymization-id';

-- Expected: All phases = true
```

---

## Expected Results

### Success Criteria

| Test | Expected Outcome | Validation Method |
|------|-----------------|-------------------|
| **Complete Anonymization** | All 7 phases complete | Check compliance proof |
| **Auth Deletion** | Cannot login again | Attempt login |
| **RLS Blocking** | 0 rows returned | Database queries |
| **Session Revocation** | All sessions invalidated | Check auth.sessions |
| **Data Tombstoning** | Encrypted fields overwritten | Check notes/folders |
| **Client Protection** | Account Deleted dialog shown | Login attempt |
| **Sync Resilience** | No crashes on null IDs | Sync with anonymized data |
| **Rate Limiting** | 24h cooldown enforced | Rapid retry attempt |
| **Email Verification** | Unverified email blocked | Test with new account |
| **Production Safety** | Explicit override required | Production build test |

### Performance Benchmarks

| Phase | Expected Duration | Acceptable Range |
|-------|------------------|------------------|
| Safeguards | 1-2s | 0.5-5s |
| Phase 1 | 1s | 0.5-3s |
| Phase 2 | 1s | 0.5-3s |
| Phase 3 | 3-5s | 2-10s |
| Phases 4-6 (Edge Function) | 5-10s | 3-20s |
| Phase 7 | 2s | 1-5s |
| **Total** | **15-20s** | **10-45s** |

### Error Scenarios

| Scenario | Expected Error | Recovery |
|----------|---------------|----------|
| **Rate limit exceeded** | Cooldown message | Wait 24h or use different account |
| **Unverified email** | Email verification required | Verify email, retry |
| **Production without override** | Explicit override required | Add override flag |
| **Invalid confirmation token** | Token mismatch | Type "DELETE MY ACCOUNT" exactly |
| **Network timeout** | Edge Function timeout | Retry (idempotent) |
| **Session expired** | Unauthorized | Re-login, retry |

---

## Rollback Procedures

### If Anonymization Fails Mid-Process

**⚠️ CRITICAL**: Phase 3 is the Point of No Return. After Phase 3, rollback is impossible.

**Before Phase 3**:
```sql
-- Rollback profile anonymization
UPDATE user_profiles
SET
  email = 'original-email@example.com',
  first_name = 'Original First Name',
  last_name = 'Original Last Name',
  passphrase_hint = 'Original Hint',
  is_anonymized = false,
  anonymization_id = NULL
WHERE user_id = 'user-id-here';
```

**After Phase 3**:
- ❌ Data is permanently inaccessible (keys destroyed)
- ✅ But can recreate user account with same email
- ✅ User starts fresh with no data

### If Need to Restore Access (Emergency)

```sql
-- Re-enable access (emergency only, data still inaccessible)
UPDATE user_profiles
SET is_anonymized = false
WHERE user_id = 'user-id-here';

-- Recreate auth.users entry (Supabase Admin API)
-- User can login but will see empty account
```

---

## Monitoring & Logging

### Key Log Locations

1. **Flutter App Logs**:
   ```
   [GDPR] Checking anonymization status for user...
   [GDPR] Starting anonymization...
   [GDPR] Phase 1 complete
   [GDPR] ⚠️  User is anonymized!
   [GDPR] User signed out after anonymization detection
   ```

2. **Edge Function Logs**:
   ```bash
   supabase functions logs gdpr-delete-auth-user --limit 50
   ```

   Expected output:
   ```
   GDPR: Starting auth.users deletion for user...
   GDPR: Phase 2.5-5 - Calling anonymize_app_user()
   GDPR: App data cleanup completed
   GDPR: Phase 6.1 - Revoking all sessions
   GDPR: All sessions revoked successfully
   GDPR: Phase 6.2 - Deleting user from auth.users
   GDPR: User deleted from auth.users successfully
   GDPR: Auth deletion completed successfully
   ```

3. **Database Logs**:
   ```sql
   -- Check anonymization events
   SELECT
     event_type,
     phase_number,
     created_at,
     details->>'error' as error_message
   FROM anonymization_events
   WHERE anonymization_id = 'test-id'
   ORDER BY created_at DESC;
   ```

---

## Post-Test Cleanup

### Clean Up Test Accounts

```sql
-- List all anonymized test accounts
SELECT user_id, email, anonymization_completed_at
FROM user_profiles
WHERE email LIKE 'gdpr-test%@%'
  OR email LIKE '%@anonymized.local';

-- Clean up test data (optional)
DELETE FROM user_profiles WHERE email LIKE 'gdpr-test%@temp-mail.org';
DELETE FROM anonymization_events WHERE user_id IN (SELECT user_id FROM ...);
DELETE FROM anonymization_proofs WHERE user_id_hash IN (SELECT ...);
```

### Reset Rate Limiting (Development Only)

```sql
-- Clear rate limit for testing
DELETE FROM anonymization_events
WHERE user_id = 'test-user-id'
  AND event_type IN ('ATTEMPT_SUCCESS', 'ATTEMPT_FAILED');
```

---

## Troubleshooting

See [GDPR_TROUBLESHOOTING.md](./GDPR_TROUBLESHOOTING.md) for common issues and solutions.

---

## Test Report Template

```markdown
# GDPR Anonymization Test Report

**Date**: YYYY-MM-DD
**Tester**: [Your Name]
**Environment**: Development / Production
**App Version**: vX.Y.Z

## Test Results

| Scenario | Result | Duration | Notes |
|----------|--------|----------|-------|
| Complete Anonymization | PASS/FAIL | 20s | |
| Rate Limiting | PASS/FAIL | 2s | |
| Email Verification | PASS/FAIL | 1s | |
| Production Safety | PASS/FAIL | 1s | |
| RLS Blocking | PASS/FAIL | - | |
| Sync Resilience | PASS/FAIL | 5s | |
| Edge Function | PASS/FAIL | 10s | |

## Issues Found

1. [Issue description]
2. [Issue description]

## Recommendations

- [Recommendation 1]
- [Recommendation 2]

## Sign-Off

✅ All critical tests passed
✅ No blocking issues found
✅ Ready for production deployment

Approved by: _____________
Date: _____________
```

---

**Document History**:
- v1.0 (2025-11-21): Initial production-ready version
