# TESTING CHECKLIST PER PHASE

## Overview
Phase-specific testing requirements to ensure safe deployment of security improvements.

## P0: CRITICAL SECURITY FIXES (Deploy Immediately)

### Pre-Deployment Tests ✅

#### 1. User Isolation Tests
```bash
flutter test test/critical/user_isolation_test.dart --no-pub
```

- [ ] **User B cannot see User A notes**
  - Create notes for User A
  - Logout and clear database
  - Login as User B
  - Verify 0 notes visible

- [ ] **User B cannot see User A tasks**
  - Similar test for tasks table

- [ ] **User B cannot see User A folders**
  - Similar test for folders table

- [ ] **User B cannot see User A templates**
  - Similar test for templates (noteType = template)

- [ ] **User B cannot see User A reminders**
  - Similar test for reminders table

#### 2. Database Clearing Tests
```bash
flutter test test/critical/database_clearing_test.dart --no-pub
```

- [ ] **All 12 tables cleared on logout**
  ```dart
  // Tables to verify:
  - localNotes
  - localFolders
  - noteFolders
  - noteTags
  - localTasks (deprecated)
  - noteTasks
  - noteLinks
  - noteReminders
  - savedSearches
  - pendingOps
  - inboxItems
  - clipperInbox
  ```

- [ ] **FTS index cleared**
  ```sql
  SELECT COUNT(*) FROM fts_notes; -- Must be 0
  ```

- [ ] **No orphaned data**
  - Verify no records with null/wrong userId

#### 3. Encryption Tests
```bash
flutter test test/critical/encryption_integrity_test.dart --no-pub
```

- [ ] **Keys isolated per user**
  - User A key cannot decrypt User B data
  - Keys cleared on logout
  - New keys generated on login

- [ ] **Account key verification**
  - hasAccountKey() returns false after logout
  - Keys stored securely
  - Keys never logged

#### 4. RLS Enforcement Tests
```bash
flutter test test/critical/rls_enforcement_test.dart --no-pub
```

- [ ] **Supabase policies enforced**
  - Cannot query with different userId
  - Cannot update other user's data
  - Cannot delete other user's data

### Manual Testing Checklist

- [ ] **Multi-user switching (5 iterations)**
  1. Login as User A
  2. Create 10 notes
  3. Logout
  4. Login as User B
  5. Verify 0 notes
  6. Create 5 notes
  7. Logout
  8. Login as User A
  9. Verify original 10 notes (not 15)

- [ ] **Rapid switching test**
  - Switch users 10 times rapidly
  - No data leakage
  - No crashes

- [ ] **Session expiration**
  - Force expire session
  - Database cleared
  - Redirect to login

### Performance Validation

- [ ] **clearAll() performance**
  ```dart
  // With 10,000 records
  Expected: < 1 second
  Maximum: 2 seconds
  ```

- [ ] **Login/logout cycle**
  ```dart
  Expected: < 500ms
  Maximum: 1 second
  ```

### Deployment Gate
**ALL TESTS MUST PASS** - No exceptions for P0

---

## P1: REPOSITORY LAYER (userId Filtering)

### Pre-Deployment Tests ✅

#### 1. Repository Filter Tests
```bash
flutter test test/unit/repositories/ --no-pub
```

- [ ] **Notes repository filters by userId**
  ```dart
  test('getAllNotes filters by userId') {
    // Setup: Notes for multiple users
    // Action: Call getAllNotes()
    // Assert: Only current user's notes
  }
  ```

- [ ] **Tasks repository filters by userId**
- [ ] **Folders repository filters by userId**
- [ ] **Templates filter correctly**
  - User templates: filtered by userId
  - System templates: available to all

- [ ] **Search respects userId**
  - Search results filtered
  - Saved searches per user

#### 2. Null userId Handling
```bash
flutter test test/unit/repositories/null_handling_test.dart --no-pub
```

- [ ] **Repositories handle null userId**
  ```dart
  // Data with null userId should be:
  - Excluded from queries
  - Logged as warning
  - Not cause crashes
  ```

- [ ] **Legacy data migration**
  - Orphaned records identified
  - Migration plan documented

#### 3. Cross-User Rejection
```bash
flutter test test/integration/cross_user_test.dart --no-pub
```

- [ ] **Sync rejects wrong userId**
  ```dart
  test('sync rejects notes with different userId') {
    // Mock sync with User B's note
    // Sync as User A
    // Verify: Note rejected, not saved
  }
  ```

### Integration Tests

- [ ] **Note workflow with userId**
  1. Create note (userId set)
  2. Edit note (userId preserved)
  3. Move to folder (userId checked)
  4. Delete note (userId verified)

- [ ] **Task workflow with userId**
  1. Create task (userId from note)
  2. Complete task (userId preserved)
  3. Archive task (userId checked)

### Performance Tests

- [ ] **Query performance with WHERE userId**
  ```dart
  // 10,000 records, filtered to 1,000
  Expected: < 100ms
  Maximum: 200ms
  ```

- [ ] **Index effectiveness**
  ```sql
  EXPLAIN QUERY PLAN
  SELECT * FROM notes WHERE user_id = ?;
  -- Must show: USING INDEX
  ```

### Migration Tests

- [ ] **Backfill existing data**
  ```dart
  test('backfill userId for existing notes') {
    // Setup: 1000 notes without userId
    // Run: migration script
    // Assert: All have userId from SharedPrefs
  }
  ```

### Rollback Plan
- [ ] Rollback script ready
- [ ] Data backup created
- [ ] Monitoring alerts configured

---

## P2: DATABASE SCHEMA (Non-nullable userId)

### Pre-Deployment Tests ✅

#### 1. Schema Migration Tests
```bash
flutter test test/migration/schema_migration_test.dart --no-pub
```

- [ ] **NoteTasks userId migration**
  ```dart
  test('migrate NoteTasks userId from parent note') {
    // Setup: Tasks without userId
    // Run: Migration
    // Assert: userId copied from parent note
  }
  ```

- [ ] **PendingOps userId migration**
  ```dart
  test('migrate PendingOps userId') {
    // Setup: Pending ops without userId
    // Run: Migration
    // Assert: userId set from current user
  }
  ```

- [ ] **Handle orphaned records**
  ```dart
  test('orphaned tasks handled gracefully') {
    // Setup: Tasks with deleted parent
    // Run: Migration
    // Assert: Orphans deleted or assigned
  }
  ```

#### 2. Constraint Tests
```bash
flutter test test/migration/constraint_test.dart --no-pub
```

- [ ] **Non-null constraints enforced**
  ```dart
  test('cannot insert null userId') {
    // Attempt insert with null userId
    // Assert: Throws exception
  }
  ```

- [ ] **Foreign key constraints**
  ```dart
  test('cannot reference non-existent user') {
    // Attempt insert with invalid userId
    // Assert: Throws exception
  }
  ```

#### 3. Data Integrity Tests

- [ ] **No data loss during migration**
  ```dart
  test('all data preserved during migration') {
    // Count before: notes, tasks, folders
    // Run migration
    // Count after: Must match
  }
  ```

- [ ] **Encryption preserved**
  ```dart
  test('encrypted data remains encrypted') {
    // Check encryption_version
    // Decrypt sample data
    // Verify content intact
  }
  ```

### Large Dataset Tests

- [ ] **Migration performance**
  ```dart
  test('migrate 100,000 records efficiently') {
    // Setup: Large dataset
    // Run: Migration
    // Assert: < 30 seconds
  }
  ```

- [ ] **Rollback performance**
  ```dart
  test('rollback completes quickly') {
    // Run: Rollback script
    // Assert: < 10 seconds
  }
  ```

### Backward Compatibility

- [ ] **Old app version compatibility**
  - Test with previous app version
  - Ensure graceful degradation
  - Migration path documented

### Production Validation

- [ ] **Staging environment test**
  - Full migration on staging
  - Performance metrics collected
  - Rollback tested

- [ ] **Canary deployment**
  - 5% user rollout
  - Monitor for 24 hours
  - Check error rates

---

## P3: ARCHITECTURE REFACTOR (Provider Isolation)

### Pre-Deployment Tests ✅

#### 1. Provider Isolation Tests
```bash
flutter test test/unit/providers/ --no-pub
```

- [ ] **Providers cleared on user switch**
  ```dart
  test('providers invalidated on logout') {
    // Setup: Populated providers
    // Action: Logout
    // Assert: All providers reset
  }
  ```

- [ ] **No state leakage between users**
  ```dart
  test('User B providers independent of User A') {
    // Login User A, populate state
    // Logout, Login User B
    // Assert: Clean state for User B
  }
  ```

#### 2. State Management Tests

- [ ] **Riverpod state isolation**
  ```dart
  test('family providers isolated by userId') {
    // Create provider.family(userId)
    // Switch users
    // Verify separate instances
  }
  ```

- [ ] **Proper disposal**
  ```dart
  test('providers dispose correctly') {
    // Monitor dispose callbacks
    // Switch users
    // Verify all disposed
  }
  ```

#### 3. Integration Tests

- [ ] **Complete user journey**
  ```dart
  test('full workflow with provider isolation') {
    // User A: Create, edit, delete
    // User B: Same workflow
    // Verify complete isolation
  }
  ```

### Performance Regression Tests

- [ ] **Provider rebuild performance**
  ```dart
  // Measure rebuild frequency
  Expected: < 10 rebuilds per action
  Maximum: 20 rebuilds
  ```

- [ ] **Memory leak detection**
  ```dart
  test('no memory leaks on user switching') {
    // Switch users 100 times
    // Monitor memory usage
    // Assert: No growth
  }
  ```

### UI Tests

- [ ] **Widget state preservation**
  - User switches don't break UI
  - Animations continue smoothly
  - No flickering

- [ ] **Error boundary testing**
  - Provider errors caught
  - Graceful fallbacks
  - User notified appropriately

### End-to-End Tests

- [ ] **Multi-platform testing**
  - iOS: User switching
  - Android: User switching
  - Web: User switching

- [ ] **Offline/Online transitions**
  - Switch users offline
  - Go online
  - Verify sync correctness

---

## Continuous Monitoring Checklist

### Daily Checks
- [ ] Error rate < 0.1%
- [ ] No userId mismatch errors
- [ ] clearAll() performance stable
- [ ] Login success rate > 99%

### Weekly Checks
- [ ] User isolation violations: 0
- [ ] Data leakage reports: 0
- [ ] Performance regression < 5%
- [ ] Test coverage maintained

### Incident Response
- [ ] Rollback procedure documented
- [ ] On-call rotation assigned
- [ ] Escalation path defined
- [ ] Post-mortem template ready

---

## Test Execution Commands

### Quick Validation
```bash
# P0 - Critical Security (5 min)
flutter test test/critical/ --no-pub

# P1 - Repository Layer (3 min)
flutter test test/unit/repositories/ --no-pub

# P2 - Migration Tests (2 min)
flutter test test/migration/ --no-pub

# P3 - Provider Tests (3 min)
flutter test test/unit/providers/ --no-pub
```

### Full Test Suite
```bash
# Complete test suite with coverage (15 min)
flutter test --coverage --no-pub

# Generate coverage report
lcov --remove coverage/lcov.info 'lib/generated/*' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Performance Tests
```bash
# Run performance benchmarks
flutter test test/performance/ --no-pub --profile

# Run with specific tags
flutter test --tags=performance --no-pub
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Run P0 Security Tests
  run: flutter test test/critical/ --no-pub

- name: Run P1 Repository Tests
  if: success()
  run: flutter test test/unit/repositories/ --no-pub

- name: Check Coverage
  if: success()
  run: |
    flutter test --coverage --no-pub
    # Fail if coverage < 80%
```

---

## Success Metrics

### P0 Success
- ✅ 100% security tests pass
- ✅ Zero data leakage incidents
- ✅ clearAll() < 1 second

### P1 Success
- ✅ All repositories filter by userId
- ✅ Query performance < 100ms
- ✅ No null userId in production

### P2 Success
- ✅ Migration completes < 30s
- ✅ No data loss
- ✅ Constraints enforced

### P3 Success
- ✅ Provider isolation verified
- ✅ No memory leaks
- ✅ Performance maintained

---

## Emergency Contacts

- **Security Team**: security@durunotes.com
- **On-Call Engineer**: Use PagerDuty
- **Database Admin**: dba@durunotes.com
- **Product Owner**: product@durunotes.com