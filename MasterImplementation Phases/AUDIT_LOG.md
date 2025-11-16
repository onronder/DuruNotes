---
**Document**: Service Layer Architecture Audit Log
**Version**: 1.0.0
**Created**: 2025-11-16T22:41:12Z
**Author**: Claude Code AI Assistant
**Git Commit**: de1dcfe0 (will be updated on commit)
**Purpose**: Track services with direct AppDb access requiring refactoring
**Related Documents**:
  - ARCHITECTURE_VIOLATIONS.md v1.0.0
  - DELETION_PATTERNS.md v1.0.0
  - MASTER_IMPLEMENTATION_PLAN.md v2.1.0

**CHANGELOG**:
- 1.0.0 (2025-11-16): Initial audit of service layer database access patterns

---

# Service Layer Architecture Audit Log

## Purpose

This document tracks all services in `lib/services/` that have direct `AppDb` dependencies, categorizing them by:
1. **Legitimate** - Direct database access is architecturally appropriate
2. **Needs Refactoring** - Should use repository pattern instead
3. **Under Review** - Requires architectural decision

---

## Audit Summary

**Total Services Audited**: 7
**Needs Refactoring**: 4
**Legitimate**: 1
**Under Review**: 2
**Last Audit Date**: 2025-11-16

---

## Services Requiring Refactoring

### 1. ❌ EnhancedTaskService

**File**: `lib/services/enhanced_task_service.dart`

**Current State**:
```dart
class EnhancedTaskService {
  final AppDb _db;  // ❌ Direct database access
  final TaskReminderBridge _reminderBridge;

  EnhancedTaskService(this._db, this._reminderBridge);
}
```

**Issues Found**:
- **Line 65**: `await _db.getTaskById()` - Should use `_taskRepository.getTaskById()`
- **Line 73**: `await _db.getTasksForNote()` - Should use `_taskRepository.getTasksForNote()`
- **Line 125**: `await _db.createTask()` - Should use `_taskRepository.createTask()`
- **Line 135**: `await _db.updateTask()` - Should use `_taskRepository.updateTask()`
- **Line 305**: `await _db.deleteTaskById()` - **CRITICAL** - Bypasses soft delete, should use `_taskRepository.deleteTask()`
- **20+ total violations** - See ARCHITECTURE_VIOLATIONS.md for complete list

**Priority**: **P0 - CRITICAL**

**Impact**:
- Tasks deleted via this service are permanently removed (hard delete)
- Users cannot recover accidentally deleted tasks
- Violates 30-day retention policy
- Breaks trash system functionality

**Remediation Plan**:
1. Inject `TaskCoreRepository` instead of `AppDb`
2. Replace all 20+ `_db.*` calls with repository methods
3. Add unit tests to verify repository usage
4. Add integration tests for trash functionality

**Estimated Effort**: 2-3 hours

**Status**: ⏸️ Pending (documented in ARCHITECTURE_VIOLATIONS.md)

**Owner**: TBD

**Target Completion**: 2025-11-17

---

### 2. ⚠️ UnifiedShareService

**File**: `lib/services/unified_share_service.dart`

**Current State**:
```dart
class UnifiedShareService {
  final AppDb _db;  // ⚠️ May need repository pattern

  UnifiedShareService(this._db);
}
```

**Needs Investigation**:
- Does this service perform deletions?
- Does it query notes/tasks that should respect `deleted_at`?
- Can operations be moved to repository?

**Priority**: **P2 - Medium**

**Status**: ⏸️ Needs architectural review

**Audit Required**:
1. Scan for all `_db.*` method calls
2. Identify CRUD operations
3. Check if deletion logic exists
4. Verify query filtering for deleted items

**Owner**: TBD

**Target Completion**: 2025-11-20

---

### 3. ⚠️ UnifiedAISuggestionsService

**File**: `lib/services/unified_ai_suggestions_service.dart`

**Current State**:
```dart
class UnifiedAISuggestionsService {
  final AppDb _db;  // ⚠️ May need repository pattern

  UnifiedAISuggestionsService(this._db);
}
```

**Needs Investigation**:
- Read-only access to notes/tasks for AI processing?
- Does it respect `deleted_at` filtering?
- Should use repository for consistency?

**Priority**: **P2 - Medium**

**Status**: ⏸️ Needs architectural review

**Audit Required**:
1. Verify all queries filter `deleted_at.isNull()`
2. Check if read-only or includes writes
3. Assess if repository abstraction adds value

**Owner**: TBD

**Target Completion**: 2025-11-20

---

### 4. ⚠️ TaskService (Legacy)

**File**: `lib/services/task_service.dart`

**Current State**:
```dart
class TaskService {
  final AppDb _db;  // ⚠️ Legacy service, may be replaced by EnhancedTaskService

  TaskService(this._db);
}
```

**Questions**:
- Is this service still in use?
- Is it superseded by `EnhancedTaskService`?
- Can it be deprecated/removed?

**Priority**: **P3 - Low** (if deprecated)

**Status**: ⏸️ Needs investigation

**Action Items**:
1. Grep codebase for usage of `TaskService` vs `EnhancedTaskService`
2. If still used, refactor to repository pattern
3. If deprecated, remove from codebase

**Owner**: TBD

**Target Completion**: 2025-11-22

---

## Services Under Review

### 5. ⚠️ TaskReminderBridge

**File**: `lib/services/task_reminder_bridge.dart`

**Current State**:
```dart
class TaskReminderBridge {
  final AppDb _db;  // ⚠️ Needs review

  TaskReminderBridge(this._db);
}
```

**Architectural Question**:
- Bridge pattern may legitimately need low-level access
- Alternative: Inject both `TaskRepository` and `ReminderRepository`
- Need to determine if database transactions span both domains

**Priority**: **P2 - Medium**

**Status**: ⏸️ Under architectural review

**Review Criteria**:
1. Does bridge coordinate transactions across task + reminder tables?
2. Can coordination be done at repository layer?
3. Is direct DB access essential for atomicity?

**Owner**: TBD

**Decision Deadline**: 2025-11-18

---

### 6. ⚠️ ReminderCoordinator

**File**: `lib/services/reminder_coordinator.dart`

**Current State**:
```dart
class ReminderCoordinator {
  final AppDb _db;  // ⚠️ Needs review

  ReminderCoordinator(this._db);
}
```

**Architectural Question**:
- Coordinator pattern may need cross-repository operations
- Reminders are intentionally hard-deleted per product requirements
- May not need soft-delete pattern

**Priority**: **P2 - Medium**

**Status**: ⏸️ Under architectural review

**Review Criteria**:
1. Does coordinator orchestrate multiple repositories?
2. Is reminder hard-delete behavior correct?
3. Should use `ReminderRepository` instead of `AppDb`?

**Owner**: TBD

**Decision Deadline**: 2025-11-18

---

## Legitimate Direct Database Access

### 7. ✅ DatabaseOptimizer

**File**: `lib/services/database_optimizer.dart`

**Current State**:
```dart
class DatabaseOptimizer {
  final AppDb _db;  // ✅ Legitimate - low-level database maintenance

  DatabaseOptimizer(this._db);
}
```

**Rationale**:
- Performs database maintenance operations (VACUUM, ANALYZE, index rebuilding)
- These operations MUST access database layer directly
- Repository pattern not applicable for DB admin tasks
- Operations do not involve business logic or CRUD

**Operations**:
- `VACUUM` - Reclaim storage space
- `ANALYZE` - Update query planner statistics
- Index rebuilding
- Schema verification
- Integrity checks

**Status**: ✅ **Approved** - No refactoring needed

**Last Reviewed**: 2025-11-16

---

## Intentionally Excluded Services

### Advanced Reminder Service

**File**: `lib/services/advanced_reminder_service.dart`

**Current Behavior**:
```dart
// Line 784: Hard delete reminders
await _db.deleteReminderById(reminderId);
```

**Status**: ✅ **Correct Behavior**

**Rationale**:
- Reminders are **intentionally hard-deleted** per product requirements
- Reminders are ephemeral notifications, not user content
- No trash/recovery needed for reminders
- When a task is deleted, associated reminder is immediately removed

**Documented In**: ARCHITECTURE_VIOLATIONS.md - "OUT OF SCOPE" section

---

## Refactoring Checklist

For each service requiring refactoring, complete these steps:

### Phase 1: Preparation
- [ ] Read service file and document all `_db.*` method calls
- [ ] Identify corresponding repository methods
- [ ] Check if repository methods exist (create if missing)
- [ ] Write unit test scaffold

### Phase 2: Refactoring
- [ ] Update constructor to inject repository instead of `AppDb`
- [ ] Replace all `_db.*` calls with `_repository.*` calls
- [ ] Update provider configuration (if using Riverpod/Provider)
- [ ] Add inline documentation referencing DELETION_PATTERNS.md

### Phase 3: Testing
- [ ] Unit tests verify repository method calls
- [ ] Integration tests verify trash functionality
- [ ] No direct `AppDb` method calls remain
- [ ] Architecture tests pass

### Phase 4: Review
- [ ] Code review by second developer
- [ ] Architecture tests in CI pass
- [ ] Documentation updated
- [ ] Update this audit log with completion status

---

## Completion Tracking

| Service | Priority | Status | Start Date | Completion Date | Owner |
|---------|----------|--------|------------|-----------------|-------|
| EnhancedTaskService | P0 | ⏸️ Pending | TBD | TBD | TBD |
| UnifiedShareService | P2 | ⏸️ Review | TBD | TBD | TBD |
| UnifiedAISuggestionsService | P2 | ⏸️ Review | TBD | TBD | TBD |
| TaskService (Legacy) | P3 | ⏸️ Review | TBD | TBD | TBD |
| TaskReminderBridge | P2 | ⏸️ Arch Review | TBD | TBD | TBD |
| ReminderCoordinator | P2 | ⏸️ Arch Review | TBD | TBD | TBD |

---

## Next Actions

### Immediate (This Week)
1. **Fix EnhancedTaskService** (P0) - 2-3 hours
   - Highest impact
   - Blocking trash system functionality
   - Clear remediation path

2. **Create Architecture Tests** - 1 hour
   - Prevent future violations
   - Add to CI pipeline
   - See ARCHITECTURE_VIOLATIONS.md Step 5

### Short Term (Next 2 Weeks)
3. **Audit UnifiedShareService** - 2 hours
   - Scan for `_db.*` calls
   - Assess repository refactoring need
   - Document findings

4. **Audit UnifiedAISuggestionsService** - 2 hours
   - Verify deleted item filtering
   - Check query patterns
   - Make architectural decision

5. **Investigate TaskService vs EnhancedTaskService** - 1 hour
   - Determine if legacy/deprecated
   - Plan consolidation or removal

### Medium Term (Next Sprint)
6. **Review Bridge/Coordinator Patterns** - 4 hours
   - Architectural decision for TaskReminderBridge
   - Architectural decision for ReminderCoordinator
   - Document approved patterns

7. **Update DELETION_PATTERNS.md** - 1 hour
   - Add coordinator pattern guidance
   - Add bridge pattern guidance
   - Document exceptions to repository rule

---

## Metrics

### Progress Metrics
- **Services Audited**: 7 / 7 (100%)
- **Services Refactored**: 0 / 4 (0%)
- **Architectural Decisions Made**: 1 / 2 (50%)
- **Tests Created**: 0 / 4 (0%)

### Quality Metrics (Target)
- **Architecture Test Coverage**: 100% (all services scanned)
- **Service → Repository Pattern**: 100% (where applicable)
- **Trash Functionality**: 100% (all entities soft-delete correctly)

---

## References

- **ARCHITECTURE_VIOLATIONS.md v1.0.0** - Detailed analysis of EnhancedTaskService bypass
- **DELETION_PATTERNS.md v1.0.0** - Correct patterns for all service implementations
- **MASTER_IMPLEMENTATION_PLAN.md v2.1.0** - Phase 1.1 completion status
- **Phase1.1.md v1.2.0** - Original soft-delete implementation plan

---

**Document Status**: ACTIVE
**Next Audit**: After P0 fix complete (estimated 2025-11-17)
**Update Frequency**: After each service refactoring
**Owner**: Development Team
**Approver**: Architecture Review Team
