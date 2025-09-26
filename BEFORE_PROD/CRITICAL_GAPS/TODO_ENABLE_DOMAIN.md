# 🎯 TODO: Enable Domain Architecture

> **Impact**: Makes or breaks the entire migration
> **Time Required**: 5 minutes (after prerequisites)
> **Difficulty**: Easy (if done right) / CATASTROPHIC (if done wrong)
> **Prerequisites**: Property mappings AND build errors fixed
> **Risk**: EXTREME if UI not migrated first

---

## ⚠️ CRITICAL WARNING

**DO NOT ENABLE UNTIL:**
1. ✅ Property mappings complete (TODO_PROPERTY_MAPPINGS.md)
2. ✅ Build errors fixed (TODO_FIX_BUILD_ERRORS.md)
3. ✅ At least 4 critical screens migrated (TODO_UI_MIGRATION_ACTUAL.md)

Enabling too early = **TOTAL APP FAILURE**

---

## 🔍 Current State

### The Killer Switch
```dart
// lib/providers.dart:114
const bool useRefactoredArchitecture = false;  // 🚨 EVERYTHING IS OFF
```

This ONE line controls:
- Which entities are used (domain vs database)
- Which repositories are active
- Which services are called
- How data flows through the app

### What This Flag Does
```dart
// Throughout providers.dart (107 conditionals!):
final noteRepositoryProvider = Provider<dynamic>((ref) {
  if (useRefactoredArchitecture) {
    return NotesCoreRepository(...);  // Domain version
  } else {
    return LocalNoteService(...);     // Legacy version
  }
});
```

---

## 📋 Pre-Enable Checklist

### 1. Verify Infrastructure (30 minutes)

- [ ] **Check domain entities compile**
  ```bash
  flutter analyze lib/domain/
  # Must show 0 errors
  ```

- [ ] **Check mappers work**
  ```bash
  flutter test test/mappers/
  # All tests must pass
  ```

- [ ] **Check repositories compile**
  ```bash
  flutter analyze lib/infrastructure/repositories/
  # Must show 0 errors
  ```

- [ ] **Verify no LocalNote in migrated UI**
  ```bash
  grep -r "LocalNote" lib/ui/notes_list_screen.dart
  grep -r "LocalNote" lib/ui/modern_edit_note_screen.dart
  # Should return nothing
  ```

### 2. Create Safety Backup (15 minutes)

- [ ] **Backup current working state**
  ```bash
  git add -A
  git commit -m "BACKUP: Before enabling domain architecture"
  git tag backup-before-domain
  ```

- [ ] **Document current functionality**
  - [ ] Notes can be created
  - [ ] Notes can be edited
  - [ ] Notes can be deleted
  - [ ] Search works
  - [ ] Sync works

### 3. Prepare Rollback Plan (10 minutes)

- [ ] **Create rollback script**
  ```bash
  echo '#!/bin/bash
  git reset --hard backup-before-domain
  flutter clean
  flutter pub get' > rollback.sh
  chmod +x rollback.sh
  ```

- [ ] **Test rollback works**
  ```bash
  ./rollback.sh
  flutter run
  # Verify app still works with old architecture
  ```

---

## 🚀 Enable Process (5 minutes)

### Step 1: Change the Flag

- [ ] **Edit providers.dart**
  ```dart
  // lib/providers.dart:114
  - const bool useRefactoredArchitecture = false;
  + const bool useRefactoredArchitecture = true;  // 🎆 DOMAIN ENABLED!
  ```

### Step 2: Clear and Rebuild

- [ ] **Clean build**
  ```bash
  flutter clean
  flutter pub get
  flutter analyze
  # Should show 0 errors if previous steps done right
  ```

### Step 3: Initial Test

- [ ] **Try to run**
  ```bash
  flutter run --verbose
  # Watch for crashes or errors
  ```

### Step 4: Quick Smoke Test

- [ ] **Test critical paths**
  - [ ] App launches
  - [ ] Can view notes list
  - [ ] Can create a note
  - [ ] Can edit a note
  - [ ] Can delete a note
  - [ ] Can search notes

---

## 🔥 If It Crashes (Recovery)

### Common Crash Scenarios

#### Scenario 1: Type Cast Exception
```
Exception: type 'LocalNote' is not a subtype of type 'Note'
```
**Fix**: UI component not migrated, still using LocalNote

#### Scenario 2: Null Pointer
```
Exception: Null check operator used on a null value
```
**Fix**: Mapper returning null, check property mappings

#### Scenario 3: Provider Not Found
```
Exception: Could not find Provider<NoteRepository>
```
**Fix**: Provider definition wrong, check providers.dart

#### Scenario 4: Database Error
```
Exception: column 'body' does not exist
```
**Fix**: Property mapping incomplete, database expects 'content'

### Emergency Rollback

- [ ] **If crashes persist**
  ```bash
  ./rollback.sh
  ```
  Then fix the issues and try again

---

## ✅ Post-Enable Validation

### Functional Tests (1 hour)

- [ ] **CRUD Operations**
  - [ ] Create 5 test notes
  - [ ] Edit all 5 notes
  - [ ] Delete 2 notes
  - [ ] Verify 3 remain

- [ ] **Search & Filter**
  - [ ] Search by title
  - [ ] Search by content
  - [ ] Filter by folder
  - [ ] Filter by tag

- [ ] **Tasks**
  - [ ] Create task from note
  - [ ] Complete task
  - [ ] Delete task

- [ ] **Sync**
  - [ ] Create note on device 1
  - [ ] Verify appears on device 2
  - [ ] Edit on device 2
  - [ ] Verify update on device 1

### Performance Tests (30 minutes)

- [ ] **Measure key metrics**
  ```bash
  flutter analyze --dartdoc
  flutter test --coverage
  ```

- [ ] **Compare with baseline**
  | Metric | Before | After | Target |
  |--------|--------|-------|--------|
  | App launch | 2.1s | ? | < 2.5s |
  | Note list load | 0.3s | ? | < 0.5s |
  | Note save | 0.1s | ? | < 0.2s |
  | Memory usage | 145MB | ? | < 200MB |

### Data Integrity (30 minutes)

- [ ] **Check database**
  ```sql
  SELECT COUNT(*) FROM notes;
  -- Should match UI count
  
  SELECT * FROM notes WHERE content IS NULL;
  -- Should return 0 rows
  ```

- [ ] **Verify mappings**
  - [ ] Export note to JSON
  - [ ] Check all fields present
  - [ ] Import back
  - [ ] Verify no data loss

---

## 📊 Success Metrics

**Domain is successfully enabled when:**

### Required (Must have ALL)
- [ ] App launches without crashes
- [ ] All CRUD operations work
- [ ] No data loss
- [ ] No type errors in logs
- [ ] Performance acceptable

### Expected Improvements
- [ ] Code is more maintainable
- [ ] Type safety improved
- [ ] Architecture is cleaner
- [ ] Testing is easier
- [ ] Future features easier to add

---

## 🚀 Next Steps

Once domain is enabled and stable:

1. **Complete UI Migration**
   - Migrate remaining 38 UI components
   - Remove ALL LocalNote references
   - See TODO_UI_MIGRATION_ACTUAL.md

2. **Remove Dual Architecture**
   - Delete conditional providers
   - Clean up providers.dart
   - See TODO_REMOVE_DUAL_ARCHITECTURE.md

3. **Begin Phase 4 Features**
   - Folders system
   - Import/Export
   - Templates
   - See TODO_PHASE4.md

---

## 📁 Files to Monitor

Watch these files for issues:
```
lib/providers.dart                    # The switch
lib/ui/notes_list_screen.dart        # Critical UI
lib/ui/modern_edit_note_screen.dart  # Critical UI
lib/infrastructure/mappers/*         # Data conversion
lib/infrastructure/repositories/*    # Data access
```

---

**Remember**: This is the moment of truth. Either the architecture works, or months of effort were wasted. NO PRESSURE! 😅