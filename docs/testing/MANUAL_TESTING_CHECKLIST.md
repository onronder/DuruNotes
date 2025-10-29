# 🧪 MANUAL TESTING CHECKLIST - Authentication & Authorization
**Execute this checklist NOW to verify all fixes**

**Date**: October 23, 2025
**Priority**: P0 - CRITICAL
**Estimated Time**: 30-45 minutes
**Required**: Physical device or simulator

---

## ✅ PRE-FLIGHT CHECKLIST

Before starting tests:

- [ ] Flutter installed and working
- [ ] Device/simulator connected and running
- [ ] Supabase project accessible
- [ ] Database accessible for verification
- [ ] Console log window open and visible
- [ ] Network connection stable

---

## 🔴 CRITICAL TEST 1: Fresh Sign-Up (15 min)

### **TEST-001: New User Creation**

**Goal**: Verify new user creation works without errors

**Steps**:

1. [ ] Kill any running Flutter processes:
   ```bash
   killall -9 dart
   flutter clean
   flutter run --debug
   ```

2. [ ] App launches → See auth screen

3. [ ] Click "Sign Up" tab (not "Sign In")

4. [ ] Enter email: `test-001@duru.app`

5. [ ] Enter password: `TestPassword123!`

6. [ ] Confirm password: `TestPassword123!`

7. [ ] Click "Sign Up" button

8. [ ] **CHECKPOINT**: Watch console output

   **MUST SEE**:
   ```
   flutter: [Auth] Starting sign up for test-001@duru.app
   flutter: [Auth] Sign-up response user=xxx, session=true
   ```

   **MUST NOT SEE**:
   ```
   ❌ LateInitializationError
   ❌ Field '_jwtSecret' already initialized
   ❌ Cannot use "ref" after disposed
   ```

9. [ ] Should see passphrase entry screen

10. [ ] Enter passphrase: `MySecurePassphrase123`

11. [ ] Confirm passphrase: `MySecurePassphrase123`

12. [ ] Click "Continue" or "Set Passphrase"

13. [ ] **CHECKPOINT**: Watch console output

    **MUST SEE**:
    ```
    flutter: [AuthWrapper] ✅ Cross-device AMK found locally
    flutter: ✅ Security services initialized successfully
    flutter: ✅ Sync completed successfully
    flutter: 📊 Synced: X notes, Y tasks
    ```

    **MUST NOT SEE**:
    ```
    ❌ Failed to initialize security services
    ❌ LateInitializationError
    ```

14. [ ] Should see main app screen (notes list)

15. [ ] **CHECKPOINT**: Verify in Supabase Dashboard
    - Go to Supabase → Authentication → Users
    - [ ] User `test-001@duru.app` exists
    - [ ] User has UUID
    - [ ] Confirmed: Yes

16. [ ] **CHECKPOINT**: Verify AMK in Database
    ```sql
    SELECT user_id,
           length(wrapped_key) as key_length,
           kdf,
           kdf_params
    FROM user_keys
    WHERE user_id = (
      SELECT id FROM auth.users WHERE email = 'test-001@duru.app'
    );
    ```
    - [ ] One row returned
    - [ ] `key_length` > 100
    - [ ] `kdf` = 'pbkdf2-hmac-sha256'
    - [ ] `kdf_params` contains `iterations` and `salt_b64`

**Result**: ✅ PASS / ❌ FAIL

**Notes**: _______________________________________

---

## 🔴 CRITICAL TEST 2: Sign-Out → Sign-Up (10 min)

### **TEST-002: Sign-Out → Create New User**

**Goal**: Verify the EXACT flow that was broken before our fixes!

**Steps**:

1. [ ] From main app screen (logged in as test-001@duru.app)

2. [ ] Navigate to Settings

3. [ ] Scroll to bottom → Click "Sign Out"

4. [ ] **CHECKPOINT**: Watch console output
   ```
   flutter: supabase.auth: INFO: Signing out user
   ```

5. [ ] Should return to auth screen

6. [ ] Click "Sign Up" tab

7. [ ] Enter NEW email: `test-002@duru.app`

8. [ ] Enter password: `TestPassword456!`

9. [ ] Confirm password: `TestPassword456!`

10. [ ] Click "Sign Up"

11. [ ] **CRITICAL CHECKPOINT**: Watch console output CAREFULLY

    **MUST SEE**:
    ```
    flutter: [Auth] Starting sign up for test-002@duru.app
    flutter: [Auth] Sign-up response user=xxx, session=true
    flutter: ✅ Security services initialized successfully
    ```

    **MUST NOT SEE** (THIS WAS THE BUG!):
    ```
    ❌ LateInitializationError: Field '_jwtSecret@3339213222' has already been initialized
    ❌ Failed to initialize security services
    ```

12. [ ] Enter passphrase: `SecondUserPass789`

13. [ ] Confirm passphrase: `SecondUserPass789`

14. [ ] Click "Continue"

15. [ ] **CHECKPOINT**: Should see main app screen

16. [ ] **CHECKPOINT**: Verify no errors in console

17. [ ] **CHECKPOINT**: User `test-002@duru.app` exists in Supabase

**Result**: ✅ PASS / ❌ FAIL

**This is THE MOST CRITICAL TEST - it validates all our fixes!**

**Notes**: _______________________________________

---

## 🔴 CRITICAL TEST 3: Sign-Out → Sign-In (5 min)

### **TEST-003: Sign-Out → Existing User Sign-In**

**Goal**: Verify re-authentication works

**Steps**:

1. [ ] Currently logged in as test-002@duru.app

2. [ ] Settings → Sign Out

3. [ ] Should see auth screen

4. [ ] Click "Sign In" tab (NOT Sign Up)

5. [ ] Enter email: `test-001@duru.app` (first user we created)

6. [ ] Enter password: `TestPassword123!`

7. [ ] Click "Sign In"

8. [ ] **CHECKPOINT**: Watch console output
   ```
   flutter: [Auth] Attempting sign-in for test-001@duru.app
   flutter: [Auth] Sign-in successful
   flutter: [AuthWrapper] ✅ Cross-device AMK found locally
   ```

9. [ ] Should see main app screen IMMEDIATELY (no passphrase needed - AMK cached locally)

10. [ ] **CHECKPOINT**: No errors in console

**Result**: ✅ PASS / ❌ FAIL

**Notes**: _______________________________________

---

## 🔴 CRITICAL TEST 4: Note Encryption After Auth (5 min)

### **TEST-004: Verify Note Encryption/Decryption Works**

**Goal**: Verify our note decryption fixes work correctly

**Steps**:

1. [ ] Logged in as test-001@duru.app

2. [ ] Click "+" to create new note

3. [ ] Enter title: `Test Note After Auth Fix`

4. [ ] Enter body: `This note tests encryption after authentication fixes.`

5. [ ] Save note

6. [ ] **CHECKPOINT**: Watch console output

    **MUST SEE**:
    ```
    flutter: [NotesCoreRepository] createOrUpdate noteId=xxx isUpdate=false
    flutter: [NotesCoreRepository] note persisted noteId=xxx
    ```

    **MUST NOT SEE**:
    ```
    ❌ Failed to decrypt title
    ❌ Failed to decrypt body
    ❌ FormatException: Invalid character
    ```

7. [ ] Go back to notes list

8. [ ] **CHECKPOINT**: Note displays with correct title "Test Note After Auth Fix" (NOT JSON string)

9. [ ] Tap to open note

10. [ ] **CHECKPOINT**: Body displays correctly

11. [ ] **CHECKPOINT**: No console errors

**Result**: ✅ PASS / ❌ FAIL

**Notes**: _______________________________________

---

## 🔴 CRITICAL TEST 5: Multiple Sign-Out → Sign-Up Cycles (10 min)

### **TEST-005: Stress Test - 3 Sign-Up Cycles**

**Goal**: Verify no errors accumulate over multiple cycles

**Cycle 1**:
1. [ ] Sign out
2. [ ] Sign up as `test-003@duru.app` / password: `Test123!`
3. [ ] Passphrase: `Pass3`
4. [ ] ✅ Success, no errors

**Cycle 2**:
5. [ ] Sign out
6. [ ] Sign up as `test-004@duru.app` / password: `Test456!`
7. [ ] Passphrase: `Pass4`
8. [ ] ✅ Success, no errors

**Cycle 3**:
9. [ ] Sign out
10. [ ] Sign up as `test-005@duru.app` / password: `Test789!`
11. [ ] Passphrase: `Pass5`
12. [ ] ✅ Success, no errors

**Result**: ✅ PASS / ❌ FAIL

**Notes**: _______________________________________

---

## ✅ VALIDATION QUERIES

Run these SQL queries in Supabase SQL Editor to verify data integrity:

### **Query 1: Verify All Test Users Created**
```sql
SELECT email,
       created_at,
       confirmed_at IS NOT NULL as email_confirmed
FROM auth.users
WHERE email LIKE 'test-%@duru.app'
ORDER BY created_at;
```

**Expected**: 5 users (test-001 through test-005)

---

### **Query 2: Verify All AMKs Created**
```sql
SELECT u.email,
       uk.user_id IS NOT NULL as has_amk,
       length(uk.wrapped_key) as key_length
FROM auth.users u
LEFT JOIN user_keys uk ON uk.user_id = u.id
WHERE u.email LIKE 'test-%@duru.app'
ORDER BY u.created_at;
```

**Expected**: All 5 users have `has_amk = true` and `key_length > 100`

---

### **Query 3: Verify RLS Protection**
```sql
-- Try to access another user's notes (should return empty)
-- Run this while logged in as test-001@duru.app
SELECT * FROM notes
WHERE user_id != (
  SELECT id FROM auth.users WHERE email = 'test-001@duru.app'
)
LIMIT 10;
```

**Expected**: 0 rows (RLS blocks cross-user access)

---

### **Query 4: Verify AMK Encryption Metadata**
```sql
SELECT user_id,
       kdf,
       (kdf_params->>'iterations')::int as iterations,
       length(kdf_params->>'salt_b64') as salt_length
FROM user_keys
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE 'test-%@duru.app'
);
```

**Expected**:
- `kdf` = 'pbkdf2-hmac-sha256' for all
- `iterations` = 150000 for all
- `salt_length` > 16 for all

---

## 📊 RESULTS SUMMARY

| Test | Name | Result | Time | Notes |
|------|------|--------|------|-------|
| TEST-001 | Fresh Sign-Up | ⬜ | ___ min | |
| TEST-002 | Sign-Out → Sign-Up | ⬜ | ___ min | **CRITICAL** |
| TEST-003 | Sign-Out → Sign-In | ⬜ | ___ min | |
| TEST-004 | Note Encryption | ⬜ | ___ min | |
| TEST-005 | Multiple Cycles | ⬜ | ___ min | **STRESS TEST** |

**Total Tests**: 5
**Passed**: ____ / 5
**Failed**: ____ / 5
**Overall**: ✅ PASS / ❌ FAIL

---

## ❌ IF ANY TEST FAILS

**Immediate Actions**:

1. **DO NOT PROCEED** to next test
2. Copy full console output
3. Copy error message
4. Take screenshot
5. Share with development team
6. DO NOT deploy to production

---

## ✅ IF ALL TESTS PASS

**Next Steps**:

1. ✅ Document test results
2. ✅ Save console logs
3. ✅ Run automated test suite:
   ```bash
   flutter test test/auth/comprehensive_auth_test_suite.dart
   ```
4. ✅ Review code changes one more time
5. ✅ Create git commit with fixes
6. ✅ Deploy to staging first
7. ✅ Monitor Sentry for 24 hours
8. ✅ Deploy to production

---

## 📝 TESTER SIGN-OFF

**Tested By**: _______________________
**Date**: _______________________
**Time Spent**: _______________________
**Overall Result**: ✅ PASS / ❌ FAIL
**Ready for Production**: ✅ YES / ❌ NO

**Tester Signature**: _______________________

---

**REMEMBER**: Authentication is CRITICAL. We need **ZERO ERRORS** before deployment.

If you see ANY errors during testing, **STOP** and investigate immediately.
