# P0 SECURITY FIX CHECKLIST

**Issue**: Data leakage between users
**Severity**: CRITICAL
**Target**: Deploy within 1 week

---

## PRE-IMPLEMENTATION

- [ ] Read [DATABASE_SECURITY_FIX_SUMMARY.md](./DATABASE_SECURITY_FIX_SUMMARY.md) (5 min)
- [ ] Review [DATABASE_INTEGRITY_AUDIT_REPORT.md](./DATABASE_INTEGRITY_AUDIT_REPORT.md) (20 min)
- [ ] Review [DATABASE_INTEGRITY_IMMEDIATE_FIXES.md](./DATABASE_INTEGRITY_IMMEDIATE_FIXES.md) (10 min)
- [ ] Create feature branch: `git checkout -b fix/critical-data-isolation`
- [ ] Backup current database schema

---

## FIX 1: NotesCoreRepository Query Filtering (2 hours)

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

### Changes Required
- [ ] Update `localNotes()` method (line ~1839)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

- [ ] Update `localNotesForSync()` method (line ~1801)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

- [ ] Update `getRecentlyViewedNotes()` method (line ~1873)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

- [ ] Update `listAfter()` method (line ~1906)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

- [ ] Update `list()` method (line ~2073)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

- [ ] Update `getPinnedNotes()` method (line ~2004)
  - Add userId check at start
  - Add `& note.userId.equals(userId)` to where clause

### Verification
- [ ] No compilation errors
- [ ] All methods return early if userId is null
- [ ] All queries include user_id filter

---

## FIX 2: Complete Database Clearing (30 minutes)

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

### Changes Required (line ~1037)
- [ ] Add `await delete(localTemplates).go();`
- [ ] Add `await delete(attachments).go();`
- [ ] Add `await delete(inboxItems).go();`
- [ ] Update debug message

### Verification
- [ ] No compilation errors
- [ ] clearAll() includes all 12 tables
- [ ] Debug message updated

---

## FIX 3: Add user_id to NoteTasks (3 hours)

### Part A: Schema Change

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

- [ ] Add `TextColumn get userId => text()();` to `NoteTasks` class (line ~163)
- [ ] Increment schema version to 30 (line ~509)
- [ ] Add migration in `onUpgrade` method:
  ```dart
  if (from < 30) {
    await m.addColumn(noteTasks, noteTasks.userId);
    await customStatement('''
      UPDATE note_tasks SET user_id = (
        SELECT user_id FROM local_notes
        WHERE local_notes.id = note_tasks.note_id
        LIMIT 1
      )
    ''');
  }
  ```
- [ ] Update `getTasksForNote()` to filter by userId

### Part B: Repository Updates

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart`

- [ ] Update `createTask()` to set userId in companion (line ~215)
- [ ] Update `getAllTasks()` to filter by userId (line ~160)
- [ ] Update `getPendingTasks()` to filter by userId (line ~176)
- [ ] Update `updateTask()` to preserve userId
- [ ] Update all query methods to include userId filter

### Verification
- [ ] No compilation errors
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs` succeeds
- [ ] Migration runs without errors
- [ ] Tasks are filtered by user_id in all queries

---

## FIX 4: Add user_id to PendingOps (2 hours)

**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

### Changes Required
- [ ] Add `TextColumn get userId => text()();` to `PendingOps` class (line ~59)
- [ ] In migration (version 30):
  - [ ] Add `await m.addColumn(pendingOps, pendingOps.userId);`
  - [ ] Add `await delete(pendingOps).go();` (clear existing queue)
- [ ] Update `enqueue()` method (line ~1005):
  - [ ] Get userId from current user
  - [ ] Throw error if no user
  - [ ] Add userId to PendingOpsCompanion
- [ ] Update `getPendingOps()` method (line ~1014):
  - [ ] Check for userId
  - [ ] Filter by userId in query

### Verification
- [ ] No compilation errors
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs` succeeds
- [ ] Migration runs without errors
- [ ] Pending ops filtered by user_id

---

## FIX 5: Defensive Sync Validation (1 hour)

**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

### Changes Required
- [ ] Update `_applyRemoteNote()` method (line ~999):
  - [ ] Get currentUserId at start
  - [ ] Validate remoteNote['user_id'] == currentUserId
  - [ ] Log security violation if mismatch
  - [ ] Return early (skip note) if mismatch

- [ ] Apply same pattern to:
  - [ ] `_applyRemoteFolder()` (line ~1138)
  - [ ] `_applyRemoteTask()` (line ~1219)
  - [ ] `_applyRemoteTemplate()` (line ~1340)

### Verification
- [ ] No compilation errors
- [ ] Security violations logged to Sentry
- [ ] Mismatched data is skipped, not applied

---

## TESTING

### Unit Tests
- [ ] Run: `flutter test test/database_isolation_integration_test.dart`
- [ ] All tests pass
- [ ] No warnings

### Manual Testing - Scenario 1: User Switch
- [ ] Delete app from device
- [ ] Install fresh build
- [ ] Login as User A (test+a@example.com)
- [ ] Create 3 notes
- [ ] Create 2 tasks
- [ ] Create 1 folder
- [ ] **Verify**: All have userId set (check with debugger)
- [ ] Logout
- [ ] **Verify**: clearAll() called (check logs)
- [ ] Login as User B (test+b@example.com)
- [ ] **CRITICAL**: User B should see ZERO notes/tasks/folders
- [ ] Create 1 note for User B
- [ ] Logout
- [ ] Login as User A again
- [ ] **Verify**: User A sees their original 3 notes (synced from Supabase)

### Manual Testing - Scenario 2: Database Inspection
- [ ] After User B logs in, connect to device database
- [ ] Run: `SELECT COUNT(DISTINCT user_id) FROM local_notes WHERE deleted = 0;`
- [ ] **Expected**: Result = 1 (only User B's ID)
- [ ] Run: `SELECT COUNT(*) FROM local_notes WHERE user_id IS NULL OR user_id = '';`
- [ ] **Expected**: Result = 0 (no missing user_id)

### SQL Verification
- [ ] Connect to device database
- [ ] Run queries from `verify_data_isolation.sql`
- [ ] Section 2: All counts should be 0
- [ ] Section 3: user_count should be 1
- [ ] Section 4: 0 rows (no data leakage)
- [ ] Section 5: After clearAll(), all counts = 0

### Performance Testing
- [ ] Login with account that has 100+ notes
- [ ] **Verify**: Notes load quickly (< 2 seconds)
- [ ] Create new note
- [ ] **Verify**: Sync completes without errors
- [ ] Logout and login again
- [ ] **Verify**: All notes synced correctly

---

## CODE REVIEW

- [ ] Self-review all changes
- [ ] Check for typos in SQL
- [ ] Verify all log messages are clear
- [ ] Check Sentry error tags are correct
- [ ] Ensure no debug code left in
- [ ] Run `flutter analyze` - no new warnings
- [ ] Run `flutter test` - all tests pass
- [ ] Create PR with detailed description
- [ ] Request review from 2+ team members
- [ ] Address all review comments
- [ ] Get approval from senior engineer
- [ ] Get approval from security lead (if applicable)

---

## DEPLOYMENT PREPARATION

### Build Verification
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze` (0 issues)
- [ ] `flutter test` (all pass)

### Version Bump
- [ ] Update `pubspec.yaml` version: `x.y.z` → `x.y.(z+1)`
- [ ] Update changelog: Add security fix entry
- [ ] Commit version bump

### iOS Build
- [ ] Build: `flutter build ios --release`
- [ ] Archive in Xcode
- [ ] Test on physical iOS device
- [ ] Upload to TestFlight
- [ ] Test on TestFlight
- [ ] Submit to App Store Review
- [ ] Release notes: "Important security update"

### Android Build
- [ ] Build: `flutter build appbundle --release`
- [ ] Test on physical Android device
- [ ] Upload to Google Play Console
- [ ] Test with internal testing track
- [ ] Promote to production
- [ ] Release notes: "Important security update"

---

## POST-DEPLOYMENT MONITORING

### First 24 Hours
- [ ] Monitor Sentry for `securityViolation` errors
- [ ] Monitor Sentry for `dataLeakage` errors
- [ ] Check crash rates (should not increase)
- [ ] Monitor support channels for user reports
- [ ] Check App Store/Play Store reviews
- [ ] Run SQL health checks on sample devices

### First Week
- [ ] Daily review of Sentry errors
- [ ] Weekly database health check:
  ```sql
  SELECT COUNT(DISTINCT user_id) FROM local_notes WHERE deleted = 0;
  -- Should be 1 or 0
  ```
- [ ] Monitor user retention (should not decrease)
- [ ] Check for support tickets related to data issues
- [ ] Verify sync operations working correctly

### Success Metrics
- [ ] 0 reports of "seeing other user's data"
- [ ] 0 `securityViolation` errors in Sentry
- [ ] 0 `dataLeakage` errors in Sentry
- [ ] No increase in crash rate
- [ ] Sync success rate > 95%

---

## ROLLBACK PLAN

### If Critical Issues Arise

**Option 1: Emergency Hotfix**
- [ ] Identify the issue
- [ ] Create hotfix branch from previous release
- [ ] Apply minimal fix
- [ ] Test
- [ ] Deploy

**Option 2: Revert to Previous Version**
- [ ] Pull previous version from App Store
- [ ] Deploy to all users
- [ ] Force update in app

**Option 3: Data Recovery**
- [ ] Guide users to logout and login again
- [ ] Force full sync from Supabase
- [ ] Clear local database

### Rollback Checklist
- [ ] Notify users via push notification
- [ ] Post status update on website/social media
- [ ] Create incident report
- [ ] Schedule post-mortem meeting

---

## COMPLETION CRITERIA

### Definition of Done
- [ ] All 5 P0 fixes implemented
- [ ] All tests pass
- [ ] Code reviewed and approved
- [ ] Deployed to production (iOS + Android)
- [ ] No critical bugs in first 24 hours
- [ ] 0 data leakage reports
- [ ] 0 security violation errors

### Documentation
- [ ] Update README with security improvements
- [ ] Update architecture docs
- [ ] Add to team wiki
- [ ] Create runbook for future reference

### Team Communication
- [ ] Present fix summary to team
- [ ] Document lessons learned
- [ ] Update code review checklist
- [ ] Schedule follow-up for P1/P2 fixes

---

## FOLLOW-UP ITEMS (P1/P2)

Schedule these for next sprint:

### P1 - High Priority (Week 2)
- [ ] Add user_id to `NoteReminders` table
- [ ] Add user_id to `NoteTags` table
- [ ] Add user_id to `NoteLinks` table
- [ ] Add user_id filtering to TaskCoreRepository
- [ ] Create automated CI/CD tests

### P2 - Medium Priority (Week 3-4)
- [ ] Add user_id to `Attachments` table
- [ ] Implement linter rules
- [ ] Update documentation
- [ ] Team training on user isolation patterns

---

## NOTES & REMINDERS

### Important Points
- ⚠️ This is a CRITICAL security fix
- ⚠️ Do not publicly disclose the vulnerability
- ⚠️ Test thoroughly before deploying
- ⚠️ Monitor closely after deployment
- ✅ Supabase security is already correct
- ✅ Local database is the only issue

### Time Estimates
- **Implementation**: 8-10 hours
- **Testing**: 4-6 hours
- **Code Review**: 2-4 hours
- **Deployment**: 2-4 hours
- **Total**: 2-3 days

### Key Files Modified
1. `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`
2. `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart`
3. `/Users/onronder/duru-notes/lib/data/local/app_db.dart`

### Questions?
Refer to:
- [DATABASE_SECURITY_FIX_SUMMARY.md](./DATABASE_SECURITY_FIX_SUMMARY.md)
- [DATABASE_INTEGRITY_AUDIT_REPORT.md](./DATABASE_INTEGRITY_AUDIT_REPORT.md)
- [DATABASE_INTEGRITY_IMMEDIATE_FIXES.md](./DATABASE_INTEGRITY_IMMEDIATE_FIXES.md)

---

**Version**: 1.0
**Date**: 2025-10-24
**Status**: Ready for Implementation

---

## SIGN-OFF

**Developer**: _________________ Date: _________
- [ ] All fixes implemented
- [ ] All tests pass
- [ ] Ready for code review

**Code Reviewer**: _________________ Date: _________
- [ ] Code reviewed
- [ ] No security concerns
- [ ] Approved for deployment

**QA Engineer**: _________________ Date: _________
- [ ] All test scenarios passed
- [ ] No critical bugs found
- [ ] Approved for production

**Release Manager**: _________________ Date: _________
- [ ] Build verified
- [ ] Deployment successful
- [ ] Monitoring in place
