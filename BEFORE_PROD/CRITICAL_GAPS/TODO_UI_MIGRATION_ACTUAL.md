# 📦 TODO: UI Migration Reality Check

> **Current Status**: 2/45 components migrated (4.4%)
> **Time Required**: 2-3 days minimum
> **Difficulty**: High (tedious + error-prone)
> **Impact**: NOTHING works until this is done
> **Truth**: This is why domain architecture doesn't work yet

---

## 🔴 The Brutal Truth

### What Was Claimed
"UI migration complete ✓" - Phase 3 commits

### What's Actually True
```bash
# Count UI files using LocalNote (OLD model)
grep -r "LocalNote" lib/ui/ | wc -l
# Result: 200+ references

# Count UI files using domain.Note (NEW model)
grep -r "domain\.Note" lib/ui/ | wc -l
# Result: 2 references

# Migration percentage
echo "2/45 * 100" | bc -l
# Result: 4.44%
```

**96% of UI still uses database models directly!**

---

## 📊 Migration Status by Component

### 🏠 Screens (2/12 = 17%)

| Screen | Status | LocalNote Refs | Domain Refs | Priority |
|--------|--------|----------------|-------------|----------|
| notes_list_screen.dart | 🔶 PARTIAL | 12 | 3 | CRITICAL |
| modern_edit_note_screen.dart | ❌ NOT STARTED | 24 | 0 | CRITICAL |
| task_list_screen.dart | ❌ NOT STARTED | 18 | 0 | CRITICAL |
| folder_management_screen.dart | ❌ NOT STARTED | 15 | 0 | CRITICAL |
| template_gallery_screen.dart | ❌ NOT STARTED | 8 | 0 | HIGH |
| modern_search_screen.dart | ❌ NOT STARTED | 22 | 0 | HIGH |
| settings_screen.dart | ❌ NOT STARTED | 3 | 0 | MEDIUM |
| auth_screen.dart | ❌ NOT STARTED | 0 | 0 | LOW |
| reminders_screen.dart | ❌ NOT STARTED | 11 | 0 | MEDIUM |
| tags_screen.dart | ❌ NOT STARTED | 7 | 0 | MEDIUM |
| saved_search_management_screen.dart | ❌ NOT STARTED | 5 | 0 | LOW |
| change_password_screen.dart | ❌ NOT STARTED | 0 | 0 | LOW |

### 🎮 Components (1/33 = 3%)

| Component Type | Total | Migrated | Remaining | 
|---------------|-------|----------|----------|
| Note Components | 12 | 1 | 11 |
| Task Components | 8 | 0 | 8 |
| Folder Components | 6 | 0 | 6 |
| Search Components | 4 | 0 | 4 |
| Template Components | 3 | 0 | 3 |
| Other Components | 12 | 0 | 12 |

---

## 🎆 Critical Path: 4 Screens First

### Day 1 Morning: modern_edit_note_screen.dart

- [ ] **Analyze current usage**
  ```bash
  grep -n "LocalNote" lib/ui/modern_edit_note_screen.dart
  # Find all 24 references
  ```

- [ ] **Update imports**
  ```dart
  - import 'package:duru_notes/data/local/app_db.dart';
  + import 'package:duru_notes/domain/entities/note.dart';
  + import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
  ```

- [ ] **Change state variables**
  ```dart
  - LocalNote? _note;
  - List<LocalNote> _suggestions = [];
  + Note? _note;
  + List<Note> _suggestions = [];
  ```

- [ ] **Update method signatures**
  ```dart
  - Future<void> _loadNote(String noteId) async {
  -   final localNote = await _database.getNote(noteId);
  -   setState(() => _note = localNote);
  - }
  
  + Future<void> _loadNote(NoteId noteId) async {
  +   final note = await _repository.getNote(noteId);
  +   setState(() => _note = note);
  + }
  ```

- [ ] **Fix property access**
  ```dart
  - _contentController.text = _note.content;
  - _titleController.text = _note.title ?? '';
  
  + _contentController.text = _note.content;
  + _titleController.text = _note.title ?? '';
  ```

- [ ] **Update save logic**
  ```dart
  - await _database.updateNote(_note.copyWith(
  -   content: _contentController.text,
  -   modifiedDate: DateTime.now(),
  - ));
  
  + await _repository.updateNote(
  +   _note.copyWith(
  +     content: _contentController.text,
  +     modifiedDate: DateTime.now(),
  +   ),
  + );
  ```

- [ ] **Test the screen**
  - [ ] Create note
  - [ ] Edit note
  - [ ] Delete note
  - [ ] Auto-save works

### Day 1 Afternoon: notes_list_screen.dart

- [ ] **Complete partial migration**
  - [x] Basic domain support (done)
  - [ ] Remove remaining 12 LocalNote refs
  - [ ] Fix pagination with domain
  - [ ] Fix filtering with domain
  - [ ] Update sorting logic

- [ ] **Update stream handling**
  ```dart
  - Stream<List<LocalNote>> get notesStream
  + Stream<List<Note>> get notesStream
  ```

- [ ] **Fix list item builder**
  ```dart
  - Widget _buildNoteCard(LocalNote note)
  + Widget _buildNoteCard(Note note)
  ```

### Day 2 Morning: task_list_screen.dart

- [ ] **Replace task model**
  ```dart
  - import 'package:duru_notes/data/local/app_db.dart';
  + import 'package:duru_notes/domain/entities/task.dart';
  ```

- [ ] **Update task operations**
  - [ ] Create task from note
  - [ ] Update task status
  - [ ] Delete task
  - [ ] Link task to note

- [ ] **Fix task-note relationship**
  ```dart
  - final note = await _database.getNote(task.noteId);
  + final note = await _repository.getNote(task.noteId);
  ```

### Day 2 Afternoon: folder_management_screen.dart

- [ ] **Replace folder model**
  ```dart
  - LocalFolder
  + Folder
  ```

- [ ] **Update tree structure**
  ```dart
  - List<LocalFolder> _buildFolderTree()
  + List<Folder> _buildFolderTree()
  ```

- [ ] **Fix folder operations**
  - [ ] Create folder
  - [ ] Move folder
  - [ ] Delete folder
  - [ ] Move notes between folders

---

## 🛠️ Migration Pattern

### For Each Component:

1. **Find all database model usage**
   ```bash
   grep -n "LocalNote\|LocalTask\|LocalFolder" [file]
   ```

2. **Update imports**
   ```dart
   // Remove:
   - import '.../app_db.dart';
   - import '.../local_note_service.dart';
   
   // Add:
   + import '.../domain/entities/note.dart';
   + import '.../domain/repositories/i_notes_repository.dart';
   ```

3. **Change type declarations**
   ```dart
   - LocalNote note
   + Note note
   
   - Future<LocalNote>
   + Future<Note>
   
   - List<LocalNote>
   + List<Note>
   ```

4. **Update repository calls**
   ```dart
   - _database.getNotes()
   + _repository.getAllNotes()
   
   - _localNoteService.create()
   + _repository.createNote()
   ```

5. **Fix property access**
   ```dart
   // May change based on mapper fixes
   - note.createdDate
   + note.createdAt
   ```

6. **Test thoroughly**
   - Create
   - Read
   - Update
   - Delete
   - List/Search

---

## ⚠️ Common Pitfalls

### Type Mismatches
```dart
// WRONG: Mixing models
Note note = LocalNote();  // ❌

// RIGHT: Use domain consistently
Note note = Note(...);  // ✓
```

### Null Safety
```dart
// WRONG: Assuming non-null
note.title.length  // ❌ Crashes if title is null

// RIGHT: Handle nulls
note.title?.length ?? 0  // ✓
```

### Async/Await
```dart
// WRONG: Missing await
final note = _repository.getNote(id);  // ❌ Returns Future

// RIGHT: Await the result
final note = await _repository.getNote(id);  // ✓
```

### Provider Usage
```dart
// WRONG: Old provider
ref.watch(localNoteServiceProvider)  // ❌

// RIGHT: Domain provider
ref.watch(noteRepositoryProvider)  // ✓
```

---

## 📊 Progress Tracking

### Overall Migration
```
Screens:     [█░░░░░░░░░] 17%  (2/12)
Components:  [░░░░░░░░░░] 3%   (1/33)
TOTAL:       [░░░░░░░░░░] 7%   (3/45)
```

### Daily Goals
| Day | Goal | Components |
|-----|------|------------|
| 1 | Critical screens | 2 screens |
| 2 | Critical screens | 2 screens |
| 3 | Secondary screens | 4 screens |
| 4 | Components batch 1 | 10 components |
| 5 | Components batch 2 | 10 components |
| 6 | Components batch 3 | 10 components |
| 7 | Final + testing | 3 components + verify |

---

## 🎯 Success Criteria

### Per Component
- [ ] Zero LocalNote/LocalTask/LocalFolder imports
- [ ] All operations use domain repositories
- [ ] Type safety maintained
- [ ] All tests pass
- [ ] No runtime errors

### Overall
- [ ] 45/45 components migrated
- [ ] App runs with domain enabled
- [ ] No performance regression
- [ ] All features work
- [ ] Can delete all database model imports

---

## 📝 Testing Checklist

After each component migration:

- [ ] **Unit test**
  ```bash
  flutter test test/ui/[component]_test.dart
  ```

- [ ] **Integration test**
  ```bash
  flutter test integration_test/[feature]_test.dart
  ```

- [ ] **Manual test**
  - [ ] All CRUD operations
  - [ ] Edge cases
  - [ ] Error handling
  - [ ] Performance

---

## 🚀 After Migration Complete

1. **Enable domain architecture**
   - See TODO_ENABLE_DOMAIN.md

2. **Remove old code**
   - Delete all LocalNote imports
   - Delete all database model usage
   - Remove legacy services

3. **Celebrate!**
   - The architecture finally works
   - Code is clean and maintainable
   - Ready for new features

---

**Current Reality**: 3/45 migrated | **Required**: 45/45 | **Time**: 3 days minimum

**Remember**: This isn't optional. The entire domain architecture is useless until this is done!