---
**Document**: Deletion Patterns & Architecture Guidelines
**Version**: 1.0.0
**Created**: 2025-11-16T22:41:12Z
**Author**: Claude Code AI Assistant
**Git Commit**: de1dcfe0 (will be updated on commit)
**Purpose**: Establish canonical deletion patterns to prevent architectural violations
**Related Documents**:
  - ARCHITECTURE_VIOLATIONS.md v1.0.0
  - MASTER_IMPLEMENTATION_PLAN.md v2.1.0
  - Phase1.1.md v1.2.0

**CHANGELOG**:
- 1.0.0 (2025-11-16): Initial documentation of correct deletion patterns

---

# Deletion Patterns & Architecture Guidelines

## Executive Summary

This document establishes the **canonical patterns** for implementing deletion operations in Duru Notes. Following these patterns ensures:

1. ✅ Consistent user experience (30-day trash retention)
2. ✅ Data recovery capabilities
3. ✅ GDPR compliance
4. ✅ Clean architecture adherence
5. ✅ Testable, maintainable code

**Golden Rule**: **Services MUST use repository methods. NEVER bypass to database layer.**

---

## Table of Contents

1. [Layer Responsibilities](#layer-responsibilities)
2. [Soft Delete Pattern](#soft-delete-pattern)
3. [Hard Delete Pattern](#hard-delete-pattern)
4. [Service Layer Guidelines](#service-layer-guidelines)
5. [Testing Requirements](#testing-requirements)
6. [Common Mistakes](#common-mistakes)
7. [Code Examples](#code-examples)

---

## Layer Responsibilities

### 1. UI Layer (`lib/ui/`, `lib/presentation/`)

**Responsibilities**:
- Display user-facing delete actions (trash icon, swipe-to-delete)
- Show confirmation dialogs for destructive actions
- Call service layer methods

**MUST NOT**:
- ❌ Call repository methods directly
- ❌ Call database methods directly
- ❌ Implement deletion logic

**Example**:
```dart
// ✅ CORRECT
await ref.read(taskServiceProvider).deleteTask(taskId);

// ❌ WRONG - Bypasses service layer
await ref.read(taskRepositoryProvider).deleteTask(taskId);

// ❌ VERY WRONG - Bypasses all layers
await db.deleteTaskById(taskId, userId);
```

---

### 2. Service Layer (`lib/services/`)

**Responsibilities**:
- Orchestrate business logic (e.g., cancel reminders before deleting task)
- Call repository methods for data operations
- Handle cross-cutting concerns (logging, analytics)

**MUST NOT**:
- ❌ Call `AppDb` methods directly
- ❌ Implement SQL/Drift queries
- ❌ Bypass repository pattern

**Pattern**:
```dart
class TaskService {
  final TaskCoreRepository _taskRepository;  // ✅ Inject repository
  final ReminderBridge _reminderBridge;

  TaskService(this._taskRepository, this._reminderBridge);

  Future<void> deleteTask(String taskId) async {
    // 1. Get task (for reminder cleanup)
    final task = await _taskRepository.getTaskById(taskId);
    if (task == null) return;

    // 2. Soft delete via repository
    await _taskRepository.deleteTask(taskId);  // ✅ Uses repository

    // 3. Handle side effects
    await _reminderBridge.onTaskDeleted(task);
  }
}
```

---

### 3. Repository Layer (`lib/infrastructure/repositories/`)

**Responsibilities**:
- Implement soft delete logic (set timestamps)
- Implement hard delete logic (permanent removal)
- Coordinate local + remote database operations
- Enqueue sync operations

**MUST NOT**:
- ❌ Expose `AppDb` methods as public API
- ❌ Allow services to bypass repository

**Pattern**:
```dart
class TaskCoreRepository {
  final AppDb _db;
  final String? _currentUserId;

  // ✅ Soft delete (default for user actions)
  Future<void> deleteTask(String taskId) async {
    final now = DateTime.now();
    final purgeDate = now.add(const Duration(days: 30));

    await _db.updateTask(
      taskId,
      userId: _currentUserId!,
      deleted: true,
      deletedAt: now,
      scheduledPurgeAt: purgeDate,
    );
  }

  // ✅ Hard delete (ONLY for purge automation)
  Future<void> permanentlyDeleteTask(String taskId) async {
    // Call PRIVATE AppDb method
    await _db._deleteTaskById(taskId, _currentUserId!);
  }
}
```

---

### 4. Database Layer (`lib/data/local/app_db.dart`)

**Responsibilities**:
- Provide low-level database operations
- Execute SQL/Drift queries
- Maintain data integrity

**MUST**:
- ✅ Keep hard-delete methods **PRIVATE** (`_deleteTaskById`)
- ✅ Only expose soft-delete-safe operations publicly

**Pattern**:
```dart
@DriftDatabase(/* ... */)
class AppDb extends _$AppDb {
  // ✅ PUBLIC - Soft delete safe
  Future<void> updateTask(String id, {
    required String userId,
    bool? deleted,
    DateTime? deletedAt,
    DateTime? scheduledPurgeAt,
    // ... other fields
  }) async {
    await (update(noteTasks)
      ..where((t) => t.id.equals(id) & t.userId.equals(userId))
    ).write(/* ... */);
  }

  // ⚠️ PRIVATE - Only for repository's permanentlyDelete methods
  Future<void> _deleteTaskById(String id, String userId) async {
    await (delete(noteTasks)
      ..where((t) => t.id.equals(id) & t.userId.equals(userId))
    ).go();
  }
}
```

---

## Soft Delete Pattern

### When to Use
- ✅ User-initiated deletions (delete button, swipe-to-delete)
- ✅ Folder deletions (cascade to children)
- ✅ Bulk delete operations
- ✅ Any deletion that should be recoverable

### Implementation Steps

1. **Set deletion timestamps**:
   ```dart
   deleted = true
   deleted_at = DateTime.now()
   scheduled_purge_at = DateTime.now() + 30 days
   ```

2. **Update queries to filter deleted items**:
   ```dart
   // ✅ Exclude deleted items from normal queries
   .where((t) => t.deletedAt.isNull())
   ```

3. **Enqueue sync operation**:
   ```dart
   // Let sync engine propagate to Supabase
   await _enqueuePendingOp('upsert_task', taskId);
   ```

### Exit Criteria
- ✅ Item appears in TrashScreen
- ✅ Item can be restored for 30 days
- ✅ Purge automation removes after 30 days
- ✅ Changes sync to other devices

---

## Hard Delete Pattern

### When to Use
- ⚠️ **ONLY** in purge automation (`purge_scheduler_service.dart`)
- ⚠️ **ONLY** for items past `scheduled_purge_at` date
- ❌ **NEVER** for user-initiated actions

### Implementation

**File**: `lib/services/purge_scheduler_service.dart`

```dart
Future<void> _purgeExpiredItems() async {
  final now = DateTime.now();

  // 1. Find items past purge date
  final expiredTasks = await _taskRepository.getTasksPastPurgeDate(now);

  // 2. Permanently delete via repository
  for (final task in expiredTasks) {
    await _taskRepository.permanentlyDeleteTask(task.id);  // ✅ Repository method
  }
}
```

**Repository Method**:
```dart
Future<void> permanentlyDeleteTask(String taskId) async {
  // Verify task is deleted and past purge date
  final task = await getTaskById(taskId);
  if (task == null || !task.deleted) {
    throw StateError('Cannot permanently delete non-deleted task');
  }

  if (task.scheduledPurgeAt == null ||
      task.scheduledPurgeAt!.isAfter(DateTime.now())) {
    throw StateError('Cannot purge task before scheduled date');
  }

  // Call PRIVATE database method
  await _db._deleteTaskById(taskId, _currentUserId!);
}
```

---

## Service Layer Guidelines

### Dependency Injection

**✅ CORRECT Pattern**:
```dart
class EnhancedTaskService {
  final TaskCoreRepository _taskRepository;  // Inject repository
  final TaskReminderBridge _reminderBridge;

  EnhancedTaskService(
    this._taskRepository,
    this._reminderBridge,
  );
}
```

**❌ WRONG Pattern**:
```dart
class EnhancedTaskService {
  final AppDb _db;  // ❌ Direct database access

  EnhancedTaskService(this._db);
}
```

### Method Implementation

**✅ CORRECT**:
```dart
Future<void> deleteTask(String taskId) async {
  // 1. Retrieve via repository
  final task = await _taskRepository.getTaskById(taskId);
  if (task == null) return;

  // 2. Soft delete via repository
  await _taskRepository.deleteTask(taskId);

  // 3. Handle side effects
  await _reminderBridge.onTaskDeleted(task);
}
```

**❌ WRONG**:
```dart
Future<void> deleteTask(String taskId) async {
  final task = await _db.getTaskById(taskId, userId: _currentUserId!);
  await _db.deleteTaskById(taskId, _currentUserId!);  // ❌ Bypasses repository
  await _reminderBridge.onTaskDeleted(task);
}
```

---

## Testing Requirements

### Service Layer Tests

```dart
test('deleteTask() calls repository soft-delete', () async {
  final mockRepository = MockTaskCoreRepository();
  final service = EnhancedTaskService(mockRepository, mockBridge);

  await service.deleteTask('task-123');

  // ✅ Verify repository method was called
  verify(mockRepository.deleteTask('task-123')).called(1);

  // ✅ Verify database was NOT called directly
  verifyNever(mockDb.deleteTaskById(any, any));
});
```

### Integration Tests

```dart
test('Deleted task appears in trash and can be restored', () async {
  // Create task
  final taskId = await taskRepository.createTask(...);

  // Delete via service
  await taskService.deleteTask(taskId);

  // Verify in trash
  final trashItems = await trashService.getDeletedTasks();
  expect(trashItems.any((t) => t.id == taskId), true);

  // Verify can restore
  await trashService.restoreTask(taskId);
  final restored = await taskRepository.getTaskById(taskId);
  expect(restored!.deleted, false);
});
```

---

## Common Mistakes

### ❌ Mistake #1: Service Bypasses Repository

**Wrong**:
```dart
class TaskService {
  final AppDb _db;

  Future<void> deleteTask(String taskId) async {
    await _db.deleteTaskById(taskId, userId);  // ❌
  }
}
```

**Fix**:
```dart
class TaskService {
  final TaskCoreRepository _taskRepository;

  Future<void> deleteTask(String taskId) async {
    await _taskRepository.deleteTask(taskId);  // ✅
  }
}
```

**Why it's wrong**: Bypasses soft-delete logic, breaks trash system, violates architecture.

---

### ❌ Mistake #2: Public Hard-Delete Methods

**Wrong**:
```dart
class AppDb {
  // ❌ Public - Services can bypass repository
  Future<void> deleteTaskById(String id, String userId) async {
    await (delete(noteTasks)...).go();
  }
}
```

**Fix**:
```dart
class AppDb {
  // ✅ Private - Only repository can call
  Future<void> _deleteTaskById(String id, String userId) async {
    await (delete(noteTasks)...).go();
  }
}
```

**Why it's wrong**: Allows architectural violations, enables accidental data loss.

---

### ❌ Mistake #3: Missing Repository Injection

**Wrong**:
```dart
class TaskService {
  Future<void> deleteTask(String taskId) async {
    // ❌ Creating repository inline
    final repo = TaskCoreRepository(db, userId);
    await repo.deleteTask(taskId);
  }
}
```

**Fix**:
```dart
class TaskService {
  final TaskCoreRepository _taskRepository;

  TaskService(this._taskRepository);  // ✅ Inject via constructor

  Future<void> deleteTask(String taskId) async {
    await _taskRepository.deleteTask(taskId);
  }
}
```

**Why it's wrong**: Hard to test, violates dependency injection, creates coupling.

---

## Code Examples

### Complete Service Example

```dart
/// Enhanced Task Service
///
/// ARCHITECTURE: This service uses repository pattern exclusively.
/// All database operations go through TaskCoreRepository.
///
/// Related: DELETION_PATTERNS.md v1.0.0
class EnhancedTaskService {
  final TaskCoreRepository _taskRepository;
  final TaskReminderBridge _reminderBridge;
  final Logger _logger;

  EnhancedTaskService(
    this._taskRepository,
    this._reminderBridge, {
    Logger? logger,
  }) : _logger = logger ?? Logger('EnhancedTaskService');

  /// Delete a task (soft delete - goes to trash with 30-day retention)
  ///
  /// This method:
  /// 1. Retrieves task via repository
  /// 2. Soft-deletes via repository (sets deleted=true, timestamps)
  /// 3. Cancels associated reminder if present
  ///
  /// The task will:
  /// - Appear in TrashScreen
  /// - Be restorable for 30 days
  /// - Be permanently deleted after scheduled_purge_at date
  ///
  /// Related: ARCHITECTURE_VIOLATIONS.md v1.0.0
  Future<void> deleteTask(String taskId) async {
    try {
      // 1. Get task before deletion (for reminder cleanup)
      final task = await _taskRepository.getTaskById(taskId);
      if (task == null) {
        _logger.warning('Task not found for deletion: $taskId');
        return;
      }

      // 2. Soft delete via repository (sets timestamps, enqueues sync)
      await _taskRepository.deleteTask(taskId);

      // 3. Cancel reminder if task had one
      await _reminderBridge.onTaskDeleted(task);

      _logger.info('Task soft-deleted: $taskId');
    } catch (e, stack) {
      _logger.severe('Failed to delete task', e, stack);
      rethrow;
    }
  }

  /// Restore a task from trash
  Future<void> restoreTask(String taskId) async {
    try {
      await _taskRepository.restoreTask(taskId);
      _logger.info('Task restored from trash: $taskId');
    } catch (e, stack) {
      _logger.severe('Failed to restore task', e, stack);
      rethrow;
    }
  }
}
```

### Complete Repository Example

```dart
class TaskCoreRepository {
  final AppDb _db;
  final String? _currentUserId;
  final Logger _logger;

  TaskCoreRepository(this._db, this._currentUserId)
      : _logger = Logger('TaskCoreRepository');

  /// Soft delete a task (sets deleted=true, timestamps)
  ///
  /// This is the canonical method for user-initiated task deletion.
  /// Tasks are marked as deleted and scheduled for purge in 30 days.
  ///
  /// Related: DELETION_PATTERNS.md v1.0.0
  Future<void> deleteTask(String taskId) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) {
        _logger.warning('Task not found for deletion: $taskId');
        return;
      }

      final now = DateTime.now();
      final purgeDate = now.add(const Duration(days: 30));

      await _db.updateTask(
        taskId,
        userId: _currentUserId!,
        deleted: true,
        deletedAt: now,
        scheduledPurgeAt: purgeDate,
      );

      _logger.info('Soft deleted task: $taskId, purge: $purgeDate');
    } catch (e, stack) {
      _logger.severe('Failed to soft delete task', e, stack);
      rethrow;
    }
  }

  /// Restore a task from trash
  Future<void> restoreTask(String taskId) async {
    try {
      await _db.updateTask(
        taskId,
        userId: _currentUserId!,
        deleted: false,
        deletedAt: null,
        scheduledPurgeAt: null,
      );

      _logger.info('Restored task from trash: $taskId');
    } catch (e, stack) {
      _logger.severe('Failed to restore task', e, stack);
      rethrow;
    }
  }

  /// Permanently delete a task (ONLY for purge automation)
  ///
  /// ⚠️ WARNING: This performs HARD DELETE (permanent removal).
  /// Only call from purge_scheduler_service.dart after verifying:
  /// 1. Task is marked deleted=true
  /// 2. Current time > scheduled_purge_at
  ///
  /// Related: DELETION_PATTERNS.md v1.0.0
  Future<void> permanentlyDeleteTask(String taskId) async {
    try {
      final task = await getTaskById(taskId);

      if (task == null) {
        _logger.warning('Task not found for permanent deletion: $taskId');
        return;
      }

      if (!task.deleted) {
        throw StateError(
          'Cannot permanently delete non-deleted task: $taskId'
        );
      }

      if (task.scheduledPurgeAt == null ||
          task.scheduledPurgeAt!.isAfter(DateTime.now())) {
        throw StateError(
          'Cannot purge task before scheduled date: $taskId'
        );
      }

      // Call PRIVATE AppDb method
      await _db._deleteTaskById(taskId, _currentUserId!);

      _logger.info('Permanently deleted task: $taskId');
    } catch (e, stack) {
      _logger.severe('Failed to permanently delete task', e, stack);
      rethrow;
    }
  }

  /// Get tasks past their scheduled purge date
  Future<List<Task>> getTasksPastPurgeDate(DateTime now) async {
    return await _db.getTasksWhere(
      userId: _currentUserId!,
      deleted: true,
      purgeBeforeDate: now,
    );
  }
}
```

---

## Enforcement

### Manual Review Checklist

Before merging any PR that touches deletion logic:

- [ ] Service layer uses repository methods (not `AppDb`)
- [ ] Repository implements soft delete (sets timestamps)
- [ ] AppDb hard-delete methods are private
- [ ] Tests verify repository method calls
- [ ] Integration tests verify trash functionality
- [ ] Architecture tests pass (`repository_pattern_test.dart`)

### Automated Checks

**File**: `test/architecture/repository_pattern_test.dart`

See `ARCHITECTURE_VIOLATIONS.md` Step 5 for implementation.

---

## Summary

### ✅ DO

- Use repository methods from services
- Implement soft delete for user actions
- Keep hard-delete methods private
- Test via mocks and integration tests
- Add timestamps for all deletions
- Follow the layer hierarchy: UI → Service → Repository → Database

### ❌ DON'T

- Bypass repository pattern
- Call `AppDb` methods from services
- Use hard delete for user actions
- Make database delete methods public
- Skip testing trash functionality

---

**Document Status**: ACTIVE
**Next Review**: After service layer bypass fix (estimated 2025-11-17)
**Owner**: Development Team
**Enforcement**: CI architecture tests + PR review checklist
