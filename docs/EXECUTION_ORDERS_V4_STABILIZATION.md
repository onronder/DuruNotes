# 📋 EXECUTION ORDERS V4.0 - STABILIZATION PROTOCOL
**Status:** CRITICAL - Complete Stabilization Required
**Errors:** 635 total (0 production after fixes)
**Goal:** Functional app on iOS/Android with sync

---

## 🚨 DAY 1: DEPENDENCY RESOLUTION (4 hours)

### Morning (2 hours)
```bash
cd /Users/onronder/duru-notes
```

1. **Fix pubspec.yaml**
```yaml
name: duru_notes
description: Advanced note-taking application
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.13.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # Core packages - PIN VERSIONS
  flutter_riverpod: ^2.6.1
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.39
  supabase_flutter: ^2.7.0

  # Utilities - PIN VERSIONS
  uuid: ^4.5.1
  path_provider: ^2.1.5
  path: ^1.9.0
  intl: ^0.19.0
  shared_preferences: ^2.3.3
  url_launcher: ^6.3.1
  share_plus: ^10.1.2

  # Security - PIN VERSION
  encrypt: ^5.0.3
  crypto: ^3.0.6

  # UI packages - PIN VERSIONS
  flutter_markdown: ^0.7.4
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0

  # Remove these duplicates:
  # riverpod: any  # REMOVE
  # collection: any  # Use built-in

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.7.2
  drift_dev: ^2.21.0
  mockito: ^5.6.0
  test: ^1.25.0
  flutter_lints: ^5.0.0
```

2. **Clean and get packages**
```bash
rm -rf .dart_tool/
rm -rf build/
rm pubspec.lock
flutter clean
flutter pub get
```

### Afternoon (2 hours)
3. **Verify resolution**
```bash
flutter pub deps
dart analyze 2>&1 | grep "error" | wc -l
```

4. **Fix any remaining dependency issues**

---

## 🔧 DAY 2: COMPILATION FIXES (8 hours)

### Morning (4 hours)
1. **Create missing converters**
```bash
touch lib/core/converters/task_converter.dart
touch lib/core/converters/template_converter.dart
```

2. **Implement TaskConverter**
```dart
// lib/core/converters/task_converter.dart
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;

class TaskConverter {
  static domain.Task fromLocal(NoteTask local) {
    return domain.Task(
      id: local.id,
      noteId: local.noteId,
      title: local.title,
      description: local.description,
      isCompleted: local.isCompleted,
      dueDate: local.dueDate,
      priority: local.priority,
      tags: [],
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  static NoteTask toLocal(domain.Task task) {
    return NoteTask(
      id: task.id,
      noteId: task.noteId,
      title: task.title,
      description: task.description ?? '',
      isCompleted: task.isCompleted,
      dueDate: task.dueDate,
      priority: task.priority,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }
}
```

3. **Fix remaining type errors**
```bash
dart analyze 2>&1 | grep "error - lib/" | head -20
# Fix each error systematically
```

### Afternoon (4 hours)
4. **Verify all production code compiles**
```bash
dart analyze lib/ 2>&1 | grep "error"
# Should show 0 errors
```

---

## 🏗️ DAY 3-4: REPOSITORY IMPLEMENTATION (16 hours)

### Day 3: Core Repositories (8 hours)
1. **Fix INotesRepository interface**
2. **Implement all missing methods in NotesCoreRepository**
3. **Fix TaskCoreRepository**
4. **Fix FolderCoreRepository**

### Day 4: Service Layer (8 hours)
1. **Fix ServiceAdapter**
2. **Fix RepositoryAdapter**
3. **Remove dual architecture code**
4. **Test data flow**

---

## 🎨 DAY 5: UI FIXES (8 hours)

### Morning (4 hours)
1. **Fix notes_list_screen.dart**
   - Apply type converters
   - Fix provider usage
   - Remove migration_fixes dependency

2. **Fix modern_edit_note_screen.dart**
   - Fix validation
   - Fix save logic

### Afternoon (4 hours)
3. **Test on both platforms**
```bash
flutter run -d ios
flutter run -d android
```

---

## 🔐 DAY 6: SECURITY FIX - CRITICAL (8 hours)

### Morning (4 hours)
1. **Create AES encryption service**
```dart
// lib/services/security/aes_encryption_service.dart
import 'package:encrypt/encrypt.dart';

class AESEncryptionService {
  static final _key = Key.fromBase64(
    // Generate with: Key.fromSecureRandom(32).base64
    'YOUR_32_BYTE_BASE64_KEY_HERE'
  );

  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String plainText) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decrypt(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length != 2) return encryptedText;

    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    return _encrypter.decrypt(encrypted, iv: iv);
  }
}
```

2. **Replace base64 encoding in SupabaseNoteApi**

### Afternoon (4 hours)
3. **Test encryption thoroughly**
4. **Audit for any remaining security issues**

---

## 🔄 DAY 7-8: SYNC IMPLEMENTATION (16 hours)

### Day 7: Infrastructure (8 hours)
1. **Fix Supabase connection**
2. **Implement auth flow**
3. **Test API calls**

### Day 8: Bidirectional Sync (8 hours)
1. **Implement push sync**
2. **Implement pull sync**
3. **Test conflict resolution**

---

## ⚡ DAY 9-10: PERFORMANCE (16 hours)

### Day 9: Database (8 hours)
1. **Fix N+1 queries - CRITICAL**
```dart
// Add to app_db.dart
Future<Map<String, List<String>>> getBatchTagsForNotes(List<String> noteIds) async {
  final tags = await (select(noteTags)
    ..where((t) => t.noteId.isIn(noteIds)))
    .get();

  final result = <String, List<String>>{};
  for (final tag in tags) {
    result.putIfAbsent(tag.noteId, () => []).add(tag.tag);
  }
  return result;
}
```

2. **Apply batch loading to all 7 problematic methods**

### Day 10: UI Performance (8 hours)
1. **Optimize large files**
2. **Fix provider rebuilds**
3. **Profile and optimize**

---

## ✅ DAY 11-14: VALIDATION (32 hours)

### Days 11-12: Screen Testing
- Test every screen
- Fix navigation
- Verify functionality

### Days 13-14: Integration
- Full system test
- Platform validation
- Bug fixes

---

## 📊 DAILY COMMANDS

### Morning Validation
```bash
#!/bin/bash
echo "=== Daily Build Check ==="
flutter clean
flutter pub get
ERROR_COUNT=$(dart analyze 2>&1 | grep "error" | wc -l)
echo "Errors: $ERROR_COUNT"

if [ $ERROR_COUNT -eq 0 ]; then
  echo "✅ Building iOS..."
  flutter build ios --debug --no-codesign

  echo "✅ Building Android..."
  flutter build apk --debug
else
  echo "❌ Fix errors before building"
fi
```

### Progress Tracking
```bash
# Create progress file
echo "Day $(date +%j): $ERROR_COUNT errors" >> stabilization_progress.log
```

---

## 🚫 STRICT RULES

1. **NO NEW FEATURES** - Only fixes
2. **NO REFACTORING** - Unless required for fixes
3. **TEST AFTER EACH FIX** - Ensure nothing breaks
4. **COMMIT FREQUENTLY** - Small, focused commits
5. **DOCUMENT ISSUES** - Log all problems found

---

## 🎯 SUCCESS METRICS

- [ ] Day 1: Dependencies resolve
- [ ] Day 2: 0 production errors
- [ ] Day 5: App runs on both platforms
- [ ] Day 6: Encryption implemented
- [ ] Day 8: Sync works
- [ ] Day 10: Performance acceptable
- [ ] Day 14: All screens functional

---

*Execute orders sequentially. Do not skip steps. Document all changes.*