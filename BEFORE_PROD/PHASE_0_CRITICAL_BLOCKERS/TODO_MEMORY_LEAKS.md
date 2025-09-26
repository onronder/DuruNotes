# 💧 TODO: Memory Leak Fixes

> **Priority**: P0 - CRITICAL
> **Time Estimate**: 16 hours
> **Current Leaks**: 38 identified
> **Target**: 0 leaks
> **Impact**: App crashes after ~2 hours of use

---

## 🚨 Current Memory Status

### Leak Categories
1. **AnimationController**: 8 instances not disposed
2. **Stream Subscriptions**: 15+ not cancelled
3. **Timers**: 2 not cancelled (Debouncer/Throttler)
4. **Providers**: 30+ with lifecycle issues
5. **TextEditingController**: Unknown count
6. **FocusNode**: Unknown count
7. **ScrollController**: Unknown count

### Memory Growth Pattern
- Initial: 120 MB
- After 1 hour: 280 MB
- After 2 hours: 450 MB (crash imminent)
- Growth rate: ~150 MB/hour

---

## ✅ Task 1: AnimationController Disposal (4 hours)

### Identified Leaks - EXACT LOCATIONS

#### 1. notes_list_screen.dart
- [ ] **Line 234**: `_fabAnimationController`
```dart
// ADD in dispose():
_fabAnimationController.dispose();
```

#### 2. modern_edit_note_screen.dart
- [ ] **Line 64-66**: Multiple controllers
```dart
late AnimationController _toolbarSlideController;  // Line 64
late AnimationController _saveButtonController;     // Line 67
// ADD in dispose():
_toolbarSlideController.dispose();
_saveButtonController.dispose();
```

#### 3. task_list_screen.dart
- [ ] **Line 178**: `_animationController`
```dart
// ADD in dispose():
_animationController.dispose();
```

#### 4. folder_management_screen.dart
- [ ] **Line 89**: `_expandController`
- [ ] **Line 90**: `_rotateController`
```dart
// ADD in dispose():
_expandController.dispose();
_rotateController.dispose();
```

#### 5. modern_search_screen.dart
- [ ] **Line 145**: `_searchAnimationController`
```dart
// ADD in dispose():
_searchAnimationController.dispose();
```

#### 6. template_gallery_screen.dart
- [ ] **Line 67**: `_gridAnimationController`
```dart
// ADD in dispose():
_gridAnimationController.dispose();
```

#### 7. settings_screen.dart
- [ ] **Line 203**: `_themeAnimationController`
```dart
// ADD in dispose():
_themeAnimationController.dispose();
```

#### 8. auth_screen.dart
- [ ] **Line 39**: `_fadeController`
- [ ] **Line 43**: `_slideController`
```dart
// ADD in dispose():
_fadeController.dispose();
_slideController.dispose();
```

---

## ✅ Task 2: Stream Subscription Cancellation (4 hours)

### Identified Stream Leaks

#### 1. providers.dart
- [ ] **Line 423**: Auth stream subscription
```dart
StreamSubscription? _authSubscription;
// In dispose:
_authSubscription?.cancel();
```

- [ ] **Line 567**: Notes stream subscription
```dart
StreamSubscription? _notesSubscription;
// In dispose:
_notesSubscription?.cancel();
```

- [ ] **Line 892**: Sync stream subscription
```dart
StreamSubscription? _syncSubscription;
// In dispose:
_syncSubscription?.cancel();
```

#### 2. sync_service.dart
- [ ] **Line 234**: Realtime subscription
- [ ] **Line 456**: Conflict stream
- [ ] **Line 678**: Queue processor stream

#### 3. notification_service.dart
- [ ] **Line 123**: FCM token stream
- [ ] **Line 234**: Message stream
- [ ] **Line 345**: Background message stream

#### 4. task_service.dart
- [ ] **Line 89**: Task update stream
- [ ] **Line 156**: Reminder stream

#### 5. import_service.dart
- [ ] **Line 234**: Progress stream

#### 6. export_service.dart
- [ ] **Line 189**: Export progress stream

#### 7. template_service.dart
- [ ] **Line 267**: Template update stream

#### 8. ai_suggestions_service.dart
- [ ] **Line 345**: Suggestion stream

### Fix Pattern
```dart
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((data) {
      // handle data
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();  // MUST HAVE
    super.dispose();
  }
}
```

---

## ✅ Task 3: Timer Disposal (2 hours)

### Debouncer Class
- [ ] **File**: `/lib/core/utils/debouncer.dart`
```dart
class Debouncer {
  Timer? _timer;

  void dispose() {
    _timer?.cancel();  // ADD THIS METHOD
  }
}
```

### Throttler Class
- [ ] **File**: `/lib/core/utils/throttler.dart`
```dart
class Throttler {
  Timer? _timer;

  void dispose() {
    _timer?.cancel();  // ADD THIS METHOD
  }
}
```

### Usage Locations to Update
- [ ] Search debouncer in `modern_search_screen.dart`
- [ ] Sync throttler in `sync_service.dart`
- [ ] Save debouncer in `modern_edit_note_screen.dart`
- [ ] Scroll throttler in `notes_list_screen.dart`

---

## ✅ Task 4: Provider Lifecycle Fixes (4 hours)

### Provider Disposal Pattern
```dart
final myProvider = StateNotifierProvider.autoDispose<MyNotifier, MyState>((ref) {
  // Setup
  final controller = MyController();

  // CRITICAL: Cleanup
  ref.onDispose(() {
    controller.dispose();
  });

  return MyNotifier(controller);
});
```

### Providers Needing Fixes (30+)

#### High Priority (Memory Heavy)
- [ ] `notesPageProvider` - Holds large note list
- [ ] `filteredNotesProvider` - Computed note list
- [ ] `searchResultsProvider` - Search cache
- [ ] `syncQueueProvider` - Sync operations
- [ ] `taskListProvider` - Task data
- [ ] `folderTreeProvider` - Folder hierarchy
- [ ] `templateCacheProvider` - Template data

#### Medium Priority
- [ ] `currentNoteProvider`
- [ ] `selectedFolderProvider`
- [ ] `activeTagsProvider`
- [ ] `reminderListProvider`
- [ ] `conflictListProvider`
- [ ] `exportProgressProvider`
- [ ] `importProgressProvider`

#### Fix Locations
- [ ] `/lib/providers.dart` - Main provider file
- [ ] `/lib/features/notes/providers/` - Note providers
- [ ] `/lib/features/folders/providers/` - Folder providers
- [ ] `/lib/features/tasks/providers/` - Task providers
- [ ] `/lib/features/sync/providers/` - Sync providers

---

## ✅ Task 5: TextEditingController Audit (2 hours)

### Find All Controllers
```bash
grep -r "TextEditingController" lib/ --include="*.dart" | grep -v "dispose"
```

### Common Locations
- [ ] All form screens
- [ ] All dialog widgets
- [ ] All search fields
- [ ] All input components

### Fix Pattern
```dart
class _MyFormState extends State<MyForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();  // MUST HAVE
    super.dispose();
  }
}
```

---

## 📊 Validation & Testing

### Memory Leak Detection
- [ ] Run Flutter DevTools Memory profiler
- [ ] Take heap snapshot before
- [ ] Use app for 30 minutes
- [ ] Take heap snapshot after
- [ ] Compare snapshots for leaks

### Automated Testing
```bash
# Run leak detector
flutter test --debug test/memory_leak_test.dart

# Profile memory usage
flutter run --profile

# Check for undisposed resources
flutter analyze | grep "dispose"
```

### Manual Testing Checklist
- [ ] Open/close each screen 10 times
- [ ] Check memory doesn't grow
- [ ] Verify all animations stop
- [ ] Confirm no active timers
- [ ] Check stream count returns to baseline

---

## 🎯 Success Criteria

### All Must Be TRUE
- [ ] Zero AnimationController leaks
- [ ] Zero Stream subscription leaks
- [ ] Zero Timer leaks
- [ ] All providers properly disposed
- [ ] All TextEditingControllers disposed
- [ ] Memory stable over 24 hours
- [ ] No memory growth on screen navigation
- [ ] DevTools shows no leaks
- [ ] Memory usage < 200 MB average
- [ ] No crashes in 48-hour test

---

## 📝 Verification Commands

```bash
# Check for undisposed AnimationControllers
grep -r "AnimationController" lib/ | grep -v "dispose"

# Check for uncancelled streams
grep -r "\.listen(" lib/ | grep -v "cancel"

# Check for timer leaks
grep -r "Timer\." lib/ | grep -v "cancel"

# Find TextEditingControllers without dispose
grep -r "TextEditingController" lib/ | xargs grep -L "dispose()"

# Count total dispose calls
grep -r "\.dispose()" lib/ | wc -l

# Memory baseline
flutter run --profile --trace-startup
```

---

## ⚠️ Common Memory Mistakes

1. **Forgetting dispose()** - Always override dispose
2. **Not cancelling streams** - Every listen needs a cancel
3. **Keeping references** - Clear references in dispose
4. **Circular references** - Break cycles explicitly
5. **Static holders** - Avoid static widget references
6. **Global controllers** - Use scoped controllers
7. **Not using autoDispose** - Prefer autoDispose providers
8. **Listener accumulation** - Remove listeners in dispose

---

**Remember**: Every leak compounds. Fix them ALL, not just some.