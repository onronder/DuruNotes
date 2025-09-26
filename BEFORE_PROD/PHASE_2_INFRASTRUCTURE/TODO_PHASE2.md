# 🏗️ TODO Phase 2: Core Infrastructure

> **Claimed Status**: ✅ COMPLETE (Days 8-12)
> **Actual Status**: 15% functional
> **Critical Issue**: Built but DISABLED with `useRefactoredArchitecture = false`
> **Time to Fix**: 3-4 days

---

## 🔴 The Reality

### What Was Built
- ✅ Domain entities created
- ✅ Repository interfaces defined
- ✅ Mappers implemented
- ✅ Infrastructure layer structured

### What Actually Works
- ❌ Entities not used (disabled)
- ❌ Mappers have property mismatches
- ❌ Repositories not connected to UI
- ❌ 1199 build errors when enabled

---

## 📝 Day 8: Domain Layer [NEEDS FIXES]

### Completed ✅
- [x] Created domain entities:
  - Note, Task, Folder, Template, Tag
  - SavedSearch, Attachment, Conflict
  - Value objects (NoteId, FolderId, etc.)

### Needs Fixing ❌
- [ ] **Property name standardization**
  ```dart
  // Current BROKEN state:
  class Note {
    final String body;        // ❌ Wrong name
    final DateTime createdAt; // ❌ Wrong name
  }
  
  // Should be:
  class Note {
    final String content;        // ✓ Match database
    final DateTime createdDate; // ✓ Match database
  }
  ```

- [ ] **Value object validation**
  ```dart
  // Add validation to value objects
  class NoteId {
    final String value;
    
    NoteId(this.value) {
      if (value.isEmpty) throw ArgumentError('NoteId cannot be empty');
      if (value.length != 36) throw ArgumentError('Invalid UUID format');
    }
  }
  ```

---

## 📝 Day 9: Mapper Layer [BROKEN]

### Current Issues
- ❌ Property mismatches (content vs body)
- ❌ Date field mismatches
- ❌ Relationship mapping broken
- ❌ No bidirectional conversion tests

### Fix Tasks
- [ ] **Fix NoteMapper**
  - [ ] Align property names
  - [ ] Fix date conversions
  - [ ] Handle nullable fields
  - [ ] Add conversion tests

- [ ] **Fix TaskMapper**
  - [ ] Map task-note relationships
  - [ ] Handle reminder data
  - [ ] Test conversions

- [ ] **Fix FolderMapper**
  - [ ] Handle nested folders
  - [ ] Map folder-note relationships
  - [ ] Test hierarchy

- [ ] **Add mapper tests**
  ```dart
  test('converts LocalNote to Note and back', () {
    final local = LocalNote(...);
    final domain = NoteMapper.fromLocal(local);
    final backToLocal = NoteMapper.toLocal(domain);
    expect(backToLocal, equals(local));
  });
  ```

---

## 📝 Day 10: Repository Pattern [DISCONNECTED]

### Created but Unused
- [x] INoteRepository interface
- [x] NotesCoreRepository implementation
- [x] Other repository interfaces

### Connection Tasks
- [ ] **Wire repositories to providers**
  ```dart
  // Currently DISABLED:
  final noteRepositoryProvider = Provider((ref) {
    if (useRefactoredArchitecture) {  // FALSE!
      return NotesCoreRepository(...);
    }
    return LocalNoteService();  // Still using this!
  });
  ```

- [ ] **Remove conditional logic**
- [ ] **Update UI to use repositories**
- [ ] **Add repository tests**

---

## 📝 Day 11-12: Provider Architecture [BROKEN]

### The 1,669 Line Disaster
```dart
// lib/providers.dart
// 107 conditional providers!
// 40% performance overhead!
// Type safety destroyed!
```

### Required Fixes
- [ ] **Split providers.dart**
  ```
  lib/
    features/
      notes/
        providers/
          note_repository_provider.dart
          note_list_provider.dart
      folders/
        providers/
          folder_repository_provider.dart
      tasks/
        providers/
          task_repository_provider.dart
  ```

- [ ] **Remove ALL conditionals**
  ```dart
  // WRONG (current):
  if (useRefactoredArchitecture) {
    return DomainVersion();
  } else {
    return LegacyVersion();
  }
  
  // RIGHT (target):
  return DomainVersion();  // One version only!
  ```

- [ ] **Fix type safety**
  ```dart
  // WRONG:
  Provider<dynamic>  // ❌
  
  // RIGHT:
  Provider<INoteRepository>  // ✓
  ```

---

## 🎯 Phase 2 Completion Criteria

### Must ALL be true:
- [ ] Domain entities use correct property names
- [ ] All mappers work bidirectionally
- [ ] Repositories connected (not conditional)
- [ ] Providers split into modules
- [ ] Zero conditional architecture
- [ ] Type safety restored
- [ ] 0 build errors when enabled
- [ ] Basic CRUD operations work

---

## 📈 Actual Progress

```
Domain Entities:     [████████░░] 80%  (created but wrong properties)
Mappers:            [██░░░░░░░░] 20%  (broken conversions)
Repositories:       [█████░░░░░] 50%  (created but not connected)
Providers:          [░░░░░░░░░░] 0%   (need complete refactor)

OVERALL:           [██░░░░░░░░] 15%  functional
```

---

## ⚠️ Critical Dependencies

Phase 2 BLOCKS everything because:
1. UI can't use domain until mappers work
2. Services need repositories to be connected
3. Providers control entire data flow
4. Build errors prevent any progress

**Fix Phase 2 properly or nothing else works!**