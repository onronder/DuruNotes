# GDPR Anonymization - Troubleshooting Guide

**Document Version**: 1.0
**Date**: November 21, 2025

---

## Common Issues & Solutions

### Issue 1: "Rate limit exceeded" Error

**Symptoms**:
```
Rate limit exceeded. You must wait X hours and Y minutes before attempting anonymization again.
```

**Cause**: 24-hour cooldown enforced between anonymization attempts

**Solution**:
```sql
-- Check last attempt time
SELECT created_at, event_type, details
FROM anonymization_events
WHERE user_id = 'user-id-here'
ORDER BY created_at DESC
LIMIT 1;

-- For testing only: Clear rate limit
DELETE FROM anonymization_events
WHERE user_id = 'user-id-here'
  AND event_type IN ('ATTEMPT_SUCCESS', 'ATTEMPT_FAILED');
```

**Prevention**: Wait 24 hours between attempts or use different test account

---

### Issue 2: "Email must be verified" Error

**Symptoms**:
```
Email address must be verified before account deletion.
```

**Cause**: User's email not confirmed

**Solution**:
1. Check email inbox for verification email
2. Click verification link
3. Retry anonymization

**Check verification status**:
```sql
SELECT
  email,
  email_confirmed_at,
  confirmation_sent_at
FROM auth.users
WHERE id = 'user-id-here';
```

---

### Issue 3: "Production requires explicit override" Error

**Symptoms**:
```
GDPR anonymization in PRODUCTION requires explicit override.
```

**Cause**: Safety check preventing accidental production deletion

**Solution**:
```dart
final confirmations = UserConfirmations(
  dataBackupComplete: true,
  understandsIrreversibility: true,
  finalConfirmationToken: 'DELETE MY ACCOUNT',
  acknowledgesRisks: true,
  allowProductionOverride: true, // ← Add this
);
```

---

### Issue 4: Edge Function Timeout

**Symptoms**:
- Anonymization hangs at Phase 4-6
- Edge Function logs show timeout

**Cause**: Large dataset taking too long to process

**Solution**:
1. Check Edge Function logs:
   ```bash
   supabase functions logs gdpr-delete-auth-user --limit 50
   ```

2. If timeout, Edge Function is idempotent - safe to retry:
   ```dart
   await service.anonymizeUserAccount(...);
   ```

3. Check database state:
   ```sql
   SELECT is_anonymized, anonymization_completed_at
   FROM user_profiles
   WHERE user_id = 'user-id-here';
   ```

---

### Issue 5: "Cannot access data" After Failed Anonymization

**Symptoms**:
- Anonymization failed mid-process
- User can login but sees no data
- RLS blocking data access

**Cause**: `is_anonymized` flag set to true but process didn't complete

**Solution**:
```sql
-- Check anonymization status
SELECT is_anonymized, anonymization_completed_at
FROM user_profiles
WHERE user_id = 'user-id-here';

-- If is_anonymized = true but anonymization_completed_at is NULL:
-- Process was interrupted

-- Check which phase failed
SELECT event_type, phase_number, details
FROM anonymization_events
WHERE user_id = 'user-id-here'
ORDER BY created_at DESC;

-- CRITICAL: If Phase 3 completed, keys are destroyed - data is gone
-- If Phase 3 NOT completed, can potentially restore:

-- Restore access (emergency only, before Phase 3)
UPDATE user_profiles
SET is_anonymized = false
WHERE user_id = 'user-id-here'
  AND anonymization_completed_at IS NULL;
```

**⚠️ WARNING**: If Phase 3 completed, data is permanently inaccessible

---

### Issue 6: Sync Crashes with Null Pointer

**Symptoms**:
```
type 'Null' is not a subtype of type 'String' in type cast
```

**Cause**: Sync encountering anonymized data with null IDs

**Solution**: Already fixed in `unified_sync_service.dart` (lines 517, 621, 728, etc.)

**Verification**:
```dart
// Should see these log messages:
Skipping remote folder with null ID (likely anonymized)
Skipping remote note with null ID (likely anonymized)
```

---

### Issue 7: User Can Still Login After Anonymization

**Symptoms**:
- Anonymization reported success
- User can login with old credentials
- Sees "Account Deleted" dialog but not blocked

**Cause**: Edge Function didn't delete `auth.users` entry

**Diagnosis**:
```bash
# Check Edge Function logs
supabase functions logs gdpr-delete-auth-user

# Look for:
GDPR: User deleted from auth.users successfully
```

```sql
-- Check if auth.users entry still exists
SELECT id, email, deleted_at
FROM auth.users
WHERE id = 'user-id-here';

-- Expected: 0 rows (user deleted)
```

**Solution**:
```typescript
// Manually delete via Supabase Dashboard or SQL
-- ⚠️ Use service role credentials
const { error } = await supabaseAdmin.auth.admin.deleteUser('user-id-here');
```

---

### Issue 8: RLS Not Blocking Access

**Symptoms**:
- User marked as anonymized
- Can still query data via SQL

**Diagnosis**:
```sql
-- Check if RLS is enabled
SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('notes', 'folders', 'note_tasks', 'reminders');

-- Expected: rowsecurity = true for all

-- Check if policy exists
SELECT
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE policyname = 'block_anonymized_users';

-- Expected: 10+ rows (one per table)
```

**Solution**:
```sql
-- Re-apply migration
-- supabase db reset (⚠️ WARNING: Destroys all data)

-- Or manually create missing policy:
DROP POLICY IF EXISTS "block_anonymized_users" ON public.notes;
CREATE POLICY "block_anonymized_users" ON public.notes
  FOR ALL
  USING (NOT is_user_anonymized(user_id));
```

---

### Issue 9: Compliance Proof Missing

**Symptoms**:
- Anonymization completed
- No entry in `anonymization_proofs` table

**Diagnosis**:
```sql
SELECT COUNT(*) FROM anonymization_proofs
WHERE anonymization_id = 'test-id';

-- Expected: 1
```

**Cause**: Phase 7 failed

**Solution**:
```sql
-- Check Phase 7 events
SELECT event_type, details
FROM anonymization_events
WHERE anonymization_id = 'test-id'
  AND phase_number = 7;

-- If no Phase 7 event, anonymization didn't complete properly
-- Compliance proof cannot be regenerated (data destroyed)
-- Document as manual compliance record
```

---

## Diagnostic Queries

### Complete Health Check

```sql
-- 1. Check user profile status
SELECT
  user_id,
  email,
  is_anonymized,
  anonymization_completed_at,
  auth_deletion_completed_at,
  anonymization_id
FROM user_profiles
WHERE user_id = 'user-id-here';

-- 2. Check anonymization events
SELECT
  event_type,
  phase_number,
  created_at,
  details
FROM anonymization_events
WHERE user_id = 'user-id-here'
ORDER BY created_at DESC;

-- 3. Check auth.users existence
SELECT id, email, deleted_at
FROM auth.users
WHERE id = 'user-id-here';

-- 4. Check data tombstoning
SELECT COUNT(*) as remaining_notes
FROM notes
WHERE user_id = 'user-id-here';

-- Expected: 0 (if anonymized)

-- 5. Check RLS policies
SELECT COUNT(*) as rls_policies
FROM pg_policies
WHERE policyname = 'block_anonymized_users';

-- Expected: 10+

-- 6. Check compliance proof
SELECT proof_hash, created_at
FROM anonymization_proofs
WHERE anonymization_id = 'test-id';
```

---

## Recovery Procedures

### Scenario: Partial Anonymization (Before Phase 3)

```sql
-- 1. Check current state
SELECT
  is_anonymized,
  anonymization_completed_at
FROM user_profiles
WHERE user_id = 'user-id-here';

-- 2. Check which phases completed
SELECT phase_number, event_type
FROM anonymization_events
WHERE user_id = 'user-id-here'
ORDER BY phase_number;

-- 3. If Phase 3 NOT completed, can restore
UPDATE user_profiles
SET
  is_anonymized = false,
  anonymization_id = NULL
WHERE user_id = 'user-id-here';

-- 4. Clean up events
DELETE FROM anonymization_events
WHERE user_id = 'user-id-here'
  AND anonymization_id = 'failed-id';
```

### Scenario: Partial Anonymization (After Phase 3)

**⚠️ CRITICAL**: Data is permanently inaccessible. Cannot recover.

```sql
-- Option 1: Complete the anonymization manually
-- 1. Call Edge Function manually
curl -X POST .../functions/v1/gdpr-delete-auth-user \
  -H "Authorization: Bearer SERVICE_ROLE_KEY" \
  -d '{"userId": "...", "anonymizationId": "..."}'

-- Option 2: Allow user to create new account
-- Data is gone, but user can start fresh
UPDATE user_profiles
SET is_anonymized = false
WHERE user_id = 'user-id-here';

-- User will have empty account
```

---

## Edge Function Debugging

### Check Edge Function Status

```bash
# 1. List functions
supabase functions list

# 2. Check logs
supabase functions logs gdpr-delete-auth-user --limit 50

# 3. Test directly
curl -X POST https://your-project.supabase.co/functions/v1/gdpr-delete-auth-user \
  -H "Authorization: Bearer USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-id",
    "anonymizationId": "test-anon-id",
    "environment": "development"
  }'
```

### Common Edge Function Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` | Invalid/expired token | Re-login, get fresh token |
| `403 Forbidden` | Wrong userId | Ensure userId matches authenticated user |
| `500 Internal Error` | Service role key missing | Check `supabase secrets list` |
| `Timeout` | Large dataset | Retry (idempotent) |

---

## Performance Issues

### Slow Anonymization (>60s)

**Diagnosis**:
```sql
-- Check data size
SELECT
  (SELECT COUNT(*) FROM notes WHERE user_id = 'user-id-here') as notes,
  (SELECT COUNT(*) FROM note_tasks WHERE user_id = 'user-id-here') as tasks,
  (SELECT COUNT(*) FROM folders WHERE user_id = 'user-id-here') as folders,
  (SELECT COUNT(*) FROM reminders WHERE user_id = 'user-id-here') as reminders;
```

**Solution**:
- If >10,000 items: Expected to take longer
- Consider batching in future version
- Current implementation handles up to ~50,000 items

### RLS Performance Impact

**Check RLS overhead**:
```sql
EXPLAIN ANALYZE
SELECT * FROM notes WHERE user_id = 'test-user-id';

-- Look for is_user_anonymized() function calls
-- Expected overhead: <1ms per query
```

---

## Contact & Escalation

### When to Escalate

- ⚠️ User data visible after anonymization
- ⚠️ RLS policies not blocking access
- ⚠️ Auth.users entry not deleted
- ⚠️ Edge Function consistently failing
- ⚠️ Data recovery needed (if before Phase 3)

### Escalation Process

1. Gather diagnostic information (run health check queries)
2. Export relevant logs
3. Document exact steps to reproduce
4. Contact: [your-team@example.com]

---

**Document History**:
- v1.0 (2025-11-21): Initial production-ready version
