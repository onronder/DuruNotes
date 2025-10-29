# TESTING STRATEGY MASTER PLAN

## Executive Summary
Comprehensive testing strategy for Duru Notes security implementation (P0-P3 phases). Ensures bulletproof user isolation, data integrity, and performance standards.

## Testing Philosophy
- **Security First**: Every test validates user isolation
- **Performance Aware**: No operation should degrade >10%
- **Real-World Focused**: Test actual user workflows, not edge cases
- **CI/CD Integrated**: Automated testing gates for every PR

## Test Pyramid

```
        E2E Tests (5%)
       /            \
      /  System      \
     / Integration    \
    /   Tests (15%)   \
   /                  \
  /   Integration      \
 /    Tests (30%)       \
/                        \
Unit Tests (50%)
```

### Unit Tests (50% - Target: 3000+ tests)
**Execution Time**: < 30 seconds
**Coverage Target**: 85%+

- **Repository Layer** (800 tests)
  - userId filtering in every query
  - Null userId handling
  - Cross-user data rejection

- **Service Layer** (1000 tests)
  - Business logic validation
  - Encryption/decryption
  - State management

- **Provider Layer** (600 tests)
  - State updates
  - Proper disposal
  - Invalidation cascades

- **Utility Functions** (600 tests)
  - Data converters
  - Validators
  - Formatters

### Integration Tests (30% - Target: 500+ tests)
**Execution Time**: < 2 minutes
**Coverage Target**: 70%+

- **Feature Workflows**
  - Notes: Create → Edit → Sync → Delete
  - Tasks: Create → Link → Complete → Archive
  - Folders: Create → Nest → Move → Delete
  - Reminders: Schedule → Snooze → Trigger
  - Templates: Create → Use → Share

- **Cross-Feature Integration**
  - Note + Tasks + Reminders
  - Folders + Notes + Search
  - Templates + Notes + Tasks

### System Integration Tests (15% - Target: 100+ tests)
**Execution Time**: < 5 minutes
**Coverage Target**: 60%+

- **Database Operations**
  - clearAll() with 10,000+ records
  - Concurrent user operations
  - Transaction rollbacks

- **Sync Operations**
  - Conflict resolution
  - Offline → Online sync
  - Cross-device sync

- **Security Scenarios**
  - User switching
  - Session expiration
  - Key rotation

### E2E Tests (5% - Target: 20+ tests)
**Execution Time**: < 10 minutes
**Coverage Target**: Critical paths only

- **Complete User Journeys**
  - New user onboarding
  - Daily note workflow
  - Task management flow
  - Multi-user switching

## Coverage Targets

### Critical Security Code (95%+ Required)
```dart
// Files requiring 95%+ coverage:
- lib/core/guards/auth_guard.dart
- lib/core/security/*
- lib/data/local/app_db.dart (clearAll method)
- lib/infrastructure/repositories/* (userId filtering)
- lib/services/security/*
```

### Core Business Logic (80%+ Required)
```dart
// Files requiring 80%+ coverage:
- lib/domain/repositories/*
- lib/services/*
- lib/features/*/providers/*
- lib/core/sync/*
```

### UI Code (60%+ Target)
```dart
// Files requiring 60%+ coverage:
- lib/ui/screens/*
- lib/features/*/widgets/*
```

## Test Execution Strategy

### Local Development
```bash
# Quick unit tests (< 30s)
flutter test --no-pub test/unit/

# Feature integration tests (< 2m)
flutter test --no-pub test/integration/

# Full test suite (< 10m)
flutter test --no-pub

# With coverage
flutter test --coverage --no-pub
lcov --remove coverage/lcov.info 'lib/generated/*' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
```

### CI/CD Pipeline
```yaml
# GitHub Actions workflow
test:
  stages:
    - unit_tests:      # Fast feedback (< 1m)
        parallel: true
        fail_fast: true
    - integration:     # Feature validation (< 3m)
        parallel: true
    - security:        # Critical tests (< 2m)
        parallel: false # Run sequentially for isolation
    - performance:     # Benchmarks (< 2m)
        compare: main
    - e2e:            # User journeys (< 10m)
        browsers: [chrome, safari]
```

### Test Parallelization
```dart
// Group tests for parallel execution
@Tags(['unit', 'fast'])
void main() {
  group('Repository Tests', () {
    // Tests run in parallel
  });
}

@Tags(['integration', 'slow'])
void main() {
  group('Sync Tests', () {
    // Tests run sequentially
  }, timeout: Timeout(Duration(minutes: 2)));
}
```

## Security Testing Requirements

### P0 - Critical Security Tests (MUST PASS)
1. **User Isolation**
   - User B cannot see User A data
   - Database cleared on logout
   - No cached data leakage

2. **Encryption Integrity**
   - Keys properly isolated
   - Data encrypted at rest
   - Keys cleared on logout

3. **RLS Enforcement**
   - Supabase policies enforced
   - Invalid userId rejected
   - Cross-user sync prevented

### P1 - Repository Layer Tests
1. **userId Filtering**
   ```dart
   test('repository filters by userId') {
     // Setup: Multiple users' data
     // Action: Query as User A
     // Assert: Only User A data returned
   }
   ```

2. **Null userId Handling**
   ```dart
   test('repository handles null userId') {
     // Setup: Data with null userId
     // Action: Query with userId filter
     // Assert: Null userId data excluded
   }
   ```

### P2 - Schema Migration Tests
1. **NoteTasks Backfill**
   ```dart
   test('backfill NoteTasks userId from parent note') {
     // Setup: 1000+ tasks without userId
     // Action: Run migration
     // Assert: All tasks have correct userId
   }
   ```

2. **Orphaned Data Handling**
   ```dart
   test('handle orphaned tasks gracefully') {
     // Setup: Tasks with deleted parent notes
     // Action: Run migration
     // Assert: Orphans deleted or assigned
   }
   ```

### P3 - Architecture Refactor Tests
1. **Provider Isolation**
   ```dart
   test('providers isolated per user') {
     // Setup: Switch users rapidly
     // Action: Access providers
     // Assert: No state leakage
   }
   ```

## Performance Benchmarks

### Critical Operations
| Operation | Current | Target | Maximum |
|-----------|---------|--------|---------|
| clearAll() with 10k records | - | < 500ms | 1000ms |
| Repository query with userId | - | < 50ms | 100ms |
| Sync validation per note | - | < 10ms | 20ms |
| Provider invalidation | - | < 5ms | 10ms |
| Encryption per note | - | < 20ms | 50ms |

### Load Testing Scenarios
```dart
test('handle 10,000 notes efficiently') {
  // Create 10,000 notes
  // Measure: Query time, memory usage
  // Assert: < 2s load time, < 200MB memory
}

test('rapid user switching performance') {
  // Switch users 10 times
  // Measure: Switch time, cleanup time
  // Assert: < 500ms per switch
}
```

## Test Data Management

### Test Data Builders
```dart
// Standardized test data creation
final userA = TestDataBuilder.user()
  .withId('user-a-123')
  .withEmail('usera@test.com')
  .build();

final note = TestDataBuilder.note()
  .withUserId(userA.id)
  .withEncryption()
  .withTasks(3)
  .build();
```

### Database Seeding
```dart
// Predefined scenarios
class TestScenarios {
  static Future<void> basicUserData(AppDb db, String userId);
  static Future<void> complexFolderHierarchy(AppDb db, String userId);
  static Future<void> largeDataset(AppDb db, String userId);
  static Future<void> edgeCases(AppDb db, String userId);
}
```

## Mock Strategy

### Service Mocks
```dart
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockEncryptionService extends Mock implements EncryptionService {}
class MockSyncService extends Mock implements SyncService {}
class MockKeyManager extends Mock implements KeyManager {}
```

### Repository Mocks
```dart
class MockNotesRepository extends Mock implements INotesRepository {}
class MockTaskRepository extends Mock implements ITaskRepository {}
class MockFolderRepository extends Mock implements IFolderRepository {}
```

## Continuous Monitoring

### Test Metrics Dashboard
- Test execution time trends
- Coverage trends
- Flaky test detection
- Performance regression alerts

### Quality Gates
```yaml
quality_gates:
  coverage:
    security_code: 95%  # Block if < 95%
    business_logic: 80% # Block if < 80%
    overall: 70%        # Warning if < 70%

  performance:
    regression: 10%     # Block if > 10% slower

  security:
    user_isolation: 100% # All must pass
    encryption: 100%     # All must pass
```

## Test Maintenance

### Weekly Tasks
- Review flaky tests
- Update test data
- Optimize slow tests
- Add tests for new features

### Monthly Tasks
- Coverage analysis
- Performance baseline update
- Mock service updates
- Test pyramid review

## Emergency Procedures

### Test Failure in Production
1. **Immediate**: Revert deployment
2. **Investigation**: Run full test suite locally
3. **Fix**: Add regression test
4. **Deploy**: With increased monitoring

### Security Test Failure
1. **Alert**: Security team immediately
2. **Isolate**: Affected users
3. **Patch**: Emergency fix
4. **Audit**: Full security review

## Documentation Requirements

### Test Documentation
- Each test file must have header explaining purpose
- Complex tests need inline comments
- Integration tests need workflow diagrams
- Performance tests need baseline documentation

### Living Documentation
```dart
test('User isolation is maintained across sessions',
  skip: false, // Never skip security tests
  timeout: Timeout(Duration(seconds: 30)),
  () async {
    // SECURITY: This test ensures User B cannot access User A's data
    // REQUIREMENT: SOC2 compliance - data isolation
    // ...
  },
);
```

## Success Metrics

### Sprint Metrics
- [ ] All P0 security tests passing (100%)
- [ ] Unit test coverage > 85%
- [ ] Integration test coverage > 70%
- [ ] No performance regression > 10%
- [ ] CI pipeline < 10 minutes

### Release Metrics
- [ ] Zero security test failures
- [ ] Zero data leakage incidents
- [ ] User switching < 500ms
- [ ] Database clear < 1 second
- [ ] 100% RLS enforcement

## Appendix

### Test File Organization
```
test/
├── unit/
│   ├── repositories/
│   ├── services/
│   ├── providers/
│   └── utils/
├── integration/
│   ├── features/
│   ├── workflows/
│   └── sync/
├── critical/         # P0 Security tests
│   ├── user_isolation_test.dart
│   ├── database_clearing_test.dart
│   └── encryption_integrity_test.dart
├── performance/
│   ├── benchmarks/
│   └── load_tests/
├── e2e/
│   └── user_journeys/
└── helpers/
    ├── test_data_builders.dart
    ├── mock_services.dart
    └── test_scenarios.dart
```

### Command Reference
```bash
# Run specific test categories
flutter test --no-pub --tags=unit
flutter test --no-pub --tags=integration
flutter test --no-pub --tags=security
flutter test --no-pub --tags=performance

# Run with coverage
flutter test --coverage --no-pub
open coverage/html/index.html

# Run specific phase tests
flutter test --no-pub test/critical/  # P0
flutter test --no-pub test/unit/repositories/  # P1
flutter test --no-pub test/migration/  # P2

# Performance profiling
flutter test --no-pub --profile test/performance/
```