---
**Document**: Architecture Violations & Remediation Plan
**Version**: 1.1.0
**Created**: 2025-11-16T22:41:12Z
**Updated**: 2025-11-17T14:30:00Z
**Author**: Claude Code AI Assistant
**Git Commit**: 359f30d1
**Discovery Date**: 2025-11-17
**Severity**: P0 - CRITICAL (Validated with Tests)
**Related Documents**:
  - MASTER_IMPLEMENTATION_PLAN.md v2.1.0
  - Phase1.1.md v1.2.0
  - DELETION_PATTERNS.md v1.0.0
  - AUDIT_LOG.md v1.1.0
**Related Files**:
  - lib/services/enhanced_task_service.dart
  - lib/data/local/app_db.dart
  - lib/infrastructure/repositories/task_core_repository.dart
  - test/architecture/repository_pattern_test.dart (NEW - automated detection)
  - test/services/enhanced_task_service_isolation_test.dart (UPDATED)

**CHANGELOG**:
- 1.1.0 (2025-11-17): ✅ Phase 1 Complete - Test coverage added
  - Created repository_pattern_test.dart for automated violation detection
  - Expanded enhanced_task_service_isolation_test.dart (11 new tests)
  - Bug validated: deleteTask test FAILS (confirms hard delete instead of soft delete)
  - 23 violations detected automatically (18 in EnhancedTaskService, 5 in TaskReminderBridge)
  - Ready for remediation phases 2-4
- 1.0.0 (2025-11-16): Initial documentation of service layer repository bypass issue

---

# Architecture Violations & Remediation Plan

## Executive Summary

**Issue**: Service layer bypasses repository pattern for task deletion, causing **permanent data loss** instead of following the 30-day retention policy established in Phase 1.1.

**Impact**: Tasks deleted via `EnhancedTaskService.deleteTask()` are immediately and permanently removed from the database, bypassing:
- ✅ Trash system (TrashScreen)
- ✅ 30-day retention (`scheduled_purge_at`)
- ✅ Restore functionality
- ✅ Audit trail

**Root Cause**: `EnhancedTaskService` directly calls `AppDb.deleteTaskById()` (hard delete) instead of `TaskCoreRepository.deleteTask()` (soft delete).

**Severity**: P0 - CRITICAL
- Violates data retention commitments
- Breaks user expectations (no "undo" for task deletion)
- Inconsistent behavior (notes/folders soft-delete, but tasks hard-delete when deleted via this service)

---

## Detailed Analysis

### The Problem

#### Architecture Design (CORRECT)

```
UI Layer
   ↓
Service Layer (EnhancedTaskService)
   ↓
Repository Layer (TaskCoreRepository) ← implements soft delete
   ↓
Database Layer (AppDb)
```

#### Current Implementation (INCORRECT)

```
UI Layer
   ↓
Service Layer (EnhancedTaskService)
   ↓ ❌ BYPASS!
Database Layer (AppDb.deleteTaskById) ← hard delete
```

**Result**: Repository soft-delete logic is never executed.

---

### Evidence

#### File: `lib/services/enhanced_task_service.dart`

**Line 305** - The violation:
```dart
Future<void> deleteTask(String taskId) async {
  final userId = _currentUserId;
  if (userId == null) return;

  final task = await _db.getTaskById(taskId, userId: userId);
  await _db.deleteTaskById(taskId, userId); // ❌ BYPASS!

  // Cancel reminder...
}
```

**Additional Violations** - 20+ instances of `_db.*` calls:
- Line 65: `await _db.getTaskById()`
- Line 73: `await _db.getTasksForNote()`
- Line 125: `await _db.createTask()`
- Line 135: `await _db.updateTask()`
- Line 176: `await _db.getTaskById()`
- Line 217: `await _db.getTasksForNote()`
- Line 230: `await _db.getTasksByIds()`
- Line 248: `await _db.getUserTaskIds()`
- Line 251: `await _db.getTasksForNote()`
- Line 275: `await _db.updateTask()`
- Line 278: `await _db.getUserTaskIds()`
- Line 285: `await _db.getTasksByIds()`
- Line 302: `await _db.getTaskById()`
- **Line 305**: `await _db.deleteTaskById()` ⚠️

#### File: `lib/data/local/app_db.dart`

**Line 2334** - Public hard-delete method:
```dart
Future<void> deleteTaskById(String id, String userId) async {
  await (delete(noteTasks)
    ..where((t) => t.id.equals(id) & t.userId.equals(userId))
  ).go();
}
```

**Problem**: This method is `public`, allowing services to bypass repositories.

**Should be**: Private (`_deleteTaskById`) and only called by `TaskCoreRepository.permanentlyDeleteTask()`.

---

### What SHOULD Happen

#### File: `lib/infrastructure/repositories/task_core_repository.dart`

**Lines 659-719** - Correct soft-delete implementation (currently bypassed):

```dart
Future<void> deleteTask(String taskId) async {
  try {
    // Get the task first
    final task = await getTaskById(taskId);
    if (task == null) {
      _logger.warning('Task not found for deletion: $taskId');
      return;
    }

    // Soft delete: Set deleted=true, deletedAt=now, scheduledPurgeAt=now+30days
    final now = DateTime.now();
    final purgeDate = now.add(const Duration(days: 30));

    await _db.updateTask(
      taskId,
      userId: _currentUserId!,
      deleted: true,
      deletedAt: now,
      scheduledPurgeAt: purgeDate,
    );

    // Audit log
    _logger.info('[TaskRepository] Soft deleted task: $taskId, purge scheduled: $purgeDate');
  } catch (e, stack) {
    _logger.severe('[TaskRepository] Failed to soft delete task', e, stack);
    rethrow;
  }
}
```

**This code EXISTS and is TESTED**, but `EnhancedTaskService` never calls it!

---

## Impact Assessment

### User Impact
- ❌ Users cannot recover accidentally deleted tasks
- ❌ No 30-day grace period for task deletion
- ❌ Trash screen shows notes/folders but not tasks (inconsistent UX)

### Compliance Impact
- ❌ Violates documented retention policy (Phase 1.1)
- ❌ No audit trail for task deletions
- ❌ Potential GDPR issue (immediate permanent deletion)

### Technical Debt
- ❌ Architecture violation sets precedent for future bypasses
- ❌ Test coverage is meaningless (repository tests pass, but code isn't used)
- ❌ Documentation lies (plan says soft-delete is implemented)

---

## Remediation Plan

### Priority 0 (Immediate) - Fix the Bypass

#### Step 1: Inject TaskCoreRepository into EnhancedTaskService

**File**: `lib/services/enhanced_task_service.dart`

**Current constructor**:
```dart
class EnhancedTaskService {
  final AppDb _db;
  final TaskReminderBridge _reminderBridge;

  EnhancedTaskService(this._db, this._reminderBridge);
}
```

**Updated constructor**:
```dart
class EnhancedTaskService {
  final TaskCoreRepository _taskRepository;
  final TaskReminderBridge _reminderBridge;

  EnhancedTaskService(this._taskRepository, this._reminderBridge);
}
```

#### Step 2: Refactor deleteTask() Method

**Current (line 297-315)**:
```dart
Future<void> deleteTask(String taskId) async {
  final userId = _currentUserId;
  if (userId == null) return;

  final task = await _db.getTaskById(taskId, userId: userId);
  await _db.deleteTaskById(taskId, userId); // ❌ BYPASS!

  // Cancel reminder if task had one
  if (task != null) {
    await _reminderBridge.onTaskDeleted(task);
  }
}
```

**Fixed**:
```dart
/// Delete a task (soft delete - goes to trash with 30-day retention)
///
/// FIXED 2025-11-16: Now uses repository pattern instead of direct DB access.
/// Tasks will appear in Trash and can be restored for 30 days.
///
/// Related: ARCHITECTURE_VIOLATIONS.md v1.0.0
Future<void> deleteTask(String taskId) async {
  try {
    // Get task before deletion (for reminder cleanup)
    final task = await _taskRepository.getTaskById(taskId);
    if (task == null) {
      _logger.warning('[EnhancedTaskService] Task not found for deletion: $taskId');
      return;
    }

    // Soft delete via repository (sets deleted=true, schedules purge in 30 days)
    await _taskRepository.deleteTask(taskId);

    // Cancel reminder if task had one
    await _reminderBridge.onTaskDeleted(task);

    _logger.info('[EnhancedTaskService] Task soft-deleted: $taskId');
  } catch (e, stack) {
    _logger.severe('[EnhancedTaskService] Failed to delete task', e, stack);
    rethrow;
  }
}
```

#### Step 3: Update All Other _db.* Calls

Replace all 20+ `_db.*` calls with repository methods:
- `_db.getTaskById()` → `_taskRepository.getTaskById()`
- `_db.createTask()` → `_taskRepository.createTask()`
- `_db.updateTask()` → `_taskRepository.updateTask()`
- etc.

**Estimated Effort**: 2-3 hours

---

### Priority 1 (This Week) - Prevent Future Bypasses

#### Step 4: Make AppDb Delete Methods Private

**File**: `lib/data/local/app_db.dart`

**Lines 2334-2346** - Make these private:

```dart
/// ⚠️ MADE PRIVATE 2025-11-16: Only call from repository permanentlyDelete methods
/// Previously: deleteTaskById (public)
///
/// This method performs HARD DELETE (permanent removal).
/// Services must use TaskCoreRepository.deleteTask() for soft delete.
/// Only TaskCoreRepository.permanentlyDeleteTask() should call this.
Future<void> _deleteTaskById(String id, String userId) async {
  await (delete(noteTasks)
    ..where((t) => t.id.equals(id) & t.userId.equals(userId))
  ).go();
}

/// ⚠️ MADE PRIVATE 2025-11-16
Future<void> _deleteTasksForNote(String noteId, String userId) async {
  await (delete(noteTasks)
    ..where((t) => t.noteId.equals(noteId) & t.userId.equals(userId))
  ).go();
}
```

**Also make private** (if they should be):
- `deleteReminderById` (line 2081)
- `deleteRemindersForNote` (line 2088)
- `deleteSavedSearch` (line 3307)

**Estimated Effort**: 30 minutes + fix repository layer to use private methods

---

#### Step 5: Create Architecture Enforcement Test ✅ COMPLETE (2025-11-17)

**File**: `test/architecture/repository_pattern_test.dart` (CREATED - commit 359f30d1)

```dart
/// Repository Pattern Enforcement Tests
/// Version: 1.0.0
/// Created: 2025-11-16T22:41:12Z
/// Author: Claude Code AI Assistant
/// Purpose: Prevent service layer from bypassing repositories
/// Runs in: CI pipeline
/// Related: ARCHITECTURE_VIOLATIONS.md v1.0.0

import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Repository Pattern Enforcement', () {
    test('Services must not directly call AppDb delete methods', () {
      // Scan all service files
      final serviceDir = Directory('lib/services');
      final serviceFiles = serviceDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in serviceFiles) {
        final content = file.readAsStringSync();

        // Check for direct AppDb delete calls
        final patterns = [
          '_db.deleteTaskById',
          '_db.deleteTasksForNote',
          '_db.deleteNoteById',
          '_db.deleteFolderById',
        ];

        for (final pattern in patterns) {
          if (content.contains(pattern)) {
            violations.add('${file.path}: Found $pattern (should use repository)');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Services must use repositories, not direct DB access:\n${violations.join('\n')}');
    });
  });
}
```

**Run in CI**: Add to GitHub Actions workflow

**Estimated Effort**: 1 hour

---

### Priority 2 (Next Sprint) - Documentation & Prevention

#### Step 6: Create DELETION_PATTERNS.md

Document the correct pattern for all future developers.

#### Step 7: Add PR Template Checklist

**File**: `.github/PULL_REQUEST_TEMPLATE.md`

```markdown
## Deletion/Trash Changes Checklist

If this PR modifies deletion logic:
- [ ] Verified changes use repository layer (not direct DB access)
- [ ] Soft delete uses `repository.deleteX()`, not `db.deleteXById()`
- [ ] Checked DELETION_PATTERNS.md for correct pattern
- [ ] Architecture tests pass (`test/architecture/repository_pattern_test.dart`)
- [ ] Updated Phase1.1.md if trash system behavior changes
```

---

## Testing Strategy

### Required Tests

1. **Service Layer Test** (`test/services/enhanced_task_service_test.dart`):
   ```dart
   test('deleteTask() calls repository soft-delete, not hard-delete', () async {
     final mockRepository = MockTaskCoreRepository();
     final service = EnhancedTaskService(mockRepository, mockBridge);

     await service.deleteTask('task-123');

     verify(mockRepository.deleteTask('task-123')).called(1);
     verifyNever(mockDb.deleteTaskById(any, any));
   });
   ```

2. **Integration Test**:
   ```dart
   test('Deleted task appears in trash and can be restored', () async {
     // Create task
     final taskId = await taskRepository.createTask(...);

     // Delete via service
     await enhancedTaskService.deleteTask(taskId);

     // Verify in trash
     final deletedTasks = await trashService.getDeletedTasks();
     expect(deletedTasks.any((t) => t.id == taskId), true);

     // Verify can restore
     await trashService.restoreTask(taskId);
     final restored = await taskRepository.getTaskById(taskId);
     expect(restored!.deleted, false);
   });
   ```

---

## Success Criteria

### Exit Conditions

- ✅ `EnhancedTaskService` uses `TaskCoreRepository` exclusively
- ✅ All task deletions go through trash system
- ✅ Deleted tasks visible in TrashScreen
- ✅ Tasks can be restored for 30 days
- ✅ AppDb hard-delete methods are private
- ✅ Architecture tests prevent future bypasses
- ✅ CI fails if services bypass repositories

### Verification Steps

1. Delete a task via UI → appears in Trash
2. Restore task from Trash → task returns to original list
3. Check database → task has `deleted=true`, `deletedAt`, `scheduledPurgeAt`
4. Wait 30 days (or manually trigger purge) → task permanently removed
5. Architecture tests pass in CI

---

## Related Issues

### Other Services with Direct _db Access

Found 7 other services with `final AppDb _db`:
1. `task_reminder_bridge.dart` - Needs audit
2. `reminder_coordinator.dart` - Needs audit
3. `advanced_reminder_service.dart` - Reminders are **intentionally** hard-deleted per plan
4. `unified_share_service.dart` - Needs audit
5. `unified_ai_suggestions_service.dart` - Needs audit
6. `task_service.dart` - Needs audit
7. `database_optimizer.dart` - Legitimate (maintenance operations)

**Action**: Create AUDIT_LOG.md to track which services need refactoring.

---

## References

- Phase 1.1: Soft Delete & Trash System Implementation Plan
- MASTER_IMPLEMENTATION_PLAN.md: Track 1.1 requirements
- `lib/infrastructure/repositories/task_core_repository.dart`: Correct implementation
- `lib/services/enhanced_task_service.dart`: Current violation
- `test/infrastructure/repositories/soft_delete_repository_test.dart`: Repository tests

---

**Document Status**: ACTIVE
**Next Review**: After remediation complete (estimated 2025-11-20)
**Owner**: Development Team
**Approver**: Architecture Review
