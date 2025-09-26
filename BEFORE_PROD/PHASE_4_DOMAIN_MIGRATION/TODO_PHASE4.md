# 📋 TODO Phase 4: Complete Domain Migration

> **Current Status**: 30% Complete (15% Functional)
> **Timeline**: Week 3-4 (240 hours)
> **Prerequisites**: Phase 0 blockers fixed
> **Reality Check**: This is where we ACTUALLY are

---

## 🎯 Phase 4 Objectives

1. **Complete the migration** we claimed was done
2. **Use the domain entities** we created
3. **Remove the dual architecture** causing chaos
4. **Achieve 70% test coverage** minimum
5. **Make the architecture actually work**

---

## 📊 Overall Phase 4 Progress

```
UI Migration:       [█         ] 5%   (2/45 components)
Service Migration:  [██        ] 15%  (11/73 services)
Provider Refactor:  [          ] 0%   (BROKEN)
Test Coverage:      [██        ] 15%  (Need 70%)
```

---

## ✅ Critical Path Tasks

### 🔴 IMMEDIATE: Enable Domain Architecture (Day 1)

- [ ] **Verify infrastructure ready**
  - [ ] All domain entities compile
  - [ ] All mappers work correctly
  - [ ] Repositories connected to domain
  - [ ] Test basic CRUD operations

- [ ] **Fix the architecture flag**
  ```dart
  // lib/providers.dart:114
  - [ ] Change: const bool useRefactoredArchitecture = false;
  - [ ] To:     const bool useRefactoredArchitecture = true;
  ```

- [ ] **Test core flows**
  - [ ] Note creation with domain
  - [ ] Note listing with domain
  - [ ] Note editing with domain
  - [ ] Note deletion with domain

---

## 📦 4.1: UI Component Migration [5% → 100%]

### Critical Screens (Day 2-3)

- [ ] **modern_edit_note_screen.dart**
  - [ ] Replace LocalNote with domain.Note
  - [ ] Update all data operations
  - [ ] Fix type safety
  - [ ] Add proper error handling
  - [ ] Test all features

- [ ] **notes_list_screen.dart** (50% done)
  - [x] Basic domain support
  - [ ] Complete pagination with domain
  - [ ] Fix filtering with domain
  - [ ] Update sorting logic
  - [ ] Remove legacy code

- [ ] **task_list_screen.dart**
  - [ ] Replace NoteTask with domain.Task
  - [ ] Update task operations
  - [ ] Fix task-note relationships
  - [ ] Test task workflows

- [ ] **folder_management_screen.dart**
  - [ ] Replace LocalFolder with domain.Folder
  - [ ] Update folder tree logic
  - [ ] Fix folder-note relationships
  - [ ] Test folder operations

### Secondary Screens (Day 4-5)

- [ ] **template_gallery_screen.dart**
- [ ] **modern_search_screen.dart**
- [ ] **settings_screen.dart**
- [ ] **auth_screen.dart**
- [ ] **reminders_screen.dart**
- [ ] **tags_screen.dart**
- [ ] **saved_search_management_screen.dart**
- [ ] **change_password_screen.dart**

### Components (Day 6-7) - [Full list in TODO_PHASE4_1_UI.md]

- [ ] **Note Components** (12 total)
  - [x] DualTypeNoteCard
  - [ ] NoteEditor
  - [ ] NotePreview
  - [ ] ... 9 more

- [ ] **Task Components** (8 total)
  - [ ] TaskListItem
  - [ ] TaskEditor
  - [ ] ... 6 more

- [ ] **Folder Components** (6 total)
  - [ ] FolderTreeItem
  - [ ] FolderPicker
  - [ ] ... 4 more

---

## 🔧 4.2: Service Migration [15% → 100%]

### Completed Services ✅
1. UnifiedExportService
2. UnifiedImportService
3. UnifiedTaskService
4. UnifiedTemplateService
5. UnifiedSearchService
6. UnifiedAnalyticsService
7. UnifiedShareService
8. UnifiedReminderService
9. UnifiedSyncService
10. UnifiedAISuggestionsService
11. UnifiedTemplateVariableService

### Critical Services to Migrate (Day 8-9)

- [ ] **NotificationService** (impacts UX)
- [ ] **AuthService** (security critical)
- [ ] **CryptoService** (data protection)
- [ ] **BackupService** (data safety)
- [ ] **ConflictResolutionService** (sync critical)

### Data Services (Day 10)

- [ ] **CacheService**
- [ ] **IndexingService**
- [ ] **MigrationService**
- [ ] **ValidationService**
- [ ] **TransformationService**

### Remaining 47 Services (Day 11-12) - [Full list in TODO_PHASE4_2_SERVICES.md]

---

## 🏗️ 4.3: Provider Refactoring [0% → 100%]

### Remove Dual Architecture (Day 13-14)

- [ ] **Split providers.dart**
  - [ ] Create features/*/providers/ structure
  - [ ] Move auth providers
  - [ ] Move notes providers
  - [ ] Move folder providers
  - [ ] Move task providers
  - [ ] Move sync providers
  - [ ] Delete providers.dart

- [ ] **Remove 107 conditional providers**
  - [ ] List all conditionals
  - [ ] Create unified versions
  - [ ] Update UI references
  - [ ] Remove old providers
  - [ ] Test each change

- [ ] **Fix type safety**
  - [ ] Remove ALL dynamic types
  - [ ] Add proper typing
  - [ ] Fix generic types
  - [ ] Validate with analyzer

---

## 🧪 4.4: Test Coverage [15% → 70%]

### Domain Tests (Day 15)
- [ ] **Entity Tests** (0% → 100%)
  - [ ] Note entity tests
  - [ ] Task entity tests
  - [ ] Folder entity tests
  - [ ] Template entity tests
  - [ ] All value objects

### Repository Tests (Day 16)
- [ ] **Repository Tests** (0% → 90%)
  - [ ] NotesCoreRepository
  - [ ] TaskCoreRepository
  - [ ] FolderCoreRepository
  - [ ] TemplateCoreRepository

### Service Tests (Day 17)
- [ ] **Service Tests** (30% → 85%)
  - [ ] All 73 services
  - [ ] Mock dependencies
  - [ ] Error scenarios
  - [ ] Edge cases

### UI Tests (Day 18)
- [ ] **Widget Tests** (10% → 75%)
  - [ ] All 45 components
  - [ ] User interactions
  - [ ] State management
  - [ ] Navigation flows

### Integration Tests (Day 19-20)
- [ ] **E2E Tests** (5% → 60%)
  - [ ] Complete note workflow
  - [ ] Task management flow
  - [ ] Folder organization
  - [ ] Search and filter
  - [ ] Sync operations

---

## 🎯 Success Metrics

### Must ALL be TRUE to complete Phase 4:

#### Architecture
- [ ] useRefactoredArchitecture = true
- [ ] App runs on domain entities
- [ ] Zero database model imports in UI
- [ ] All services use unified pattern

#### Quality
- [ ] 70%+ test coverage
- [ ] Zero build warnings
- [ ] All tests passing
- [ ] Performance baseline met

#### Cleanup
- [ ] providers.dart deleted
- [ ] No conditional providers
- [ ] No dynamic types
- [ ] No feature flags

---

## 📅 Daily Checklist

### Every Day:
- [ ] Run all tests before starting
- [ ] Migrate at least 2 components/services
- [ ] Add tests for migrated code
- [ ] Update documentation
- [ ] Commit working code only
- [ ] Run tests before ending

### End of Week 3:
- [ ] UI migration complete
- [ ] Provider refactoring done
- [ ] 50% test coverage

### End of Week 4:
- [ ] Service migration complete
- [ ] 70% test coverage
- [ ] All tests passing
- [ ] Performance validated

---

## 🚫 Do NOT:

1. Claim completion without testing
2. Mix domain and database models
3. Use dynamic to avoid typing
4. Skip writing tests
5. Break existing functionality
6. Merge broken code
7. Ignore performance impacts

---

## ✅ Phase 4 Complete When:

- [ ] 100% UI components migrated
- [ ] 100% services migrated
- [ ] 0 conditional providers
- [ ] 70%+ test coverage
- [ ] App runs fully on domain layer
- [ ] Performance equal or better
- [ ] All tests passing
- [ ] Zero regressions

---

**Current Reality**: 15% functional migration | **Target**: 100% functional migration | **Time**: 2 weeks