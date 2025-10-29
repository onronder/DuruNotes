# Security Testing Matrix - P0-P4 Validation

**Generated**: 2025-10-24
**Purpose**: Comprehensive test scenarios for all security phases
**Coverage**: User isolation, data integrity, performance, edge cases

---

## Test Execution Priority

| Priority | Phase | Risk if Skipped | Automation Required |
|----------|-------|-----------------|---------------------|
| **P0** | Critical User Isolation | Data breach | YES - CI/CD blocking |
| **P1** | Cross-Feature Integration | Functional breaks | YES - Regression suite |
| **P2** | Migration Safety | Data loss | YES - Migration tests |
| **P3** | Performance Validation | User experience | NO - Manual acceptable |
| **P4** | Edge Cases | Corner case bugs | PARTIAL - Key scenarios |

---

## 🔴 P0: Critical User Isolation Tests (MUST PASS)

### Test Suite: Multi-User Data Isolation

#### TEST-001: Basic User Switch
```gherkin
Given User A is logged in with 10 notes, 5 tasks, 3 folders
When User A logs out
And User B logs in
Then User B should see 0 notes, 0 tasks, 0 folders
And database should contain only User B's data
And no SecretBox deserialization errors should occur
```

#### TEST-002: Rapid User Switching
```gherkin
Given Users A, B, and C exist
When performing 20 rapid login/logout cycles between users
Then each user sees only their own data
And no data corruption occurs
And memory usage remains stable
```

#### TEST-003: Encryption Key Isolation
```gherkin
Given User A has encrypted notes with passphrase "PasswordA"
When User A logs out and User B logs in
And User B sets passphrase "PasswordB"
Then User B's encryption works independently
And no keychain collision occurs
And User A's keys are not accessible
```

#### TEST-004: Provider State Isolation
```gherkin
Given User A has active Riverpod provider state
When User A logs out
Then all 27 providers should be invalidated
And User B starts with fresh provider state
And no cached data leaks between sessions
```

### Validation Queries
```dart
// Verify complete isolation
Future<bool> verifyUserIsolation(String userId) async {
  final db = ref.read(appDbProvider);

  // Check notes
  final notes = await db.select(db.localNotes).get();
  final wrongUserNotes = notes.where((n) => n.userId != userId);
  assert(wrongUserNotes.isEmpty, 'Found notes from other users!');

  // Check tasks
  final tasks = await db.select(db.noteTasks).get();
  // After P1: verify tasks.where((t) => t.userId != userId).isEmpty

  // Check templates
  final templates = await db.select(db.localTemplates)
    .where((t) => t.isSystem.equals(false))
    .get();
  final wrongUserTemplates = templates.where((t) => t.userId != userId);
  assert(wrongUserTemplates.isEmpty, 'Found templates from other users!');

  return true;
}
```

---

## 🟡 P1: Repository Filtering Tests

### Test Suite: Query Filtering Verification

#### TEST-101: Repository userId Filtering
```dart
@Test
Future<void> testRepositoryFiltering() async {
  // Setup: Create data for multiple users
  await createTestNote(userId: 'user_a', title: 'Note A');
  await createTestNote(userId: 'user_b', title: 'Note B');

  // Test: Query as User A
  when(mockAuth.currentUser?.id).thenReturn('user_a');
  final notes = await notesRepo.getAllNotes();

  // Verify: Only User A's notes returned
  expect(notes.length, 1);
  expect(notes.first.title, 'Note A');
}
```

#### TEST-102: Pagination with Filtering
```gherkin
Given 100 notes exist for User A and 100 for User B
When User A requests page 2 with 20 items per page
Then only User A's notes 21-40 are returned
And total count shows 100 (not 200)
```

#### TEST-103: Search with User Isolation
```gherkin
Given User A has note "Secret Project"
And User B has note "Secret Recipe"
When User A searches for "Secret"
Then only "Secret Project" is returned
And FTS index respects user boundaries
```

### Performance Benchmarks
```dart
@Benchmark
Future<void> measureQueryPerformance() async {
  // Baseline (without userId filter)
  final baselineTime = await measureQuery(() =>
    db.select(db.localNotes).get()
  );

  // With userId filter
  final filteredTime = await measureQuery(() =>
    (db.select(db.localNotes)
      ..where((n) => n.userId.equals('test_user')))
      .get()
  );

  // Assert performance degradation < 20%
  final degradation = (filteredTime - baselineTime) / baselineTime;
  expect(degradation, lessThan(0.20));
}
```

---

## 🟡 P2: Migration & Schema Tests

### Test Suite: Safe Migration Validation

#### TEST-201: Null userId Backfill
```dart
@Test
Future<void> testUserIdBackfill() async {
  // Setup: Create notes without userId (legacy data)
  await db.customStatement('''
    INSERT INTO local_notes (id, title_encrypted, user_id)
    VALUES ('legacy_1', 'encrypted_title', NULL)
  ''');

  // Execute: Migration
  await Migration25SecurityUserIdPopulation.run(db, 24);

  // Verify: userId populated
  final note = await db.getNoteById('legacy_1');
  expect(note.userId, isNotNull);
  expect(note.userId, equals(currentUserId));
}
```

#### TEST-202: NoteTasks userId Migration
```gherkin
Given NoteTasks exist without userId column
When P1 migration adds userId column
Then existing tasks are linked to their parent note's userId
And no orphaned tasks remain
And task-note relationships preserved
```

#### TEST-203: Non-Nullable Migration Safety
```gherkin
Given notes exist with null userId values
When P2 migration makes userId non-nullable
Then migration succeeds without data loss
And orphaned notes get placeholder userId
And sync doesn't break for migrated data
```

### Rollback Tests
```dart
@Test
Future<void> testMigrationRollback() async {
  // Apply P2 changes
  await applyP2Migration();

  // Create new data
  await createTestData();

  // Rollback
  await rollbackP2Migration();

  // Verify data integrity
  final notes = await db.getAllNotes();
  expect(notes, isNotEmpty);
  expect(() => syncService.syncAll(), completes);
}
```

---

## 🟢 P3: Integration Tests

### Test Suite: Cross-Feature Validation

#### TEST-301: Notes + Tasks + Reminders
```gherkin
Given a note with 3 tasks and 2 reminders
When User A logs out and User B logs in
Then User B sees no tasks or reminders
And creating new note with tasks works
And reminders fire only for correct user
```

#### TEST-302: Sync + Realtime + Offline
```gherkin
Given User A creates notes offline
When going online with userId validation
Then sync completes successfully
And realtime updates respect user boundaries
And no cross-user contamination occurs
```

#### TEST-303: Templates + Search + Analytics
```gherkin
Given User A has custom templates and search history
When User B logs in
Then User B sees only system templates
And search returns no results from User A
And analytics show zero activity
```

### Load Testing
```dart
@LoadTest
Future<void> testHighVolumeUserSwitching() async {
  // Simulate 100 user switches
  for (int i = 0; i < 100; i++) {
    final userId = 'user_$i';

    // Login
    await auth.signIn(userId);

    // Create data
    await createTestNotes(count: 10);
    await createTestTasks(count: 5);

    // Verify isolation
    final notes = await notesRepo.getAllNotes();
    expect(notes.length, 10);

    // Logout
    await auth.signOut();

    // Verify cleanup
    final db = ref.read(appDbProvider);
    await db.clearAll();
  }

  // Check for memory leaks
  expect(memoryUsage(), lessThan(initialMemory * 1.5));
}
```

---

## 🔴 P4: New Security Gap Tests

### Test Suite: Attachment Isolation

#### TEST-401: File Attachment Security
```gherkin
Given User A uploads file "secret.pdf" to a note
When User B logs in
Then User B cannot access "secret.pdf"
And attachment queries filter by userId
And file storage paths include userId
```

#### TEST-402: FTS Index Isolation
```gherkin
Given FTS index contains data from multiple users
When searching as User A
Then results contain only User A's content
And no information leakage through search
```

#### TEST-403: Reminder Persistence
```gherkin
Given User A sets 5 reminders
When User A logs out and User B logs in
Then User B sees no reminders
And User A's reminders don't fire for User B
And reminder storage includes userId
```

---

## Edge Case Testing

### Concurrent Access
```dart
@Test
Future<void> testConcurrentUserAccess() async {
  // Simulate two devices with different users
  final device1 = await createSession('user_a');
  final device2 = await createSession('user_b');

  // Concurrent operations
  await Future.wait([
    device1.createNote('Note from A'),
    device2.createNote('Note from B'),
  ]);

  // Verify isolation maintained
  final notesA = await device1.getNotes();
  final notesB = await device2.getNotes();

  expect(notesA.any((n) => n.title.contains('B')), isFalse);
  expect(notesB.any((n) => n.title.contains('A')), isFalse);
}
```

### Crash Recovery
```gherkin
Given User A is logged in with active session
When app crashes during logout
And User B attempts to login
Then database is cleared before User B access
And no partial data remains
And recovery is transparent
```

### Token Expiration
```gherkin
Given User A's auth token expires
When automatic refresh fails
And User B logs in
Then User A's data is cleared
And User B starts fresh
And no auth token confusion
```

---

## Performance Testing Requirements

### Baseline Metrics (Pre-P1)
- Note query: < 50ms for 1000 notes
- Task query: < 30ms for 500 tasks
- Search: < 100ms for full-text search
- Sync: < 5s for 100 note delta

### Target Metrics (Post-P3)
- Note query: < 60ms with userId filter
- Task query: < 35ms with userId filter
- Search: < 120ms with user isolation
- Sync: < 6s with validation

### Stress Test Scenarios
1. 10,000 notes per user
2. 1,000 tasks per note
3. 50 rapid user switches
4. 100 concurrent sync operations

---

## Automated Test Pipeline

### CI/CD Integration
```yaml
security-tests:
  stage: test
  script:
    # P0: Critical isolation tests (blocking)
    - flutter test test/security/p0_isolation_test.dart

    # P1: Repository filtering (blocking)
    - flutter test test/security/p1_repository_test.dart

    # P2: Migration safety (warning only)
    - flutter test test/security/p2_migration_test.dart || true

    # Performance regression (warning only)
    - flutter test test/performance/query_benchmark_test.dart || true

  artifacts:
    reports:
      junit: test-results.xml
      coverage: coverage/lcov.info
```

### Test Coverage Requirements
- P0 Tests: **100%** coverage required
- P1 Tests: **90%** coverage required
- P2 Tests: **80%** coverage required
- P3 Tests: **70%** coverage required
- Edge Cases: **60%** coverage required

---

## Manual Testing Checklist

### User Acceptance Testing
- [ ] User can switch accounts 10 times without issues
- [ ] No visual data leakage (UI shows correct user's data)
- [ ] Encryption works independently per user
- [ ] Sync completes without errors
- [ ] Search returns only current user's results
- [ ] Reminders fire for correct user only
- [ ] Templates show user + system correctly
- [ ] Analytics track per-user metrics
- [ ] Attachments accessible only by owner
- [ ] No performance degradation noticed

### Security Verification
- [ ] Database inspection shows single user's data
- [ ] Keychain inspection shows isolated keys
- [ ] Network traffic shows correct userId
- [ ] Logs show no cross-user references
- [ ] Memory dumps contain no other user's data

---

## Test Data Generators

```dart
class SecurityTestData {
  static Future<void> createMultiUserScenario() async {
    // User A: Heavy user
    await createUser('user_a',
      notes: 1000,
      tasks: 500,
      folders: 50,
      templates: 20,
      attachments: 100
    );

    // User B: Light user
    await createUser('user_b',
      notes: 10,
      tasks: 5,
      folders: 2,
      templates: 0,
      attachments: 0
    );

    // User C: Edge cases
    await createUser('user_c',
      notes: 0, // Empty account
      tasks: 0,
      folders: 0,
      templates: 0,
      attachments: 0
    );
  }
}
```

---

## Success Criteria

### Phase Completion Gates

**P0 Complete When**:
- Zero data leakage incidents in testing
- All 27 providers properly invalidated
- No keychain collisions detected
- 100% of P0 tests passing

**P1 Complete When**:
- All repository methods filter by userId
- NoteTasks table has userId column
- Performance degradation < 20%
- 90% of P1 tests passing

**P2 Complete When**:
- All userId columns non-nullable
- Successful migration of legacy data
- Encryption format unified
- 80% of P2 tests passing

**P3 Complete When**:
- Architecture refactoring complete
- Automated tests integrated
- Security middleware operational
- 70% of P3 tests passing

**P4 Complete When**:
- Attachments isolated by user
- FTS index rebuilt with userId
- Reminders persisted with userId
- Analytics properly scoped
- 100% of P4 tests passing

---

## Monitoring & Alerting

### Production Metrics to Track
1. **Security Events**: Data leakage attempts, wrong userId access
2. **Performance**: Query times, sync duration, memory usage
3. **Errors**: SecretBox failures, RLS violations, migration errors
4. **User Impact**: Logout frequency, data loss reports

### Alert Thresholds
- Data leakage attempt: **IMMEDIATE** page
- Performance degradation > 50%: **HIGH** priority
- Error rate > 1%: **MEDIUM** priority
- Memory leak detected: **LOW** priority

---

This comprehensive testing matrix ensures complete validation of all security phases with focus on user isolation, data integrity, and system stability.