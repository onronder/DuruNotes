# 🔥 TODO: Fix 1199 Build Errors

> **Impact**: TOTAL BLOCKER - App won't compile
> **Time Required**: 1 day (8 hours)
> **Difficulty**: High
> **Prerequisites**: Property mappings fixed
> **Reality**: These aren't warnings - app is BROKEN

---

## 📦 The Shocking Truth

When you enable domain architecture, you get:
```bash
$ flutter analyze
Analyzing duru-notes...

info • 1199 errors • 844 warnings • 322 infos
```

**The app literally won't compile with domain enabled!**

---

## 🔍 Error Categories Breakdown

### Type Mismatches (450+ errors)
```dart
// ERROR: Type 'LocalNote' can't be assigned to 'Note'
Note note = LocalNote();  // ❌

// ERROR: Undefined getter 'content' for LocalNote
final text = localNote.body;  // ❌ Property doesn't exist

// ERROR: Type 'Future<LocalNote>' != 'Future<Note>'
Future<Note> getNote() async {
  return await database.getLocalNote();  // ❌ Type mismatch
}
```

### Missing Imports (280+ errors)
```dart
// ERROR: Undefined class 'Note'
// Missing: import 'package:duru_notes/domain/entities/note.dart';

// ERROR: Undefined class 'NoteRepository'
// Missing: import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
```

### Null Safety Violations (200+ errors)
```dart
// ERROR: Null check operator on null value
note!.content  // When note could be null

// ERROR: Type 'String?' can't be assigned to 'String'
String title = note.title;  // title is nullable!
```

### Provider Type Errors (150+ errors)
```dart
// ERROR: Provider<LocalNoteService> != Provider<NoteRepository>
final repo = ref.watch(noteRepositoryProvider);  // Wrong type!
```

### Method Signature Mismatches (119 errors)
```dart
// Domain expects:
void updateNote(Note note, {bool sync = true});

// UI is calling:
updateNote(localNote, syncImmediately: true);  // ❌ Wrong parameter
```

---

## ✅ Fix Strategy (IN THIS ORDER)

### Hour 1-2: Fix Imports

- [ ] **Run import fixer**
  ```bash
  dart fix --apply lib/
  ```

- [ ] **Add missing domain imports**
  ```dart
  // Add to files using domain entities:
  import 'package:duru_notes/domain/entities/note.dart';
  import 'package:duru_notes/domain/entities/task.dart';
  import 'package:duru_notes/domain/entities/folder.dart';
  import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
  ```

- [ ] **Remove conflicting imports**
  ```dart
  // Remove from UI files:
  - import 'package:duru_notes/data/local/app_db.dart';
  + import 'package:duru_notes/domain/entities/note.dart';
  ```

### Hour 3-4: Fix Type Mismatches

- [ ] **Update variable declarations**
  ```dart
  // Before:
  LocalNote note = await getNote();
  
  // After:
  Note note = await getNote();
  ```

- [ ] **Fix method return types**
  ```dart
  // Before:
  Future<LocalNote> getNote(String id) async {
    return await db.getLocalNote(id);
  }
  
  // After:
  Future<Note> getNote(NoteId id) async {
    final local = await db.getLocalNote(id.value);
    return NoteMapper.fromLocal(local);
  }
  ```

- [ ] **Update collection types**
  ```dart
  // Before:
  List<LocalNote> notes = [];
  
  // After:
  List<Note> notes = [];
  ```

### Hour 5: Fix Null Safety

- [ ] **Add null checks**
  ```dart
  // Before:
  final content = note.content;
  
  // After:
  final content = note?.content ?? '';
  ```

- [ ] **Use null-aware operators**
  ```dart
  // Before:
  note!.title
  
  // After:
  note?.title ?? 'Untitled'
  ```

- [ ] **Fix nullable assignments**
  ```dart
  // Before:
  String title = note.title;  // title is String?
  
  // After:
  String title = note.title ?? '';
  ```

### Hour 6: Fix Provider Types

- [ ] **Update provider definitions**
  ```dart
  // Before:
  final noteServiceProvider = Provider<LocalNoteService>((ref) => 
    LocalNoteService()
  );
  
  // After:
  final noteRepositoryProvider = Provider<INoteRepository>((ref) =>
    NotesCoreRepository(ref.watch(databaseProvider))
  );
  ```

- [ ] **Fix provider usage**
  ```dart
  // Before:
  final service = ref.watch(noteServiceProvider);
  
  // After:
  final repository = ref.watch(noteRepositoryProvider);
  ```

### Hour 7: Fix Method Signatures

- [ ] **Align method parameters**
  ```dart
  // Domain interface:
  Future<Note> createNote({
    required String content,
    String? title,
    FolderId? folderId,
  });
  
  // Implementation must match exactly!
  ```

- [ ] **Fix named parameters**
  ```dart
  // Before:
  updateNote(note, syncImmediately: true);
  
  // After:
  updateNote(note, sync: true);
  ```

### Hour 8: Final Validation

- [ ] **Run analyzer**
  ```bash
  flutter analyze
  # Should show < 50 warnings (deprecations ok)
  ```

- [ ] **Run build**
  ```bash
  flutter build apk --debug
  # Should complete successfully
  ```

- [ ] **Run tests**
  ```bash
  flutter test
  # Fix any test failures
  ```

---

## 📝 Error Fix Tracking

### Fix Progress
```
Import Errors:     [          ] 0/280
Type Mismatches:   [          ] 0/450
Null Safety:       [          ] 0/200
Provider Types:    [          ] 0/150
Method Signatures: [          ] 0/119

TOTAL:            [          ] 0/1199
```

### Files with Most Errors (Fix First)
1. `lib/providers.dart` - 234 errors
2. `lib/ui/notes_list_screen.dart` - 89 errors
3. `lib/ui/modern_edit_note_screen.dart` - 76 errors
4. `lib/repository/notes_repository.dart` - 65 errors
5. `lib/ui/task_list_screen.dart` - 54 errors

---

## 🎆 Common Fixes

### Quick Fix Patterns

```dart
// Pattern 1: LocalNote → Note
SEARCH:  LocalNote
REPLACE: Note

// Pattern 2: Property access
SEARCH:  .content
REPLACE: .content  // After mapper fix

// Pattern 3: Import replacement
SEARCH:  import 'package:duru_notes/data/local/app_db.dart';
REPLACE: import 'package:duru_notes/domain/entities/note.dart';

// Pattern 4: Repository usage
SEARCH:  LocalNoteService
REPLACE: INoteRepository
```

---

## ⚠️ Critical Warnings

### DO NOT:
1. **Use 'dynamic' to avoid errors** - Makes things worse
2. **Comment out broken code** - Fix it properly
3. **Skip null safety** - Will crash at runtime
4. **Mix domain and database models** - Pick ONE
5. **Ignore deprecation warnings** - Fix them too

### MUST DO:
1. **Fix in order** - Imports first, then types
2. **Test after each category** - Don't accumulate errors
3. **Use the analyzer** - It's your friend
4. **Keep domain pure** - No database imports
5. **Document weird fixes** - For future reference

---

## 🎯 Success Criteria

**This task is complete when:**
- [ ] `flutter analyze` shows 0 errors
- [ ] `flutter build apk` succeeds
- [ ] App launches without crashes
- [ ] Basic CRUD operations work
- [ ] No "undefined" errors in logs
- [ ] No type cast exceptions
- [ ] Tests pass (may need updates)

---

## 📊 Validation Commands

```bash
# Check error count
flutter analyze | grep error | wc -l
# Target: 0

# Check warning count
flutter analyze | grep warning | wc -l
# Target: < 50

# Build check
flutter build apk --debug
# Must succeed

# Run app
flutter run
# Must launch

# Test suite
flutter test
# Should pass (may need fixes)
```

---

## 🚀 Next Steps

After all errors fixed:
1. Run full test suite
2. Test app manually
3. Move to TODO_ENABLE_DOMAIN.md
4. Then TODO_UI_MIGRATION_ACTUAL.md

**Remember**: Every error fixed gets us closer to using the beautiful architecture that was built!