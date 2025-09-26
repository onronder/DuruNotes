# 🎨 UI/FRONTEND ISSUES
*Separated from multi-agent audit findings*

## 🔴 CRITICAL UI ISSUES (P0)

### 1. Missing Type Imports (Blocks ALL Builds)
**Affected Files**: 20+ UI files
**Common missing imports**:
```dart
// Add to affected files:
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' show TaskStatus, TaskPriority;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
```

**Specific files needing fixes**:
- `lib/ui/note_search_delegate.dart` - SavedSearch type missing
- `lib/ui/enhanced_task_list_screen.dart` - TaskStatus/TaskPriority missing
- `lib/ui/modern_edit_note_screen.dart` - Multiple type issues

### 2. Property Access Errors
**Wrong property names after migration**:
```dart
// UI components using wrong properties:
note.content → should be note.body (for note content)
task.content → should be task.title (for task name)
note.pinned → should be note.isPinned
folder.parentId → should check metadata['parentId']
```

---

## 🟡 FLUTTER-SPECIFIC ISSUES (P1)

### Memory Leaks (151+ instances)
**1. TextEditingController disposal issues**:
```dart
// WRONG - Controllers not disposed:
class _NoteEditState extends State<NoteEdit> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  // Missing dispose() method!
}

// CORRECT:
class _NoteEditState extends State<NoteEdit> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
```

**2. Timer disposal in widgets**:
```dart
// Files with timer leaks:
- unified_task_service.dart (periodic timers)
- task_time_tracker_widget.dart (countdown timers)
- sync_status_widget.dart (refresh timers)
```

**3. StreamSubscription leaks**:
```dart
// Missing cancellation:
StreamSubscription? _noteStream;

@override
void dispose() {
  _noteStream?.cancel();  // Often missing
  super.dispose();
}
```

### BuildContext Misuse
**Files violating context rules**:
```dart
// WRONG - Using context after async:
onPressed: () async {
  await someAsyncOperation();
  Navigator.pop(context);  // ❌ Context may be invalid
}

// CORRECT:
onPressed: () async {
  await someAsyncOperation();
  if (mounted) {  // ✅ Check mounted first
    Navigator.pop(context);
  }
}
```

**Common violations found in**:
- Dialog callbacks
- Async button handlers
- Timer callbacks
- Network response handlers

---

## 🟠 UI COMPONENT ISSUES (P2)

### Dual-Type Components (Technical Debt)
**Components supporting both old and new models**:
```dart
// Files with dual support:
- dual_type_note_card.dart
- dual_type_task_card.dart
- dual_type_folder_item.dart

// These create complexity:
if (isUsingDomain) {
  // Domain model code
} else {
  // Legacy model code
}
```

### Widget Rebuilding Issues
**Unnecessary rebuilds detected**:
```dart
// WRONG - Rebuilds on every frame:
Widget build(BuildContext context) {
  final notes = ref.watch(notesProvider);  // Watches entire provider

// CORRECT - Selective watching:
Widget build(BuildContext context) {
  final noteCount = ref.watch(
    notesProvider.select((notes) => notes.length)
  );
```

### Platform-Specific Issues
**iOS/Android inconsistencies**:
1. **Haptic feedback missing on Android**
2. **Swipe gestures not working on iOS**
3. **Keyboard handling differences**
4. **Safe area issues on newer devices**

---

## 🔵 UI DATA FLOW ISSUES (P2)

### Provider Dependencies
**Circular dependencies found**:
```dart
// Problem: Providers depending on each other
notesProvider → foldersProvider → notesProvider

// Solution: Break circular deps with proper layering
```

**Provider disposal issues**:
```dart
// WRONG - ref.read in dispose:
@override
void dispose() {
  ref.read(someProvider).cleanup();  // ❌ ref not available
}

// CORRECT - Store reference earlier:
late final SomeService _service;

@override
void initState() {
  _service = ref.read(someProvider);
}

@override
void dispose() {
  _service.cleanup();  // ✅ Use stored reference
}
```

### State Management Issues
**Mixed state management patterns**:
- Some screens use Riverpod
- Some use StatefulWidget state
- Some use both (causing conflicts)
- No consistent pattern

---

## 📊 UI/FRONTEND METRICS

### Current Issues
| Component | Issues | Severity | Impact |
|-----------|--------|----------|---------|
| Type Imports | 20+ files | CRITICAL | Blocks builds |
| Memory Leaks | 151+ | HIGH | App crashes |
| Context Misuse | 30+ places | MEDIUM | Runtime errors |
| Dual Components | 3 files | LOW | Maintenance debt |
| Provider Issues | 10+ | MEDIUM | State bugs |

### Performance Impact
| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Widget Rebuilds | Excessive | Optimized | ❌ |
| Memory Usage | Growing | Stable | ❌ |
| Frame Rate | 45-60 fps | 60 fps | ⚠️ |
| App Startup | 3.5s | <2s | ❌ |

---

## 🎯 UI FIX PRIORITY

### Day 2 (Immediate)
1. Add all missing type imports
2. Fix property access errors
3. Verify UI compilation

### Week 1
1. Fix all TextEditingController disposals
2. Fix timer disposals
3. Add mounted checks after async
4. Fix context usage patterns

### Week 2
1. Remove dual-type components
2. Optimize widget rebuilds
3. Standardize state management
4. Fix platform-specific issues

### Week 3
1. Performance optimization
2. Accessibility audit
3. UI testing
4. Polish and refinement

---

## 🧪 UI VALIDATION

### Visual Regression Points
**Critical UI flows to test**:
1. Note creation and editing
2. Task management workflow
3. Folder navigation
4. Search and filter
5. Settings and preferences
6. Sync status display

### Accessibility Checks
```dart
// Required for each screen:
- Semantic labels
- Focus management
- Contrast ratios
- Touch target sizes (min 44x44)
- Screen reader support
```

### Platform Testing
```bash
# iOS specific
- Test on iPhone 15 Pro (Dynamic Island)
- Test on iPad (multitasking)
- Test on iPhone SE (small screen)

# Android specific
- Test on Pixel 8 (Material You)
- Test on Samsung (One UI)
- Test on tablet (large screen)
```

---

## 🔍 UI VALIDATION COMMANDS

```bash
# Check for missing dispose methods
grep -r "TextEditingController" lib/ui/ | grep -v "dispose" | wc -l

# Check for mounted checks
grep -r "await.*Navigator\|await.*ScaffoldMessenger" lib/ui/ | grep -v "mounted" | wc -l

# Check for dual-type components
grep -r "dual_type" lib/ui/ | wc -l

# Check for context misuse
grep -r "context\)" lib/ui/ | grep "async" | wc -l

# Flutter analyze for UI
flutter analyze lib/ui/ 2>&1 | grep -c "warning\|error"
```

---

## 🎨 UI BEST PRACTICES TO IMPLEMENT

### 1. Consistent Widget Structure
```dart
class MyWidget extends ConsumerStatefulWidget {
  // 1. Constructor with required/optional params
  // 2. Static methods
  // 3. createState
}

class _MyWidgetState extends ConsumerState<MyWidget> {
  // 1. Member variables
  // 2. initState
  // 3. didUpdateWidget
  // 4. dispose
  // 5. build
  // 6. Helper methods
}
```

### 2. Resource Management Pattern
```dart
class ResourceManager {
  final _controllers = <TextEditingController>[];
  final _subscriptions = <StreamSubscription>[];
  final _timers = <Timer>[];

  T register<T>(T resource) {
    // Track resource for disposal
    return resource;
  }

  void dispose() {
    // Dispose all tracked resources
  }
}
```

### 3. Safe Async Pattern
```dart
Future<void> _safeAsync(Future<void> Function() action) async {
  try {
    await action();
    if (mounted) {
      // Safe to use context
    }
  } catch (e) {
    // Handle error
  }
}
```

---

**Document Created**: September 26, 2025
**Severity**: CRITICAL (Build blocking)
**Next Action**: Add missing type imports