# 🚨 EMERGENCY FIX TODO LIST
**Generated:** September 26, 2025
**Status:** CRITICAL - Build Failure
**Errors:** 670 compilation errors blocking production

---

## 🔴 DAY 1-2: TYPE SYSTEM FIXES (270 errors)

### `/lib/ui/notes_list_screen.dart` (44 errors)
- [ ] Line 854: Cast `note` to `domain.Note`
- [ ] Line 860: Fix dynamic to Note conversion
- [ ] Line 900: Add type check before _editNote
- [ ] Line 907: Cast to domain.Note in onTap
- [ ] Line 916: Fix _deleteNote parameter type
- [ ] Line 941: Add type safety to trailing widget
- [ ] Line 948: Fix onDismissed callback type
- [ ] Line 962: Cast note in confirmDismiss
- [ ] Line 1004: Fix _shareNote parameter
- [ ] Lines 1073-1074: Fix double cast issue
- [ ] Line 1674: Convert List<LocalNote> to List<Note>
- [ ] Line 1776: Fix search result type
- [ ] Line 1826: Cast filtered note type
- [ ] Line 2354: Fix list type conversion
- [ ] Line 2687-2709: Fix all _getNoteTitle/_getNoteId calls
- [ ] Line 2802: Convert Note to LocalNote for drop
- [ ] Line 2810: Fix drag data type
- [ ] Line 3352: Fix share dialog note type
- [ ] Line 3488-3492: Fix export note types

### `/lib/services/unified_template_service.dart` (8 errors)
- [ ] Line 226: Fix TemplateVariable iteration type
- [ ] Line 314: Add null check for existingTemplate
- [ ] Line 315-319: Fix property access with null safety

### `/lib/ui/modern_edit_note_screen.dart` (3 errors)
- [ ] Line 1659: Initialize sanitizedContent before use

### Type Converter Utility Creation
- [ ] Create `/lib/core/converters/note_converter.dart`
- [ ] Create `/lib/core/converters/folder_converter.dart`
- [ ] Add conversion methods for all entity types

---

## 🔴 DAY 3-4: MISSING METHODS (98 errors)

### Repository Interfaces
- [ ] Add `getAll()` to `INotesRepository`
- [ ] Add `setLinksForNote()` to `NotesCoreRepository`
- [ ] Add `fetchRecentNotes()` to `SupabaseNoteApi`
- [ ] Add `fetchAllFolders()` to `SupabaseNoteApi`
- [ ] Implement batch operations in all repositories

### Test Helpers Fix
- [ ] `/test/test_helpers.dart` Line 47: Add version parameter
- [ ] Line 55: Fix FolderHierarchyState constructor
- [ ] Line 99: Change noteType from int to NoteKind
- [ ] Line 106: Add missing required parameters
- [ ] Line 119: Fix mock return types

### Undefined Identifiers (74 errors)
- [ ] Define `ConflictResolutionStrategy` enum
- [ ] Add missing provider definitions
- [ ] Fix import statements for undefined types

---

## 🔴 DAY 5: DATABASE PERFORMANCE (Critical)

### Fix N+1 Queries
- [ ] `/lib/infrastructure/repositories/notes_core_repository.dart`
  - [ ] Line 247-260: Batch load tags and links
  - [ ] Line 277-290: Fix getRecentlyViewedNotes
  - [ ] Line 312-326: Fix listAfter method
  - [ ] Line 341-349: Fix getPinnedNotes

### Add Missing Indexes
```sql
-- Add to SQLite migration:
CREATE INDEX idx_local_notes_user_updated ON local_notes(user_id, updated_at DESC);
CREATE INDEX idx_note_tasks_user_status ON note_tasks(user_id, status, due_date);
CREATE INDEX idx_note_tags_batch ON note_tags(note_id) INCLUDE (tag);
CREATE INDEX idx_fts_optimization ON fts_notes(title, body);
```

### Implement Batch Loading Pattern
- [ ] Create `getBatchTagsForNotes()` method
- [ ] Create `getBatchLinksForNotes()` method
- [ ] Update all repository methods to use batch loading

---

## 🔴 WEEK 2: SECURITY & DEPENDENCIES

### Day 6-8: Real Encryption
- [ ] `/lib/data/remote/supabase_note_api.dart:652-683`
  - [ ] Replace base64 with AES-256-GCM
  - [ ] Add encryption key management
  - [ ] Implement key rotation mechanism
  - [ ] Add encryption tests

### Day 9-10: Dependency Updates
- [ ] Fix pubspec.yaml conflicts:
  ```yaml
  flutter_riverpod: ^3.0.0  # Update from 2.6.1
  mockito: ^5.6.0           # Resolve conflict
  test: ^1.25.0             # Specific version
  # Remove duplicate: riverpod: any
  ```
- [ ] Update deprecated Riverpod APIs (153 locations)
- [ ] Fix test mock handlers
- [ ] Update package_info_plus to v9.0.0

---

## 🟡 WEEK 3-4: ARCHITECTURE CLEANUP

### Migration Completion
- [ ] Choose single architecture (domain-driven)
- [ ] Remove dual repository pattern
- [ ] Delete legacy adapters
- [ ] Clean up migration config
- [ ] Remove feature flags

### Provider Refactoring
- [ ] Split 1,643-line providers.dart into:
  - [ ] `/lib/providers/notes_providers.dart`
  - [ ] `/lib/providers/folders_providers.dart`
  - [ ] `/lib/providers/tasks_providers.dart`
  - [ ] `/lib/providers/sync_providers.dart`
  - [ ] `/lib/providers/ui_providers.dart`

### Widget Optimization
- [ ] Add const constructors (target 95% coverage)
- [ ] Add ValueKey to all ListView items
- [ ] Fix widget disposal and memory leaks
- [ ] Implement proper stream subscription cleanup

---

## 📊 VERIFICATION CHECKLIST

### After Each Day:
```bash
# Run these commands to verify progress:
flutter clean
flutter pub get
dart analyze 2>&1 | grep "^  error" | wc -l  # Should decrease daily
flutter test                                   # Should start passing
flutter build apk --release                    # Ultimate goal
```

### Success Metrics:
- [ ] Day 1: <600 errors
- [ ] Day 2: <500 errors
- [ ] Day 3: <400 errors
- [ ] Day 4: <300 errors
- [ ] Day 5: <200 errors
- [ ] Week 2 End: <50 errors
- [ ] Week 3 End: 0 ERRORS ✅

---

## 🚨 CRITICAL FILES TO FIX FIRST

Priority order based on error count and impact:

1. `/lib/ui/notes_list_screen.dart` - 44 errors
2. `/lib/infrastructure/repositories/notes_core_repository.dart` - N+1 queries
3. `/lib/services/unified_template_service.dart` - 8 errors
4. `/lib/data/remote/supabase_note_api.dart` - Security vulnerability
5. `/lib/providers.dart` - Architecture complexity
6. `/test/test_helpers.dart` - Blocks all tests
7. `/lib/ui/modern_edit_note_screen.dart` - 3 errors
8. `/lib/ui/modern_search_screen.dart` - 1 error

---

## 📞 ESCALATION TRIGGERS

**Escalate immediately if:**
- [ ] Errors increase instead of decrease
- [ ] Build time exceeds 5 minutes
- [ ] Memory usage exceeds 500MB
- [ ] Any data loss occurs
- [ ] Security vulnerability exploited

**Daily standup topics:**
- Error count reduction
- Blockers encountered
- Resource needs
- Timeline adjustments

---

## 🏁 FINAL VALIDATION

Before declaring production ready:
- [ ] 0 compilation errors
- [ ] 0 analyzer errors
- [ ] All tests passing
- [ ] Security audit passed
- [ ] Performance benchmarks met
- [ ] Code review completed
- [ ] Deployment guide updated
- [ ] Rollback plan tested

---

*This TODO list is based on the comprehensive audit conducted on September 26, 2025. Update daily with progress.*