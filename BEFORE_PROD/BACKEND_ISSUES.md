# 🔧 BACKEND ARCHITECTURE ISSUES
*Separated from multi-agent audit findings*

## 🔴 CRITICAL BACKEND ISSUES (P0)

### 1. Data Mapper Corruption Bug
**Location**: `/lib/infrastructure/mappers/task_mapper.dart`
**Issue**: Task fields are incorrectly mapped causing data corruption
```dart
// CURRENT (WRONG):
static Task fromDatabase(Map<String, dynamic> data) {
  return Task(
    title: data['notes'] ?? '',    // ❌ WRONG: Using notes for title
    content: data['content'],      // ❌ WRONG: Using content for content
    // ...
  );
}

// CORRECT:
static Task fromDatabase(Map<String, dynamic> data) {
  return Task(
    title: data['content'],        // ✅ Task content is the title
    content: data['notes'] ?? '',  // ✅ Task notes is the description
    // ...
  );
}
```

### 2. Other Mapper Issues
**Files to check**:
- `/lib/infrastructure/mappers/note_mapper.dart`
- `/lib/infrastructure/mappers/folder_mapper.dart`
- `/lib/infrastructure/mappers/template_mapper.dart`

**Common issues found**:
```dart
// Property mapping errors:
note.content → should be note.body
note.pinned → should be note.isPinned
folder.parentId → should be folder.parent_id (Supabase)
```

---

## 🟡 SERVICE LAYER VIOLATIONS (P1)

### Direct Database Access (Repository Pattern Violations)
**10+ Services bypassing repositories:**

1. **UnifiedTaskService** (1,648 lines)
   - Direct AppDb() instantiation
   - Should use ITaskRepository
   ```dart
   // CURRENT (WRONG):
   final db = ref.read(appDbProvider);
   final tasks = await db.getTasksForNote(noteId);

   // SHOULD BE:
   final repository = ref.read(taskRepositoryProvider);
   final tasks = await repository.getTasksByNoteId(noteId);
   ```

2. **DualModeSyncService** (deprecated but still active)
   - Competing with UnifiedSyncService
   - Creates sync conflicts
   - Should be removed entirely

3. **Other violating services**:
   - `import_service.dart` - Direct DB for import operations
   - `export_service.dart` - Direct DB for export
   - `analytics_service.dart` - Direct DB for stats
   - `deep_link_service.dart` - Direct DB for navigation
   - `push_notification_service.dart` - Direct DB for tasks

### Sync Architecture Issues
**Multiple competing sync implementations:**
```
dual_mode_sync_service.dart (OLD - should be removed)
unified_sync_service.dart (NEW - should be primary)
sync_coordinator.dart (Orchestrator - unclear purpose)
```

**Problems**:
- Race conditions between services
- Duplicate sync operations
- Inconsistent conflict resolution
- No clear sync state machine

---

## 🟠 REPOSITORY LAYER ISSUES (P2)

### Well-Designed but Underutilized
**Good interfaces exist**:
- `i_notes_repository.dart` ✅
- `i_task_repository.dart` ✅
- `i_folder_repository.dart` ✅

**Implementation issues**:
1. **Inconsistent method naming**:
   ```dart
   // Different patterns used:
   getNoteById() vs fetchNote() vs loadNote()
   saveNote() vs updateNote() vs persistNote()
   ```

2. **Missing batch operations**:
   ```dart
   // Need to add:
   Future<List<Note>> saveNotes(List<Note> notes);
   Future<void> deleteNotes(List<String> ids);
   ```

3. **Transaction support missing**:
   ```dart
   // Need transactional operations:
   Future<T> runInTransaction<T>(Future<T> Function() action);
   ```

---

## 🔵 DATA LAYER ISSUES (P2)

### Database Schema Inconsistencies
1. **Drift (Local) vs Supabase (Remote) mismatches**:
   - Column naming: camelCase vs snake_case
   - Data types: DateTime vs timestamptz
   - Nullable fields inconsistent

2. **Migration state**:
   - 6 Supabase migrations ready but not deployed
   - Local Drift migrations out of sync
   - No migration version tracking

### Encryption Implementation
**File**: `/lib/core/security/database_encryption.dart`
```dart
// Current:
throw UnimplementedError('File encryption not implemented');

// Needs:
- AES-256 encryption for sensitive data
- Key derivation from user password
- Secure key storage in platform keychain
```

---

## 📊 BACKEND METRICS

### Current State
| Component | Coverage | Issues | Risk |
|-----------|----------|--------|------|
| Mappers | 60% correct | Field swaps | HIGH |
| Services | 30% use repos | Direct DB access | HIGH |
| Repositories | 100% defined | 40% utilized | MEDIUM |
| Sync | 2 competing | Race conditions | HIGH |
| Database | Schema mismatch | Migration pending | MEDIUM |
| Encryption | 0% implemented | Security gap | HIGH |

### Target State
| Component | Goal | Timeline |
|-----------|------|----------|
| Mappers | 100% correct mappings | Day 2 |
| Services | 100% repository usage | Week 1 |
| Repositories | 100% utilized | Week 1 |
| Sync | Single service | Week 2 |
| Database | Synced schemas | Week 2 |
| Encryption | Full implementation | Week 3 |

---

## 🚀 BACKEND FIX PRIORITY

### Day 2 (Immediate)
1. Fix TaskMapper field swap bug
2. Audit all other mappers for similar issues
3. Create mapper unit tests

### Week 1
1. Remove direct DB access from all services
2. Update services to use repositories
3. Remove DualModeSyncService
4. Standardize repository method names

### Week 2
1. Consolidate sync services
2. Implement transaction support
3. Sync database schemas
4. Deploy Supabase migrations

### Week 3
1. Implement encryption
2. Add batch operations
3. Performance optimization
4. Security audit

---

## 🔍 VALIDATION COMMANDS

```bash
# Check for direct DB access in services
grep -r "AppDb()" lib/services/ | wc -l  # Should be 0

# Check for repository usage
grep -r "repository" lib/services/ | wc -l  # Should be high

# Check for dual sync service references
grep -r "DualModeSyncService" lib/ | wc -l  # Should be 0

# Check mapper tests exist
ls test/mappers/*.dart 2>/dev/null | wc -l  # Should be > 0

# Verify Supabase migrations ready
ls supabase/migrations/*.sql | wc -l  # Should match expected
```

---

**Document Created**: September 26, 2025
**Severity**: CRITICAL (Data corruption risk)
**Next Action**: Fix TaskMapper bug immediately