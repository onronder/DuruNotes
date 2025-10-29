# 🔐 Authentication & Authorization Testing Master Plan
**Date**: October 23, 2025
**Priority**: P0 - CRITICAL
**Status**: 📋 **IN PROGRESS**
**Goal**: **ZERO ERRORS** in all authentication flows

---

## 🎯 Objective

**Ensure 100% reliability of authentication and authorization across ALL user flows with ZERO errors.**

This is **CRITICAL** because authentication is the foundation of the entire app:
- User data security depends on it
- Encryption system depends on it
- Sync system depends on it
- All features depend on successful authentication

---

## 📊 Test Coverage Matrix

| Test Category | Manual Tests | Automated Tests | Integration Tests | Status |
|--------------|--------------|-----------------|-------------------|--------|
| **Sign-Up Flow** | 5 tests | 8 tests | 3 tests | 🟡 In Progress |
| **Sign-In Flow** | 4 tests | 6 tests | 2 tests | 🟡 In Progress |
| **Sign-Out Flow** | 3 tests | 4 tests | 2 tests | 🟡 In Progress |
| **Re-Authentication** | 6 tests | 10 tests | 4 tests | 🟡 In Progress |
| **AMK Management** | 4 tests | 8 tests | 3 tests | 🟡 In Progress |
| **Security Services** | 3 tests | 6 tests | 2 tests | 🟡 In Progress |
| **Error Handling** | 8 tests | 12 tests | 4 tests | 🟡 In Progress |
| **Stress Testing** | 4 tests | 6 tests | 2 tests | 🟡 In Progress |
| **RLS Policies** | 3 tests | 5 tests | 2 tests | 🟡 In Progress |

**TOTAL**: 40 manual tests + 65 automated tests + 24 integration tests = **129 tests**

---

## 🔴 CRITICAL PATH 1: Sign-Up Flow

### User Story
"As a new user, I want to create an account and start using the app securely."

### Flow Diagram
```
┌─────────────────────┐
│  Enter Email/Pass   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Click "Sign Up"     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Supabase Auth       │
│ Creates Account     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Enter Passphrase    │
│ (for encryption)    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ AMK Provisioning    │
│ - Generate AMK      │
│ - Wrap with KDF     │
│ - Store in DB       │
│ - Cache locally     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Security Services   │
│ Initialization      │
│ - AuthGuard         │
│ - Encryption        │
│ - RateLimiter       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Provider Init       │
│ - Database          │
│ - Repositories      │
│ - Services          │
│ - Sync              │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ ✅ Main App Screen  │
└─────────────────────┘
```

### Manual Test Cases

#### TEST-SIGNUP-001: Basic Sign-Up
**Priority**: P0
**Preconditions**: App is installed, no user logged in
**Steps**:
1. Launch app
2. Enter email: `test001@duru.app`
3. Enter password: `TestPassword123!`
4. Confirm password: `TestPassword123!`
5. Click "Sign Up"
6. Enter passphrase: `MySecurePassphrase123`
7. Confirm passphrase: `MySecurePassphrase123`
8. Wait for account creation

**Expected Results**:
- ✅ Account created in Supabase `auth.users` table
- ✅ No `LateInitializationError`
- ✅ No widget disposal errors
- ✅ AMK created and stored in `user_keys` table
- ✅ Local AMK cached in secure storage
- ✅ Security services initialized successfully
- ✅ User sees main app screen
- ✅ No console errors

**Console Output to Verify**:
```
flutter: [Auth] Starting sign up for test001@duru.app
flutter: [Auth] Sign-up response user=xxx, session=true
flutter: [AuthWrapper] ✅ Cross-device AMK found locally
flutter: ✅ Security services initialized successfully
flutter: ✅ Sync completed successfully
```

---

#### TEST-SIGNUP-002: Sign-Up with Passphrase Mismatch
**Priority**: P1
**Steps**:
1. Launch app
2. Enter email/password
3. Click "Sign Up"
4. Enter passphrase: `Passphrase1`
5. Confirm passphrase: `Passphrase2` (different!)
6. Try to continue

**Expected Results**:
- ✅ Validation error shown
- ✅ "Passphrases do not match" message displayed
- ✅ Cannot proceed until fixed
- ✅ No crash

---

#### TEST-SIGNUP-003: Sign-Up with Weak Password
**Priority**: P1
**Steps**:
1. Enter email: `test@duru.app`
2. Enter password: `123` (too weak)
3. Click "Sign Up"

**Expected Results**:
- ✅ Supabase validation error
- ✅ Clear error message shown
- ✅ No crash
- ✅ User can retry with stronger password

---

#### TEST-SIGNUP-004: Sign-Up Network Failure
**Priority**: P1
**Steps**:
1. Turn off network connection
2. Enter valid email/password
3. Click "Sign Up"

**Expected Results**:
- ✅ Network error message displayed
- ✅ "Check your connection and try again"
- ✅ No crash
- ✅ Can retry when network restored

---

#### TEST-SIGNUP-005: Sign-Up with Existing Email
**Priority**: P1
**Steps**:
1. Use email that already exists
2. Enter password
3. Click "Sign Up"

**Expected Results**:
- ✅ Supabase error: "User already exists"
- ✅ Clear error message shown
- ✅ Suggest "Sign In" instead
- ✅ No crash

---

### Automated Test Cases

```dart
test('TEST-SIGNUP-AUTO-001: Complete sign-up flow succeeds', () async {
  // Arrange
  final mockSupabase = MockSupabaseClient();
  final authService = AuthService(mockSupabase);

  // Act
  final result = await authService.signUp(
    email: 'test@example.com',
    password: 'SecurePass123!',
    passphrase: 'MyPassphrase',
  );

  // Assert
  expect(result.success, true);
  expect(result.user, isNotNull);
  expect(result.error, isNull);
  verify(mockSupabase.auth.signUp(any)).called(1);
});

test('TEST-SIGNUP-AUTO-002: AMK provisioning succeeds', () async {
  // Verify AMK is created and stored correctly
});

test('TEST-SIGNUP-AUTO-003: Security services initialize after signup', () async {
  // Verify all security services are initialized
});

test('TEST-SIGNUP-AUTO-004: AuthGuard allows multiple initializations', () async {
  // Verify idempotency
});

test('TEST-SIGNUP-AUTO-005: Widget mounted check prevents disposal errors', () async {
  // Verify mounted check works
});
```

---

## 🔴 CRITICAL PATH 2: Sign-In Flow

### Flow Diagram
```
┌─────────────────────┐
│  Enter Email/Pass   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Click "Sign In"     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Supabase Auth       │
│ Validates Creds     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Check for AMK       │
│ - Local first       │
│ - Server if not     │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
  Found     Not Found
     │           │
     ▼           ▼
┌─────────┐ ┌─────────┐
│Show Main│ │Show     │
│Screen   │ │Unlock   │
│         │ │Screen   │
└─────────┘ └────┬────┘
               │
               ▼
        ┌─────────────┐
        │Enter        │
        │Passphrase   │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │Unlock AMK   │
        │from Server  │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │✅ Main App  │
        │Screen       │
        └─────────────┘
```

### Manual Test Cases

#### TEST-SIGNIN-001: Basic Sign-In
**Priority**: P0
**Preconditions**: User account exists from TEST-SIGNUP-001
**Steps**:
1. Launch app (if logged in, sign out first)
2. Enter email: `test001@duru.app`
3. Enter password: `TestPassword123!`
4. Click "Sign In"

**Expected Results**:
- ✅ Authentication succeeds
- ✅ AMK found locally (from previous sign-up)
- ✅ No unlock screen shown
- ✅ Security services initialized
- ✅ User sees main app screen immediately
- ✅ No console errors

---

#### TEST-SIGNIN-002: Sign-In After Fresh Install (AMK on Server)
**Priority**: P0
**Preconditions**:
- User account exists
- App was uninstalled and reinstalled
- AMK exists on server but not locally

**Steps**:
1. Uninstall app completely
2. Reinstall app
3. Enter valid email/password
4. Click "Sign In"
5. Should see unlock screen
6. Enter passphrase

**Expected Results**:
- ✅ Authentication succeeds
- ✅ Unlock screen shown (AMK not found locally)
- ✅ After entering passphrase, AMK unlocked from server
- ✅ AMK cached locally
- ✅ User sees main app screen
- ✅ No console errors

---

#### TEST-SIGNIN-003: Sign-In with Wrong Password
**Priority**: P1
**Steps**:
1. Enter valid email
2. Enter wrong password
3. Click "Sign In"

**Expected Results**:
- ✅ Authentication fails
- ✅ "Invalid credentials" error shown
- ✅ No crash
- ✅ User can retry

---

#### TEST-SIGNIN-004: Sign-In with Wrong Passphrase
**Priority**: P1
**Preconditions**: Unlock screen shown
**Steps**:
1. Authenticate successfully
2. Unlock screen appears
3. Enter wrong passphrase
4. Click "Unlock"

**Expected Results**:
- ✅ Unlock fails
- ✅ "Incorrect passphrase" error shown
- ✅ Can retry
- ✅ No crash

---

## 🔴 CRITICAL PATH 3: Sign-Out → Sign-In Flow

### Manual Test Cases

#### TEST-REAUTH-001: Sign-Out → Sign-In Same User
**Priority**: P0
**Steps**:
1. User is signed in
2. Navigate to Settings
3. Click "Sign Out"
4. Confirm sign-out
5. Enter same email/password
6. Click "Sign In"

**Expected Results**:
- ✅ Sign-out succeeds
- ✅ SecurityInitialization.reset() called
- ✅ Sign-in succeeds
- ✅ AMK found locally (not cleared on sign-out)
- ✅ No unlock screen needed
- ✅ Security services re-initialized
- ✅ **NO "already initialized" errors**
- ✅ User sees main app screen

**Console Output to Verify**:
```
flutter: 🔄 Resetting security services initialization state...
flutter: ✅ Security services reset complete
flutter: [Auth] Starting sign in for test@duru.app
flutter: [AuthWrapper] ✅ Cross-device AMK found locally
flutter: ✅ Security services initialized successfully
```

---

#### TEST-REAUTH-002: Sign-Out → Sign-In Different User
**Priority**: P0
**Steps**:
1. User A is signed in
2. Sign out
3. Sign in as User B

**Expected Results**:
- ✅ User A signed out successfully
- ✅ User B authentication succeeds
- ✅ User B's AMK is loaded (different from User A)
- ✅ Security services re-initialized with User B's ID
- ✅ User B sees their own data (RLS working)
- ✅ No cross-user data leakage

---

## 🔴 CRITICAL PATH 4: Sign-Out → Sign-Up Flow

### Manual Test Cases

#### TEST-REAUTH-003: Sign-Out → Sign-Up New User
**Priority**: P0 - **MOST CRITICAL**
**This is the flow that was BROKEN before our fixes!**

**Steps**:
1. User A is signed in
2. Navigate to Settings → Sign Out
3. Confirm sign-out
4. Click "Sign Up" (not "Sign In")
5. Enter NEW email: `newuser@duru.app`
6. Enter password
7. Click "Sign Up"
8. Enter passphrase
9. Confirm passphrase

**Expected Results**:
- ✅ User A signed out successfully
- ✅ SecurityInitialization.reset() called
- ✅ New user account created
- ✅ **NO `LateInitializationError`** ← THIS WAS THE BUG!
- ✅ **NO "Field '_jwtSecret' already initialized" error**
- ✅ AMK provisioned for new user
- ✅ Security services initialized with new user ID
- ✅ New user sees main app screen
- ✅ No console errors

**Console Output to Verify**:
```
flutter: supabase.auth: INFO: Signing out user
flutter: 🔄 Resetting security services initialization state...
flutter: ✅ Security services reset complete
flutter: [Auth] Starting sign up for newuser@duru.app
flutter: [Auth] Sign-up response user=xxx, session=true
flutter: ✅ Security services initialized successfully  ← NO ERRORS!
```

**THIS TEST MUST PASS** - It validates all our fixes!

---

#### TEST-REAUTH-004: Multiple Sign-Out → Sign-Up Cycles
**Priority**: P1 - **STRESS TEST**
**Steps**:
1. Sign up User 1
2. Sign out
3. Sign up User 2
4. Sign out
5. Sign up User 3
6. Sign out
7. Sign up User 4
8. Sign out
9. Sign up User 5

**Expected Results**:
- ✅ All 5 users created successfully
- ✅ No errors on any iteration
- ✅ No "already initialized" errors
- ✅ Each user has their own AMK
- ✅ Security services work for all users

---

## 🔐 CRITICAL PATH 5: AMK (Account Master Key) Management

### Manual Test Cases

#### TEST-AMK-001: AMK Provisioning on Sign-Up
**Priority**: P0
**Steps**:
1. Create new account
2. Enter passphrase
3. Check database

**Expected Results**:
- ✅ Row exists in `user_keys` table
- ✅ `user_id` matches authenticated user
- ✅ `wrapped_key` is base64-encoded
- ✅ `kdf` is 'pbkdf2-hmac-sha256'
- ✅ `kdf_params` contains iterations and salt
- ✅ Local AMK cached in secure storage

**Database Query to Verify**:
```sql
SELECT user_id,
       length(wrapped_key) as wrapped_key_length,
       kdf,
       kdf_params
FROM user_keys
WHERE user_id = '<user-id>';
```

**Expected Result**:
```
user_id                              | wrapped_key_length | kdf                  | kdf_params
-------------------------------------|-------------------|---------------------|-------------
xxx-xxx-xxx-xxx                      | > 100             | pbkdf2-hmac-sha256  | {"iterations": 150000, "salt_b64": "..."}
```

---

#### TEST-AMK-002: AMK Unlock from Server
**Priority**: P0
**Steps**:
1. Clear local AMK cache
2. Sign in
3. Enter passphrase on unlock screen

**Expected Results**:
- ✅ Unlock screen appears
- ✅ Passphrase validated
- ✅ Wrapping key derived
- ✅ AMK unwrapped from server data
- ✅ Local AMK cached
- ✅ Main app screen shown

---

#### TEST-AMK-003: Wrong Passphrase Handling
**Priority**: P1
**Steps**:
1. Clear local AMK
2. Sign in
3. Enter WRONG passphrase

**Expected Results**:
- ✅ Decryption fails gracefully
- ✅ "Incorrect passphrase" error shown
- ✅ Can retry
- ✅ No crash
- ✅ No data corruption

---

#### TEST-AMK-004: AMK Persistence Across App Restarts
**Priority**: P1
**Steps**:
1. Sign in with passphrase
2. AMK unlocked and cached
3. Kill app (force quit)
4. Relaunch app
5. Sign in

**Expected Results**:
- ✅ Local AMK still cached
- ✅ No unlock screen shown
- ✅ Immediate access to main app
- ✅ Encryption works correctly

---

## 🛡️ CRITICAL PATH 6: Security Services Initialization

### Manual Test Cases

#### TEST-SECURITY-001: First-Time Initialization
**Priority**: P0
**Steps**:
1. Fresh app install
2. Create account
3. Complete sign-up

**Expected Results**:
- ✅ `SecurityInitialization.initialize()` called once
- ✅ All services initialized:
  - ErrorLoggingService
  - InputValidationService
  - EncryptionService
  - RateLimitingMiddleware
  - AuthenticationGuard
  - ProviderErrorRecovery
- ✅ No initialization errors
- ✅ `_initialized` flag set to true

---

#### TEST-SECURITY-002: Re-Initialization After Reset
**Priority**: P0
**Steps**:
1. Services initialized
2. User signs out
3. `SecurityInitialization.reset()` called
4. User signs in again
5. Services re-initialized

**Expected Results**:
- ✅ Reset succeeds
- ✅ `_initialized` flag set to false
- ✅ Re-initialization succeeds
- ✅ **NO "already initialized" warnings**
- ✅ Services work correctly

---

#### TEST-SECURITY-003: Multiple Reset/Initialize Cycles
**Priority**: P1 - **STRESS TEST**
**Steps**:
1. Initialize
2. Reset
3. Initialize
4. Reset
5. Initialize
6. Repeat 10 times

**Expected Results**:
- ✅ All cycles complete successfully
- ✅ No errors
- ✅ No memory leaks
- ✅ Services remain functional

---

## 🔍 CRITICAL PATH 7: RLS (Row Level Security) Policies

### Manual Test Cases

#### TEST-RLS-001: User Can Only Access Their Own Notes
**Priority**: P0
**Steps**:
1. Create User A, create 5 notes
2. Note down note IDs
3. Sign out
4. Create User B
5. Try to access User A's note IDs directly

**Expected Results**:
- ✅ User B cannot see User A's notes
- ✅ Direct API queries return empty
- ✅ RLS blocks unauthorized access
- ✅ No data leakage

**Database Test**:
```sql
-- As User B, try to query User A's notes
SELECT * FROM notes WHERE id = '<user-a-note-id>';

-- Expected result: Empty (RLS blocks it)
```

---

#### TEST-RLS-002: User Can Only Access Their Own AMK
**Priority**: P0
**Steps**:
1. User A's AMK in `user_keys`
2. Sign out
3. Sign in as User B
4. Try to query User A's AMK

**Expected Results**:
- ✅ User B cannot access User A's AMK
- ✅ RLS policy blocks access
- ✅ No security breach

---

#### TEST-RLS-003: User Can Access All Their Own Data
**Priority**: P0
**Steps**:
1. Create notes, folders, tasks, reminders
2. Sign out
3. Sign in again

**Expected Results**:
- ✅ All user's data visible
- ✅ Correct counts
- ✅ No missing data

---

## 🚨 ERROR HANDLING & EDGE CASES

### TEST-ERROR-001: Network Timeout During Sign-Up
**Steps**: Slow network connection, sign up

**Expected**: Timeout error shown, can retry

---

### TEST-ERROR-002: Supabase Server Error
**Steps**: Mock server error response

**Expected**: Error message shown, no crash

---

### TEST-ERROR-003: Encryption Failure
**Steps**: Corrupt encryption key

**Expected**: Graceful error handling, user can reset

---

### TEST-ERROR-004: Database Write Failure
**Steps**: Mock database write failure

**Expected**: Error shown, retry mechanism works

---

### TEST-ERROR-005: Token Expiration During Session
**Steps**: Let token expire

**Expected**: Automatic token refresh or re-auth prompt

---

### TEST-ERROR-006: Concurrent Sign-Up Attempts
**Steps**: Rapidly click sign-up button 10 times

**Expected**: Only one account created, others ignored or queued

---

### TEST-ERROR-007: Invalid Email Format
**Steps**: Enter `not-an-email`

**Expected**: Validation error, clear message

---

### TEST-ERROR-008: Empty Passphrase
**Steps**: Try to continue without passphrase

**Expected**: Validation error, cannot proceed

---

## 📊 Acceptance Criteria

**ALL of the following MUST be true**:

- [ ] ✅ Zero `LateInitializationError` errors in all flows
- [ ] ✅ Zero widget disposal errors
- [ ] ✅ Zero note decryption errors
- [ ] ✅ 100% sign-up success rate (with valid inputs)
- [ ] ✅ 100% sign-in success rate (with valid credentials)
- [ ] ✅ 100% sign-out → sign-up success rate
- [ ] ✅ 100% sign-out → sign-in success rate
- [ ] ✅ AMK provisioning succeeds every time
- [ ] ✅ AMK unlock succeeds with correct passphrase
- [ ] ✅ Security services initialize every time
- [ ] ✅ RLS policies prevent cross-user access
- [ ] ✅ All error cases handled gracefully
- [ ] ✅ No crashes in any flow
- [ ] ✅ All console logs clean (no unexpected errors)

---

## 🎯 Next Steps

1. **Implement Automated Tests**: Create test file with all automated test cases
2. **Execute Manual Tests**: Follow this checklist for manual testing
3. **Document Results**: Record pass/fail for each test
4. **Fix Any Issues**: Address any failing tests immediately
5. **Repeat**: Test again until 100% pass rate
6. **Deploy**: Only deploy when all tests pass

---

**Test Execution Order**:
1. ✅ Run automated tests first
2. ✅ Run manual tests for critical paths
3. ✅ Run stress tests
4. ✅ Run error handling tests
5. ✅ Verify RLS policies
6. ✅ Final integration test

**Estimated Testing Time**: 4-6 hours for complete coverage

**Testing Team**: Claude (automated) + User (manual)

---

**Last Updated**: October 23, 2025
**Next Review**: After first test execution
**Owner**: Development Team
