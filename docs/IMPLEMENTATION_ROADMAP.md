# Implementation Roadmap: P1-P3 Security Phases

**Version**: 1.0
**Last Updated**: 2025-10-24
**Status**: Ready for Execution

---

## Executive Summary

This roadmap provides a detailed, day-by-day plan for implementing userId-based security across Duru Notes application. The implementation is divided into three phases:

- **P1 (Weeks 1-2)**: Repository layer filtering (CRITICAL - security fix)
- **P2 (Week 3)**: Non-nullable userId database constraints
- **P3 (Weeks 4-5)**: Security middleware and automatic provider lifecycle

**Critical Path**: P1 must be completed first (fixes security vulnerability). P2 and P3 build on P1 foundation.

---

## Phase 1: Repository Layer Filtering (Weeks 1-2)

**Goal**: Add userId filtering to ALL repository queries to prevent cross-user data access

**Priority**: CRITICAL
**Estimated Duration**: 10 working days
**Team**: 2 developers (1 primary, 1 reviewer)

### Week 1: Days 1-5

#### Day 1: Setup and Planning

**Morning (4 hours)**:
- [ ] Create feature branch: `feature/p1-repository-filtering`
- [ ] Review ARCHITECTURAL_DECISION_RECORD.md
- [ ] Review SECURITY_DESIGN_PATTERNS.md
- [ ] Set up development environment
- [ ] Create test database with multi-user data

**Afternoon (4 hours)**:
- [ ] Update NotesCoreRepository: Add helper methods
  - `String? _getCurrentUserId()`
  - `void _validateUserId(String? userId)`
- [ ] Write unit tests for helper methods
- [ ] Commit: "feat(p1): Add userId helper methods to NotesCoreRepository"

**Deliverables**:
- Feature branch created
- Helper methods implemented and tested
- Team aligned on implementation approach

---

#### Day 2: NotesCoreRepository Read Operations

**Morning (4 hours)**:
- [ ] Update `getNoteById()` with userId filtering
- [ ] Update `localNotes()` with userId filtering
- [ ] Update `getPinnedNotes()` with userId filtering
- [ ] Write tests for each method (authorized and unauthorized access)
- [ ] Commit: "feat(p1): Add userId filtering to NotesCoreRepository read methods"

**Afternoon (4 hours)**:
- [ ] Update `listAfter()` (pagination) with userId filtering
- [ ] Update `searchNotes()` with userId filtering
- [ ] Update `getNotesByTag()` with userId filtering
- [ ] Write tests for pagination and search
- [ ] Commit: "feat(p1): Add userId filtering to pagination and search"

**Deliverables**:
- All read methods have userId filtering
- Comprehensive test coverage (90%+)

---

#### Day 3: NotesCoreRepository Write & Sync Operations

**Morning (4 hours)**:
- [ ] Update `updateLocalNote()` with userId validation
- [ ] Update `deleteNote()` with userId validation
- [ ] Update `_pushNoteOp()` with userId validation
- [ ] Write tests for write operations
- [ ] Commit: "feat(p1): Add userId validation to write operations"

**Afternoon (4 hours)**:
- [ ] Update `_applyRemoteNote()` with userId validation
- [ ] Add Sentry monitoring for userId mismatches
- [ ] Write tests for sync operations
- [ ] Code review: NotesCoreRepository changes
- [ ] Commit: "feat(p1): Add userId validation to sync operations"

**Deliverables**:
- All write and sync operations validated
- Monitoring in place for security violations

---

#### Day 4: TaskCoreRepository + NoteTasks Migration

**Morning (4 hours)**:
- [ ] Create migration: `20250124_add_userid_to_note_tasks.sql`
  ```sql
  ALTER TABLE note_tasks ADD COLUMN user_id TEXT;
  UPDATE note_tasks SET user_id = (
    SELECT user_id FROM local_notes WHERE id = note_tasks.note_id
  );
  DELETE FROM note_tasks WHERE user_id IS NULL;
  ```
- [ ] Update AppDb schema: `NoteTasks` table
- [ ] Test migration on local database
- [ ] Commit: "feat(p1): Add userId column to NoteTasks table"

**Afternoon (4 hours)**:
- [ ] Update TaskCoreRepository: Add helper methods
- [ ] Update `getTasksForNote()` with userId filtering
- [ ] Update `getAllTasks()` with userId filtering
- [ ] Update `getTaskById()` with userId filtering
- [ ] Write tests for task read operations
- [ ] Commit: "feat(p1): Add userId filtering to TaskCoreRepository read methods"

**Deliverables**:
- NoteTasks migration ready
- Task read operations secured

---

#### Day 5: TaskCoreRepository Completion + FolderCoreRepository

**Morning (4 hours)**:
- [ ] Update TaskCoreRepository write operations:
  - `createTask()` - add userId to companion
  - `updateTask()` - validate userId
  - `deleteTask()` - validate userId
- [ ] Write tests for task write operations
- [ ] Commit: "feat(p1): Add userId validation to TaskCoreRepository write methods"

**Afternoon (4 hours)**:
- [ ] Update FolderCoreRepository: Add helper methods
- [ ] Update folder read operations with userId filtering:
  - `getFolderById()`
  - `getAllFolders()`
  - `getRootFolders()`
  - `getSubfolders()`
- [ ] Write tests for folder operations
- [ ] Commit: "feat(p1): Add userId filtering to FolderCoreRepository"

**Deliverables**:
- TaskCoreRepository fully secured
- FolderCoreRepository read operations secured

---

### Week 2: Days 6-10

#### Day 6: Repository Completion + Service Updates

**Morning (4 hours)**:
- [ ] Update FolderCoreRepository write operations:
  - `createFolder()` - validate userId
  - `updateFolder()` - validate userId
  - `deleteFolder()` - validate userId
- [ ] Update TemplateRepository (system vs user templates)
- [ ] Write tests
- [ ] Commit: "feat(p1): Complete repository userId validation"

**Afternoon (4 hours)**:
- [ ] Update UnifiedSyncService:
  - Add `_validateAndCleanPendingOps()` method
  - Update `syncAll()` to call validation
- [ ] Update EnhancedTaskService:
  - Remove direct DB access
  - Force all operations through repository
- [ ] Write tests for service changes
- [ ] Commit: "feat(p1): Update services for userId validation"

**Deliverables**:
- All repositories fully secured
- Services updated to use secured repositories

---

#### Day 7: Realtime and Sync Enhancements

**Morning (4 hours)**:
- [ ] Update UnifiedRealtimeService:
  - Add runtime userId validation in `_handleChange()`
  - Add Sentry monitoring for userId mismatches
- [ ] Update FolderSyncCoordinator:
  - Add userId validation in `handleRealtimeUpdate()`
- [ ] Write tests for realtime validation
- [ ] Commit: "feat(p1): Enhance realtime userId validation"

**Afternoon (4 hours)**:
- [ ] Code review: Service layer changes
- [ ] Fix any issues from code review
- [ ] Run full test suite
- [ ] Performance benchmarks (before/after)
- [ ] Commit: "fix(p1): Address code review feedback"

**Deliverables**:
- Realtime validation enhanced
- Code review completed
- Performance baseline established

---

#### Day 8: Integration Testing

**Morning (4 hours)**:
- [ ] Write end-to-end security tests:
  - Multi-user scenarios
  - Cross-user access attempts
  - Sync with multiple users
  - Realtime with multiple users
- [ ] Run integration test suite
- [ ] Fix any failing tests

**Afternoon (4 hours)**:
- [ ] Manual testing:
  - Create two test accounts
  - Attempt cross-user access
  - Test sync behavior
  - Test logout/login flow
- [ ] Document test results
- [ ] Commit: "test(p1): Add comprehensive security tests"

**Deliverables**:
- Comprehensive test coverage
- Manual testing completed
- Test report documenting results

---

#### Day 9: Staging Deployment

**Morning (4 hours)**:
- [ ] Merge to staging branch
- [ ] Deploy to staging environment
- [ ] Run database migrations on staging
- [ ] Verify staging deployment

**Afternoon (4 hours)**:
- [ ] Smoke testing on staging:
  - Create notes/tasks/folders
  - Test sync
  - Test realtime updates
  - Test logout/login
- [ ] Monitor logs for errors
- [ ] Performance testing on staging
- [ ] Document any issues

**Deliverables**:
- Staging deployment successful
- Smoke tests passing
- Performance acceptable

---

#### Day 10: Production Deployment

**Morning (4 hours)**:
- [ ] Final code review with security team
- [ ] Update documentation:
  - API changes (if any)
  - Migration notes
  - Rollback procedures
- [ ] Create rollback branch (just in case)
- [ ] Schedule production deployment

**Afternoon (4 hours)**:
- [ ] Deploy to production:
  - Apply database migrations
  - Deploy application update
  - Verify deployment
- [ ] Monitor production:
  - Error logs
  - Performance metrics
  - User feedback
  - Sentry alerts
- [ ] Post-deployment testing
- [ ] Send deployment notification

**Deliverables**:
- P1 deployed to production
- Monitoring in place
- Team notified

---

## Phase 2: Non-Nullable userId (Week 3)

**Goal**: Make userId required at database level

**Priority**: HIGH
**Estimated Duration**: 5 working days
**Team**: 1 developer

### Day 11: Migration Planning

**Morning (4 hours)**:
- [ ] Create feature branch: `feature/p2-non-nullable-userid`
- [ ] Review P1 deployment metrics
- [ ] Plan migration strategy:
  - Identify tables needing migration
  - Plan backfill logic
  - Design rollback procedure
- [ ] Document migration plan

**Afternoon (4 hours)**:
- [ ] Create migration scripts:
  - `20250131_make_userid_non_nullable.sql`
- [ ] Test migration on local database
- [ ] Test rollback procedure
- [ ] Commit: "feat(p2): Create non-nullable userId migration"

**Deliverables**:
- Migration scripts ready
- Rollback procedure tested

---

### Day 12: Schema Updates

**Morning (4 hours)**:
- [ ] Update Drift schema:
  - `LocalNotes.userId: text()` (remove `.nullable()`)
  - `NoteTasks.userId: text()` (remove `.nullable()`)
  - `LocalFolders.userId: text()` (remove `.nullable()`)
- [ ] Run `flutter pub run build_runner build`
- [ ] Fix compilation errors
- [ ] Commit: "feat(p2): Update schema for non-nullable userId"

**Afternoon (4 hours)**:
- [ ] Update repository methods:
  - Remove null checks for userId
  - Update create operations to require userId
  - Stricter validation
- [ ] Update tests for non-nullable userId
- [ ] Commit: "feat(p2): Update repositories for non-nullable userId"

**Deliverables**:
- Schema updated
- Repositories updated
- Tests passing

---

### Day 13: Testing and Validation

**Morning (4 hours)**:
- [ ] Write migration tests:
  - Test backfill logic
  - Test null detection
  - Test rollback
- [ ] Run full test suite
- [ ] Fix any failing tests

**Afternoon (4 hours)**:
- [ ] Integration testing:
  - Fresh install (no migration)
  - Upgrade path (with migration)
  - Multi-user scenarios
- [ ] Performance testing
- [ ] Document test results

**Deliverables**:
- Migration thoroughly tested
- Integration tests passing

---

### Day 14: Staging Deployment

**Morning (4 hours)**:
- [ ] Deploy to staging
- [ ] Run migrations on staging
- [ ] Verify migration success
- [ ] Smoke testing

**Afternoon (4 hours)**:
- [ ] Extended testing on staging:
  - Create new entities
  - Update existing entities
  - Test sync
  - Test logout/login
- [ ] Monitor for issues
- [ ] Performance validation

**Deliverables**:
- Staging deployment successful
- Tests passing on staging

---

### Day 15: Production Deployment

**Morning (4 hours)**:
- [ ] Final review and approval
- [ ] Prepare rollback plan
- [ ] Schedule maintenance window (if needed)
- [ ] Deploy to production

**Afternoon (4 hours)**:
- [ ] Monitor production:
  - Migration success rate
  - Error logs
  - Performance metrics
  - User reports
- [ ] Post-deployment testing
- [ ] Document deployment results

**Deliverables**:
- P2 deployed to production
- Monitoring shows no issues

---

## Phase 3: Security Middleware & Automation (Weeks 4-5)

**Goal**: Centralize security validation and automate provider lifecycle

**Priority**: MEDIUM
**Estimated Duration**: 10 working days
**Team**: 2 developers

### Week 4: Days 16-20

#### Day 16: Security Middleware Design

**Morning (4 hours)**:
- [ ] Create feature branch: `feature/p3-security-middleware`
- [ ] Design SecurityMiddleware class:
  - API contract
  - Error handling
  - Logging strategy
- [ ] Review design with team
- [ ] Create implementation plan

**Afternoon (4 hours)**:
- [ ] Implement SecurityMiddleware:
  - `execute()` method
  - Error handling
  - Logging and monitoring
- [ ] Write unit tests
- [ ] Commit: "feat(p3): Implement SecurityMiddleware"

**Deliverables**:
- SecurityMiddleware implemented
- Unit tests passing

---

#### Day 17: Service Integration

**Morning (4 hours)**:
- [ ] Update EnhancedTaskService to use middleware
- [ ] Update UnifiedSyncService to use middleware
- [ ] Write tests for middleware integration
- [ ] Commit: "feat(p3): Integrate SecurityMiddleware in services"

**Afternoon (4 hours)**:
- [ ] Update remaining services:
  - NoteService (if exists)
  - FolderService (if exists)
  - Other services
- [ ] Remove duplicate security logic
- [ ] Write tests
- [ ] Commit: "feat(p3): Complete service middleware integration"

**Deliverables**:
- Services using middleware
- Duplicate logic removed

---

#### Day 18: Provider Lifecycle - Planning

**Morning (4 hours)**:
- [ ] Audit current providers:
  - List all data-related providers
  - Identify dependencies
  - Plan conversion order
- [ ] Design family provider architecture:
  - currentUserIdProvider
  - Repository family providers
  - Service family providers
  - Stream family providers
- [ ] Document conversion plan

**Afternoon (4 hours)**:
- [ ] Create currentUserIdProvider
- [ ] Test userId provider with auth changes
- [ ] Write tests
- [ ] Commit: "feat(p3): Create currentUserIdProvider"

**Deliverables**:
- Provider conversion plan documented
- currentUserIdProvider implemented

---

#### Day 19: Repository Family Providers

**Morning (4 hours)**:
- [ ] Convert to family providers:
  - `notesCoreRepositoryProvider`
  - `taskCoreRepositoryProvider`
  - `folderCoreRepositoryProvider`
- [ ] Update dependencies
- [ ] Write tests
- [ ] Commit: "feat(p3): Convert repository providers to family"

**Afternoon (4 hours)**:
- [ ] Convert service providers:
  - `enhancedTaskServiceProvider`
  - `unifiedSyncServiceProvider`
- [ ] Update dependencies
- [ ] Write tests
- [ ] Commit: "feat(p3): Convert service providers to family"

**Deliverables**:
- Repository providers are family providers
- Service providers are family providers

---

#### Day 20: Stream Family Providers

**Morning (4 hours)**:
- [ ] Convert stream providers:
  - `domainNotesStreamProvider`
  - `domainTasksStreamProvider`
  - `domainFoldersStreamProvider`
- [ ] Update UI consumers
- [ ] Write tests
- [ ] Commit: "feat(p3): Convert stream providers to family"

**Afternoon (4 hours)**:
- [ ] Remove manual invalidation code:
  - Delete `_invalidateAllProviders()` method
  - Clean up related code
- [ ] Update logout flow
- [ ] Write tests
- [ ] Commit: "feat(p3): Remove manual provider invalidation"

**Deliverables**:
- All providers are family providers
- Manual invalidation removed

---

### Week 5: Days 21-25

#### Day 21: UI Updates

**Morning (4 hours)**:
- [ ] Update UI consumers to use userId:
  - `NotesListScreen`
  - `TaskListScreen`
  - `FolderManagementScreen`
  - Other screens
- [ ] Fix compilation errors
- [ ] Write tests

**Afternoon (4 hours)**:
- [ ] Update remaining screens
- [ ] Verify all providers used correctly
- [ ] Clean up unused code
- [ ] Commit: "feat(p3): Update UI for family providers"

**Deliverables**:
- All UI updated
- No compilation errors

---

#### Day 22: Testing

**Morning (4 hours)**:
- [ ] Write integration tests:
  - Provider lifecycle tests
  - userId change scenarios
  - Logout/login flow
- [ ] Run full test suite
- [ ] Fix failing tests

**Afternoon (4 hours)**:
- [ ] Manual testing:
  - Provider invalidation on logout
  - New providers on login
  - Multi-account switching
  - Memory leak testing
- [ ] Performance benchmarks
- [ ] Document test results

**Deliverables**:
- Comprehensive testing completed
- Performance acceptable

---

#### Day 23: Staging Deployment

**Morning (4 hours)**:
- [ ] Code review with team
- [ ] Address review feedback
- [ ] Merge to staging branch
- [ ] Deploy to staging

**Afternoon (4 hours)**:
- [ ] Smoke testing on staging
- [ ] Extended testing:
  - Multi-user scenarios
  - Provider lifecycle
  - Memory usage
- [ ] Monitor for issues

**Deliverables**:
- Staging deployment successful
- Tests passing

---

#### Day 24: Production Deployment Prep

**Morning (4 hours)**:
- [ ] Final security review
- [ ] Update documentation:
  - Architecture diagrams
  - Provider patterns
  - Migration guide
- [ ] Prepare deployment plan
- [ ] Create rollback procedure

**Afternoon (4 hours)**:
- [ ] Feature flag configuration:
  - Enable P3 features gradually
  - A/B testing setup
- [ ] Monitoring setup:
  - Provider metrics
  - Security violations
  - Performance metrics
- [ ] Notify stakeholders

**Deliverables**:
- Production deployment ready
- Documentation updated

---

#### Day 25: Production Deployment

**Morning (4 hours)**:
- [ ] Deploy to production
- [ ] Verify deployment
- [ ] Enable feature flags (10% users)
- [ ] Monitor closely

**Afternoon (4 hours)**:
- [ ] Gradual rollout:
  - 25% users (if stable)
  - 50% users (if stable)
  - 100% users (if stable)
- [ ] Post-deployment monitoring:
  - Error rates
  - Performance metrics
  - User feedback
- [ ] Document deployment
- [ ] Send completion notification

**Deliverables**:
- P3 deployed to production
- Full rollout completed (if stable)
- Team notified

---

## Feature Flags

### P1 Feature Flags (Optional)

```dart
class FeatureFlags {
  // P1: Repository filtering
  static const bool enableRepositoryFiltering = true;

  // P1: Sync validation
  static const bool enableSyncValidation = true;

  // P1: Realtime validation enhancement
  static const bool enableRealtimeValidation = true;
}
```

**Usage**: P1 changes are critical security fixes - no feature flags needed (deploy directly)

### P2 Feature Flags (Optional)

```dart
class FeatureFlags {
  // P2: Non-nullable userId enforcement
  static const bool enforceNonNullableUserId = true;
}
```

**Usage**: P2 migration is all-or-nothing - no feature flags needed

### P3 Feature Flags (Recommended)

```dart
class FeatureFlags {
  // P3: Security middleware
  static const bool useSecurityMiddleware = true;

  // P3: Automatic provider lifecycle
  static const bool useFamilyProviders = true;
}
```

**Usage**: P3 changes can be gradually rolled out:
- Week 1: 10% users
- Week 2: 25% users
- Week 3: 50% users
- Week 4: 100% users (if stable)

---

## Rollback Procedures

### P1 Rollback

**Scenario**: Users cannot access their own data

**Steps**:
1. Revert application deployment
2. Keep database migrations (they don't break anything)
3. Deploy previous version
4. Investigate root cause
5. Fix and redeploy

**Rollback Time**: 15 minutes

### P2 Rollback

**Scenario**: Migration fails or app crashes

**Steps**:
1. Run rollback migration:
   ```sql
   ALTER TABLE local_notes ALTER COLUMN user_id DROP NOT NULL;
   ALTER TABLE note_tasks ALTER COLUMN user_id DROP NOT NULL;
   ALTER TABLE local_folders ALTER COLUMN user_id DROP NOT NULL;
   ```
2. Deploy previous app version
3. Investigate failures
4. Fix migration and redeploy

**Rollback Time**: 30 minutes

### P3 Rollback

**Scenario**: Performance issues or unexpected errors

**Steps**:
1. Disable feature flags:
   ```dart
   FeatureFlags.useSecurityMiddleware = false;
   FeatureFlags.useFamilyProviders = false;
   ```
2. Deploy config update (no code changes needed)
3. Monitor for stability
4. Investigate issues
5. Fix and re-enable

**Rollback Time**: 5 minutes (feature flag toggle)

---

## Success Criteria

### P1 Success Metrics

- [ ] Zero cross-user data access incidents
- [ ] All repository tests passing (90%+ coverage)
- [ ] No performance regression (< 5% slower)
- [ ] Zero Sentry errors for userId mismatches
- [ ] Successful deployment to production

### P2 Success Metrics

- [ ] Migration success rate > 99.9%
- [ ] Zero data loss incidents
- [ ] All tests passing with non-nullable userId
- [ ] No app crashes related to null userId
- [ ] Successful production deployment

### P3 Success Metrics

- [ ] Zero manual provider invalidation code remaining
- [ ] Memory usage stable or improved
- [ ] Provider lifecycle tests passing
- [ ] No performance regression
- [ ] Positive developer feedback (easier to maintain)

---

## Communication Plan

### Weekly Updates

**Audience**: Engineering team, product managers, stakeholders

**Content**:
- Progress update (% complete)
- Blockers and risks
- Next week's plan
- Questions for stakeholders

**Format**: Email + Slack update

### Deployment Notifications

**Audience**: All engineering, customer support

**Content**:
- What was deployed
- Expected impact
- Rollback procedure
- Who to contact for issues

**Format**: Slack announcement

### Post-Deployment Reports

**Audience**: Engineering leadership, product

**Content**:
- Deployment summary
- Metrics (performance, errors)
- User impact
- Lessons learned

**Format**: Document + presentation

---

## Contingency Plans

### If P1 Deployment Blocked

**Blocker**: Critical bug found in testing

**Action**:
1. Assess severity (security vs. functionality)
2. If security-critical: Fix immediately and redeploy
3. If functionality issue: Hotfix or rollback
4. Document root cause
5. Update testing procedures

### If P2 Migration Fails

**Blocker**: Users have null userId that can't be backfilled

**Action**:
1. Rollback migration
2. Investigate data inconsistencies
3. Write data cleanup script
4. Re-test migration
5. Schedule new deployment

### If P3 Causes Performance Issues

**Blocker**: Provider overhead or memory leaks

**Action**:
1. Disable feature flags immediately
2. Profile application to find bottleneck
3. Optimize hot paths
4. Re-test with load testing
5. Gradual re-rollout

---

## Resource Requirements

### Team Allocation

- **P1**: 2 developers (1 primary, 1 reviewer) × 2 weeks = 4 developer-weeks
- **P2**: 1 developer × 1 week = 1 developer-week
- **P3**: 2 developers × 2 weeks = 4 developer-weeks

**Total**: 9 developer-weeks (≈ 2 months with parallel work)

### Tools and Infrastructure

- Development environment
- Staging environment (multi-user data)
- Production deployment access
- Sentry account (monitoring)
- Feature flag system (P3)
- Load testing tools (performance validation)

---

## Conclusion

This roadmap provides a detailed, day-by-day plan for implementing P1-P3 security phases. The phased approach ensures:

1. **P1 (Critical)**: Addresses security vulnerability immediately
2. **P2 (Important)**: Strengthens database-level enforcement
3. **P3 (Enhancement)**: Improves maintainability and developer experience

Each phase has clear success criteria, rollback procedures, and contingency plans. The implementation is designed to be safe, testable, and deployable with minimal risk.

**Total Duration**: 5 weeks (25 working days)
**Team Size**: 2 developers (average)
**Risk Level**: LOW (with proper testing and rollback procedures)

**Next Step**: Approve roadmap and allocate resources to begin P1 implementation.
